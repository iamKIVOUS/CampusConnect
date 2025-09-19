/**
 * @file Business logic for message and message status operations.
 * @author Your Name
 * @version 1.0.0
 */

import { Op } from 'sequelize';
import models from '../../models/index.js';
import { AppError } from '../../utils/error.js';
import { checkMembership, formatUserProfile, getOverallMessageStatus } from './chat.helpers.js';
import { getFullConversation } from './conversation.service.js';

const { Message, MessageStatus, Member, Conversation, Auth, Student, Employee, sequelize } = models;

/**
 * A local helper to create a message and its statuses within a transaction.
 * @private
 */
const _createMessageInTransaction = async (messageData, onlineUsersMap, t) => {
  const { conversationId, senderId, body, clientMsgId } = messageData;
  const message = await Message.create({ conversationId, senderId, body, clientMsgId, type: 'user' }, { transaction: t });
  
  const members = await Member.findAll({ where: { conversationId }, attributes: ['userId'], transaction: t, raw: true });
  const statuses = members.map(member => ({
    messageId: message.id,
    userId: member.userId,
    readAt: member.userId === senderId ? new Date() : null,
    deliveredAt: onlineUsersMap.has(member.userId) || member.userId === senderId ? new Date() : null,
  }));
  await MessageStatus.bulkCreate(statuses, { transaction: t });

  await Conversation.update({ lastMessageId: message.id, lastMessageAt: message.createdAt }, { where: { id: conversationId }, transaction: t });
  await Member.increment('unreadCount', { by: 1, where: { conversationId, userId: { [Op.ne]: senderId } }, transaction: t });

  return message;
};

/**
 * Atomically creates a message. If the conversation doesn't exist (for direct chats),
 * it creates the conversation as well in the same transaction.
 */
export const createMessageAndConversationIfNeeded = async (messageData, onlineUsersMap) => {
  const { conversationId, senderId, body, clientMsgId, members, type } = messageData;
  const t = await sequelize.transaction();
  let isNewConversation = false;
  try {
    let convId = conversationId;

    if (convId === 'new_direct_chat' && type === 'direct' && members) {
      isNewConversation = true;
      const allMemberIds = [...new Set([senderId, ...members.filter(id => id !== senderId)])];
      if (allMemberIds.length !== 2) throw new AppError('Direct conversations must have exactly two members.', 400);

      const existing = await sequelize.query(
          `SELECT "conversation_id" FROM "conversation_members" cm JOIN conversations c ON c.id = cm.conversation_id
           WHERE c.type = 'direct' AND cm.user_id IN (:allMemberIds)
           GROUP BY "conversation_id" HAVING COUNT(DISTINCT cm.user_id) = 2;`,
          { replacements: { allMemberIds }, type: sequelize.QueryTypes.SELECT, transaction: t }
      );

      if (existing.length > 0) {
        convId = existing[0].conversation_id;
        isNewConversation = false;
      } else {
        const conversation = await Conversation.create({ type, createdBy: senderId }, { transaction: t });
        const memberObjects = allMemberIds.map(userId => ({
          conversationId: conversation.id,
          userId,
          role: userId === senderId ? 'admin' : 'member'
        }));
        await Member.bulkCreate(memberObjects, { transaction: t });
        convId = conversation.id;
      }
    }

    const message = await _createMessageInTransaction({ conversationId: convId, senderId, body, clientMsgId }, onlineUsersMap, t);
    
    const newMessage = await Message.findByPk(message.id, {
      include: [
        { model: Auth, as: 'sender', include: [Student, Employee] },
        { model: MessageStatus, as: 'statuses' }
      ],
      transaction: t
    });

    const updatedConversation = await getFullConversation(convId, senderId, t);
    await t.commit();

    const formattedMessage = newMessage.toJSON();
    formattedMessage.sender = formatUserProfile(formattedMessage.sender);
    formattedMessage.status = getOverallMessageStatus(formattedMessage, senderId);

    return { newMessage: formattedMessage, updatedConversation, isNewConversation };
  } catch (err) {
    await t.rollback();
    throw err;
  }
};

/**
 * Fetches a paginated list of messages for a given conversation.
 */
export const getMessagesForConversation = async ({ conversationId, userId, limit = 30, cursor }) => {
  await checkMembership(conversationId, userId);
  const whereClause = { conversationId };
  if (cursor) {
    whereClause.id = { [Op.lt]: cursor };
  }
  const messages = await Message.findAll({
    where: whereClause,
    order: [['created_at', 'DESC']],
    limit: limit + 1,
    include: [
      { model: Auth, as: 'sender', include: [Student, Employee] },
      { model: MessageStatus, as: 'statuses' },
    ]
  });
  
  const hasMore = messages.length > limit;
  const nextCursor = hasMore ? messages[limit - 1].id : null;
  const paginatedMessages = hasMore ? messages.slice(0, limit) : messages;

  const formattedMessages = paginatedMessages.map(message => {
    const messageJson = message.toJSON();
    messageJson.sender = formatUserProfile(messageJson.sender);
    messageJson.status = getOverallMessageStatus(messageJson, userId);
    return messageJson;
  });

  return { messages: formattedMessages, pagination: { nextCursor, hasMore } };
};

/**
 * Marks a user's unread messages in a conversation as read.
 */
export const markMessagesAsRead = async ({ conversationId, userId }) => {
  return sequelize.transaction(async (t) => {
    await Member.update({ unreadCount: 0 }, { where: { conversationId, userId }, transaction: t });
    const statusesToUpdate = await MessageStatus.findAll({
      where: { userId, readAt: null },
      include: [{ model: Message, where: { conversationId }, attributes: ['id', 'senderId'] }],
      transaction: t
    });
    if (statusesToUpdate.length === 0) {
      return { affectedMessages: [] };
    }
    const messageIds = statusesToUpdate.map(s => s.messageId);
    await MessageStatus.update({ readAt: new Date() }, { where: { messageId: { [Op.in]: messageIds }, userId }, transaction: t });
    return { affectedMessages: statusesToUpdate.map(s => s.Message.toJSON()) };
  });
};

/**
 * Searches for messages within a user's conversations.
 */
export const searchMessagesForUser = async ({ query, userId, limit = 20, offset = 0 }) => {
  const userMemberships = await Member.findAll({ where: { userId }, attributes: ['conversationId'], raw: true });
  const conversationIds = userMemberships.map(m => m.conversationId);
  if (conversationIds.length === 0) return { messages: [], pagination: { hasMore: false } };
  
  const { count, rows } = await Message.findAndCountAll({
    where: {
      conversationId: { [Op.in]: conversationIds },
      body: { [Op.iLike]: `%${query}%` },
      type: 'user'
    },
    include: [
      { model: Auth, as: 'sender', include: [Student, Employee] },
      { model: Conversation, attributes: ['id', 'title', 'type'] },
      { model: MessageStatus, as: 'statuses' }
    ],
    order: [['createdAt', 'DESC']],
    limit,
    offset,
  });

  const formattedMessages = rows.map(message => {
    const messageJson = message.toJSON();
    messageJson.sender = formatUserProfile(messageJson.sender);
    messageJson.status = getOverallMessageStatus(messageJson, userId);
    return messageJson;
  });

  return {
    messages: formattedMessages,
    pagination: { total: count, limit, offset, hasMore: (offset + rows.length) < count }
  };
};

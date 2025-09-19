/**
 * @file Business logic for conversation entity management.
 * @author Your Name
 * @version 1.0.0
 */

import { Op } from 'sequelize';
import models from '../../models/index.js';
import { AppError } from '../../utils/error.js';
import { checkMembership, formatUserProfile, getOverallMessageStatus, createAndBroadcastSystemMessage } from './chat.helpers.js';

const { Conversation, Member, Message, MessageStatus, Auth, Student, Employee, sequelize } = models;

/**
 * Fetches a single, fully detailed conversation object for a specific user.
 */
export const getFullConversation = async (conversationId, userId, transaction) => {
  await checkMembership(conversationId, userId, transaction);
  const conversation = await Conversation.findByPk(conversationId, {
    include: [
      {
        model: Auth, as: 'Members', attributes: ['enrollment_number'],
        include: [Student, Employee],
        through: { attributes: ['role', 'unread_count', 'is_archived'] },
      },
      {
        model: Message, as: 'lastMessage',
        include: [
          { model: Auth, as: 'sender', attributes: ['enrollment_number'], include: [Student, Employee] },
          { model: MessageStatus, as: 'statuses' }
        ],
      },
    ],
    transaction,
  });
  if (!conversation) throw new AppError('Conversation not found', 404);
  
  const conversationJson = conversation.toJSON();
  const currentUserMembership = conversationJson.Members.find(m => m.enrollment_number === userId)?.Member;
  
  conversationJson.unreadCount = currentUserMembership?.unread_count ?? 0;
  conversationJson.isArchived = currentUserMembership?.is_archived ?? false;
  
  conversationJson.Members = conversationJson.Members.map(member => ({
    ...formatUserProfile(member),
    role: member.Member.role
  }));
  
  if (conversationJson.lastMessage) {
    conversationJson.lastMessage.sender = formatUserProfile(conversationJson.lastMessage.sender);
    conversationJson.lastMessage.status = getOverallMessageStatus(conversationJson.lastMessage, userId);
  }
  
  return conversationJson;
};

/**
 * Creates a new conversation (primarily for groups, as direct chats are created on first message).
 */
export const createConversation = async ({ creatorId, memberIds, type, title, joinPolicy }) => {
  const allMemberIds = [...new Set([creatorId, ...memberIds])];
  if (type === 'direct' && allMemberIds.length !== 2) throw new AppError('Direct conversations must have exactly two members.', 400);
  if (type === 'group' && !title) throw new AppError('Group conversations must have a title.', 400);

  return sequelize.transaction(async (t) => {
    if (type === 'direct') {
      const existing = await sequelize.query(`
        SELECT "conversation_id" FROM "conversation_members" cm JOIN conversations c ON c.id = cm.conversation_id
        WHERE c.type = 'direct' AND cm.user_id IN (:allMemberIds)
        GROUP BY "conversation_id" HAVING COUNT(DISTINCT cm.user_id) = 2;`,
        { replacements: { allMemberIds }, type: sequelize.QueryTypes.SELECT, transaction: t }
      );
      if (existing.length > 0) return getFullConversation(existing[0].conversation_id, creatorId, t);
    }
    
    const conversation = await Conversation.create({ type, title, createdBy: creatorId, joinPolicy }, { transaction: t });
    const members = allMemberIds.map(userId => ({ conversationId: conversation.id, userId, role: userId === creatorId ? 'admin' : 'member' }));
    await Member.bulkCreate(members, { transaction: t });
    
    if (type === 'group') {
      const creatorProfile = await Auth.findOne({ where: { enrollment_number: creatorId }, include: [Student, Employee], transaction: t });
      const creatorName = formatUserProfile(creatorProfile)?.name || 'Admin';
      await createAndBroadcastSystemMessage(conversation.id, `${creatorName} created the group "${title}".`, t);
    }
    
    return getFullConversation(conversation.id, creatorId, t);
  });
};

/**
 * Fetches all of a user's active (non-archived) conversations.
 */
export const getUserConversations = async (userId) => {
  const userMemberships = await Member.findAll({ where: { userId, isArchived: false }});
  const conversationIds = userMemberships.map(m => m.conversationId);
  if (conversationIds.length === 0) return [];
  
  const conversations = await Conversation.findAll({
    where: { id: { [Op.in]: conversationIds } },
    include: [
      {
        model: Message, as: 'lastMessage', include: [
          { model: Auth, as: 'sender', attributes: ['enrollment_number'], include: [Student, Employee]},
          { model: MessageStatus, as: 'statuses' }
        ]
      },
      {
        model: Auth, as: 'Members', attributes: ['enrollment_number'], include: [Student, Employee],
        through: { attributes: ['role'] }
      }
    ],
    order: [['lastMessageAt', 'DESC']],
  });
  
  const userMembershipMap = new Map(userMemberships.map(m => [m.conversationId, { unreadCount: m.unreadCount, isArchived: m.isArchived }]));

  return conversations.map(conv => {
    const convJson = conv.toJSON();
    convJson.Members = convJson.Members.map(member => ({
      ...formatUserProfile(member),
      role: member.Member.role,
    }));
    if (convJson.lastMessage) {
      convJson.lastMessage.sender = formatUserProfile(convJson.lastMessage.sender);
      convJson.lastMessage.status = getOverallMessageStatus(convJson.lastMessage, userId);
    }
    const membership = userMembershipMap.get(convJson.id);
    convJson.unreadCount = membership?.unreadCount ?? 0;
    convJson.isArchived = membership?.isArchived ?? false;
    return convJson;
  });
};

/**
 * Sets the archived state for a user in a specific conversation.
 */
export const archiveConversationForUser = async ({ conversationId, userId, isArchived }) => {
  await checkMembership(conversationId, userId);
  const [updateCount] = await Member.update({ isArchived }, { where: { conversationId, userId } });
  if (updateCount === 0) throw new AppError('Conversation archive state could not be updated.', 400);
  return { success: true };
};

/**
 * Deletes a conversation, but only if it has no messages.
 */
export const deleteEmptyConversation = async ({ conversationId, userId }) => {
  return sequelize.transaction(async (t) => {
    await checkMembership(conversationId, userId, t);
    const messageCount = await Message.count({ where: { conversationId }, transaction: t });
    if (messageCount > 0) {
      throw new AppError('Cannot delete a conversation with messages.', 400);
    }
    await Member.destroy({ where: { conversationId }, transaction: t });
    await Conversation.destroy({ where: { id: conversationId }, transaction: t });
    return { success: true };
  });
};

/**
 * @file Shared helper functions for the chat feature.
 * @author Your Name
 * @version 1.0.0
 * @description This module centralizes common utilities like data formatting,
 * status calculation, and permission checks to keep other services DRY.
 */

import models from '../../models/index.js';
import { AppError } from '../../utils/error.js';
import { io } from '../socket/chat.socket.js';

const { Member, Auth, Student, Employee, Message, Conversation } = models;

/**
 * Formats a user's Auth object into a consistent public profile.
 * @param {object} user - The Sequelize Auth model instance with included profiles.
 * @returns {object|null} A clean user profile object or null.
 */
export const formatUserProfile = (user) => {
  if (!user) return null;
  const profile = user.Student || user.Employee;
  return {
    enrollment_number: user.enrollment_number,
    name: profile?.name || 'Unknown User',
    photo_url: profile?.photo_url || null,
  };
};

/**
 * Calculates the overall status of a message from a specific user's perspective.
 * @param {object} message - A message object with its statuses included.
 * @param {string} userId - The ID of the user viewing the message.
 * @returns {string} The calculated status ('sent', 'delivered', or 'read').
 */
export const getOverallMessageStatus = (message, userId) => {
  if (message.senderId !== userId || !message.statuses) {
    return 'sent';
  }
  const recipientStatuses = message.statuses.filter(s => s.userId !== userId);
  if (recipientStatuses.length === 0) {
    return 'sent';
  }
  if (recipientStatuses.some(s => s.readAt !== null)) {
    return 'read';
  }
  if (recipientStatuses.every(s => s.deliveredAt !== null)) {
    return 'delivered';
  }
  return 'sent';
};

/**
 * Checks if a user is a member of a conversation. Throws a 403 error if not.
 * @param {string} conversationId - The ID of the conversation.
 * @param {string} userId - The ID of the user.
 * @param {object} [transaction] - An optional Sequelize transaction.
 * @returns {Promise<object>} The membership object if found.
 */
export const checkMembership = async (conversationId, userId, transaction) => {
  const member = await Member.findOne({
    where: { conversationId, userId },
    include: [{ model: Auth, include: [Student, Employee] }],
    transaction,
  });
  if (!member) {
    throw new AppError('Forbidden: You are not a member of this conversation.', 403);
  }
  return member;
};

/**
 * Checks if a user has admin permissions in a conversation. Throws a 403 error if not.
 * @param {string} conversationId - The ID of the conversation.
 * @param {string} userId - The ID of the user.
 * @param {object} [transaction] - An optional Sequelize transaction.
 * @returns {Promise<object>} The membership object if the user is an admin.
 */
export const checkAdminPermissions = async (conversationId, userId, transaction) => {
  const member = await checkMembership(conversationId, userId, transaction);
  if (member.role !== 'admin') {
    throw new AppError('Forbidden: You must be an admin to perform this action.', 403);
  }
  return member;
};

/**
 * Creates a system message and broadcasts it to the conversation room.
 * @param {string} conversationId - The ID of the conversation.
 * @param {string} body - The content of the system message.
 * @param {object} [transaction] - An optional Sequelize transaction.
 * @returns {Promise<object>} The created system message.
 */
export const createAndBroadcastSystemMessage = async (conversationId, body, transaction) => {
  const systemMessage = await Message.create({
    conversationId,
    senderId: null,
    body,
    type: 'system',
  }, { transaction });

  await Conversation.update({
    lastMessageId: systemMessage.id,
    lastMessageAt: systemMessage.createdAt,
  }, { where: { id: conversationId }, transaction });

  const broadcastPayload = systemMessage.toJSON();
  broadcastPayload.sender = { name: 'System' };

  if (io) {
    io.to(conversationId).emit('message_receive', broadcastPayload);
  }
  return systemMessage;
};

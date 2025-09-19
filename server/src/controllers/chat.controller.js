/**
 * @file Manages the request/response cycle for all chat-related API endpoints.
 * @author Your Name
 * @version 3.0.0
 * @description This controller has been refactored to use the new modular
 * service structure (conversation, message, group services).
 */

// --- Refactored Service Imports ---
import * as conversationService from '../services/chat/conversation.service.js';
import * as messageService from '../services/chat/message.service.js';
import * as groupService from '../services/chat/group.service.js';
import { broadcastConversationUpdate } from '../services/socket/chat.socket.js';

/**
 * A higher-order function to wrap async controllers and pass errors to the next middleware.
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// --- Conversation Controllers ---

export const createNewConversation = asyncHandler(async (req, res) => {
  const { type, title, memberIds, joinPolicy } = req.body;
  const creatorId = req.user.enrollmentNumber;

  const conversation = await conversationService.createConversation({
    creatorId,
    memberIds,
    type,
    title,
    joinPolicy,
  });
  
  // After creating a new group, broadcast the update to all its new members.
  await broadcastConversationUpdate(conversation);

  res.status(201).json({
    success: true,
    data: conversation,
  });
});

export const getMyConversations = asyncHandler(async (req, res) => {
  const userId = req.user.enrollmentNumber;
  const conversations = await conversationService.getUserConversations(userId);
  res.status(200).json({ success: true, data: conversations });
});

export const getConversationById = asyncHandler(async (req, res) => {
  const { conversationId } = req.params;
  const userId = req.user.enrollmentNumber;
  const conversation = await conversationService.getFullConversation(conversationId, userId);
  res.status(200).json({ success: true, data: conversation });
});

export const archiveConversation = asyncHandler(async (req, res) => {
  const { conversationId } = req.params;
  const userId = req.user.enrollmentNumber;
  await conversationService.archiveConversationForUser({ conversationId, userId, isArchived: true });
  res.status(200).json({ success: true, data: { message: 'Conversation archived.' } });
});

export const unarchiveConversation = asyncHandler(async (req, res) => {
  const { conversationId } = req.params;
  const userId = req.user.enrollmentNumber;
  await conversationService.archiveConversationForUser({ conversationId, userId, isArchived: false });
  res.status(200).json({ success: true, data: { message: 'Conversation un-archived.' } });
});

export const deleteEmptyConversation = asyncHandler(async (req, res) => {
    const { conversationId } = req.params;
    const userId = req.user.enrollmentNumber;
    await conversationService.deleteEmptyConversation({ conversationId, userId });
    res.status(200).json({ success: true, data: { message: 'Conversation deleted.' } });
});


// --- Message Controllers ---

export const getMessages = asyncHandler(async (req, res) => {
  const { conversationId } = req.params;
  const { limit, cursor } = req.query;
  const userId = req.user.enrollmentNumber;
  const result = await messageService.getMessagesForConversation({
    conversationId,
    userId,
    limit: parseInt(limit, 10) || 30,
    cursor: cursor ? parseInt(cursor, 10) : null,
  });
  res.status(200).json({ success: true, ...result });
});

export const searchMessages = asyncHandler(async (req, res) => {
    const { q, limit, offset } = req.query;
    const userId = req.user.enrollmentNumber;
    const results = await messageService.searchMessagesForUser({
      query: q,
      userId,
      limit: parseInt(limit, 10) || 20,
      offset: parseInt(offset, 10) || 0,
    });
    res.status(200).json({ success: true, data: results });
});


// --- Group Management Controllers ---

export const updateGroupDetails = asyncHandler(async (req, res) => {
  const { conversationId } = req.params;
  const actorId = req.user.enrollmentNumber;
  const details = req.body;
  const updatedConversation = await groupService.updateGroupDetails({ conversationId, actorId, details });
  await broadcastConversationUpdate(updatedConversation);
  res.status(200).json({ success: true, data: updatedConversation });
});

export const addMembers = asyncHandler(async (req, res) => {
  const { conversationId } = req.params;
  const { memberIds } = req.body;
  const actorId = req.user.enrollmentNumber;
  const updatedConversation = await groupService.addMembersToGroup({ conversationId, actorId, newMemberIds: memberIds });
  await broadcastConversationUpdate(updatedConversation);
  res.status(200).json({ success: true, data: updatedConversation });
});

export const removeMember = asyncHandler(async (req, res) => {
  const { conversationId, userId: memberToRemoveId } = req.params;
  const actorId = req.user.enrollmentNumber;
  const updatedConversation = await groupService.removeMemberFromGroup({ conversationId, actorId, memberToRemoveId });
  await broadcastConversationUpdate(updatedConversation);
  res.status(200).json({ success: true, data: updatedConversation });
});

export const updateUserRole = asyncHandler(async (req, res) => {
  const { conversationId, userId: targetUserId } = req.params;
  const { role } = req.body;
  const actorId = req.user.enrollmentNumber;
  const updatedConversation = await groupService.updateUserRoleInGroup({ conversationId, actorId, targetUserId, newRole: role });
  await broadcastConversationUpdate(updatedConversation);
  res.status(200).json({ success: true, data: updatedConversation });
});

export const leaveGroup = asyncHandler(async (req, res) => {
  const { conversationId } = req.params;
  const userId = req.user.enrollmentNumber;
  await groupService.leaveGroup({ conversationId, userId });
  // Note: Broadcasting for 'leaveGroup' is handled within the service itself
  // because it might need to promote a new admin.
  res.status(200).json({ success: true, data: { message: 'You have left the group.' } });
});


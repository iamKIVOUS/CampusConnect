/**
 * @file Contains the implementation logic for all Socket.IO event handlers.
 * @author Your Name
 * @version 1.0.0
 */

import Joi from 'joi';
import { logger } from '../../utils/logger.js';
// Import the newly refactored services
import * as messageService from '../chat/message.service.js';
import * as conversationService from '../chat/conversation.service.js';
import { checkMembership } from '../chat/chat.helpers.js';

// --- Joi Schemas for Validation ---
const sendMessageSchema = Joi.object({
  conversationId: Joi.string().required(),
  body: Joi.string().min(1).max(2000).required(),
  clientMsgId: Joi.string().required(),
  members: Joi.array().items(Joi.string()).when('conversationId', {
    is: 'new_direct_chat',
    then: Joi.required(),
  }),
  type: Joi.string().valid('direct').when('conversationId', {
    is: 'new_direct_chat',
    then: Joi.required(),
  }),
});

const uuidSchema = Joi.string().uuid().required();
const messagesReadSchema = Joi.object({ conversationId: Joi.string().uuid().required() });
const typingSchema = Joi.object({ conversationId: Joi.string().uuid().required() });

/**
 * A centralized function to broadcast personalized conversation updates to all members.
 * @param {object} io - The Socket.IO server instance.
 * @param {Map<string, string>} onlineUsers - The map of online users.
 * @param {object} conversation - The conversation object to broadcast.
 */
export const broadcastConversationUpdate = async (io, onlineUsers, conversation) => {
  if (!conversation || !conversation.Members || !conversation.id) {
    logger.warn('broadcastConversationUpdate called with invalid conversation object.');
    return;
  }
  await Promise.all(conversation.Members.map(async (member) => {
    const memberId = member.enrollment_number;
    const memberSocketId = onlineUsers.get(memberId);
    if (memberSocketId) {
      try {
        const personalizedConversation = await conversationService.getFullConversation(conversation.id, memberId);
        io.to(memberSocketId).emit('conversation_update', personalizedConversation);
      } catch (err) {
        logger.error(`Failed to broadcast personalized update to ${memberId} for conv ${conversation.id}: ${err.message}`);
      }
    }
  }));
};

// --- Event Handler Implementations ---

export const handleJoinConversation = async (socket, conversationId, callback) => {
  const { error } = uuidSchema.validate(conversationId);
  if (error) return callback?.({ success: false, error: 'Invalid ID.' });
  
  try {
    await checkMembership(conversationId, socket.user.enrollmentNumber);
    socket.join(conversationId);
    logger.info(`User ${socket.user.enrollmentNumber} joined room ${conversationId}`);
    callback?.({ success: true });
  } catch (err) {
    logger.warn(`Unauthorized attempt to join room ${conversationId} by user ${socket.user.enrollmentNumber}`);
    callback?.({ success: false, error: 'Forbidden' });
  }
};

export const handleSendMessage = async (io, socket, onlineUsers, data, callback) => {
  const { error, value } = sendMessageSchema.validate(data);
  if (error) {
    return callback?.({ success: false, error: `Invalid payload: ${error.details[0].message}` });
  }
  try {
    const { newMessage, updatedConversation, isNewConversation } = await messageService.createMessageAndConversationIfNeeded(
      { ...value, senderId: socket.user.enrollmentNumber },
      onlineUsers
    );

    if (isNewConversation) {
      updatedConversation.Members.forEach(member => {
        const memberSocketId = onlineUsers.get(member.enrollment_number);
        if (memberSocketId) {
          const memberSocket = io.sockets.sockets.get(memberSocketId);
          memberSocket?.join(updatedConversation.id);
        }
      });
    }

    io.to(updatedConversation.id).emit('message_receive', newMessage);
    await broadcastConversationUpdate(io, onlineUsers, updatedConversation);
    
    callback?.({ success: true, message: newMessage });
  } catch (err) {
    logger.error(`Error in message_send: ${err.message}`);
    callback?.({ success: false, error: err.message || 'An internal error occurred.' });
  }
};

export const handleMessagesRead = async (io, socket, onlineUsers, data, callback) => {
  const { error, value } = messagesReadSchema.validate(data);
  if (error) return callback?.({ success: false, error: 'Invalid payload.' });

  try {
    const { affectedMessages } = await messageService.markMessagesAsRead({
      conversationId: value.conversationId,
      userId: socket.user.enrollmentNumber,
    });
    
    const updatedConversation = await conversationService.getFullConversation(value.conversationId, socket.user.enrollmentNumber);
    await broadcastConversationUpdate(io, onlineUsers, updatedConversation);

    if (affectedMessages.length > 0) {
      const messageIds = affectedMessages.map(msg => msg.id);
      const senderIds = [...new Set(affectedMessages.map(msg => msg.senderId).filter(id => id))];
      
      senderIds.forEach(senderId => {
        const senderSocketId = onlineUsers.get(senderId);
        if (senderSocketId && senderId !== socket.user.enrollmentNumber) {
          io.to(senderSocketId).emit('message_status_update', {
            conversationId: value.conversationId,
            messageIds,
            status: 'read',
          });
        }
      });
    }
    
    callback?.({ success: true });
  } catch (err) {
    logger.error(`Error marking messages as read: ${err.message}`);
    callback?.({ success: false, error: 'Server error.' });
  }
};

export const handleTypingStart = (socket, data) => {
  const { error, value } = typingSchema.validate(data);
  if (error) return;
  socket.to(value.conversationId).emit('typing_start', {
    conversationId: value.conversationId,
    user: { enrollmentNumber: socket.user.enrollmentNumber, name: socket.user.name },
  });
};

export const handleTypingStop = (socket, data) => {
  const { error, value } = typingSchema.validate(data);
  if (error) return;
  socket.to(value.conversationId).emit('typing_stop', {
    conversationId: value.conversationId,
    user: { enrollmentNumber: socket.user.enrollmentNumber },
  });
};

export const handleDisconnect = (io, socket, onlineUsers) => {
  logger.info(`User disconnected: ${socket.user.enrollmentNumber}`);
  onlineUsers.delete(socket.user.enrollmentNumber);
};

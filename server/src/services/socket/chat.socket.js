/**
 * @file Initializes the Socket.IO server and orchestrates event handling.
 * @author Your Name
 * @version 1.0.0
 * @description This file sets up the server, handles authentication, manages
 * user presence, and registers the event handlers from socket.handlers.js.
 */

import jwt from 'jsonwebtoken';
import { logger } from '../../utils/logger.js';
import { getSessionByToken } from '../session.service.js';
import {
  handleJoinConversation,
  handleSendMessage,
  handleMessagesRead,
  handleTypingStart,
  handleTypingStop,
  handleDisconnect,
  broadcastConversationUpdate as broadcastUpdate
} from './socket.handlers.js';

// --- Global State ---
let io;
export const onlineUsers = new Map();

/**
 * Middleware to authenticate a socket connection using a JWT.
 */
const authenticateSocket = async (socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) return next(new Error('Authentication error: No token provided.'));
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const session = await getSessionByToken(token);
    if (!session) return next(new Error('Authentication error: Invalid session.'));
    
    socket.user = { 
      id: decoded.id, 
      enrollmentNumber: decoded.enrollment_number,
      name: session.name || decoded.enrollment_number
    };
    next();
  } catch (err) {
    return next(new Error('Authentication error: Invalid token.'));
  }
};

/**
 * Initializes the Socket.IO server and registers all event listeners.
 * @param {object} socketIo - The Socket.IO server instance.
 */
export const initializeSocket = (socketIo) => {
  io = socketIo;
  io.use(authenticateSocket);

  io.on('connection', (socket) => {
    logger.info(`User connected: ${socket.user.enrollmentNumber} (Socket ID: ${socket.id})`);
    
    onlineUsers.set(socket.user.enrollmentNumber, socket.id);
    socket.join(socket.user.enrollmentNumber);

    socket.on('join_conversation', (data, cb) => handleJoinConversation(socket, data, cb));
    socket.on('message_send', (data, cb) => handleSendMessage(io, socket, onlineUsers, data, cb));
    socket.on('messages_read', (data, cb) => handleMessagesRead(io, socket, onlineUsers, data, cb));
    socket.on('typing_start', (data) => handleTypingStart(socket, data));
    socket.on('typing_stop', (data) => handleTypingStop(socket, data));
    socket.on('disconnect', () => handleDisconnect(io, socket, onlineUsers));
  });
};

export { io };
export const broadcastConversationUpdate = (conversation) => {
  if (io) {
    broadcastUpdate(io, onlineUsers, conversation);
  }
};

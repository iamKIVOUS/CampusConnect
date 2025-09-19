/**
 * @file Defines all API routes for the chat feature.
 * @author Your Name
 * @version 2.1.0
 * @description This file uses Express Router and Celebrate to create a secure,
 * RESTful, and well-validated set of endpoints that map to the chat controller functions.
 */

import { Router } from 'express';
import { celebrate, Joi, Segments } from 'celebrate';
import * as chatController from '../controllers/chat.controller.js';

const router = Router();

// --- Reusable Joi Validation Schemas for DRY code ---

const conversationIdParam = {
  [Segments.PARAMS]: Joi.object({
    conversationId: Joi.string().uuid().required(),
  }),
};

const userIdParam = {
  [Segments.PARAMS]: Joi.object({
    conversationId: Joi.string().uuid().required(),
    userId: Joi.string().required(),
  }),
};


// --- Route Definitions ---

/**
 * @section Global Search
 */
router.get(
  '/search',
  celebrate({
    [Segments.QUERY]: Joi.object({
      q: Joi.string().min(1).max(100).required(),
      limit: Joi.number().integer().default(20),
      offset: Joi.number().integer().default(0),
    }),
  }),
  chatController.searchMessages
);


/**
 * @section Main Conversation Routes
 */
router.get(
  '/conversations',
  chatController.getMyConversations
);

router.post(
  '/conversations',
  celebrate({
    [Segments.BODY]: Joi.object({
      type: Joi.string().valid('direct', 'group').required(),
      title: Joi.string().min(1).max(100).when('type', { is: 'group', then: Joi.required() }),
      memberIds: Joi.array().items(Joi.string()).min(1).required(),
      joinPolicy: Joi.string().valid('admin_approval', 'open').optional(),
      messagingPolicy: Joi.string().valid('all_members', 'admins_only').optional(),
    }),
  }),
  chatController.createNewConversation
);


/**
 * @section Specific Conversation Routes
 */
router.get(
  '/conversations/:conversationId',
  celebrate(conversationIdParam),
  chatController.getConversationById
);

router.get(
  '/conversations/:conversationId/messages',
  celebrate({
    ...conversationIdParam,
    [Segments.QUERY]: Joi.object({
      limit: Joi.number().integer().min(1).max(50).default(30),
      cursor: Joi.number().integer().positive().optional(),
    }),
  }),
  chatController.getMessages
);

router.patch(
  '/conversations/:conversationId',
  celebrate({
    ...conversationIdParam,
    [Segments.BODY]: Joi.object({
      title: Joi.string().min(1).max(100).optional(),
      photoUrl: Joi.string().uri().allow(null, '').optional(),
      joinPolicy: Joi.string().valid('admin_approval', 'open').optional(),
      messagingPolicy: Joi.string().valid('all_members', 'admins_only').optional(),
    }).min(1),
  }),
  chatController.updateGroupDetails
);


/**
 * @section Archiving Routes
 */
router.post(
  '/conversations/:conversationId/archive',
  celebrate(conversationIdParam),
  chatController.archiveConversation
);

router.delete(
  '/conversations/:conversationId/archive',
  celebrate(conversationIdParam),
  chatController.unarchiveConversation
);


/**
 * @section Deletion Route
 */
// --- FIX ---
// Add a new DELETE route for empty conversations.
router.delete(
  '/conversations/:conversationId',
  celebrate(conversationIdParam),
  chatController.deleteEmptyConversation,
);


/**
 * @section Group Member Management
 */
router.post(
  '/conversations/:conversationId/members',
  celebrate({
    ...conversationIdParam,
    [Segments.BODY]: Joi.object({
      memberIds: Joi.array().items(Joi.string()).min(1).required(),
    }),
  }),
  chatController.addMembers
);

router.delete(
  '/conversations/:conversationId/members/:userId',
  celebrate(userIdParam),
  chatController.removeMember
);

router.patch(
  '/conversations/:conversationId/members/:userId/role',
  celebrate({
    ...userIdParam,
    [Segments.BODY]: Joi.object({
      role: Joi.string().valid('admin', 'member').required(),
    }),
  }),
  chatController.updateUserRole
);

router.post(
  '/conversations/:conversationId/leave',
  celebrate(conversationIdParam),
  chatController.leaveGroup
);


export default router;
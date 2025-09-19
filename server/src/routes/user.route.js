// server/src/routes/user.route.js
import { Router } from 'express';
import { celebrate, Joi, Segments } from 'celebrate';
import { searchUsersController , getUserProfileController } from '../controllers/user.controller.js';

const router = Router();

/**
 * GET /api/protected/users/search
 *
 * A protected route to search for users by name or enrollment number.
 * Requires a query parameter 'q'. Supports pagination with 'page' and 'limit'.
 */
router.get(
  '/search',
  celebrate({
    [Segments.QUERY]: Joi.object({
      q: Joi.string().min(1).max(50).required().trim(), // Search query is mandatory
      page: Joi.number().integer().min(1).default(1),
      limit: Joi.number().integer().min(1).max(100).default(20),
    }),
  }),
  searchUsersController
);
router.get(
  '/:enrollmentNumber',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      enrollmentNumber: Joi.string().required(),
    }),
  }),
  getUserProfileController
);
export default router;

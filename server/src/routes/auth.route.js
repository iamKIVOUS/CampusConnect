// server/src/routes/auth.route.js
import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { celebrate, Joi, Segments } from 'celebrate';
import * as authController from '../controllers/auth.controller.js';
import { authenticateToken } from '../middleware/auth.middleware.js';
import { logout } from '../controllers/logout.controller.js';

const router = Router();

// Rate limiter for login
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 5,
  message: { error: 'Too many login attempts, please try again later.' },
});

// Validate login payload
const loginValidation = celebrate({
  [Segments.BODY]: Joi.object({
    enrollment_number: Joi.string().alphanum().required(),
    password: Joi.string().required(),
    role: Joi.string().valid('student','employee').required(),
  }),
});

// Auth routes
router.post(
  '/login',
  loginLimiter,
  loginValidation,
  authController.login
);

router.post(
  '/logout',
  authenticateToken,
  logout
);

router.post(
  '/forgot-password',
  authController.forgotPassword
);

export default router;
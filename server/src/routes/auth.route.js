// server/src/routes/auth.route.js

import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { celebrate, Joi, Segments } from 'celebrate';
import * as authController from '../controllers/auth.controller.js';
import { logout } from '../controllers/logout.controller.js';
const router = Router();

// Rate limiter middleware to protect against brute-force login attempts
const loginRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 login requests per windowMs
  message: 'Too many login attempts. Please try again later.',
  standardHeaders: true,
  legacyHeaders: false
});

// Joi validation schema for login payload
const loginValidation = celebrate({
  [Segments.BODY]: Joi.object().keys({
    enrollment_number: Joi.string().required(),
    password: Joi.string().required(),
    role: Joi.string().valid('student', 'employee').required()
  })
});

// POST /login route
router.post(
  '/login',
  loginRateLimiter,       // Protect from brute force
  loginValidation,        // Validate input structure
  authController.login    // Login handler
);

// POST /forgot-password route (currently a stub)
router.post(
  '/forgot-password',
  authController.forgotPassword
);

router.post(
  '/logout',
  logout
);
export default router;

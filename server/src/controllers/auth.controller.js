// server/src/controllers/auth.controller.js

import * as authService from '../services/auth.service.js';
import { logger } from '../utils/logger.js';
import {
  InvalidCredentialsError,
  RoleNotSupportedError,
  ServerError
} from '../utils/error.js';

/**
 * POST /api/auth/login
 * Authenticates user and returns JWT + user info
 */
export const login = async (req, res, next) => {
  const { enrollment_number, password, role } = req.body;

  // Input validation
  if (!enrollment_number || !password || !role) {
    logger.warn('[LOGIN] Missing credentials or role.');
    return res.status(400).json({ error: 'Missing enrollment number, password, or role.' });
  }

  try {
    const { user, token } = await authService.login(enrollment_number, password, role);
    logger.info(`[LOGIN] Success for ${enrollment_number}`);
    return res.status(200).json({ token, user });
  } catch (err) {
    if (err instanceof InvalidCredentialsError) {
      logger.warn(`[LOGIN FAILED] ${err.message}`);
      return res.status(401).json({ error: 'Invalid enrollment, password, or role.' });
    }
    if (err instanceof RoleNotSupportedError) {
      logger.warn(`[LOGIN FAILED] ${err.message}`);
      return res.status(403).json({ error: 'Role not implemented.' });
    }
    // Unexpected errors
    logger.error(`[LOGIN ERROR] ${err.message}`, { stack: err.stack });
    return next(new ServerError());
  }
};

/**
 * POST /api/auth/forgot-password
 * Stub for password reset flow
 */
export const forgotPassword = (req, res, next) => {
  logger.info('[FORGOT PASSWORD] Endpoint hit.');
  return res.status(501).json({ message: 'Forgot password functionality is not yet implemented.' });
};

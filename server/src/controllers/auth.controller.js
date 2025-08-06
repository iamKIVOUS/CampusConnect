// server/src/controllers/auth.controller.js

import * as authService from '../services/auth.service.js';
import {
  InvalidCredentialsError,
  RoleNotSupportedError,
  ServerError,
} from '../utils/error.js';

/**
 * POST /api/auth/login
 * Authenticates user and returns JWT + user info
 */
export const login = async (req, res, next) => {
  const { enrollment_number, password, role } = req.body;

  // Input validation
  if (!enrollment_number || !password || !role) {
    req.logger?.warn('[LOGIN] Missing credentials or role.');
    return res.status(400).json({ error: 'Missing enrollment number, password, or role.' });
  }

  try {
    const ip = req.ip || req.headers['x-forwarded-for'] || req.connection.remoteAddress;

    const { user, routine, token } = await authService.login(
      enrollment_number,
      password,
      role,
      ip
    );

    req.logger?.info('[LOGIN] Success', {
      enrollment_number,
      ip,
      role,
      token,
    });

    return res.status(200).json({ token, user, routine });
  } catch (err) {
    if (err instanceof InvalidCredentialsError) {
      req.logger?.warn('[LOGIN FAILED] Invalid credentials.', { enrollment_number, role });
      return res.status(401).json({ error: err.message });
    }

    if (err instanceof RoleNotSupportedError) {
      req.logger?.warn('[LOGIN FAILED] Unsupported role.', { enrollment_number, role });
      return res.status(403).json({ error: err.message });
    }

    req.logger?.error('[LOGIN ERROR]', {
      message: err.message,
      stack: err.stack,
      enrollment_number,
      role,
    });

    return next(new ServerError());
  }
};

/**
 * POST /api/auth/forgot-password
 * Stub for password reset flow
 */
export const forgotPassword = (req, res) => {
  req.logger?.info('[FORGOT PASSWORD] Endpoint hit.', {
    ip: req.ip,
    time: new Date().toISOString(),
  });
  return res.status(501).json({ message: 'Forgot password functionality is not yet implemented.' });
};

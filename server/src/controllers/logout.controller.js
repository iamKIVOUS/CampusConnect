// server/src/controllers/logout.controller.js

import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import { logger } from '../utils/logger.js';
import { ServerError, InvalidCredentialsError } from '../utils/error.js';
import { getSessionByToken, removeSession } from '../services/session.service.js';

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET;

/**
 * POST /api/auth/logout
 * Revokes a bearer token by removing session from store (in-memory/Redis).
 */
export const logout = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      logger.warn(`[LOGOUT] Missing or malformed Authorization header. IP: ${req.ip}`);
      throw new InvalidCredentialsError('Authorization token missing or malformed.');
    }

    const token = authHeader.split(' ')[1];

    // 1) Verify token integrity (ignore expiration to get payload regardless)
    let payload;
    try {
      payload = jwt.verify(token, JWT_SECRET, { ignoreExpiration: true });
    } catch (err) {
      logger.warn(`[LOGOUT] Invalid token provided. IP: ${req.ip} Error: ${err.message}`);
      throw new InvalidCredentialsError('Invalid token.');
    }

    const enrollmentNumber = payload.enrollment_number || 'unknown';

    // 2) Check if session exists and IP matches
    const session = await getSessionByToken(token);
    if (!session) {
      logger.warn(`[LOGOUT] No active session found for token. IP: ${req.ip}`);
      throw new InvalidCredentialsError('Session not found or already logged out.');
    }

    if (session.ip !== req.ip) {
      logger.warn(`[LOGOUT] IP mismatch. Expected: ${session.ip}, Received: ${req.ip}`);
      throw new InvalidCredentialsError('Session IP mismatch.');
    }

    // 3) Invalidate session (remove from store)
    await removeSession(token);

    logger.info(`[LOGOUT] Success for ${enrollmentNumber} from IP ${req.ip}`);
    return res.status(200).json({ message: 'Logged out successfully.' });
  } catch (err) {
    if (err instanceof InvalidCredentialsError) {
      return res.status(401).json({ error: err.message });
    }

    // Unexpected
    logger.error(`[LOGOUT ERROR] ${err.message}`, { stack: err.stack });
    return next(new ServerError('Logout failed.'));
  }
};
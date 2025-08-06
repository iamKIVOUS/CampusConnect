// server/src/middleware/auth.middleware.js

import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import { logger } from '../utils/logger.js';
import { getSessionByToken } from '../services/session.service.js';
import { InvalidCredentialsError } from '../utils/error.js';

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET;

/**
 * JWT Authentication Middleware
 * Verifies token and session, attaches user info to req.user
 */
export const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>

  if (!token) {
    logger.warn(`Unauthorized access attempt: Missing token. IP: ${req.ip}`);
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    // Get session from store and verify IP matches
    const session = await getSessionByToken(token);
    if (!session) {
      logger.warn(`Session not found for token. IP: ${req.ip}`);
      return res.status(401).json({ error: 'Invalid session' });
    }

    if (session.ip !== req.ip) {
      logger.warn(
        `IP mismatch for token. Token IP: ${session.ip}, Request IP: ${req.ip}`
      );
      return res.status(401).json({ error: 'Session IP mismatch' });
    }

    req.user = {
      id: decoded.id,
      role: decoded.role,
      enrollmentNumber: decoded.enrollment_number,
    };

    next();
  } catch (err) {
    logger.warn(
      `Unauthorized access attempt: Invalid token. IP: ${req.ip}, Error: ${err.message}`
    );
    return res.status(401).json({ error: 'Unauthorized' });
  }
};

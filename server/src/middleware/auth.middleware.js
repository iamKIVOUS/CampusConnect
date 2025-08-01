// server/src/middleware/auth.middleware.js

import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import { logger } from '../utils/logger.js';    // <-- named import

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET;

/**
 * JWT Authentication Middleware
 * Verifies token and attaches user info to req.user
 */
export const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>

  if (!token) {
    logger.warn(`Unauthorized access attempt: Missing token. IP: ${req.ip}`);
    return res.status(401).json({ error: 'Unauthorized' });
  }

  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      logger.warn(
        `Unauthorized access attempt: Invalid token. IP: ${req.ip}, Error: ${err.message}`
      );
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // decoded.enrollment_number matches the key used when signing
    req.user = {
      id: decoded.id,
      role: decoded.role,
      enrollmentNumber: decoded.enrollment_number, // <-- aligned key name
    };

    next();
  });
};

// server/src/utils/logger.js

import winston from 'winston';
import path from 'path';
import fs from 'fs';

// Ensure logs directory exists
const logDir = path.resolve('logs');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir);
}

// Define custom log format
const logFormat = winston.format.printf(({ timestamp, level, message, stack }) => {
  return `[${timestamp}] ${level.toUpperCase()}: ${stack || message}`;
});

// Create Winston logger instance
const logger = winston.createLogger({
  level: 'info', // Change to 'debug' for more verbosity
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    logFormat
  ),
  transports: [
    // Log errors separately
    new winston.transports.File({
      filename: path.join(logDir, 'error.log'),
      level: 'error',
    }),
    // Combined log
    new winston.transports.File({
      filename: path.join(logDir, 'combined.log'),
    }),
  ],
});

// Add console transport in development
if (process.env.NODE_ENV !== 'production') {
  logger.add(
    new winston.transports.Console({
      format: winston.format.combine(winston.format.colorize(), logFormat),
    })
  );
}

// Export stream for morgan
export const stream = {
  write: (message) => logger.http(message.trim()),
};

export { logger };


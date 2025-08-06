// server/src/utils/error.js

/**
 * Custom Error Classes for consistent error handling
 */
export class AppError extends Error {
  constructor(message, statusCode = 500, expose = false) {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.expose = expose; // if true, message is safe to expose to client
    Error.captureStackTrace(this, this.constructor);
  }
}

export class InvalidCredentialsError extends AppError {
  constructor(message = 'Invalid credentials.') {
    super(message, 401, true);
  }
}

export class RoleNotSupportedError extends AppError {
  constructor(message = 'Role not supported.') {
    super(message, 403, true);
  }
}

export class ResourceNotFoundError extends AppError {
  constructor(message = 'Resource not found.') {
    super(message, 404, true);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized.') {
    super(message, 401, true);
  }
}

export class ServerError extends AppError {
  constructor(message = 'Internal server error.') {
    super(message, 500, false);
  }
}

/**
 * Global error handling middleware for Express
 */
export const errorHandler = (err, req, res, next) => {
  const statusCode = err.statusCode || 500;
  const message = err.expose ? err.message : 'Internal Server Error';

  // Use Winston logger if integrated, fallback to console
  const logger = req.logger || console;

  logger.error(`Error ${statusCode} on ${req.method} ${req.originalUrl}: ${message}`, {
    stack: err.stack,
    ip: req.ip,
    user: req.user || null
  });

  res.status(statusCode).json({
    success: false,
    error: message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
  });
};
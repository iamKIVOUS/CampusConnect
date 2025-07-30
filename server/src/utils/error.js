// server/src/utils/error.js

/**
 * Custom Error Classes for consistent error handling
 */
export class AppError extends Error {
  constructor(message, statusCode = 500, expose = false) {
    super(message);
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

  // Log full error for diagnostics
  // Use console.error here or integrate with your winston logger
  console.error(`Error ${statusCode} on ${req.method} ${req.originalUrl}:`, err);

  res.status(statusCode).json({
    error: message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
  });
};
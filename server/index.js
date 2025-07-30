// server/src/index.js

import express from 'express';
import dotenv from 'dotenv';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import xssClean from 'xss-clean';
import hpp from 'hpp';
import path from 'path';

// Load environment variables
dotenv.config();

// Import custom modules
import { logger, stream } from './src/utils/logger.js';
import { errorHandler } from './src/utils/error.js';
import authRoutes from './src/routes/auth.route.js';

const app = express();
const PORT = process.env.PORT || 5000;

// ---------------- Middleware ----------------

// Set security HTTP headers
app.use(helmet());

// Enable CORS with default config (you can customize origin if needed)
app.use(cors());

// Log requests
app.use(morgan('combined', { stream }));

// Limit repeated requests to public APIs
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 mins
  max: 100,
  message: 'Too many requests from this IP, please try again later.',
  handler: (req, res, next, options) => {
    logger.warn(`Rate limit exceeded from IP: ${req.ip}`);
    res.status(options.statusCode).json({ error: options.message });
  },
});
app.use('/api', limiter);

// Body parser
app.use(express.json({ limit: '10kb' })); // Limit body size

// Prevent XSS attacks
app.use(xssClean());

// Prevent HTTP param pollution
app.use(hpp());

// ---------------- Routes ----------------

// Health check
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Auth routes
app.use('/api/auth', authRoutes);

// ---------------- Error Handler ----------------

app.use(errorHandler);

// ---------------- Server Startup ----------------

app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode.`);
});

// ---------------- Process-wide Error Handling ----------------

// Handle unhandled promise rejections
process.on('unhandledRejection', (err) => {
  logger.error('Unhandled Rejection:', err);
  process.exit(1);
});

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  logger.error('Uncaught Exception:', err);
  process.exit(1);
});

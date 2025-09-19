// server/index.js

import express from 'express';
import dotenv from 'dotenv';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import hpp from 'hpp';
import http from 'http';
import { Server } from 'socket.io';
import { createClient } from 'redis';
import { createAdapter } from '@socket.io/redis-adapter';

dotenv.config();

import { syncDatabase } from './src/config/database.js';
import { logger, stream } from './src/utils/logger.js';
import { errorHandler } from './src/utils/error.js';
// --- REFACTORED IMPORT ---
// Update the path to point to the new socket orchestrator file.
import { initializeSocket } from './src/services/socket/chat.socket.js';
import { authenticateToken } from './src/middleware/auth.middleware.js';

// --- Route Imports ---
import authRoutes from './src/routes/auth.route.js';
import protectedRoutes from './src/routes/protected.route.js';

const app = express();
const PORT = process.env.PORT || 4000;
const httpServer = http.createServer(app);

// --- Production-Ready Socket.IO Setup ---
const io = new Server(httpServer, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
  transports: ['websocket', 'polling'],
});

// --- Redis Adapter Setup for Scalability ---
const pubClient = createClient({ url: process.env.REDIS_URL });
const subClient = pubClient.duplicate();

Promise.all([pubClient.connect(), subClient.connect()]).then(() => {
  io.adapter(createAdapter(pubClient, subClient));
  logger.info('Socket.IO Redis adapter connected successfully.');
  initializeSocket(io);
  startServer();
}).catch(err => {
  logger.error('Failed to connect to Redis:', err);
  process.exit(1);
});


async function startServer() {
  await syncDatabase();

  app.use((req, _res, next) => {
    req.logger = logger;
    next();
  });

  app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }));
  
  app.use(helmet());
  app.use(morgan('combined', { stream }));

  app.use(
    '/api',
    rateLimit({
      windowMs: 15 * 60 * 1000,
      max: 100,
      standardHeaders: true,
      legacyHeaders: false,
      handler: (req, res) => {
        req.logger.warn(`Rate limit exceeded: ${req.ip}`);
        res.status(429).json({ error: 'Too many requests, please try later.' });
      },
    })
  );

  app.use(express.json({ limit: '10kb' }));
  app.use(hpp());

  app.get('/api/health', (_req, res) =>
    res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() })
  );

  // Public routes (no token required)
  app.use('/api/auth', authRoutes);
  
  // The middleware is applied ONCE here, protecting all routes inside `protectedRoutes`.
  app.use('/api/protected', authenticateToken, protectedRoutes);

  // --- Global Error Handler ---
  app.use(errorHandler);

  httpServer.listen(PORT, () => {
    logger.info(`Server running on port ${PORT} (mode: ${process.env.NODE_ENV})`);
  });
}

// --- Graceful Shutdown Logic ---
const shutdown = (signal) => {
  logger.info(`${signal} received. Shutting down gracefully.`);
  httpServer.close(() => {
    logger.info('HTTP server closed.');
    io.close();
    Promise.all([pubClient.quit(), subClient.quit()]).then(() => {
      logger.info('Redis clients disconnected.');
      process.exit(0);
    });
  });
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', err => {
  logger.error('Unhandled Rejection:', err);
});
process.on('uncaughtException', err => {
  logger.error('Uncaught Exception:', err);
  process.exit(1);
});

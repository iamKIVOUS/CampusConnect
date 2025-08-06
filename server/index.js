// server/index.js

import express from 'express';
import dotenv from 'dotenv';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import hpp from 'hpp';

dotenv.config();

import { syncDatabase } from './src/config/database.js';
import { logger, stream } from './src/utils/logger.js';
import { errorHandler } from './src/utils/error.js';
import authRoutes from './src/routes/auth.route.js';
import protectedRoutes from './src/routes/protected.route.js';
import { authenticateToken } from './src/middleware/auth.middleware.js';

const app = express();
const PORT = process.env.PORT;

async function startServer() {
// 1. Ensure DB is ready
await syncDatabase();

// 2. Attach logger per request
app.use((req, _res, next) => {
req.logger = logger;
next();
});

// 3. Security & logging
app.use(helmet());
app.use(cors());
app.use(morgan('combined', { stream }));

// 4. Rate limiting on all /api
app.use(
'/api',
rateLimit({
windowMs: 15 * 60 * 1000,
max: 100,
handler: (req, res) => {
req.logger.warn(`Rate limit exceeded: ${req.ip}`);
res.status(429).json({ error: 'Too many requests, please try later.' });
},
})
);

// 5. Body parsing & HPP
app.use(express.json({ limit: '10kb' }));
app.use(hpp());

// 6. Public routes (no auth required)
app.get('/api/health', (_req, res) =>
res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() })
);
app.use('/api/auth', authRoutes);

// 7. Protected routes (require valid JWT)
app.use('/api/protected', authenticateToken, protectedRoutes);

// 8. Global error handler
app.use(errorHandler);

// 9. Start listening
app.listen(PORT, () => {
logger.info(`Server running on port ${PORT} (mode: ${process.env.NODE_ENV})`);
});
}

startServer().catch(err => {
logger.error('Startup failure:', err);
process.exit(1);
});

process.on('unhandledRejection', err => {
logger.error('Unhandled Rejection:', err);
process.exit(1);
});
process.on('uncaughtException', err => {
logger.error('Uncaught Exception:', err);
process.exit(1);
});

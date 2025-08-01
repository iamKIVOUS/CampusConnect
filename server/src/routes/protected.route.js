// server/src/routes/protected.route.js

import { Router } from 'express';
import { authenticateToken } from '../middleware/auth.middleware.js';

const router = Router();

// Example protected route - user dashboard
router.get('/dashboard', authenticateToken, (req, res) => {
  res.status(200).json({
    message: `Welcome ${req.user.enrollment_number}, this is your dashboard.`,
    user: req.user
  });
});

router.get('/profile', authenticateToken, (req, res) => {
  res.status(200).json({
    message: `This is your profile page`,
    user: req.user
  });
});

router.get('/chat', authenticateToken, (req, res) => {
  res.status(200).json({
    message: `This is your chat page`,
    user: req.user
  });
});
export default router;

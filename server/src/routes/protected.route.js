// server/src/routes/protected.route.js
import { Router } from 'express';
import { celebrate, Joi, Segments } from 'celebrate';
import chatRoutes from './chat.route.js';
import userRoutes from './user.route.js';
import * as routineController from '../controllers/routine.controller.js';
import * as attendanceController from '../controllers/attendance.controller.js';
const router = Router();

router.use('/chat', chatRoutes);
router.use('/users', userRoutes);

// Dashboard
router.get(
  '/dashboard',  
  (req, res) => res.json({
    success: true,
    message: `Welcome ${req.user.enrollmentNumber} to your dashboard`,
    user: req.user,
  })
);

// Profile
router.get(
  '/profile',
  (req, res) => res.json({
    success: true,
    user: req.user,
  })
);


// Get routine for authenticated user
router.get(
  '/routine',
  routineController.getRoutine
);

// Attendance routes

// Student summary
router.get(
  '/attendance', attendanceController.attendanceSummary
);

// Class list (professors)
router.get(
  '/attendance/class-list',
  celebrate({
    [Segments.QUERY]: Joi.object({
      course: Joi.string().required(),
      stream: Joi.string().required(),
      year: Joi.number().integer().min(1).max(4).required(),
      section: Joi.string().required()
    })
  }),
  attendanceController.classList
);

// Submit attendance
router.post(
  '/attendance/submit',
  celebrate({
    [Segments.BODY]: Joi.object({
      date: Joi.date().iso().required(),
      period: Joi.number().integer().min(1).max(6).required(),
      subject: Joi.string().required(),
      course: Joi.string().required(),
      stream: Joi.string().required(),
      year: Joi.number().integer().min(1).max(4).required(),
      section: Joi.string().required(),
      professor_id: Joi.string().required(),
      students: Joi.array().items(
        Joi.object({
          enrollment_number: Joi.string().required(),
          status: Joi.string().valid('present','absent').required()
        })
      ).required()
    })
  }),
  attendanceController.submitAttendanceHandler
);

export default router;
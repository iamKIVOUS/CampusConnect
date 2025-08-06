// server/src/controllers/routine.controller.js

import { getRoutineForStudent, getRoutineForEmployee } from '../services/routine.service.js';
import { Student } from '../models/student.model.js';
import { ServerError } from '../utils/error.js';

/**
 * GET /api/protected/routine
 * Returns routine entries for the authenticated user based on their role.
 */
export const getRoutine = async (req, res, next) => {
  try {
    const { enrollmentNumber, role } = req.user;
    let routine;

    if (role === 'student') {
      const student = await Student.findOne({
        where: { enrollment_number: enrollmentNumber },
        raw: true
      });

      if (!student) {
        return res.status(404).json({ success: false, error: 'Student record not found.' });
      }

      routine = await getRoutineForStudent(student);
    } else if (role === 'employee') {
      routine = await getRoutineForEmployee(enrollmentNumber);
    } else {
      return res.status(403).json({ success: false, error: 'Role not supported for routine.' });
    }

    return res.status(200).json({ success: true, routine });
  } catch (err) {
    req.logger?.error('[ROUTINE_ERROR]', { message: err.message, stack: err.stack });
    return next(new ServerError());
  }
};

import {
  getStudentAttendanceSummary,
  getClassList,
  submitAttendance
} from '../services/attendance.service.js';
import { UnauthorizedError, ServerError } from '../utils/error.js';

/**
 * GET /attendance
 * Student daily summary
 */
export async function attendanceSummary(req, res, next) {
  try {
    const { role, enrollmentNumber } = req.user;
    if (role !== 'student') throw new UnauthorizedError('Only students can view their attendance');

    const summary = await getStudentAttendanceSummary(enrollmentNumber);
    res.json({ success: true, summary });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /attendance/class-list
 * For professors: get list of students
 */
export async function classList(req, res, next) {
  try {
    const { role } = req.user;
    if (role !== 'employee') throw new UnauthorizedError('Only professors can access class list');

    const filters = req.query; // expect course, stream, year, section
    const list = await getClassList(filters);
    res.json({ success: true, students: list });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /attendance/submit
 */
export async function submitAttendanceHandler(req, res, next) {
  try {
    const { role } = req.user;
    if (role !== 'employee') throw new UnauthorizedError('Only professors can submit attendance');

    const { date, period, subject, course, stream, year, section, professor_id, students } = req.body;
    await submitAttendance(date, period, subject, { course, stream, year, section, professor_id }, students);
    res.status(201).json({ success: true, message: 'Attendance submitted' });
  } catch (err) {
    next(err);
  }
}
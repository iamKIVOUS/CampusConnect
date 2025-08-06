// server/src/services/auth.service.js

import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import validator from 'validator';
import { Auth } from '../models/auth.model.js';
import { Student } from '../models/student.model.js';
import { Employee } from '../models/employee.model.js';
import { RoutineSchedule } from '../models/routine.model.js';
import { logger } from '../utils/logger.js';
import { InvalidCredentialsError, ServerError } from '../utils/error.js';
import { Op } from 'sequelize';
import { saveSession } from './session.service.js';

const PEPPER = process.env.PEPPER || '';
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '1h';

export const login = async (enrollmentNumber, password, role, ip) => {
  try {
    // Validate inputs
    if (
      !enrollmentNumber ||
      !password ||
      !role ||
      !validator.isAlphanumeric(enrollmentNumber) ||
      !validator.isIn(role, ['student', 'employee'])
    ) {
      throw new InvalidCredentialsError('Invalid enrollment number, password, or role.');
    }

    logger.info(`[LOGIN_ATTEMPT] Enrollment: ${enrollmentNumber}, Role: ${role}, IP: ${ip}`);

    const authUser = await Auth.findOne({ where: { enrollment_number: enrollmentNumber } });

    if (!authUser) {
      throw new InvalidCredentialsError('User not found.');
    }

    const passwordMatches = await bcrypt.compare(password + PEPPER, authUser.password_hash);

    if (!passwordMatches) {
      throw new InvalidCredentialsError('Invalid password.');
    }

    if (authUser.role !== role) {
      throw new InvalidCredentialsError('Role mismatch.');
    }

    let user;
    let routine;

    if (role === 'student') {
      user = await Student.findOne({ where: { enrollment_number: enrollmentNumber }, raw: true });

      if (!user) {
        throw new ServerError('Student record not found.');
      }

      routine = await RoutineSchedule.findAll({
        where: {
          course: user.course,
          stream: user.stream,
          year: user.year,
          section: user.section,
        },
        raw: true,
      });
    } else if (role === 'employee') {
      user = await Employee.findOne({ where: { enrollment_number: enrollmentNumber }, raw: true });

      if (!user) {
        throw new ServerError('Employee record not found.');
      }

      routine = await RoutineSchedule.findAll({
        where: {
          [Op.or]: [
            { professor_id: enrollmentNumber },
            { substitute_id: enrollmentNumber },
          ],
        },
        raw: true,
      });
    }

    delete user.password_hash;

    const token = jwt.sign(
      { id: authUser.id, enrollment_number: authUser.enrollment_number, role: authUser.role },
      JWT_SECRET
      // { expiresIn: JWT_EXPIRES_IN }
    );
    await saveSession(token, {ip: ip});

    logger.info(`[LOGIN_SUCCESS] User ${enrollmentNumber} logged in successfully. ip: ${ip}`);

    return { user, routine, token };
  } catch (err) {
    if (err instanceof InvalidCredentialsError || err instanceof ServerError) {
      logger.warn(`[LOGIN_FAILED] ${err.message}`);
      throw err;
    }
    logger.error(`[LOGIN_ERROR] Unexpected error: ${err.message}`, err);
    throw new ServerError('Internal server error during login.');
  }
};

export const logout = async (token) => {
  try {
    // Optional: implement token blacklist here if required
    logger.info(`[LOGOUT] Token invalidated (not implemented).`);
    return;
  } catch (err) {
    logger.error(`[LOGOUT_ERROR] ${err.message}`, err);
    throw new ServerError('Logout failed.');
  }
};
// server/src/services/routine.service.js

import { RoutineSchedule } from '../models/routine.model.js';
import { Op } from 'sequelize';

/**
 * Get routine schedule for a student based on course, stream, year, and section.
 * @param {object} student - Student object
 * @returns {Promise<Array>} - List of routine entries
 */
export const getRoutineForStudent = async (student) => {
  return await RoutineSchedule.findAll({
    where: {
      course: student.course,
      stream: student.stream,
      year: student.year,
      section: student.section
    },
    order: [['day', 'ASC'], ['period', 'ASC']],
    raw: true
  });
};

/**
 * Get routine schedule for an employee (professor or substitute).
 * @param {string} enrollmentNumber - Employee enrollment number
 * @returns {Promise<Array>} - List of routine entries
 */
export const getRoutineForEmployee = async (enrollmentNumber) => {
  return await RoutineSchedule.findAll({
    where: {
      [Op.or]: [
        { professor_id: enrollmentNumber },
        { substitute_id: enrollmentNumber }
      ]
    },
    order: [['day', 'ASC'], ['period', 'ASC']],
    raw: true
  });
};

// server/src/services/user.service.js
import { QueryTypes } from 'sequelize';
import { sequelize } from '../config/connection.js';
import { AppError } from '../utils/error.js';

/**
 * Searches for users (both students and employees) by name or enrollment number.
 * The search is case-insensitive, paginated, and secure against SQL injection.
 *
 * @param {string} currentUserId - The enrollment number of the user performing the search, to exclude them from results.
 * @param {string} query - The search term.
 * @param {number} limit - The number of results to return per page.
 * @param {number} offset - The starting point for pagination.
 * @returns {Promise<Array>} A list of users matching the search criteria.
 */
export const searchUsers = async ({ currentUserId, query, limit, offset }) => {
  try {
    // This raw query is safe because we use replacements (`?`) to prevent SQL injection.
    // It efficiently combines results from both students and employees tables.
    const sqlQuery = `
      SELECT enrollment_number, name, photo_url, 'student' as type
      FROM student
      WHERE
        (name ILIKE ? OR enrollment_number ILIKE ?)
        AND enrollment_number != ?
      UNION ALL
      SELECT enrollment_number, name, photo_url, 'employee' as type
      FROM employee
      WHERE
        (name ILIKE ? OR enrollment_number ILIKE ?)
        AND enrollment_number != ?
      LIMIT ?
      OFFSET ?;
    `;

    const users = await sequelize.query(sqlQuery, {
      replacements: [
        `%${query}%`, `%${query}%`, currentUserId, // For students table
        `%${query}%`, `%${query}%`, currentUserId, // For employees table
        limit, offset
      ],
      type: QueryTypes.SELECT,
    });

    return users;
  } catch (error) {
    // Log the detailed error internally but send a generic message to the client.
    console.error('User search failed:', error);
    throw new AppError('An error occurred while searching for users.', 500);
  }
};
export const getUserProfile = async (enrollmentNumber) => {
  try {
    const authUser = await sequelize.models.Auth.findByPk(enrollmentNumber, {
      attributes: ['enrollment_number', 'email', 'phone', 'role'],
      include: [
        { model: sequelize.models.Student, required: false },
        { model: sequelize.models.Employee, required: false },
      ],
    });

    if (!authUser) {
      return null;
    }

    // Combine the auth data with the specific profile data (Student or Employee)
    const profile = authUser.Student || authUser.Employee;
    if (!profile) {
        // This case might happen if there's an auth record without a profile
        return authUser.toJSON();
    }

    return { ...authUser.toJSON(), ...profile.toJSON() };

  } catch (error) {
    console.error('Get user profile failed:', error);
    throw new AppError('An error occurred while fetching the user profile.', 500);
  }
};

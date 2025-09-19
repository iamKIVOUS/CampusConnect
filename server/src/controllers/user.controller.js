// server/src/controllers/user.controller.js
import { searchUsers, getUserProfile } from '../services/user.service.js';

/**
 * A higher-order function to wrap async controllers and pass errors to the next middleware.
 * This avoids repetitive try-catch blocks in each controller.
 * @param {Function} fn - The async controller function to wrap.
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

/**
 * Handles the user search request.
 * Parses query parameters, calls the search service, and returns the results.
 */
export const searchUsersController = asyncHandler(async (req, res) => {
  const { q, page = 1, limit = 20 } = req.query;
  const currentUserId = req.user.enrollmentNumber;

  // Sanitize and calculate pagination
  const pageNum = parseInt(page, 10);
  const limitNum = parseInt(limit, 10);
  const offset = (pageNum - 1) * limitNum;

  const users = await searchUsers({
    currentUserId,
    query: q,
    limit: limitNum,
    offset,
  });

  res.status(200).json({
    success: true,
    data: users,
    pagination: {
      page: pageNum,
      limit: limitNum,
      hasMore: users.length === limitNum, // If we got a full page, there might be more
    },
  });
});

/**
 * Handles the request to get a single user's profile.
 */
export const getUserProfileController = asyncHandler(async (req, res) => {
  const { enrollmentNumber } = req.params;
  const user = await getUserProfile(enrollmentNumber);

  if (!user) {
    // Using return here is fine as it's a specific "not found" case, not an unexpected error.
    return res.status(404).json({ success: false, message: 'User not found.' });
  }

  res.status(200).json({ success: true, data: user });
});

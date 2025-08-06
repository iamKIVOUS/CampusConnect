// server/src/services/session.service.js

// In-memory session store
const sessionStore = new Map();

/**
 * Save session with token as key.
 * @param {string} token - JWT token.
 * @param {object} sessionData - Session metadata (e.g., IP address).
 */
export const saveSession = async (token, sessionData) => {
  sessionStore.set(token, sessionData);
};

/**
 * Get session metadata by token.
 * @param {string} token
 * @returns {object|null}
 */
export const getSessionByToken = async (token) => {
  return sessionStore.get(token) || null;
};

/**
 * Remove session from store.
 * @param {string} token
 */
export const removeSession = async (token) => {
  sessionStore.delete(token);
};

/**
 * Clear all sessions (for testing or admin).
 */
export const clearAllSessions = async () => {
  sessionStore.clear();
};

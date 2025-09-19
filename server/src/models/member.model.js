/**
 * @file Defines the Sequelize model for the 'Member' table.
 * @author Your Name
 * @version 2.0.0
 */

import { DataTypes } from 'sequelize';
import { sequelize } from '../config/connection.js';

/**
 * Represents the membership of a user in a conversation.
 * This table acts as a many-to-many join table between the Auth (User) and
 * Conversation models, with additional fields to store user-specific state
 * for that conversation, such as role, unread count, and archive status.
 * @class Member
 */
export const Member = sequelize.define('Member', {
  /**
   * The ID of the conversation the user is a member of.
   * Forms a composite primary key with userId.
   * @type {UUID}
   */
  conversationId: {
    type: DataTypes.UUID,
    primaryKey: true,
    field: 'conversation_id',
  },
  /**
   * The ID of the user who is a member of the conversation.
   * Forms a composite primary key with conversationId.
   * @type {string}
   */
  userId: {
    type: DataTypes.STRING,
    primaryKey: true,
    field: 'user_id',
  },
  /**
   * The role of the user within the conversation, e.g., 'member' or 'admin'.
   * @type {string}
   */
  role: {
    type: DataTypes.STRING,
    allowNull: false,
    defaultValue: 'member',
    validate: {
      isIn: [['member', 'admin']],
    },
  },
  /**
   * (NEW & Denormalized) A server-managed counter for unread messages.
   * This is a critical performance optimization to avoid expensive database
   * queries when fetching the conversation list. The server will increment this
   * for each member when a new message is sent and reset it to zero when a
   * member reads the chat.
   * @type {number}
   */
  unreadCount: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
    field: 'unread_count',
  },
  /**
   * (NEW) A user-specific flag to "hide" or "archive" a conversation.
   * This provides a non-destructive way for users to manage their chat list,
   * allowing them to archive chats instead of permanently deleting or leaving them.
   * @type {boolean}
   */
  isArchived: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false,
    field: 'is_archived',
  },
}, {
  tableName: 'conversation_members',
  timestamps: true,
  createdAt: 'joined_at', // Semantic timestamp for when the member joined.
  updatedAt: false,       // Not needed for this join table.
});

/**
 * Defines the associations for the Member model.
 * @param {object} models - An object containing all initialized Sequelize models.
 */
Member.associate = (models) => {
  // A Member entry represents one user (Auth).
  // The targetKey is crucial for ensuring the foreign key 'userId' correctly
  // maps to the 'enrollment_number' field on the Auth model.
  Member.belongsTo(models.Auth, {
    foreignKey: 'userId',
    targetKey: 'enrollment_number',
  });

  // A Member entry belongs to one Conversation.
  Member.belongsTo(models.Conversation, {
    foreignKey: 'conversationId',
  });
};

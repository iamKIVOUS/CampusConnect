/**
 * @file Defines the Sequelize model for the 'Conversation' table.
 * @author Your Name
 * @version 2.0.0
 */

import { DataTypes } from 'sequelize';
import { sequelize } from '../config/connection.js';

/**
 * Represents a conversation (either direct or group) in the application.
 * This model includes denormalized fields for performance optimization, such as
 * tracking the last message directly on the conversation record.
 * @class Conversation
 */
export const Conversation = sequelize.define('Conversation', {
  /**
   * The unique identifier for the conversation.
   * @type {UUID}
   */
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  /**
   * The type of conversation, e.g., 'direct' for one-on-one or 'group'.
   * @type {string}
   */
  type: {
    type: DataTypes.STRING,
    allowNull: false,
    validate: {
      isIn: [['direct', 'group']],
    },
  },
  /**
   * The title of the conversation. Primarily used for group chats.
   * @type {?string}
   */
  title: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  /**
   * A URL to the conversation's photo or avatar. Primarily for group chats.
   * @type {?string}
   */
  photoUrl: {
    type: DataTypes.TEXT,
    allowNull: true,
    field: 'photo_url',
    validate: {
      isUrl: true,
    },
  },
  /**
   * Defines how users can join a group chat.
   * 'admin_approval': An admin must approve new members.
   * 'open': Anyone can join (future-proofing).
   * @type {string}
   */
  joinPolicy: {
    type: DataTypes.STRING,
    allowNull: false,
    defaultValue: 'admin_approval',
    field: 'join_policy',
    validate: {
      isIn: [['admin_approval', 'open']],
    },
  },
  /**
   * Defines who can send messages in the conversation.
   * 'all_members': Any member can send a message.
   * 'admins_only': Only members with an 'admin' role can send messages.
   * @type {string}
   */
  messagingPolicy: {
    type: DataTypes.STRING,
    allowNull: false,
    defaultValue: 'all_members',
    field: 'messaging_policy',
    validate: {
      isIn: [['all_members', 'admins_only']],
    },
  },
  /**
   * The unique ID of the user who created the conversation.
   * @type {string}
   */
  createdBy: {
    type: DataTypes.STRING,
    allowNull: false,
    field: 'created_by',
  },
  /**
   * (NEW & Denormalized) The ID of the most recent message in this conversation.
   * This is a performance optimization to avoid a subquery when fetching the conversation list.
   * @type {?number}
   */
  lastMessageId: {
    type: DataTypes.BIGINT,
    allowNull: true,
    field: 'last_message_id',
  },
  /**
   * (NEW & Denormalized) The timestamp of the most recent message.
   * This is a performance optimization for sorting conversations by recent activity.
   * @type {?Date}
   */
  lastMessageAt: {
    type: DataTypes.DATE,
    allowNull: true,
    field: 'last_message_at',
  },
}, {
  tableName: 'conversations',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
});

/**
 * Defines the associations for the Conversation model.
 * @param {object} models - An object containing all initialized Sequelize models.
 */
Conversation.associate = (models) => {
  // A Conversation can have multiple users (Auth) as members, connected via the Member table.
  Conversation.belongsToMany(models.Auth, {
    through: models.Member,
    foreignKey: 'conversationId',
    as: 'Members',
  });

  // A Conversation consists of many Messages.
  Conversation.hasMany(models.Message, {
    foreignKey: 'conversationId',
  });

  // Each Conversation is created by a single user (Auth).
  Conversation.belongsTo(models.Auth, {
    foreignKey: 'createdBy',
    as: 'creator',
  });

  // (NEW) Each Conversation has a reference to its last message for optimization.
  Conversation.belongsTo(models.Message, {
    foreignKey: 'lastMessageId',
    as: 'lastMessage',
  });
};

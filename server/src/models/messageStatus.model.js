/**
 * @file Defines the Sequelize model for the 'MessageStatus' table.
 * @author Your Name
 * @version 2.2.0
 */

import { DataTypes } from 'sequelize';
import { sequelize } from '../config/connection.js';

export const MessageStatus = sequelize.define('MessageStatus', {
  messageId: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    field: 'message_id',
  },
  userId: {
    type: DataTypes.STRING,
    primaryKey: true,
    field: 'user_id',
  },
  deliveredAt: {
    type: DataTypes.DATE,
    allowNull: true,
    field: 'delivered_at',
  },
  readAt: {
    type: DataTypes.DATE,
    allowNull: true,
    field: 'read_at',
  },
}, {
  tableName: 'message_status',
  timestamps: false,
});

MessageStatus.associate = (models) => {
  // A MessageStatus record belongs to one specific Message.
  MessageStatus.belongsTo(models.Message, {
    foreignKey: 'messageId',
    onDelete: 'CASCADE',
  });

  // A MessageStatus record belongs to one specific User (Auth).
  MessageStatus.belongsTo(models.Auth, {
    foreignKey: 'userId',
    targetKey: 'enrollment_number',
    onDelete: 'CASCADE',
  });

  // --- FIX ---
  // The redundant `belongsToMany` associations that were here have been
  // completely removed. Those relationships are correctly defined in their
  // respective source models (`message.model.js` and `auth.model.js`),
  // which resolves the duplicate alias error.
};


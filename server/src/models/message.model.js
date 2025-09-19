/**
 * @file Defines the Sequelize model for the 'Message' table.
 * @author Your Name
 * @version 2.1.0
 */

import { DataTypes } from 'sequelize';
import { sequelize } from '../config/connection.js';

export const Message = sequelize.define('Message', {
  id: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    autoIncrement: true,
  },
  conversationId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'conversation_id',
  },
  senderId: {
    type: DataTypes.STRING,
    allowNull: true,
    field: 'sender_id',
  },
  clientMsgId: {
    type: DataTypes.STRING,
    allowNull: true,
    field: 'client_msg_id',
  },
  body: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  attachmentUrl: {
    type: DataTypes.TEXT,
    allowNull: true,
    field: 'attachment_url',
    validate: {
      isUrl: true,
    },
  },
  attachmentType: {
    type: DataTypes.STRING,
    allowNull: true,
    field: 'attachment_type',
  },
  deleted: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  type: {
    type: DataTypes.ENUM('user', 'system'),
    allowNull: false,
    defaultValue: 'user',
  },
}, {
  tableName: 'messages',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'edited_at',
});

Message.associate = (models) => {
  Message.belongsTo(models.Conversation, {
    foreignKey: 'conversationId',
  });

  Message.belongsTo(models.Auth, {
    as: 'sender',
    foreignKey: 'senderId',
    targetKey: 'enrollment_number',
  });

  // --- FIX ---
  // This is the critical missing association.
  // It explicitly tells Sequelize that a single Message can have multiple
  // MessageStatus records linked to it.
  Message.hasMany(models.MessageStatus, {
    foreignKey: 'messageId',
    as: 'statuses',
    onDelete: 'CASCADE', // Ensures statuses are deleted when a message is.
  });

  Message.belongsToMany(models.Auth, {
    through: models.MessageStatus,
    foreignKey: 'messageId',
    as: 'statusRecipients',
  });
};

// server/src/models/auth.model.js

import { DataTypes } from 'sequelize';
import bcrypt from 'bcrypt';
import { sequelize } from '../config/connection.js';
import dotenv from 'dotenv';

// --- REMOVED: Imports for Student and Employee to break the circular dependency ---

dotenv.config();

const PEPPER = process.env.PEPPER || '';
const HASH_VERSION = 'v1';

export const Auth = sequelize.define('Auth', {
  // --- The model's fields remain exactly the same ---
  enrollment_number: {
    type: DataTypes.TEXT,
    primaryKey: true,
    allowNull: false,
    validate: { notEmpty: true },
  },
  password_hash: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: true,
      len: [60, 100],
    },
  },
  email: {
    type: DataTypes.TEXT,
    allowNull: false,
    unique: true,
    validate: { isEmail: true },
  },
  phone: {
    type: DataTypes.TEXT,
    allowNull: true,
    validate: {
      is: /^[0-9]{10,15}$/,
    },
  },
  role: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      isIn: [['student', 'employee']],
    },
  },
  password_hash_version: {
    type: DataTypes.STRING,
    allowNull: false,
    defaultValue: HASH_VERSION,
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
}, {
  // --- The model's options and hooks remain exactly the same ---
  tableName: 'auth',
  timestamps: false,
  underscored: true,
  hooks: {
    beforeCreate: async (user) => {
      if (user.password_hash) {
        const salted = user.password_hash + PEPPER;
        const salt = await bcrypt.genSalt(12);
        user.password_hash = await bcrypt.hash(salted, salt);
        user.password_hash_version = HASH_VERSION;
      }
    },
    beforeUpdate: async (user) => {
      if (user.changed('password_hash')) {
        const salted = user.password_hash + PEPPER;
        const salt = await bcrypt.genSalt(12);
        user.password_hash = await bcrypt.hash(salted, salt);
        user.password_hash_version = HASH_VERSION;
      }
    }
  }
});

// --- REMOVED: All association definitions from here ---

// --- NEW: A static method to define associations ---
// This method will be called by the central index.js after all models are loaded.
Auth.associate = (models) => {
  // An Auth record has one corresponding Student record.
  Auth.hasOne(models.Student, {
    foreignKey: 'enrollment_number',
    sourceKey: 'enrollment_number',
  });

  // An Auth record has one corresponding Employee record.
  Auth.hasOne(models.Employee, {
    foreignKey: 'enrollment_number',
    sourceKey: 'enrollment_number',
  });

  // A User (Auth) can be in many Conversations through the Member table.
  Auth.belongsToMany(models.Conversation, {
    through: models.Member,
    foreignKey: 'userId',
    as: 'Members'
  });
};

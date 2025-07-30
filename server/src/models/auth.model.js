// server/src/models/auth.model.js

import { DataTypes } from 'sequelize';
import bcrypt from 'bcrypt';
import { sequelize } from '../config/database.js';
import dotenv from 'dotenv';

dotenv.config();

const PEPPER = process.env.PEPPER || '';
const HASH_VERSION = 'v1';

export const Auth = sequelize.define('Auth', {
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

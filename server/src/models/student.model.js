import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';
import { Auth } from './auth.model.js';

const Student = sequelize.define('Student', {
  enrollment_number: {
    type: DataTypes.TEXT,
    primaryKey: true,
    allowNull: false,
    references: {
      model: Auth,
      key: 'enrollment_number',
    },
    onDelete: 'CASCADE',
    onUpdate: 'CASCADE',
  },
  registration_number: {
    type: DataTypes.TEXT,
    unique: true,
    allowNull: false,
    validate: {
      notEmpty: true,
      len: [15],
    },
  },
  name: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: true,
    },
  },
  course: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: true,
    },
  },
  year: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1,
      max: 5,
    },
  },
  stream: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: true,
    },
  },
  section: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: true,
      isIn: [['A', 'B', 'C', 'D']],
    },
  },
  roll_number: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: true,
      len: [1, 10],
    },
  },
  photo_url: {
    type: DataTypes.TEXT,
    allowNull: true,
    validate: {
      isUrl: true,
    },
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
  tableName: 'student',
  timestamps: false,
});

export { Student };

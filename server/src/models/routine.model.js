import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';
import { Auth } from './auth.model.js'; // Assuming enrollment_number exists in auth.model.js
import { Employee } from './employee.model.js';

const RoutineSchedule = sequelize.define('RoutineSchedule', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  course: {
    type: DataTypes.TEXT,
    allowNull: false,
  },
  stream: {
    type: DataTypes.TEXT,
    allowNull: false,
  },
  year: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1,
      max: 4,
    },
  },
  section: {
    type: DataTypes.TEXT,
    allowNull: false,
  },
  day: {
    type: DataTypes.ENUM('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'),
    allowNull: false,
  },
  period: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1,
      max: 8,
    },
  },
  subject: {
    type: DataTypes.TEXT,
    allowNull: false,
  },
  room: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: true,
    },
  },
  professor_id: {
    type: DataTypes.TEXT,
    allowNull: false,
    references: {
      model: Employee,
      key: 'enrollment_number',
    },
    onUpdate: 'CASCADE',
    onDelete: 'CASCADE',
  },
  substitute_id: {
    type: DataTypes.TEXT,
    allowNull: true,
    references: {
      model: Employee,
      key: 'enrollment_number',
    },
    onUpdate: 'CASCADE',
    onDelete: 'SET NULL',
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
  tableName: 'routine_schedule',
  timestamps: false,
});

export { RoutineSchedule };

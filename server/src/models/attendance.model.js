import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';
import { Student } from './student.model.js';
import { Employee } from './employee.model.js';

const Attendance = sequelize.define('Attendance', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  student_id: {
    type: DataTypes.TEXT,
    allowNull: false,
    references: {
      model: Student,
      key: 'enrollment_number',
    },
    onUpdate: 'CASCADE',
    onDelete: 'CASCADE',
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
  date: {
    type: DataTypes.DATEONLY,
    allowNull: false,
  },
  period: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1,
      max: 6,
    },
  },
  subject: {
    type: DataTypes.TEXT,
    allowNull: false,
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
  status: {
    type: DataTypes.ENUM('Present', 'Absent'),
    allowNull: false,
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
}, {
  tableName: 'attendance',
  timestamps: false,
});

export { Attendance };

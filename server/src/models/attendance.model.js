// server/src/models/attendance.model.js
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/connection.js';

// --- REMOVED: Imports for Student and Employee models ---

export const Attendance = sequelize.define('Attendance', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  student_id: {
    type: DataTypes.TEXT,
    allowNull: false,
    // --- REMOVED: references property ---
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
    // --- REMOVED: references property ---
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

// --- NEW: Static method for defining associations ---
Attendance.associate = (models) => {
  // An attendance record belongs to one student.
  Attendance.belongsTo(models.Student, {
    foreignKey: 'student_id',
    targetKey: 'enrollment_number',
    onUpdate: 'CASCADE',
    onDelete: 'CASCADE',
  });

  // An attendance record is taken by one professor (Employee).
  Attendance.belongsTo(models.Employee, {
    foreignKey: 'professor_id',
    targetKey: 'enrollment_number',
    onUpdate: 'CASCADE',
    onDelete: 'CASCADE',
  });
};

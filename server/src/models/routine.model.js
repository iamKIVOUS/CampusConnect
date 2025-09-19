// server/src/models/routine.model.js
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/connection.js';

// --- REMOVED: Imports for Employee model ---

export const RoutineSchedule = sequelize.define('RoutineSchedule', {
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
    // --- REMOVED: references property ---
  },
  substitute_id: {
    type: DataTypes.TEXT,
    allowNull: true,
    // --- REMOVED: references property ---
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

// --- NEW: Static method for defining associations ---
RoutineSchedule.associate = (models) => {
  // A routine schedule entry is taught by one professor.
  RoutineSchedule.belongsTo(models.Employee, {
    foreignKey: 'professor_id',
    targetKey: 'enrollment_number',
    onUpdate: 'CASCADE',
    onDelete: 'CASCADE', // Or SET NULL if you want to keep the record
  });

  // A routine schedule can have one substitute professor.
  RoutineSchedule.belongsTo(models.Employee, {
    foreignKey: 'substitute_id',
    targetKey: 'enrollment_number',
    as: 'substitute', // Alias to distinguish from the main professor
    onUpdate: 'CASCADE',
    onDelete: 'SET NULL',
  });
};

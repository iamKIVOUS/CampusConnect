import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';
import { Auth } from './auth.model.js'; // Make sure `auth.model.js` also uses ESM and exports `Auth`

const Employee = sequelize.define('Employee', {
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
  year_of_joining: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1990,
      max: new Date().getFullYear(),
    },
  },
  department: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      notEmpty: true,
    },
  },
  role: {
    type: DataTypes.TEXT,
    allowNull: false,
    validate: {
      isIn: [[
        'Professor', 'HOD', 'AHOD', 'Admin', 'Placement', 'Staff', 'Security'
      ]],
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
  tableName: 'employee',
  timestamps: false,
});

export { Employee };

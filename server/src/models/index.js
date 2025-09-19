// src/models/index.js

import { Sequelize } from 'sequelize';
import { sequelize } from '../config/connection.js';

// 1. Import all model definitions
import { Auth } from './auth.model.js';
import { Student } from './student.model.js';
import { Employee } from './employee.model.js';
import { Conversation } from './conversation.model.js';
import { Member } from './member.model.js';
import { Message } from './message.model.js';
import { MessageStatus } from './messageStatus.model.js';
import { Attendance } from './attendance.model.js';
import { RoutineSchedule } from './routine.model.js';

// 2. Create a 'db' object to hold everything
const db = {
  sequelize,
  Sequelize,
  Auth,
  Student,
  Employee,
  Conversation,
  Member,
  Message,
  MessageStatus,
  Attendance,
  RoutineSchedule,
};

// 3. Iterate over the models and create associations if the 'associate' method exists
// This is the crucial step that runs *after* all models have been defined,
// preventing any circular dependency errors.
Object.keys(db).forEach(modelName => {
  if (db[modelName].associate) {
    db[modelName].associate(db);
  }
});

// 4. Export the fully initialized db object
export default db;

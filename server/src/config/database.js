// server/src/config/database.js

import dotenv from 'dotenv';
import { Sequelize } from 'sequelize';
import chalk from 'chalk';

dotenv.config();

const isProduction = process.env.NODE_ENV === 'production';

const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DB_USER,
  process.env.DB_PASS,
  {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    dialect: 'postgres',
    logging: !isProduction ? console.log : false,

    pool: {
      max: 20,
      min: 5,
      acquire: 30000,
      idle: 10000,
    },

    dialectOptions: isProduction
      ? {
          ssl: {
            require: true,
            rejectUnauthorized: true,
          },
        }
      : {},

    retry: { max: 3 },

    define: {
      freezeTableName: true,
      underscored: true,
      timestamps: true,
    },
  }
);

const syncDatabase = async (options = {}) => {
  try {
    console.log(chalk.blue('[DB] Initializing model definitions...'));

    // Lazy import models (must use dynamic import with ESM if there's a cycle)
    await import('../models/auth.model.js');
    await import('../models/student.model.js');
    await import('../models/employee.model.js');

    console.log(chalk.yellow('[DB] Syncing database schema...'));

    await sequelize.sync({
      alter: true,
      ...options,
    });

    console.log(chalk.green('[DB] Database synchronized successfully.'));
  } catch (err) {
    console.error(chalk.red('[DB ERROR] Failed to sync database:'), err);
    process.exit(1);
  }
};

export { sequelize, syncDatabase };

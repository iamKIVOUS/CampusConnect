// src/config/connection.js
import dotenv from 'dotenv';
import { Sequelize } from 'sequelize';
import chalk from 'chalk';

dotenv.config();

const {
  DB_HOST,
  DB_PORT,
  DB_USER,
  DB_PASS,
  DB_NAME,
  NODE_ENV
} = process.env;

const isProduction = NODE_ENV === 'production';

// This file's only purpose is to create and export the Sequelize instance.
const sequelize = new Sequelize(DB_NAME, DB_USER, DB_PASS, {
  host: DB_HOST,
  port: DB_PORT,
  dialect: 'postgres',
  logging: isProduction ? false : (msg) => console.log(chalk.gray(msg)),
  pool: { max: 20, min: 5, acquire: 30000, idle: 10000 },
  dialectOptions: isProduction ? { ssl: { require: true, rejectUnauthorized: false } } : {},
  retry: { max: 3 },
  define: { freezeTableName: true, underscored: true, timestamps: true },
});

export { sequelize };

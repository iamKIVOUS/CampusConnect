import dotenv from 'dotenv';
import { Sequelize } from 'sequelize';
import { Client } from 'pg';
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

// 1️⃣ Ensure the database exists
async function ensureDatabaseExists() {
  // Connect to the default 'postgres' database
  const client = new Client({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASS,
    database: 'postgres'
  });
  await client.connect();
  try {
    // Create database if it doesn't exist
    await client.query(`CREATE DATABASE ${DB_NAME}`);
    console.log(chalk.green(`[DB] Created database "${DB_NAME}".`));
  } catch (err) {
    if (err.code === '42P04') {
      // 42P04 = duplicate_database, i.e. it already exists
      console.log(chalk.blue(`[DB] Database "${DB_NAME}" already exists.`));
    } else {
      console.error(chalk.red(`[DB ERROR] Could not create database: ${err.message}`));
      process.exit(1);
    }
  } finally {
    await client.end();
  }
}

// 2️⃣ Initialize Sequelize
const sequelize = new Sequelize(DB_NAME, DB_USER, DB_PASS, {
  host: DB_HOST,
  port: DB_PORT,
  dialect: 'postgres',
  logging: !isProduction ? console.log : false,
  pool: { max: 20, min: 5, acquire: 30000, idle: 10000 },
  dialectOptions: isProduction ? { ssl: { require: true, rejectUnauthorized: true } } : {},
  retry: { max: 3 },
  define: { freezeTableName: true, underscored: true, timestamps: true },
});

// 3️⃣ Full sync routine
export async function syncDatabase(options = {}) {
  await ensureDatabaseExists();

  console.log(chalk.blue('[DB] Loading models…'));
  // Dynamic import of your models
  await import('../models/auth.model.js');
  await import('../models/student.model.js');
  await import('../models/employee.model.js');

  console.log(chalk.yellow('[DB] Applying schema changes…'));
  await sequelize.sync({ alter: true, ...options });
  console.log(chalk.green('[DB] Database ready.'));
}

export { sequelize };

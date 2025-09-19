// src/config/database.js
import dotenv from 'dotenv';
import { Client } from 'pg';
import chalk from 'chalk';

// --- UPDATED: Import sequelize from the new connection file ---
import { sequelize } from './connection.js'; 
import '../models/index.js';

dotenv.config();

const {
  DB_HOST,
  DB_PORT,
  DB_USER,
  DB_PASS,
  DB_NAME
} = process.env;

// This function remains the same.
async function ensureDatabaseExists() {
  const client = new Client({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASS,
    database: 'postgres'
  });
  await client.connect();
  try {
    await client.query(`CREATE DATABASE ${DB_NAME}`);
    console.log(chalk.green(`[DB] Created database "${DB_NAME}".`));
  } catch (err) {
    if (err.code === '42P04') {
      console.log(chalk.blue(`[DB] Database "${DB_NAME}" already exists.`));
    } else {
      console.error(chalk.red(`[DB ERROR] Could not create database: ${err.message}`));
      process.exit(1);
    }
  } finally {
    await client.end();
  }
}

// The sync function now uses the imported sequelize instance.
export async function syncDatabase(options = {}) {
  await ensureDatabaseExists();
  console.log(chalk.yellow('[DB] Applying schema changes...'));
  await sequelize.sync({ alter: true, ...options });
  console.log(chalk.green('[DB] Database ready.'));
}

// hash-passwords.js

import bcrypt from 'bcrypt';
import dotenv from 'dotenv';

dotenv.config();

const PEPPER = process.env.PEPPER || '';
const SALT_ROUNDS = 12;

// Example list of users with plaintext passwords
const users = [
  { enrollment_number: 'STU001', plain_password: 'hash_pass_1' },
  { enrollment_number: 'STU002', plain_password: 'hash_pass_1' },
  { enrollment_number: 'EMP001', plain_password: 'hash_pass_1' },
  { enrollment_number: 'EMP002', plain_password: 'hash_pass_1' },
  { enrollment_number: 'EMP003', plain_password: 'hash_pass_1' },
  { enrollment_number: 'EMP004', plain_password: 'hash_pass_1' },
  { enrollment_number: 'EMP005', plain_password: 'hash_pass_1' },
  { enrollment_number: 'EMP006', plain_password: 'hash_pass_1' },
  { enrollment_number: 'EMP007', plain_password: 'hash_pass_1' },
];

async function hashPasswords(users) {
  const results = [];

  for (const user of users) {
    const salted = user.plain_password + PEPPER;
    const hash = await bcrypt.hash(salted, SALT_ROUNDS);

    results.push({
      enrollment_number: user.enrollment_number,
      hashed_password: hash,
    });
  }

  return results;
}

hashPasswords(users).then((result) => {
  console.log('Hashed Passwords:');
  console.table(result);
  process.exit(0);
}).catch((err) => {
  console.error('Error hashing passwords:', err);
  process.exit(1);
});

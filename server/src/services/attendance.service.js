import { Attendance } from '../models/attendance.model.js';
import { Student } from '../models/student.model.js';
import { Op } from 'sequelize';

/**
 * Normalize various date representations to 'YYYY-MM-DD'.
 * Accepts Date objects, DATEONLY strings ('YYYY-MM-DD'), and other date strings.
 * Returns null if value is falsy.
 * @param {Date|string|number} value
 * @returns {string|null}
 */
function toYMD(value) {
  if (!value) return null;

  // If it's already a Date instance
  if (value instanceof Date && !isNaN(value)) {
    return value.toISOString().slice(0, 10);
  }

  // If it's a string like 'YYYY-MM-DD' (Sequelize DATEONLY often returns this)
  if (typeof value === 'string') {
    const match = value.match(/^(\d{4}-\d{2}-\d{2})/);
    if (match) return match[1];
    // Fallback to Date parsing (may be timezone-sensitive)
    const d = new Date(value);
    if (!isNaN(d)) return d.toISOString().slice(0, 10);
  }

  // If it's a number (timestamp)
  if (typeof value === 'number') {
    const d = new Date(value);
    if (!isNaN(d)) return d.toISOString().slice(0, 10);
  }

  // Unknown format
  return null;
}

/**
 * Get daily attendance summary for a student.
 * Summary rule: a day is 'Present' if presentCount >= 5, otherwise 'Absent'.
 * @param {string} studentId
 * @returns {Promise<Array<{ date: string, status: 'Present' | 'Absent', presentCount: number, total: number }>>}
 */
export async function getStudentAttendanceSummary(studentId) {
  try {
    // Fetch all records for this student as model instances (no raw: true)
    const records = await Attendance.findAll({
      where: { student_id: studentId },
      order: [['date', 'ASC'], ['period', 'ASC']],
    });

    // Group by normalized date string
    const map = new Map();
    records.forEach(r => {
      const dateStr = toYMD(r.date);
      if (!dateStr) return; // skip malformed dates
      if (!map.has(dateStr)) map.set(dateStr, []);
      map.get(dateStr).push(r);
    });

    // Build summary array
    const summary = [];
    for (const [date, recs] of map.entries()) {
      const presentCount = recs.filter(rr => String(rr.status).toLowerCase() === 'present').length;
      const total = recs.length;
      summary.push({
        date,
        status: presentCount >= 5 ? 'Present' : 'Absent',
        presentCount,
        total,
      });
    }

    // Sort by date ascending
    summary.sort((a, b) => a.date.localeCompare(b.date));
    return summary;
  } catch (err) {
    // Re-throw with context for controller to handle
    throw new Error(`Failed to get attendance summary for ${studentId}: ${err.message}`);
  }
}

/**
 * Get class list for attendance by professor filters
 * @param {object} filters { course, stream, year, section }
 * @returns {Promise<Array<{ enrollment_number: string, name: string }>>}
 */
export async function getClassList(filters) {
  try {
    const students = await Student.findAll({
      where: {
        course: filters.course,
        stream: filters.stream,
        year: filters.year,
        section: filters.section
      },
      attributes: ['enrollment_number', 'name'],
      raw: true
    });
    return students;
  } catch (err) {
    throw new Error(`Failed to get class list: ${err.message}`);
  }
}

/**
 * Submit attendance for a list of students
 * @param {string} date - YYYY-MM-DD
 * @param {number} period
 * @param {string} subject
 * @param {object} meta - { course, stream, year, section, professor_id }
 * @param {Array<{ enrollment_number: string, status: 'Present'|'Absent'|'present'|'absent' }> } students
 */
export async function submitAttendance(date, period, subject, meta, students) {
  try {
    const entries = students.map(s => ({
      student_id: s.enrollment_number,
      course: meta.course,
      stream: meta.stream,
      year: meta.year,
      section: meta.section,
      date,          // expected as YYYY-MM-DD (DATEONLY)
      period,
      subject,
      professor_id: meta.professor_id,
      // normalize status to 'Present' or 'Absent'
      status: String(s.status).toLowerCase() === 'present' ? 'Present' : 'Absent'
    }));

    // Bulk insert
    await Attendance.bulkCreate(entries, { validate: true });
  } catch (err) {
    throw new Error(`Failed to submit attendance: ${err.message}`);
  }
}

import { Attendance } from '../models/attendance.model.js';
import { Student } from '../models/student.model.js';
import { Op } from 'sequelize';

/**
 * Get daily attendance summary for a student.
 * @param {string} studentId
 * @returns {Promise<Array<{ date: string, status: 'Present' | 'Absent' }>>}
 */
export async function getStudentAttendanceSummary(studentId) {
  // Fetch all records for this student
  const records = await Attendance.findAll({
    where: { student_id: studentId },
    raw: true
  });

  // Group by date
  const map = new Map();
  records.forEach(r => {
    const date = r.date.toISOString().slice(0, 10);
    if (!map.has(date)) map.set(date, []);
    map.get(date).push(r);
  });

  // Build summary
  const summary = [];
  for (const [date, recs] of map.entries()) {
    const presentCount = recs.filter(r => r.status === 'Present').length;
    summary.push({
      date,
      status: presentCount >= 5 ? 'Present' : 'Absent'
    });
  }
  // Sort by date
  summary.sort((a, b) => a.date.localeCompare(b.date));
  return summary;
}

/**
 * Get class list for attendance by professor filters
 * @param {object} filters { course, stream, year, section }
 * @returns {Promise<Array<{ enrollment_number: string, name: string }>>}
 */
export async function getClassList(filters) {
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
}

/**
 * Submit attendance for a list of students
 * @param {string} date - YYYY-MM-DD
 * @param {number} period
 * @param {string} subject
 * @param {object} meta - { course, stream, year, section, professor_id }
 * @param {Array<{ enrollment_number: string, status: 'Present'|'Absent' }> } students
 */
export async function submitAttendance(date, period, subject, meta, students) {
  const entries = students.map(s => ({
    student_id: s.enrollment_number,
    course: meta.course,
    stream: meta.stream,
    year: meta.year,
    section: meta.section,
    date,
    period,
    subject,
    professor_id: meta.professor_id,
    status: s.status === 'present' ? 'Present' : 'Absent'
  }));
  // Bulk insert (upsert could be added if needed)
  await Attendance.bulkCreate(entries);
}
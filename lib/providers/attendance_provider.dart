// lib/providers/attendance_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/attendance_service.dart'; // UPDATED: Import the new service

/// Simple model used by UI to represent a student and their selected attendance status.
class StudentAttendance {
  final String enrollmentNumber;
  final String name;
  String status; // 'Present' or 'Absent'

  StudentAttendance({
    required this.enrollmentNumber,
    required this.name,
    this.status = 'Absent',
  });
}

class AttendanceProvider extends ChangeNotifier {
  // UPDATED: Use the new dedicated service
  final AttendanceService _attendanceService = AttendanceService();

  Database? _db;
  bool _initialized = false;
  bool _loading = false;
  String? _error;
  List<StudentAttendance> _classList = [];

  bool get loading => _loading;
  String? get error => _error;
  List<StudentAttendance> get classList => List.unmodifiable(_classList);
  bool get isInitialized => _initialized;

  /// Initialize SQLite DB.
  Future<void> init() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();

    try {
      final dbPath = await _getDbPath();
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS class_list_cache (
              enrollment_number TEXT, name TEXT, course TEXT, stream TEXT,
              year INTEGER, section TEXT, cached_at TEXT,
              PRIMARY KEY (enrollment_number, course, stream, year, section)
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS attendance_submissions (
              submission_key TEXT PRIMARY KEY, date TEXT, period INTEGER, subject TEXT,
              course TEXT, stream TEXT, year INTEGER, section TEXT,
              professor_id TEXT, submitted_at TEXT
            )
          ''');
        },
      );
      _initialized = true;
      _error = null;
    } catch (e, st) {
      _error = 'DB initialization failed: $e';
      debugPrint('AttendanceProvider.init error: $e\n$st');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch class list from API (or cache).
  Future<List<StudentAttendance>> fetchClassList({
    required String course,
    required String stream,
    required int year,
    required String section,
    bool force = false,
  }) async {
    if (!_initialized) await init();

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (!force && _db != null) {
        final cachedRows = await _db!.query(
          'class_list_cache',
          where: 'course = ? AND stream = ? AND year = ? AND section = ?',
          whereArgs: [course, stream, year, section],
        );
        if (cachedRows.isNotEmpty) {
          _classList = cachedRows
              .map(
                (r) => StudentAttendance(
                  enrollmentNumber: r['enrollment_number']?.toString() ?? '',
                  name: r['name']?.toString() ?? '',
                ),
              )
              .toList();
          _loading = false;
          notifyListeners();
          return classList;
        }
      }

      // UPDATED: Calls the new AttendanceService
      final students = await _attendanceService.fetchClassList(
        course: course,
        stream: stream,
        year: year,
        section: section,
      );

      final parsed = students
          .map(
            (s) => StudentAttendance(
              enrollmentNumber: s['enrollment_number']?.toString() ?? '',
              name: s['name']?.toString() ?? '',
            ),
          )
          .toList();

      if (_db != null) {
        await _db!.transaction((txn) async {
          for (final student in parsed) {
            await txn.insert('class_list_cache', {
              'enrollment_number': student.enrollmentNumber,
              'name': student.name,
              'course': course,
              'stream': stream,
              'year': year,
              'section': section,
              'cached_at': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
      }

      _classList = parsed;
      return classList;
    } catch (e, st) {
      _error = 'Failed to load class list: $e';
      debugPrint('fetchClassList error: $e\n$st');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Submit attendance for the currently loaded class list.
  Future<Map<String, dynamic>> submitAttendance({
    required String date,
    required int period,
    required String subject,
    required String course,
    required String stream,
    required int year,
    required String section,
    required String professorId,
  }) async {
    if (!_initialized) await init();
    _loading = true;
    _error = null;
    notifyListeners();

    final key = _buildSubmissionKey(
      date: date,
      period: period,
      subject: subject,
      course: course,
      stream: stream,
      year: year,
      section: section,
    );

    try {
      if (await _submissionExists(key)) {
        throw Exception(
          'Attendance for this session has already been submitted.',
        );
      }

      final payload = {
        'date': date,
        'period': period,
        'subject': subject,
        'course': course,
        'stream': stream,
        'year': year,
        'section': section,
        'professor_id': professorId,
        'students': _classList
            .map(
              (s) => {
                'enrollment_number': s.enrollmentNumber,
                'status': s.status.toLowerCase(),
              },
            )
            .toList(),
      };

      // UPDATED: Calls the new AttendanceService
      final response = await _attendanceService.submitAttendance(payload);

      if (response['success'] == true && _db != null) {
        await _db!.insert('attendance_submissions', {
          'submission_key': key,
          'date': date,
          'period': period,
          'subject': subject,
          'course': course,
          'stream': stream,
          'year': year,
          'section': section,
          'professor_id': professorId,
          'submitted_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return response;
    } catch (e, st) {
      _error = 'Attendance submission failed: ${e.toString()}';
      debugPrint('submitAttendance error: $e\n$st');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch attendance summary from API.
  Future<List<dynamic>> fetchAttendanceSummary() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // UPDATED: Calls the new AttendanceService
      return await _attendanceService.fetchAttendanceSummary();
    } catch (e, st) {
      _error = 'Failed to fetch attendance summary: $e';
      debugPrint('fetchAttendanceSummary error: $e\n$st');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // --- Local Helper and State Management Methods (Unchanged) ---

  void setStatus(String enrollmentNumber, String status) {
    final index = _classList.indexWhere(
      (s) => s.enrollmentNumber == enrollmentNumber,
    );
    if (index != -1) {
      _classList[index].status = status;
      notifyListeners();
    }
  }

  Future<bool> isCurrentSessionSubmitted({
    required String date,
    required int period,
    required String subject,
    required String course,
    required String stream,
    required int year,
    required String section,
  }) async {
    final key = _buildSubmissionKey(
      date: date,
      period: period,
      subject: subject,
      course: course,
      stream: stream,
      year: year,
      section: section,
    );
    return await _submissionExists(key);
  }

  String _buildSubmissionKey({
    required String date,
    required int period,
    required String subject,
    required String course,
    required String stream,
    required int year,
    required String section,
  }) {
    return '$date|$period|$subject|$course|$stream|$year|$section';
  }

  Future<bool> _submissionExists(String key) async {
    if (_db == null) return false;
    final rows = await _db!.query(
      'attendance_submissions',
      where: 'submission_key = ?',
      whereArgs: [key],
    );
    return rows.isNotEmpty;
  }

  Future<String> _getDbPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'campus_connect.db');
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }
}

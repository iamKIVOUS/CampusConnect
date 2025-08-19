// lib/providers/attendance_provider.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../services/api_service.dart';

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

  Map<String, dynamic> toMap() => {
    'enrollment_number': enrollmentNumber,
    'name': name,
    'status': status,
  };

  factory StudentAttendance.fromMap(Map<String, dynamic> m) {
    return StudentAttendance(
      enrollmentNumber: m['enrollment_number']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      status: (m['status']?.toString() ?? 'Absent'),
    );
  }
}

class AttendanceProvider extends ChangeNotifier {
  Database? _db;
  bool _initialized = false;

  bool _loading = false;
  String? _error;

  // The currently loaded class list used in the AttendanceScreen
  List<StudentAttendance> _classList = [];

  bool get loading => _loading;
  String? get error => _error;
  List<StudentAttendance> get classList => List.unmodifiable(_classList);

  bool get isInitialized => _initialized;

  /// Initialize SQLite DB. Call once (e.g., app startup or when provider is created)
  Future<void> init() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();

    try {
      final dbPath = await _dbPath();
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          // cache of class lists
          await db.execute('''
          CREATE TABLE IF NOT EXISTS class_list_cache (
            enrollment_number TEXT,
            name TEXT,
            course TEXT,
            stream TEXT,
            year INTEGER,
            section TEXT,
            cached_at TEXT,
            PRIMARY KEY (enrollment_number, course, stream, year, section)
          )
        ''');

          // optional cache of attendance records (per-student)
          await db.execute('''
          CREATE TABLE IF NOT EXISTS attendance_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            period INTEGER,
            subject TEXT,
            course TEXT,
            stream TEXT,
            year INTEGER,
            section TEXT,
            enrollment_number TEXT,
            status TEXT,
            professor_id TEXT,
            created_at TEXT
          )
        ''');

          // record submissions to prevent re-submission
          await db.execute('''
          CREATE TABLE IF NOT EXISTS attendance_submissions (
            submission_key TEXT PRIMARY KEY,
            date TEXT,
            period INTEGER,
            subject TEXT,
            course TEXT,
            stream TEXT,
            year INTEGER,
            section TEXT,
            professor_id TEXT,
            submitted_at TEXT
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

  Future<String> _dbPath() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        return p.join(dir.path, 'univ_comm_app.db');
      } else {
        final dir = await getApplicationSupportDirectory();
        return p.join(dir.path, 'univ_comm_app.db');
      }
    } catch (e) {
      // fallback to default sqflite path
      return await getDatabasesPath().then(
        (base) => p.join(base, 'univ_comm_app.db'),
      );
    }
  }

  /// Build the submission key used to lock submissions for a (date,period,subject,course,stream,year,section)
  String _buildSubmissionKey({
    required String date, // 'YYYY-MM-DD'
    required int period,
    required String subject,
    required String course,
    required String stream,
    required int year,
    required String section,
  }) {
    return '$date|p$period|$subject|$course|$stream|y$year|s$section';
  }

  /// Check if submission exists in local DB
  Future<bool> _submissionExists(String key) async {
    if (_db == null) return false;
    final rows = await _db!.query(
      'attendance_submissions',
      columns: ['submission_key'],
      where: 'submission_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Fetch class list from API (or cache). Force refresh if force==true.
  /// The API accepts course, stream, year, section as query params.
  Future<List<StudentAttendance>> fetchClassList({
    required String course,
    required String stream,
    required int year,
    required String section,
    bool force = false,
  }) async {
    if (!_initialized) {
      await init();
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cache first if not forcing
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
                  status: 'Absent',
                ),
              )
              .toList();
          _loading = false;
          notifyListeners();
          return classList;
        }
      }

      // Fetch from API
      final students = await ApiService.instance.getClassList(
        course: course,
        stream: stream,
        year: year,
        section: section,
      );

      // Normalize list
      final parsed = <StudentAttendance>[];
      for (final s in students) {
        if (s == null) continue;
        if (s is Map) {
          final enroll =
              s['enrollment_number']?.toString() ??
              s['enroll']?.toString() ??
              '';
          final name = s['name']?.toString() ?? '';
          if (enroll.isEmpty) continue;
          parsed.add(
            StudentAttendance(
              enrollmentNumber: enroll,
              name: name,
              status: 'Absent',
            ),
          );
        } else {
          // unsupported format - skip
        }
      }

      // Cache the class list
      if (_db != null) {
        await _db!.transaction((txn) async {
          // Upsert: we will insert or replace rows for this class
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
      _loading = false;
      notifyListeners();
      return classList;
    } catch (e, st) {
      _error = 'Failed to load class list: $e';
      debugPrint('fetchClassList error: $e\n$st');
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle student's status between Present and Absent
  void toggleStatus(String enrollmentNumber) {
    final index = _classList.indexWhere(
      (s) => s.enrollmentNumber == enrollmentNumber,
    );
    if (index == -1) return;
    final cur = _classList[index];
    cur.status = (cur.status.toLowerCase() == 'present') ? 'Absent' : 'Present';
    notifyListeners();
  }

  /// Set a student's status explicitly
  void setStatus(String enrollmentNumber, String status) {
    final index = _classList.indexWhere(
      (s) => s.enrollmentNumber == enrollmentNumber,
    );
    if (index == -1) return;
    _classList[index].status = status;
    notifyListeners();
  }

  /// Returns true if the given session is already submitted
  Future<bool> isSubmittedSession({
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

  /// Submit attendance for the currently loaded _classList under the given session params.
  /// After successful submission, records a submission lock in local DB to prevent re-submission.
  Future<Map<String, dynamic>> submitAttendance({
    required String date, // 'YYYY-MM-DD'
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
      // check local lock
      final exists = await _submissionExists(key);
      if (exists) {
        _loading = false;
        notifyListeners();
        throw Exception(
          'Attendance for this session has already been submitted.',
        );
      }

      // Build payload expected by server
      final studentsPayload = _classList.map((s) {
        return {
          'enrollment_number': s.enrollmentNumber,
          'status': (s.status.toLowerCase() == 'present')
              ? 'present'
              : 'absent',
        };
      }).toList();

      final payload = {
        'date': date,
        'period': period,
        'subject': subject,
        'course': course,
        'stream': stream,
        'year': year,
        'section': section,
        'professor_id': professorId,
        'students': studentsPayload,
      };

      // Call API
      final response = await ApiService.instance.submitAttendance(payload);
      // Expect response like {"success":true,"message":"Attendance submitted"}
      final success = response['success'] == true;

      if (success) {
        // record submission locally
        if (_db != null) {
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

          // Optionally persist attendance per student into attendance_cache
          final batch = _db!.batch();
          for (final s in _classList) {
            batch.insert('attendance_cache', {
              'date': date,
              'period': period,
              'subject': subject,
              'course': course,
              'stream': stream,
              'year': year,
              'section': section,
              'enrollment_number': s.enrollmentNumber,
              'status': s.status,
              'professor_id': professorId,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
          await batch.commit(noResult: true);
        }
      }

      _loading = false;
      notifyListeners();
      return response;
    } catch (e, st) {
      _error = 'Attendance submission failed: ${e.toString()}';
      debugPrint('submitAttendance error: $e\n$st');
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Fetch attendance summary from API (used by student dashboard calendar)
  Future<List<dynamic>> fetchAttendanceSummary() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final summary = await ApiService.instance.fetchAttendanceSummary();
      _loading = false;
      notifyListeners();
      return summary;
    } catch (e, st) {
      _error = 'Failed to fetch attendance summary: $e';
      debugPrint('fetchAttendanceSummary error: $e\n$st');
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Check whether current session key equals stored submission key and report whether submission is locked
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

  /// Clear cached class list for a given class
  Future<void> clearClassListCache({
    required String course,
    required String stream,
    required int year,
    required String section,
  }) async {
    if (_db == null) return;
    await _db!.delete(
      'class_list_cache',
      where: 'course = ? AND stream = ? AND year = ? AND section = ?',
      whereArgs: [course, stream, year, section],
    );
    notifyListeners();
  }

  /// Completely clear all attendance caches (useful for debugging / dev)
  Future<void> clearAllAttendanceCache() async {
    if (_db == null) return;
    await _db!.delete('class_list_cache');
    await _db!.delete('attendance_cache');
    await _db!.delete('attendance_submissions');
    notifyListeners();
  }

  /// Close DB gracefully
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _initialized = false;
    }
  }

  @override
  void dispose() {
    // close db asynchronously (don't await here)
    close();
    super.dispose();
  }
}

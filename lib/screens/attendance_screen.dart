// lib/screens/attendance_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';

class AttendanceScreen extends StatefulWidget {
  /// periodData should contain at least:
  /// {
  ///   'course': 'B.Tech',
  ///   'stream': 'CSE',
  ///   'year': 3,
  ///   'section': 'A',
  ///   'period': 2,
  ///   'subject': 'Mathematics',
  ///   'professor_id': 'EMP001' // optional - fallback to current user
  /// }
  final Map<String, dynamic> periodData;

  const AttendanceScreen({super.key, required this.periodData});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late AttendanceProvider _provider;
  bool _loading = false; // local UI loading (fetching class list / submission)
  String? _error;
  bool _submitted = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // provider init & fetch will happen in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<AttendanceProvider>(context, listen: false);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ensure provider DB is initialized
      await _provider.init();

      // Extract class identifiers from periodData
      final course = widget.periodData['course']?.toString();
      final stream = widget.periodData['stream']?.toString();
      final year = widget.periodData['year'] is int
          ? widget.periodData['year'] as int
          : int.tryParse(widget.periodData['year']?.toString() ?? '') ?? 0;
      final section = widget.periodData['section']?.toString();

      if (course == null || stream == null || year == 0 || section == null) {
        throw Exception(
          'Missing class identifiers (course/stream/year/section).',
        );
      }

      // Fetch class list (from cache or API)
      await _provider.fetchClassList(
        course: course,
        stream: stream,
        year: year,
        section: section,
        force: false,
      );

      // Check if the session has already been submitted
      final dateStr = _formatDate(_selectedDate);
      final period = widget.periodData['period'] is int
          ? widget.periodData['period'] as int
          : int.tryParse(widget.periodData['period']?.toString() ?? '') ?? 0;
      final subject = widget.periodData['subject']?.toString() ?? '';

      if (period == 0 || subject.isEmpty) {
        // allowed, but will warn user later
      } else {
        final submitted = await _provider.isCurrentSessionSubmitted(
          date: dateStr,
          period: period,
          subject: subject,
          course: course,
          stream: stream,
          year: year,
          section: section,
        );
        _submitted = submitted;
      }
      setState(() {
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('AttendanceScreen init error: $e\n$st');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime d) {
    // Format YYYY-MM-DD
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });

      // re-check submission lock for new date
      await _checkSubmissionLock();
    }
  }

  Future<void> _checkSubmissionLock() async {
    setState(() => _loading = true);
    try {
      final course = widget.periodData['course']?.toString() ?? '';
      final stream = widget.periodData['stream']?.toString() ?? '';
      final year = widget.periodData['year'] is int
          ? widget.periodData['year'] as int
          : int.tryParse(widget.periodData['year']?.toString() ?? '') ?? 0;
      final section = widget.periodData['section']?.toString() ?? '';
      final period = widget.periodData['period'] is int
          ? widget.periodData['period'] as int
          : int.tryParse(widget.periodData['period']?.toString() ?? '') ?? 0;
      final subject = widget.periodData['subject']?.toString() ?? '';

      if (course.isEmpty ||
          stream.isEmpty ||
          year == 0 ||
          section.isEmpty ||
          period == 0 ||
          subject.isEmpty) {
        // can't check properly
        setState(() {
          _submitted = false;
          _loading = false;
        });
        return;
      }

      final submitted = await _provider.isCurrentSessionSubmitted(
        date: _formatDate(_selectedDate),
        period: period,
        subject: subject,
        course: course,
        stream: stream,
        year: year,
        section: section,
      );
      setState(() {
        _submitted = submitted;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error checking submission lock: $e');
      setState(() {
        _submitted = false;
        _loading = false;
      });
    }
  }

  Future<void> _submitAttendance() async {
    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit attendance'),
        content: const Text(
          'Are you sure you want to submit attendance for this session? This cannot be edited later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final course = widget.periodData['course']?.toString() ?? '';
      final stream = widget.periodData['stream']?.toString() ?? '';
      final year = widget.periodData['year'] is int
          ? widget.periodData['year'] as int
          : int.tryParse(widget.periodData['year']?.toString() ?? '') ?? 0;
      final section = widget.periodData['section']?.toString() ?? '';
      final period = widget.periodData['period'] is int
          ? widget.periodData['period'] as int
          : int.tryParse(widget.periodData['period']?.toString() ?? '') ?? 0;
      final subject = widget.periodData['subject']?.toString() ?? '';
      final professorId =
          widget.periodData['professor_id']?.toString() ??
          Provider.of<AuthProvider>(
            context,
            listen: false,
          ).user?['enrollment_number']?.toString() ??
          '';

      if (course.isEmpty ||
          stream.isEmpty ||
          year == 0 ||
          section.isEmpty ||
          period == 0 ||
          subject.isEmpty) {
        throw Exception(
          'Missing session metadata (course/stream/year/section/period/subject).',
        );
      }

      if (_submitted) {
        throw Exception(
          'Attendance for this session has already been submitted.',
        );
      }

      // Use provider's submitAttendance which reads provider.classList for students' statuses
      final response = await _provider.submitAttendance(
        date: _formatDate(_selectedDate),
        period: period,
        subject: subject,
        course: course,
        stream: stream,
        year: year,
        section: section,
        professorId: professorId,
      );

      // Expected response contains success flag
      final success = response['success'] == true;
      if (!mounted) return;

      if (success) {
        setState(() {
          _submitted = true;
          _loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance submitted successfully')),
        );
      } else {
        setState(() {
          _loading = false;
        });
        final message =
            response['message']?.toString() ?? 'Unknown response from server';
        throw Exception(message);
      }
    } catch (e, st) {
      debugPrint('Submit error: $e\n$st');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take Attendance')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Consumer<AttendanceProvider>(
            builder: (context, provider, child) {
              final classList = provider.classList;
              if (_loading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_error != null) {
                return Center(child: Text('Error: $_error'));
              }

              if (classList.isEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No students available for this class.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _initialize,
                      child: const Text('Reload'),
                    ),
                  ],
                );
              }

              final subject = widget.periodData['subject']?.toString() ?? '';
              final period = widget.periodData['period']?.toString() ?? '';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // session meta
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject.isNotEmpty ? subject : 'Subject',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text('Period: $period'),
                                const SizedBox(height: 6),
                                Text(
                                  'Class: ${widget.periodData['course'] ?? ''} • ${widget.periodData['stream'] ?? ''} • Year ${widget.periodData['year'] ?? ''} • Sec ${widget.periodData['section'] ?? ''}',
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                ),
                                label: Text(_formatDate(_selectedDate)),
                              ),
                              const SizedBox(height: 6),
                              if (_submitted)
                                Chip(
                                  label: Text(
                                    'Submitted',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // list header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      'Class List',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),

                  Expanded(
                    child: ListView.separated(
                      itemCount: classList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final stu = classList[index];
                        final present = stu.status.toLowerCase() == 'present';
                        return ListTile(
                          title: Text(stu.name),
                          subtitle: Text(stu.enrollmentNumber),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(present ? 'Present' : 'Absent'),
                              const SizedBox(width: 8),
                              Switch(
                                value: present,
                                onChanged: _submitted
                                    ? null
                                    : (v) {
                                        if (v) {
                                          provider.setStatus(
                                            stu.enrollmentNumber,
                                            'Present',
                                          );
                                        } else {
                                          provider.setStatus(
                                            stu.enrollmentNumber,
                                            'Absent',
                                          );
                                        }
                                      },
                              ),
                            ],
                          ),
                          onTap: _submitted
                              ? null
                              : () {
                                  // toggle on tap as well
                                  if (stu.status.toLowerCase() == 'present') {
                                    provider.setStatus(
                                      stu.enrollmentNumber,
                                      'Absent',
                                    );
                                  } else {
                                    provider.setStatus(
                                      stu.enrollmentNumber,
                                      'Present',
                                    );
                                  }
                                },
                        );
                      },
                    ),
                  ),

                  // bottom action row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_submitted || provider.loading)
                                ? null
                                : _submitAttendance,
                            child: provider.loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _submitted
                                        ? 'Submitted'
                                        : 'Submit Attendance',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// lib/views/attendance_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/attendance_calendar.dart';
import '../widgets/attendance_counter.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({super.key});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  // Map of date -> status ('present', 'absent')
  Map<DateTime, String> _dateStatus = {};
  bool _loading = true;
  String? _error;

  // currently displayed month (first day)
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    try {
      // Ensure provider DB initialized (safe to call multiple times)
      if (!provider.isInitialized) {
        await provider.init();
      }
      final raw = await provider.fetchAttendanceSummary();
      final parsed = _parseSummary(raw);
      setState(() {
        _dateStatus = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load attendance: ${e.toString()}';
        _loading = false;
      });
    }
  }

  /// Try to accept a few reasonable response shapes:
  /// - List of { "date": "YYYY-MM-DD", "status": "present" }
  /// - Map-like items where key is date and value is status
  /// - List of strings (dates) -> treat as present (best-effort)
  Map<DateTime, String> _parseSummary(dynamic raw) {
    final out = <DateTime, String>{};
    if (raw == null) return out;
    try {
      if (raw is List) {
        for (final item in raw) {
          if (item == null) continue;
          if (item is Map) {
            // common API shape
            String? ds;
            if (item.containsKey('date')) {
              ds = item['date']?.toString();
            } else if (item.containsKey('day')) {
              ds = item['day']?.toString();
            }
            String status = 'present';
            if (item.containsKey('status')) {
              status = item['status']?.toString().toLowerCase() ?? 'present';
            } else if (item.containsKey('type')) {
              status = item['type']?.toString().toLowerCase() ?? 'present';
            }
            if (ds != null) {
              final dt = DateTime.tryParse(ds);
              if (dt != null) {
                out[_stripTime(dt)] = (status.contains('abs')
                    ? 'absent'
                    : 'present');
              }
            } else {
              // maybe map has keys that are dates
              item.forEach((k, v) {
                final key = k?.toString();
                final val = v?.toString();
                final dt = DateTime.tryParse(key ?? '');
                if (dt != null) {
                  out[_stripTime(
                    dt,
                  )] = (val?.toLowerCase().contains('abs') ?? false)
                      ? 'absent'
                      : 'present';
                }
              });
            }
          } else if (item is String) {
            final dt = DateTime.tryParse(item);
            if (dt != null) out[_stripTime(dt)] = 'present';
          }
        }
      } else if (raw is Map) {
        // map of date->status
        raw.forEach((k, v) {
          final key = k?.toString();
          final val = v?.toString();
          final dt = DateTime.tryParse(key ?? '');
          if (dt != null) {
            out[_stripTime(dt)] = (val?.toLowerCase().contains('abs') ?? false)
                ? 'absent'
                : 'present';
          }
        });
      }
    } catch (e) {
      // parsing failed; return what we have
    }
    return out;
  }

  DateTime _stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  // Count present/absent in visible month
  Map<String, int> _countsForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(
      month.year,
      month.month + 1,
      1,
    ).subtract(const Duration(days: 1));
    int present = 0;
    int absent = 0;
    _dateStatus.forEach((k, v) {
      if (!k.isBefore(start) && !k.isAfter(end)) {
        if (v.toLowerCase().contains('abs')) {
          absent++;
        } else {
          present++;
        }
      }
    });
    return {'present': present, 'absent': absent};
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadSummary,
            ),
          ],
        ),
      );
    }

    final counts = _countsForMonth(_visibleMonth);
    final monthLabel =
        "${_visibleMonth.year} - ${_visibleMonth.month.toString().padLeft(2, '0')}";

    return Column(
      children: [
        // Counters row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: AttendanceCounter(
                  label: 'Present',
                  count: counts['present'] ?? 0,
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AttendanceCounter(
                  label: 'Absent',
                  count: counts['absent'] ?? 0,
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),

        // Month selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _prevMonth,
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
                tooltip: 'Next month',
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Calendar
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: AttendanceCalendar(
              month: _visibleMonth,
              dateStatus: _dateStatus,
              onDayTap: (date, status) {
                // show a snackbar with status (or expand to show details)
                final d =
                    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                final msg = status == null
                    ? "$d — No data"
                    : "$d — ${status[0].toUpperCase()}${status.substring(1)}";
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

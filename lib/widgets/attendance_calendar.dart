// lib/widgets/attendance_calendar.dart
import 'package:flutter/material.dart';

typedef DayTapCallback = void Function(DateTime date, String? status);

class AttendanceCalendar extends StatelessWidget {
  /// month must point to first day of month (we normalize inside)
  final DateTime month;
  final Map<DateTime, String> dateStatus;
  final DayTapCallback? onDayTap;

  const AttendanceCalendar({
    super.key,
    required this.month,
    this.dateStatus = const {},
    this.onDayTap,
  });

  DateTime _startOfMonth(DateTime m) => DateTime(m.year, m.month, 1);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final first = _startOfMonth(month);
    final year = first.year;
    final mon = first.month;
    final daysInMonth = DateTime(year, mon + 1, 0).day;

    // weekday index: DateTime.weekday => Monday=1 .. Sunday=7
    final leadingEmpty =
        (first.weekday - 1); // number of empty slots before day 1 (Mon-based)

    final today = DateTime.now();

    // Build grid cells
    final cells = <Widget>[];

    // Weekday labels (Mon..Sun)
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Weekdays header
    final header = Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
          .toList(),
    );

    // Generate cells
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox()); // empty
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final dt = DateTime(year, mon, day);
      final key = DateTime(dt.year, dt.month, dt.day);
      final status = dateStatus.entries
          .firstWhere(
            (e) => _isSameDay(e.key, key),
            orElse: () => MapEntry<DateTime, String>(DateTime(0), ''),
          )
          .value;
      final hasData = status.isNotEmpty;
      final isToday = _isSameDay(dt, today);

      Color? bg;
      Color textColor = Colors.black87;
      if (isToday) {
        bg = Colors.yellow[700];
        textColor = Colors.black;
      } else if (hasData) {
        if (status.toLowerCase().contains('abs')) {
          bg = Colors.red[600];
          textColor = Colors.white;
        } else {
          bg = Colors.green[600];
          textColor = Colors.white;
        }
      } else {
        bg = null;
      }

      cells.add(
        GestureDetector(
          onTap: () {
            if (onDayTap != null) onDayTap!(dt, hasData ? status : null);
          },
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: (bg == null)
                      ? Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Fill trailing empty cells so grid is rectangular
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return Column(
      children: [
        header,
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              return cells[index];
            },
          ),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legendItem(context, Colors.green[600]!, 'Present'),
              _legendItem(context, Colors.red[600]!, 'Absent'),
              _legendItem(context, Colors.yellow[700]!, 'Today'),
              _legendItem(
                context,
                Colors.transparent,
                'No data',
                bordered: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendItem(
    BuildContext context,
    Color color,
    String label, {
    bool bordered = false,
  }) {
    final box = Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: bordered
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
              )
            : null,
      ),
    );
    return Row(
      children: [
        box,
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// lib/views/routine_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/routine_provider.dart';
import '../screens/attendance_screen.dart'; // Import AttendanceScreen

class RoutineView extends StatefulWidget {
  const RoutineView({super.key});

  @override
  State<RoutineView> createState() => _RoutineViewState();
}

class _RoutineViewState extends State<RoutineView> {
  late PageController _pageController;
  int _selectedDayIndex = 0;
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    // Set initial day to current day, defaulting to Monday if it's Sunday
    int today = DateTime.now().weekday; // Monday is 1, Sunday is 7
    _selectedDayIndex = (today > 6) ? 0 : today - 1;
    _pageController = PageController(initialPage: _selectedDayIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDaySelected(int index) {
    setState(() {
      _selectedDayIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDaySelector(),
        const SizedBox(height: 8),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _days.length,
            onPageChanged: (index) {
              setState(() {
                _selectedDayIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return DayRoutine(day: _days[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_days.length, (index) {
            final isSelected = _selectedDayIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(_days[index]),
                selected: isSelected,
                onSelected: (_) => _onDaySelected(index),
                selectedColor: Theme.of(context).primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                ),
                backgroundColor: Colors.grey[200],
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[400]!,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class DayRoutine extends StatelessWidget {
  final String day;
  const DayRoutine({super.key, required this.day});

  static const periodTimings = {
    1: '9:30 - 10:30',
    2: '10:30 - 11:30',
    3: '11:30 - 12:30',
    4: '13:30 - 14:20',
    5: '14:20 - 15:10',
    6: '15:10 - 16:00',
  };

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final routineProvider = Provider.of<RoutineProvider>(
      context,
      listen: false,
    );
    final user = authProvider.user;

    // Extract user details. Provide sensible defaults if they are null.
    final course = user?['course']?.toString() ?? 'B.Tech';
    final stream = user?['stream']?.toString() ?? 'CSE';
    final year = user?['year'] as int? ?? 3;
    final section = user?['section']?.toString() ?? 'A';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: routineProvider.getRoutineForDay(
        course: course,
        stream: stream,
        year: year,
        section: section,
        day: day,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No classes scheduled for today.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final routineData = snapshot.data!;
        // Create a map of period number to routine item for quick lookup
        final routineMap = {
          for (var item in routineData) item['period'] as int: item,
        };

        return ListView.builder(
          itemCount: 6, // We always show 6 periods
          itemBuilder: (context, index) {
            final periodNumber = index + 1;
            final periodData = routineMap[periodNumber];
            return PeriodCard(
              periodNumber: periodNumber,
              periodTime: periodTimings[periodNumber]!,
              periodData: periodData,
            );
          },
        );
      },
    );
  }
}

class PeriodCard extends StatelessWidget {
  final int periodNumber;
  final String periodTime;
  final Map<String, dynamic>? periodData;

  const PeriodCard({
    super.key,
    required this.periodNumber,
    required this.periodTime,
    this.periodData,
  });

  @override
  Widget build(BuildContext context) {
    final hasClass = periodData != null;
    final subject = periodData?['subject']?.toString() ?? 'No Class';
    final room = periodData?['room']?.toString() ?? 'N/A';

    // Show substitute if available, otherwise professor
    final professor =
        periodData?['substitute_id']?.toString() ??
        periodData?['professor_id']?.toString() ??
        'N/A';

    // Get user role to conditionally show the button
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?['role'] ?? 'student';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasClass
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: hasClass
              ? Theme.of(context).primaryColor
              : Colors.grey,
          child: Text(
            periodNumber.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          subject,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: hasClass ? Colors.black87 : Colors.grey,
          ),
        ),
        subtitle: Text(periodTime),
        children: hasClass
            ? [
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: Colors.deepPurple,
                  ),
                  title: const Text('Faculty'),
                  subtitle: Text(professor),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.deepPurple,
                  ),
                  title: const Text('Room No.'),
                  subtitle: Text(room),
                ),
                // --- START: Conditional "Take Attendance" Button ---
                if (userRole != 'student')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Take Attendance'),
                        onPressed: () {
                          // Navigate to AttendanceScreen, passing the period data
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AttendanceScreen(periodData: periodData!),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                // --- END: Conditional "Take Attendance" Button ---
              ]
            : [], // No expansion if there's no class
      ),
    );
  }
}

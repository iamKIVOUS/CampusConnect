// lib/providers/routine_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/api_service.dart';

// Adapter to allow Hive to store the routine data
class RoutineDataAdapter extends TypeAdapter<Map<String, dynamic>> {
  @override
  final int typeId = 0;

  @override
  Map<String, dynamic> read(BinaryReader reader) {
    return Map<String, dynamic>.from(reader.readMap());
  }

  @override
  void write(BinaryWriter writer, Map<String, dynamic> obj) {
    writer.writeMap(obj);
  }
}

/// RoutineProvider
/// - Fetches routine from remote API via ApiService.instance.fetchRoutine()
/// - Caches entries into a local Hive box for cross-platform support
/// - Exposes helpers to query by course/stream/year/section/day/period
class RoutineProvider extends ChangeNotifier {
  static const _routineBoxName = 'routine_schedule';
  Box<Map<String, dynamic>>? _routineBox;

  bool _initialized = false;
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;
  bool get isReady =>
      _initialized && _routineBox != null && _routineBox!.isOpen;

  /// Call this once (e.g., from main() or a splash screen)
  Future<void> init() async {
    if (_initialized) return;
    try {
      _loading = true;
      notifyListeners();

      await Hive.initFlutter();

      // Register adapter if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(RoutineDataAdapter());
      }

      _routineBox = await Hive.openBox<Map<String, dynamic>>(_routineBoxName);

      _initialized = true;
      _error = null;
    } catch (e, st) {
      _error = 'Failed to initialize local DB: $e';
      debugPrint('RoutineProvider.init error: $e\n$st');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh remote routine and cache it locally
  Future<bool> refreshRoutine() async {
    // Ensure initialization is complete before proceeding
    if (!isReady) {
      await init();
      // If initialization fails, we cannot proceed.
      if (!isReady) {
        _error = 'Local database is not available. Cannot refresh routine.';
        notifyListeners();
        return false;
      }
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final List<dynamic> remote = await ApiService.instance.fetchRoutine();

      // Clear existing data
      await _routineBox!.clear();

      // Add new data. We use a map for efficient storage.
      for (final item in remote) {
        if (item is Map<String, dynamic>) {
          // Create a unique key for each routine entry
          final key =
              '${item['course']}_${item['stream']}_${item['year']}_${item['section']}_${item['day']}_${item['period']}';
          await _routineBox!.put(key, item);
        }
      }

      _error = null;
      return true;
    } catch (e, st) {
      _error = 'Failed to refresh routine: $e';
      debugPrint('RoutineProvider.refreshRoutine error: $e\n$st');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Query distinct days available for given course/stream/year/section
  Future<List<String>> getAvailableDays({
    required String course,
    required String stream,
    required int year,
    required String section,
  }) async {
    if (!isReady) return [];

    final allRoutines = _routineBox!.values.where(
      (item) =>
          item['course'] == course &&
          item['stream'] == stream &&
          item['year'] == year &&
          item['section'] == section,
    );

    final days = allRoutines
        .map((item) => item['day'].toString())
        .toSet()
        .toList();

    // Sort days in correct order
    days.sort((a, b) {
      const dayOrder = {
        'Monday': 1,
        'Tuesday': 2,
        'Wednesday': 3,
        'Thursday': 4,
        'Friday': 5,
        'Saturday': 6,
        'Sunday': 7,
      };
      return (dayOrder[a] ?? 8).compareTo(dayOrder[b] ?? 8);
    });

    return days;
  }

  /// Get routine entries for a specific day
  Future<List<Map<String, dynamic>>> getRoutineForDay({
    required String course,
    required String stream,
    required int year,
    required String section,
    required String day,
  }) async {
    if (!isReady) return [];

    final routinesForDay = _routineBox!.values
        .where(
          (item) =>
              item['course'] == course &&
              item['stream'] == stream &&
              item['year'] == year &&
              item['section'] == section &&
              item['day'] == day,
        )
        .toList();

    // Sort by period
    routinesForDay.sort(
      (a, b) => (a['period'] as int).compareTo(b['period'] as int),
    );

    return routinesForDay;
  }

  /// Get single period entry (or null)
  Future<Map<String, dynamic>?> getRoutineForPeriod({
    required String course,
    required String stream,
    required int year,
    required String section,
    required String day,
    required int period,
  }) async {
    if (!isReady) return null;
    final key = '${course}_${stream}_${year}_${section}_${day}_$period';
    return _routineBox!.get(key);
  }

  /// Clear local cached routines
  Future<void> clearCache() async {
    if (!isReady) return;
    await _routineBox!.clear();
    notifyListeners();
  }

  /// Close DB (call on dispose)
  Future<void> close() async {
    if (_routineBox != null && _routineBox!.isOpen) {
      await _routineBox!.close();
    }
    _initialized = false;
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

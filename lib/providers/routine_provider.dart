// lib/providers/routine_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/routine_service.dart'; // UPDATED: Import the new service

// This adapter is specific to this provider, so it's kept here for encapsulation.
class RoutineDataAdapter extends TypeAdapter<Map<String, dynamic>> {
  @override
  final int typeId = 0; // Ensure this typeId is unique across your Hive adapters.

  @override
  Map<String, dynamic> read(BinaryReader reader) {
    return Map<String, dynamic>.from(reader.readMap());
  }

  @override
  void write(BinaryWriter writer, Map<String, dynamic> obj) {
    writer.writeMap(obj);
  }
}

class RoutineProvider extends ChangeNotifier {
  // UPDATED: Use the new dedicated service for network calls.
  final RoutineService _routineService = RoutineService();

  static const _routineBoxName = 'routine_schedule';
  Box<Map<String, dynamic>>? _routineBox;

  bool _initialized = false;
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;
  bool get isReady =>
      _initialized && _routineBox != null && _routineBox!.isOpen;

  /// Initializes the Hive database for local caching.
  Future<void> init() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();

    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(RoutineDataAdapter());
      }
      _routineBox = await Hive.openBox<Map<String, dynamic>>(_routineBoxName);
      _initialized = true;
      _error = null;
    } catch (e, st) {
      _error = 'Failed to initialize routine database: $e';
      debugPrint('RoutineProvider.init error: $e\n$st');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetches the latest routine from the server and updates the local cache.
  Future<bool> refreshRoutine() async {
    if (!isReady) await init();
    if (!isReady) {
      _error = 'Local database is not available. Cannot refresh routine.';
      notifyListeners();
      return false;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // UPDATED: Calls the new RoutineService instead of the old ApiService.
      final List<dynamic> remoteRoutine = await _routineService.fetchRoutine();

      await _routineBox!.clear();
      for (final item in remoteRoutine) {
        if (item is Map<String, dynamic>) {
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

  // --- ALL LOCAL DATA QUERY METHODS ARE PRESERVED ---

  /// Query distinct days available for a given class from the local cache.
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

  /// Get routine entries for a specific day from the local cache.
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
    routinesForDay.sort(
      (a, b) => (a['period'] as int).compareTo(b['period'] as int),
    );
    return routinesForDay;
  }

  /// Get a single period entry from the local cache.
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

  /// Clear all local cached routines.
  Future<void> clearCache() async {
    if (!isReady) return;
    await _routineBox!.clear();
    notifyListeners();
  }

  /// Close the Hive box.
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

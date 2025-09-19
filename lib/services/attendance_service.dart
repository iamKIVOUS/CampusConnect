// lib/services/attendance_service.dart
import 'api_client.dart';

class AttendanceService {
  final ApiClient _apiClient = ApiClient.instance;

  Future<List<dynamic>> fetchAttendanceSummary() async {
    final response = await _apiClient.get('/protected/attendance');
    return response['summary'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> submitAttendance(
    Map<String, dynamic> attendanceData,
  ) async {
    return await _apiClient.post(
      '/protected/attendance/submit',
      body: attendanceData,
    );
  }

  // This method was missing and has now been restored.
  Future<List<dynamic>> fetchClassList({
    required String course,
    required String stream,
    required int year,
    required String section,
  }) async {
    final endpoint =
        '/protected/attendance/class-list'
        '?course=${Uri.encodeComponent(course)}'
        '&stream=${Uri.encodeComponent(stream)}'
        '&year=${Uri.encodeComponent(year.toString())}'
        '&section=${Uri.encodeComponent(section)}';
    final response = await _apiClient.get(endpoint);
    return response['students'] as List<dynamic>;
  }
}

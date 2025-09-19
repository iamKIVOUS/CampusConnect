// lib/services/routine_service.dart
import 'api_client.dart';

class RoutineService {
  final ApiClient _apiClient = ApiClient.instance;

  Future<List<dynamic>> fetchRoutine() async {
    final response = await _apiClient.get('/protected/routine');
    return response['routine'] as List<dynamic>;
  }
}

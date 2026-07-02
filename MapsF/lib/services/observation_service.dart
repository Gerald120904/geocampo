import '../core/network/api_client.dart';
import '../models/field_observation.dart';

class ObservationService {
  ObservationService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<FieldObservation>> listForMap(String mapId) async {
    try {
      final response = await _apiClient.dio.get('/observations/map/$mapId');
      final list = response.data as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(FieldObservation.fromJson)
          .toList();
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }
}

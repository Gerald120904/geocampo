import '../core/network/api_client.dart';
import '../models/project_share.dart';
import '../models/shared_project_preview.dart';

class ProjectShareService {
  ProjectShareService(this._apiClient);

  final ApiClient _apiClient;

  Future<ProjectShare> createShare({
    required String projectId,
    int expiresInDays = 7,
    int maxUses = 10,
    bool includeObservations = false,
    bool includeOnlyReadyMaps = true,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/projects/$projectId/shares',
        data: {
          'expires_in_days': expiresInDays,
          'max_uses': maxUses,
          'include_observations': includeObservations,
          'include_only_ready_maps': includeOnlyReadyMaps,
        },
      );
      return ProjectShare.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<SharedProjectPreview> getPreview(String tokenOrCode) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/project-shares/$tokenOrCode',
      );
      return SharedProjectPreview.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<Map<String, dynamic>> acceptShare(String tokenOrCode) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/project-shares/$tokenOrCode/accept',
      );
      return response.data as Map<String, dynamic>;
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }
}

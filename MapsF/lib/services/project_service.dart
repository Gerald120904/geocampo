import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../models/project.dart';
import '../models/project_detail.dart';
import '../models/project_viewer.dart';
import '../models/remote_map.dart';

class ProjectService {
  ProjectService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Project>> listProjects() async {
    try {
      final response = await _apiClient.dio.get('/projects');
      final list = response.data as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Project.fromJson)
          .toList();
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<Project> createProject({
    required String companyId,
    required String name,
    String? description,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/projects',
        data: {
          'company_id': companyId,
          'name': name,
          'description': description,
        },
      );
      return Project.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<ProjectDetail> getProject(String projectId) async {
    try {
      final response = await _apiClient.dio.get('/projects/$projectId');
      return ProjectDetail.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return _getProjectDetailFallback(projectId);
    }
  }

  Future<ProjectDetail> _getProjectDetailFallback(String projectId) async {
    try {
      final projectsResponse = await _apiClient.dio.get('/projects');
      final projects = (projectsResponse.data as List)
          .whereType<Map<String, dynamic>>()
          .map(Project.fromJson)
          .toList();
      final matchingProjects = projects
          .where((item) => item.id == projectId)
          .toList();
      final project = matchingProjects.isEmpty
          ? Project(
              id: projectId,
              companyId: '',
              name: 'Proyecto no disponible',
              description:
                  'El backend no devolvio el detalle de este proyecto.',
            )
          : matchingProjects.first;

      final maps = await _listProjectMapsForFallback(projectId);
      return ProjectDetail(
        id: project.id,
        companyId: project.companyId,
        name: project.name,
        description: project.description,
        updatedAt: project.updatedAt,
        mapsCount: maps.length,
        readyMapsCount: maps.where((map) => map.isReady).length,
        processingMapsCount: maps.where((map) => map.isProcessing).length,
        failedMapsCount: maps.where((map) => map.isFailed).length,
        maps: maps,
      );
    } catch (error) {
      return ProjectDetail(
        id: projectId,
        companyId: '',
        name: 'Proyecto no disponible',
        description: _apiClient.handleError(error).toString(),
      );
    }
  }

  Future<List<RemoteMap>> _listProjectMapsForFallback(String projectId) async {
    try {
      final response = await _apiClient.dio.get('/projects/$projectId/maps');
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map(RemoteMap.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Project> updateProject({
    required String projectId,
    required String name,
    String? description,
  }) async {
    try {
      final response = await _apiClient.dio.patch(
        '/projects/$projectId',
        data: {'name': name, 'description': description},
      );
      return Project.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _apiClient.dio.delete('/projects/$projectId');
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 404) {
        return;
      }
      throw _apiClient.handleError(error);
    }
  }

  Future<ProjectViewer> getProjectViewer({
    required String projectId,
    List<String>? mapIds,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/projects/$projectId/viewer',
        queryParameters: mapIds == null || mapIds.isEmpty
            ? null
            : {'map_ids': mapIds.join(',')},
      );
      return ProjectViewer.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }
}

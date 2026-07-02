import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../core/network/api_client.dart';
import '../models/duplicate_review.dart';
import '../models/map_detail.dart';
import '../models/map_status.dart';
import '../models/remote_map.dart';

class MapService {
  MapService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RemoteMap>> listProjectMaps(String projectId) async {
    try {
      final response = await _apiClient.dio.get('/projects/$projectId/maps');
      final list = response.data as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(RemoteMap.fromJson)
          .toList();
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<MapDetail> getMapDetail(String mapId) async {
    try {
      final response = await _apiClient.dio.get('/maps/$mapId');
      return MapDetail.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<MapStatus> getMapStatus(String mapId) async {
    try {
      final response = await _apiClient.dio.get('/maps/$mapId/status');
      return MapStatus.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> startProcessing(String mapId) async {
    try {
      await _apiClient.dio.post('/maps/$mapId/process');
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<MapUploadResult> uploadMap({
    required String projectId,
    required String name,
    String? description,
    required PlatformFile file,
    String processingMode = 'raw',
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      MultipartFile multipartFile;

      if (file.bytes != null && file.bytes!.isNotEmpty) {
        multipartFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
          contentType: _contentTypeFor(file.name),
        );
      } else if (file.path != null) {
        multipartFile = await MultipartFile.fromFile(
          file.path!,
          filename: file.name,
          contentType: _contentTypeFor(file.name),
        );
      } else {
        throw Exception('No se pudo leer el archivo seleccionado.');
      }

      final formData = FormData.fromMap({
        'project_id': projectId,
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'auto_process': true,
        'processing_mode': processingMode,
        'file': multipartFile,
      });

      final response = await _apiClient.dio.post(
        '/maps/upload',
        data: formData,
        onSendProgress: onProgress,
      );
      final data = response.data as Map<String, dynamic>;
      return MapUploadResult.fromJson(data);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> deleteMap(String mapId) async {
    try {
      await _apiClient.dio.delete('/maps/$mapId');
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> retryMap(String mapId) async {
    try {
      await _apiClient.dio.post('/maps/$mapId/retry');
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> optimizeMap(String mapId) async {
    try {
      await _apiClient.dio.post('/maps/$mapId/optimize');
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<DuplicateReview> getDuplicateReview(String mapId) async {
    try {
      final response = await _apiClient.dio.get('/maps/$mapId/duplicates');
      return DuplicateReview.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> resolveDuplicate({
    required String mapId,
    required String action,
    String? existingMapId,
  }) async {
    try {
      await _apiClient.dio.post(
        '/maps/$mapId/duplicates/resolve',
        data: {
          'action': action,
          ...?existingMapId == null ? null : {'existing_map_id': existingMapId},
        },
      );
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<Response<List<int>>> downloadPackage({
    required String mapId,
    required void Function(int received, int total)? onProgress,
  }) async {
    try {
      return _apiClient.dio.get<List<int>>(
        '/maps/$mapId/package',
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: onProgress,
      );
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<Map<String, dynamic>> getPackageInfo(String mapId) async {
    try {
      final response = await _apiClient.dio.get('/maps/$mapId/package/info');
      return response.data as Map<String, dynamic>;
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<Uint8List> downloadPreview(String mapId) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        '/maps/$mapId/preview',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const <int>[]);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }
}

DioMediaType _contentTypeFor(String fileName) {
  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.pdf')) return DioMediaType('application', 'pdf');
  if (lowerName.endsWith('.geojson') || lowerName.endsWith('.json')) {
    return DioMediaType('application', 'geo+json');
  }
  if (lowerName.endsWith('.gpkg')) {
    return DioMediaType('application', 'geopackage+sqlite3');
  }
  if (lowerName.endsWith('.mbtiles')) {
    return DioMediaType('application', 'x-sqlite3');
  }
  if (lowerName.endsWith('.zip')) return DioMediaType('application', 'zip');
  if (lowerName.endsWith('.tif') || lowerName.endsWith('.tiff')) {
    return DioMediaType('image', 'tiff');
  }
  return DioMediaType('application', 'octet-stream');
}

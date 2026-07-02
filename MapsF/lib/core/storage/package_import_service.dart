import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/local_map.dart';
import '../../repositories/local_map_repository.dart';

class PackageImportService {
  const PackageImportService(this._localMapRepository);

  final LocalMapRepository _localMapRepository;

  Future<LocalMap> installDownloadedPackage(
    String packagePath, {
    int? packageSizeBytes,
    String? packageChecksumSha256,
  }) async {
    final extension = packagePath.toLowerCase();
    if (!extension.endsWith('.geocampo.zip') && !extension.endsWith('.zip')) {
      throw Exception('El mapa descargado no tiene un formato valido.');
    }

    final packageFile = File(packagePath);
    if (!await packageFile.exists()) {
      throw Exception('No se encontro el mapa descargado.');
    }

    final tempRoot = await Directory.systemTemp.createTemp('geocampo_import_');
    final extracted = await compute(_extractPackage, {
      'packagePath': packageFile.path,
      'targetPath': tempRoot.path,
    });

    final metadataFile = File(extracted['metadataPath']!);
    final metadata =
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;

    final appDirectory = await getApplicationDocumentsDirectory();
    final mapsDirectory = Directory(p.join(appDirectory.path, 'local_maps'));
    await mapsDirectory.create(recursive: true);

    final now = DateTime.now().toUtc().toIso8601String();
    final mapId =
        _stringValue(metadata, ['id', 'map_id', 'local_map_id']) ??
        p
            .basenameWithoutExtension(packageFile.path)
            .replaceAll('.geocampo', '');
    final finalDirectory = Directory(p.join(mapsDirectory.path, mapId));
    if (await finalDirectory.exists()) {
      await finalDirectory.delete(recursive: true);
    }
    await finalDirectory.create(recursive: true);

    await _copyDirectory(Directory(extracted['rootPath']!), finalDirectory);
    await tempRoot.delete(recursive: true);

    final localMetadataPath = p.join(
      finalDirectory.path,
      p.relative(extracted['metadataPath']!, from: extracted['rootPath']!),
    );
    final localMbtilesPath = p.join(
      finalDirectory.path,
      p.relative(extracted['mbtilesPath']!, from: extracted['rootPath']!),
    );
    final localPreviewPath = extracted['previewPath'] == null
        ? null
        : p.join(
            finalDirectory.path,
            p.relative(extracted['previewPath']!, from: extracted['rootPath']!),
          );

    final boundsJson = _jsonString(
      _value(metadata, ['bounds', 'bounds_json', 'bbox']),
      fallback: '[]',
    );
    final footprintJson = _nullableJsonString(
      _value(metadata, ['footprint', 'footprint_json', 'polygon']),
    );
    final center = _center(metadata);
    final zoom = metadata['zoom'] is Map
        ? (metadata['zoom'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final minZoom =
        _intValue(metadata, ['min_zoom', 'minzoom']) ??
        _intValue(zoom, ['min', 'min_zoom', 'minzoom']);
    final maxZoom =
        _intValue(metadata, ['max_zoom', 'maxzoom']) ??
        _intValue(zoom, ['max', 'max_zoom', 'maxzoom']);
    final defaultZoom =
        _intValue(metadata, ['default_zoom']) ??
        _intValue(zoom, ['default', 'default_zoom']) ??
        minZoom;
    final localMap = LocalMap(
      id: mapId,
      remoteMapId: _stringValue(metadata, ['remote_map_id', 'map_id']),
      projectId: _stringValue(metadata, ['project_id']),
      name: _stringValue(metadata, ['name', 'title']) ?? 'Mapa sin nombre',
      project:
          _stringValue(metadata, ['project_name', 'project_id']) ??
          'Sin proyecto',
      type: _stringValue(metadata, ['source_type']) ?? 'PDF georreferenciado',
      sourceType:
          _stringValue(metadata, ['source_type']) ?? 'PDF georreferenciado',
      imported: now,
      size: '',
      lastOpened: now,
      accent: const Color(0xFF2F7D32),
      layers: const [],
      packagePath: finalDirectory.path,
      mbtilesPath: localMbtilesPath,
      previewPath: localPreviewPath,
      metadataPath: localMetadataPath,
      boundsJson: boundsJson,
      footprintJson: footprintJson,
      centerLat: center?.$1,
      centerLng: center?.$2,
      minZoom: minZoom,
      maxZoom: maxZoom,
      defaultZoom: defaultZoom,
      packageVersion: _stringValue(metadata, ['package_version']),
      packageSizeBytes:
          packageSizeBytes ?? _intValue(metadata, ['package_size_bytes']),
      packageChecksumSha256:
          packageChecksumSha256 ??
          _stringValue(metadata, [
            'package_checksum_sha256',
            'checksum_sha256',
          ]),
      offlineSavedAt: now,
      lastOpenedAt: now,
      createdAt: _stringValue(metadata, ['created_at']) ?? now,
      updatedAt: now,
    );

    await _localMapRepository.save(localMap);
    if (await packageFile.exists()) {
      await packageFile.delete();
    }
    return localMap;
  }

  static Object? _value(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) return json[key];
    }
    return null;
  }

  static String? _stringValue(Map<String, dynamic> json, List<String> keys) {
    final value = _value(json, keys);
    return value == null || value.toString().isEmpty ? null : value.toString();
  }

  static int? _intValue(Map<String, dynamic> json, List<String> keys) {
    final value = _value(json, keys);
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String _jsonString(Object? value, {required String fallback}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return jsonEncode(value);
  }

  static String? _nullableJsonString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return jsonEncode(value);
  }

  static (double, double)? _center(Map<String, dynamic> json) {
    final centerLat = _doubleFromValue(_value(json, ['center_lat']));
    final centerLng = _doubleFromValue(_value(json, ['center_lng']));
    if (centerLat != null && centerLng != null) return (centerLat, centerLng);

    final center = _value(json, ['center']);
    if (center is Map) {
      final lat = _doubleFromValue(center['lat'] ?? center['latitude']);
      final lng = _doubleFromValue(
        center['lng'] ?? center['lon'] ?? center['longitude'],
      );
      if (lat != null && lng != null) return (lat, lng);
    }
    if (center is List && center.length >= 2) {
      final lng = _doubleFromValue(center[0]);
      final lat = _doubleFromValue(center[1]);
      if (lat != null && lng != null) return (lat, lng);
    }
    return null;
  }

  static double? _doubleFromValue(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

Future<Map<String, String>> _extractPackage(Map<String, String> args) async {
  final packagePath = args['packagePath']!;
  final targetPath = args['targetPath']!;
  final inputStream = InputFileStream(packagePath);
  final archive = ZipDecoder().decodeStream(inputStream);

  for (final file in archive.files) {
    final safeName = p.normalize(file.name);
    if (p.isAbsolute(safeName) || safeName.startsWith('..')) {
      throw Exception('El paquete contiene rutas invalidas.');
    }
    if (file.isFile) {
      final outputPath = p.join(targetPath, safeName);
      await Directory(p.dirname(outputPath)).create(recursive: true);
      final outputStream = OutputFileStream(outputPath);
      file.writeContent(outputStream);
      await outputStream.close();
    }
  }

  final files = Directory(
    targetPath,
  ).listSync(recursive: true).whereType<File>();
  final metadataFile = files
      .where((file) => p.basename(file.path).toLowerCase() == 'metadata.json')
      .firstOrNull;
  if (metadataFile == null) {
    throw Exception('El paquete no contiene metadata.json.');
  }

  final mbtilesFile = files
      .where((file) => p.basename(file.path).toLowerCase() == 'map.mbtiles')
      .firstOrNull;
  if (mbtilesFile == null) {
    throw Exception('El paquete no contiene map.mbtiles.');
  }

  final previewFile = files.where((file) {
    final name = p.basename(file.path).toLowerCase();
    return name == 'preview.png' || name == 'preview.jpg';
  }).firstOrNull;

  return {
    'rootPath': targetPath,
    'metadataPath': metadataFile.path,
    'mbtilesPath': mbtilesFile.path,
    if (previewFile != null) 'previewPath': previewFile.path,
  };
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await for (final entity in source.list(recursive: true)) {
    final relativePath = p.relative(entity.path, from: source.path);
    final targetPath = p.join(destination.path, relativePath);
    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(targetPath)).create(recursive: true);
      await entity.copy(targetPath);
    }
  }
}

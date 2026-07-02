import 'package:flutter/material.dart';

class LocalMap {
  const LocalMap({
    required this.id,
    required this.name,
    required this.project,
    required this.type,
    required this.imported,
    required this.size,
    required this.lastOpened,
    required this.accent,
    required this.layers,
    required this.remoteMapId,
    required this.projectId,
    required this.sourceType,
    required this.packagePath,
    required this.mbtilesPath,
    required this.metadataPath,
    required this.boundsJson,
    required this.createdAt,
    required this.updatedAt,
    this.previewPath,
    this.footprintJson,
    this.centerLat,
    this.centerLng,
    this.minZoom,
    this.maxZoom,
    this.defaultZoom,
    this.packageVersion,
    this.packageSizeBytes,
    this.packageChecksumSha256,
    this.offlineSavedAt,
    this.lastOpenedAt,
    this.availableOffline = true,
  });

  final String id;
  final String name;
  final String project;
  final String type;
  final String imported;
  final String size;
  final String lastOpened;
  final Color accent;
  final List<String> layers;
  final bool availableOffline;

  final String? remoteMapId;
  final String? projectId;
  final String sourceType;
  final String packagePath;
  final String mbtilesPath;
  final String? previewPath;
  final String metadataPath;
  final String boundsJson;
  final String? footprintJson;
  final double? centerLat;
  final double? centerLng;
  final int? minZoom;
  final int? maxZoom;
  final int? defaultZoom;
  final String? packageVersion;
  final int? packageSizeBytes;
  final String? packageChecksumSha256;
  final String? offlineSavedAt;
  final String? lastOpenedAt;
  final String createdAt;
  final String updatedAt;

  factory LocalMap.fromDatabaseRow(Map<String, Object?> row) {
    final createdAt = row['created_at']?.toString() ?? '';
    final sourceType = row['source_type']?.toString() ?? 'PDF georreferenciado';
    return LocalMap(
      id: row['id'].toString(),
      remoteMapId: row['remote_map_id']?.toString(),
      projectId: row['project_id']?.toString(),
      name: row['name']?.toString() ?? 'Mapa sin nombre',
      project: row['project_id']?.toString() ?? 'Sin proyecto',
      type: sourceType,
      sourceType: sourceType,
      imported: createdAt,
      size: '',
      lastOpened: row['updated_at']?.toString() ?? '',
      accent: const Color(0xFF2F7D32),
      layers: const [],
      packagePath: row['package_path']?.toString() ?? '',
      mbtilesPath: row['mbtiles_path']?.toString() ?? '',
      previewPath: row['preview_path']?.toString(),
      metadataPath: row['metadata_path']?.toString() ?? '',
      boundsJson: row['bounds_json']?.toString() ?? '[]',
      footprintJson: row['footprint_json']?.toString(),
      centerLat: _doubleValue(row['center_lat']),
      centerLng: _doubleValue(row['center_lng']),
      minZoom: _intValue(row['min_zoom']),
      maxZoom: _intValue(row['max_zoom']),
      defaultZoom: _intValue(row['default_zoom']),
      packageVersion: row['package_version']?.toString(),
      packageSizeBytes: _intValue(row['package_size_bytes']),
      packageChecksumSha256: row['package_checksum_sha256']?.toString(),
      offlineSavedAt: row['offline_saved_at']?.toString() ?? createdAt,
      lastOpenedAt: row['last_opened_at']?.toString(),
      createdAt: createdAt,
      updatedAt: row['updated_at']?.toString() ?? createdAt,
    );
  }

  factory LocalMap.fromLocalRow(Map<String, Object?> row) {
    return LocalMap.fromDatabaseRow(row);
  }

  Map<String, Object?> toDatabaseRow() {
    return {
      'id': id,
      'remote_map_id': remoteMapId,
      'project_id': projectId,
      'name': name,
      'source_type': sourceType,
      'package_path': packagePath,
      'mbtiles_path': mbtilesPath,
      'preview_path': previewPath,
      'metadata_path': metadataPath,
      'bounds_json': boundsJson,
      'footprint_json': footprintJson,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'min_zoom': minZoom,
      'max_zoom': maxZoom,
      'default_zoom': defaultZoom,
      'package_version': packageVersion,
      'package_size_bytes': packageSizeBytes,
      'package_checksum_sha256': packageChecksumSha256,
      'offline_saved_at': offlineSavedAt,
      'last_opened_at': lastOpenedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static double? _doubleValue(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _intValue(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class LayerState {
  LayerState(this.name, this.icon, {this.visible = true, this.opacity = 1});

  final String name;
  final IconData icon;
  bool visible;
  double opacity;
}

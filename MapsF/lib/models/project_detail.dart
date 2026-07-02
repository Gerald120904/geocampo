import 'map_detail.dart';
import 'project.dart';
import 'remote_map.dart';

class ProjectDetail extends Project {
  const ProjectDetail({
    required super.id,
    required super.companyId,
    required super.name,
    super.description,
    super.mapsCount,
    super.readyMapsCount,
    super.processingMapsCount,
    super.failedMapsCount,
    super.updatedAt,
    this.bounds,
    this.center,
    this.maps = const [],
  });

  final MapBounds? bounds;
  final MapCenter? center;
  final List<RemoteMap> maps;

  factory ProjectDetail.fromJson(Map<String, dynamic> json) {
    return ProjectDetail(
      id: json['id'].toString(),
      companyId: json['company_id']?.toString() ?? '',
      name: json['name'].toString(),
      description: json['description']?.toString(),
      mapsCount: _intValue(json['maps_count']),
      readyMapsCount: _intValue(json['ready_maps_count']),
      processingMapsCount: _intValue(json['processing_maps_count']),
      failedMapsCount: _intValue(json['failed_maps_count']),
      updatedAt: _dateValue(json['updated_at']),
      bounds: json['bounds'] is Map<String, dynamic>
          ? MapBounds.fromJson(json['bounds'] as Map<String, dynamic>)
          : null,
      center: json['center'] is Map<String, dynamic>
          ? MapCenter.fromJson(json['center'] as Map<String, dynamic>)
          : null,
      maps: (json['maps'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RemoteMap.fromJson)
          .toList(),
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateValue(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

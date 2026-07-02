import 'map_detail.dart';

class ProjectViewerMap {
  const ProjectViewerMap({
    required this.id,
    required this.name,
    required this.status,
    required this.tileUrl,
    this.bounds,
    this.opacity = 1,
    this.visible = true,
    this.minZoom = 10,
    this.maxZoom = 18,
  });

  final String id;
  final String name;
  final String status;
  final String tileUrl;
  final MapBounds? bounds;
  final double opacity;
  final bool visible;
  final int minZoom;
  final int maxZoom;

  factory ProjectViewerMap.fromJson(Map<String, dynamic> json) {
    return ProjectViewerMap(
      id: json['id'].toString(),
      name: json['name'].toString(),
      status: json['status']?.toString() ?? 'ready',
      tileUrl: json['tile_url']?.toString() ?? '',
      bounds: json['bounds'] is Map<String, dynamic>
          ? MapBounds.fromJson(json['bounds'] as Map<String, dynamic>)
          : null,
      opacity: _doubleValue(json['opacity']) ?? 1,
      visible: json['visible'] != false,
      minZoom: int.tryParse(json['min_zoom']?.toString() ?? '') ?? 10,
      maxZoom: int.tryParse(json['max_zoom']?.toString() ?? '') ?? 18,
    );
  }

  static double? _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class ProjectViewer {
  const ProjectViewer({
    required this.projectId,
    required this.projectName,
    required this.maps,
    this.bounds,
    this.center,
  });

  final String projectId;
  final String projectName;
  final MapBounds? bounds;
  final MapCenter? center;
  final List<ProjectViewerMap> maps;

  factory ProjectViewer.fromJson(Map<String, dynamic> json) {
    final project = json['project'] is Map<String, dynamic>
        ? json['project'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ProjectViewer(
      projectId: project['id']?.toString() ?? json['project_id'].toString(),
      projectName: project['name']?.toString() ?? json['name'].toString(),
      bounds: json['bounds'] is Map<String, dynamic>
          ? MapBounds.fromJson(json['bounds'] as Map<String, dynamic>)
          : null,
      center: json['center'] is Map<String, dynamic>
          ? MapCenter.fromJson(json['center'] as Map<String, dynamic>)
          : null,
      maps: (json['maps'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ProjectViewerMap.fromJson)
          .toList(),
    );
  }
}

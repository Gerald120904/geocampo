import 'map_layer.dart';

class MapBounds {
  const MapBounds({
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });

  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  factory MapBounds.fromJson(Map<String, dynamic> json) {
    return MapBounds(
      minLat: double.parse(json['min_lat'].toString()),
      minLng: double.parse(json['min_lng'].toString()),
      maxLat: double.parse(json['max_lat'].toString()),
      maxLng: double.parse(json['max_lng'].toString()),
    );
  }
}

class MapCenter {
  const MapCenter({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory MapCenter.fromJson(Map<String, dynamic> json) {
    return MapCenter(
      lat: double.parse(json['lat'].toString()),
      lng: double.parse(json['lng'].toString()),
    );
  }
}

class MapDetail {
  const MapDetail({
    required this.id,
    required this.projectId,
    required this.name,
    required this.status,
    required this.sourceType,
    required this.minZoom,
    required this.maxZoom,
    required this.defaultZoom,
    required this.layers,
    required this.packageAvailable,
    required this.rawAvailable,
    required this.quickAvailable,
    required this.optimizedAvailable,
    required this.canOpen,
    required this.canOptimize,
    required this.viewMode,
    this.description,
    this.bounds,
    this.center,
    this.tileVersion,
    this.overlayUrl,
    this.rawPdfUrl,
    this.processingProgress,
    this.processingMessage,
  });

  final String id;
  final String projectId;
  final String name;
  final String? description;
  final String status;
  final String sourceType;
  final int minZoom;
  final int maxZoom;
  final int defaultZoom;
  final MapBounds? bounds;
  final MapCenter? center;
  final List<MapLayer> layers;
  final bool packageAvailable;
  final bool rawAvailable;
  final bool quickAvailable;
  final bool optimizedAvailable;
  final bool canOpen;
  final bool canOptimize;
  final String viewMode;
  final String? tileVersion;
  final String? overlayUrl;
  final String? rawPdfUrl;
  final int? processingProgress;
  final String? processingMessage;

  factory MapDetail.fromJson(Map<String, dynamic> json) {
    return MapDetail(
      id: json['id'].toString(),
      projectId: json['project_id']?.toString() ?? '',
      name: json['name'].toString(),
      description: json['description']?.toString(),
      status: json['status'].toString(),
      sourceType: json['source_type']?.toString() ?? 'desconocido',
      minZoom: int.tryParse(json['min_zoom']?.toString() ?? '') ?? 10,
      maxZoom: int.tryParse(json['max_zoom']?.toString() ?? '') ?? 18,
      defaultZoom: int.tryParse(json['default_zoom']?.toString() ?? '') ?? 16,
      bounds: json['bounds'] is Map<String, dynamic>
          ? MapBounds.fromJson(json['bounds'] as Map<String, dynamic>)
          : null,
      center: json['center'] is Map<String, dynamic>
          ? MapCenter.fromJson(json['center'] as Map<String, dynamic>)
          : null,
      layers: (json['layers'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MapLayer.fromJson)
          .toList(),
      packageAvailable:
          json['package_available'] == true || json['has_package'] == true,
      rawAvailable: json['raw_available'] == true,
      quickAvailable: json['quick_available'] == true,
      optimizedAvailable:
          json['optimized_available'] == true ||
          json['package_available'] == true,
      canOpen: json['can_open'] == true,
      canOptimize: json['can_optimize'] == true,
      viewMode: json['view_mode']?.toString() ?? 'none',
      tileVersion: json['tile_version']?.toString(),
      overlayUrl: json['overlay_url']?.toString(),
      rawPdfUrl: json['raw_pdf_url']?.toString(),
      processingProgress: int.tryParse(
        (json['processing_progress'] ?? '').toString(),
      ),
      processingMessage: json['processing_message']?.toString(),
    );
  }
}

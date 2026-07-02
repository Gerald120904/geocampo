class MapLayer {
  const MapLayer({
    required this.id,
    required this.name,
    required this.layerType,
    required this.featureCount,
    this.layerKey,
    this.geometryType,
    this.visibleDefault = true,
    this.opacityDefault = 1,
    this.propertiesSchema,
  });

  final String id;
  final String name;
  final String? layerKey;
  final String layerType;
  final String? geometryType;
  final bool visibleDefault;
  final double opacityDefault;
  final Map<String, dynamic>? propertiesSchema;
  final int featureCount;

  factory MapLayer.fromJson(Map<String, dynamic> json) {
    return MapLayer(
      id: json['id'].toString(),
      name: json['name'].toString(),
      layerKey: json['layer_key']?.toString(),
      layerType:
          json['layer_type']?.toString() ?? json['type']?.toString() ?? '',
      geometryType: json['geometry_type']?.toString(),
      visibleDefault: json['visible_default'] != false,
      opacityDefault:
          double.tryParse(json['opacity_default']?.toString() ?? '1') ?? 1,
      propertiesSchema: json['properties_schema'] is Map<String, dynamic>
          ? json['properties_schema'] as Map<String, dynamic>
          : null,
      featureCount: int.tryParse(json['feature_count']?.toString() ?? '0') ?? 0,
    );
  }
}

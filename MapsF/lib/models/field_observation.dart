class FieldObservation {
  const FieldObservation({
    required this.id,
    required this.mapProjectId,
    required this.userId,
    required this.title,
    required this.lat,
    required this.lng,
    required this.createdAt,
    this.description,
    this.observationType,
    this.accuracy,
    this.photoPath,
    this.properties,
  });

  final String id;
  final String mapProjectId;
  final String userId;
  final String title;
  final String? description;
  final String? observationType;
  final double lat;
  final double lng;
  final double? accuracy;
  final String? photoPath;
  final Map<String, dynamic>? properties;
  final DateTime createdAt;

  factory FieldObservation.fromJson(Map<String, dynamic> json) {
    return FieldObservation(
      id: json['id'].toString(),
      mapProjectId: json['map_project_id'].toString(),
      userId: json['user_id'].toString(),
      title: json['title'].toString(),
      description: json['description']?.toString(),
      observationType: json['observation_type']?.toString(),
      lat: double.parse(json['lat'].toString()),
      lng: double.parse(json['lng'].toString()),
      accuracy: double.tryParse(json['accuracy']?.toString() ?? ''),
      photoPath: json['photo_path']?.toString(),
      properties: json['properties'] is Map<String, dynamic>
          ? json['properties'] as Map<String, dynamic>
          : null,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

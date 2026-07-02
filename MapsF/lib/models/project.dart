class Project {
  const Project({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.mapsCount = 0,
    this.readyMapsCount = 0,
    this.processingMapsCount = 0,
    this.failedMapsCount = 0,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String? description;
  final int mapsCount;
  final int readyMapsCount;
  final int processingMapsCount;
  final int failedMapsCount;
  final DateTime? updatedAt;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'].toString(),
      companyId: json['company_id']?.toString() ?? '',
      name: json['name'].toString(),
      description: json['description']?.toString(),
      mapsCount: _intValue(json['maps_count']),
      readyMapsCount: _intValue(json['ready_maps_count']),
      processingMapsCount: _intValue(json['processing_maps_count']),
      failedMapsCount: _intValue(json['failed_maps_count']),
      updatedAt: _dateValue(json['updated_at']),
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

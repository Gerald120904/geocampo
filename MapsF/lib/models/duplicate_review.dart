class DuplicateCandidate {
  const DuplicateCandidate({
    required this.mapId,
    required this.name,
    required this.score,
    required this.reason,
    this.duplicateType,
  });

  final String mapId;
  final String name;
  final double score;
  final String reason;
  final String? duplicateType;

  factory DuplicateCandidate.fromJson(Map<String, dynamic> json) {
    return DuplicateCandidate(
      mapId: (json['map_id'] ?? json['id']).toString(),
      name: json['name']?.toString() ?? 'Mapa existente',
      score: double.tryParse(json['score']?.toString() ?? '') ?? 0,
      reason: json['reason']?.toString() ?? 'ubicacion geografica similar',
      duplicateType: json['duplicate_type']?.toString(),
    );
  }
}

class DuplicateReview {
  const DuplicateReview({
    required this.mapId,
    required this.message,
    required this.candidates,
  });

  final String mapId;
  final String message;
  final List<DuplicateCandidate> candidates;

  factory DuplicateReview.fromJson(Map<String, dynamic> json) {
    return DuplicateReview(
      mapId: (json['map_id'] ?? json['id']).toString(),
      message:
          json['message']?.toString() ??
          'Ya existe un mapa con una ubicacion similar.',
      candidates: (json['candidates'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DuplicateCandidate.fromJson)
          .toList(),
    );
  }
}

class MapUploadResult {
  const MapUploadResult({
    required this.mapId,
    required this.status,
    this.message,
    this.duplicateReview,
  });

  final String mapId;
  final String status;
  final String? message;
  final DuplicateReview? duplicateReview;

  factory MapUploadResult.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'uploaded';
    return MapUploadResult(
      mapId: (json['map_id'] ?? json['id']).toString(),
      status: status,
      message: json['message']?.toString(),
      duplicateReview: status == 'duplicate_review'
          ? DuplicateReview.fromJson(json)
          : null,
    );
  }
}

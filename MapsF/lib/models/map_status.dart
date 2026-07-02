class MapJob {
  const MapJob({
    required this.status,
    required this.step,
    required this.progress,
    this.errorMessage,
  });

  final String status;
  final String step;
  final int progress;
  final String? errorMessage;

  factory MapJob.fromJson(Map<String, dynamic> json) {
    return MapJob(
      status: json['status']?.toString() ?? 'pending',
      step: json['step']?.toString() ?? 'Esperando',
      progress: int.tryParse(json['progress']?.toString() ?? '0') ?? 0,
      errorMessage: json['error_message']?.toString(),
    );
  }
}

class MapStatus {
  const MapStatus({required this.mapId, required this.status, this.job});

  final String mapId;
  final String status;
  final MapJob? job;

  factory MapStatus.fromJson(Map<String, dynamic> json) {
    final jobJson = json['job'];
    return MapStatus(
      mapId: json['map_id']?.toString() ?? json['id'].toString(),
      status: json['status'].toString(),
      job: jobJson is Map<String, dynamic> ? MapJob.fromJson(jobJson) : null,
    );
  }
}

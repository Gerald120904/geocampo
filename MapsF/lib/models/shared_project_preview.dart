class SharedProjectPreview {
  const SharedProjectPreview({
    required this.token,
    required this.code,
    required this.projectName,
    required this.ownerName,
    required this.mapsCount,
    required this.readyMapsCount,
    required this.mode,
    this.projectDescription,
    this.expiresAt,
  });

  final String token;
  final String code;
  final String projectName;
  final String? projectDescription;
  final String ownerName;
  final int mapsCount;
  final int readyMapsCount;
  final String mode;
  final DateTime? expiresAt;

  factory SharedProjectPreview.fromJson(Map<String, dynamic> json) {
    return SharedProjectPreview(
      token: json['token'].toString(),
      code: json['code'].toString(),
      projectName: json['project_name'].toString(),
      projectDescription: json['project_description']?.toString(),
      ownerName: json['owner_name'].toString(),
      mapsCount: int.tryParse(json['maps_count'].toString()) ?? 0,
      readyMapsCount: int.tryParse(json['ready_maps_count'].toString()) ?? 0,
      mode: json['mode'].toString(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'].toString()),
    );
  }
}

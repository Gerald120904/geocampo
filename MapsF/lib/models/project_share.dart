class ProjectShare {
  const ProjectShare({
    required this.id,
    required this.token,
    required this.code,
    required this.maxUses,
    required this.usedCount,
    this.expiresAt,
  });

  final String id;
  final String token;
  final String code;
  final int maxUses;
  final int usedCount;
  final DateTime? expiresAt;

  factory ProjectShare.fromJson(Map<String, dynamic> json) {
    return ProjectShare(
      id: json['id'].toString(),
      token: json['token'].toString(),
      code: json['code'].toString(),
      maxUses: int.tryParse(json['max_uses'].toString()) ?? 0,
      usedCount: int.tryParse(json['used_count'].toString()) ?? 0,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'].toString()),
    );
  }
}

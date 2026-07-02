class PackageMetadata {
  const PackageMetadata({
    required this.mapId,
    required this.name,
    required this.packageVersion,
    this.description,
    this.sizeBytes,
    this.checksumSha256,
  });

  final String mapId;
  final String name;
  final String packageVersion;
  final String? description;
  final int? sizeBytes;
  final String? checksumSha256;

  factory PackageMetadata.fromJson(Map<String, dynamic> json) {
    return PackageMetadata(
      mapId: json['map_id'].toString(),
      name: json['name'].toString(),
      packageVersion: json['package_version']?.toString() ?? '1.0.0',
      description: json['description']?.toString(),
      sizeBytes: int.tryParse(json['package_size_bytes']?.toString() ?? ''),
      checksumSha256: json['package_checksum_sha256']?.toString(),
    );
  }
}

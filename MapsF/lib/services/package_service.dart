import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/storage/package_import_service.dart';
import '../models/local_map.dart';
import 'map_service.dart';

class PackageInfo {
  const PackageInfo({
    required this.available,
    this.checksumSha256,
    this.sizeBytes,
  });

  final bool available;
  final String? checksumSha256;
  final int? sizeBytes;

  factory PackageInfo.fromJson(Map<String, dynamic> json) {
    return PackageInfo(
      available:
          json['available'] == true ||
          json['package_available'] == true ||
          json['has_package'] == true,
      checksumSha256:
          json['checksum_sha256']?.toString() ??
          json['package_checksum_sha256']?.toString(),
      sizeBytes: int.tryParse(
        (json['size_bytes'] ?? json['package_size_bytes'] ?? '').toString(),
      ),
    );
  }
}

class PackageService {
  PackageService(this._mapService, this._packageImportService);

  final MapService _mapService;
  final PackageImportService _packageImportService;

  Future<PackageInfo> getPackageInfo(String mapId) async {
    final json = await _mapService.getPackageInfo(mapId);
    return PackageInfo.fromJson(json);
  }

  Future<LocalMap> saveMapOffline({
    required String mapId,
    void Function(int received, int total)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'La descarga offline solo esta disponible en la app instalada.',
      );
    }

    final info = await getPackageInfo(mapId);
    if (!info.available) {
      throw Exception('El mapa todavia no esta listo para guardarse offline.');
    }

    final response = await _mapService.downloadPackage(
      mapId: mapId,
      onProgress: onProgress,
    );
    final bytes = response.data ?? <int>[];
    if (bytes.isEmpty) {
      throw Exception('No pudimos descargar el mapa.');
    }

    final checksum = sha256.convert(bytes).toString();
    final expectedChecksum = info.checksumSha256;
    if (expectedChecksum != null &&
        expectedChecksum.isNotEmpty &&
        checksum.toLowerCase() != expectedChecksum.toLowerCase()) {
      throw Exception('La descarga no se completo correctamente.');
    }

    final tempDirectory = await getTemporaryDirectory();
    final packageFile = File(
      p.join(
        tempDirectory.path,
        '$mapId-${DateTime.now().millisecondsSinceEpoch}.geocampo.zip',
      ),
    );
    await packageFile.writeAsBytes(bytes, flush: true);
    return _packageImportService.installDownloadedPackage(
      packageFile.path,
      packageSizeBytes: info.sizeBytes ?? bytes.length,
      packageChecksumSha256: checksum,
    );
  }
}

import '../core/constants/app_constants.dart';

class RemoteMap {
  const RemoteMap({
    required this.id,
    required this.name,
    required this.status,
    required this.sourceType,
    required this.hasPackage,
    required this.rawAvailable,
    required this.quickAvailable,
    required this.optimizedAvailable,
    required this.canOpen,
    required this.canOptimize,
    required this.viewMode,
    this.previewUrl,
    this.createdAt,
    this.processingProgress,
    this.processingMessage,
  });

  final String id;
  final String name;
  final String status;
  final String sourceType;
  final bool hasPackage;
  final bool rawAvailable;
  final bool quickAvailable;
  final bool optimizedAvailable;
  final bool canOpen;
  final bool canOptimize;
  final String viewMode;
  final String? previewUrl;
  final DateTime? createdAt;
  final int? processingProgress;
  final String? processingMessage;

  factory RemoteMap.fromJson(Map<String, dynamic> json) {
    final rawPreview = json['preview_url']?.toString();
    final rawAvailable = json['raw_available'] == true;
    final quickAvailable = json['quick_available'] == true;
    final optimizedAvailable =
        json['optimized_available'] == true ||
        json['has_package'] == true ||
        json['package_available'] == true;

    return RemoteMap(
      id: json['id'].toString(),
      name: json['name'].toString(),
      status: json['status'].toString(),
      sourceType: json['source_type']?.toString() ?? 'desconocido',
      hasPackage: optimizedAvailable,
      rawAvailable: rawAvailable,
      quickAvailable: quickAvailable,
      optimizedAvailable: optimizedAvailable,
      canOpen:
          json['can_open'] == true ||
          rawAvailable ||
          quickAvailable ||
          optimizedAvailable,
      canOptimize: json['can_optimize'] == true,
      viewMode: json['view_mode']?.toString() ?? 'none',
      previewUrl: rawPreview == null
          ? null
          : rawPreview.startsWith('http')
          ? rawPreview
          : '${AppConstants.apiBaseUrl}$rawPreview',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      processingProgress: int.tryParse(
        (json['processing_progress'] ?? '').toString(),
      ),
      processingMessage: json['processing_message']?.toString(),
    );
  }

  bool get isRawReady => status == 'raw_ready';
  bool get isQuickReady => status == 'quick_ready';
  bool get isReady => status == 'ready';
  bool get isProcessing =>
      status == 'uploaded' ||
      status == 'queued' ||
      status == 'processing' ||
      status == 'inspecting' ||
      status == 'building_preview' ||
      status == 'warping' ||
      status == 'building_tiles' ||
      status == 'building_package' ||
      status == 'quick_building' ||
      status == 'optimizing';
  bool get isOptimizing =>
      status == 'optimizing' ||
      ((rawAvailable || quickAvailable) && isProcessing);
  bool get isFailed => status == 'failed';
  bool get isDuplicateReview => status == 'duplicate_review';

  String get statusLabel {
    final percent = processingProgress?.clamp(0, 100);

    if (isReady) return 'LISTO OPTIMIZADO';
    if (isRawReady) return 'PDF LISTO';
    if (isQuickReady) return 'PDF LISTO';
    if (isOptimizing) {
      return percent == null ? 'OPTIMIZANDO' : 'OPTIMIZANDO · $percent%';
    }
    if (isProcessing) {
      return percent == null ? 'PROCESANDO' : 'PROCESANDO · $percent%';
    }
    if (isFailed) return 'ERROR';
    if (isDuplicateReview) return 'DUPLICADO';

    switch (status) {
      case 'archived':
        return 'ARCHIVADO';
      case 'replaced':
        return 'REEMPLAZADO';
      case 'deleted':
        return 'ELIMINADO';
      default:
        return status.toUpperCase();
    }
  }

  String get processingStatusLabel => statusLabel;
}

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../status_chip.dart';

class MapStatusBadge extends StatelessWidget {
  const MapStatusBadge({super.key, required this.status, this.progress});

  final String status;
  final int? progress;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toLowerCase();
    final isProcessing = {
      'uploaded',
      'queued',
      'processing',
      'inspecting',
      'building_preview',
      'warping',
      'building_tiles',
      'building_package',
      'quick_building',
      'optimizing',
    }.contains(normalizedStatus);
    final color = normalizedStatus == 'ready'
        ? AppColors.primaryGreen
        : normalizedStatus == 'failed'
        ? AppColors.dangerRed
        : normalizedStatus == 'raw_ready' || normalizedStatus == 'quick_ready'
        ? AppColors.gpsBlue
        : AppColors.warningYellow;
    final label = isProcessing && progress != null
        ? '${normalizedStatus == 'optimizing' ? 'OPTIMIZANDO' : 'PROCESANDO'} · ${progress!.clamp(0, 100)}%'
        : _labelForStatus(normalizedStatus);

    return StatusChip(
      label: label,
      color: color,
      pulse: isProcessing,
      bounceOnBuild: normalizedStatus == 'failed',
    );
  }

  String _labelForStatus(String status) {
    switch (status) {
      case 'ready':
        return 'LISTO OPTIMIZADO';
      case 'raw_ready':
      case 'quick_ready':
        return 'PDF LISTO';
      case 'quick_building':
        return 'CREANDO VISTA HD';
      case 'optimizing':
        return 'OPTIMIZANDO';
      case 'failed':
        return 'ERROR';
      case 'duplicate_review':
        return 'DUPLICADO';
      default:
        return status.toUpperCase();
    }
  }
}

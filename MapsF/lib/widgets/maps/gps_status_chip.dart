import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../status_chip.dart';

class GpsStatusChip extends StatelessWidget {
  const GpsStatusChip({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: active ? 'GPS ACTIVO' : 'SIN GPS',
      color: active ? AppColors.gpsBlue : AppColors.textSecondary,
      icon: active ? Icons.gps_fixed : Icons.gps_off,
      liveDot: active,
    );
  }
}

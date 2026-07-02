import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../services/haptic_service.dart';

enum AppToastType { success, error, info, warning }

abstract final class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
  }) {
    final data = _dataFor(type);
    if (type == AppToastType.success) {
      HapticService.success();
    } else if (type == AppToastType.error) {
      HapticService.error();
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          backgroundColor: Colors.transparent,
          content: TweenAnimationBuilder<double>(
            tween: Tween(begin: .96, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: data.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: data.foreground.withValues(alpha: .16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(data.icon, color: data.foreground, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: data.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  static _ToastData _dataFor(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return const _ToastData(
          icon: Icons.check_circle_rounded,
          background: AppColors.paleGreen,
          foreground: AppColors.primaryGreen,
        );
      case AppToastType.error:
        return const _ToastData(
          icon: Icons.error_rounded,
          background: Color(0xFFFFE9E7),
          foreground: AppColors.dangerRed,
        );
      case AppToastType.warning:
        return const _ToastData(
          icon: Icons.warning_rounded,
          background: Color(0xFFFFF4D8),
          foreground: Color(0xFF9A6700),
        );
      case AppToastType.info:
        return const _ToastData(
          icon: Icons.info_rounded,
          background: Color(0xFFE3F2FD),
          foreground: AppColors.gpsBlue,
        );
    }
  }
}

class _ToastData {
  const _ToastData({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}

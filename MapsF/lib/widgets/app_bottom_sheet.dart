import 'package:flutter/material.dart';

import '../app/app_colors.dart';

abstract final class AppBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .40),
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: .96, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              alignment: Alignment.bottomCenter,
              scale: value,
              child: child,
            );
          },
          child: SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 36),
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 10,
                bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AppBottomSheetHeader extends StatelessWidget {
  const AppBottomSheetHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = AppColors.primaryGreen,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFDDE5DF),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 18),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: .82, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: CircleAvatar(
            radius: 25,
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color, size: 26),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

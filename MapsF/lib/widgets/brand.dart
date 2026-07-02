import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72, this.light = false});

  static const assetPath = 'assets/images/geocampo_logo.png';

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final padding = size * .08;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: .10)
            : Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(size * .20),
        border: Border.all(
          color: light
              ? Colors.white.withValues(alpha: .24)
              : AppColors.primaryGreen.withValues(alpha: .10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? .16 : .08),
            blurRadius: size * .18,
            offset: Offset(0, size * .08),
          ),
        ],
      ),
      child: Image.asset(
        assetPath,
        width: size - padding * 2,
        height: size - padding * 2,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.terrain_rounded,
            size: size * .57,
            color: light ? Colors.white : AppColors.primaryGreen,
          );
        },
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

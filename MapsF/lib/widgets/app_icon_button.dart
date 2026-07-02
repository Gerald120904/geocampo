import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../services/haptic_service.dart';

enum AppIconButtonTone { neutral, open, edit, download, danger, warning, gps }

class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.tone = AppIconButtonTone.neutral,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final AppIconButtonTone tone;
  final bool loading;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(widget.tone);
    final radius = BorderRadius.circular(14);

    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _pressed && _enabled ? .93 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _enabled
                ? () {
                    HapticService.tap();
                    widget.onPressed?.call();
                  }
                : null,
            onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            borderRadius: radius,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _enabled ? colors.background : const Color(0xFFE5EAE6),
                borderRadius: radius,
                border: Border.all(color: colors.border),
                boxShadow: _enabled && colors.shadow
                    ? [
                        BoxShadow(
                          color: colors.foreground.withValues(alpha: .13),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : const [],
              ),
              child: Center(
                child: widget.loading
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.foreground,
                        ),
                      )
                    : Icon(
                        widget.icon,
                        size: 21,
                        color: _enabled
                            ? colors.foreground
                            : AppColors.textSecondary,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _IconToneColors _colorsFor(AppIconButtonTone tone) {
    switch (tone) {
      case AppIconButtonTone.open:
        return const _IconToneColors(
          background: AppColors.paleGreen,
          foreground: AppColors.primaryGreen,
          border: Color(0xFFC8DEC9),
          shadow: true,
        );
      case AppIconButtonTone.edit:
        return const _IconToneColors(
          background: Color(0xFFEAF5EC),
          foreground: AppColors.darkGreen,
          border: Color(0xFFC8DEC9),
        );
      case AppIconButtonTone.download:
        return const _IconToneColors(
          background: Color(0xFFE3F2FD),
          foreground: AppColors.gpsBlue,
          border: Color(0xFFBBD9F5),
        );
      case AppIconButtonTone.danger:
        return const _IconToneColors(
          background: Color(0xFFFFE9E7),
          foreground: AppColors.dangerRed,
          border: Color(0xFFF6B5AF),
        );
      case AppIconButtonTone.warning:
        return const _IconToneColors(
          background: Color(0xFFFFF4D8),
          foreground: Color(0xFF9A6700),
          border: Color(0xFFEED28A),
        );
      case AppIconButtonTone.gps:
        return const _IconToneColors(
          background: Color(0xFFE3F2FD),
          foreground: AppColors.gpsBlue,
          border: Color(0xFFBBD9F5),
        );
      case AppIconButtonTone.neutral:
        return const _IconToneColors(
          background: Colors.white,
          foreground: AppColors.textPrimary,
          border: Color(0xFFDDE5DF),
        );
    }
  }
}

class _IconToneColors {
  const _IconToneColors({
    required this.background,
    required this.foreground,
    required this.border,
    this.shadow = false,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final bool shadow;
}

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../services/haptic_service.dart';

class AppFloatingMapButton extends StatefulWidget {
  const AppFloatingMapButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;
  final bool active;

  @override
  State<AppFloatingMapButton> createState() => _AppFloatingMapButtonState();
}

class _AppFloatingMapButtonState extends State<AppFloatingMapButton> {
  bool pressed = false;

  bool get enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final foreground = widget.active ? AppColors.lightGreen : Colors.white;
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: pressed && enabled ? .94 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          color: AppColors.mapDark.withValues(alpha: .88),
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: .18),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled
                ? () {
                    HapticService.tap();
                    widget.onPressed?.call();
                  }
                : null,
            onTapDown: enabled ? (_) => setState(() => pressed = true) : null,
            onTapCancel: () => setState(() => pressed = false),
            onTapUp: (_) => setState(() => pressed = false),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.active
                      ? AppColors.lightGreen
                      : AppColors.primaryGreen.withValues(alpha: .34),
                ),
              ),
              child: Center(
                child: widget.loading
                    ? SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : Icon(widget.icon, color: foreground, size: 23),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

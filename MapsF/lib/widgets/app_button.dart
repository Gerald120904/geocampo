import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../services/haptic_service.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.success = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool success;
  final bool fullWidth;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(widget.variant);
    final radius = BorderRadius.circular(15);

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: widget.loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: colors.foreground,
              ),
            )
          : widget.success
          ? const Icon(Icons.check_rounded, key: ValueKey('success'), size: 20)
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: widget.fullWidth
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 19),
                  const SizedBox(width: 9),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    return AnimatedScale(
      scale: _pressed && _enabled ? .97 : 1,
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
            width: widget.fullWidth ? double.infinity : null,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: _enabled ? colors.background : colors.disabledBackground,
              borderRadius: radius,
              border: colors.border == null
                  ? null
                  : Border.all(color: colors.border!),
              boxShadow: _enabled && colors.shadow
                  ? [
                      BoxShadow(
                        color: colors.background.withValues(alpha: .22),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: _enabled ? colors.foreground : colors.disabledForeground,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: _enabled
                      ? colors.foreground
                      : colors.disabledForeground,
                ),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _AppButtonColors _colorsFor(AppButtonVariant variant) {
    switch (variant) {
      case AppButtonVariant.primary:
        return const _AppButtonColors(
          background: AppColors.primaryGreen,
          foreground: Colors.white,
          shadow: true,
        );
      case AppButtonVariant.secondary:
        return const _AppButtonColors(
          background: AppColors.paleGreen,
          foreground: AppColors.darkGreen,
          border: Color(0xFFC8DEC9),
        );
      case AppButtonVariant.danger:
        return const _AppButtonColors(
          background: Color(0xFFFFE9E7),
          foreground: AppColors.dangerRed,
          border: Color(0xFFF6B5AF),
        );
      case AppButtonVariant.ghost:
        return const _AppButtonColors(
          background: Colors.white,
          foreground: AppColors.textPrimary,
          border: Color(0xFFDDE5DF),
        );
    }
  }
}

class _AppButtonColors {
  const _AppButtonColors({
    required this.background,
    required this.foreground,
    this.border,
    this.shadow = false,
  });

  final Color background;
  final Color foreground;
  final Color? border;
  final bool shadow;

  Color get disabledBackground => const Color(0xFFE5EAE6);
  Color get disabledForeground => AppColors.textSecondary;
}

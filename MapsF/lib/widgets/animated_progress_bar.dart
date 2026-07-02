import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.label,
    this.active = true,
    this.color = AppColors.primaryGreen,
  });

  final double progress;
  final String? label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0, 1).toDouble();
    final percent = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '$percent%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            if (label != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFFE4EBE5)),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedValue,
                      child: child,
                    );
                  },
                  child: _MovingProgressFill(color: color, active: active),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MovingProgressFill extends StatefulWidget {
  const _MovingProgressFill({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<_MovingProgressFill> createState() => _MovingProgressFillState();
}

class _MovingProgressFillState extends State<_MovingProgressFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _MovingProgressFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            gradient: widget.active
                ? LinearGradient(
                    begin: Alignment(-1 + (_controller.value * 2), 0),
                    end: Alignment(1 + (_controller.value * 2), 0),
                    colors: [
                      widget.color,
                      Color.lerp(widget.color, Colors.white, .28)!,
                      widget.color,
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}

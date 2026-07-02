import 'package:flutter/material.dart';

class StatusChip extends StatefulWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.pulse = false,
    this.liveDot = false,
    this.bounceOnBuild = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool pulse;
  final bool liveDot;
  final bool bounceOnBuild;

  @override
  State<StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<StatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.pulse || widget.liveDot) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.pulse || widget.liveDot;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulseAlpha = widget.pulse ? .10 + (_controller.value * .08) : .12;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: pulseAlpha),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.color.withValues(
                alpha: widget.pulse ? .16 + (_controller.value * .12) : 0,
              ),
            ),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.liveDot) ...[
            _LiveDot(color: widget.color, animation: _controller),
            const SizedBox(width: 6),
          ] else if (widget.icon != null) ...[
            Icon(widget.icon, size: 14, color: widget.color),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: TextStyle(
              color: widget.color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    if (!widget.bounceOnBuild) return chip;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .88, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: chip,
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.color, required this.animation});

  final Color color;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .55 + (animation.value * .45)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: animation.value * .28),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

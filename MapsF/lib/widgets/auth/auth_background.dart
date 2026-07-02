import 'package:flutter/material.dart';

import '../../app/app_colors.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF07130D),
                  Color(0xFF102519),
                  Color(0xFFEEF5EE),
                ],
                stops: [0, .56, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _TopoAuthPainter())),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF07130D).withValues(alpha: .36),
                  Colors.transparent,
                  Colors.white.withValues(alpha: .24),
                ],
              ),
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}

class _TopoAuthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..strokeWidth = 1;
    final topo = Paint()
      ..color = AppColors.lightGreen.withValues(alpha: .12)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final parcel = Paint()
      ..color = const Color(0xFFE7D7B9).withValues(alpha: .18)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    for (var x = -size.height; x < size.width + size.height; x += 74) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x + size.height * .42, size.height),
        grid,
      );
    }

    for (var i = 0; i < 8; i++) {
      final y = size.height * (.12 + i * .095);
      final path = Path()..moveTo(size.width * .06, y);
      path.cubicTo(
        size.width * .24,
        y - 30,
        size.width * .34,
        y + 38,
        size.width * .52,
        y + 6,
      );
      path.cubicTo(
        size.width * .68,
        y - 24,
        size.width * .76,
        y + 22,
        size.width * .94,
        y - 8,
      );
      canvas.drawPath(path, topo);
    }

    final parcelTop = size.height * .76;
    for (var i = 0; i < 5; i++) {
      final x = size.width * (.12 + i * .18);
      canvas.drawLine(
        Offset(x, parcelTop),
        Offset(x + size.width * .12, size.height),
        parcel,
      );
    }
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.78 + i * .08);
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 26), parcel);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

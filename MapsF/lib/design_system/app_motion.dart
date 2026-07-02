import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const press = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 180);
  static const sheet = Duration(milliseconds: 220);
  static const check = Duration(milliseconds: 200);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve pop = Curves.easeOutBack;
}

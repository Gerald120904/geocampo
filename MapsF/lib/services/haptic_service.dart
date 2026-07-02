import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class HapticService {
  static Future<void> tap() => _run(HapticFeedback.lightImpact);

  static Future<void> success() => _run(HapticFeedback.mediumImpact);

  static Future<void> warning() => _run(HapticFeedback.heavyImpact);

  static Future<void> error() => _run(HapticFeedback.heavyImpact);

  static Future<void> _run(Future<void> Function() action) async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return;
    }
    await action();
  }
}

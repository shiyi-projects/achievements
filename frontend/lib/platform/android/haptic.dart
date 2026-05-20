import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 平台感知触觉反馈:仅在 Android/iOS 上触发,桌面端无操作。
abstract final class Haptic {
  static Future<void> light() => _trigger(HapticFeedback.lightImpact);
  static Future<void> medium() => _trigger(HapticFeedback.mediumImpact);
  static Future<void> heavy() => _trigger(HapticFeedback.heavyImpact);
  static Future<void> selection() => _trigger(HapticFeedback.selectionClick);

  static Future<void> _trigger(Future<void> Function() fn) async {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await fn();
    }
  }
}

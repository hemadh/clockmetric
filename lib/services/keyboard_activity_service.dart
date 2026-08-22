import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class KeyboardActivityService {
  static const MethodChannel _channel =
      MethodChannel('hamro_time_tracker/keyboard_activity');

  static Future<void> start() async {
    if (!Platform.isWindows) return;

    try {
      await _channel.invokeMethod('start');
      debugPrint('Keyboard tracking started');
    } catch (e) {
      debugPrint('Keyboard tracking start error: $e');
    }
  }

  static Future<int> getAndResetCount() async {
    if (!Platform.isWindows) return 0;

    try {
      final count =
          await _channel.invokeMethod<int>('getAndResetCount');

      return count ?? 0;
    } catch (e) {
      debugPrint('Keyboard count error: $e');
      return 0;
    }
  }

  static Future<int> stop() async {
    if (!Platform.isWindows) return 0;

    try {
      final count =
          await _channel.invokeMethod<int>('stop');

      debugPrint(
        'Keyboard tracking stopped. Final count: $count',
      );

      return count ?? 0;
    } catch (e) {
      debugPrint('Keyboard tracking stop error: $e');
      return 0;
    }
  }
}
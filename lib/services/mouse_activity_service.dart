import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MouseActivityService {
  static const MethodChannel _channel =
      MethodChannel(
    'hamro_time_tracker/mouse_activity',
  );

  static Future<void> start() async {
    if (!Platform.isWindows) return;

    try {
      await _channel.invokeMethod('start');

      debugPrint(
        'Mouse tracking started',
      );
    } catch (e) {
      debugPrint(
        'Mouse tracking start error: $e',
      );
    }
  }

  static Future<int> getAndResetCount() async {
    if (!Platform.isWindows) return 0;

    try {
      final count =
          await _channel.invokeMethod<int>(
        'getAndResetCount',
      );

      return count ?? 0;
    } catch (e) {
      debugPrint(
        'Mouse count error: $e',
      );

      return 0;
    }
  }

  static Future<int> stop() async {
    if (!Platform.isWindows) return 0;

    try {
      final count =
          await _channel.invokeMethod<int>(
        'stop',
      );

      debugPrint(
        'Mouse tracking stopped. Final count: $count',
      );

      return count ?? 0;
    } catch (e) {
      debugPrint(
        'Mouse tracking stop error: $e',
      );

      return 0;
    }
  }
}
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'keyboard_activity_service.dart';
import 'mouse_activity_service.dart';
import 'activity_sample_service.dart';

class KeyboardSampleSchedulerService {
  static Timer? _timer;

  static String? _timeEntryId;
  static DateTime? _sampleStart;

  static int _pendingKeyboardPresses = 0;
  static int _pendingMouseMovements = 0;

  static Future<void>? _activeFlush;

  static const Duration _sampleInterval =
      Duration(minutes: 5);

  // ==========================================
  // START
  // ==========================================

  static Future<void> start({
    required String timeEntryId,
  }) async {
    _timer?.cancel();
    _timer = null;

    _timeEntryId = timeEntryId;
    _sampleStart = DateTime.now();

    _pendingKeyboardPresses = 0;
    _pendingMouseMovements = 0;

    // Start both activity trackers.
    await KeyboardActivityService.start();
    await MouseActivityService.start();

    debugPrint(
      'Keyboard + mouse tracking started '
      'for entry: $timeEntryId',
    );

    _timer = Timer.periodic(
      _sampleInterval,
      (_) {
        _startFlush();
      },
    );

    debugPrint(
      '5-minute activity scheduler started',
    );
  }

  // ==========================================
  // START FLUSH
  // ==========================================

  static void _startFlush() {
    if (_activeFlush != null) {
      return;
    }

    final future = _flushSample();

    _activeFlush = future;

    future.whenComplete(() {
      _activeFlush = null;
    });
  }

  // ==========================================
  // SAVE 5-MINUTE SAMPLE
  // ==========================================

  static Future<void> _flushSample() async {
    final entryId = _timeEntryId;
    final start = _sampleStart;

    if (entryId == null || start == null) {
      return;
    }

    final end = DateTime.now();

    try {
      // Get and reset both counters.
      final counts = await Future.wait<int>([
        KeyboardActivityService.getAndResetCount(),
        MouseActivityService.getAndResetCount(),
      ]);

      final keyboardCount = counts[0];
      final mouseCount = counts[1];

      final totalKeyboard =
          _pendingKeyboardPresses +
          keyboardCount;

      final totalMouse =
          _pendingMouseMovements +
          mouseCount;

      final saved =
          await ActivitySampleService
              .saveKeyboardSample(
        timeEntryId: entryId,

        keyboardPresses:
            totalKeyboard,

        mouseMovements:
            totalMouse,

        sampleStart: start,
        sampleEnd: end,
      );

      if (saved) {
        _pendingKeyboardPresses = 0;
        _pendingMouseMovements = 0;

        _sampleStart = end;

        debugPrint(
          'Activity sample saved: '
          '$totalKeyboard keyboard presses, '
          '$totalMouse mouse movements',
        );
      } else {
        // Keep the counts so they are not lost.
        _pendingKeyboardPresses =
            totalKeyboard;

        _pendingMouseMovements =
            totalMouse;

        debugPrint(
          'Activity sample save failed. '
          'Keeping keyboard=$totalKeyboard, '
          'mouse=$totalMouse',
        );
      }
    } catch (e) {
      debugPrint(
        'Activity sample flush error: $e',
      );
    }
  }

  // ==========================================
  // STOP
  // ==========================================

  static Future<DateTime> stop() async {
    _timer?.cancel();
    _timer = null;

    // Wait for any active 5-minute save.
    if (_activeFlush != null) {
      try {
        await _activeFlush;
      } catch (_) {}
    }

    final entryId = _timeEntryId;
    final start = _sampleStart;
    final end = DateTime.now();

    // Stop both trackers and get the
    // remaining partial interval counts.
    final finalCounts =
        await Future.wait<int>([
      KeyboardActivityService.stop(),
      MouseActivityService.stop(),
    ]);

    final remainingKeyboard =
        finalCounts[0];

    final remainingMouse =
        finalCounts[1];

    if (entryId != null &&
        start != null) {
      final totalKeyboard =
          _pendingKeyboardPresses +
          remainingKeyboard;

      final totalMouse =
          _pendingMouseMovements +
          remainingMouse;

      final saved =
          await ActivitySampleService
              .saveKeyboardSample(
        timeEntryId: entryId,

        keyboardPresses:
            totalKeyboard,

        mouseMovements:
            totalMouse,

        sampleStart: start,
        sampleEnd: end,
      );

      if (saved) {
        debugPrint(
          'Final activity sample saved: '
          '$totalKeyboard keyboard presses, '
          '$totalMouse mouse movements',
        );
      } else {
        debugPrint(
          'Final activity sample '
          'could not be saved',
        );
      }
    }

    _timeEntryId = null;
    _sampleStart = null;

    _pendingKeyboardPresses = 0;
    _pendingMouseMovements = 0;

    _activeFlush = null;

    debugPrint(
      'Keyboard + mouse scheduler stopped',
    );

    return end;
  }
}
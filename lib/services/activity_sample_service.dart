import 'package:flutter/foundation.dart';
import '../main.dart';

class ActivitySampleService {
  static Future<bool> saveKeyboardSample({
    required String timeEntryId,
    required int keyboardPresses,
    int mouseMovements = 0,
    required DateTime sampleStart,
    required DateTime sampleEnd,
  }) async {
    if (timeEntryId.isEmpty ||
        currentUserId.isEmpty ||
        currentWorkspaceId.isEmpty) {
      debugPrint(
        'Activity sample skipped: missing required information',
      );
      return false;
    }

    try {
      await supabase.from('activity_samples').insert({
        'time_entry_id': timeEntryId,
        'employee_id': currentUserId,
        'employee_name': currentUserName,
        'workspace_id': currentWorkspaceId,

        'sample_start':
            sampleStart.toUtc().toIso8601String(),

        'sample_end':
            sampleEnd.toUtc().toIso8601String(),

        'keyboard_presses': keyboardPresses,

        'mouse_movements': mouseMovements,
      });

      debugPrint(
        'Activity sample saved: '
        '$keyboardPresses keyboard presses, '
        '$mouseMovements mouse movements',
      );

      return true;
    } catch (e) {
      debugPrint(
        'Activity sample save error: $e',
      );

      return false;
    }
  }
}
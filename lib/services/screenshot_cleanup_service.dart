import 'package:flutter/foundation.dart';

import '../main.dart';

class ScreenshotCleanupService {
  Future<void> deleteExpiredScreenshots() async {
    try {
      final session = supabase.auth.currentSession;

      if (session == null) {
        return;
      }

      final response = await supabase.functions.invoke(
        'delete-expired-screenshots',
      );

      if (response.status != 200) {
        debugPrint(
          'Screenshot cleanup failed: ${response.status} ${response.data}',
        );
        return;
      }

      debugPrint(
        'Screenshot cleanup result: ${response.data}',
      );
    } catch (error) {
      debugPrint(
        'Screenshot cleanup request failed: $error',
      );
    }
  }
}
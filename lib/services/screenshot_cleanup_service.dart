import 'package:flutter/foundation.dart';

import '../main.dart';

class ScreenshotCleanupService {
  static const String _bucketName = 'employee-screenshots';

  /// Calls the Supabase Edge Function that removes screenshots
  /// older than the configured retention period.
  ///
  /// IMPORTANT:
  /// The Edge Function itself must enforce the 14-day retention rule.
  Future<void> deleteExpiredScreenshots() async {
    try {
      final session = supabase.auth.currentSession;

      if (session == null) {
        debugPrint(
          'Screenshot cleanup skipped: no active Supabase session.',
        );
        return;
      }

      final response = await supabase.functions.invoke(
        'delete-expired-screenshots',
      );

      if (response.status != 200) {
        debugPrint(
          'Screenshot cleanup failed: '
          '${response.status} ${response.data}',
        );
        return;
      }

      debugPrint(
        'Screenshot cleanup result: ${response.data}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Screenshot cleanup request failed: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletes one screenshot safely.
  ///
  /// Order:
  /// 1. Delete the physical file from Supabase Storage.
  /// 2. Delete the matching database row.
  ///
  /// This avoids leaving orphaned Storage files that still consume quota.
  Future<bool> deleteScreenshot({
    required String screenshotId,
    required String imagePath,
  }) async {
    final cleanScreenshotId =
        screenshotId.trim();

    final cleanImagePath =
        imagePath.trim();

    if (cleanScreenshotId.isEmpty) {
      debugPrint(
        'Screenshot delete skipped: missing screenshot ID.',
      );
      return false;
    }

    try {
      // Delete the actual Storage object first.
      if (cleanImagePath.isNotEmpty) {
        try {
          await supabase.storage
              .from(_bucketName)
              .remove([
            cleanImagePath,
          ]);

          debugPrint(
            'Screenshot storage file deleted: '
            '$cleanImagePath',
          );
        } catch (error) {
          debugPrint(
            'Screenshot storage file delete failed: '
            '$error',
          );

          // Do not delete the database row if the file could not
          // be removed, otherwise the Storage object can become orphaned.
          return false;
        }
      }

      // Delete the matching database row.
      final deletedRows = await supabase
          .from('screenshots')
          .delete()
          .eq(
            'id',
            cleanScreenshotId,
          )
          .select('id');

      if (deletedRows.isEmpty) {
        debugPrint(
          'Screenshot database row was not deleted. '
          'Check the screenshots DELETE RLS policy.',
        );
        return false;
      }

      debugPrint(
        'Screenshot deleted successfully.',
      );

      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'Screenshot delete failed: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

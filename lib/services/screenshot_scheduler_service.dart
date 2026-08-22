import 'dart:async';

import 'package:encrypter_plus/encrypter_plus.dart' as encrypt;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'screenshot_capture_desktop.dart';

class ScreenshotSchedulerService {
  static final ScreenshotSchedulerService instance =
      ScreenshotSchedulerService._internal();

  ScreenshotSchedulerService._internal();

  Timer? _timer;
  String? _entryId;
  String? _projectId;

  bool _captureInProgress = false;

  // Change this only if your Supabase Storage bucket has another name.
  static const String _storageBucket = 'employee-screenshots';

  final encrypt.Key _key = encrypt.Key.fromUtf8(
    '12345678901234567890123456789012',
  );

  final encrypt.IV _iv = encrypt.IV.fromUtf8(
    '1234567890123456',
  );

  void start({
    required String entryId,
    required String? projectId,
  }) {
    if (entryId.trim().isEmpty) {
      print('Screenshot scheduler not started: entry ID is empty.');
      return;
    }

    if (currentUserRole.trim().toLowerCase() == 'admin') {
      print('Screenshot scheduler skipped for admin.');
      return;
    }

    if (_timer != null &&
        _timer!.isActive &&
        _entryId == entryId) {
      print(
        'Screenshot scheduler is already running '
        'for entry $entryId.',
      );
      return;
    }

    stop();

    _entryId = entryId;
    _projectId = projectId;

    print(
      'Screenshot scheduler started for entry: $_entryId',
    );

    // Take one screenshot soon after starting.
    Future.delayed(
      const Duration(seconds: 10),
      () async {
        if (_entryId == entryId) {
          await captureNow();
        }
      },
    );

    // TESTING: screenshot every 30 seconds.
    // Change this to Duration(minutes: 5) after testing.
    _timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) async {
        await captureNow();
      },
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;

    print(
      'Screenshot scheduler stopped. '
      'Previous entry: $_entryId',
    );

    _entryId = null;
    _projectId = null;
    _captureInProgress = false;
  }

  DateTime _calculateScreenshotExpiry(
    DateTime capturedAt,
  ) {
    final DateTime localCapturedAt =
        capturedAt.toLocal();

    // Monday = 1 and Sunday = 7.
    final int daysUntilSunday =
        DateTime.sunday - localCapturedAt.weekday;

    final DateTime captureWeekSunday = DateTime(
      localCapturedAt.year,
      localCapturedAt.month,
      localCapturedAt.day,
    ).add(
      Duration(days: daysUntilSunday),
    );

    // Delete at midnight on the second Monday.
    return captureWeekSunday.add(
      const Duration(days: 8),
    );
  }

  Future<bool> _isEntryStillRunning(
    String entryId,
  ) async {
    try {
      final Map<String, dynamic>? runningEntry =
          await supabase
              .from('time_entries')
              .select('id')
              .eq('id', entryId)
              .eq('employee_id', currentUserId)
              .eq('workspace_id', currentWorkspaceId)
              .filter('end_time', 'is', null)
              .maybeSingle();

      return runningEntry != null;
    } catch (error) {
      print(
        'Could not verify running time entry: $error',
      );

      // Do not stop screenshots because of a temporary
      // database or internet failure.
      return true;
    }
  }

  Future<void> captureNow() async {
    if (_captureInProgress) {
      print(
        'Screenshot skipped because another capture '
        'is still running.',
      );
      return;
    }

    final String? currentEntryId = _entryId;

    if (currentEntryId == null ||
        currentEntryId.trim().isEmpty) {
      print(
        'Screenshot skipped because no running '
        'entry is assigned.',
      );
      return;
    }

    if (currentUserRole.trim().toLowerCase() ==
        'admin') {
      return;
    }

    if (currentUserId.trim().isEmpty) {
      print(
        'Screenshot skipped because user ID is empty.',
      );
      return;
    }

    if (currentWorkspaceId.trim().isEmpty) {
      print(
        'Screenshot skipped because workspace ID '
        'is empty.',
      );
      return;
    }

    _captureInProgress = true;

    final DateTime capturedAt =
        DateTime.now().toUtc();

    String? uploadedStoragePath;

    try {
      final bool entryIsRunning =
          await _isEntryStillRunning(
        currentEntryId,
      );

      if (!entryIsRunning) {
        print(
          'Time entry is no longer running. '
          'Stopping screenshot scheduler.',
        );

        stop();
        return;
      }

      print(
        'Starting screenshot capture at '
        '${capturedAt.toLocal()}',
      );

      final List<int>? rawBytes =
          await ScreenshotCaptureService().capture();

      if (rawBytes == null || rawBytes.isEmpty) {
        print(
          'Screenshot capture returned no image data.',
        );
        return;
      }

      final encrypt.Encrypter encrypter =
          encrypt.Encrypter(
        encrypt.AES(
          _key,
          mode: encrypt.AESMode.cbc,
        ),
      );

      final encrypt.Encrypted encrypted =
          encrypter.encryptBytes(
        rawBytes,
        iv: _iv,
      );

      final String employeeName =
          currentUserName.trim().isEmpty
              ? 'employee'
              : currentUserName.trim();

      final String safeEmployeeName =
          employeeName.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );

      final int timestamp =
          capturedAt.millisecondsSinceEpoch;

      final String encryptedFileName =
          '${safeEmployeeName}_$timestamp.enc';

      final String storagePath =
          '$currentWorkspaceId/'
          '$currentUserId/'
          '$encryptedFileName';

      uploadedStoragePath = storagePath;

      print(
        'Uploading encrypted screenshot to: '
        '$storagePath',
      );

      await supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            storagePath,
            encrypted.bytes,
            fileOptions: const FileOptions(
              contentType:
                  'application/octet-stream',
              upsert: false,
            ),
          );

      print(
        'Screenshot uploaded to Supabase Storage.',
      );

      await supabase.from('screenshots').insert({
        'employee_id': currentUserId,
        'workspace_id': currentWorkspaceId,
        'employee_name': employeeName,
        'time_entry_id': currentEntryId,
        'project_id': _projectId,
        'image_path': 'private',
        'secure_image_path': storagePath,
        'image_url': null,
        'image_status': 'private',
        'captured_at':
            capturedAt.toIso8601String(),
        'expires_at':
            _calculateScreenshotExpiry(
          capturedAt,
        ).toUtc().toIso8601String(),
      });

      print(
        'Screenshot database record created '
        'successfully at ${capturedAt.toLocal()}',
      );
    } catch (error, stackTrace) {
      print('Screenshot capture failed: $error');
      print(stackTrace);

      // Remove uploaded file when the database insert fails.
      if (uploadedStoragePath != null) {
        try {
          await supabase.storage
              .from(_storageBucket)
              .remove([
            uploadedStoragePath,
          ]);

          print(
            'Removed incomplete screenshot upload.',
          );
        } catch (cleanupError) {
          print(
            'Could not remove incomplete upload: '
            '$cleanupError',
          );
        }
      }
    } finally {
      _captureInProgress = false;
    }
  }

  bool get isRunning =>
      _timer != null && _timer!.isActive;

  String? get activeEntryId => _entryId;
}
import 'dart:async';

import 'package:encrypter_plus/encrypter_plus.dart'
    as encrypt;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'screenshot_capture_desktop.dart';

class ScreenshotSchedulerService {
  static final ScreenshotSchedulerService instance =
      ScreenshotSchedulerService._internal();

  ScreenshotSchedulerService._internal();

  Timer? _watchdogTimer;
  Timer? _initialCaptureTimer;

  String? _entryId;
  String? _projectId;

  bool _captureInProgress = false;

  DateTime? _lastSuccessfulCaptureAt;

  static const Duration _screenshotInterval =
      Duration(minutes: 5);

  // Check frequently so a failed screenshot can be retried
  // instead of waiting another full 5 minutes.
  static const Duration _watchdogInterval =
      Duration(seconds: 30);

  static const String _storageBucket =
      'employee-screenshots';

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
    final String cleanEntryId = entryId.trim();

    if (cleanEntryId.isEmpty) {
      print(
        'Screenshot scheduler not started: '
        'entry ID is empty.',
      );
      return;
    }

    if (currentUserRole.trim().toLowerCase() ==
        'admin') {
      print(
        'Screenshot scheduler skipped for admin.',
      );
      return;
    }

    if (isRunning &&
        _entryId == cleanEntryId) {
      print(
        'Screenshot scheduler is already running '
        'for entry $cleanEntryId.',
      );
      return;
    }

    stop();

    _entryId = cleanEntryId;
    _projectId = projectId;
    _lastSuccessfulCaptureAt = null;

    print(
      'Screenshot scheduler started for entry: '
      '$_entryId',
    );

    // First screenshot shortly after timer starts.
    _initialCaptureTimer = Timer(
      const Duration(seconds: 10),
      () async {
        if (_entryId == cleanEntryId) {
          await captureNow();
        }
      },
    );

    // Instead of only trying once every 5 minutes,
    // check every 30 seconds whether a screenshot
    // is due.
    _watchdogTimer = Timer.periodic(
      _watchdogInterval,
      (_) async {
        await _checkAndCapture();
      },
    );
  }

  Future<void> _checkAndCapture() async {
    if (_captureInProgress) {
      return;
    }

    final String? currentEntryId = _entryId;

    if (currentEntryId == null ||
        currentEntryId.trim().isEmpty) {
      return;
    }

    final DateTime? lastCapture =
        _lastSuccessfulCaptureAt;

    // If there has never been a successful screenshot,
    // try immediately.
    if (lastCapture == null) {
      await captureNow();
      return;
    }

    final Duration elapsed =
        DateTime.now().toUtc().difference(
      lastCapture,
    );

    if (elapsed >= _screenshotInterval) {
      print(
        'Screenshot is due. '
        'Last successful screenshot: '
        '${lastCapture.toLocal()}',
      );

      await captureNow();
    }
  }

  void stop() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _initialCaptureTimer?.cancel();
    _initialCaptureTimer = null;

    print(
      'Screenshot scheduler stopped. '
      'Previous entry: $_entryId',
    );

    _entryId = null;
    _projectId = null;
    _lastSuccessfulCaptureAt = null;
  }

  DateTime _calculateScreenshotExpiry(
    DateTime capturedAt,
  ) {
    final DateTime localCapturedAt =
        capturedAt.toLocal();

    final int daysUntilSunday =
        DateTime.sunday -
            localCapturedAt.weekday;

    final DateTime captureWeekSunday =
        DateTime(
      localCapturedAt.year,
      localCapturedAt.month,
      localCapturedAt.day,
    ).add(
      Duration(
        days: daysUntilSunday,
      ),
    );

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
              .eq(
                'id',
                entryId,
              )
              .eq(
                'employee_id',
                currentUserId,
              )
              .eq(
                'workspace_id',
                currentWorkspaceId,
              )
              .filter(
                'end_time',
                'is',
                null,
              )
              .maybeSingle();

      return runningEntry != null;
    } catch (error) {
      print(
        'Could not verify running time entry: '
        '$error',
      );

      // Temporary internet/database issues should
      // not immediately stop screenshot monitoring.
      return true;
    }
  }

  Future<void> captureNow() async {
    if (_captureInProgress) {
      print(
        'Screenshot skipped because another '
        'capture is still running.',
      );
      return;
    }

    final String? currentEntryId =
        _entryId;

    if (currentEntryId == null ||
        currentEntryId.trim().isEmpty) {
      print(
        'Screenshot skipped because no running '
        'entry is assigned.',
      );
      return;
    }

    if (currentUserRole
            .trim()
            .toLowerCase() ==
        'admin') {
      return;
    }

    if (currentUserId.trim().isEmpty) {
      print(
        'Screenshot skipped because '
        'user ID is empty.',
      );
      return;
    }

    if (currentWorkspaceId
        .trim()
        .isEmpty) {
      print(
        'Screenshot skipped because '
        'workspace ID is empty.',
      );
      return;
    }

    _captureInProgress = true;

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

      // Make sure the active entry did not change
      // while the database request was running.
      if (_entryId != currentEntryId) {
        print(
          'Screenshot cancelled because '
          'active entry changed.',
        );
        return;
      }

      final DateTime capturedAt =
          DateTime.now().toUtc();

      print(
        'Starting screenshot capture at '
        '${capturedAt.toLocal()}',
      );

      final List<int>? rawBytes =
          await ScreenshotCaptureService()
              .capture();

      if (rawBytes == null ||
          rawBytes.isEmpty) {
        print(
          'Screenshot capture returned no '
          'image data. Will retry soon.',
        );
        return;
      }

      // Check again in case timer was stopped
      // during screenshot capture.
      if (_entryId != currentEntryId) {
        print(
          'Screenshot cancelled because '
          'timer stopped or entry changed.',
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
        RegExp(
          r'[^a-zA-Z0-9_-]',
        ),
        '_',
      );

      final int timestamp =
          capturedAt
              .millisecondsSinceEpoch;

      final String encryptedFileName =
          '${safeEmployeeName}_'
          '$timestamp.enc';

      final String storagePath =
          '$currentWorkspaceId/'
          '$currentUserId/'
          '$encryptedFileName';

      uploadedStoragePath =
          storagePath;

      print(
        'Uploading encrypted screenshot to: '
        '$storagePath',
      );

      await supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            storagePath,
            encrypted.bytes,
            fileOptions:
                const FileOptions(
              contentType:
                  'application/octet-stream',
              upsert: false,
            ),
          );

      print(
        'Screenshot uploaded to '
        'Supabase Storage.',
      );

      // Timer might have been stopped while upload
      // was in progress.
      if (_entryId != currentEntryId) {
        print(
          'Timer stopped during upload. '
          'Removing screenshot.',
        );

        try {
          await supabase.storage
              .from(_storageBucket)
              .remove([
            storagePath,
          ]);
        } catch (error) {
          print(
            'Could not remove screenshot: '
            '$error',
          );
        }

        uploadedStoragePath = null;

        return;
      }

      await supabase
          .from('screenshots')
          .insert({
        'employee_id':
            currentUserId,
        'workspace_id':
            currentWorkspaceId,
        'employee_name':
            employeeName,
        'time_entry_id':
            currentEntryId,
        'project_id':
            _projectId,
        'image_path':
            'private',
        'secure_image_path':
            storagePath,
        'image_url':
            null,
        'image_status':
            'private',
        'captured_at':
            capturedAt
                .toIso8601String(),
        'expires_at':
            _calculateScreenshotExpiry(
          capturedAt,
        ).toUtc().toIso8601String(),
      });

      // Only update this AFTER both storage upload
      // and database insert succeed.
      _lastSuccessfulCaptureAt =
          capturedAt;

      uploadedStoragePath = null;

      print(
        'Screenshot saved successfully at '
        '${capturedAt.toLocal()}. '
        'Next screenshot due in '
        '5 minutes.',
      );
    } catch (error, stackTrace) {
      print(
        'Screenshot capture failed: '
        '$error',
      );

      print(stackTrace);

      // Because our watchdog checks every 30 seconds,
      // failed captures will be retried soon.
      if (uploadedStoragePath != null) {
        try {
          await supabase.storage
              .from(_storageBucket)
              .remove([
            uploadedStoragePath,
          ]);

          print(
            'Removed incomplete '
            'screenshot upload.',
          );
        } catch (cleanupError) {
          print(
            'Could not remove incomplete '
            'upload: $cleanupError',
          );
        }
      }
    } finally {
      _captureInProgress = false;
    }
  }

  bool get isRunning =>
      _watchdogTimer != null &&
      _watchdogTimer!.isActive &&
      _entryId != null;

  String? get activeEntryId =>
      _entryId;

  DateTime? get lastSuccessfulCaptureAt =>
      _lastSuccessfulCaptureAt;
}
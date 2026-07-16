import 'dart:async';

import 'package:encrypt/encrypt.dart' as encrypt;

import '../main.dart';
import 'screenshot_capture_service.dart';

class ScreenshotSchedulerService {
  static final ScreenshotSchedulerService instance =
      ScreenshotSchedulerService._internal();

  ScreenshotSchedulerService._internal();

  Timer? _timer;
  String? _entryId;
  String? _projectId;

  final _key = encrypt.Key.fromUtf8(
    '12345678901234567890123456789012',
  );

  final _iv = encrypt.IV.fromUtf8(
    '1234567890123456',
  );

  void start({
    required String entryId,
    required String? projectId,
  }) {
    if (currentUserRole == 'admin') return;

    if (_timer != null && _entryId == entryId) {
      return;
    }

    stop();

    _entryId = entryId;
    _projectId = projectId;

    _timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        captureNow();
      },
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _entryId = null;
    _projectId = null;
  }

  Future<void> captureNow() async {
    if (_entryId == null) return;
    if (currentUserRole == 'admin') return;
    if (currentUserId.isEmpty) return;
    if (currentWorkspaceId.isEmpty) return;

    try {
      final rawBytes =
          await ScreenshotCaptureService().capture();

      // On Web, screenshot capture returns null.
      if (rawBytes == null || rawBytes.isEmpty) {
        return;
      }

      final encrypter = encrypt.Encrypter(
        encrypt.AES(
          _key,
          mode: encrypt.AESMode.cbc,
        ),
      );

      final encrypted = encrypter.encryptBytes(
        rawBytes,
        iv: _iv,
      );

      final safeEmployeeName = currentUserName.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );

      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      final encryptedFileName =
          '${safeEmployeeName}_$timestamp.enc';

      final storagePath =
          '$currentWorkspaceId/'
          '$currentUserId/'
          '$encryptedFileName';

      await supabase.storage
          .from('employee-screenshots')
          .uploadBinary(
            storagePath,
            encrypted.bytes,
          );

      final capturedAt = DateTime.now();

      await supabase.from('screenshots').insert({
        'employee_id': currentUserId,
        'workspace_id': currentWorkspaceId,
        'employee_name': currentUserName,
        'time_entry_id': _entryId,
        'project_id': _projectId,
        'image_path': 'private',
        'secure_image_path': storagePath,
        'image_url': null,
        'image_status': 'private',
        'captured_at': capturedAt.toIso8601String(),
        'expires_at': capturedAt
            .add(const Duration(hours: 24))
            .toIso8601String(),
      });
    } catch (error) {
      print('Screenshot capture failed: $error');
    }
  }
}
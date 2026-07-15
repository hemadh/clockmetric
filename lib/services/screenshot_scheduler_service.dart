import 'dart:async';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import 'windows_screenshot_service.dart';

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
      print('Screenshot scheduler already running');
      return;
    }

    stop();

    _entryId = entryId;
    _projectId = projectId;

    print('Global screenshot scheduler started');

    _timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => captureNow(),
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
      final directory = await getApplicationDocumentsDirectory();

      final safeEmployeeName = currentUserName
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final localPngName =
          '${safeEmployeeName}_$timestamp.png';

      final localEncName =
          '${safeEmployeeName}_$timestamp.enc';

      final localPngPath =
          '${directory.path}\\$localPngName';

      final localEncPath =
          '${directory.path}\\$localEncName';

      final file =
          await WindowsScreenshotService().captureFullScreen(
        localPngPath,
      );

      if (file == null || !await file.exists()) {
        print('Screenshot failed');
        return;
      }

      final rawBytes = await file.readAsBytes();

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

      final encryptedFile = File(localEncPath);

      await encryptedFile.writeAsBytes(
        encrypted.bytes,
      );

      final storagePath =
          '$currentWorkspaceId/$currentUserId/$localEncName';

      await supabase.storage
          .from('employee-screenshots')
          .upload(
            storagePath,
            encryptedFile,
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

      if (await file.exists()) {
        await file.delete();
      }

      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }

      print('Encrypted screenshot uploaded successfully');
    } catch (e) {
      print('Screenshot failed: $e');
    }
  }
}
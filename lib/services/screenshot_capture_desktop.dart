import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'windows_screenshot_service.dart';

class ScreenshotCaptureService {
  Future<Uint8List?> capture() async {
    final directory =
        await getApplicationDocumentsDirectory();

    final timestamp =
        DateTime.now().millisecondsSinceEpoch;

    final path =
        '${directory.path}${Platform.pathSeparator}'
        'floratime_capture_$timestamp.png';

    final file = await WindowsScreenshotService()
        .captureFullScreen(path);

    if (file == null || !await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();

    await file.delete();

    return bytes;
  }
}
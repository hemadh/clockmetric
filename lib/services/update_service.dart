import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String? releaseNotes;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    this.releaseNotes,
    required this.forceUpdate,
  });

  factory AppUpdateInfo.fromMap(Map<String, dynamic> map) {
    return AppUpdateInfo(
      version: map['version']?.toString() ?? '',
      buildNumber: int.tryParse(
            map['build_number']?.toString() ?? '',
          ) ??
          0,
      downloadUrl: map['download_url']?.toString() ?? '',
      releaseNotes: map['release_notes']?.toString(),
      forceUpdate: map['force_update'] == true,
    );
  }
}

class UpdateService {
  final SupabaseClient _supabase = Supabase.instance.client;

Future<AppUpdateInfo?> checkForUpdate() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();

    final currentVersion = packageInfo.version.trim();
    final currentBuild =
        int.tryParse(packageInfo.buildNumber) ?? 0;

    final response = await _supabase
        .from('app_updates')
        .select()
        .eq('platform', 'windows')
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final update = AppUpdateInfo.fromMap(response);

    if (update.version.isEmpty ||
        update.buildNumber <= 0 ||
        update.downloadUrl.isEmpty) {
      return null;
    }

    // -------------------------------------------------------
    // PERMANENT UPDATE CHECK
    //
    // If the installed version is already the same as the
    // version published in Supabase, NEVER show it again.
    // -------------------------------------------------------
    if (currentVersion == update.version.trim()) {
      return null;
    }

    // Different version + newer build = offer update.
    if (update.buildNumber > currentBuild) {
      return update;
    }

    return null;
  } catch (error) {
    print('Update check failed: $error');
    return null;
  }
}

  /// Downloads the installer and launches it.
  Future<void> downloadAndInstallUpdate(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    IOSink? sink;

    try {
      final uri = Uri.tryParse(update.downloadUrl);

      if (uri == null ||
          !(uri.scheme == 'https' || uri.scheme == 'http')) {
        throw Exception('The update download URL is invalid.');
      }

      final request = http.Request('GET', uri);
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download update. '
          'Server returned ${response.statusCode}.',
        );
      }

      final tempDir = await getTemporaryDirectory();

      final installer = File(
        '${tempDir.path}'
        '${Platform.pathSeparator}'
        'ClockMetric_Setup_${update.version}.exe',
      );

      if (await installer.exists()) {
        await installer.delete();
      }

      sink = installer.openWrite();

      final totalBytes = response.contentLength ?? 0;
      var downloadedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (onProgress != null && totalBytes > 0) {
          final progress = downloadedBytes / totalBytes;

          onProgress(
            progress.clamp(0.0, 1.0).toDouble(),
          );
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (!await installer.exists()) {
        throw Exception(
          'The installer could not be saved.',
        );
      }

      final installerSize = await installer.length();

      if (installerSize == 0) {
        throw Exception(
          'The downloaded installer is empty.',
        );
      }

      await Process.start(
        installer.path,
        const [],
        mode: ProcessStartMode.detached,
        runInShell: true,
      );

      exit(0);
    } catch (error) {
      await sink?.close();
      rethrow;
    }
  }
}
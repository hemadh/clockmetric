import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';

class UpdateService {
  static const String versionUrl =
       'https://zakvowocgunowgxxslqm.supabase.co/storage/v1/object/public/app-updates/version.json';

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http
          .get(Uri.parse(versionUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final latestVersion =
          decoded['version']?.toString().trim() ?? '';

      final downloadUrl =
          decoded['download']?.toString().trim() ?? '';

      if (latestVersion.isEmpty || downloadUrl.isEmpty) {
        return null;
      }

      if (_isNewer(latestVersion, currentVersion)) {
        return decoded;
      }

      return null;
    } catch (error) {
      debugPrint('Update check failed: $error');
      return null;
    }
  }

  Future<void> showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> update,
  ) async {
    final version =
        update['version']?.toString() ?? 'New version';

    final changesValue = update['changes'];

    final changes = changesValue is List
        ? changesValue
            .map((item) => item.toString())
            .toList()
        : <String>[];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool downloading = false;
        double progress = 0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> startUpdate() async {
              if (downloading) return;

              setDialogState(() {
                downloading = true;
                progress = 0;
              });

              try {
                await downloadAndInstall(
                  update: update,
                  onProgress: (value) {
                    if (!dialogContext.mounted) return;

                    setDialogState(() {
                      progress = value;
                    });
                  },
                );
              } catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  downloading = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Update failed: $error',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.system_update_alt),
                  SizedBox(width: 12),
                  Text('FloraTime Update'),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version $version is available.',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (changes.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'What’s new:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...changes.map(
                        (change) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(
                                child: Text(change),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (downloading) ...[
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: progress > 0
                            ? progress
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress > 0
                            ? 'Downloading ${(progress * 100).toStringAsFixed(0)}%'
                            : 'Preparing download...',
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: downloading
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  child: const Text('Later'),
                ),
                FilledButton.icon(
                  onPressed:
                      downloading ? null : startUpdate,
                  icon: const Icon(Icons.download),
                  label: Text(
                    downloading
                        ? 'Downloading...'
                        : 'Update Now',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> downloadAndInstall({
    required Map<String, dynamic> update,
    required ValueChanged<double> onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw Exception(
        'Automatic installation is currently available only on Windows.',
      );
    }

    final downloadUrl =
        update['download']?.toString().trim() ?? '';

    if (downloadUrl.isEmpty) {
      throw Exception('The update download URL is missing.');
    }

    final request =
        http.Request('GET', Uri.parse(downloadUrl));

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception(
        'Server returned ${response.statusCode}.',
      );
    }

    final tempDirectory = await getTemporaryDirectory();

    final installerFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'FloraTime_Update.exe',
    );

    final sink = installerFile.openWrite();

    final totalBytes = response.contentLength ?? 0;
    int downloadedBytes = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;

      if (totalBytes > 0) {
        onProgress(downloadedBytes / totalBytes);
      }
    }

    await sink.flush();
    await sink.close();

    if (!await installerFile.exists()) {
      throw Exception(
        'The update installer was not downloaded.',
      );
    }

    await runExecutableArguments(
      installerFile.path,
      [
        '/SILENT',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ],
      runInShell: true,
    );

    exit(0);
  }

  bool _isNewer(
    String latest,
    String current,
  ) {
    final latestParts = _parseVersion(latest);
    final currentParts = _parseVersion(current);

    final length = latestParts.length >
            currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (int index = 0; index < length; index++) {
      final latestValue = index < latestParts.length
          ? latestParts[index]
          : 0;

      final currentValue = index < currentParts.length
          ? currentParts[index]
          : 0;

      if (latestValue > currentValue) return true;
      if (latestValue < currentValue) return false;
    }

    return false;
  }

  List<int> _parseVersion(String version) {
    final cleanVersion = version
        .split('+')
        .first
        .split('-')
        .first;

    return cleanVersion.split('.').map((part) {
      return int.tryParse(part) ?? 0;
    }).toList();
  }
}
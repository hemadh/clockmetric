import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';

class UpdateChecker {
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final latestResponse = await supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'latest_version')
          .single();

      final downloadResponse = await supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'download_url')
          .single();

      final latestVersion = latestResponse['setting_value']?.toString();
      final downloadUrl = downloadResponse['setting_value']?.toString();

      if (latestVersion == null) return;

      if (latestVersion != appVersion) {
        if (!context.mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Update Available'),
            content: Text(
              'Version $latestVersion is available.\n\nCurrent version: $appVersion',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (downloadUrl != null && downloadUrl.isNotEmpty) {
                    await launchUrl(
                      Uri.parse(downloadUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }
}
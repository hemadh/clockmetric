import 'package:flutter/foundation.dart';

import '../main.dart';
class AuthService {
String get deviceName {
  if (kIsWeb) {
    return 'Web Browser';
  }

  return '${defaultTargetPlatform.name} Device';
}

String get platformName {
  if (kIsWeb) {
    return 'Web';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
      return 'Windows';
    case TargetPlatform.macOS:
      return 'macOS';
    case TargetPlatform.linux:
      return 'Linux';
    case TargetPlatform.android:
      return 'Android';
    case TargetPlatform.iOS:
      return 'iOS';
    case TargetPlatform.fuchsia:
      return 'Fuchsia';
  }
}

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    debugPrint('LOGIN: starting Supabase sign-in');
debugPrint('LOGIN EMAIL: $email');

debugPrint('LOGIN: starting Supabase sign-in');
debugPrint('LOGIN EMAIL: $email');

debugPrint('LOGIN: starting Supabase sign-in');
debugPrint('LOGIN EMAIL: $email');

final response = await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);

debugPrint('LOGIN: Supabase authentication succeeded');

debugPrint('LOGIN: Supabase authentication succeeded');

debugPrint('LOGIN: Supabase authentication succeeded');

    final user = response.user;
    debugPrint('LOGIN USER ID: ${user?.id}');

    if (user == null) {
      throw Exception("Login failed.");
    }

    final profile = await supabase
        .from('profiles')
        .select(
          '''
          full_name,
          email,
          role,
          workspace_id,
          approval_status,
          is_active
          ''',
        )
        .eq('id', user.id)
        .single();

    final workspaceId = profile['workspace_id']?.toString() ?? '';

    if (profile['approval_status'] != 'approved') {
      await _logLogin(
        userId: user.id,
        email: email,
        workspaceId: workspaceId,
        status: 'pending_approval',
      );

      await supabase.auth.signOut();

      throw Exception("Your account is waiting for admin approval.");
    }

    if (profile['is_active'] != true) {
      await _logLogin(
        userId: user.id,
        email: email,
        workspaceId: workspaceId,
        status: 'inactive',
      );

      await supabase.auth.signOut();

      throw Exception("Your account has been disabled.");
    }

    await _registerOrUpdateDevice(
      user.id,
      workspaceId,
    );

    currentUserName = profile['full_name'] ?? email;
    currentUserRole = profile['role'] ?? 'employee';
    currentWorkspaceId = workspaceId;

    final workspace = await supabase
        .from('workspaces')
        .select('workspace_name')
        .eq('id', workspaceId)
        .single();

    currentWorkspaceName = workspace['workspace_name'];

    await supabase.from('profiles').update({
      'last_login': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    await _logLogin(
      userId: user.id,
      email: email,
      workspaceId: workspaceId,
      status: 'success',
    );

    return profile;
  }

  Future<void> _registerOrUpdateDevice(
    String userId,
    String workspaceId,
  ) async {
    final existing = await supabase
        .from('user_devices')
        .select()
        .eq('user_id', userId)
        .eq('device_name', deviceName)
        .eq('platform', platformName)
        .maybeSingle();

    if (existing == null) {
      await supabase.from('user_devices').insert({
        'user_id': userId,
        'workspace_id': workspaceId,
        'device_name': deviceName,
        'platform': platformName,
        'last_seen': DateTime.now().toIso8601String(),
        'is_allowed': true,
      });
    } else {
      if (existing['is_allowed'] != true) {
        await supabase.auth.signOut();

        throw Exception(
          "This device has been blocked by your administrator.",
        );
      }

      await supabase.from('user_devices').update({
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
    }
  }

  Future<void> _logLogin({
    required String userId,
    required String email,
    required String workspaceId,
    required String status,
  }) async {
    await supabase.from('login_audit_logs').insert({
      'user_id': userId,
      'email': email,
      'workspace_id': workspaceId,
      'device_name': deviceName,
      'platform': platformName,
      'status': status,
      'login_time': DateTime.now().toIso8601String(),
    });
  }
}
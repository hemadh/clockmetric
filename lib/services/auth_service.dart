import 'dart:io';

import '../main.dart';

class AuthService {
  String get deviceName {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Unknown Device';
    }
  }

  String get platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';

    return 'Unknown';
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;

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
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screenshot_scheduler_service.dart';

enum TimerAutoStopReason {
  internetLost,
  logout,
  sessionEnded,
  appInterrupted,
}

enum _TimerProbeState {
  running,
  stopped,
  unreachable,
}

class TimerSafetyEvent {
  final String entryId;
  final DateTime stoppedAt;
  final TimerAutoStopReason reason;

  const TimerSafetyEvent({
    required this.entryId,
    required this.stoppedAt,
    required this.reason,
  });
}

class TimerSafetyService {
  TimerSafetyService._();

  static final TimerSafetyService instance =
      TimerSafetyService._();

  final ValueNotifier<TimerSafetyEvent?>
      forcedStopNotifier =
      ValueNotifier<TimerSafetyEvent?>(null);

  SupabaseClient get _supabase =>
      Supabase.instance.client;

  static const Duration _watchInterval =
      Duration(seconds: 5);

  static const Duration _requestTimeout =
      Duration(seconds: 5);

  // Do not freeze/stop the timer because of one slow Supabase request.
  // We only treat internet as lost after repeated failures for a short
  // continuous grace period. The recorded stop time is still the last
  // confirmed online moment, so offline time is not counted.
  static const Duration _offlineGracePeriod =
      Duration(seconds: 15);

  static const int _requiredFailedChecks = 3;

  static const String _activeEntryKey =
      'clockmetric_timer_active_entry_id';
  static const String _activeUserKey =
      'clockmetric_timer_active_user_id';
  static const String _activeWorkspaceKey =
      'clockmetric_timer_active_workspace_id';
  static const String _activeProjectKey =
      'clockmetric_timer_active_project_id';
  static const String _activeStartKey =
      'clockmetric_timer_active_start_time';
  static const String _lastOnlineKey =
      'clockmetric_timer_last_online_at';

  static const String _pendingEntryKey =
      'clockmetric_timer_pending_entry_id';
  static const String _pendingUserKey =
      'clockmetric_timer_pending_user_id';
  static const String _pendingWorkspaceKey =
      'clockmetric_timer_pending_workspace_id';
  static const String _pendingStartKey =
      'clockmetric_timer_pending_start_time';
  static const String _pendingStopKey =
      'clockmetric_timer_pending_stop_time';
  static const String _pendingReasonKey =
      'clockmetric_timer_pending_reason';

  static const MethodChannel _keyboardChannel =
      MethodChannel(
    'hamro_time_tracker/keyboard_activity',
  );

  static const MethodChannel _mouseChannel =
      MethodChannel(
    'hamro_time_tracker/mouse_activity',
  );

  Timer? _watchdogTimer;
  Timer? _recoveryTimer;

  bool _checkingConnection = false;
  bool _handlingForcedStop = false;
  bool _syncingPendingStop = false;

  int _consecutiveFailedChecks = 0;
  DateTime? _firstFailedCheckAt;

  String _userId = '';
  String _workspaceId = '';

  String? _activeEntryId;
  String? _activeProjectId;
  DateTime? _activeStartTime;
  DateTime? _lastOnlineAt;

  String? get activeEntryId => _activeEntryId;

  Future<void> startForEmployee({
    required String userId,
    required String workspaceId,
  }) async {
    final cleanUserId = userId.trim();
    final cleanWorkspaceId = workspaceId.trim();

    if (cleanUserId.isEmpty ||
        cleanWorkspaceId.isEmpty) {
      return;
    }

    final switchingAccount =
        _userId.isNotEmpty &&
        (_userId != cleanUserId ||
            _workspaceId != cleanWorkspaceId);

    if (switchingAccount) {
      detachUser();
    }

    _userId = cleanUserId;
    _workspaceId = cleanWorkspaceId;

    // First finish any stop that was saved while offline.
    await syncPendingStopForCurrentUser();

    // Historical rows in the temporary backend are already normalized.
    // Do not mutate old entries automatically on every login.
    // await repairLegacyAutomaticStopRows();

    // Restore a genuinely running server timer instead of automatically
    // freezing it just because ClockMetric restarted/hot-restarted.
    await _restoreRunningTimerAfterAppStart();

    if (_activeEntryId != null) {
      _startWatchdog();
    }
  }

  void detachUser() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _recoveryTimer?.cancel();
    _recoveryTimer = null;

    _checkingConnection = false;
    _handlingForcedStop = false;
    _syncingPendingStop = false;
    _resetConnectionFailures();

    _userId = '';
    _workspaceId = '';

    _activeEntryId = null;
    _activeProjectId = null;
    _activeStartTime = null;
    _lastOnlineAt = null;
  }

  Future<bool> canStartTimer({
    required String userId,
    required String workspaceId,
  }) async {
    final cleanUserId = userId.trim();
    final cleanWorkspaceId = workspaceId.trim();

    if (cleanUserId.isEmpty ||
        cleanWorkspaceId.isEmpty) {
      return false;
    }

    _userId = cleanUserId;
    _workspaceId = cleanWorkspaceId;

    return _isBackendReachable();
  }

  Future<void> registerRunningTimer({
    required String entryId,
    required DateTime startTime,
    required String userId,
    required String workspaceId,
    String? projectId,
  }) async {
    final cleanEntryId = entryId.trim();
    final cleanUserId = userId.trim();
    final cleanWorkspaceId = workspaceId.trim();

    if (cleanEntryId.isEmpty ||
        cleanUserId.isEmpty ||
        cleanWorkspaceId.isEmpty) {
      return;
    }

    _userId = cleanUserId;
    _workspaceId = cleanWorkspaceId;

    _activeEntryId = cleanEntryId;
    _activeProjectId = projectId?.trim();
    _activeStartTime = startTime.toUtc();
    _lastOnlineAt = DateTime.now().toUtc();
    _resetConnectionFailures();

    await _saveActiveRegistration();

    _recoveryTimer?.cancel();
    _recoveryTimer = null;

    _startWatchdog();

    // Confirm immediately that the backend is reachable.
    unawaited(_checkConnection());
  }

  Future<void> clearRunningTimer({
    required String entryId,
  }) async {
    if (_activeEntryId != entryId) {
      final prefs =
          await SharedPreferences.getInstance();

      final storedEntry =
          prefs.getString(_activeEntryKey);

      if (storedEntry == entryId) {
        await _clearActiveRegistration(prefs);
      }

      return;
    }

    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _activeEntryId = null;
    _activeProjectId = null;
    _activeStartTime = null;
    _lastOnlineAt = null;
    _resetConnectionFailures();

    final prefs =
        await SharedPreferences.getInstance();

    await _clearActiveRegistration(prefs);
  }

  Future<void> stopBeforeLogout({
    String? userId,
    String? workspaceId,
    TimerAutoStopReason reason =
        TimerAutoStopReason.logout,
  }) async {
    if (userId != null &&
        userId.trim().isNotEmpty) {
      _userId = userId.trim();
    }

    if (workspaceId != null &&
        workspaceId.trim().isNotEmpty) {
      _workspaceId = workspaceId.trim();
    }

    await _stopTrackingLocally();

    final prefs =
        await SharedPreferences.getInstance();

    await _loadActiveRegistrationFromPrefsIfNeeded(
      prefs,
    );

    if (_activeEntryId == null ||
        _activeStartTime == null) {
      // A running row may exist even if the Timer screen was
      // never opened during this session.
      await _loadRunningEntryFromServerIfPossible();
    }

    if (_activeEntryId != null &&
        _activeStartTime != null) {
      final stopTime = DateTime.now().toUtc();

      final event = TimerSafetyEvent(
        entryId: _activeEntryId!,
        stoppedAt: stopTime,
        reason: reason,
      );

      await _savePendingStop(
        prefs: prefs,
        entryId: _activeEntryId!,
        userId: _userId,
        workspaceId: _workspaceId,
        startTime: _activeStartTime!,
        stopTime: stopTime,
        reason: reason,
      );

      await _clearActiveRegistration(prefs);

      _watchdogTimer?.cancel();
      _watchdogTimer = null;

      _activeEntryId = null;
      _activeProjectId = null;
      _activeStartTime = null;
      _lastOnlineAt = null;
      _resetConnectionFailures();

      forcedStopNotifier.value = event;

      // Logout is normally online. Sync while the user's
      // authenticated session is still available.
      await syncPendingStopForCurrentUser();
    }

    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  Future<void> handleSignedOut() async {
    await _stopTrackingLocally();

    final prefs =
        await SharedPreferences.getInstance();

    await _loadActiveRegistrationFromPrefsIfNeeded(
      prefs,
    );

    if (_activeEntryId != null &&
        _activeStartTime != null) {
      final stopTime = DateTime.now().toUtc();

      await _savePendingStop(
        prefs: prefs,
        entryId: _activeEntryId!,
        userId: _userId,
        workspaceId: _workspaceId,
        startTime: _activeStartTime!,
        stopTime: stopTime,
        reason: TimerAutoStopReason.sessionEnded,
      );

      forcedStopNotifier.value =
          TimerSafetyEvent(
        entryId: _activeEntryId!,
        stoppedAt: stopTime,
        reason: TimerAutoStopReason.sessionEnded,
      );

      await _clearActiveRegistration(prefs);
    }

    detachUser();
  }

  Future<void> syncPendingStopForCurrentUser()
      async {
    if (_syncingPendingStop) return;

    final authUser = _supabase.auth.currentUser;

    if (authUser == null) return;

    final prefs =
        await SharedPreferences.getInstance();

    final entryId =
        prefs.getString(_pendingEntryKey) ?? '';
    final pendingUserId =
        prefs.getString(_pendingUserKey) ?? '';
    final pendingWorkspaceId =
        prefs.getString(_pendingWorkspaceKey) ?? '';
    final startText =
        prefs.getString(_pendingStartKey);
    final stopText =
        prefs.getString(_pendingStopKey);
    final reasonText =
        prefs.getString(_pendingReasonKey) ?? '';

    if (entryId.isEmpty ||
        pendingUserId.isEmpty ||
        pendingWorkspaceId.isEmpty ||
        startText == null ||
        stopText == null) {
      return;
    }

    if (authUser.id != pendingUserId) {
      return;
    }

    final startTime =
        DateTime.tryParse(startText);
    final stopTime =
        DateTime.tryParse(stopText);

    if (startTime == null || stopTime == null) {
      await _clearPendingStop(prefs);
      return;
    }

    _syncingPendingStop = true;

    try {
      final existing = await _supabase
          .from('time_entries')
          .select(
            'id, start_time, end_time, duration_minutes, last_heartbeat_at',
          )
          .eq('id', entryId)
          .eq('employee_id', pendingUserId)
          .eq(
            'workspace_id',
            pendingWorkspaceId,
          )
          .maybeSingle()
          .timeout(_requestTimeout);

      if (existing == null) {
        await _clearPendingStop(prefs);
        return;
      }

      if (existing['end_time'] != null) {
        await _clearPendingStop(prefs);
        return;
      }

      /*
       * IMPORTANT FOR CLOCKMETRIC:
       * The pending start/stop values may be stored in UTC, while the current
       * time_entries table stores local wall-clock timestamps.  The safest
       * value to preserve is therefore the ELAPSED TIME, not the absolute
       * pending stop clock value.
       *
       * Example:
       *   database start  = 17:02
       *   old pending UTC = 11:17 -> 12:03
       *   elapsed         = 46 minutes
       *   correct end     = 17:02 + 46 minutes = 17:48
       *
       * This prevents a real tracked session from ever becoming 00:00 just
       * because one side of the system used UTC.
       */
      Duration trackedDuration =
          stopTime.difference(startTime);

      final databaseStart = DateTime.tryParse(
        existing['start_time']?.toString() ?? '',
      )?.toUtc();

      // Fallbacks for a legacy pending record whose elapsed value is invalid.
      if (trackedDuration.isNegative) {
        final storedMinutes = int.tryParse(
          existing['duration_minutes']?.toString() ?? '',
        );

        if (storedMinutes != null && storedMinutes > 0) {
          trackedDuration = Duration(minutes: storedMinutes);
        } else if (databaseStart != null) {
          final heartbeat = DateTime.tryParse(
            existing['last_heartbeat_at']?.toString() ?? '',
          )?.toUtc();

          if (heartbeat != null && !heartbeat.isBefore(databaseStart)) {
            trackedDuration = heartbeat.difference(databaseStart);
          } else {
            trackedDuration = Duration.zero;
          }
        } else {
          trackedDuration = Duration.zero;
        }
      }

      // Reject obviously corrupted values instead of writing a huge session.
      if (trackedDuration > const Duration(hours: 24)) {
        debugPrint(
          'Pending timer stop was not written because the tracked duration '
          'was greater than 24 hours.',
        );
        _startRecoveryWatcher();
        return;
      }

      final databaseStop = databaseStart == null
          ? stopTime.toUtc()
          : databaseStart.add(trackedDuration);

      final durationMinutes = trackedDuration.inMinutes;
      final databaseStopText = databaseStop.toUtc().toIso8601String();

      await _supabase
          .from('time_entries')
          .update({
            'end_time': databaseStopText,
            'duration_minutes':
                durationMinutes < 0
                    ? 0
                    : durationMinutes,
            'last_heartbeat_at':
                databaseStopText,
            'note':
                _automaticStopNote(
              _reasonFromText(reasonText),
            ),
          })
          .eq('id', entryId)
          .eq('employee_id', pendingUserId)
          .eq(
            'workspace_id',
            pendingWorkspaceId,
          )
          .filter('end_time', 'is', null)
          .timeout(_requestTimeout);

      final verified = await _supabase
          .from('time_entries')
          .select('end_time')
          .eq('id', entryId)
          .eq('employee_id', pendingUserId)
          .maybeSingle()
          .timeout(_requestTimeout);

      if (verified != null &&
          verified['end_time'] != null) {
        await _clearPendingStop(prefs);

        _recoveryTimer?.cancel();
        _recoveryTimer = null;
      }
    } catch (error) {
      debugPrint(
        'Pending timer stop is waiting for internet: '
        '$error',
      );

      _startRecoveryWatcher();
    } finally {
      _syncingPendingStop = false;
    }
  }

  /// Repairs legacy automatic-stop rows created by the old UTC/local bug.
  /// It never changes normal manually-stopped rows.
  Future<int> repairLegacyAutomaticStopRows({
    String? userId,
    String? workspaceId,
  }) async {
    if (userId != null && userId.trim().isNotEmpty) {
      _userId = userId.trim();
    }

    if (workspaceId != null && workspaceId.trim().isNotEmpty) {
      _workspaceId = workspaceId.trim();
    }

    if (_userId.isEmpty ||
        _workspaceId.isEmpty ||
        _supabase.auth.currentUser == null) {
      return 0;
    }

    var repaired = 0;

    try {
      final rows = await _supabase
          .from('time_entries')
          .select(
            'id, start_time, end_time, duration_minutes, last_heartbeat_at, note',
          )
          .eq('employee_id', _userId)
          .eq('workspace_id', _workspaceId)
          .order('start_time', ascending: false)
          .limit(80)
          .timeout(_requestTimeout);

      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final note = row['note']?.toString().trim() ?? '';

        if (!note.startsWith('Automatically stopped')) {
          continue;
        }

        final start = DateTime.tryParse(
          row['start_time']?.toString() ?? '',
        )?.toLocal();
        final end = DateTime.tryParse(
          row['end_time']?.toString() ?? '',
        )?.toLocal();

        if (start == null || end == null || !end.isBefore(start)) {
          continue;
        }

        DateTime? correctedEnd;

        // Best source: a duration that was already recorded correctly.
        final storedMinutes = int.tryParse(
          row['duration_minutes']?.toString() ?? '',
        );

        if (storedMinutes != null &&
            storedMinutes > 0 &&
            storedMinutes <= 24 * 60) {
          correctedEnd = start.add(Duration(minutes: storedMinutes));
        }

        // Legacy UTC bug: 12:03 was really 17:48 in Nepal. Reinterpret the
        // wall-clock components as UTC and convert to this computer's local
        // timezone. This recovers the actual elapsed time instead of 00:00.
        correctedEnd ??= DateTime.utc(
          end.year,
          end.month,
          end.day,
          end.hour,
          end.minute,
          end.second,
          end.millisecond,
          end.microsecond,
        ).toLocal();

        if (correctedEnd.isBefore(start)) {
          continue;
        }

        final tracked = correctedEnd.difference(start);

        if (tracked <= Duration.zero ||
            tracked > const Duration(hours: 24)) {
          continue;
        }

        final correctedText = correctedEnd.toIso8601String();

        await _supabase
            .from('time_entries')
            .update({
              'end_time': correctedText,
              'duration_minutes': tracked.inMinutes,
              'last_heartbeat_at': correctedText,
            })
            .eq('id', row['id'].toString())
            .eq('employee_id', _userId)
            .eq('workspace_id', _workspaceId)
            .timeout(_requestTimeout);

        repaired += 1;
      }
    } catch (error) {
      debugPrint('Legacy automatic-stop repair skipped: $error');
    }

    return repaired;
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();

    if (_activeEntryId == null ||
        _userId.isEmpty ||
        _workspaceId.isEmpty) {
      return;
    }

    _watchdogTimer = Timer.periodic(
      _watchInterval,
      (_) {
        unawaited(_checkConnection());
      },
    );
  }

  Future<void> _checkConnection() async {
    if (_checkingConnection ||
        _handlingForcedStop ||
        _activeEntryId == null) {
      return;
    }

    _checkingConnection = true;

    try {
      final probe = await _probeActiveTimer();

      if (probe == _TimerProbeState.running) {
        _lastOnlineAt = DateTime.now().toUtc();
        _resetConnectionFailures();

        final prefs =
            await SharedPreferences.getInstance();

        await prefs.setString(
          _lastOnlineKey,
          _lastOnlineAt!
              .toUtc()
              .toIso8601String(),
        );

        return;
      }

      // Another ClockMetric window or a server-side action may already have
      // stopped this row. In that case stop the LOCAL ticker too, but do not
      // write another stop over the server row.
      if (probe == _TimerProbeState.stopped) {
        await _handleServerEntryAlreadyStopped();
        return;
      }

      _consecutiveFailedChecks += 1;
      _firstFailedCheckAt ??= DateTime.now().toUtc();

      final failedFor = DateTime.now().toUtc().difference(
        _firstFailedCheckAt!,
      );

      if (_consecutiveFailedChecks <
              _requiredFailedChecks ||
          failedFor < _offlineGracePeriod) {
        debugPrint(
          'ClockMetric connection check failed '
          '($_consecutiveFailedChecks). Timer is still running '
          'during the safety grace period.',
        );
        return;
      }

      await _handleInternetLoss();
    } finally {
      _checkingConnection = false;
    }
  }

  Future<_TimerProbeState> _probeActiveTimer() async {
    if (_userId.isEmpty ||
        _workspaceId.isEmpty ||
        _activeEntryId == null ||
        _supabase.auth.currentUser == null) {
      return _TimerProbeState.unreachable;
    }

    // Retry once. A single timeout/token refresh/network wobble must not
    // freeze an employee's timer.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final row = await _supabase
            .from('time_entries')
            .select('id, end_time')
            .eq('id', _activeEntryId!)
            .eq('employee_id', _userId)
            .eq('workspace_id', _workspaceId)
            .maybeSingle()
            .timeout(_requestTimeout);

        if (row == null) {
          return _TimerProbeState.stopped;
        }

        return row['end_time'] == null
            ? _TimerProbeState.running
            : _TimerProbeState.stopped;
      } catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(
            const Duration(milliseconds: 700),
          );
        }
      }
    }

    return _TimerProbeState.unreachable;
  }

  Future<bool> _isBackendReachable() async {
    if (_userId.isEmpty ||
        _supabase.auth.currentUser == null) {
      return false;
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _supabase
            .from('profiles')
            .select('id')
            .eq('id', _userId)
            .limit(1)
            .timeout(_requestTimeout);

        return true;
      } catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(
            const Duration(milliseconds: 700),
          );
        }
      }
    }

    return false;
  }

  void _resetConnectionFailures() {
    _consecutiveFailedChecks = 0;
    _firstFailedCheckAt = null;
  }

  Future<void> _handleServerEntryAlreadyStopped() async {
    if (_activeEntryId == null) return;

    final stoppedEntryId = _activeEntryId!;
    DateTime stoppedAt = DateTime.now().toUtc();

    try {
      final row = await _supabase
          .from('time_entries')
          .select('end_time')
          .eq('id', stoppedEntryId)
          .eq('employee_id', _userId)
          .eq('workspace_id', _workspaceId)
          .maybeSingle()
          .timeout(_requestTimeout);

      final parsed = DateTime.tryParse(
        row?['end_time']?.toString() ?? '',
      );

      if (parsed != null) {
        stoppedAt = parsed.toUtc();
      }
    } catch (_) {
      // The row is already known to be stopped. Current local time is only
      // used for the UI notification if its exact end time cannot be loaded.
    }

    await _stopTrackingLocally();

    final prefs =
        await SharedPreferences.getInstance();
    await _clearActiveRegistration(prefs);

    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _activeEntryId = null;
    _activeProjectId = null;
    _activeStartTime = null;
    _lastOnlineAt = null;
    _resetConnectionFailures();

    forcedStopNotifier.value =
        TimerSafetyEvent(
      entryId: stoppedEntryId,
      stoppedAt: stoppedAt,
      reason: TimerAutoStopReason.sessionEnded,
    );
  }

  Future<void> _handleInternetLoss() async {
    if (_handlingForcedStop ||
        _activeEntryId == null ||
        _activeStartTime == null) {
      return;
    }

    _handlingForcedStop = true;

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final stoppedEntryId =
          _activeEntryId!;
      final stoppedStartTime =
          _activeStartTime!;

      // Use the last moment when ClockMetric definitely had a
      // working connection. This avoids counting offline time.
      final stoppedAt =
          _lastOnlineAt ?? DateTime.now().toUtc();

      await _stopTrackingLocally();

      await _savePendingStop(
        prefs: prefs,
        entryId: stoppedEntryId,
        userId: _userId,
        workspaceId: _workspaceId,
        startTime: stoppedStartTime,
        stopTime: stoppedAt,
        reason:
            TimerAutoStopReason.internetLost,
      );

      await _clearActiveRegistration(prefs);

      _watchdogTimer?.cancel();
      _watchdogTimer = null;

      _activeEntryId = null;
      _activeProjectId = null;
      _activeStartTime = null;
      _lastOnlineAt = null;
      _resetConnectionFailures();

      forcedStopNotifier.value =
          TimerSafetyEvent(
        entryId: stoppedEntryId,
        stoppedAt: stoppedAt,
        reason:
            TimerAutoStopReason.internetLost,
      );

      // Do not restart the timer. Only keep checking so the
      // stored stop can be synchronized when internet returns.
      _startRecoveryWatcher();
    } finally {
      _handlingForcedStop = false;
    }
  }

  void _startRecoveryWatcher() {
    _recoveryTimer?.cancel();

    _recoveryTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        if (_supabase.auth.currentUser == null) {
          return;
        }

        final online =
            await _isBackendReachable();

        if (!online) return;

        await syncPendingStopForCurrentUser();
      },
    );
  }

  Future<void> _restoreRunningTimerAfterAppStart()
      async {
    final prefs =
        await SharedPreferences.getInstance();

    await _loadActiveRegistrationFromPrefsIfNeeded(
      prefs,
    );

    // If there is no local backup, try the server. This covers opening the
    // Dashboard before the Timer screen after an app restart.
    if (_activeEntryId == null ||
        _activeStartTime == null) {
      await _loadRunningEntryFromServerIfPossible();

      if (_activeEntryId != null) {
        _lastOnlineAt = DateTime.now().toUtc();
        _resetConnectionFailures();
        await _saveActiveRegistration();
      }

      return;
    }

    final probe = await _probeActiveTimer();

    if (probe == _TimerProbeState.running) {
      // The server still says the timer is running. Continue it. A restart or
      // hot restart must not create a 20-second frozen time entry.
      _lastOnlineAt = DateTime.now().toUtc();
      _resetConnectionFailures();
      await _saveActiveRegistration();
      return;
    }

    if (probe == _TimerProbeState.stopped) {
      await _clearActiveRegistration(prefs);
      _activeEntryId = null;
      _activeProjectId = null;
      _activeStartTime = null;
      _lastOnlineAt = null;
      _resetConnectionFailures();
      return;
    }

    // Backend is currently unreachable. Keep the local timer registration
    // alive for the short grace period. If the outage is genuine, the watchdog
    // will stop it at the last confirmed online time and sync later.
    _startWatchdog();
  }

  Future<void>
      _loadActiveRegistrationFromPrefsIfNeeded(
    SharedPreferences prefs,
  ) async {
    if (_activeEntryId != null &&
        _activeStartTime != null) {
      return;
    }

    final entryId =
        prefs.getString(_activeEntryKey) ?? '';
    final userId =
        prefs.getString(_activeUserKey) ?? '';
    final workspaceId =
        prefs.getString(_activeWorkspaceKey) ?? '';
    final projectId =
        prefs.getString(_activeProjectKey);
    final startText =
        prefs.getString(_activeStartKey);
    final lastOnlineText =
        prefs.getString(_lastOnlineKey);

    if (entryId.isEmpty ||
        userId.isEmpty ||
        workspaceId.isEmpty ||
        startText == null) {
      return;
    }

    final parsedStart =
        DateTime.tryParse(startText);

    if (parsedStart == null) return;

    if (_userId.isNotEmpty &&
        userId != _userId) {
      return;
    }

    _userId = userId;
    _workspaceId = workspaceId;
    _activeEntryId = entryId;
    _activeProjectId = projectId;
    _activeStartTime = parsedStart.toUtc();
    _lastOnlineAt =
        lastOnlineText == null
            ? null
            : DateTime.tryParse(
                lastOnlineText,
              )?.toUtc();
  }

  Future<void>
      _loadRunningEntryFromServerIfPossible()
      async {
    if (_userId.isEmpty ||
        _workspaceId.isEmpty ||
        _supabase.auth.currentUser == null) {
      return;
    }

    try {
      final rows = await _supabase
          .from('time_entries')
          .select(
            'id, start_time, project_id',
          )
          .eq('employee_id', _userId)
          .eq('workspace_id', _workspaceId)
          .filter('end_time', 'is', null)
          .order(
            'start_time',
            ascending: false,
          )
          .limit(1)
          .timeout(_requestTimeout);

      if (rows.isEmpty) return;

      final row =
          Map<String, dynamic>.from(
        rows.first,
      );

      final parsedStart =
          DateTime.tryParse(
        row['start_time']?.toString() ?? '',
      );

      final entryId =
          row['id']?.toString().trim() ?? '';

      if (parsedStart == null ||
          entryId.isEmpty) {
        return;
      }

      _activeEntryId = entryId;
      _activeStartTime = parsedStart.toUtc();
      _activeProjectId =
          row['project_id']?.toString();
      _lastOnlineAt = DateTime.now().toUtc();
    } catch (_) {
      // If logout is happening while offline, the persisted
      // active registration is the source of truth.
    }
  }

  Future<void> _stopTrackingLocally() async {
    try {
      ScreenshotSchedulerService.instance.stop();
    } catch (error) {
      debugPrint(
        'Screenshot scheduler stop error: $error',
      );
    }

    if (kIsWeb) return;

    try {
      await _keyboardChannel
          .invokeMethod('stop');
    } catch (_) {
      // Native activity channel is Windows-only.
    }

    try {
      await _mouseChannel
          .invokeMethod('stop');
    } catch (_) {
      // Native activity channel is Windows-only.
    }
  }

  Future<void> _saveActiveRegistration()
      async {
    final entryId = _activeEntryId;
    final startTime = _activeStartTime;

    if (entryId == null ||
        startTime == null ||
        _userId.isEmpty ||
        _workspaceId.isEmpty) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _activeEntryKey,
      entryId,
    );

    await prefs.setString(
      _activeUserKey,
      _userId,
    );

    await prefs.setString(
      _activeWorkspaceKey,
      _workspaceId,
    );

    if (_activeProjectId != null &&
        _activeProjectId!.isNotEmpty) {
      await prefs.setString(
        _activeProjectKey,
        _activeProjectId!,
      );
    } else {
      await prefs.remove(
        _activeProjectKey,
      );
    }

    await prefs.setString(
      _activeStartKey,
      startTime
          .toUtc()
          .toIso8601String(),
    );

    await prefs.setString(
      _lastOnlineKey,
      (_lastOnlineAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
    );
  }

  Future<void> _savePendingStop({
    required SharedPreferences prefs,
    required String entryId,
    required String userId,
    required String workspaceId,
    required DateTime startTime,
    required DateTime stopTime,
    required TimerAutoStopReason reason,
  }) async {
    if (entryId.isEmpty ||
        userId.isEmpty ||
        workspaceId.isEmpty) {
      return;
    }

    await prefs.setString(
      _pendingEntryKey,
      entryId,
    );

    await prefs.setString(
      _pendingUserKey,
      userId,
    );

    await prefs.setString(
      _pendingWorkspaceKey,
      workspaceId,
    );

    await prefs.setString(
      _pendingStartKey,
      startTime
          .toUtc()
          .toIso8601String(),
    );

    await prefs.setString(
      _pendingStopKey,
      stopTime
          .toUtc()
          .toIso8601String(),
    );

    await prefs.setString(
      _pendingReasonKey,
      reason.name,
    );
  }

  Future<void> _clearActiveRegistration(
    SharedPreferences prefs,
  ) async {
    await prefs.remove(_activeEntryKey);
    await prefs.remove(_activeUserKey);
    await prefs.remove(_activeWorkspaceKey);
    await prefs.remove(_activeProjectKey);
    await prefs.remove(_activeStartKey);
    await prefs.remove(_lastOnlineKey);
  }

  Future<void> _clearPendingStop(
    SharedPreferences prefs,
  ) async {
    await prefs.remove(_pendingEntryKey);
    await prefs.remove(_pendingUserKey);
    await prefs.remove(_pendingWorkspaceKey);
    await prefs.remove(_pendingStartKey);
    await prefs.remove(_pendingStopKey);
    await prefs.remove(_pendingReasonKey);
  }

  TimerAutoStopReason _reasonFromText(
    String value,
  ) {
    for (final reason
        in TimerAutoStopReason.values) {
      if (reason.name == value) {
        return reason;
      }
    }

    return TimerAutoStopReason.sessionEnded;
  }

  String _automaticStopNote(
    TimerAutoStopReason reason,
  ) {
    switch (reason) {
      case TimerAutoStopReason.internetLost:
        return 'Automatically stopped because the internet connection was lost.';
      case TimerAutoStopReason.logout:
        return 'Automatically stopped when the user logged out.';
      case TimerAutoStopReason.sessionEnded:
        return 'Automatically stopped when the login session ended.';
      case TimerAutoStopReason.appInterrupted:
        return 'Automatically stopped after ClockMetric was closed or interrupted.';
    }
  }
}

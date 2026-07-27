import '../main.dart';
import 'package:flutter/foundation.dart';

class TimeEntryService {
  Future<Map<String, dynamic>?> getRunningEntry() async {
    return await supabase
        .from('time_entries')
        .select(
          'id, project_id, start_time, last_heartbeat_at, '
          'projects(project_name)',
        )
        .eq('employee_id', currentUserId)
        .eq('workspace_id', currentWorkspaceId)
        .filter('end_time', 'is', null)
        .maybeSingle();
  }

  Future<String> startTimeEntry({
    required String projectId,
  }) async {
    final now = DateTime.now();

    final response = await supabase
        .from('time_entries')
        .insert({
          'employee_id': currentUserId,
          'project_id': projectId,
          'employee_name': currentUserName,
          'workspace_id': currentWorkspaceId,
          'start_time': now.toIso8601String(),
          'last_heartbeat_at': now.toIso8601String(),
          'end_time': null,
          'duration_minutes': null,
          'note': null,
        })
        .select('id')
        .single();

    return response['id'].toString();
  }

  Future<void> updateHeartbeat({
    required String entryId,
  }) async {
    if (entryId.isEmpty ||
        currentUserId.isEmpty ||
        currentWorkspaceId.isEmpty) {
      return;
    }

    await supabase
        .from('time_entries')
        .update({
          'last_heartbeat_at':
              DateTime.now().toIso8601String(),
        })
        .eq('id', entryId)
        .eq('employee_id', currentUserId)
        .eq('workspace_id', currentWorkspaceId)
        .filter('end_time', 'is', null);
  }

Future<void> stopTimeEntry({
  required String entryId,
  required DateTime startTime,
  required String note,
}) async {
  final endTime = DateTime.now();

  final durationMinutes =
      endTime.difference(startTime).inMinutes;

  debugPrint("========== STOP TIMER ==========");
  debugPrint("Entry ID: $entryId");
  debugPrint("Employee ID: $currentUserId");
  debugPrint("Workspace ID: $currentWorkspaceId");

  final result = await supabase
      .from('time_entries')
      .update({
        'end_time': endTime.toIso8601String(),
        'last_heartbeat_at': endTime.toIso8601String(),
        'duration_minutes':
             durationMinutes <= 0 ? 1 : durationMinutes,
        'note': note.trim().isEmpty ? null : note.trim(),
      })
      .eq('id', entryId)
      .eq('employee_id', currentUserId)
      .eq('workspace_id', currentWorkspaceId)
      .filter('end_time', 'is', null)
      .select();

  debugPrint("Rows updated:");
  debugPrint(result.toString());
  debugPrint("===============================");
}

  Future<void> stopRunningEntrySilently({
    required String entryId,
    required DateTime startTime,
  }) async {
    await stopTimeEntry(
      entryId: entryId,
      startTime: startTime,
      note: '',
    );
  }
}
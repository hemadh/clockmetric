import '../main.dart';
import 'package:flutter/foundation.dart';
import 'keyboard_sample_scheduler_service.dart';

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

    final entryId = response['id'].toString();

    await KeyboardSampleSchedulerService.start(
      timeEntryId: entryId,
    );

    debugPrint(
      'Keyboard tracking and 5-minute sampling started',
    );

    return entryId;
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
    final endTime =
        await KeyboardSampleSchedulerService.stop();

    final durationMinutes =
        endTime.difference(startTime).inMinutes;

    debugPrint('========== STOP TIMER ==========');
    debugPrint('Entry ID: $entryId');
    debugPrint('Employee ID: $currentUserId');
    debugPrint('Workspace ID: $currentWorkspaceId');

    final result = await supabase
        .from('time_entries')
        .update({
          'end_time': endTime.toIso8601String(),
          'last_heartbeat_at':
              endTime.toIso8601String(),
          'duration_minutes':
              durationMinutes <= 0
                  ? 1
                  : durationMinutes,
          'note':
              note.trim().isEmpty
                  ? null
                  : note.trim(),
        })
        .eq('id', entryId)
        .eq('employee_id', currentUserId)
        .eq('workspace_id', currentWorkspaceId)
        .filter('end_time', 'is', null)
        .select();

    debugPrint('Rows updated:');
    debugPrint(result.toString());
    debugPrint('===============================');
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

  Future<void> deleteCompletedEntry({
    required String entryId,
  }) async {
    if (entryId.trim().isEmpty ||
        currentWorkspaceId.isEmpty ||
        currentUserId.isEmpty) {
      throw Exception(
        'Invalid time entry information.',
      );
    }

    final isAdmin =
        currentUserRole.trim().toLowerCase() ==
            'admin';

    var query = supabase
        .from('time_entries')
        .delete()
        .eq('id', entryId)
        .eq('workspace_id', currentWorkspaceId)
        .not('end_time', 'is', null);

    if (!isAdmin) {
      query = query.eq(
        'employee_id',
        currentUserId,
      );
    }

    final deletedRows =
        await query.select('id');

    if (deletedRows.isEmpty) {
      throw Exception(
        'This entry could not be deleted. '
        'It may be running or you may not have permission.',
      );
    }
  }
}
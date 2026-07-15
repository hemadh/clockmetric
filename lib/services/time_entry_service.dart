import '../main.dart';

class TimeEntryService {
  Future<Map<String, dynamic>?> getRunningEntry() async {
    return await supabase
        .from('time_entries')
        .select('id, project_id, start_time, projects(project_name)')
        .eq('employee_id', currentUserId)
        .eq('workspace_id', currentWorkspaceId)
        .filter('end_time', 'is', null)
        .maybeSingle();
  }

  Future<String> startTimeEntry({
    required String projectId,
  }) async {
    final response = await supabase
        .from('time_entries')
        .insert({
          'employee_id': currentUserId,
          'project_id': projectId,
          'employee_name': currentUserName,
          'workspace_id': currentWorkspaceId,
          'start_time': DateTime.now().toIso8601String(),
          'end_time': null,
          'duration_minutes': null,
          'note': null,
        })
        .select('id')
        .single();

    return response['id'];
  }

  Future<void> stopTimeEntry({
    required String entryId,
    required DateTime startTime,
    required String note,
  }) async {
    final endTime = DateTime.now();
    final durationMinutes = endTime.difference(startTime).inMinutes;

    await supabase
        .from('time_entries')
        .update({
          'end_time': endTime.toIso8601String(),
          'duration_minutes': durationMinutes,
          'note': note,
        })
        .eq('id', entryId)
        .eq('employee_id', currentUserId)
        .eq('workspace_id', currentWorkspaceId);
  }
}
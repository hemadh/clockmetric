import '../main.dart';

class ReportService {
  Future<List<Map<String, dynamic>>> getWeeklyByEmployee() async {
    final now = DateTime.now();

    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    var query = supabase
        .from('time_entries')
        .select('employee_name, duration_minutes')
        .eq('workspace_id', currentWorkspaceId)
        .gte('start_time', weekStart.toIso8601String());

    if (currentUserRole != 'admin') {
      query = query.eq('employee_name', currentUserName);
    }

    final response = await query;

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getWeeklyByProject() async {
    final now = DateTime.now();

    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    var query = supabase
        .from('time_entries')
        .select('duration_minutes, projects(project_name)')
        .eq('workspace_id', currentWorkspaceId)
        .gte('start_time', weekStart.toIso8601String());

    if (currentUserRole != 'admin') {
      query = query.eq('employee_name', currentUserName);
    }

    final response = await query;

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getWeeklyEntries() async {
    final now = DateTime.now();

    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final weekEnd = weekStart.add(const Duration(days: 7));

    var query = supabase
        .from('time_entries')
        .select(
          'employee_name, duration_minutes, start_time, projects(project_name)',
        )
        .eq('workspace_id', currentWorkspaceId)
        .gte('start_time', weekStart.toIso8601String())
        .lt('start_time', weekEnd.toIso8601String());

    if (currentUserRole != 'admin') {
      query = query.eq('employee_name', currentUserName);
    }

    final response = await query;

    return List<Map<String, dynamic>>.from(response);
  }
}
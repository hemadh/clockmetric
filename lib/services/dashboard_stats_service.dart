import '../main.dart';

class DashboardStatsService {
  Future<int> getThisWeekMinutes() async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    var query = supabase
        .from('time_entries')
        .select('duration_minutes')
        .eq('workspace_id', currentWorkspaceId)
        .gte('start_time', weekStart.toIso8601String());

    if (currentUserRole != 'admin') {
  query = query.eq(
    'employee_name',
    currentUserName,
  );
}

    final response = await query;

    int total = 0;
    for (final item in response) {
      total += (item['duration_minutes'] ?? 0) as int;
    }

    return total;
  }

  Future<int> getLastWeekMinutes() async {
    final now = DateTime.now();
    final thisWeekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart;

    var query = supabase
        .from('time_entries')
        .select('duration_minutes')
        .eq('workspace_id', currentWorkspaceId)
        .gte('start_time', lastWeekStart.toIso8601String())
        .lt('start_time', lastWeekEnd.toIso8601String());

    if (currentUserRole != 'admin') {
      query = query.eq('employee_name', currentUserName);
    }

    final response = await query;

    int total = 0;
    for (final item in response) {
      total += (item['duration_minutes'] ?? 0) as int;
    }

    return total;
  }

  Future<Map<String, int>> getDailyWeekMinutes() async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    var query = supabase
        .from('time_entries')
        .select('start_time, duration_minutes')
        .eq('workspace_id', currentWorkspaceId)
        .gte('start_time', weekStart.toIso8601String());

    if (currentUserRole != 'admin') {
      query = query.eq('employee_name', currentUserName);
    }

    final response = await query;

    final Map<String, int> daily = {
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (final item in response) {
      final date = DateTime.parse(item['start_time']);
      final label = labels[date.weekday - 1];

      daily[label] =
          daily[label]! + ((item['duration_minutes'] ?? 0) as int);
    }

    return daily;
  }

  Future<Map<String, int>> getHoursByProject() async {
    var query = supabase
        .from('time_entries')
        .select('duration_minutes, projects(project_name)')
        .eq('workspace_id', currentWorkspaceId);

    if (currentUserRole != 'admin') {
      query = query.eq('employee_name', currentUserName);
    }

    final response = await query;

    final Map<String, int> projectTotals = {};

    for (final item in response) {
      final projectName =
          item['projects']?['project_name']?.toString() ?? 'Unknown Project';

      final minutes = (item['duration_minutes'] ?? 0) as int;

      projectTotals[projectName] =
          (projectTotals[projectName] ?? 0) + minutes;
    }

    return projectTotals;
  }

  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    var query = supabase
        .from('time_entries')
        .select(
          'employee_name, duration_minutes, start_time, note, projects(project_name)',
        )
        .eq('workspace_id', currentWorkspaceId);

    if (currentUserRole != 'admin') {
      query = query.eq('employee_name', currentUserName);
    }

    final response = await query;

    final Map<String, Map<String, dynamic>> grouped = {};

    for (final item in response) {
      final employee = item['employee_name']?.toString() ?? 'Employee';
      final project =
          item['projects']?['project_name']?.toString() ?? 'Unknown Project';
      final minutes = (item['duration_minutes'] ?? 0) as int;
      final note = item['note']?.toString() ?? '';

      grouped.putIfAbsent(employee, () {
        return {
          'employee_name': employee,
          'total_minutes': 0,
          'projects': <String, int>{},
          'notes': <String>[],
        };
      });

      grouped[employee]!['total_minutes'] =
          (grouped[employee]!['total_minutes'] as int) + minutes;

      final projectMap = grouped[employee]!['projects'] as Map<String, int>;
      projectMap[project] = (projectMap[project] ?? 0) + minutes;

      if (note.trim().isNotEmpty) {
        final notes = grouped[employee]!['notes'] as List<String>;
        notes.add("$project: $note");
      }
    }

    final list = grouped.values.toList();

    list.sort(
      (a, b) =>
          (b['total_minutes'] as int).compareTo(a['total_minutes'] as int),
    );

    return list;
  }

  Future<Map<String, int>> getEmployeeLeaderboard() async {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final employeesResponse = await supabase
        .from('profiles')
        .select('full_name, role')
        .eq('workspace_id', currentWorkspaceId)
        .eq('role', 'employee');

    final Set<String> employeeNames = employeesResponse
        .map<String>((e) => e['full_name'].toString())
        .toSet();

    final response = await supabase
        .from('time_entries')
        .select('employee_name, duration_minutes')
        .eq('workspace_id', currentWorkspaceId)
        .not('duration_minutes', 'is', null)
        .gte('start_time', weekStart.toIso8601String());

    final Map<String, int> totals = {};

    for (final item in response) {
      final employee =
          item['employee_name']?.toString() ?? 'Unknown Employee';

      if (!employeeNames.contains(employee)) {
        continue;
      }

      final minutes = (item['duration_minutes'] ?? 0) as int;
      totals[employee] = (totals[employee] ?? 0) + minutes;
    }

    final sorted = Map.fromEntries(
      totals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );

    return sorted;
  }

  Future<int> getActiveProjectsCount() async {
    final response = await supabase
        .from('projects')
        .select('id')
        .eq('workspace_id', currentWorkspaceId);

    return response.length;
  }

  Future<List<Map<String, dynamic>>> getActiveNow() async {
    final response = await supabase
        .from('time_entries')
        .select('employee_name, start_time, project_id')
        .eq('workspace_id', currentWorkspaceId)
        .filter('end_time', 'is', null);

    return List<Map<String, dynamic>>.from(response);
  }
}
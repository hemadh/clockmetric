import 'dart:async';

import 'package:fl_chart/fl_chart.dart';

import 'package:flutter/material.dart';

import '../main.dart';

import '../theme/app_colors.dart';

class TimesheetScreen extends StatefulWidget {

  final bool isManager;

  final String employeeName;

  const TimesheetScreen({

    super.key,

    required this.isManager,

    this.employeeName = '',

  });

  @override

  State<TimesheetScreen> createState() => _TimesheetScreenState();

}

class _TimesheetScreenState extends State<TimesheetScreen> {

  bool loading = true;

  bool loadingEmployees = false;

  bool loadingTeamTime = false;

  String? errorMessage;

  String? teamTimeErrorMessage;

  String? selectedEmployeeName;

  String? selectedEmployeeId;

  int weekOffset = 0;

  List<String> employees = [];

  List<Map<String, dynamic>> entries = [];

  
  List<Map<String, dynamic>> screenshots = [];
List<EmployeeWeeklyTime> weeklyTeamTimes = [];

  final Map<String, String> employeeIdsByName = {};

  Timer? _liveRefreshTimer;

  @override

  void initState() {

    super.initState();

    initializeScreen();

    // Keep a running entry live on the Timesheet instead of freezing

    // at the value from the last page load/refresh.

    _liveRefreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || loading || weekOffset != 0) return;

        // Only repaint for a genuinely live timer. An old row with end_time = null
        // must not keep growing forever.
        final hasLiveRunningEntry = entries.any(isEntryLiveRunning);

        if (hasLiveRunningEntry) {
          setState(() {});
        }
      },
    );

  }

  @override

  void dispose() {

    _liveRefreshTimer?.cancel();

    super.dispose();

  }

  Future<void> initializeScreen() async {

    if (widget.isManager) {

      await loadEmployees();

    } else {

      selectedEmployeeName = widget.employeeName.trim().isNotEmpty

          ? widget.employeeName.trim()

          : currentUserName;

      // IMPORTANT: the employee ID is the permanent identity.

      // Names can be edited, but this ID must never change.

      selectedEmployeeId = currentUserId.trim();

    }

    await loadTimesheet();

  }

  DateTime getWeekStart() {

    final shiftedDate = DateTime.now().add(

      Duration(days: weekOffset * 7),

    );

    final date = DateTime(

      shiftedDate.year,

      shiftedDate.month,

      shiftedDate.day,

    );

    return date.subtract(

      Duration(days: date.weekday - DateTime.monday),

    );

  }

  DateTime getWeekEnd() {

    return getWeekStart().add(

      const Duration(days: 7),

    );

  }

  List<DateTime> getWeekDays() {

    final weekStart = getWeekStart();

    return List.generate(

      7,

      (index) => weekStart.add(

        Duration(days: index),

      ),

    );

  }

  Future<void> loadEmployees() async {

    if (!mounted) return;

    setState(() {

      loadingEmployees = true;

    });

    try {

      final response = await supabase

          .from('profiles')

          .select('id, full_name')

          .eq('workspace_id', currentWorkspaceId)

          .eq('approval_status', 'approved')

          .order('full_name');

      final loadedEmployees = <String>[];

      final loadedEmployeeIdsByName = <String, String>{};

      for (final profile in response) {

        final name = profile['full_name']?.toString().trim();

        final id = profile['id']?.toString().trim() ?? '';

        if (name != null &&

            name.isNotEmpty &&

            !loadedEmployees.contains(name)) {

          loadedEmployees.add(name);

          if (id.isNotEmpty) {

            loadedEmployeeIdsByName[name] = id;

          }

        }

      }

      String? initialEmployee;

      final requestedEmployee = widget.employeeName.trim();

      if (requestedEmployee.isNotEmpty &&

          loadedEmployees.contains(requestedEmployee)) {

        initialEmployee = requestedEmployee;

      } else if (loadedEmployees.contains(currentUserName)) {

        initialEmployee = currentUserName;

      } else if (loadedEmployees.isNotEmpty) {

        initialEmployee = loadedEmployees.first;

      }

      final initialEmployeeId = initialEmployee == null

          ? null

          : loadedEmployeeIdsByName[initialEmployee];

      if (!mounted) return;

      setState(() {

        employees = loadedEmployees;

        employeeIdsByName

          ..clear()

          ..addAll(loadedEmployeeIdsByName);

        selectedEmployeeName = initialEmployee;

        selectedEmployeeId = initialEmployeeId;

        loadingEmployees = false;

      });

    } catch (error) {

      debugPrint('Employee loading error: $error');

      if (!mounted) return;

      setState(() {

        loadingEmployees = false;

      });

    }

  }

  Future<void> loadTimesheet() async {
    if (!mounted) return;

    // Use employee_id for both admin and employee mode so renamed users keep
    // the same historical timesheet.
    final employeeId = widget.isManager
        ? (selectedEmployeeId ?? '').trim()
        : currentUserId.trim();

    if (employeeId.isEmpty) {
      setState(() {
        loading = false;
        entries = [];
        screenshots = [];
        errorMessage = 'Unable to identify the selected employee.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final weekStart = getWeekStart();
      final weekEnd = getWeekEnd();

      // Supabase stores timestamptz values in UTC. Converting the local week
      // boundary to UTC prevents off-by-one-day/week errors.
      final weekStartUtc = weekStart.toUtc().toIso8601String();
      final weekEndUtc = weekEnd.toUtc().toIso8601String();

      final response = await supabase
          .from('time_entries')
          .select(
            'id, employee_id, employee_name, project_id, '
            'start_time, end_time, last_heartbeat_at, duration_minutes, note, '
            'projects(project_name)',
          )
          .eq('workspace_id', currentWorkspaceId)
          .eq('employee_id', employeeId)
          .gte('start_time', weekStartUtc)
          .lt('start_time', weekEndUtc)
          .order('start_time', ascending: true);

      final loadedEntries = List<Map<String, dynamic>>.from(response);
      final entryIds = loadedEntries
          .map((entry) => entry['id']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      List<Map<String, dynamic>> loadedScreenshots = [];

      if (entryIds.isNotEmpty) {
        final screenshotResponse = await supabase
            .from('screenshots')
            .select('id, time_entry_id, project_id, created_at')
            .eq('workspace_id', currentWorkspaceId)
            .inFilter('time_entry_id', entryIds)
            .gte('created_at', weekStartUtc)
            .lt('created_at', weekEndUtc)
            .order('created_at', ascending: true);

        loadedScreenshots =
            List<Map<String, dynamic>>.from(screenshotResponse);
      }

      if (!mounted) return;

      setState(() {
        entries = loadedEntries;
        screenshots = loadedScreenshots;
        loading = false;
      });
    } catch (error) {
      debugPrint('Timesheet loading error: $error');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Unable to load the timesheet. Please try again.';
      });
    }
  }

Future<void> loadWeeklyTeamTime() async {

  if (widget.isManager || !mounted) return;

  setState(() {

    loadingTeamTime = true;

    teamTimeErrorMessage = null;

  });

  try {

    final response = await supabase.rpc(

      'get_weekly_team_time_seconds',

      params: {

        'p_week_start': getWeekStart().toIso8601String(),

        'p_week_end': getWeekEnd().toIso8601String(),

      },

    );

    final loadedTeamTimes = <EmployeeWeeklyTime>[];

    for (final rawItem in response as List<dynamic>) {

      final item = Map<String, dynamic>.from(rawItem as Map);

      final employeeName =

          item['employee_name']?.toString().trim();

      final totalMinutes = int.tryParse(

      item['total_seconds']?.toString() ?? '',

    ) ??

    0;

      if (employeeName == null ||

          employeeName.isEmpty ||

          totalMinutes <= 0) {

        continue;

      }

      loadedTeamTimes.add(

        EmployeeWeeklyTime(

          employeeName: employeeName,

          totalMinutes: totalMinutes,

        ),

      );

    }

    loadedTeamTimes.sort(

      (first, second) => second.totalMinutes.compareTo(

        first.totalMinutes,

      ),

    );

    if (!mounted) return;

    setState(() {

      weeklyTeamTimes = loadedTeamTimes;

      loadingTeamTime = false;

    });

  } catch (error) {

    debugPrint('Weekly team time loading error: $error');

    if (!mounted) return;

    setState(() {

      loadingTeamTime = false;

      teamTimeErrorMessage =

          'Unable to load weekly team time.';

    });

  }

}

  static const Duration _runningHeartbeatGrace = Duration(minutes: 2);

  DateTime? _parseLocalDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  bool isEntryLiveRunning(Map<String, dynamic> entry) {
    if (entry['end_time'] != null) return false;

    final startTime = _parseLocalDate(entry['start_time']);
    if (startTime == null) return false;

    final now = DateTime.now();
    final heartbeat = _parseLocalDate(entry['last_heartbeat_at']);

    // New/current rows may briefly exist before the first heartbeat is saved.
    if (heartbeat == null) {
      final age = now.difference(startTime);
      return !age.isNegative && age <= _runningHeartbeatGrace;
    }

    final heartbeatAge = now.difference(heartbeat);
    return !heartbeatAge.isNegative && heartbeatAge <= _runningHeartbeatGrace;
  }

  int entrySeconds(Map<String, dynamic> entry) {
    final startTime = _parseLocalDate(entry['start_time']);
    if (startTime == null) return 0;

    final endTime = _parseLocalDate(entry['end_time']);

    // Finished entry: always use the real start/end timestamps for second-level
    // accuracy.
    if (endTime != null) {
      if (endTime.isBefore(startTime)) return 0;
      return endTime.difference(startTime).inSeconds;
    }

    // Open entry: only count up to NOW when the heartbeat proves the timer is
    // still alive. This prevents stale end_time = null rows from creating
    // values such as 48+ hours.
    if (isEntryLiveRunning(entry)) {
      final now = DateTime.now();
      if (now.isBefore(startTime)) return 0;
      return now.difference(startTime).inSeconds;
    }

    // Stale open entry: freeze it at its last known heartbeat.
    final heartbeat = _parseLocalDate(entry['last_heartbeat_at']);
    if (heartbeat != null && !heartbeat.isBefore(startTime)) {
      return heartbeat.difference(startTime).inSeconds;
    }

    // Compatibility fallback for old rows created before heartbeat tracking was
    // added. Never use DateTime.now() here.
    final storedMinutes = int.tryParse(
          entry['duration_minutes']?.toString() ?? '',
        ) ??
        0;

    return storedMinutes < 0 ? 0 : storedMinutes * 60;
  }

  int entryMinutes(Map<String, dynamic> entry) => entrySeconds(entry) ~/ 60;

  String getProjectKey(Map<String, dynamic> entry) {

    final projectId = entry['project_id']?.toString().trim();

    if (projectId != null && projectId.isNotEmpty) {

      return projectId;

    }

    return getProjectName(entry);

  }

  String projectDisplayName(dynamic value) {

    var name = value?.toString().trim() ?? '';

    if (name.isEmpty ||

        name.toLowerCase() == 'no project' ||

        name.toLowerCase() == 'unknown project') {

      return 'Project: No Project';

    }

    name = name.replaceFirst(

      RegExp(

        r'^project\s*:\s*',

        caseSensitive: false,

      ),

      '',

    );

    return 'Project: ${name.trim()}';

  }

  String getProjectName(Map<String, dynamic> entry) {

    final project = entry['projects'];

    if (project is Map) {

      final projectName =

          project['project_name']?.toString().trim();

      if (projectName != null && projectName.isNotEmpty) {

        return projectName;

      }

    }

    return 'No Project';

  }

  bool isSameDay(DateTime first, DateTime second) {

    return first.year == second.year &&

        first.month == second.month &&

        first.day == second.day;

  }

  Map<String, ProjectTimesheetRow> createProjectRows() {

    final rows = <String, ProjectTimesheetRow>{};

    for (final entry in entries) {

      final startTime = DateTime.tryParse(

        entry['start_time']?.toString() ?? '',

      )?.toLocal();

      if (startTime == null) continue;

      final projectKey = getProjectKey(entry);

      final projectName = getProjectName(entry);

      final minutes = entrySeconds(entry);

      final dayIndex = startTime.weekday - DateTime.monday;

      if (dayIndex < 0 || dayIndex > 6) continue;

      rows.putIfAbsent(

        projectKey,

        () => ProjectTimesheetRow(

          projectName: projectName,

        ),

      );

      rows[projectKey]!.minutesByDay[dayIndex] += minutes;

      rows[projectKey]!.entriesByDay[dayIndex].add(entry);

    }

    final sortedRows = rows.entries.toList()

      ..sort(

        (first, second) => first.value.projectName

            .toLowerCase()

            .compareTo(

              second.value.projectName.toLowerCase(),

            ),

      );

    return Map.fromEntries(sortedRows);

  }

  int getWeeklyTotalMinutes() {

    int total = 0;

    for (final entry in entries) {

      total += entrySeconds(entry);

    }

    return total;

  }

  List<int> getDailyTotals(

    Map<String, ProjectTimesheetRow> projectRows,

  ) {

    final totals = List<int>.filled(7, 0);

    for (final row in projectRows.values) {

      for (int index = 0; index < 7; index++) {

        totals[index] += row.minutesByDay[index];

      }

    }

    return totals;

  }

  int getWeeklyScreenshotCount() => screenshots.length;

  int getProjectScreenshotCount(ProjectTimesheetRow projectRow) {
    final projectEntryIds = <String>{};

    for (final dayEntries in projectRow.entriesByDay) {
      for (final entry in dayEntries) {
        final entryId = entry['id']?.toString().trim() ?? '';
        if (entryId.isNotEmpty) projectEntryIds.add(entryId);
      }
    }

    if (projectEntryIds.isEmpty) return 0;

    return screenshots.where((screenshot) {
      final timeEntryId = screenshot['time_entry_id']?.toString().trim() ?? '';
      return projectEntryIds.contains(timeEntryId);
    }).length;
  }

 String formatDuration(int seconds) {

  final safeSeconds = seconds < 0 ? 0 : seconds;

  final hours = safeSeconds ~/ 3600;

  final minutes = (safeSeconds % 3600) ~/ 60;

  final secs = safeSeconds % 60;

  return '${hours.toString().padLeft(2, '0')}:'

      '${minutes.toString().padLeft(2, '0')}:'

      '${secs.toString().padLeft(2, '0')}';

}

  String formatLongDuration(int seconds) {

  final safeSeconds = seconds < 0 ? 0 : seconds;

  final hours = safeSeconds ~/ 3600;

  final minutes = (safeSeconds % 3600) ~/ 60;

  final secs = safeSeconds % 60;

  return '${hours.toString().padLeft(2, '0')}:'

      '${minutes.toString().padLeft(2, '0')}:'

      '${secs.toString().padLeft(2, '0')}';

}

  String formatTime(DateTime? time) {

    if (time == null) return '--:--';

    final hour = time.hour == 0

        ? 12

        : time.hour > 12

            ? time.hour - 12

            : time.hour;

    final minute = time.minute.toString().padLeft(2, '0');

    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';

  }

  String weekTitle() {

    if (weekOffset == 0) return 'This Week';

    if (weekOffset == -1) return 'Last Week';

    return '${weekOffset.abs()} Weeks Ago';

  }

  String weekDateRange() {

    final start = getWeekStart();

    final end = getWeekEnd().subtract(

      const Duration(days: 1),

    );

    return '${start.day} ${monthName(start.month)}'

        ' – ${end.day} ${monthName(end.month)} ${end.year}';

  }

  String monthName(int month) {

    const months = [

      'Jan',

      'Feb',

      'Mar',

      'Apr',

      'May',

      'Jun',

      'Jul',

      'Aug',

      'Sep',

      'Oct',

      'Nov',

      'Dec',

    ];

    return months[month - 1];

  }

  String dayName(int weekday) {

    const days = [

      'Mon',

      'Tue',

      'Wed',

      'Thu',

      'Fri',

      'Sat',

      'Sun',

    ];

    return days[weekday - 1];

  }

  Future<void> refreshTimesheetScreen() async {

  await loadTimesheet();

}

  void goToPreviousWeek() {

    setState(() {

      weekOffset--;

    });

    refreshTimesheetScreen();

  }

  void goToNextWeek() {

    if (weekOffset >= 0) return;

    setState(() {

      weekOffset++;

    });

    refreshTimesheetScreen();

  }

  void goToCurrentWeek() {

    if (weekOffset == 0) return;

    setState(() {

      weekOffset = 0;

    });

    refreshTimesheetScreen();

  }

  void showDayDetails({

    required String projectName,

    required DateTime date,

    required List<Map<String, dynamic>> dayEntries,

  }) {

    if (dayEntries.isEmpty) return;

    final dayTotal = dayEntries.fold<int>(

  0,

  (total, entry) => total + entrySeconds(entry),

);

    showDialog<void>(

      context: context,

      builder: (dialogContext) {

        return AlertDialog(

          backgroundColor: AppColors.surface,

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(18),

          ),

          titlePadding: const EdgeInsets.fromLTRB(

            24,

            24,

            24,

            12,

          ),

          contentPadding: const EdgeInsets.fromLTRB(

            24,

            0,

            24,

            10,

          ),

          title: Row(

            children: [

              Container(

                width: 45,

                height: 45,

                decoration: BoxDecoration(

                  color: AppColors.primarySurface,

                  borderRadius: BorderRadius.circular(12),

                ),

                child: const Icon(

                  Icons.schedule_outlined,

                  color: AppColors.primary,

                ),

              ),

              const SizedBox(width: 13),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      projectDisplayName(projectName),

                      style: const TextStyle(

                        color: AppColors.textPrimary,

                        fontSize: 19,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                    const SizedBox(height: 3),

                    Text(

                      '${dayName(date.weekday)}, '

                      '${date.day} ${monthName(date.month)} ${date.year}',

                      style: const TextStyle(

                        color: AppColors.textSecondary,

                        fontSize: 13,

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          content: SizedBox(

            width: 520,

            child: SingleChildScrollView(

              child: Column(

                children: [

                  Container(

                    width: double.infinity,

                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(

                      color: AppColors.primarySurface,

                      borderRadius: BorderRadius.circular(12),

                      border: Border.all(

                        color: AppColors.primaryLight,

                      ),

                    ),

                    child: Row(

                      children: [

                        const Text(

                          'Daily total',

                          style: TextStyle(

                            color: AppColors.textSecondary,

                            fontWeight: FontWeight.w600,

                          ),

                        ),

                        const Spacer(),

                        Text(

                          formatLongDuration(dayTotal),

                          style: const TextStyle(

                            color: AppColors.primary,

                            fontWeight: FontWeight.bold,

                            fontSize: 16,

                          ),

                        ),

                      ],

                    ),

                  ),

                  const SizedBox(height: 14),

                  ...dayEntries.map(

                    (entry) => buildDetailEntry(entry),

                  ),

                ],

              ),

            ),

          ),

          actions: [

            FilledButton(

              style: FilledButton.styleFrom(

                backgroundColor: AppColors.primary,

                foregroundColor: Colors.white,

              ),

              onPressed: () {

                Navigator.of(dialogContext).pop();

              },

              child: const Text('Close'),

            ),

          ],

        );

      },

    );

  }

  Widget buildDetailEntry(Map<String, dynamic> entry) {

    final startTime = DateTime.tryParse(

      entry['start_time']?.toString() ?? '',

    )?.toLocal();

    final endTime = DateTime.tryParse(

      entry['end_time']?.toString() ?? '',

    )?.toLocal();

    final note = entry['note']?.toString().trim();

    final isRunning = entry['end_time'] == null;

    return Container(

      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color: AppColors.background,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(

          color: AppColors.border,

        ),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(

                isRunning

                    ? Icons.play_circle_outline

                    : Icons.check_circle_outline,

                size: 19,

                color: isRunning

                    ? AppColors.primary

                    : AppColors.success,

              ),

              const SizedBox(width: 8),

              Expanded(

                child: Text(

                  '${formatTime(startTime)} – '

                  '${isRunning ? 'Running' : formatTime(endTime)}',

                  style: const TextStyle(

                    color: AppColors.textPrimary,

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ),

              Text(

                formatDuration(entrySeconds(entry)),

                style: const TextStyle(

                  color: AppColors.textPrimary,

                  fontWeight: FontWeight.bold,

                ),

              ),

            ],

          ),

          if (note != null && note.isNotEmpty) ...[

            const SizedBox(height: 10),

            Text(

              note,

              style: const TextStyle(

                color: AppColors.textSecondary,

                height: 1.4,

              ),

            ),

          ],

        ],

      ),

    );

  }

  @override

  Widget build(BuildContext context) {

    final projectRows = createProjectRows();
    final dailyTotals = getDailyTotals(projectRows);
    final weeklyTotal = dailyTotals.fold<int>(
      0,
      (total, seconds) => total + seconds,
    );

    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(

        automaticallyImplyLeading: false,

        backgroundColor: AppColors.primary,

        foregroundColor: Colors.white,

        elevation: 0,

        centerTitle: true,

        title: Text(

          widget.isManager

              ? 'Team Timesheet'

              : 'My Timesheet',

          style: const TextStyle(

            color: Colors.white,

            fontWeight: FontWeight.bold,

          ),

        ),

        actions: [

          IconButton(

            tooltip: 'Refresh',

            onPressed: loading ? null : refreshTimesheetScreen,

            icon: const Icon(Icons.refresh),

          ),

        ],

      ),

      body: loading

          ? const Center(

              child: CircularProgressIndicator(

                color: AppColors.primary,

              ),

            )

          : errorMessage != null

              ? buildErrorState()

              : RefreshIndicator(

                  color: AppColors.primary,

                  onRefresh: refreshTimesheetScreen,

                  child: ListView(

                    physics:

                        const AlwaysScrollableScrollPhysics(),

                    padding: const EdgeInsets.fromLTRB(

                      20,

                      20,

                      20,

                      45,

                    ),

                    children: [

                      buildTopSection(weeklyTotal),

                      const SizedBox(height: 18),

                      buildWeekNavigation(),

                      const SizedBox(height: 20),

                      if (widget.isManager)

                        buildEmployeeSelector(),

                      if (widget.isManager)

                        const SizedBox(height: 20),

                      buildReadOnlyNotice(),

                      const SizedBox(height: 16),

                      projectRows.isEmpty

                          ? buildEmptyState()

                          : buildTimesheetTable(
                              projectRows,
                              dailyTotals,
                              weeklyTotal,
                            ),

                    ],

                  ),

                ),

    );

  }

  Widget buildTopSection(int weeklyTotal) {
    Widget periodInfo() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_view_week_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekTitle(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  weekDateRange(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget totalInfo() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'WEEK TOTAL',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatDuration(weeklyTotal),
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                periodInfo(),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: totalInfo(),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: periodInfo()),
              const SizedBox(width: 24),
              totalInfo(),
            ],
          );
        },
      ),
    );
  }

  Widget buildWeekNavigation() {

    return Row(

      children: [

        OutlinedButton.icon(

          style: OutlinedButton.styleFrom(

            foregroundColor: AppColors.primary,

            side: const BorderSide(

              color: AppColors.primary,

            ),

            padding: const EdgeInsets.symmetric(

              horizontal: 18,

              vertical: 15,

            ),

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(11),

            ),

          ),

          onPressed: goToPreviousWeek,

          icon: const Icon(Icons.chevron_left),

          label: const Text('Previous'),

        ),

        const SizedBox(width: 10),

        OutlinedButton.icon(

          style: OutlinedButton.styleFrom(

            foregroundColor: AppColors.primary,

            side: const BorderSide(

              color: AppColors.primary,

            ),

            padding: const EdgeInsets.symmetric(

              horizontal: 18,

              vertical: 15,

            ),

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(11),

            ),

          ),

          onPressed: weekOffset == 0

              ? null

              : goToCurrentWeek,

          icon: const Icon(Icons.today_outlined),

          label: const Text('This Week'),

        ),

        const SizedBox(width: 10),

        OutlinedButton.icon(

          style: OutlinedButton.styleFrom(

            foregroundColor: AppColors.primary,

            side: const BorderSide(

              color: AppColors.primary,

            ),

            padding: const EdgeInsets.symmetric(

              horizontal: 18,

              vertical: 15,

            ),

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(11),

            ),

          ),

          onPressed: weekOffset == 0

              ? null

              : goToNextWeek,

          icon: const Icon(Icons.chevron_right),

          label: const Text('Next'),

        ),

      ],

    );

  }

Widget buildEmployeeSelector() {

  return Container(

    padding: const EdgeInsets.symmetric(

      horizontal: 16,

      vertical: 6,

    ),

    decoration: BoxDecoration(

      color: AppColors.surface,

      borderRadius: BorderRadius.circular(12),

      border: Border.all(

        color: AppColors.border,

      ),

    ),

    child: Row(

      children: [

        const Icon(

          Icons.person_outline,

          color: AppColors.primary,

        ),

        const SizedBox(width: 12),

        const Text(

          'Employee',

          style: TextStyle(

            color: AppColors.textPrimary,

            fontWeight: FontWeight.bold,

          ),

        ),

        const SizedBox(width: 18),

        if (loadingEmployees)

          const SizedBox(

            width: 150,

            child: LinearProgressIndicator(

              color: AppColors.primary,

            ),

          )

        else

          Container(

            padding: const EdgeInsets.symmetric(

              horizontal: 14,

              vertical: 3,

            ),

            decoration: BoxDecoration(

              color: AppColors.primarySurface,

              borderRadius: BorderRadius.circular(10),

              border: Border.all(

                color: AppColors.primary,

                width: 1.5,

              ),

            ),

            child: DropdownButtonHideUnderline(

              child: DropdownButton<String>(

                value: employees.contains(

                  selectedEmployeeName,

                )

                    ? selectedEmployeeName

                    : null,

                isExpanded: false,

                dropdownColor: AppColors.surface,

                icon: const Padding(

                  padding: EdgeInsets.only(left: 6),

                  child: Icon(

                    Icons.keyboard_arrow_down_rounded,

                    color: AppColors.primary,

                    size: 22,

                  ),

                ),

                hint: const Text(

                  'Select employee',

                  style: TextStyle(

                    color: AppColors.primary,

                  ),

                ),

                style: const TextStyle(

                  color: AppColors.textPrimary,

                  fontSize: 15,

                  fontWeight: FontWeight.w600,

                ),

                items: employees

                    .map(

                      (employee) =>

                          DropdownMenuItem<String>(

                        value: employee,

                        child: Text(

                          employee,

                          overflow: TextOverflow.ellipsis,

                        ),

                      ),

                    )

                    .toList(),

                onChanged: (employee) {

                  if (employee == null ||

                      employee ==

                          selectedEmployeeName) {

                    return;

                  }

                  setState(() {

                    selectedEmployeeName = employee;

                    selectedEmployeeId =

                        employeeIdsByName[employee];

                  });

                  loadTimesheet();

                },

              ),

            ),

          ),

      ],

    ),

  );

}

Widget buildReadOnlyNotice() {

    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: 14,

        vertical: 12,

      ),

      decoration: BoxDecoration(

        color: AppColors.primarySurface,

        borderRadius: BorderRadius.circular(11),

        border: Border.all(

          color: AppColors.primaryLight,

        ),

      ),

      child: const Row(

        children: [

          Icon(

            Icons.lock_outline,

            color: AppColors.primary,

            size: 20,

          ),

          SizedBox(width: 10),

          Expanded(

            child: Text(

              'This timesheet is read-only. Hours are added automatically from the timer.',

              style: TextStyle(

                color: AppColors.textPrimary,

                fontWeight: FontWeight.w500,

              ),

            ),

          ),

        ],

      ),

    );

  }

  Widget buildTimesheetTable(
    Map<String, ProjectTimesheetRow> projectRows,
    List<int> dailyTotals,
    int weeklyTotal,
  ) {
    final weekDays = getWeekDays();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 67,
            dataRowMinHeight: 62,
            dataRowMaxHeight: 72,
            horizontalMargin: 20,
            columnSpacing: 22,
            headingRowColor: const WidgetStatePropertyAll(
              AppColors.primarySurface,
            ),
            columns: [
              const DataColumn(
                label: SizedBox(
                  width: 175,
                  child: Text(
                    'PROJECT',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ...weekDays.map(
                (date) => DataColumn(
                  numeric: true,
                  label: SizedBox(
                    width: 78,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          dayName(date.weekday).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${date.day} ${monthName(date.month)}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const DataColumn(
                numeric: true,
                label: SizedBox(
                  width: 72,
                  child: Tooltip(
                    message: 'Total screenshots captured this week',
                    child: Text(
                      'TOTAL SS',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const DataColumn(
                numeric: true,
                label: SizedBox(
                  width: 86,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            rows: [
              ...projectRows.values.map(
                (projectRow) => DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 175,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.folder_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                projectDisplayName(projectRow.projectName),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...List.generate(7, (dayIndex) {
                      final seconds = projectRow.minutesByDay[dayIndex];
                      final date = weekDays[dayIndex];

                      return DataCell(
                        SizedBox(
                          width: 78,
                          child: Text(
                            seconds == 0 ? '—' : formatDuration(seconds),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            style: TextStyle(
                              color: seconds == 0
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontWeight: seconds == 0
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        onTap: seconds == 0
                            ? null
                            : () {
                                showDayDetails(
                                  projectName: projectRow.projectName,
                                  date: date,
                                  dayEntries:
                                      projectRow.entriesByDay[dayIndex],
                                );
                              },
                      );
                    }),
                    DataCell(
                      SizedBox(
                        width: 72,
                        child: Text(
                          getProjectScreenshotCount(projectRow).toString(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 86,
                        child: Text(
                          formatDuration(projectRow.totalMinutes),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DataRow(
                color: const WidgetStatePropertyAll(
                  AppColors.primarySurface,
                ),
                cells: [
                  const DataCell(
                    SizedBox(
                      width: 175,
                      child: Text(
                        'TOTAL',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ...dailyTotals.map(
                    (seconds) => DataCell(
                      SizedBox(
                        width: 78,
                        child: Text(
                          formatDuration(seconds),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 72,
                      child: Text(
                        getWeeklyScreenshotCount().toString(),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 86,
                      child: Text(
                        formatDuration(weeklyTotal),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildWeeklyTeamTimeSection() {

    final teamTotalMinutes = weeklyTeamTimes.fold<int>(

      0,

      (total, employee) => total + employee.totalMinutes,

    );

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(

        color: AppColors.surface,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(

          color: AppColors.border,

        ),

        boxShadow: const [

          BoxShadow(

            color: Color(0x0D000000),

            blurRadius: 18,

            offset: Offset(0, 7),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Row(

            children: [

              Icon(

                Icons.donut_large_outlined,

                color: AppColors.primary,

                size: 25,

              ),

              SizedBox(width: 10),

              Text(

                'Weekly Team Time',

                style: TextStyle(

                  color: AppColors.textPrimary,

                  fontSize: 20,

                  fontWeight: FontWeight.bold,

                ),

              ),

            ],

          ),

          const SizedBox(height: 6),

          Text(

            'Total time worked by your team for ${weekTitle().toLowerCase()}.',

            style: const TextStyle(

              color: AppColors.textSecondary,

            ),

          ),

          const SizedBox(height: 22),

          if (loadingTeamTime)

            const Center(

              child: Padding(

                padding: EdgeInsets.symmetric(vertical: 42),

                child: CircularProgressIndicator(

                  color: AppColors.primary,

                ),

              ),

            )

          else if (teamTimeErrorMessage != null)

            Center(

              child: Padding(

                padding: const EdgeInsets.symmetric(vertical: 28),

                child: Column(

                  children: [

                    const Icon(

                      Icons.cloud_off_outlined,

                      color: AppColors.danger,

                      size: 40,

                    ),

                    const SizedBox(height: 10),

                    Text(

                      teamTimeErrorMessage!,

                      style: const TextStyle(

                        color: AppColors.textSecondary,

                      ),

                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(

                      onPressed: loadWeeklyTeamTime,

                      icon: const Icon(Icons.refresh),

                      label: const Text('Try Again'),

                    ),

                  ],

                ),

              ),

            )

          else if (weeklyTeamTimes.isEmpty)

            const Center(

              child: Padding(

                padding: EdgeInsets.symmetric(vertical: 38),

                child: Text(

                  'No team time recorded for this week.',

                  style: TextStyle(

                    color: AppColors.textSecondary,

                    fontWeight: FontWeight.w500,

                  ),

                ),

              ),

            )

          else

            LayoutBuilder(

              builder: (context, constraints) {

                final useVerticalLayout = constraints.maxWidth < 760;

                final chart = buildWeeklyTeamDonut(

                  teamTotalMinutes,

                );

                final legend = buildWeeklyTeamLegend();

                if (useVerticalLayout) {

                  return Column(

                    children: [

                      chart,

                      const SizedBox(height: 25),

                      legend,

                    ],

                  );

                }

                return Row(

                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [

                    Expanded(child: legend),

                    const SizedBox(width: 32),

                    chart,

                  ],

                );

              },

            ),

        ],

      ),

    );

  }

  Widget buildWeeklyTeamDonut(int teamTotalMinutes) {

    return SizedBox(

      width: 290,

      height: 290,

      child: Stack(

        alignment: Alignment.center,

        children: [

          PieChart(

            PieChartData(

              startDegreeOffset: -90,

              centerSpaceRadius: 76,

              sectionsSpace: 3,

              borderData: FlBorderData(show: false),

              sections: List.generate(

                weeklyTeamTimes.length,

                (index) {

                  final employee = weeklyTeamTimes[index];

                  final isCurrentEmployee = employee.employeeName

                          .trim()

                          .toLowerCase() ==

                      currentUserName.trim().toLowerCase();

                  return PieChartSectionData(

                    value: employee.totalMinutes.toDouble(),

                    color: teamChartColor(index),

                    radius: isCurrentEmployee ? 61 : 52,

                    showTitle: false,

                    badgePositionPercentageOffset: 1.1,

                  );

                },

              ),

            ),

            duration: const Duration(milliseconds: 500),

            curve: Curves.easeOutCubic,

          ),

          Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              Text(

                formatDuration(teamTotalMinutes),

                style: const TextStyle(

                  color: AppColors.textPrimary,

                  fontSize: 25,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 3),

              const Text(

                'TEAM TOTAL',

                style: TextStyle(

                  color: AppColors.textSecondary,

                  fontSize: 11,

                  fontWeight: FontWeight.bold,

                  letterSpacing: 0.6,

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }

  Widget buildWeeklyTeamLegend() {

    return Column(

      children: List.generate(

        weeklyTeamTimes.length,

        (index) {

          final employee = weeklyTeamTimes[index];

          final isCurrentEmployee = employee.employeeName

                  .trim()

                  .toLowerCase() ==

              currentUserName.trim().toLowerCase();

          return Container(

            margin: const EdgeInsets.only(bottom: 10),

            padding: const EdgeInsets.symmetric(

              horizontal: 14,

              vertical: 13,

            ),

            decoration: BoxDecoration(

              color: isCurrentEmployee

                  ? AppColors.primarySurface

                  : AppColors.background,

              borderRadius: BorderRadius.circular(12),

              border: Border.all(

                color: isCurrentEmployee

                    ? AppColors.primaryLight

                    : AppColors.border,

                width: isCurrentEmployee ? 1.4 : 1,

              ),

            ),

            child: Row(

              children: [

                Container(

                  width: 13,

                  height: 13,

                  decoration: BoxDecoration(

                    color: teamChartColor(index),

                    shape: BoxShape.circle,

                  ),

                ),

                const SizedBox(width: 11),

                Expanded(

                  child: Text(

                    isCurrentEmployee

                        ? '${employee.employeeName} (You)'

                        : employee.employeeName,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(

                      color: AppColors.textPrimary,

                      fontWeight: isCurrentEmployee

                          ? FontWeight.bold

                          : FontWeight.w600,

                    ),

                  ),

                ),

                const SizedBox(width: 12),

                Text(

                  formatDuration(employee.totalMinutes),

                  style: TextStyle(

                    color: isCurrentEmployee

                        ? AppColors.primary

                        : AppColors.textPrimary,

                    fontWeight: FontWeight.bold,

                  ),

                ),

              ],

            ),

          );

        },

      ),

    );

  }

  Color teamChartColor(int index) {

    const colors = [

      Color(0xFFFF6B00),

      Color(0xFF2478C9),

      Color(0xFF65A030),

      Color(0xFF8B5CF6),

      Color(0xFFE5484D),

      Color(0xFF0F9D8A),

      Color(0xFFE5A000),

      Color(0xFF64748B),

    ];

    return colors[index % colors.length];

  }

  Widget buildEmptyState() {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.symmetric(

        horizontal: 28,

        vertical: 65,

      ),

      decoration: BoxDecoration(

        color: AppColors.surface,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(

          color: AppColors.border,

        ),

      ),

      child: const Column(

        children: [

          Icon(

            Icons.calendar_view_week_outlined,

            size: 60,

            color: AppColors.primary,

          ),

          SizedBox(height: 16),

          Text(

            'No tracked time this week',

            style: TextStyle(

              color: AppColors.textPrimary,

              fontSize: 19,

              fontWeight: FontWeight.bold,

            ),

          ),

          SizedBox(height: 7),

          Text(

            'Time recorded using the timer will appear here.',

            textAlign: TextAlign.center,

            style: TextStyle(

              color: AppColors.textSecondary,

            ),

          ),

        ],

      ),

    );

  }

  Widget buildErrorState() {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(30),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            const Icon(

              Icons.cloud_off_outlined,

              size: 58,

              color: AppColors.danger,

            ),

            const SizedBox(height: 16),

            Text(

              errorMessage ??

                  'Unable to load the timesheet.',

              textAlign: TextAlign.center,

              style: const TextStyle(

                color: AppColors.textSecondary,

                fontSize: 16,

              ),

            ),

            const SizedBox(height: 20),

            FilledButton.icon(

              style: FilledButton.styleFrom(

                backgroundColor: AppColors.primary,

                foregroundColor: Colors.white,

              ),

              onPressed: initializeScreen,

              icon: const Icon(Icons.refresh),

              label: const Text('Try Again'),

            ),

          ],

        ),

      ),

    );

  }

}

class EmployeeWeeklyTime {

  final String employeeName;

  final int totalMinutes;

  const EmployeeWeeklyTime({

    required this.employeeName,

    required this.totalMinutes,

  });

}

class ProjectTimesheetRow {

  final String projectName;

  final List<int> minutesByDay = List<int>.filled(

    7,

    0,

  );

  final List<List<Map<String, dynamic>>> entriesByDay =

      List.generate(

    7,

    (_) => <Map<String, dynamic>>[],

  );

  ProjectTimesheetRow({

    required this.projectName,

  });

  int get totalMinutes {

    return minutesByDay.fold(

      0,

      (total, minutes) => total + minutes,

    );

  }

}

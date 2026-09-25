import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/session_timeout_service.dart';

import 'billing_screen.dart';
import 'change_password_screen.dart';
import 'employee_management_screen.dart';
import 'leave_approval_screen.dart';
import 'leave_request_screen.dart';
import 'login_screen.dart';
import 'project_management_screen.dart';
import 'screenshot_gallery_screen.dart';
import 'keyboard_activity_screen.dart';
import 'timer_screen.dart';
import 'timesheet_screen.dart';
import 'weekly_report_screen.dart';
import 'workspace_screen.dart';
import '../services/update_service.dart';
import '../services/time_entry_service.dart';
import '../services/timer_safety_service.dart';
import '../widgets/dashboard/admin_weekly_overview.dart';
import 'ai_summary_screen.dart';

import '../widgets/dashboard/dashboard_sidebar.dart';

class _MutableAdminEmployeeWeekSummary {
  final String employeeId;
  String employeeName;
  Duration thisWeek;
  Duration previousWeek;
  bool isWorking;

  _MutableAdminEmployeeWeekSummary({
    required this.employeeId,
    required this.employeeName,
    this.thisWeek = Duration.zero,
    this.previousWeek = Duration.zero,
    this.isWorking = false,
  });
}

class DashboardV2Screen extends StatefulWidget {
  const DashboardV2Screen({super.key});

  @override
  State<DashboardV2Screen> createState() =>
      _DashboardV2ScreenState();
}

class _DashboardV2ScreenState extends State<DashboardV2Screen> {
  static const Color orange = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color darkText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color groupBackground = Color(0xFFF1F5F9);

  bool loading = true;
  String? errorMessage;

  DateTime now = DateTime.now();
  Timer? clockTimer;

  List<Map<String, dynamic>> weekEntries = [];
  List<Map<String, dynamic>> previousWeekEntries = [];
  Map<String, dynamic>? runningEntry;
  Map<String, String> employeeNamesById = {};

  final Set<String> expandedDateGroups = <String>{};
  final Set<String> expandedEmployeeGroups = <String>{};


  String selectedPage = 'dashboard';
  bool sidebarCollapsed = false;

  bool get isAdmin =>
      currentUserRole.trim().toLowerCase() == 'admin';

  DateTime get weekStart {
    final localNow = DateTime.now();

    final today = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
    );

    return today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
  }

  DateTime get nextWeekStart =>
      weekStart.add(const Duration(days: 7));

  DateTime get previousWeekStart =>
      weekStart.subtract(const Duration(days: 7));

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
});

    // Inactivity logout is intentionally disabled.
    // Timer safety is handled separately.
    TimerSafetyService
        .instance
        .forcedStopNotifier
        .addListener(
          _handleForcedTimerStop,
        );

    loadDashboard();

    clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    TimerSafetyService
        .instance
        .forcedStopNotifier
        .removeListener(
          _handleForcedTimerStop,
        );

    clockTimer?.cancel();
    SessionTimeoutService.instance.stop();
    super.dispose();
  }

  void resetSessionTimer() {
    // Inactivity logout is disabled.
  }

  void _handleForcedTimerStop() {
    final event = TimerSafetyService
        .instance
        .forcedStopNotifier
        .value;

    if (event == null || isAdmin || !mounted) {
      return;
    }

    final entryIndex = weekEntries.indexWhere(
      (entry) =>
          entry['id']?.toString() ==
          event.entryId,
    );

    if (entryIndex >= 0) {
      final existing =
          Map<String, dynamic>.from(
        weekEntries[entryIndex],
      );

      final start = DateTime.tryParse(
        existing['start_time']?.toString() ?? '',
      )?.toLocal();

      final stoppedAtLocal =
          event.stoppedAt.toLocal();

      final durationMinutes = start == null
          ? 0
          : stoppedAtLocal
              .difference(start)
              .inMinutes;

      // Keep the dashboard's local copy in the same wall-clock time
      // that the employee sees. Converting this to UTC was what created
      // rows such as 17:02 -> 12:03 on the dashboard.
      existing['end_time'] =
          stoppedAtLocal.toIso8601String();

      existing['duration_minutes'] =
          durationMinutes < 0
              ? 0
              : durationMinutes;

      weekEntries[entryIndex] = existing;
    }

    setState(() {
      if (runningEntry?['id']?.toString() ==
          event.entryId) {
        runningEntry = null;
      }

      now = event.stoppedAt;
    });
  }

  Future<void> logout() async {
    SessionTimeoutService.instance.stop();

    await TimerSafetyService.instance
        .stopBeforeLogout(
      userId: currentUserId,
      workspaceId: currentWorkspaceId,
      reason: TimerAutoStopReason.logout,
    );

    await supabase.auth.signOut();

    currentUserId = '';
    currentUserName = '';
    currentUserRole = '';
    currentWorkspaceId = '';
    currentWorkspaceName = '';

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }
Future<void> loadDashboard() async {
  if (!mounted) return;

  setState(() {
    loading = true;
    errorMessage = null;
  });

  try {
    // ---------------------------------------------------------
    // 1. LOAD THIS WEEK'S ENTRIES
    // ---------------------------------------------------------
    var query = supabase
        .from('time_entries')
        .select(
          'id, employee_id, employee_name, project_id, '
          'start_time, end_time, duration_minutes, note, '
          'projects(project_name)',
        )
        .eq('workspace_id', currentWorkspaceId)
        .gte(
          'start_time',
          weekStart.toUtc().toIso8601String(),
        )
        .lt(
          'start_time',
          nextWeekStart.toUtc().toIso8601String(),
        );

    if (!isAdmin) {
      query = query.eq(
        'employee_id',
        currentUserId,
      );
    }

    final response = await query.order(
      'start_time',
      ascending: false,
    );

    final entries =
        List<Map<String, dynamic>>.from(response);

final profilesResponse = await supabase
    .from('profiles')
    .select('id, full_name')
    .eq('workspace_id', currentWorkspaceId);

final profiles =
    List<Map<String, dynamic>>.from(
  profilesResponse,
);

final namesById = <String, String>{};

for (final profile in profiles) {
  final id =
      profile['id']?.toString().trim() ?? '';

  final name =
      profile['full_name']?.toString().trim() ?? '';

  if (id.isNotEmpty && name.isNotEmpty) {
    namesById[id] = name;
  }
}

    // ---------------------------------------------------------
    // 2. ADMIN ONLY: LOAD THE PREVIOUS WEEK
    //    This is used by the admin comparison card. Employees
    //    keep the existing dashboard and do not need this query.
    // ---------------------------------------------------------
    List<Map<String, dynamic>> previousEntries = [];

    if (isAdmin) {
      final previousResponse = await supabase
          .from('time_entries')
          .select(
            'id, employee_id, employee_name, project_id, '
            'start_time, end_time, duration_minutes, note, '
            'projects(project_name)',
          )
          .eq(
            'workspace_id',
            currentWorkspaceId,
          )
          .gte(
            'start_time',
            previousWeekStart.toUtc().toIso8601String(),
          )
          .lt(
            'start_time',
            weekStart.toUtc().toIso8601String(),
          )
          .order(
            'start_time',
            ascending: false,
          );

      previousEntries =
          List<Map<String, dynamic>>.from(previousResponse);
    }

    // ---------------------------------------------------------
    // 3. LOAD RUNNING TIMER SEPARATELY
    //    IMPORTANT:
    //    Do NOT depend on the weekly query to find it.
    // ---------------------------------------------------------
    Map<String, dynamic>? active;

    if (!isAdmin) {
      final runningResponse = await supabase
          .from('time_entries')
          .select(
            'id, employee_id, employee_name, project_id, '
            'start_time, end_time, duration_minutes, note, '
            'projects(project_name)',
          )
          .eq(
            'workspace_id',
            currentWorkspaceId,
          )
          .eq(
            'employee_id',
            currentUserId,
          )
          .isFilter(
            'end_time',
            null,
          )
          .order(
            'start_time',
            ascending: false,
          )
          .limit(1);

      final runningList =
          List<Map<String, dynamic>>.from(
        runningResponse,
      );

      if (runningList.isNotEmpty) {
        active = runningList.first;

        // -----------------------------------------------------
        // Make sure the running entry also exists in weekEntries
        // so TODAY + THIS WEEK TOTAL update immediately.
        // -----------------------------------------------------
        final activeId =
            active['id']?.toString();

        final alreadyExists = entries.any(
          (entry) =>
              entry['id']?.toString() == activeId,
        );

        if (!alreadyExists) {
          entries.insert(0, active);
        }
      }
    } else {
      // Admin dashboard can still identify active employee rows
      // for Working / Offline status.
      for (final entry in entries) {
        if (entry['end_time'] == null) {
          active ??= entry;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      weekEntries = entries;
      previousWeekEntries = previousEntries;
      employeeNamesById = namesById;

      // Employee gets their own running timer.
      // Admin does not need the employee-style timer card.
      runningEntry = isAdmin ? null : active;

      loading = false;
      now = DateTime.now();

      final todayKey = _dateKey(
        DateTime.now(),
      );

      expandedDateGroups.add(todayKey);
    });
  } catch (error) {
    debugPrint(
      'Dashboard load error: $error',
    );

    if (!mounted) return;

    setState(() {
      loading = false;
      errorMessage =
          'Unable to load this week’s time entries.';
    });
  }
}

  DateTime? _parseLocalDate(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  DateTime? _resolvedEntryEnd(
    Map<String, dynamic> entry,
    DateTime start,
  ) {
    final storedEnd = _parseLocalDate(
      entry['end_time'],
    );

    if (storedEnd == null) {
      return null;
    }

    if (!storedEnd.isBefore(start)) {
      return storedEnd;
    }

    /*
     * Older automatic-stop rows were written using UTC wall-clock values
     * into a local timestamp column. Example:
     *   real 17:47:15 became stored/displayed around 12:02:15.
     *
     * Reinterpret those wall-clock components as UTC and convert them
     * back to local time. This preserves the SECONDS too, so Dashboard
     * and Timesheet can match exactly instead of losing ~45 minutes.
     */
    final correctedEnd = DateTime.utc(
      storedEnd.year,
      storedEnd.month,
      storedEnd.day,
      storedEnd.hour,
      storedEnd.minute,
      storedEnd.second,
      storedEnd.millisecond,
      storedEnd.microsecond,
    ).toLocal();

    final correctedDuration =
        correctedEnd.difference(start);

    if (!correctedEnd.isBefore(start) &&
        correctedDuration <= const Duration(hours: 24)) {
      return correctedEnd;
    }

    /*
     * Final fallback for very old rows where only duration_minutes
     * is trustworthy. This can only preserve whole minutes.
     */
    final storedMinutes = int.tryParse(
          entry['duration_minutes']?.toString() ?? '',
        ) ??
        0;

    if (storedMinutes > 0) {
      return start.add(
        Duration(minutes: storedMinutes),
      );
    }

    return storedEnd;
  }

  Duration _entryDuration(
    Map<String, dynamic> entry,
  ) {
    final start = _parseLocalDate(
      entry['start_time'],
    );

    if (start == null) {
      return Duration.zero;
    }

    // Running entry: calculate live duration.
    if (entry['end_time'] == null) {
      final liveDuration = now.difference(start);

      return liveDuration.isNegative
          ? Duration.zero
          : liveDuration;
    }

    final end = _resolvedEntryEnd(
      entry,
      start,
    );

    if (end == null || end.isBefore(start)) {
      return Duration.zero;
    }

    final calculated = end.difference(start);

    if (calculated > const Duration(hours: 24)) {
      return Duration.zero;
    }

    return calculated;
  }

  String _entryEndText(
    Map<String, dynamic> entry,
  ) {
    if (entry['end_time'] == null) {
      return 'Running';
    }

    final start = _parseLocalDate(
      entry['start_time'],
    );

    if (start == null) {
      return formatEntryTime(
        entry['end_time'],
      );
    }

    final end = _resolvedEntryEnd(
      entry,
      start,
    );

    if (end == null) {
      return '--:--';
    }

    return formatEntryTime(end);
  }

  Duration get thisWeekDuration {
    Duration total = Duration.zero;

    for (final entry in weekEntries) {
      total += _entryDuration(entry);
    }

    return total;
  }


  String _projectDisplayName(dynamic value) {
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

    if (name.trim().isEmpty) {
      return 'Project: No Project';
    }

    return 'Project: ${name.trim()}';
  }

  String _employeeDisplayName(
  Map<String, dynamic> entry,
) {
  final employeeId =
      entry['employee_id']?.toString().trim() ?? '';

  final currentProfileName =
      employeeNamesById[employeeId]?.trim() ?? '';

  if (currentProfileName.isNotEmpty) {
    return currentProfileName;
  }

  final savedName =
      entry['employee_name']?.toString().trim() ?? '';

  if (savedName.isNotEmpty) {
    return savedName;
  }

  if (employeeId == currentUserId &&
      currentUserName.trim().isNotEmpty) {
    return currentUserName.trim();
  }

  return 'Unknown Employee';
}


  List<AdminEmployeeWeekSummary> get adminEmployeeWeekSummaries {
    final summaries =
        <String, _MutableAdminEmployeeWeekSummary>{};

    void addEntries(
      List<Map<String, dynamic>> entries, {
      required bool currentWeek,
    }) {
      for (final entry in entries) {
        final employeeId =
            entry['employee_id']?.toString().trim() ?? '';

        final employeeName =
    _employeeDisplayName(entry);

        // Prefer employee_id so two employees with the same name
        // are not merged. Fall back to the name for older rows.
        final key = employeeId.isNotEmpty
            ? employeeId
            : 'name:${employeeName.toLowerCase()}';

        final summary = summaries.putIfAbsent(
          key,
          () => _MutableAdminEmployeeWeekSummary(
            employeeId: employeeId,
            employeeName: employeeName,
          ),
        );

        if (summary.employeeName == 'Unknown Employee' &&
            employeeName != 'Unknown Employee') {
          summary.employeeName = employeeName;
        }

        final duration = _entryDuration(entry);

        if (currentWeek) {
          summary.thisWeek += duration;

          if (entry['end_time'] == null) {
            summary.isWorking = true;
          }
        } else {
          summary.previousWeek += duration;
        }
      }
    }

    addEntries(
      weekEntries,
      currentWeek: true,
    );

    addEntries(
      previousWeekEntries,
      currentWeek: false,
    );

    final result = summaries.values
        .map(
          (item) => AdminEmployeeWeekSummary(
            employeeId: item.employeeId,
            employeeName: item.employeeName,
            thisWeek: item.thisWeek,
            previousWeek: item.previousWeek,
            isWorking: item.isWorking,
          ),
        )
        .toList();

    result.sort((a, b) {
      final byCurrent =
          b.thisWeek.compareTo(a.thisWeek);

      if (byCurrent != 0) {
        return byCurrent;
      }

      return a.employeeName
          .toLowerCase()
          .compareTo(
            b.employeeName.toLowerCase(),
          );
    });

    return result;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String dateGroupKey(
    Map<String, dynamic> entry,
  ) {
    final date = _parseLocalDate(
      entry['start_time'],
    );

    if (date == null) {
      return 'unknown';
    }

    return _dateKey(date);
  }

  Map<String, List<Map<String, dynamic>>>
      groupedEntries() {
    final groups =
        <String, List<Map<String, dynamic>>>{};

    for (final entry in weekEntries) {
      final key = dateGroupKey(entry);

      groups.putIfAbsent(
        key,
        () => [],
      );

      groups[key]!.add(entry);
    }

    return groups;
  }

  Map<String, List<Map<String, dynamic>>> groupByEmployee(
  List<Map<String, dynamic>> entries,
) {
  final groups = <String, List<Map<String, dynamic>>>{};

  for (final entry in entries) {
    final employee =
    _employeeDisplayName(entry);

    groups.putIfAbsent(employee, () => []);
    groups[employee]!.add(entry);
  }

  return groups;
}

  Duration durationForEntries(
    List<Map<String, dynamic>> entries,
  ) {
    Duration total = Duration.zero;

    for (final entry in entries) {
      total += _entryDuration(entry);
    }

    return total;
  }

  String formatClockDuration(Duration duration) {
    final safeDuration = duration.isNegative
        ? Duration.zero
        : duration;

    final hours = safeDuration.inHours;
    final minutes =
        safeDuration.inMinutes.remainder(60);
    final seconds =
        safeDuration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String formatEntryTime(dynamic value) {
    final date = _parseLocalDate(value);

    if (date == null) {
      return '--:--';
    }

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String dateGroupLabel(
    List<Map<String, dynamic>> entries,
  ) {
    if (entries.isEmpty) {
      return 'UNKNOWN DATE';
    }

    final date = _parseLocalDate(
      entries.first['start_time'],
    );

    if (date == null) {
      return 'UNKNOWN DATE';
    }

    final current = DateTime.now();

    final today = DateTime(
      current.year,
      current.month,
      current.day,
    );

    final entryDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    if (entryDate == today) {
      return 'TODAY';
    }

    if (entryDate ==
        today.subtract(const Duration(days: 1))) {
      return 'YESTERDAY';
    }

    const weekdays = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ];

    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    return '${weekdays[date.weekday - 1]}, '
        '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }

  String greeting() {
    if (now.hour < 12) {
      return 'Good Morning';
    }

    if (now.hour < 17) {
      return 'Good Afternoon';
    }

    return 'Good Evening';
  }

  String dateText() {
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

    return '${months[now.month - 1]} '
        '${now.day}, ${now.year}';
  }

  String timeText() {
    final rawHour = now.hour % 12;
    final hour = rawHour == 0 ? 12 : rawHour;
    final minute =
        now.minute.toString().padLeft(2, '0');
    final suffix =
        now.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $suffix';
  }

Widget buildHeader() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 16,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8F1),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFFFED7AA),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${greeting()}, $currentUserName 👋',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                currentWorkspaceName,
                style: const TextStyle(
                  fontSize: 14,
                  color: secondaryText,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _headerPill(
                    Icons.calendar_today_outlined,
                    dateText(),
                  ),
                  _headerPill(
                    Icons.access_time,
                    timeText(),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ADMIN EMPLOYEE STATUS
        if (isAdmin &&
    adminEmployeeWeekSummaries.isNotEmpty) ...[
  ConstrainedBox(
    constraints: const BoxConstraints(
      maxWidth: 560,
    ),
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        ...adminEmployeeWeekSummaries
            .take(2)
            .map(
              (employee) => _employeeStatusItem(
                employeeName: employee.employeeName,
                isWorking: employee.isWorking,
              ),
            ),

        if (adminEmployeeWeekSummaries.length > 2)
          _moreEmployeesButton(),
      ],
    ),
  ),

  const SizedBox(width: 18),
],

        // ADMIN AVATAR
        CircleAvatar(
          radius: 28,
          backgroundColor: orange,
          child: Text(
            currentUserName.isNotEmpty
                ? currentUserName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
  Widget _employeeStatusItem({
    required String employeeName,
    required bool isWorking,
  }) {
    final statusColor = isWorking
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFFFE8D5),
            child: Text(
              employeeName.isNotEmpty
                  ? employeeName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: orange,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 140,
                ),
                child: Text(
                  employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isWorking ? 'Working' : 'Offline',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
Widget _moreEmployeesButton() {
  final remaining =
      adminEmployeeWeekSummaries.length - 2;

  return PopupMenuButton<void>(
    tooltip: 'View all employees',

    offset: const Offset(0, 48),

    color: Colors.white,

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),

    itemBuilder: (context) {
      return [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 340,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TEAM STATUS',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '${adminEmployeeWeekSummaries.length} employees',
                    style: const TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Divider(height: 1),

                  const SizedBox(height: 8),

                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 340,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children:
                            adminEmployeeWeekSummaries
                                .map((employee) {
                          final statusColor =
                              employee.isWorking
                                  ? const Color(
                                      0xFF22C55E,
                                    )
                                  : const Color(
                                      0xFFEF4444,
                                    );

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        statusColor,
                                    shape:
                                        BoxShape.circle,
                                  ),
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      const Color(
                                    0xFFFFE8D5,
                                  ),
                                  child: Text(
                                    employee.employeeName
                                            .isNotEmpty
                                        ? employee
                                            .employeeName[0]
                                            .toUpperCase()
                                        : '?',
                                    style:
                                        const TextStyle(
                                      color: orange,
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                Expanded(
                                  child: Text(
                                    employee.employeeName,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      color: darkText,
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                Text(
                                  employee.isWorking
                                      ? 'Working'
                                      : 'Offline',
                                  style: TextStyle(
                                    color:
                                        statusColor,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    },

    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.groups_outlined,
            color: orange,
            size: 18,
          ),

          const SizedBox(width: 7),

          Text(
            '+$remaining more',
            style: const TextStyle(
              color: orange,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _headerPill(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: secondaryText,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRunningTimer() {
    if (runningEntry == null) {
      return const SizedBox.shrink();
    }

    final entry = runningEntry!;

    final project = _projectDisplayName(
      entry['projects']?['project_name'],
    );

    final employee =
    _employeeDisplayName(entry);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFDBA74),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stop,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  project,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employee,
                  style: const TextStyle(
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatClockDuration(
              _entryDuration(entry),
            ),
            style: const TextStyle(
              color: orange,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
            ),
            onPressed: openTimerScreen,
            child: const Text('Open Timer'),
          ),
        ],
      ),
    );
  }

  Widget buildActivityList() {
    final groups = groupedEntries();
    final groupEntries = groups.entries.toList();

    if (groupEntries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 70,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.history,
              size: 50,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 14),
            Text(
              'No time entries this week',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkText,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            color: Colors.white,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'THIS WEEK TOTAL',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  formatClockDuration(
                    thisWeekDuration,
                  ),
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...groupEntries.map(
            (group) => buildDateGroup(
              group.key,
              group.value,
            ),
          ),
        ],
      ),
    );
  }

Widget buildDateGroup(
  String groupKey,
  List<Map<String, dynamic>> entries,
) {
  final expanded = expandedDateGroups.contains(groupKey);
  final total = durationForEntries(entries);

  return Column(
    children: [
      InkWell(
        onTap: () {
          setState(() {
            if (expanded) {
              expandedDateGroups.remove(groupKey);
            } else {
              expandedDateGroups.add(groupKey);
            }
          });
        },
        child: Container(
          color: Color(0xFFFFF8F1),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
          child: Row(
            children: [
              Icon(
                expanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                color: orange,
                size: 22,
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.calendar_month_outlined,
                color: secondaryText,
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  dateGroupLabel(entries),
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatClockDuration(total),
                style: const TextStyle(
                  color: darkText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      if (expanded)
  ...(isAdmin
      ? buildEmployeeGroups(groupKey, entries)
      : entries.map(buildTimeEntryRow)),
      const Divider(
        height: 1,
        thickness: 1,
        color: borderColor,
      ),
    ],
  );
}


List<Widget> buildEmployeeGroups(
  String dayKey,
  List<Map<String, dynamic>> entries,
) {
  final grouped = groupByEmployee(entries);

  final employeeGroups = grouped.entries.toList();

employeeGroups.sort((a, b) {
  final aTotal = durationForEntries(a.value);
  final bTotal = durationForEntries(b.value);

  return bTotal.compareTo(aTotal);
});

return employeeGroups.map((employeeGroup) {
    final employee = employeeGroup.key;
    final employeeEntries = employeeGroup.value;

    final employeeKey = '$dayKey-$employee';

    final expanded =
        expandedEmployeeGroups.contains(employeeKey);

    final total = durationForEntries(employeeEntries);

    return Column(
      children: [

        InkWell(
          onTap: () {
            setState(() {
              if (expanded) {
                expandedEmployeeGroups.remove(employeeKey);
              } else {
                expandedEmployeeGroups.add(employeeKey);
              }
            });
          },

          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.only(
              left: 45,
              right: 20,
              top: 14,
              bottom: 14,
            ),

            child: Row(
              children: [

                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: orange,
                ),

                const SizedBox(width: 8),

                Container(
  width: 10,
  height: 10,
  decoration: BoxDecoration(
    color: employeeEntries.any((e) => e['end_time'] == null)
        ? Colors.green
        : Colors.red,
    shape: BoxShape.circle,
  ),
),

const SizedBox(width: 10),

                Expanded(
  child: Row(
    children: [
      Text(
        employeeEntries.any((e) => e['end_time'] == null)
            ? 'Working'
            : 'Offline',
        style: TextStyle(
          color: employeeEntries.any((e) => e['end_time'] == null)
              ? Colors.green
              : Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),

      const SizedBox(width: 8),

      Expanded(
        child: Text(
          employee,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: darkText,
          ),
        ),
      ),
    ],
  ),
),

                Text(
                  formatClockDuration(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (expanded)
          ...employeeEntries.map(buildTimeEntryRow),
      ],
    );
  }).toList();
}
Future<void> deleteTimeEntry(
  Map<String, dynamic> entry,
) async {
  final entryId = entry['id']?.toString() ?? '';

  if (entryId.isEmpty) {
    return;
  }

  if (entry['end_time'] == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A running entry cannot be deleted.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final projectName = _projectDisplayName(
    entry['projects']?['project_name'],
  );

  final duration = _entryDuration(entry);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete Time Entry?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectName),
            const SizedBox(height: 8),
            Text(
              'Duration: ${formatClockDuration(duration)}',
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !mounted) {
    return;
  }

  try {
    await TimeEntryService().deleteCompletedEntry(
      entryId: entryId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Time entry deleted successfully.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    await loadDashboard();
  } catch (error) {
    debugPrint(error.toString());

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to delete this time entry.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> continueTimeEntry(
  Map<String, dynamic> entry,
) async {
  if (isAdmin) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Admins cannot start or continue timers.',
        ),
        backgroundColor: Colors.red,
      ),
    );

    return;
  }

  final projectId =
      entry['project_id']?.toString().trim() ?? '';

  if (projectId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This entry does not have a valid project.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (runningEntry != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A timer is already running. Stop it before continuing another entry.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  resetSessionTimer();

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TimerScreen(
        initialProjectId: projectId,
        autoStart: true,
      ),
    ),
  );

  if (!mounted) return;

  await loadDashboard();
}

 Widget buildTimeEntryRow(
  Map<String, dynamic> entry,
) {
  final project = _projectDisplayName(
    entry['projects']?['project_name'],
  );

  final employee =
    _employeeDisplayName(entry);

  final note =
      entry['note']?.toString().trim() ?? '';

  final start =
      formatEntryTime(entry['start_time']);

  final end = _entryEndText(entry);

  final duration = _entryDuration(entry);

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 17,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(
        bottom: BorderSide(
          color: borderColor,
        ),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project,
                style: const TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                note.isEmpty
                    ? employee
                    : '$employee • $note',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: secondaryText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Expanded(
  flex: 2,
  child: Text(
    '$start - $end',
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: secondaryText,
      fontSize: 14,
    ),
  ),
),

SizedBox(
  width: 100,
  child: Text(
    formatClockDuration(duration),
    textAlign: TextAlign.right,
    style: const TextStyle(
      color: darkText,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  ),
),

if (entry['end_time'] != null) ...[
  const SizedBox(width: 8),
  PopupMenuButton<String>(
    tooltip: 'Entry options',
    icon: const Icon(
      Icons.more_vert,
      color: secondaryText,
    ),
    onSelected: (value) {
      if (value == 'continue') {
  continueTimeEntry(entry);
} if (value == 'delete') {
  deleteTimeEntry(entry);
}
    },
    itemBuilder: (context) {
      return const [
        PopupMenuItem<String>(
          value: 'continue',
          child: Row(
            children: [
              Icon(Icons.play_arrow_outlined),
              SizedBox(width: 10),
              Text('Continue'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              SizedBox(width: 10),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ];
    },
  ),
],
      ],
    ),
  );
}

  void openTimerScreen() {
    resetSessionTimer();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TimerScreen(),
      ),
    ).then(
      (_) => loadDashboard(),
    );
  }

  Widget dashboardContent() {
    return RefreshIndicator(
      color: orange,
      onRefresh: loadDashboard,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            buildHeader(),
            if (!isAdmin && runningEntry != null) ...[
              const SizedBox(height: 20),
              buildRunningTimer(),
            ],
            const SizedBox(height: 20),

            // Employee dashboard remains exactly as before.
            // Admin gets the new pie chart + individual weekly comparison.
            if (isAdmin)
              AdminWeeklyOverview(
                employees: adminEmployeeWeekSummaries,
              )
            else
              buildActivityList(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
Widget buildSelectedPage() {
  switch (selectedPage) {
    case 'timer':
      return const TimerScreen();

    case 'timesheet':
      return TimesheetScreen(
        isManager: isAdmin,
        employeeName: currentUserName,
      );

    case 'screenshots':
      return const ScreenshotGalleryScreen();

    case 'keyboard_activity':
      return const KeyboardActivityScreen();

    case 'ai_summary':
  return const AiSummaryScreen();

    case 'leave':
      return const LeaveRequestScreen();

    case 'employees':
      return const EmployeeManagementScreen();

    case 'projects':
      return const ProjectManagementScreen();

    case 'workspace':
      return const WorkspaceScreen();

    case 'reports':
      return const WeeklyReportScreen();

    case 'approvals':
      return const LeaveApprovalScreen();

    case 'billing':
      return BillingScreen(
        workspaceId: currentWorkspaceId,
      );

    case 'change_password':
      return const ChangePasswordScreen();

    case 'dashboard':
    default:
      if (loading) {
        return const Center(
          child: CircularProgressIndicator(
            color: orange,
          ),
        );
      }

      if (errorMessage != null) {
        return buildError();
      }

      return dashboardContent();
  }
}
  Widget buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 54,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 15),
          Text(
            errorMessage ??
                'Unable to load dashboard.',
            style: const TextStyle(
              color: secondaryText,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: orange,
            ),
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Large desktop: full sidebar by default.
    // Smaller laptop/browser: automatically show icon-only sidebar.
    final bool autoCollapseSidebar = screenWidth < 1200;

    final bool effectiveSidebarCollapsed =
        autoCollapseSidebar || sidebarCollapsed;

    return Listener(
      onPointerDown: (_) => resetSessionTimer(),
      onPointerMove: (_) => resetSessionTimer(),
      onPointerHover: (_) => resetSessionTimer(),
      child: Scaffold(
        backgroundColor: background,
        body: Row(
          children: [
            DashboardSidebar(
              workspaceName: currentWorkspaceName,
              currentPage: selectedPage,
              isAdmin: isAdmin,
              isCollapsed: effectiveSidebarCollapsed,

              // On smaller laptop widths the sidebar stays icon-only.
              // On large desktop the admin can manually collapse/expand it.
              onToggle: autoCollapseSidebar
                  ? null
                  : () {
                      setState(() {
                        sidebarCollapsed = !sidebarCollapsed;
                      });
                    },

              onDashboard: () async {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'dashboard';
                });

                await loadDashboard();
              },

              onTimer: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'timer';
                });
              },

              onTimesheet: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'timesheet';
                });
              },

              onScreenshots: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'screenshots';
                });
              },

              onKeyboardActivity: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'keyboard_activity';
                });
              },

              onAiSummary: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'ai_summary';
                });
              },

              onLeave: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'leave';
                });
              },

              onEmployees: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'employees';
                });
              },

              onProjects: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'projects';
                });
              },

              onWorkspace: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'workspace';
                });
              },

              onReports: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'reports';
                });
              },

              onApprovals: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'approvals';
                });
              },

              onBilling: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'billing';
                });
              },

              onChangePassword: () {
                resetSessionTimer();

                setState(() {
                  selectedPage = 'change_password';
                });
              },

              onLogout: logout,
            ),

            Expanded(
              child: buildSelectedPage(),
            ),
          ],
        ),
      ),
    );
  }
}

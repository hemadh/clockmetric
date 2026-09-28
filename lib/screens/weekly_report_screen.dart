import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_colors.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() =>
      _WeeklyReportScreenState();
}

class _WeeklyReportScreenState
    extends State<WeeklyReportScreen> {
  Map<String, int> employeeTotals = {};
  Map<String, int> lifetimeEmployeeTotals = {};
  Map<String, int> projectTotals = {};
  Map<String, Map<String, int>> projectEmployeeTotals = {};
  Map<String, Map<String, int>> employeeDailyTotals = {};

  String projectSearchQuery = '';

  List<Map<String, dynamic>> complianceRows = [];

  bool loading = true;
  String? errorMessage;

  final List<String> days = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    loadReports();
  }
  int _entryDurationSeconds(Map<String, dynamic> item) {
  final start = DateTime.tryParse(
    item['start_time']?.toString() ?? '',
  );

  final end = item['end_time'] == null
      ? DateTime.now()
      : DateTime.tryParse(
          item['end_time'].toString(),
        );

  if (start != null &&
      end != null &&
      !end.isBefore(start)) {
    return end.difference(start).inSeconds;
  }

  final storedMinutes = int.tryParse(
        item['duration_minutes']?.toString() ?? '',
      ) ??
      0;

  return storedMinutes * 60;
}

  Future<void> loadReports() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      // ---------------------------------------------------------
      // EMPLOYEE PROFILES
      // Used to resolve a real employee name from employee_id.
      // This prevents valid time entries from showing as
      // "Unknown Employee" when employee_name is missing.
      // ---------------------------------------------------------
      final profiles = await supabase
          .from('profiles')
          .select(
            'id, full_name, required_weekly_hours',
          )
          .eq(
            'workspace_id',
            currentWorkspaceId,
          )
          .eq('role', 'employee');

      final Map<String, String> profileNamesById = {};

      for (final profile in profiles) {
        final profileId =
            profile['id']?.toString().trim() ?? '';

        final fullName =
            profile['full_name']?.toString().trim() ?? '';

        if (profileId.isNotEmpty && fullName.isNotEmpty) {
          profileNamesById[profileId] = fullName;
        }
      }

      // ---------------------------------------------------------
      // PROJECT MEMBERS
      // Used as a safe fallback for old time entries where both
      // employee_id and employee_name were not saved.
      // If a project has exactly one assigned employee, we can
      // safely attribute that unidentified project time to them.
      // ---------------------------------------------------------
      final projectRows = await supabase
          .from('projects')
          .select('id, project_name')
          .eq(
            'workspace_id',
            currentWorkspaceId,
          );

      final projectMemberRows = await supabase
          .from('project_members')
          .select('project_id, employee_id')
          .eq(
            'workspace_id',
            currentWorkspaceId,
          );

      final Map<String, String> projectNamesById = {};
      final Map<String, Set<String>>
          assignedEmployeeNamesByProjectId = {};

      for (final project in projectRows) {
        final projectId =
            project['id']?.toString().trim() ?? '';

        final projectName =
            project['project_name']?.toString().trim() ?? '';

        if (projectId.isNotEmpty && projectName.isNotEmpty) {
          projectNamesById[projectId] = projectName;
        }
      }

      for (final member in projectMemberRows) {
        final projectId =
            member['project_id']?.toString().trim() ?? '';

        final employeeId =
            member['employee_id']?.toString().trim() ?? '';

        final employeeName =
            profileNamesById[employeeId];

        if (projectId.isEmpty ||
            employeeName == null ||
            employeeName.trim().isEmpty) {
          continue;
        }

        assignedEmployeeNamesByProjectId.putIfAbsent(
          projectId,
          () => <String>{},
        );

        assignedEmployeeNamesByProjectId[projectId]!.add(
          employeeName.trim(),
        );
      }

      String resolveEmployeeName(
        Map<String, dynamic> item,
      ) {
        final employeeId =
            item['employee_id']?.toString().trim() ?? '';

        if (employeeId.isNotEmpty) {
          final profileName =
              profileNamesById[employeeId];

          if (profileName != null &&
              profileName.trim().isNotEmpty) {
            return profileName.trim();
          }
        }

        final savedName =
            item['employee_name']?.toString().trim() ?? '';

        if (savedName.isNotEmpty &&
            savedName.toLowerCase() !=
                'unknown employee') {
          return savedName;
        }

        return 'Unknown Employee';
      }

      // ---------------------------------------------------------
      // CURRENT WEEK PROJECT + EMPLOYEE TIME
      // Load directly from time_entries so every row contains
      // project_id, employee_id and employee_name together.
      // ---------------------------------------------------------
      final current = DateTime.now();

      final currentWeekStart = DateTime(
        current.year,
        current.month,
        current.day,
      ).subtract(
        Duration(
          days: current.weekday - DateTime.monday,
        ),
      );

      final nextWeekStart = currentWeekStart.add(
        const Duration(days: 7),
      );

      final projectEmployeeEntriesResponse =
          await supabase
              .from('time_entries')
              .select(
                'employee_id, employee_name, project_id, '
                'start_time, end_time, duration_minutes, '
                'projects(project_name)',
              )
              .eq(
                'workspace_id',
                currentWorkspaceId,
              )
              .gte(
                'start_time',
                currentWeekStart
                    .toUtc()
                    .toIso8601String(),
              )
              .lt(
                'start_time',
                nextWeekStart
                    .toUtc()
                    .toIso8601String(),
              )
              .order(
                'start_time',
                ascending: true,
              );

      final projectEmployeeEntries =
          List<Map<String, dynamic>>.from(
        projectEmployeeEntriesResponse,
      );

      // Load every time entry for the workspace so we can show
      // each employee's all-time / lifetime tracked hours.
      final lifetimeEntries = await supabase
          .from('time_entries')
          .select(
            'employee_id, employee_name, start_time, '
            'end_time, duration_minutes',
          )
          .eq(
            'workspace_id',
            currentWorkspaceId,
          )
          .order(
            'start_time',
            ascending: true,
          );

      final Map<String, int> newEmployeeTotals = {};
      final Map<String, int> newLifetimeEmployeeTotals = {};
      final Map<String, int> newProjectTotals = {};
      final Map<String, Map<String, int>>
          newProjectEmployeeTotals = {};

      final Map<String, Map<String, int>>
          newDailyTotals = {};

      for (final rawItem in lifetimeEntries) {
        final item = Map<String, dynamic>.from(rawItem);

        final employeeName =
            resolveEmployeeName(item);

        final seconds = _entryDurationSeconds(item);

        newLifetimeEmployeeTotals[employeeName] =
            (newLifetimeEmployeeTotals[employeeName] ?? 0) +
                seconds;
      }

      // ---------------------------------------------------------
      // CURRENT WEEK AGGREGATION
      //
      // IMPORTANT:
      // employee_id is the identity. profiles.full_name is only the
      // display name. This prevents a renamed employee from appearing
      // twice (for example "sonee" and "Sonee Acharya").
      // ---------------------------------------------------------
      for (final item in projectEmployeeEntries) {
        final projectId =
            item['project_id']?.toString().trim() ?? '';

        final joinedProjectName =
            item['projects']?['project_name']
                    ?.toString()
                    .trim() ??
                '';

        final projectNameFromId =
            projectNamesById[projectId] ?? '';

        final displayProject =
            joinedProjectName.isNotEmpty
                ? joinedProjectName
                : projectNameFromId.isNotEmpty
                    ? projectNameFromId
                    : 'Unknown Project';

        var employeeName =
            resolveEmployeeName(item);

        // Very old entries may not contain employee_id or employee_name.
        // If exactly one employee is assigned to that project, safely use
        // that employee as the only possible worker.
        if (employeeName == 'Unknown Employee' &&
            projectId.isNotEmpty) {
          final assignedNames =
              assignedEmployeeNamesByProjectId[projectId] ??
                  <String>{};

          if (assignedNames.length == 1) {
            employeeName = assignedNames.first;
          }
        }

        final seconds = _entryDurationSeconds(item);

        // Weekly total by employee.
        newEmployeeTotals[employeeName] =
            (newEmployeeTotals[employeeName] ?? 0) +
                seconds;

        // Daily total by employee.
        final startTime = DateTime.tryParse(
          item['start_time']?.toString() ?? '',
        )?.toLocal();

        if (startTime != null) {
          final dayName =
              days[startTime.weekday - 1];

          newDailyTotals.putIfAbsent(
            employeeName,
            () => {
              'Mon': 0,
              'Tue': 0,
              'Wed': 0,
              'Thu': 0,
              'Fri': 0,
              'Sat': 0,
              'Sun': 0,
            },
          );

          newDailyTotals[employeeName]![dayName] =
              (newDailyTotals[employeeName]![dayName] ?? 0) +
                  seconds;
        }

        // Weekly total by project.
        newProjectTotals[displayProject] =
            (newProjectTotals[displayProject] ?? 0) +
                seconds;

        // Weekly employee totals inside each project.
        newProjectEmployeeTotals.putIfAbsent(
          displayProject,
          () => <String, int>{},
        );

        newProjectEmployeeTotals[displayProject]![employeeName] =
            (newProjectEmployeeTotals[displayProject]![
                        employeeName] ??
                    0) +
                seconds;
      }

      final List<Map<String, dynamic>> compliance = [];

      for (final profile in profiles) {
        final name =
            profile['full_name']?.toString().trim() ??
                '';

        final displayName =
            name.isEmpty ? 'Unnamed Employee' : name;

        newLifetimeEmployeeTotals.putIfAbsent(
          displayName,
          () => 0,
        );

        final requiredHours = int.tryParse(
              profile['required_weekly_hours']
                      ?.toString() ??
                  '',
            ) ??
            0;

        final workedMinutes =
            newEmployeeTotals[displayName] ?? 0;

        final requiredMinutes =
    requiredHours * 60 * 60;

        final missingMinutes =
            workedMinutes < requiredMinutes
                ? requiredMinutes - workedMinutes
                : 0;

        compliance.add({
          'employee': displayName,
          'required': requiredMinutes,
          'worked': workedMinutes,
          'missing': missingMinutes,
          'status': missingMinutes > 0
              ? 'Below Target'
              : 'On Target',
        });
      }

      compliance.sort((a, b) {
        final firstMissing =
            int.tryParse(
              a['missing']?.toString() ?? '',
            ) ??
            0;

        final secondMissing =
            int.tryParse(
              b['missing']?.toString() ?? '',
            ) ??
            0;

        return secondMissing.compareTo(firstMissing);
      });

      if (!mounted) return;

      setState(() {
        employeeTotals = newEmployeeTotals;
        lifetimeEmployeeTotals = newLifetimeEmployeeTotals;
        projectTotals = newProjectTotals;
        projectEmployeeTotals =
            newProjectEmployeeTotals;
        employeeDailyTotals = newDailyTotals;
        complianceRows = compliance;
        loading = false;
      });
    } catch (error) {
      debugPrint(
        'Weekly report loading error: $error',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Unable to load weekly reports. Please try again.';
      });
    }
  }

  String _projectDisplayName(dynamic value) {
    var name = value?.toString().trim() ?? '';

    if (name.isEmpty ||
        name.toLowerCase() == 'unknown project' ||
        name.toLowerCase() == 'no project') {
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

  String formatHours(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}';
}

  int get totalMinutes {
    int total = 0;

    for (final value in employeeTotals.values) {
      total += value;
    }

    return total;
  }

  int get onTargetEmployees {
    return complianceRows.where((row) {
      return row['status'] == 'On Target';
    }).length;
  }

  int get belowTargetEmployees {
    return complianceRows.where((row) {
      return row['status'] == 'Below Target';
    }).length;
  }

  Widget summaryCard({
    required IconData icon,
    required String title,
    required String value,
    Color accentColor = AppColors.primary,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget weeklyComplianceReport() {
    return _reportContainer(
      title: 'Employee Weekly Hours',
      subtitle:
          'Compare each employee’s worked hours with their weekly requirement.',
      icon: Icons.fact_check_outlined,
      child: complianceRows.isEmpty
          ? _emptySection(
              'No compliance data available.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    const WidgetStatePropertyAll(
                  AppColors.primarySurface,
                ),
                headingTextStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                dataTextStyle: const TextStyle(
                  color: AppColors.textPrimary,
                ),
                dividerThickness: 0.6,
                headingRowHeight: 38,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 42,
                horizontalMargin: 12,
                columnSpacing: 28,
                columns: const [
                  DataColumn(
                    label: Text('Employee'),
                  ),
                  DataColumn(
                    label: Text('Required'),
                  ),
                  DataColumn(
                    label: Text('Worked'),
                  ),
                  DataColumn(
                    label: Text('Missing'),
                  ),
                  DataColumn(
                    label: Text('Status'),
                  ),
                ],
                rows: complianceRows.map((row) {
                  final below =
                      row['status'] == 'Below Target';

                  final required = int.tryParse(
                        row['required']?.toString() ??
                            '',
                      ) ??
                      0;

                  final worked = int.tryParse(
                        row['worked']?.toString() ??
                            '',
                      ) ??
                      0;

                  final missing = int.tryParse(
                        row['missing']?.toString() ??
                            '',
                      ) ??
                      0;

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  AppColors.primaryLight,
                              child: Text(
                                _initials(
                                  row['employee']
                                          ?.toString() ??
                                      'E',
                                ),
                                style: const TextStyle(
                                  color:
                                      AppColors.primaryDark,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              row['employee']?.toString() ??
                                  '',
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(formatHours(required)),
                      ),
                      DataCell(
                        Text(formatHours(worked)),
                      ),
                      DataCell(
                        Text(
                          formatHours(missing),
                          style: TextStyle(
                            color: below
                                ? AppColors.danger
                                : AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        _statusBadge(
                          below: below,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget dailyEmployeeReport() {
    return _reportContainer(
      title: 'Daily Hours by Employee',
      subtitle:
          'Review each employee’s tracked time across the week.',
      icon: Icons.calendar_view_week_outlined,
      child: employeeDailyTotals.isEmpty
          ? _emptySection(
              'No daily employee data available.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    const WidgetStatePropertyAll(
                  AppColors.primarySurface,
                ),
                headingTextStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                dataTextStyle: const TextStyle(
                  color: AppColors.textPrimary,
                ),
                dividerThickness: 0.6,
                headingRowHeight: 38,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 42,
                horizontalMargin: 12,
                columnSpacing: 28,
                columns: const [
                  DataColumn(
                    label: Text('Employee'),
                  ),
                  DataColumn(label: Text('Mon')),
                  DataColumn(label: Text('Tue')),
                  DataColumn(label: Text('Wed')),
                  DataColumn(label: Text('Thu')),
                  DataColumn(label: Text('Fri')),
                  DataColumn(label: Text('Sat')),
                  DataColumn(label: Text('Sun')),
                  DataColumn(label: Text('Total')),
                ],
                rows:
                    employeeDailyTotals.entries.map(
                  (entry) {
                    final employee = entry.key;
                    final daily = entry.value;
                    final total =
                        employeeTotals[employee] ?? 0;

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            employee,
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                        ...days.map(
                          (day) => DataCell(
                            Text(
                              formatHours(
                                daily[day] ?? 0,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            formatHours(total),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ).toList(),
              ),
            ),
    );
  }

  Future<void> _showProjectWeekPopup(
    String projectName,
  ) async {
    final employees =
        (projectEmployeeTotals[projectName] ??
                <String, int>{})
            .entries
            .toList()
          ..sort(
            (a, b) => b.value.compareTo(a.value),
          );

    final projectTotal =
        projectTotals[projectName] ?? 0;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 620,
              maxHeight: 600,
            ),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.border,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius:
                            BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.folder_open_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _projectDisplayName(projectName),
                            style: const TextStyle(
                              color:
                                  AppColors.textPrimary,
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Employees who worked on this project this week',
                            style: TextStyle(
                              color: AppColors
                                  .textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'EMPLOYEE',
                          style: TextStyle(
                            color: AppColors
                                .textSecondary,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Text(
                          'WEEK TIME',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors
                                .textSecondary,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                Flexible(
                  child: employees.isEmpty
                      ? const Padding(
                          padding:
                              EdgeInsets.symmetric(
                            vertical: 36,
                          ),
                          child: Center(
                            child: Text(
                              'No employee time recorded this week.',
                              style: TextStyle(
                                color: AppColors
                                    .textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount:
                              employees.length,
                          separatorBuilder:
                              (_, _) =>
                                  const Divider(
                            height: 1,
                            color: AppColors.border,
                          ),
                          itemBuilder:
                              (context, index) {
                            final employee =
                                employees[index];

                            final isUnknown =
                                employee.key ==
                                    'Unknown Employee';

                            return Padding(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 6,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        AppColors
                                            .primaryLight,
                                    child: Text(
                                      _initials(
                                        employee.key,
                                      ),
                                      style:
                                          const TextStyle(
                                        color: AppColors
                                            .primaryDark,
                                        fontSize: 9,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          employee.key,
                                          style:
                                              const TextStyle(
                                            color: AppColors
                                                .textPrimary,
                                            fontWeight:
                                                FontWeight
                                                    .w600,
                                          ),
                                        ),
                                        if (isUnknown)
                                          const Padding(
                                            padding:
                                                EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              'Employee details were not saved on this older time entry.',
                                              style:
                                                  TextStyle(
                                                color: AppColors
                                                    .textSecondary,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      formatHours(
                                        employee.value,
                                      ),
                                      textAlign:
                                          TextAlign.right,
                                      style:
                                          const TextStyle(
                                        color: AppColors
                                            .primary,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 12),
                const Divider(
                  color: AppColors.border,
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Project total this week',
                      style: TextStyle(
                        color:
                            AppColors.textSecondary,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      formatHours(projectTotal),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget projectEmployeeReport() {
    final query =
        projectSearchQuery.trim().toLowerCase();

    final sortedProjects =
        projectTotals.entries.where((entry) {
      if (query.isEmpty) {
        return true;
      }

      final projectMatches =
          entry.key.toLowerCase().contains(query);

      final employees =
          projectEmployeeTotals[entry.key] ??
              <String, int>{};

      final employeeMatches =
          employees.keys.any(
        (name) =>
            name.toLowerCase().contains(query),
      );

      return projectMatches || employeeMatches;
    }).toList()
      ..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    return _reportContainer(
      title: 'Weekly Hours by Project',
      subtitle:
          'Click a project to see who worked on it and how much time they invested this week.',
      icon: Icons.folder_copy_outlined,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                projectSearchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Search project or employee...',
              prefixIcon: const Icon(
                Icons.search_rounded,
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (sortedProjects.isEmpty)
            _emptySection(
              projectTotals.isEmpty
                  ? 'No project time data available.'
                  : 'No matching project or employee found.',
            )
          else
            ...sortedProjects.map(
              (projectEntry) {
                final employees =
                    projectEmployeeTotals[
                            projectEntry.key] ??
                        <String, int>{};

                final employeeCount =
                    employees.length;

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: Material(
                    color:
                        AppColors.background,
                    borderRadius:
                        BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                      onTap: () {
                        _showProjectWeekPopup(
                          projectEntry.key,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          border: Border.all(
                            color:
                                AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration:
                                  BoxDecoration(
                                color: AppColors
                                    .primaryLight,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  9,
                                ),
                              ),
                              child: const Icon(
                                Icons
                                    .folder_outlined,
                                color: AppColors
                                    .primary,
                                size: 19,
                              ),
                            ),
                            const SizedBox(
                              width: 11,
                            ),
                            Expanded(
                              child: Text(
                                _projectDisplayName(
                                  projectEntry.key,
                                ),
                                style:
                                    const TextStyle(
                                  color: AppColors
                                      .textPrimary,
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ),
                            Text(
                              '$employeeCount '
                              '${employeeCount == 1 ? 'employee' : 'employees'}',
                              style:
                                  const TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                            const SizedBox(
                              width: 24,
                            ),
                            Text(
                              formatHours(
                                projectEntry.value,
                              ),
                              style:
                                  const TextStyle(
                                color: AppColors
                                    .primary,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            const Icon(
                              Icons
                                  .chevron_right_rounded,
                              color: AppColors
                                  .textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget reportSection({
    required String title,
    required String subtitle,
    required String firstColumn,
    required Map<String, int> data,
    required IconData icon,
  }) {
    final sortedEntries = data.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    return _reportContainer(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: sortedEntries.isEmpty
          ? _emptySection(
              'No report data available.',
            )
          : SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor:
                    const WidgetStatePropertyAll(
                  AppColors.primarySurface,
                ),
                headingTextStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                dataTextStyle: const TextStyle(
                  color: AppColors.textPrimary,
                ),
                dividerThickness: 0.6,
                headingRowHeight: 38,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 42,
                horizontalMargin: 12,
                columnSpacing: 28,
                columns: [
                  DataColumn(
                    label: Text(firstColumn),
                  ),
                  const DataColumn(
                    label: Text('Total Time'),
                  ),
                ],
                rows: sortedEntries.map((entry) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          formatHours(entry.value),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _reportContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius:
                      BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color:
                            AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _statusBadge({
    required bool below,
  }) {
    final color = below
        ? AppColors.danger
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            below
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            below ? 'Below Target' : 'On Target',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 22,
        horizontal: 16,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'E';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'
        .toUpperCase();
  }

  Widget _buildErrorState() {
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
                  'Unable to load weekly reports.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    AppColors.primary,
              ),
              onPressed: loadReports,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        toolbarHeight: 54,
        title: const Text(
          'Weekly Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed:
                loading ? null : loadReports,
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
              ? _buildErrorState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: loadReports,
                  child: SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(
                          maxWidth: 1320,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Weekly Summary',
                              style: TextStyle(
                                color:
                                    AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Review employee hours, project totals and weekly compliance.',
                              style: TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder:
                                  (context, constraints) {
                                final cardWidth =
                                    constraints.maxWidth >=
                                            900
                                        ? (constraints
                                                    .maxWidth -
                                                45) /
                                            4
                                        : constraints
                                                    .maxWidth >=
                                                600
                                            ? (constraints
                                                        .maxWidth -
                                                    15) /
                                                2
                                            : constraints
                                                .maxWidth;

                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    SizedBox(
                                      width: cardWidth,
                                      child: summaryCard(
                                        icon: Icons
                                            .access_time,
                                        title:
                                            'Total Weekly Hours',
                                        value: formatHours(
                                          totalMinutes,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: summaryCard(
                                        icon: Icons
                                            .people_outline,
                                        title:
                                            'Employees',
                                        value:
                                            complianceRows
    .length
    .toString(),
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: summaryCard(
                                        icon: Icons
                                            .folder_outlined,
                                        title: 'Projects Tracked',
                                        value:
                                            projectTotals
                                                .length
                                                .toString(),
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: summaryCard(
                                        icon: Icons
                                            .check_circle_outline,
                                        title:
                                            'On Target',
                                        value:
                                            '$onTargetEmployees / '
                                            '${complianceRows.length}',
                                        accentColor:
                                            belowTargetEmployees >
                                                    0
                                                ? AppColors
                                                    .warning
                                                : AppColors
                                                    .success,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            weeklyComplianceReport(),
                            const SizedBox(height: 16),
                            dailyEmployeeReport(),
                            const SizedBox(height: 16),
                            reportSection(
                              title:
                                  'Employee Lifetime Hours',
                              subtitle:
                                  'Total tracked time from each employee’s first recorded session until now.',
                              firstColumn: 'Employee',
                              data: lifetimeEmployeeTotals,
                              icon:
                                  Icons.history_rounded,
                            ),
                            const SizedBox(height: 16),
                            projectEmployeeReport(),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
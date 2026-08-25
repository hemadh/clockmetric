import 'package:flutter/material.dart';

import '../main.dart';
import '../services/report_service.dart';
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
  Map<String, int> projectTotals = {};
  Map<String, Map<String, int>> employeeDailyTotals = {};

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
      final employeeData =
          await ReportService().getWeeklyByEmployee();

      final projectData =
          await ReportService().getWeeklyByProject();

      final weeklyEntries =
          await ReportService().getWeeklyEntries();

      final Map<String, int> newEmployeeTotals = {};
      final Map<String, int> newProjectTotals = {};

      final Map<String, Map<String, int>>
          newDailyTotals = {};

      for (final item in employeeData) {
  final employee =
      item['employee_name']?.toString().trim();

  final employeeName =
      employee == null || employee.isEmpty
          ? 'Unknown Employee'
          : employee;

  final seconds = _entryDurationSeconds(item);

  newEmployeeTotals[employeeName] =
      (newEmployeeTotals[employeeName] ?? 0) +
          seconds;
}

      for (final item in projectData) {
  final projectName =
      item['projects']?['project_name']
              ?.toString()
              .trim() ??
          '';

  final displayProject =
      projectName.isEmpty
          ? 'Unknown Project'
          : projectName;

  final seconds = _entryDurationSeconds(item);

  newProjectTotals[displayProject] =
      (newProjectTotals[displayProject] ?? 0) +
          seconds;
}
      for (final item in weeklyEntries) {
        final employee =
            item['employee_name']?.toString().trim();

        final employeeName =
            employee == null || employee.isEmpty
                ? 'Unknown Employee'
                : employee;

        final seconds = _entryDurationSeconds(item);

        final startTime = DateTime.tryParse(
          item['start_time']?.toString() ?? '',
        )?.toLocal();

        if (startTime == null) {
          continue;
        }

        final dayName = days[startTime.weekday - 1];

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

      final profiles = await supabase
          .from('profiles')
          .select(
            'full_name, required_weekly_hours',
          )
          .eq(
            'workspace_id',
            currentWorkspaceId,
          )
          .eq('role', 'employee');

      final List<Map<String, dynamic>> compliance = [];

      for (final profile in profiles) {
        final name =
            profile['full_name']?.toString().trim() ??
                '';

        final displayName =
            name.isEmpty ? 'Unnamed Employee' : name;

        final requiredHours = int.tryParse(
              profile['required_weekly_hours']
                      ?.toString() ??
                  '',
            ) ??
            45;

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
        projectTotals = newProjectTotals;
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
              color: accentColor.withOpacity(0.12),
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
      title: 'Weekly Hours Compliance',
      subtitle:
          'Compare worked hours against each employee’s weekly requirement.',
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
        color: color.withOpacity(0.11),
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
                                  'Weekly Hours by Employee',
                              subtitle:
                                  'Total tracked time for each employee.',
                              firstColumn: 'Employee',
                              data: employeeTotals,
                              icon:
                                  Icons.people_alt_outlined,
                            ),
                            const SizedBox(height: 16),
                            reportSection(
                              title:
                                  'Weekly Hours by Project',
                              subtitle:
                                  'Total tracked time grouped by project.',
                              firstColumn: 'Project',
                              data: projectTotals,
                              icon:
                                  Icons.folder_copy_outlined,
                            ),
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
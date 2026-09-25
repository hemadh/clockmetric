import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_colors.dart';

class ProjectManagementScreen extends StatefulWidget {
  const ProjectManagementScreen({super.key});

  @override
  State<ProjectManagementScreen> createState() =>
      _ProjectManagementScreenState();
}

class _ProjectManagementScreenState
    extends State<ProjectManagementScreen> {
  final TextEditingController projectController =
      TextEditingController();

  final TextEditingController searchController =
      TextEditingController();

  final Set<String> expandedProjectIds = <String>{};

  String searchQuery = '';

  bool loading = true;
  bool addingProject = false;
  bool savingMembers = false;

  String? errorMessage;

  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> projectMembers = [];
  List<Map<String, dynamic>> weekTimeEntries = [];
  List<Map<String, dynamic>> previousWeekTimeEntries = [];

  @override
  void initState() {
    super.initState();
    loadEverything();
  }

  Future<void> loadEverything() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await Future.wait([
        loadProjects(),
        loadEmployees(),
        loadProjectMembers(),
        loadWeekTimeEntries(),
        loadPreviousWeekTimeEntries(),
      ]);

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    } catch (error) {
      debugPrint('Project screen loading error: $error');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Unable to load project information. Please try again.';
      });
    }
  }

  Future<void> loadProjects() async {
    final response = await supabase
        .from('projects')
        .select(
          'id, project_name, created_at, workspace_id',
        )
        .eq(
          'workspace_id',
          currentWorkspaceId,
        )
        .order(
          'created_at',
          ascending: false,
        );

    projects = List<Map<String, dynamic>>.from(response);
  }

  Future<void> loadEmployees() async {
    final response = await supabase
        .from('profiles')
        .select(
          'id, full_name, email, role, approval_status',
        )
        .eq(
          'workspace_id',
          currentWorkspaceId,
        )
        .eq(
          'approval_status',
          'approved',
        )
        .order(
          'full_name',
          ascending: true,
        );

    employees = List<Map<String, dynamic>>.from(response);
  }

  Future<void> loadProjectMembers() async {
    final response = await supabase
        .from('project_members')
        .select(
          'id, project_id, employee_id, workspace_id',
        )
        .eq(
          'workspace_id',
          currentWorkspaceId,
        );

    projectMembers =
        List<Map<String, dynamic>>.from(response);
  }

  DateTime get currentWeekStart {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    return today.subtract(
      Duration(
        days: today.weekday - DateTime.monday,
      ),
    );
  }

  DateTime get nextWeekStart {
    return currentWeekStart.add(
      const Duration(days: 7),
    );
  }

  DateTime get previousWeekStart {
    return currentWeekStart.subtract(
      const Duration(days: 7),
    );
  }

  Future<void> loadWeekTimeEntries() async {
    final response = await supabase
        .from('time_entries')
        .select(
          'id, project_id, employee_id, employee_name, '
          'start_time, end_time, duration_minutes',
        )
        .eq(
          'workspace_id',
          currentWorkspaceId,
        )
        .gte(
          'start_time',
          currentWeekStart.toUtc().toIso8601String(),
        )
        .lt(
          'start_time',
          nextWeekStart.toUtc().toIso8601String(),
        )
        .order(
          'start_time',
          ascending: true,
        );

    weekTimeEntries =
        List<Map<String, dynamic>>.from(response);
  }

  Future<void> loadPreviousWeekTimeEntries() async {
    final response = await supabase
        .from('time_entries')
        .select(
          'id, project_id, employee_id, employee_name, '
          'start_time, end_time, duration_minutes',
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
          currentWeekStart.toUtc().toIso8601String(),
        )
        .order(
          'start_time',
          ascending: true,
        );

    previousWeekTimeEntries =
        List<Map<String, dynamic>>.from(response);
  }

  int timeEntrySeconds(
    Map<String, dynamic> entry,
  ) {
    final startTime = DateTime.tryParse(
      entry['start_time']?.toString() ?? '',
    )?.toLocal();

    if (startTime == null) {
      final storedMinutes = int.tryParse(
            entry['duration_minutes']?.toString() ?? '',
          ) ??
          0;

      return storedMinutes < 0
          ? 0
          : storedMinutes * 60;
    }

    final endTime = DateTime.tryParse(
      entry['end_time']?.toString() ?? '',
    )?.toLocal();

    final effectiveEndTime =
        endTime ?? DateTime.now();

    if (!effectiveEndTime.isBefore(startTime)) {
      final seconds =
          effectiveEndTime.difference(startTime).inSeconds;

      if (seconds >= 0 &&
          seconds <= const Duration(hours: 24).inSeconds) {
        return seconds;
      }
    }

    final storedMinutes = int.tryParse(
          entry['duration_minutes']?.toString() ?? '',
        ) ??
        0;

    return storedMinutes < 0
        ? 0
        : storedMinutes * 60;
  }

  bool entryMatchesEmployee(
    Map<String, dynamic> entry,
    Map<String, dynamic> employee,
  ) {
    final employeeId =
        employee['id']?.toString().trim() ?? '';

    final entryEmployeeId =
        entry['employee_id']?.toString().trim() ?? '';

    if (employeeId.isNotEmpty &&
        entryEmployeeId.isNotEmpty) {
      return employeeId == entryEmployeeId;
    }

    final employeeName =
        employee['full_name']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    final entryEmployeeName =
        entry['employee_name']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    return employeeName.isNotEmpty &&
        employeeName == entryEmployeeName;
  }

  int projectEmployeeSeconds(
    String projectId,
    Map<String, dynamic> employee,
  ) {
    int total = 0;

    for (final entry in weekTimeEntries) {
      final entryProjectId =
          entry['project_id']?.toString() ?? '';

      if (entryProjectId != projectId) {
        continue;
      }

      if (entryMatchesEmployee(entry, employee)) {
        total += timeEntrySeconds(entry);
      }
    }

    return total;
  }

  int employeeWeekSeconds(
    Map<String, dynamic> employee,
  ) {
    int total = 0;

    for (final entry in weekTimeEntries) {
      if (entryMatchesEmployee(entry, employee)) {
        total += timeEntrySeconds(entry);
      }
    }

    return total;
  }

  int projectTotalSeconds(
    String projectId,
  ) {
    int total = 0;

    for (final entry in weekTimeEntries) {
      final entryProjectId =
          entry['project_id']?.toString() ?? '';

      if (entryProjectId == projectId) {
        total += timeEntrySeconds(entry);
      }
    }

    return total;
  }

  int previousProjectEmployeeSeconds(
    String projectId,
    Map<String, dynamic> employee,
  ) {
    int total = 0;

    for (final entry in previousWeekTimeEntries) {
      final entryProjectId =
          entry['project_id']?.toString() ?? '';

      if (entryProjectId != projectId) {
        continue;
      }

      if (entryMatchesEmployee(entry, employee)) {
        total += timeEntrySeconds(entry);
      }
    }

    return total;
  }

  int employeePreviousWeekSeconds(
    Map<String, dynamic> employee,
  ) {
    int total = 0;

    for (final entry in previousWeekTimeEntries) {
      if (entryMatchesEmployee(entry, employee)) {
        total += timeEntrySeconds(entry);
      }
    }

    return total;
  }

  int previousProjectTotalSeconds(
    String projectId,
  ) {
    int total = 0;

    for (final entry in previousWeekTimeEntries) {
      final entryProjectId =
          entry['project_id']?.toString() ?? '';

      if (entryProjectId == projectId) {
        total += timeEntrySeconds(entry);
      }
    }

    return total;
  }

  List<Map<String, dynamic>> getTimeEmployeesForProject(
    String projectId,
  ) {
    final result = <Map<String, dynamic>>[
      ...getMembersForProject(projectId),
    ];

    final seenIds = result
        .map((employee) => employee['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final seenNames = result
        .map(
          (employee) =>
              employee['full_name']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '',
        )
        .where((name) => name.isNotEmpty)
        .toSet();

    for (final entry in <Map<String, dynamic>>[
      ...weekTimeEntries,
      ...previousWeekTimeEntries,
    ]) {
      if (entry['project_id']?.toString() != projectId) {
        continue;
      }

      final entryEmployeeId =
          entry['employee_id']?.toString().trim() ?? '';

      final entryEmployeeName =
          entry['employee_name']?.toString().trim() ?? '';

      Map<String, dynamic>? matchedEmployee;

      for (final employee in employees) {
        final employeeId =
            employee['id']?.toString().trim() ?? '';

        final fullName =
            employee['full_name']?.toString().trim() ?? '';

        if (entryEmployeeId.isNotEmpty &&
            employeeId == entryEmployeeId) {
          matchedEmployee = employee;
          break;
        }

        if (entryEmployeeName.isNotEmpty &&
            fullName.toLowerCase() ==
                entryEmployeeName.toLowerCase()) {
          matchedEmployee = employee;
          break;
        }
      }

      if (matchedEmployee != null) {
        final matchedId =
            matchedEmployee['id']?.toString() ?? '';

        final matchedName =
            matchedEmployee['full_name']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        if ((matchedId.isNotEmpty &&
                seenIds.contains(matchedId)) ||
            (matchedName.isNotEmpty &&
                seenNames.contains(matchedName))) {
          continue;
        }

        result.add(matchedEmployee);

        if (matchedId.isNotEmpty) {
          seenIds.add(matchedId);
        }

        if (matchedName.isNotEmpty) {
          seenNames.add(matchedName);
        }

        continue;
      }

      final normalizedName =
          entryEmployeeName.toLowerCase();

      if (entryEmployeeName.isNotEmpty &&
          !seenNames.contains(normalizedName)) {
        result.add({
          'id': entryEmployeeId,
          'full_name': entryEmployeeName,
          'email': '',
        });

        seenNames.add(normalizedName);

        if (entryEmployeeId.isNotEmpty) {
          seenIds.add(entryEmployeeId);
        }
      }
    }

    return result;
  }

  String formatTrackedTime(int totalSeconds) {
    final safeSeconds =
        totalSeconds < 0 ? 0 : totalSeconds;

    final hours = safeSeconds ~/ 3600;
    final minutes =
        (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String currentWeekRangeText() {
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

    final start = currentWeekStart;
    final end = nextWeekStart.subtract(
      const Duration(days: 1),
    );

    return '${start.day} ${months[start.month - 1]}'
        ' – ${end.day} ${months[end.month - 1]} ${end.year}';
  }

  String previousWeekRangeText() {
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

    final start = previousWeekStart;
    final end = currentWeekStart.subtract(
      const Duration(days: 1),
    );

    return '${start.day} ${months[start.month - 1]}'
        ' – ${end.day} ${months[end.month - 1]} ${end.year}';
  }

  void toggleProjectDetails(String projectId) {
    if (projectId.isEmpty) return;

    setState(() {
      if (expandedProjectIds.contains(projectId)) {
        expandedProjectIds.remove(projectId);
      } else {
        expandedProjectIds.add(projectId);
      }
    });
  }

  List<Map<String, dynamic>> get filteredProjects {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return projects;
    }

    return projects.where((project) {
      final projectId =
          project['id']?.toString() ?? '';

      final projectName =
          project['project_name']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      if (projectName.contains(query)) {
        return true;
      }

      final projectEmployees =
          getTimeEmployeesForProject(projectId);

      return projectEmployees.any((employee) {
        final fullName =
            employee['full_name']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final email =
            employee['email']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        return fullName.contains(query) ||
            email.contains(query);
      });
    }).toList();
  }

  Future<bool> addProject() async {
    final projectName = projectController.text.trim();

    if (projectName.isEmpty) {
      showMessage(
        'Please enter a project name.',
        isError: true,
      );

      return false;
    }

    final duplicateExists = projects.any((project) {
      final existingName =
          project['project_name']?.toString().trim().toLowerCase() ??
              '';

      return existingName == projectName.toLowerCase();
    });

    if (duplicateExists) {
      showMessage(
        'A project with this name already exists.',
        isError: true,
      );

      return false;
    }

    if (addingProject) return false;

    setState(() {
      addingProject = true;
    });

    try {
      await supabase.from('projects').insert({
        'project_name': projectName,
        'workspace_id': currentWorkspaceId,
      });

      projectController.clear();

      await loadEverything();

      showMessage(
        'Project added successfully.',
      );

      return true;
    } catch (error) {
      debugPrint('Project creation error: $error');

      showMessage(
        'Unable to add the project.',
        isError: true,
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          addingProject = false;
        });
      }
    }
  }

  Future<void> showAddProjectDialog() async {
    projectController.clear();

    await showDialog<void>(
      context: context,
      barrierDismissible: !addingProject,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitProject() async {
              setDialogState(() {});

              final success = await addProject();

              if (success && dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              } else {
                setDialogState(() {});
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.create_new_folder_outlined,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Add Project',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 430,
                child: TextField(
                  controller: projectController,
                  autofocus: true,
                  enabled: !addingProject,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    submitProject();
                  },
                  decoration: InputDecoration(
                    labelText: 'Project Name',
                    hintText: 'Enter project name',
                    prefixIcon: const Icon(
                      Icons.work_outline,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(
                        color: AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: addingProject
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      addingProject ? null : submitProject,
                  icon: addingProject
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    addingProject
                        ? 'Adding...'
                        : 'Add Project',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> getMembersForProject(
    String projectId,
  ) {
    final employeeIds = projectMembers
        .where(
          (member) =>
              member['project_id']?.toString() == projectId,
        )
        .map(
          (member) => member['employee_id']?.toString(),
        )
        .whereType<String>()
        .toSet();

    return employees
        .where(
          (employee) =>
              employeeIds.contains(
                employee['id']?.toString(),
              ),
        )
        .toList();
  }

  Future<void> showManageEmployeesDialog(
    Map<String, dynamic> project,
  ) async {
    final projectId = project['id']?.toString() ?? '';

    final projectName =
        project['project_name']?.toString().trim() ??
            'Project';

    if (projectId.isEmpty) {
      showMessage(
        'Invalid project.',
        isError: true,
      );

      return;
    }

    final selectedEmployeeIds = projectMembers
        .where(
          (member) =>
              member['project_id']?.toString() == projectId,
        )
        .map(
          (member) => member['employee_id']?.toString(),
        )
        .whereType<String>()
        .toSet();

    await showDialog<void>(
      context: context,
      barrierDismissible: !savingMembers,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveAssignments() async {
              if (savingMembers) return;

              setDialogState(() {
                savingMembers = true;
              });

              try {
                final existingAssignments = projectMembers
                    .where(
                      (member) =>
                          member['project_id']?.toString() ==
                          projectId,
                    )
                    .toList();

                final existingEmployeeIds = existingAssignments
                    .map(
                      (member) =>
                          member['employee_id']?.toString(),
                    )
                    .whereType<String>()
                    .toSet();

                final employeeIdsToAdd = selectedEmployeeIds
                    .difference(existingEmployeeIds);

                final employeeIdsToRemove = existingEmployeeIds
                    .difference(selectedEmployeeIds);

                if (employeeIdsToRemove.isNotEmpty) {
                  await supabase
                      .from('project_members')
                      .delete()
                      .eq(
                        'project_id',
                        projectId,
                      )
                      .inFilter(
                        'employee_id',
                        employeeIdsToRemove.toList(),
                      );
                }

                if (employeeIdsToAdd.isNotEmpty) {
                  final newAssignments = employeeIdsToAdd
                      .map(
                        (employeeId) => {
                          'workspace_id':
                              currentWorkspaceId,
                          'project_id': projectId,
                          'employee_id': employeeId,
                        },
                      )
                      .toList();

                  await supabase
                      .from('project_members')
                      .insert(newAssignments);
                }

                await loadProjectMembers();

                if (!mounted) return;

                setState(() {});

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                showMessage(
                  'Project employees updated successfully.',
                );
              } catch (error) {
                debugPrint(
                  'Project employee assignment error: $error',
                );

                showMessage(
                  'Unable to update project employees.',
                  isError: true,
                );
              } finally {
                savingMembers = false;

                if (dialogContext.mounted) {
                  setDialogState(() {});
                }
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                12,
              ),
              title: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.group_add_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Employees',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _projectDisplayName(projectName),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 440,
                child: employees.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 52,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'No approved employees found.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius:
                                  BorderRadius.circular(11),
                              border: Border.all(
                                color: AppColors.primaryLight,
                              ),
                            ),
                            child: Text(
                              '${selectedEmployeeIds.length} '
                              '${selectedEmployeeIds.length == 1 ? 'employee selected' : 'employees selected'}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: employees.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final employee =
                                    employees[index];

                                final employeeId =
                                    employee['id']
                                            ?.toString() ??
                                        '';

                                final fullName =
                                    employee['full_name']
                                            ?.toString()
                                            .trim();

                                final email = employee['email']
                                        ?.toString()
                                        .trim() ??
                                    '';

                                final role = employee['role']
                                        ?.toString()
                                        .trim() ??
                                    'employee';

                                final displayName =
                                    fullName == null ||
                                            fullName.isEmpty
                                        ? email
                                        : fullName;

                                final selected =
                                    selectedEmployeeIds.contains(
                                  employeeId,
                                );

                                return Container(
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primarySurface
                                        : AppColors.background,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.primaryLight
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: selected,
                                    activeColor: AppColors.primary,
                                    controlAffinity:
                                        ListTileControlAffinity
                                            .leading,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    title: Text(
                                      displayName.isEmpty
                                          ? 'Employee'
                                          : displayName,
                                      style: const TextStyle(
                                        color:
                                            AppColors.textPrimary,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      email.isEmpty
                                          ? role.toUpperCase()
                                          : '$email  •  ${role.toUpperCase()}',
                                      style: const TextStyle(
                                        color:
                                            AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    onChanged: savingMembers
                                        ? null
                                        : (checked) {
                                            setDialogState(() {
                                              if (checked == true) {
                                                selectedEmployeeIds
                                                    .add(
                                                  employeeId,
                                                );
                                              } else {
                                                selectedEmployeeIds
                                                    .remove(
                                                  employeeId,
                                                );
                                              }
                                            });
                                          },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: savingMembers
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(145, 46),
                  ),
                  onPressed:
                      savingMembers ? null : saveAssignments,
                  icon: savingMembers
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    savingMembers
                        ? 'Saving...'
                        : 'Save Employees',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String formatCreatedDate(dynamic value) {
    if (value == null) {
      return 'Date unavailable';
    }

    final date = DateTime.tryParse(
      value.toString(),
    )?.toLocal();

    if (date == null) {
      return 'Date unavailable';
    }

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

    return 'Created ${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }

  String _projectDisplayName(dynamic value) {
    var name = value?.toString().trim() ?? '';

    if (name.isEmpty ||
        name.toLowerCase() == 'unnamed project' ||
        name.toLowerCase() == 'unknown project' ||
        name.toLowerCase() == 'no project') {
      return 'Project: Unnamed Project';
    }

    name = name.replaceFirst(
      RegExp(
        r'^project\s*:\s*',
        caseSensitive: false,
      ),
      '',
    );

    if (name.trim().isEmpty) {
      return 'Project: Unnamed Project';
    }

    return 'Project: ${name.trim()}';
  }

  String projectInitial(String name) {
    final cleanedName = name.trim();

    if (cleanedName.isEmpty) return 'P';

    return cleanedName[0].toUpperCase();
  }

  String employeeInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'E';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    projectController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 54,
        centerTitle: true,
        title: const Text(
          'Project Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh projects',
            onPressed: loading ? null : loadEverything,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed:
            addingProject ? null : showAddProjectDialog,
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'Add Project',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : errorMessage != null
              ? buildErrorState()
              : projects.isEmpty
                  ? buildEmptyState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: loadEverything,
                      child: ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          22,
                          18,
                          22,
                          90,
                        ),
                        children: [
                          buildHeader(),
                          const SizedBox(height: 16),
                          if (filteredProjects.isEmpty)
                            buildNoSearchResults()
                          else
                            ...filteredProjects.map(buildProjectCard),
                        ],
                      ),
                    ),
    );
  }

  Widget buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 820;

        final title = const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Workspace Projects',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Create projects and assign employees for time tracking.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        );

        final search = SizedBox(
          width: compact ? double.infinity : 300,
          height: 42,
          child: TextField(
            controller: searchController,
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Search projects or employees',
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              suffixIcon: searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        searchController.clear();

                        setState(() {
                          searchQuery = '';
                        });
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
        );

        final count = Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryLight,
            ),
          ),
          child: Text(
            '${filteredProjects.length} '
            '${filteredProjects.length == 1 ? 'Project' : 'Projects'}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              search,
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: count,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: title,
            ),
            const SizedBox(width: 18),
            search,
            const SizedBox(width: 12),
            count,
          ],
        );
      },
    );
  }

  Widget buildProjectCard(
    Map<String, dynamic> project,
  ) {
    final projectId =
        project['id']?.toString() ?? '';

    final projectName =
        project['project_name']
                ?.toString()
                .trim() ??
            '';

    final displayName =
        projectName.isEmpty
            ? 'Unnamed Project'
            : projectName;

    final members =
        getMembersForProject(projectId);

    final expanded =
        expandedProjectIds.contains(projectId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            toggleProjectDetails(projectId);
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color:
                            AppColors.primarySurface,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              AppColors.primaryLight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          projectInitial(displayName),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _projectDisplayName(displayName),
                            style: const TextStyle(
                              color:
                                  AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons
                                    .business_outlined,
                                size: 14,
                                color:
                                    AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                currentWorkspaceName
                                        .isEmpty
                                    ? 'Workspace Project'
                                    : currentWorkspaceName,
                                style:
                                    const TextStyle(
                                  color: AppColors
                                      .textSecondary,
                                ),
                              ),
                              const SizedBox(width: 11),
                              const Icon(
                                Icons.people_outline,
                                size: 15,
                                color:
                                    AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${members.length} '
                                '${members.length == 1 ? 'employee' : 'employees'}',
                                style:
                                    const TextStyle(
                                  color: AppColors
                                      .textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCreatedDate(
                        project['created_at'],
                      ),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success
                            .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                const Divider(
                  color: AppColors.border,
                  height: 1,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: members.isEmpty
                          ? const Text(
                              'No employees assigned yet.',
                              style: TextStyle(
                                color: AppColors
                                    .textSecondary,
                              ),
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children:
                                  members.take(5).map(
                                (employee) {
                                  final name = employee[
                                              'full_name']
                                          ?.toString()
                                          .trim() ??
                                      'Employee';

                                  return Tooltip(
                                    message: name,
                                    child:
                                        CircleAvatar(
                                      radius: 15,
                                      backgroundColor:
                                          AppColors
                                              .primarySurface,
                                      foregroundColor:
                                          AppColors
                                              .primary,
                                      child: Text(
                                        employeeInitials(
                                          name,
                                        ),
                                        style:
                                            const TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ).toList(),
                            ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            AppColors.primary,
                        side: const BorderSide(
                          color:
                              AppColors.primary,
                        ),
                        padding: const EdgeInsets
                            .symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            9,
                          ),
                        ),
                      ),
                      onPressed: () {
                        showManageEmployeesDialog(
                          project,
                        );
                      },
                      icon: const Icon(
                        Icons.group_add_outlined,
                        size: 16,
                      ),
                      label: const Text(
                        'Manage Employees',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(
                    milliseconds: 220,
                  ),
                  curve: Curves.easeInOut,
                  child: expanded
                      ? Column(
                          children: [
                            const SizedBox(height: 13),
                            const Divider(
                              color: AppColors.border,
                              height: 1,
                            ),
                            const SizedBox(height: 13),
                            buildProjectTimeDetails(
                              projectId,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildProjectTimeDetails(
    String projectId,
  ) {
    final projectEmployees =
        getTimeEmployeesForProject(projectId);

    projectEmployees.sort((first, second) {
      final firstSeconds =
          projectEmployeeSeconds(
        projectId,
        first,
      );

      final secondSeconds =
          projectEmployeeSeconds(
        projectId,
        second,
      );

      return secondSeconds.compareTo(
        firstSeconds,
      );
    });

    final projectTotal =
        projectTotalSeconds(projectId);

    final previousProjectTotal =
        previousProjectTotalSeconds(projectId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              const Text(
                'EMPLOYEE TIME',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'This week ${currentWeekRangeText()}  •  Previous ${previousWeekRangeText()}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (projectEmployees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 10,
              ),
              child: Text(
                'No employee time is available for this project this week.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...projectEmployees.map(
              (employee) {
                final name =
                    employee['full_name']
                            ?.toString()
                            .trim() ??
                        'Employee';

                final projectSeconds =
                    projectEmployeeSeconds(
                  projectId,
                  employee,
                );

                final weekSeconds =
                    employeeWeekSeconds(
                  employee,
                );

                final previousProjectSeconds =
                    previousProjectEmployeeSeconds(
                  projectId,
                  employee,
                );

                final previousWeekSeconds =
                    employeePreviousWeekSeconds(
                  employee,
                );

                return Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 9,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor:
                            AppColors.primarySurface,
                        foregroundColor:
                            AppColors.primary,
                        child: Text(
                          employeeInitials(name),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: Text(
                          name,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:
                                AppColors.textPrimary,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 125,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Project this week',
                              style: TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatTrackedTime(
                                projectSeconds,
                              ),
                              style:
                                  const TextStyle(
                                color: AppColors
                                    .textPrimary,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 125,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Project previous',
                              style: TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatTrackedTime(
                                previousProjectSeconds,
                              ),
                              style:
                                  const TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 125,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total this week',
                              style: TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatTrackedTime(
                                weekSeconds,
                              ),
                              style:
                                  const TextStyle(
                                color: AppColors
                                    .textPrimary,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius:
                    BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryLight,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  const Text(
                    'PROJECT TOTAL',
                    style: TextStyle(
                      color:
                          AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'This week',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            formatTrackedTime(
                              projectTotal,
                            ),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Previous week',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            formatTrackedTime(
                              previousProjectTotal,
                            ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNoSearchResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 48,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 42,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 10),
          const Text(
            'No matching projects',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'No project or employee matches "${searchQuery.trim()}".',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: 560,
          padding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 70,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.folder_open_outlined,
                  color: AppColors.primary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No projects found',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your first project and assign employees.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: showAddProjectDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Project'),
              ),
            ],
          ),
        ),
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
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ??
                  'Unable to load projects.',
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
              onPressed: loadEverything,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
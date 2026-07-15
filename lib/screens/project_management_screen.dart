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

  bool loading = true;
  bool addingProject = false;
  bool savingMembers = false;

  String? errorMessage;

  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> projectMembers = [];

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
                borderRadius: BorderRadius.circular(18),
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
                borderRadius: BorderRadius.circular(20),
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
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          projectName,
                          overflow: TextOverflow.ellipsis,
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
                                        fontSize: 12,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Project Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed:
            addingProject ? null : showAddProjectDialog,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Project',
          style: TextStyle(
            fontWeight: FontWeight.bold,
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
                          26,
                          26,
                          26,
                          110,
                        ),
                        children: [
                          buildHeader(),
                          const SizedBox(height: 24),
                          ...projects.map(buildProjectCard),
                        ],
                      ),
                    ),
    );
  }

  Widget buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace Projects',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Create projects and assign employees for time tracking.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryLight,
            ),
          ),
          child: Text(
            '${projects.length} '
            '${projects.length == 1 ? 'Project' : 'Projects'}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildProjectCard(
    Map<String, dynamic> project,
  ) {
    final projectId = project['id']?.toString() ?? '';

    final projectName =
        project['project_name']?.toString().trim() ?? '';

    final displayName =
        projectName.isEmpty ? 'Unnamed Project' : projectName;

    final members = getMembersForProject(projectId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryLight,
                  ),
                ),
                child: Center(
                  child: Text(
                    projectInitial(displayName),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.business_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          currentWorkspaceName.isEmpty
                              ? 'Workspace Project'
                              : currentWorkspaceName,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.people_outline,
                          size: 17,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${members.length} '
                          '${members.length == 1 ? 'employee' : 'employees'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
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
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const Divider(
            color: AppColors.border,
            height: 1,
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: members.isEmpty
                    ? const Text(
                        'No employees assigned yet.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: members.take(5).map(
                          (employee) {
                            final name =
                                employee['full_name']
                                        ?.toString()
                                        .trim() ??
                                    'Employee';

                            return Tooltip(
                              message: name,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    AppColors.primarySurface,
                                foregroundColor:
                                    AppColors.primary,
                                child: Text(
                                  employeeInitials(name),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(
                    color: AppColors.primary,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () {
                  showManageEmployeesDialog(project);
                },
                icon: const Icon(
                  Icons.group_add_outlined,
                  size: 19,
                ),
                label: const Text(
                  'Manage Employees',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
            borderRadius: BorderRadius.circular(20),
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
                  fontWeight: FontWeight.bold,
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
import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_colors.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() =>
      _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final TextEditingController renameController =
      TextEditingController();

  final TextEditingController createWorkspaceController =
      TextEditingController();

  final TextEditingController inviteNameController =
      TextEditingController();

  final TextEditingController inviteEmailController =
      TextEditingController();

  final TextEditingController employeeSearchController =
      TextEditingController();

  bool loading = true;
  bool saving = false;

  String? errorMessage;
  String inviteRole = 'employee';
  String employeeSearch = '';

  Map<String, dynamic>? workspace;

  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> projectMembers = [];
  List<Map<String, dynamic>> pendingEmployees = [];
  List<Map<String, dynamic>> allWorkspaces = [];
  List<Map<String, dynamic>> weeklyEntries = [];
  List<Map<String, dynamic>> runningEntries = [];

  bool get isAdmin =>
      currentUserRole.trim().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();

    employeeSearchController.addListener(() {
      if (!mounted) return;

      setState(() {
        employeeSearch =
            employeeSearchController.text.trim().toLowerCase();
      });
    });

    loadWorkspaceData();
  }

  @override
  void dispose() {
    renameController.dispose();
    createWorkspaceController.dispose();
    inviteNameController.dispose();
    inviteEmailController.dispose();
    employeeSearchController.dispose();

    super.dispose();
  }

  DateTime getWeekStart() {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    return today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
  }

  Future<void> loadWorkspaceData() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final weekStart = getWeekStart();

      final responses = await Future.wait([
        supabase
            .from('workspaces')
            .select(
              'id, workspace_name, owner_email, owner_name',
            )
            .eq('id', currentWorkspaceId)
            .single(),

        supabase
            .from('profiles')
            .select(
              'id, full_name, email, role, workspace_id, '
              'approval_status, required_weekly_hours',
            )
            .eq('workspace_id', currentWorkspaceId)
            .order('full_name'),

        supabase
            .from('projects')
            .select(
              'id, project_name, created_at, created_by, '
              'is_active, workspace_id',
            )
            .eq('workspace_id', currentWorkspaceId)
            .order('created_at', ascending: false),

        supabase
            .from('project_members')
            .select(
              'id, project_id, employee_id, workspace_id',
            )
            .eq('workspace_id', currentWorkspaceId),

        supabase
            .from('pending_employees')
            .select(
              'full_name, email, role, status, created_at',
            )
            .eq('workspace_id', currentWorkspaceId)
            .order('created_at', ascending: false),

        supabase
            .from('workspaces')
            .select(
              'id, workspace_name, owner_email, owner_name',
            )
            .order('workspace_name'),

        supabase
            .from('time_entries')
            .select(
              'id, employee_name, project_id, start_time, '
              'end_time, duration_minutes',
            )
            .eq('workspace_id', currentWorkspaceId)
            .gte(
              'start_time',
              weekStart.toIso8601String(),
            ),

        supabase
            .from('time_entries')
            .select(
              'id, employee_name, project_id, start_time, end_time',
            )
            .eq('workspace_id', currentWorkspaceId)
            .isFilter('end_time', null),
      ]);

      if (!mounted) return;

      setState(() {
        workspace = Map<String, dynamic>.from(
          responses[0] as Map,
        );

        members = List<Map<String, dynamic>>.from(
          responses[1] as List,
        );

        projects = List<Map<String, dynamic>>.from(
          responses[2] as List,
        );

        projectMembers = List<Map<String, dynamic>>.from(
          responses[3] as List,
        );

        pendingEmployees = List<Map<String, dynamic>>.from(
          responses[4] as List,
        );

        allWorkspaces = List<Map<String, dynamic>>.from(
          responses[5] as List,
        );

        weeklyEntries = List<Map<String, dynamic>>.from(
          responses[6] as List,
        );

        runningEntries = List<Map<String, dynamic>>.from(
          responses[7] as List,
        );

        loading = false;
      });
    } catch (error) {
      debugPrint('Workspace loading error: $error');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Unable to load workspace information.';
      });

      showMessage(
        'Unable to load workspace information.',
        isError: true,
      );
    }
  }

  List<Map<String, dynamic>> get filteredMembers {
    if (employeeSearch.isEmpty) {
      return members;
    }

    return members.where((member) {
      final name = member['full_name']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      final email = member['email']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      final role = member['role']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      return name.contains(employeeSearch) ||
          email.contains(employeeSearch) ||
          role.contains(employeeSearch);
    }).toList();
  }

  int parseMinutes(dynamic value) {
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get totalWeeklyMinutes {
    int total = 0;

    for (final entry in weeklyEntries) {
      total += parseMinutes(entry['duration_minutes']);
    }

    return total;
  }

  int employeeWeeklyMinutes(String employeeName) {
    int total = 0;

    for (final entry in weeklyEntries) {
      if (entry['employee_name']?.toString().trim() ==
          employeeName.trim()) {
        total += parseMinutes(entry['duration_minutes']);
      }
    }

    return total;
  }

  List<Map<String, dynamic>> getEmployeeProjects(
    String employeeId,
  ) {
    final assignedProjectIds = projectMembers
        .where(
          (member) =>
              member['employee_id']?.toString() == employeeId,
        )
        .map(
          (member) => member['project_id']?.toString(),
        )
        .whereType<String>()
        .toSet();

    return projects
        .where(
          (project) => assignedProjectIds.contains(
            project['id']?.toString(),
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> getProjectEmployees(
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

    return members
        .where(
          (member) => employeeIds.contains(
            member['id']?.toString(),
          ),
        )
        .toList();
  }

  String getCreatorName(dynamic creatorId) {
    final id = creatorId?.toString();

    if (id == null || id.isEmpty) {
      return workspace?['owner_name']?.toString() ?? 'Admin';
    }

    for (final member in members) {
      if (member['id']?.toString() == id) {
        final name = member['full_name']?.toString().trim();

        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
    }

    return 'Admin';
  }

  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$remainingMinutes min';
    }

    if (remainingMinutes == 0) {
      return '$hours hr';
    }

    return '$hours hr $remainingMinutes min';
  }

  String formatCreatedDate(dynamic value) {
    final date = DateTime.tryParse(
      value?.toString() ?? '',
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

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }

  String initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'U';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> createNewWorkspace() async {
    final name = createWorkspaceController.text.trim();

    if (name.isEmpty) {
      showMessage(
        'Please enter a workspace name.',
        isError: true,
      );

      return;
    }

    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      final userEmail =
          supabase.auth.currentUser?.email ?? '';

      final newWorkspace = await supabase
          .from('workspaces')
          .insert({
            'workspace_name': name,
            'owner_name': currentUserName,
            'owner_email': userEmail,
          })
          .select(
            'id, workspace_name',
          )
          .single();

      final newWorkspaceId =
          newWorkspace['id'].toString();

      await supabase
          .from('profiles')
          .update({
            'workspace_id': newWorkspaceId,
            'role': 'admin',
          })
          .eq('id', currentUserId);

      currentWorkspaceId = newWorkspaceId;

      currentWorkspaceName =
          newWorkspace['workspace_name']?.toString() ?? name;

      createWorkspaceController.clear();

      if (mounted) {
        Navigator.of(context).pop();
      }

      showMessage(
        'New workspace created successfully.',
      );

      await loadWorkspaceData();
    } catch (error) {
      debugPrint('Create workspace error: $error');

      showMessage(
        'Unable to create the workspace.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> switchWorkspace(
    String workspaceId,
  ) async {
    final selectedWorkspace = allWorkspaces.firstWhere(
      (item) => item['id']?.toString() == workspaceId,
      orElse: () => <String, dynamic>{},
    );

    currentWorkspaceId = workspaceId;

    currentWorkspaceName =
        selectedWorkspace['workspace_name']?.toString() ?? '';

    showMessage('Workspace switched successfully.');

    await loadWorkspaceData();
  }

  Future<void> renameWorkspace() async {
    final newName = renameController.text.trim();

    if (newName.isEmpty) {
      showMessage(
        'Please enter a workspace name.',
        isError: true,
      );

      return;
    }

    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      await supabase
          .from('workspaces')
          .update({
            'workspace_name': newName,
          })
          .eq('id', currentWorkspaceId);

      currentWorkspaceName = newName;
      renameController.clear();

      if (mounted) {
        Navigator.of(context).pop();
      }

      showMessage(
        'Workspace renamed successfully.',
      );

      await loadWorkspaceData();
    } catch (error) {
      debugPrint('Rename workspace error: $error');

      showMessage(
        'Unable to rename the workspace.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

Future<void> inviteEmployee() async {
  final name = inviteNameController.text.trim();

  final email = inviteEmailController.text
      .trim()
      .toLowerCase();

  if (name.isEmpty || email.isEmpty) {
    showMessage(
      'Please enter the employee name and email.',
      isError: true,
    );
    return;
  }

  if (!email.contains('@')) {
    showMessage(
      'Please enter a valid email address.',
      isError: true,
    );
    return;
  }

  if (saving) return;

  setState(() {
    saving = true;
  });

  try {
    debugPrint('CALLING invite-workspace-member');
   final session = supabase.auth.currentSession;

if (session == null) {
  throw Exception(
    'Your login session has expired. Please log in again.',
  );
}

final response = await supabase.functions.invoke(
  'invite-workspace-member',
  headers: {
    'Authorization':
        'Bearer ${session.accessToken}',
  },
  body: {
    'full_name': name,
    'email': email,
    'role': 'employee',
    'workspace_id': currentWorkspaceId,
    'redirect_to': 'timetracker://invite',
  },
);

    final data = response.data;

    if (data is Map &&
        data['error'] != null) {
      throw Exception(
        data['error'].toString(),
      );
    }

    inviteNameController.clear();
    inviteEmailController.clear();
    inviteRole = 'employee';

    if (mounted &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    showMessage(
      'Invitation email sent successfully.',
    );

    await loadWorkspaceData();
  } catch (error) {
    debugPrint(
      'Invite employee error: $error',
    );

    var message =
        'Unable to send the invitation.';

    final errorText = error.toString();

    if (errorText.contains(
      'already has a pending invitation',
    )) {
      message =
          'This employee already has a pending invitation.';
    } else if (errorText.contains(
      'already exists with this email',
    )) {
      message =
          'An account already exists with this email.';
    } else if (errorText.contains(
      'Only administrators',
    )) {
      message =
          'Only administrators can invite employees.';
    }

    showMessage(
      message,
      isError: true,
    );
  } finally {
    if (mounted) {
      setState(() {
        saving = false;
      });
    }
  }
}

  Future<void> activatePendingEmployee(
    Map<String, dynamic> employee,
  ) async {
    final email = employee['email']?.toString() ?? '';

    if (email.isEmpty) return;

    try {
      await supabase.rpc(
        'activate_pending_employee',
        params: {
          'invite_email': email,
          'workspace': currentWorkspaceId,
        },
      );

      showMessage(
        'Employee activated successfully.',
      );

      await loadWorkspaceData();
    } catch (error) {
      debugPrint('Employee activation error: $error');

      showMessage(
        'Activation failed. Ensure the employee has registered.',
        isError: true,
      );
    }
  }
  Future<void> resendWorkspaceInvitation(
  Map<String, dynamic> employee,
) async {
  final email =
      employee['email']?.toString().trim().toLowerCase() ?? '';

  if (email.isEmpty) {
    showMessage(
      'Invitation email is missing.',
      isError: true,
    );
    return;
  }

  if (saving) return;

  setState(() {
    saving = true;
  });

  try {
    final response = await supabase.functions.invoke(
      'resend-workspace-invitation',
      body: {
        'email': email,
        'workspace_id': currentWorkspaceId,
        'redirect_to': 'timetracker://invite',
      },
    );

    final data = response.data;

    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    showMessage(
      'Invitation resent successfully.',
    );

    await loadWorkspaceData();
  } catch (error) {
    debugPrint(
      'Resend invitation error: $error',
    );

    final errorText = error.toString();

    showMessage(
      errorText.contains('No active pending invitation')
          ? 'This invitation is no longer active.'
          : errorText.contains(
              'already completed registration',
            )
              ? 'This employee has already joined the workspace.'
              : 'Unable to resend the invitation.',
      isError: true,
    );
  } finally {
    if (mounted) {
      setState(() {
        saving = false;
      });
    }
  }
}
  Future<void> cancelWorkspaceInvitation(
  Map<String, dynamic> employee,
) async {
  final email =
      employee['email']?.toString().trim().toLowerCase() ?? '';

  if (email.isEmpty) {
    showMessage(
      'Invitation email is missing.',
      isError: true,
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Cancel Invitation',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Cancel the invitation sent to $email?',
          style: const TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Keep Invitation'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Cancel Invitation'),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;

  if (saving) return;

  setState(() {
    saving = true;
  });

  try {
    final response = await supabase.functions.invoke(
      'cancel-workspace-invitation',
      body: {
        'email': email,
        'workspace_id': currentWorkspaceId,
      },
    );

    final data = response.data;

    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    showMessage(
      'Invitation cancelled successfully.',
    );

    await loadWorkspaceData();
  } catch (error) {
    debugPrint(
      'Cancel invitation error: $error',
    );

    showMessage(
      error
              .toString()
              .contains('No active pending invitation')
          ? 'This invitation is no longer active.'
          : 'Unable to cancel the invitation.',
      isError: true,
    );
  } finally {
    if (mounted) {
      setState(() {
        saving = false;
      });
    }
  }
}

  Future<void> saveEmployeeProjects({
    required String employeeId,
    required Set<String> selectedProjectIds,
  }) async {
    final existingProjectIds = projectMembers
        .where(
          (member) =>
              member['employee_id']?.toString() == employeeId,
        )
        .map(
          (member) => member['project_id']?.toString(),
        )
        .whereType<String>()
        .toSet();

    final projectIdsToAdd = selectedProjectIds.difference(
      existingProjectIds,
    );

    final projectIdsToRemove = existingProjectIds.difference(
      selectedProjectIds,
    );

    if (projectIdsToRemove.isNotEmpty) {
      await supabase
          .from('project_members')
          .delete()
          .eq('employee_id', employeeId)
          .inFilter(
            'project_id',
            projectIdsToRemove.toList(),
          );
    }

    if (projectIdsToAdd.isNotEmpty) {
      await supabase.from('project_members').insert(
            projectIdsToAdd
                .map(
                  (projectId) => {
                    'workspace_id': currentWorkspaceId,
                    'project_id': projectId,
                    'employee_id': employeeId,
                  },
                )
                .toList(),
          );
    }
  }

  Future<void> saveProjectEmployees({
    required String projectId,
    required Set<String> selectedEmployeeIds,
  }) async {
    final existingEmployeeIds = projectMembers
        .where(
          (member) =>
              member['project_id']?.toString() == projectId,
        )
        .map(
          (member) => member['employee_id']?.toString(),
        )
        .whereType<String>()
        .toSet();

    final employeeIdsToAdd = selectedEmployeeIds.difference(
      existingEmployeeIds,
    );

    final employeeIdsToRemove = existingEmployeeIds.difference(
      selectedEmployeeIds,
    );

    if (employeeIdsToRemove.isNotEmpty) {
      await supabase
          .from('project_members')
          .delete()
          .eq('project_id', projectId)
          .inFilter(
            'employee_id',
            employeeIdsToRemove.toList(),
          );
    }

    if (employeeIdsToAdd.isNotEmpty) {
      await supabase.from('project_members').insert(
            employeeIdsToAdd
                .map(
                  (employeeId) => {
                    'workspace_id': currentWorkspaceId,
                    'project_id': projectId,
                    'employee_id': employeeId,
                  },
                )
                .toList(),
          );
    }
  }

  Future<void> toggleProjectStatus(
    Map<String, dynamic> project,
  ) async {
    final projectId = project['id']?.toString() ?? '';
    final isActive = project['is_active'] != false;

    if (projectId.isEmpty) return;

    try {
      await supabase
          .from('projects')
          .update({
            'is_active': !isActive,
          })
          .eq('id', projectId);

      showMessage(
        isActive
            ? 'Project archived successfully.'
            : 'Project activated successfully.',
      );

      await loadWorkspaceData();
    } catch (error) {
      debugPrint('Project status error: $error');

      showMessage(
        'Unable to update the project.',
        isError: true,
      );
    }
  }

  void showCreateWorkspaceDialog() {
    createWorkspaceController.clear();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.add_business_outlined,
                color: AppColors.primary,
              ),
              SizedBox(width: 12),
              Text(
                'Create Workspace',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: TextField(
              controller: createWorkspaceController,
              autofocus: true,
              decoration: inputDecoration(
                label: 'Workspace Name',
                icon: Icons.business_outlined,
              ),
              onSubmitted: (_) {
                createNewWorkspace();
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                    },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: saving ? null : createNewWorkspace,
              icon: saving
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
                saving ? 'Creating...' : 'Create',
              ),
            ),
          ],
        );
      },
    );
  }

  void showRenameDialog() {
    renameController.text =
        workspace?['workspace_name']?.toString() ?? '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
              ),
              SizedBox(width: 12),
              Text(
                'Rename Workspace',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: TextField(
              controller: renameController,
              autofocus: true,
              decoration: inputDecoration(
                label: 'Workspace Name',
                icon: Icons.business_outlined,
              ),
              onSubmitted: (_) {
                renameWorkspace();
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                    },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: saving ? null : renameWorkspace,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void showInviteEmployeeDialog() {
    inviteNameController.clear();
    inviteEmailController.clear();
    inviteRole = 'employee';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Invite Employee',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: inviteNameController,
                      decoration: inputDecoration(
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: inviteEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: inputDecoration(
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: inviteRole,
                      decoration: inputDecoration(
                        label: 'Role',
                        icon: Icons.badge_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'employee',
                          child: Text('Employee'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          inviteRole = value ?? 'employee';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: saving ? null : inviteEmployee,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send Invite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showWorkspaceSwitcher() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.swap_horiz_outlined,
                color: AppColors.primary,
              ),
              SizedBox(width: 12),
              Text(
                'Switch Workspace',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            height: 420,
            child: ListView.separated(
              itemCount: allWorkspaces.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = allWorkspaces[index];

                final workspaceId =
                    item['id']?.toString() ?? '';

                final selected =
                    workspaceId == currentWorkspaceId;

                return Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primarySurface
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryLight
                          : AppColors.border,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: selected
                          ? AppColors.success
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      child: Icon(
                        selected
                            ? Icons.check
                            : Icons.business_outlined,
                      ),
                    ),
                    title: Text(
                      item['workspace_name']?.toString() ??
                          'Workspace',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      item['owner_email']?.toString() ?? '',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: selected
                        ? const Text(
                            'CURRENT',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();

                              await switchWorkspace(
                                workspaceId,
                              );
                            },
                            child: const Text('Switch'),
                          ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
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

  void showManageEmployeeProjectsDialog(
    Map<String, dynamic> employee,
  ) {
    final employeeId = employee['id']?.toString() ?? '';

    final employeeName =
        employee['full_name']?.toString().trim() ?? 'Employee';

    final selectedProjectIds = getEmployeeProjects(employeeId)
        .map(
          (project) => project['id']?.toString(),
        )
        .whereType<String>()
        .toSet();

    bool dialogSaving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              setDialogState(() {
                dialogSaving = true;
              });

              try {
                await saveEmployeeProjects(
                  employeeId: employeeId,
                  selectedProjectIds: selectedProjectIds,
                );

                await loadWorkspaceData();

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                showMessage(
                  'Employee projects updated successfully.',
                );
              } catch (error) {
                debugPrint(
                  'Manage employee projects error: $error',
                );

                showMessage(
                  'Unable to update employee projects.',
                  isError: true,
                );

                if (dialogContext.mounted) {
                  setDialogState(() {
                    dialogSaving = false;
                  });
                }
              }
            }

            final availableProjects = projects
                .where(
                  (project) => project['is_active'] != false,
                )
                .toList();

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.folder_shared_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Projects',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          employeeName,
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
                height: 460,
                child: availableProjects.isEmpty
                    ? const Center(
                        child: Text(
                          'No active projects found.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryLight,
                              ),
                            ),
                            child: Text(
                              '${selectedProjectIds.length} '
                              '${selectedProjectIds.length == 1 ? 'project selected' : 'projects selected'}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: ListView.separated(
                              itemCount: availableProjects.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 9),
                              itemBuilder: (context, index) {
                                final project =
                                    availableProjects[index];

                                final projectId =
                                    project['id']?.toString() ?? '';

                                final projectName =
                                    project['project_name']
                                            ?.toString() ??
                                        'Project';

                                final selected =
                                    selectedProjectIds.contains(
                                  projectId,
                                );

                                return Container(
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primarySurface
                                        : AppColors.background,
                                    borderRadius:
                                        BorderRadius.circular(13),
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
                                    title: Text(
                                      projectName,
                                      style: const TextStyle(
                                        color:
                                            AppColors.textPrimary,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${getProjectEmployees(projectId).length} members',
                                      style: const TextStyle(
                                        color:
                                            AppColors.textSecondary,
                                      ),
                                    ),
                                    onChanged: dialogSaving
                                        ? null
                                        : (checked) {
                                            setDialogState(() {
                                              if (checked == true) {
                                                selectedProjectIds.add(
                                                  projectId,
                                                );
                                              } else {
                                                selectedProjectIds
                                                    .remove(
                                                  projectId,
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
                  onPressed: dialogSaving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: dialogSaving ? null : save,
                  icon: dialogSaving
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
                    dialogSaving ? 'Saving...' : 'Save Projects',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showManageProjectEmployeesDialog(
    Map<String, dynamic> project,
  ) {
    final projectId = project['id']?.toString() ?? '';

    final projectName =
        project['project_name']?.toString().trim() ?? 'Project';

    final selectedEmployeeIds = getProjectEmployees(projectId)
        .map(
          (employee) => employee['id']?.toString(),
        )
        .whereType<String>()
        .toSet();

    bool dialogSaving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              setDialogState(() {
                dialogSaving = true;
              });

              try {
                await saveProjectEmployees(
                  projectId: projectId,
                  selectedEmployeeIds: selectedEmployeeIds,
                );

                await loadWorkspaceData();

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                showMessage(
                  'Project employees updated successfully.',
                );
              } catch (error) {
                debugPrint(
                  'Manage project employees error: $error',
                );

                showMessage(
                  'Unable to update project employees.',
                  isError: true,
                );

                if (dialogContext.mounted) {
                  setDialogState(() {
                    dialogSaving = false;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.group_add_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Employees',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          projectName,
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
                height: 460,
                child: members.isEmpty
                    ? const Center(
                        child: Text(
                          'No employees found.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius:
                                  BorderRadius.circular(12),
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
                          const SizedBox(height: 14),
                          Expanded(
                            child: ListView.separated(
                              itemCount: members.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 9),
                              itemBuilder: (context, index) {
                                final employee = members[index];

                                final employeeId =
                                    employee['id']?.toString() ?? '';

                                final employeeName =
                                    employee['full_name']
                                            ?.toString() ??
                                        'Employee';

                                final role =
                                    employee['role']?.toString() ??
                                        'employee';

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
                                        BorderRadius.circular(13),
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
                                    secondary: CircleAvatar(
                                      backgroundColor:
                                          AppColors.primary,
                                      foregroundColor: Colors.white,
                                      child: Text(
                                        initials(employeeName),
                                      ),
                                    ),
                                    title: Text(
                                      employeeName,
                                      style: const TextStyle(
                                        color:
                                            AppColors.textPrimary,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      role.toUpperCase(),
                                      style: const TextStyle(
                                        color:
                                            AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onChanged: dialogSaving
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
                  onPressed: dialogSaving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: dialogSaving ? null : save,
                  icon: dialogSaving
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
                    dialogSaving
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

  static InputDecoration inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
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
    );
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
Widget build(BuildContext context) {
  final workspaceName =
      workspace?['workspace_name']?.toString() ??
          'Workspace';

  final ownerName =
      workspace?['owner_name']?.toString() ??
          currentUserName;

  final ownerEmail =
      workspace?['owner_email']?.toString() ?? '';

  final activeProjects = projects
      .where((p) => p['is_active'] != false)
      .length;

  return Scaffold(
    backgroundColor: const Color(0xffF5F7FB),

    appBar: AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,

      title: const Text(
        "Workspace",
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),

      actions: [

        IconButton(
          tooltip: "Refresh",
          onPressed: loadWorkspaceData,
          icon: const Icon(
            Icons.refresh,
            color: Colors.black87,
          ),
        ),

        const SizedBox(width: 12),

      ],
    ),

    body: loading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : RefreshIndicator(
            onRefresh: loadWorkspaceData,
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [

                buildWorkspaceHero(
                  workspaceName: workspaceName,
                  ownerName: ownerName,
                  ownerEmail: ownerEmail,
                ),

                const SizedBox(height: 28),

                buildStatistics(
                  activeProjects: activeProjects,
                ),

                const SizedBox(height: 35),

                buildMembersSection(),

                const SizedBox(height: 35),

                buildProjectsSection(),

                const SizedBox(height: 35),

                buildPendingInvitesSection(),

              ],
            ),
          ),

    floatingActionButton: isAdmin
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              FloatingActionButton.extended(
                heroTag: "invite",

                backgroundColor: AppColors.primary,

                onPressed: showInviteEmployeeDialog,

                icon: const Icon(Icons.person_add),

                label: const Text(
                  "Invite Employee",
                ),
              ),

              const SizedBox(height: 16),

              FloatingActionButton.extended(

                heroTag: "workspace",

                backgroundColor: Colors.green,

                onPressed: showCreateWorkspaceDialog,

                icon: const Icon(Icons.add_business),

                label: const Text(
                  "New Workspace",
                ),
              ),

            ],
          )
        : null,
  );
}
Widget buildWorkspaceHero({
  required String workspaceName,
  required String ownerName,
  required String ownerEmail,
}) {
  return Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x11000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          children: [

            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.business,
                color: AppColors.primary,
                size: 40,
              ),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  Text(
                    workspaceName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    ownerEmail,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                    child: const Text(
                      "Workspace Active",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                ],
              ),
            ),

          ],
        ),

        const SizedBox(height: 30),

        Row(
          children: [

            Expanded(
              child: FilledButton.icon(
                onPressed: showInviteEmployeeDialog,
                icon: const Icon(Icons.person_add),
                label: const Text("Invite Employee"),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: OutlinedButton.icon(
                onPressed: showRenameDialog,
                icon: const Icon(Icons.edit),
                label: const Text("Rename"),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: OutlinedButton.icon(
                onPressed: showWorkspaceSwitcher,
                icon: const Icon(Icons.swap_horiz),
                label: const Text("Switch"),
              ),
            ),

          ],
        ),

        const SizedBox(height: 25),

        Divider(),

        const SizedBox(height: 20),

        Wrap(
          spacing: 40,
          runSpacing: 15,
          children: [

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: Colors.grey,
                ),

                const SizedBox(width: 8),

                Text(
                  ownerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),

              ],
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Icon(
                  Icons.people_outline,
                  size: 18,
                  color: Colors.grey,
                ),

                const SizedBox(width: 8),

                Text(
                  "${members.length} Members",
                ),

              ],
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: Colors.grey,
                ),

                const SizedBox(width: 8),

                Text(
                  "${projects.length} Projects",
                ),

              ],
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Icon(
                  Icons.mail_outline,
                  size: 18,
                  color: Colors.grey,
                ),

                const SizedBox(width: 8),

                Text(
                  "${pendingEmployees.length} Pending Invites",
                ),

              ],
            ),

          ],
        ),

      ],
    ),
  );
}

 Widget buildStatistics({
  required int activeProjects,
}) {
  return GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 18,
    crossAxisSpacing: 18,
    childAspectRatio: 1.45,
    children: [

      dashboardCard(
        title: "Members",
        value: members.length.toString(),
        icon: Icons.people,
        color: Colors.blue,
      ),

      dashboardCard(
        title: "Projects",
        value: activeProjects.toString(),
        icon: Icons.folder_copy_outlined,
        color: Colors.orange,
      ),

      dashboardCard(
        title: "Running",
        value: runningEntries.length.toString(),
        icon: Icons.play_circle_fill,
        color: Colors.green,
      ),

      dashboardCard(
        title: "Pending",
        value: pendingEmployees.length.toString(),
        icon: Icons.mail_outline,
        color: Colors.red,
      ),

    ],
  );
}

Widget dashboardCard({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(.12),
          child: Icon(
            icon,
            color: color,
          ),
        ),

        const Spacer(),

        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 15,
          ),
        ),

      ],
    ),
  );
}

  Widget statisticCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(
        minHeight: 165,
      ),
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
Widget buildMembersSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Icon(
            Icons.people,
            color: AppColors.primary,
          ),
          SizedBox(width: 10),
          Text(
            "Team Members",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),

      const SizedBox(height: 20),

      if (filteredMembers.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              "No employees found.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        )
      else
        ...filteredMembers.map((member) {
          final name =
              member["full_name"]?.toString() ??
                  "Employee";

          final email =
              member["email"]?.toString() ??
                  "";

          final role =
              member["role"]?.toString() ??
                  "employee";

          final employeeId =
              member["id"]?.toString() ?? "";

          final weeklyMinutes =
              employeeWeeklyMinutes(name);

          final assignedProjects =
              getEmployeeProjects(employeeId);

          final isRunning = runningEntries.any(
            (e) =>
                e["employee_name"]
                    ?.toString()
                    .trim() ==
                name.trim(),
          );

          return Container(
            margin:
                const EdgeInsets.only(bottom: 16),
            padding:
                const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      AppColors.primary,
                  child: Text(
                    initials(name),
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 18),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration:
                                BoxDecoration(
                              color: role ==
                                      "admin"
                                  ? Colors.orange
                                      .shade100
                                  : Colors.blue
                                      .shade100,
                              borderRadius:
                                  BorderRadius.circular(
                                      30),
                            ),
                            child: Text(
                              role
                                  .toUpperCase(),
                              style:
                                  const TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        email,
                        style:
                            const TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          Text(
                            "Projects : ${assignedProjects.length}",
                          ),

                          Text(
                            "Week : ${formatDuration(weeklyMinutes)}",
                          ),

                          Text(
                            isRunning
                                ? "🟢 Running"
                                : "⚪ Offline",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                FilledButton.icon(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        AppColors.primary,
                    foregroundColor:
                        Colors.white,
                  ),
                  onPressed: () {
                    showManageEmployeeProjectsDialog(
                      member,
                    );
                  },
                  icon:
                      const Icon(Icons.settings),
                  label:
                      const Text("Manage"),
                ),
              ],
            ),
          );
        }),
    ],
  );
}

  Widget buildEmployeeCard(
    Map<String, dynamic> employee,
  ) {
    final employeeId =
        employee['id']?.toString() ?? '';

    final name =
        employee['full_name']?.toString().trim() ?? '';

    final email =
        employee['email']?.toString().trim() ?? '';

    final role =
        employee['role']?.toString().trim() ?? 'employee';

    final isEmployeeAdmin =
        role.toLowerCase() == 'admin';

    final employeeProjects =
        getEmployeeProjects(employeeId);

    final weeklyMinutes =
        employeeWeeklyMinutes(name);

    final requiredHours = int.tryParse(
          employee['required_weekly_hours']?.toString() ?? '',
        ) ??
        45;

    final weeklyTargetMinutes = requiredHours * 60;

    final progress = weeklyTargetMinutes == 0
        ? 0.0
        : (weeklyMinutes / weeklyTargetMinutes)
            .clamp(0.0, 1.0);

    final running = runningEntries.any(
      (entry) =>
          entry['employee_name']?.toString().trim() ==
          name,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: isEmployeeAdmin
                    ? AppColors.primary
                    : AppColors.primarySurface,
                foregroundColor: isEmployeeAdmin
                    ? Colors.white
                    : AppColors.primary,
                child: Text(
                  initials(name.isEmpty ? email : name),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment:
                          WrapCrossAlignment.center,
                      children: [
                        Text(
                          name.isEmpty ? 'Employee' : name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        roleBadge(
                          isEmployeeAdmin
                              ? 'ADMIN'
                              : 'EMPLOYEE',
                          isEmployeeAdmin,
                        ),
                        if (running)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'TRACKING NOW',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    showManageEmployeeProjectsDialog(employee);
                  },
                  icon: const Icon(
                    Icons.folder_shared_outlined,
                  ),
                  label: const Text(
                    'Manage Projects',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(
            color: AppColors.border,
            height: 1,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  employeeInfoBox(
                    width: constraints.maxWidth >= 800
                        ? 205
                        : constraints.maxWidth,
                    icon: Icons.schedule_outlined,
                    title: 'This Week',
                    value: formatDuration(weeklyMinutes),
                  ),
                  employeeInfoBox(
                    width: constraints.maxWidth >= 800
                        ? 205
                        : constraints.maxWidth,
                    icon: Icons.flag_outlined,
                    title: 'Weekly Target',
                    value: '$requiredHours hr',
                  ),
                  employeeInfoBox(
                    width: constraints.maxWidth >= 800
                        ? 205
                        : constraints.maxWidth,
                    icon: Icons.folder_outlined,
                    title: 'Assigned Projects',
                    value: employeeProjects.length.toString(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Weekly progress',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: employeeProjects.isEmpty
                ? const Text(
                    'No projects assigned.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  )
                : Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: employeeProjects.map(
                      (project) {
                        final projectName =
                            project['project_name']
                                    ?.toString() ??
                                'Project';

                        final isActive =
                            project['is_active'] != false;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primarySurface
                                : AppColors.background,
                            borderRadius:
                                BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primaryLight
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            projectName,
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildPendingInvitesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          title: 'Pending Invitations',
          subtitle:
              'Employees waiting to accept their workspace invitation.',
          count: pendingEmployees.length,
        ),
        const SizedBox(height: 20),
        ...pendingEmployees.map(
          (employee) {
            final name =
                employee['full_name']?.toString() ?? 'Employee';

            final email =
                employee['email']?.toString() ?? '';

            final role =
                employee['role']?.toString() ?? 'employee';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(21),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor:
                        AppColors.primarySurface,
                    foregroundColor: AppColors.primary,
                    child: Text(
                      initials(name),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          email,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${role.toUpperCase()} • '
                          '${employee['status']?.toString() ?? 'PENDING'}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
  Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
        ),
        onPressed: saving
            ? null
            : () {
                resendWorkspaceInvitation(employee);
              },
        icon: const Icon(Icons.refresh_outlined),
        label: const Text("Resend"),
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(
            color: AppColors.danger,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
        ),
        onPressed: saving
            ? null
            : () {
                cancelWorkspaceInvitation(employee);
              },
        icon: const Icon(Icons.cancel_outlined),
        label: const Text("Cancel"),
      ),
    ],
  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildProjectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          title: 'Workspace Projects',
          subtitle:
              'Review project members, ownership and availability.',
          count: projects.length,
        ),
        const SizedBox(height: 20),
        if (projects.isEmpty)
          emptySection(
            icon: Icons.folder_off_outlined,
            title: 'No projects found',
            subtitle:
                'Create projects from Project Management.',
          )
        else
          ...projects.map(buildProjectCard),
      ],
    );
  }

  Widget buildProjectCard(
    Map<String, dynamic> project,
  ) {
    final projectId =
        project['id']?.toString() ?? '';

    final projectName =
        project['project_name']?.toString().trim() ?? '';

    final displayName =
        projectName.isEmpty ? 'Unnamed Project' : projectName;

    final projectEmployees =
        getProjectEmployees(projectId);

    final isActive =
        project['is_active'] != false;

    final creatorName =
        getCreatorName(project['created_by']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primarySurface
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primaryLight
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  isActive
    ? Icons.folder_open
    : Icons.folder_off,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 33,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment:
                          WrapCrossAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.success.withValues(
                                    alpha: 0.10,
                                  )
                                : AppColors.background,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : 'ARCHIVED',
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        infoLabel(
  Icons.calendar_today_outlined,
  formatCreatedDate(project['created_at']),
),
                        infoLabel(
                          Icons.calendar_today_outlined,
                          formatCreatedDate(
                            project['created_at'],
                          ),
                        ),
                        infoLabel(
                          Icons.people_outline,
                          '${projectEmployees.length} members',
                        ),
                        infoLabel(
  Icons.play_circle_fill_outlined,
  '${runningEntries.where((e) => e["project_id"]?.toString() == projectId).length} running',
),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
                      ),
                      onPressed: () {
                        showManageProjectEmployeesDialog(project);
                      },
                      icon: const Icon(
                        Icons.group_add_outlined,
                      ),
                      label: const Text(
                        'Manage Employees',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: isActive
                            ? AppColors.textSecondary
                            : AppColors.success,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                      ),
                      onPressed: () {
                        toggleProjectStatus(project);
                      },
                      icon: Icon(
                        isActive
                            ? Icons.archive_outlined
                            : Icons.unarchive_outlined,
                      ),
                      label: Text(
                        isActive ? 'Archive' : 'Activate',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 21),
          const Divider(
            color: AppColors.border,
            height: 1,
          ),
          const SizedBox(height: 19),
          Align(
            alignment: Alignment.centerLeft,
            child: projectEmployees.isEmpty
                ? const Text(
                    'No employees assigned to this project.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: projectEmployees.map(
                      (employee) {
                        final name =
                            employee['full_name']
                                    ?.toString()
                                    .trim() ??
                                'Employee';

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius:
                                BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.primaryLight,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    AppColors.primary,
                                foregroundColor: Colors.white,
                                child: Text(
                                  initials(name),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget sectionHeader({
    required String title,
    required String subtitle,
    required int count,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primaryLight,
            ),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget infoLabel(
    IconData icon,
    String text,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: AppColors.textMuted,
          size: 17,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget roleBadge(
    String label,
    bool admin,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: admin
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: admin
              ? AppColors.primary
              : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget employeeInfoBox({
    required double width,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 41,
            height: 41,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget emptySection({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 30,
        vertical: 55,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
              size: 60,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ??
                  'Unable to load workspace information.',
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
              onPressed: loadWorkspaceData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
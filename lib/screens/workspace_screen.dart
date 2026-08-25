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

  final TextEditingController workspaceKpiSearchController =
      TextEditingController();

  bool loading = true;
  bool saving = false;

  String? errorMessage;
  String inviteRole = 'employee';
  String employeeSearch = '';
  String workspaceKpiSearch = '';
  String selectedWorkspaceKpi = 'projects';

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

    workspaceKpiSearchController.addListener(() {
      if (!mounted) return;

      setState(() {
        workspaceKpiSearch =
            workspaceKpiSearchController.text.trim().toLowerCase();
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
    workspaceKpiSearchController.dispose();

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
    .eq('status', 'pending')
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
    final query = selectedWorkspaceKpi == 'members'
        ? workspaceKpiSearch
        : employeeSearch;

    if (query.isEmpty) {
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

      return name.contains(query) ||
          email.contains(query) ||
          role.contains(query);
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
currentWorkspaceNameNotifier.value = newName;

if (mounted) {
  setState(() {
    workspace?['workspace_name'] = newName;
  });
}

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
          borderRadius: BorderRadius.circular(13),
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
                  const SizedBox(height: 6),
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
  centerTitle: true,
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  surfaceTintColor: AppColors.primary,
  title: const Text(
    'Workspace',
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
  actions: [
  IconButton(
    tooltip: 'Invite Employee',
    onPressed: showInviteEmployeeDialog,
    icon: const Icon(Icons.person_add_outlined),
  ),

  IconButton(
    tooltip: 'New Workspace',
    onPressed: showCreateWorkspaceDialog,
    icon: const Icon(Icons.add_business_outlined),
  ),

  IconButton(
    tooltip: 'Refresh',
    onPressed: loadWorkspaceData,
    icon: const Icon(Icons.refresh),
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [

                buildWorkspaceHero(
                  workspaceName: workspaceName,
                  ownerName: ownerName,
                  ownerEmail: ownerEmail,
                ),

                const SizedBox(height: 16),

                buildStatistics(
                  activeProjects: activeProjects,
                ),

                const SizedBox(height: 12),

                buildKpiSearchBox(),

                buildSelectedWorkspaceSection(),

              ],
            ),
          ),

  );
}
Widget buildWorkspaceHero({
  required String workspaceName,
  required String ownerName,
  required String ownerEmail,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x11000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          children: [

            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.business,
                color: AppColors.primary,
                size: 28,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  Text(
                    workspaceName,
                    style: const TextStyle(
                      fontSize: 21,
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

                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(20),
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

        const SizedBox(height: 16),

        Row(
          children: [

            Expanded(
              child: FilledButton.icon(
                onPressed: showInviteEmployeeDialog,
                icon: const Icon(Icons.person_add),
                label: const Text("Invite Employee"),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: OutlinedButton.icon(
                onPressed: showRenameDialog,
                icon: const Icon(Icons.edit),
                label: const Text("Rename"),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: OutlinedButton.icon(
                onPressed: showWorkspaceSwitcher,
                icon: const Icon(Icons.swap_horiz),
                label: const Text("Switch"),
              ),
            ),

          ],
        ),

        const SizedBox(height: 14),

        Divider(),

        const SizedBox(height: 12),

        Wrap(
          spacing: 26,
          runSpacing: 10,
          children: [

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Icon(
                  Icons.person_outline,
                  size: 15,
                  color: Colors.grey,
                ),

                const SizedBox(width: 6),

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
                  size: 15,
                  color: Colors.grey,
                ),

                const SizedBox(width: 6),

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
                  size: 15,
                  color: Colors.grey,
                ),

                const SizedBox(width: 6),

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
                  size: 15,
                  color: Colors.grey,
                ),

                const SizedBox(width: 6),

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
  return SizedBox(
    height: 76,
    child: Row(
      children: [
        Expanded(
          child: dashboardCard(
            title: "Members",
            value: members.length.toString(),
            icon: Icons.people,
            color: Colors.blue,
            section: 'members',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: dashboardCard(
            title: "Projects",
            value: activeProjects.toString(),
            icon: Icons.folder_copy_outlined,
            color: Colors.orange,
            section: 'projects',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: dashboardCard(
            title: "Running",
            value: runningEntries.length.toString(),
            icon: Icons.play_circle_fill,
            color: Colors.green,
            section: 'running',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: dashboardCard(
            title: "Pending",
            value: pendingEmployees.length.toString(),
            icon: Icons.mail_outline,
            color: Colors.red,
            section: 'pending',
          ),
        ),
      ],
    ),
  );
}

Widget dashboardCard({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
  required String section,
}) {
  final selected = selectedWorkspaceKpi == section;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () {
        setState(() {
          selectedWorkspaceKpi = section;
          workspaceKpiSearch = '';
          workspaceKpiSearchController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.055)
              : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.55)
                : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x09000000),
              blurRadius: 7,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? color
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                size: 16,
                color: color,
              ),
          ],
        ),
      ),
    ),
  );
}

Widget buildKpiSearchBox() {
  String hint;

  switch (selectedWorkspaceKpi) {
    case 'members':
      hint = 'Search members by name, email or role...';
      break;
    case 'projects':
      hint = 'Search projects by name...';
      break;
    case 'running':
      hint = 'Search running employees...';
      break;
    case 'pending':
      hint = 'Search pending invitations by name, email or role...';
      break;
    default:
      hint = 'Search...';
  }

  return Container(
    height: 42,
    margin: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: workspaceKpiSearchController,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textMuted,
          fontWeight: FontWeight.normal,
        ),
        prefixIcon: const Icon(
          Icons.search,
          size: 19,
          color: AppColors.textSecondary,
        ),
        suffixIcon: workspaceKpiSearch.isNotEmpty
            ? IconButton(
                tooltip: 'Clear',
                onPressed: workspaceKpiSearchController.clear,
                icon: const Icon(
                  Icons.close,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.2,
          ),
        ),
      ),
    ),
  );
}

Widget buildSelectedWorkspaceSection() {
  switch (selectedWorkspaceKpi) {
    case 'members':
      return buildMembersSection();
    case 'running':
      return buildRunningSection();
    case 'pending':
      return buildPendingInvitesSection();
    case 'projects':
    default:
      return buildProjectsSection();
  }
}

Widget buildRunningSection() {
  final runningNames = runningEntries
      .map(
        (entry) =>
            entry['employee_name']?.toString().trim().toLowerCase(),
      )
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toSet();

  final runningMembers = members.where((member) {
    final name =
        member['full_name']?.toString().trim().toLowerCase() ?? '';

    final email =
        member['email']?.toString().trim().toLowerCase() ?? '';

    final role =
        member['role']?.toString().trim().toLowerCase() ?? '';

    final isRunning = runningNames.contains(name);

    if (!isRunning) {
      return false;
    }

    if (workspaceKpiSearch.isEmpty) {
      return true;
    }

    return name.contains(workspaceKpiSearch) ||
        email.contains(workspaceKpiSearch) ||
        role.contains(workspaceKpiSearch);
  }).toList();

  final filteredRunningEntries = runningEntries.where((entry) {
    if (workspaceKpiSearch.isEmpty) {
      return true;
    }

    final name =
        entry['employee_name']?.toString().trim().toLowerCase() ?? '';

    return name.contains(workspaceKpiSearch);
  }).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionHeader(
        title: 'Running Now',
        subtitle: 'Employees currently tracking time in this workspace.',
        count: runningEntries.length,
      ),
      const SizedBox(height: 12),
      if (runningEntries.isEmpty)
        emptySection(
          icon: Icons.play_circle_outline,
          title: 'No active timers',
          subtitle: 'No employee is tracking time right now.',
        )
      else if (runningMembers.isNotEmpty)
        ...runningMembers.map(buildEmployeeCard)
      else if (filteredRunningEntries.isNotEmpty)
        ...filteredRunningEntries.map((entry) {
          final name =
              entry['employee_name']?.toString().trim() ?? 'Employee';

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(.12),
                  foregroundColor: Colors.green,
                  child: const Icon(Icons.play_arrow_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  'TRACKING NOW',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        })
      else
        emptySection(
          icon: Icons.search_off_outlined,
          title: 'No running employees found',
          subtitle: 'Try a different search.',
        ),
    ],
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
          const SizedBox(height: 12),
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
            size: 18,
          ),
          SizedBox(width: 7),
          Text(
            "Team Members",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      if (filteredMembers.isEmpty)
        emptySection(
          icon: Icons.search_off_outlined,
          title: 'No matching members found',
          subtitle: 'Try a different search.',
        )
      else
        ...filteredMembers.map(buildEmployeeCard),
    ],
  );
}

  Widget buildEmployeeCard(
    Map<String, dynamic> employee,
  ) {
    final employeeId =
        employee['id']?.toString() ?? '';

    final name =
        employee['full_name']?.toString().trim() ?? 'Employee';

    final email =
        employee['email']?.toString().trim() ?? '';

    final role =
        employee['role']?.toString().trim() ?? 'employee';

    final employeeProjects =
        getEmployeeProjects(employeeId);

    final weeklyMinutes =
        employeeWeeklyMinutes(name);

    final running = runningEntries.any(
      (entry) =>
          entry['employee_name']?.toString().trim() ==
          name.trim(),
    );

    final isEmployeeAdmin =
        role.toLowerCase() == 'admin';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: Text(
              initials(name),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isEmployeeAdmin
                            ? Colors.orange.shade100
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 13,
                  runSpacing: 3,
                  children: [
                    Text(
                      'Projects: ${employeeProjects.length}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Text(
                      'Week: ${formatDuration(weeklyMinutes)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: running
                                ? AppColors.success
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: running
                                ? null
                                : Border.all(
                                    color: AppColors.textMuted,
                                    width: 1,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          running ? 'Running' : 'Offline',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                showManageEmployeeProjectsDialog(
                  employee,
                );
              },
              icon: const Icon(
                Icons.settings,
                size: 14,
              ),
              label: const Text(
                'Manage',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildPendingInvitesSection() {
    final filteredPendingEmployees =
        pendingEmployees.where((employee) {
      if (workspaceKpiSearch.isEmpty) {
        return true;
      }

      final name =
          employee['full_name']?.toString().trim().toLowerCase() ?? '';

      final email =
          employee['email']?.toString().trim().toLowerCase() ?? '';

      final role =
          employee['role']?.toString().trim().toLowerCase() ?? '';

      return name.contains(workspaceKpiSearch) ||
          email.contains(workspaceKpiSearch) ||
          role.contains(workspaceKpiSearch);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          title: 'Pending Invitations',
          subtitle:
              'Employees waiting to accept their workspace invitation.',
          count: pendingEmployees.length,
        ),
        const SizedBox(height: 9),
        if (pendingEmployees.isEmpty)
          emptySection(
            icon: Icons.mark_email_read_outlined,
            title: 'No pending invitations',
            subtitle: 'There are no pending workspace invitations.',
          )
        else if (filteredPendingEmployees.isEmpty)
          emptySection(
            icon: Icons.search_off_outlined,
            title: 'No pending invitations found',
            subtitle: 'Try a different search.',
          )
        else
          ...filteredPendingEmployees.map((employee) {
            final name =
                employee['full_name']?.toString() ?? 'Employee';
            final email =
                employee['email']?.toString() ?? '';
            final role =
                employee['role']?.toString() ?? 'employee';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: AppColors.primarySurface,
                    foregroundColor: AppColors.primary,
                    child: Text(
                      initials(name),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${role.toUpperCase()} • '
                          '${employee['status']?.toString() ?? 'PENDING'}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    Wrap(
                      spacing: 6,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 31),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: saving
                              ? null
                              : () {
                                  resendWorkspaceInvitation(employee);
                                },
                          icon: const Icon(
                            Icons.refresh_outlined,
                            size: 14,
                          ),
                          label: const Text(
                            'Resend',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(
                              color: AppColors.danger,
                            ),
                            minimumSize: const Size(0, 31),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: saving
                              ? null
                              : () {
                                  cancelWorkspaceInvitation(employee);
                                },
                          icon: const Icon(
                            Icons.cancel_outlined,
                            size: 14,
                          ),
                          label: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget buildProjectsSection() {
    final filteredProjects = projects.where((project) {
      if (workspaceKpiSearch.isEmpty) {
        return true;
      }

      final projectName =
          project['project_name']?.toString().trim().toLowerCase() ?? '';

      return projectName.contains(workspaceKpiSearch);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          title: 'Workspace Projects',
          subtitle:
              'Review project members, ownership and availability.',
          count: projects.length,
        ),
        const SizedBox(height: 12),
        if (projects.isEmpty)
          emptySection(
            icon: Icons.folder_off_outlined,
            title: 'No projects found',
            subtitle:
                'Create projects from Project Management.',
          )
        else if (filteredProjects.isEmpty)
          emptySection(
            icon: Icons.search_off_outlined,
            title: 'No projects found',
            subtitle: 'Try a different project name.',
          )
        else
          ...filteredProjects.map(buildProjectCard),
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

    final runningCount = runningEntries
        .where(
          (e) =>
              e['project_id']?.toString() == projectId,
        )
        .length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primarySurface
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 3,
                      crossAxisAlignment:
                          WrapCrossAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.success.withValues(
                                    alpha: 0.10,
                                  )
                                : AppColors.background,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : 'ARCHIVED',
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.textMuted,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 11,
                      runSpacing: 3,
                      children: [
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
                          '$runningCount running',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                        ),
                        minimumSize: const Size(0, 31),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity:
                            VisualDensity.compact,
                      ),
                      onPressed: () {
                        showManageProjectEmployeesDialog(
                          project,
                        );
                      },
                      icon: const Icon(
                        Icons.group_add_outlined,
                        size: 14,
                      ),
                      label: const Text(
                        'Manage Employees',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isActive
                            ? AppColors.textSecondary
                            : AppColors.success,
                        minimumSize: const Size(0, 31),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        visualDensity:
                            VisualDensity.compact,
                      ),
                      onPressed: () {
                        toggleProjectStatus(project);
                      },
                      icon: Icon(
                        isActive
                            ? Icons.archive_outlined
                            : Icons.unarchive_outlined,
                        size: 14,
                      ),
                      label: Text(
                        isActive ? 'Archive' : 'Activate',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (projectEmployees.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(
              color: AppColors.border,
              height: 1,
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 5,
                children: projectEmployees.map((employee) {
                  final name =
                      employee['full_name']
                              ?.toString()
                              .trim() ??
                          'Employee';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primaryLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor:
                              AppColors.primary,
                          foregroundColor:
                              Colors.white,
                          child: Text(
                            initials(name),
                            style: const TextStyle(
                              fontSize: 6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryLight,
            ),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 12),
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
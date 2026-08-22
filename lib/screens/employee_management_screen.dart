import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState
    extends State<EmployeeManagementScreen> {
  static const primary = Color(0xFFFF6B00);
static const primaryLight = Color(0xFFFF8A33);
static const primarySurface = Color(0xFFFFF3E8);

static const success = Color(0xFF16A34A);
static const warning = Color(0xFFF59E0B);
static const danger = Color(0xFFDC2626);

static const background = Color(0xFFF8F9FC);
static const surface = Colors.white;

static const border = Color(0xFFE7E7E7);

static const textPrimary = Color(0xFF1F2937);
static const textSecondary = Color(0xFF6B7280);
static const textMuted = Color(0xFF9CA3AF);

  bool loading = true;
  bool actionLoading = false;
  String? errorMessage;

  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> pendingApprovals = [];

  final Map<String, int> weeklyMinutes = {};
  final Map<String, int> screenshotsToday = {};

  final searchController = TextEditingController();
  String searchText = '';
  String statusFilter = 'all';

  bool get isAdmin =>
      currentUserRole.trim().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        searchText =
            searchController.text.trim().toLowerCase();
      });
    });

    loadEmployees();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadEmployees() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final profilesResponse = await supabase
          .from('profiles')
          .select(
            'id, full_name, email, role, required_weekly_hours, '
            'approval_status, is_active, created_at',
          )
          .eq('workspace_id', currentWorkspaceId)
          .order('full_name');

      final allProfiles =
          List<Map<String, dynamic>>.from(
        profilesResponse,
      );

      final approved = allProfiles.where((employee) {
        return employee['approval_status']
                ?.toString()
                .toLowerCase() ==
            'approved';
      }).toList();

      final pending = allProfiles.where((employee) {
        return employee['approval_status']
                ?.toString()
                .toLowerCase() ==
            'pending';
      }).toList();

      await _loadStatistics();

      if (!mounted) return;

      setState(() {
        employees = approved;
        pendingApprovals = pending;
        loading = false;
      });
    } catch (error) {
      debugPrint('Employee loading error: $error');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Unable to load employees.';
      });
    }
  }

  Future<void> _loadStatistics() async {
    weeklyMinutes.clear();
    screenshotsToday.clear();

    final now = DateTime.now();

    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(
      Duration(days: now.weekday - 1),
    );

    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    );

    try {
      final entries = await supabase
          .from('time_entries')
          .select('employee_id, duration_minutes')
          .eq('workspace_id', currentWorkspaceId)
          .gte(
            'start_time',
            weekStart.toIso8601String(),
          );

      for (final item in entries) {
        final id =
            item['employee_id']?.toString() ?? '';

        if (id.isEmpty) continue;

        final minutes = int.tryParse(
              item['duration_minutes']?.toString() ??
                  '',
            ) ??
            0;

        weeklyMinutes[id] =
            (weeklyMinutes[id] ?? 0) + minutes;
      }
    } catch (error) {
      debugPrint(
        'Weekly statistics error: $error',
      );
    }

    try {
      final screenshots = await supabase
          .from('screenshots')
          .select('employee_id')
          .eq('workspace_id', currentWorkspaceId)
          .gte(
            'captured_at',
            todayStart.toIso8601String(),
          );

      for (final item in screenshots) {
        final id =
            item['employee_id']?.toString() ?? '';

        if (id.isEmpty) continue;

        screenshotsToday[id] =
            (screenshotsToday[id] ?? 0) + 1;
      }
    } catch (error) {
      debugPrint(
        'Screenshot statistics error: $error',
      );
    }
  }

  List<Map<String, dynamic>> get filteredEmployees {
    return employees.where((employee) {
      final name =
          employee['full_name']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final email =
          employee['email']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final active =
          employee['is_active'] == true;

      final matchesSearch = searchText.isEmpty ||
          name.contains(searchText) ||
          email.contains(searchText);

      final matchesFilter =
          statusFilter == 'all' ||
              (statusFilter == 'active' &&
                  active) ||
              (statusFilter == 'disabled' &&
                  !active);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> showAddEmployeeDialog() async {
    final nameController =
        TextEditingController();

    final emailController =
        TextEditingController();

    final hoursController =
        TextEditingController(text: '45');

    String role = 'employee';
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final name =
                  nameController.text.trim();

              final email = emailController.text
                  .trim()
                  .toLowerCase();

              final hours = int.tryParse(
                hoursController.text.trim(),
              );

              if (name.isEmpty ||
                  email.isEmpty) {
                _message(
                  'Please enter employee name and email.',
                  error: true,
                );
                return;
              }

              if (!_validEmail(email)) {
                _message(
                  'Please enter a valid email address.',
                  error: true,
                );
                return;
              }

              if (hours == null ||
                  hours < 1 ||
                  hours > 168) {
                _message(
                  'Weekly hours must be between 1 and 168.',
                  error: true,
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                final existingProfile =
                    await supabase
                        .from('profiles')
                        .select('id')
                        .eq('email', email)
                        .maybeSingle();

                if (existingProfile != null) {
                  throw Exception(
                    'A profile already exists for this email.',
                  );
                }

                final existingPending =
                    await supabase
                        .from(
                          'pending_employees',
                        )
                        .select('id')
                        .eq(
                          'workspace_id',
                          currentWorkspaceId,
                        )
                        .eq('email', email)
                        .maybeSingle();

                if (existingPending != null) {
                  throw Exception(
                    'This employee is already pending registration.',
                  );
                }

                final response = await supabase.functions.invoke(
  'invite-workspace-member',
  body: {
    'full_name': name,
    'email': email,
    'role': role,
    'workspace_id': currentWorkspaceId,
  },
);

final data = response.data;

if (data is Map && data['error'] != null) {
  throw Exception(data['error'].toString());
}

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext)
                      .pop();
                }

                _message(
                  'Employee added successfully.',
                );

                await loadEmployees();
              } catch (error) {
                _message(
                  _cleanError(error),
                  error: true,
                );

                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: surface,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
              title: const Text(
                'Add Employee',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    _field(
                      controller:
                          nameController,
                      label: 'Full Name',
                      icon:
                          Icons.person_outline,
                      enabled: !saving,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller:
                          emailController,
                      label: 'Email',
                      icon:
                          Icons.email_outlined,
                      enabled: !saving,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<
                        String>(
                      initialValue: role,
                      decoration: _decoration(
                        label: 'Role',
                        icon: Icons
                            .admin_panel_settings_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'employee',
                          child:
                              Text('Employee'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              setDialogState(
                                () {
                                  role = value ??
                                      'employee';
                                },
                              );
                            },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller:
                          hoursController,
                      label:
                          'Required Weekly Hours',
                      icon: Icons.schedule,
                      enabled: !saving,
                      keyboardType:
                          TextInputType.number,
                      suffixText: 'hrs/week',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  child:
                      const Text('Cancel'),
                ),
                FilledButton(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor: primary,
                  ),
                  onPressed:
                      saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Add Employee',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    hoursController.dispose();
  }

  Future<void> approveEmployee(
    Map<String, dynamic> employee,
  ) async {
    await _runAction(
      () async {
        await supabase
            .from('profiles')
            .update({
              'approval_status': 'approved',
              'is_active': true,
            })
            .eq('id', employee['id'])
            .eq(
              'workspace_id',
              currentWorkspaceId,
            );
      },
      'Employee approved.',
    );
  }

  Future<void> rejectEmployee(
    Map<String, dynamic> employee,
  ) async {
    final confirmed = await _confirm(
      title: 'Reject Employee',
      message:
          'Reject ${employee['full_name']}? '
          'The account will be disabled.',
      confirmText: 'Reject',
      color: danger,
    );

    if (!confirmed) return;

    await _runAction(
      () async {
        await supabase
            .from('profiles')
            .update({
              'approval_status': 'rejected',
              'is_active': false,
            })
            .eq('id', employee['id'])
            .eq(
              'workspace_id',
              currentWorkspaceId,
            );
      },
      'Employee rejected.',
    );
  }

  Future<void> toggleStatus(
    Map<String, dynamic> employee,
  ) async {
    final id =
        employee['id']?.toString() ?? '';

    final name =
        employee['full_name']?.toString() ??
            'Employee';

    final active =
        employee['is_active'] == true;

    final newStatus = !active;

    if (id == currentUserId &&
        !newStatus) {
      _message(
        'You cannot disable your own administrator account.',
        error: true,
      );
      return;
    }

    final confirmed = await _confirm(
      title: newStatus
          ? 'Enable Employee'
          : 'Disable Employee',
      message: newStatus
          ? 'Enable $name?'
          : 'Disable $name? Their existing data will remain.',
      confirmText:
          newStatus ? 'Enable' : 'Disable',
      color:
          newStatus ? success : danger,
    );

    if (!confirmed) return;

    await _runAction(
      () async {
        await supabase
            .from('profiles')
            .update({
              'is_active': newStatus,
            })
            .eq('id', id)
            .eq(
              'workspace_id',
              currentWorkspaceId,
            );
      },
      newStatus
          ? '$name was enabled.'
          : '$name was disabled.',
    );
  }

  Future<void> sendPasswordReset(
    Map<String, dynamic> employee,
  ) async {
    final email =
        employee['email']?.toString().trim() ??
            '';

    if (email.isEmpty) {
      _message(
        'Employee email is missing.',
        error: true,
      );
      return;
    }

    final confirmed = await _confirm(
      title: 'Send Password Reset',
      message:
          'Send a password-reset email to:\n\n$email',
      confirmText: 'Send',
      color: primary,
    );

    if (!confirmed) return;

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo:
            'timetracker://reset-password',
      );

      _message(
        'Password-reset email sent.',
      );
    } on AuthException catch (error) {
      _message(
        error.message,
        error: true,
      );
    } catch (error) {
      _message(
        _cleanError(error),
        error: true,
      );
    }
  }

  Future<void> showEditEmployeeDialog(
    Map<String, dynamic> employee,
  ) async {
    final nameController =
        TextEditingController(
      text:
          employee['full_name']?.toString() ??
              '',
    );

    final hoursController =
        TextEditingController(
      text:
          (employee['required_weekly_hours'] ??
                  45)
              .toString(),
    );

    String role =
        employee['role']?.toString() ??
            'employee';

    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final name =
                  nameController.text.trim();

              final hours = int.tryParse(
                hoursController.text.trim(),
              );

              if (name.isEmpty) {
                _message(
                  'Employee name cannot be empty.',
                  error: true,
                );
                return;
              }

              if (hours == null ||
                  hours < 1 ||
                  hours > 168) {
                _message(
                  'Weekly hours must be between 1 and 168.',
                  error: true,
                );
                return;
              }

              if (employee['id']
                          ?.toString() ==
                      currentUserId &&
                  role != 'admin') {
                _message(
                  'You cannot remove your own admin role.',
                  error: true,
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                await supabase
                    .from('profiles')
                    .update({
                      'full_name': name,
                      'role': role,
                      'required_weekly_hours':
                          hours,
                    })
                    .eq(
                      'id',
                      employee['id'],
                    )
                    .eq(
                      'workspace_id',
                      currentWorkspaceId,
                    );

                if (dialogContext.mounted) {
                  Navigator.of(
                    dialogContext,
                  ).pop();
                }

                _message(
                  'Employee updated.',
                );

                await loadEmployees();
              } catch (error) {
                _message(
                  _cleanError(error),
                  error: true,
                );

                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: surface,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
              title: const Text(
                'Edit Employee',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    _field(
                      controller:
                          nameController,
                      label: 'Full Name',
                      icon:
                          Icons.person_outline,
                      enabled: !saving,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue:
                          employee['email']
                                  ?.toString() ??
                              '',
                      enabled: false,
                      decoration: _decoration(
                        label: 'Email',
                        icon:
                            Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<
                        String>(
                      initialValue: role,
                      decoration: _decoration(
                        label: 'Role',
                        icon: Icons
                            .admin_panel_settings_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'employee',
                          child:
                              Text('Employee'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              setDialogState(
                                () {
                                  role = value ??
                                      'employee';
                                },
                              );
                            },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller:
                          hoursController,
                      label:
                          'Required Weekly Hours',
                      icon: Icons.schedule,
                      enabled: !saving,
                      keyboardType:
                          TextInputType.number,
                      suffixText: 'hrs/week',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  child:
                      const Text('Cancel'),
                ),
                FilledButton(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor: primary,
                  ),
                  onPressed:
                      saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    hoursController.dispose();
  }

  Future<void> showEmployeeDetails(
    Map<String, dynamic> employee,
  ) async {
    final id =
        employee['id']?.toString() ?? '';

    final requiredHours = int.tryParse(
          employee['required_weekly_hours']
                  ?.toString() ??
              '',
        ) ??
        45;

    final thisWeek =
        weeklyMinutes[id] ?? 0;

    final requiredMinutes =
        requiredHours * 60;

    final missing =
        requiredMinutes - thisWeek;

    final active =
        employee['is_active'] == true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          title: Text(
            employee['full_name']
                    ?.toString() ??
                'Employee',
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                _detailRow(
                  'Email',
                  employee['email']
                          ?.toString() ??
                      '',
                ),
                _detailRow(
                  'Role',
                  _titleCase(
                    employee['role']
                            ?.toString() ??
                        'employee',
                  ),
                ),
                _detailRow(
                  'Status',
                  active
                      ? 'Active'
                      : 'Disabled',
                ),
                _detailRow(
                  'Required weekly hours',
                  '$requiredHours hrs',
                ),
                _detailRow(
                  'This week',
                  formatHours(thisWeek),
                ),
                _detailRow(
                  'Screenshots today',
                  '${screenshotsToday[id] ?? 0}',
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: missing > 0
                        ? const Color(
                            0xFFFFFBEB,
                          )
                        : const Color(
                            0xFFF0FDF4,
                          ),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Text(
                    missing > 0
                        ? 'Below target by ${formatHours(missing)}'
                        : 'Weekly target reached',
                    style: TextStyle(
                      color: missing > 0
                          ? warning
                          : success,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (actionLoading) return;

    setState(() {
      actionLoading = true;
    });

    try {
      await action();

      _message(successMessage);

      await loadEmployees();
    } catch (error) {
      _message(
        _cleanError(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    required Color color,
  }) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor: color,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return value == true;
  }

  Widget _employeeCard(
    Map<String, dynamic> employee,
  ) {
    final id =
        employee['id']?.toString() ?? '';

    final role =
        employee['role']?.toString() ??
            'employee';

    final active =
        employee['is_active'] == true;

    final requiredHours = int.tryParse(
          employee['required_weekly_hours']
                  ?.toString() ??
              '',
        ) ??
        45;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: border,
        ),
       boxShadow: const [
  BoxShadow(
    color: Color(0x12000000),
    blurRadius: 24,
    spreadRadius: 0,
    offset: Offset(0, 10),
  ),
],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: role == 'admin'
                ? const Color(
                    0xFF7C3AED,
                  )
                : active
                    ? primary
                    : Colors.grey,
            child: Icon(
              role == 'admin'
                  ? Icons
                      .admin_panel_settings
                  : Icons.person,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        employee['full_name']
                                ?.toString() ??
                            'Employee',
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: textPrimary,
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _badge(
                      active
                          ? 'Active'
                          : 'Disabled',
                      active
                          ? const Color(0xFF16A34A)
                          : danger,
                    ),
                    const SizedBox(width: 6),
                    _badge(
                      _titleCase(role),
                      role == 'admin'
                          ? const Color(
                              0xFF7C3AED,
                            )
                          :primary,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  employee['email']
                          ?.toString() ??
                      '',
                  style: const TextStyle(
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _metric(
                  Icons.timelapse,
                  'This week: ${formatHours(weeklyMinutes[id] ?? 0)}',
                  primary,
                ),
                _metric(
                  Icons.schedule,
                  'Required: $requiredHours hrs',
                  textSecondary,
                ),
                _metric(
                  Icons.photo_camera_outlined,
                  'Screenshots today: ${screenshotsToday[id] ?? 0}',
                  textSecondary,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Employee actions',
            color: Colors.white,
            onSelected: (value) {
              switch (value) {
                case 'details':
                  showEmployeeDetails(
                    employee,
                  );
                  break;

                case 'edit':
                  showEditEmployeeDialog(
                    employee,
                  );
                  break;

                case 'reset':
                  sendPasswordReset(
                    employee,
                  );
                  break;

                case 'status':
                  toggleStatus(employee);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'details',
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: primary,
                  ),
                  title:
                      Text('View details'),
                  contentPadding:
                      EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    color: Color(
                      0xFF4F46E5,
                    ),
                  ),
                  title:
                      Text('Edit employee'),
                  contentPadding:
                      EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(
                    Icons.lock_reset,
                    color: warning,
                  ),
                  title: Text(
                    'Send password reset',
                  ),
                  contentPadding:
                      EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'status',
                child: ListTile(
                  leading: Icon(
                    active
                        ? Icons
                            .person_off_outlined
                        : Icons
                            .person_add_alt,
                    color: active
                        ? danger
                        : success,
                  ),
                  title: Text(
                    active
                        ? 'Disable employee'
                        : 'Enable employee',
                  ),
                  contentPadding:
                      EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _employeeWorkChart(
  List<Map<String, dynamic>> visibleEmployees,
) {
  final chartEmployees = visibleEmployees.where((employee) {
    final id = employee['id']?.toString() ?? '';

    return (weeklyMinutes[id] ?? 0) > 0;
  }).toList();

  final totalMinutes = chartEmployees.fold<int>(
    0,
    (total, employee) {
      final id = employee['id']?.toString() ?? '';

      return total + (weeklyMinutes[id] ?? 0);
    },
  );

  const chartColors = <Color>[
    Color(0xFF5B6CC1),
    Color(0xFF9B7B6E),
    Color(0xFF2878C8),
    Color(0xFF67A437),
    Color(0xFFFF5622),
    Color(0xFFF0A72E),
    Color(0xFF8B5CF6),
    Color(0xFF0F9D8A),
  ];

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 25),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: const Text(
            'Employee Work Distribution — This Week',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (chartEmployees.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 42,
            ),
            child: Center(
              child: Text(
                'No employee time entries found for this week.',
                style: TextStyle(
                  color: textSecondary,
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 850;

              final legend = _employeeChartLegend(
                chartEmployees,
                chartColors,
                totalMinutes,
              );

              final chart = SizedBox(
                width: compact ? 320 : 430,
                height: 390,
                child: Center(
                  child: SizedBox(
                    width: 285,
                    height: 285,
                    child: CustomPaint(
                      painter: _EmployeeDonutPainter(
                        values: chartEmployees.map((employee) {
                          final id =
                              employee['id']?.toString() ?? '';

                          return weeklyMinutes[id] ?? 0;
                        }).toList(),
                        colors: chartColors,
                        holeFraction: 0.50,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatClockDuration(
                                totalMinutes,
                              ),
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Total',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              if (compact) {
                return Column(
                  children: [
                    chart,
                    const Divider(height: 1),
                    legend,
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: legend,
                    ),
                    const VerticalDivider(width: 1),
                    chart,
                  ],
                ),
              );
            },
          ),
      ],
    ),
  );
}

Widget _employeeChartLegend(
  List<Map<String, dynamic>> chartEmployees,
  List<Color> colors,
  int totalMinutes,
) {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'EMPLOYEE',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              'DURATION',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        ...List.generate(
          chartEmployees.length,
          (index) {
            final employee = chartEmployees[index];

            final id =
                employee['id']?.toString() ?? '';

            final minutes =
                weeklyMinutes[id] ?? 0;

            final percentage = totalMinutes == 0
                ? 0.0
                : (minutes / totalMinutes) * 100;

            return Container(
              padding: const EdgeInsets.symmetric(
                vertical: 13,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color:
                          colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee['full_name']
                                  ?.toString() ??
                              'Employee',
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${percentage.toStringAsFixed(1)}% of total',
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _formatClockDuration(minutes),
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

String _formatClockDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${mins.toString().padLeft(2, '0')}:00';
}

  Widget _pendingCard(
    Map<String, dynamic> employee,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 12),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: warning,
            child: Icon(
              Icons.hourglass_top,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  employee['full_name']
                          ?.toString() ??
                      'Employee',
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                Text(
                  employee['email']
                          ?.toString() ??
                      '',
                  style: const TextStyle(
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style:
                OutlinedButton.styleFrom(
              foregroundColor: danger,
            ),
            onPressed: actionLoading
                ? null
                : () {
                    rejectEmployee(
                      employee,
                    );
                  },
            child:
                const Text('Reject'),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style:
                FilledButton.styleFrom(
              backgroundColor: primary,
            ),
            onPressed: actionLoading
                ? null
                : () {
                    approveEmployee(
                      employee,
                    );
                  },
            child:
                const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Widget _badge(
    String text,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.11),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _metric(
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: textSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: textPrimary,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController
        controller,
    required String label,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: _decoration(
        label: label,
        icon: icon,
        suffixText: suffixText,
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      suffixText: suffixText,
      prefixIcon: Icon(
        icon,
        color: primary,
      ),
      filled: true,
      fillColor: Colors.white,
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: border,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: primary,
          width: 1.7,
        ),
      ),
      disabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: border,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
      ),
    );
  }

  String formatHours(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours == 0) {
      return '$mins min';
    }

    if (mins == 0) {
      return '$hours hr';
    }

    return '$hours hr $mins min';
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;

    return '${value[0].toUpperCase()}'
        '${value.substring(1).toLowerCase()}';
  }

  bool _validEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  String _cleanError(Object error) {
    final value = error.toString();

    return value.startsWith(
      'Exception: ',
    )
        ? value.substring(
            'Exception: '.length,
          )
        : value;
  }

  void _message(
    String text, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor:
              error ? danger : success,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(
          child: Text(
            'Administrator access is required.',
            style: TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final visible =
        filteredEmployees;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor:
            Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Employee Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                loading ? null : loadEmployees,
            icon:
                const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Add Employee',
            onPressed: actionLoading
                ? null
                : showAddEmployeeDialog,
            icon: const Icon(
              Icons.person_add,
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor: primary,
        foregroundColor:
            Colors.white,
        onPressed: actionLoading
            ? null
            : showAddEmployeeDialog,
        icon: const Icon(
          Icons.person_add,
        ),
        label: const Text(
          'Add Employee',
        ),
      ),
      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primary,
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      30,
                    ),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .cloud_off_outlined,
                          color: danger,
                          size: 54,
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        Text(
                          errorMessage!,
                          style:
                              const TextStyle(
                            color:
                                textSecondary,
                          ),
                        ),
                        const SizedBox(
                          height: 18,
                        ),
                        FilledButton.icon(
                          style: FilledButton
                              .styleFrom(
                            backgroundColor:
                                primary,
                          ),
                          onPressed:
                              loadEmployees,
                          icon: const Icon(
                            Icons.refresh,
                          ),
                          label: const Text(
                            'Try Again',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: primary,
                  onRefresh: loadEmployees,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      100,
                    ),
                    children: [
                      TextField(
                        controller:
                            searchController,
                        decoration:
                            InputDecoration(
                          hintText:
                              'Search by employee name or email',
                          prefixIcon:
                              const Icon(
                            Icons.search,
                          ),
                          suffixIcon:
                              searchText.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed:
                                          () {
                                        searchController
                                            .clear();
                                      },
                                      icon:
                                          const Icon(
                                        Icons
                                            .close,
                                      ),
                                    ),
                          filled: true,
                          fillColor:
                              Colors.white,
                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  border,
                            ),
                          ),
                          focusedBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  primary,
                              width: 1.7,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      Align(
                        alignment:
                            Alignment.centerLeft,
                        child:
                            SegmentedButton<
                                String>(
                          segments: const [
                            ButtonSegment(
                              value: 'all',
                              label:
                                  Text('All'),
                              icon: Icon(
                                Icons
                                    .people_outline,
                              ),
                            ),
                            ButtonSegment(
                              value: 'active',
                              label:
                                  Text('Active'),
                              icon: Icon(
                                Icons
                                    .check_circle_outline,
                              ),
                            ),
                            ButtonSegment(
                              value:
                                  'disabled',
                              label: Text(
                                'Disabled',
                              ),
                              icon: Icon(
                                Icons.block,
                              ),
                            ),
                          ],
                          selected: {
                            statusFilter,
                          },
                          onSelectionChanged:
                              (selection) {
                            setState(() {
                              statusFilter =
                                  selection.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(
                        height: 25,
                      ),
                      if (pendingApprovals
                          .isNotEmpty) ...[
                        const Text(
                          'Pending Approval',
                          style:
                              TextStyle(
                            color:
                                textPrimary,
                            fontSize: 20,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        ...pendingApprovals
                            .map(
                          _pendingCard,
                        ),
                        const SizedBox(
                          height: 25,
                        ),
                      ],
                      _employeeWorkChart(visible),

const SizedBox(height: 24),
                      Text(
                        'Employees (${visible.length})',
                        style:
                            const TextStyle(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      if (visible.isEmpty)
                        const Padding(
                          padding:
                              EdgeInsets
                                  .symmetric(
                            vertical: 35,
                          ),
                          child: Center(
                            child: Text(
                              'No employees match the current search or filter.',
                              style:
                                  TextStyle(
                                color:
                                    textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        ...visible.map(
                          _employeeCard,
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _EmployeeDonutPainter extends CustomPainter {
  const _EmployeeDonutPainter({
    required this.values,
    required this.colors,
    this.holeFraction = 0.5,
  });

  final List<int> values;
  final List<Color> colors;
  final double holeFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    if (total <= 0) return;

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * (1 - holeFraction);
    final arcRadius = radius - (strokeWidth / 2);

    final rect = Rect.fromCircle(
      center: center,
      radius: arcRadius,
    );

    var startAngle = -math.pi / 2;
    const gap = 0.012;

    for (var index = 0; index < values.length; index++) {
      final value = values[index];

      if (value <= 0) continue;

      final sweep = (value / total) * math.pi * 2;

      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      final adjustedSweep = math.max(0.0, sweep - gap);

      canvas.drawArc(
        rect,
        startAngle + (gap / 2),
        adjustedSweep,
        false,
        paint,
      );

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(
    covariant _EmployeeDonutPainter oldDelegate,
  ) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.holeFraction != holeFraction;
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'master_admin_sidebar.dart';
import 'master_admin_dashboard.dart';
import 'master_admin_workspaces.dart';
import 'master_admin_users.dart';
import 'master_admin_subscriptions.dart';
import 'master_admin_reports.dart';
import 'master_admin_settings.dart';
import 'master_admin_finance.dart';

class MasterAdminWorkspaceDetails extends StatefulWidget {
  final Map<String, dynamic> workspace;

  const MasterAdminWorkspaceDetails({
    super.key,
    required this.workspace,
  });

  @override
  State<MasterAdminWorkspaceDetails> createState() =>
      _MasterAdminWorkspaceDetailsState();
}

class _MasterAdminWorkspaceDetailsState
    extends State<MasterAdminWorkspaceDetails> {
  final supabase = Supabase.instance.client;

  static const Color orange = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  bool loading = true;
  bool actionLoading = false;
  String? errorMessage;

  Map<String, dynamic> workspace = {};
  List<Map<String, dynamic>> members = [];

  String searchQuery = '';
  final TextEditingController searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    loadWorkspaceDetails();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadWorkspaceDetails() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final workspaceId =
          widget.workspace['id']?.toString() ?? '';

      final workspaceRow = await supabase
          .from('workspaces')
          .select(
            'id, workspace_name, subscription_status, '
            'trial_ends_at, current_period_end, is_active',
          )
          .eq('id', workspaceId)
          .maybeSingle();

      if (workspaceRow == null) {
        throw Exception('Workspace could not be found.');
      }

      final rows = await supabase
          .from('profiles')
          .select(
            'id, full_name, email, role, '
            'is_active, approval_status, workspace_id',
          )
          .eq('workspace_id', workspaceId);

      final profileList =
          List<Map<String, dynamic>>.from(rows);

      profileList.sort((a, b) {
        final aRole =
            a['role']?.toString().toLowerCase() ?? '';

        final bRole =
            b['role']?.toString().toLowerCase() ?? '';

        if (aRole == 'admin' && bRole != 'admin') {
          return -1;
        }

        if (bRole == 'admin' && aRole != 'admin') {
          return 1;
        }

        final aName =
            a['full_name']?.toString() ?? '';

        final bName =
            b['full_name']?.toString() ?? '';

        return aName
            .toLowerCase()
            .compareTo(bName.toLowerCase());
      });

      if (!mounted) return;

      setState(() {
        workspace =
            Map<String, dynamic>.from(workspaceRow);
        members = profileList;
        loading = false;
      });
    } catch (error) {
      debugPrint(
        'MASTER WORKSPACE DETAILS ERROR: $error',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = error.toString();
      });
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(
      value.toString(),
    );

    if (date == null) return '-';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  Future<void> showExtendTrialDialog() async {
    final days = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Extend Trial'),
          content: const Text(
            'How many days would you like to add?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, 7);
              },
              child: const Text('+7 Days'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, 14);
              },
              child: const Text('+14 Days'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, 30);
              },
              child: const Text('+30 Days'),
            ),
          ],
        );
      },
    );

    if (days != null) {
      await extendTrial(days);
    }
  }

  Future<void> extendTrial(int days) async {
    if (actionLoading) return;

    setState(() {
      actionLoading = true;
    });

    try {
      final workspaceId =
          workspace['id']?.toString() ?? '';

      final now = DateTime.now().toUtc();

      final existingText =
          workspace['trial_ends_at']?.toString();

      final existing =
          existingText == null
              ? null
              : DateTime.tryParse(existingText)?.toUtc();

      final baseDate =
          existing != null && existing.isAfter(now)
              ? existing
              : now;

      final newTrialEnd =
          baseDate.add(Duration(days: days));

      final currentStatus =
          workspace['subscription_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final updateData = <String, dynamic>{
        'trial_ends_at':
            newTrialEnd.toIso8601String(),
      };

      if (currentStatus != 'active') {
        updateData['subscription_status'] =
            'trialing';
      }

      await supabase
          .from('workspaces')
          .update(updateData)
          .eq('id', workspaceId);

      await loadWorkspaceDetails();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trial extended by $days days.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to extend trial: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> toggleWorkspaceAccess() async {
    if (actionLoading) return;

    final currentlyActive =
        workspace['is_active'] != false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            currentlyActive
                ? 'Disable Workspace?'
                : 'Enable Workspace?',
          ),
          content: Text(
            currentlyActive
                ? 'Users in this workspace will no longer be allowed to access ClockMetric.'
                : 'Users in this workspace will be allowed to access ClockMetric again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: Text(
                currentlyActive
                    ? 'Disable'
                    : 'Enable',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      actionLoading = true;
    });

    try {
      final workspaceId =
          workspace['id']?.toString() ?? '';

      await supabase
          .from('workspaces')
          .update({
            'is_active': !currentlyActive,
          })
          .eq('id', workspaceId);

      await loadWorkspaceDetails();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyActive
                ? 'Workspace disabled.'
                : 'Workspace enabled.',
          ),
          backgroundColor:
              currentlyActive
                  ? Colors.orange
                  : Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update workspace: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceName =
        workspace['workspace_name']
                ?.toString() ??
            widget.workspace['workspace_name']
                ?.toString() ??
            'Workspace';

    return Scaffold(
      backgroundColor: background,
      body: Row(
        children: [
          MasterAdminSidebar(
            currentPage: 'workspaces',
            onDashboard: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MasterAdminDashboard(),
                ),
              );
            },
            onWorkspaces: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MasterAdminWorkspaces(),
                ),
              );
            },
            onUsers: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MasterAdminUsers(),
                ),
              );
            },
            onSubscriptions: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MasterAdminSubscriptions(),
                ),
              );
            },
            onFinance: () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const MasterAdminFinance(),
    ),
  );
},
            onReports: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MasterAdminReports(),
                ),
              );
            },
            onSettings: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MasterAdminSettings(),
                ),
              );
            },
            onLogout: () async {
              await supabase.auth.signOut();

              if (!context.mounted) return;

              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            },
          ),
          Expanded(
            child: loading
                ? const Center(
                    child:
                        CircularProgressIndicator(
                      color: orange,
                    ),
                  )
                : errorMessage != null
                    ? _buildError()
                    : _buildContent(
                        workspaceName,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String workspaceName) {
    final subscriptionStatus =
        workspace['subscription_status']
                ?.toString() ??
            'unknown';

    final trialEnds = formatDate(
      workspace['trial_ends_at'],
    );

    final currentPeriodEnd = formatDate(
      workspace['current_period_end'],
    );

    final workspaceActive =
        workspace['is_active'] != false;

    final admins = members.where((member) {
      return member['role']
              ?.toString()
              .toLowerCase() ==
          'admin';
    }).toList();

    final employees = members.where((member) {
      return member['role']
              ?.toString()
              .toLowerCase() ==
          'employee';
    }).toList();

    final activeEmployees =
        employees.where((employee) {
      return employee['is_active'] == true;
    }).length;

    final query =
        searchQuery.trim().toLowerCase();

    final filteredMembers =
        members.where((member) {
      if (query.isEmpty) return true;

      final name =
          member['full_name']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final email =
          member['email']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final role =
          member['role']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final approval =
          member['approval_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final status =
          member['is_active'] == true
              ? 'active enabled'
              : 'disabled inactive';

      return name.contains(query) ||
          email.contains(query) ||
          role.contains(query) ||
          approval.contains(query) ||
          status.contains(query);
    }).toList();

    return RefreshIndicator(
      color: orange,
      onRefresh: loadWorkspaceDetails,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment:
                  WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 560,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspaceName,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight:
                              FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Workspace details and member overview.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: actionLoading
                        ? null
                        : showExtendTrialDialog,
                    icon: const Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Extend Trial',
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          workspaceActive
                              ? Colors.red
                              : Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: actionLoading
                        ? null
                        : toggleWorkspaceAccess,
                    icon: Icon(
                      workspaceActive
                          ? Icons.block_rounded
                          : Icons
                              .check_circle_rounded,
                      size: 16,
                    ),
                    label: Text(
                      workspaceActive
                          ? 'Disable Workspace'
                          : 'Enable Workspace',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _searchBox(),

            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  title: 'Admins',
                  value: admins.length.toString(),
                  icon:
                      Icons.admin_panel_settings_rounded,
                ),
                _summaryCard(
                  title: 'Employees',
                  value:
                      employees.length.toString(),
                  icon:
                      Icons.people_alt_rounded,
                ),
                _summaryCard(
                  title: 'Active Employees',
                  value:
                      activeEmployees.toString(),
                  icon:
                      Icons.check_circle_rounded,
                ),
                _summaryCard(
                  title: 'Subscription',
                  value:
                      subscriptionStatus.toUpperCase(),
                  icon:
                      Icons.credit_card_rounded,
                ),
              ],
            ),

            const SizedBox(height: 18),

            _buildWorkspaceInfo(
              subscriptionStatus,
              trialEnds,
              currentPeriodEnd,
              workspaceActive,
            ),

            const SizedBox(height: 18),

            _buildMembersTable(
              filteredMembers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox() {
    return SizedBox(
      width: 420,
      height: 46,
      child: TextField(
        controller: searchController,
        style: const TextStyle(
          fontSize: 12,
          color: textDark,
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText:
              'Search member, email, role, approval or status...',
          hintStyle: const TextStyle(
            fontSize: 12,
            color: textGrey,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: orange,
            size: 19,
          ),
          prefixIconConstraints:
              const BoxConstraints(
            minWidth: 40,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  padding: EdgeInsets.zero,
                  visualDensity:
                      VisualDensity.compact,
                  onPressed: () {
                    searchController.clear();

                    setState(() {
                      searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: textGrey,
                    size: 18,
                  ),
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: border,
            ),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: border,
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: orange,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceInfo(
    String status,
    String trialEnds,
    String currentPeriodEnd,
    bool workspaceActive,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Workspace Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 26,
            runSpacing: 14,
            children: [
              _infoItem(
                'Workspace Access',
                workspaceActive
                    ? 'ENABLED'
                    : 'DISABLED',
              ),
              _infoItem(
                'Subscription Status',
                status.toUpperCase(),
              ),
              _infoItem(
                'Trial Ends',
                trialEnds,
              ),
              _infoItem(
                'Current Period End',
                currentPeriodEnd,
              ),
              _infoItem(
                'Workspace ID',
                workspace['id']
                        ?.toString() ??
                    '-',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(
    String label,
    String value,
  ) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: textGrey,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: textDark,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTable(
    List<Map<String, dynamic>> visibleMembers,
  ) {
    const headerStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.bold,
      color: textGrey,
    );

    const cellStyle = TextStyle(
      fontSize: 12,
      color: textDark,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            child: Text(
              'Workspace Members',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),
          const Divider(
            height: 1,
            color: border,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 11,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Name',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Email',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Role',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Approval',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: headerStyle,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            color: border,
          ),

          if (visibleMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(26),
              child: Center(
                child: Text(
                  searchQuery.isEmpty
                      ? 'No members found.'
                      : 'No matching members found.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: textGrey,
                  ),
                ),
              ),
            ),

          ...visibleMembers.map(
            (member) {
              final name =
                  member['full_name']
                          ?.toString() ??
                      '-';

              final email =
                  member['email']
                          ?.toString() ??
                      '-';

              final role =
                  member['role']
                          ?.toString() ??
                      '-';

              final approval =
                  member['approval_status']
                          ?.toString() ??
                      '-';

              final active =
                  member['is_active'] == true;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: border,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        email,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: textGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child:
                          _roleBadge(role),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        approval.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight:
                              FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(
                            active
                                ? Icons
                                    .check_circle_rounded
                                : Icons
                                    .cancel_rounded,
                            size: 16,
                            color: active
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            active
                                ? 'Active'
                                : 'Disabled',
                            style: cellStyle,
                          ),
                        ],
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

  Widget _roleBadge(String role) {
    final isAdmin =
        role.toLowerCase() == 'admin';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isAdmin
              ? const Color(0xFFFFEDD5)
              : const Color(0xFFEFF6FF),
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Text(
          role.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isAdmin
                ? orange
                : const Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 185,
      height: 84,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFFFEDD5),
              borderRadius:
                  BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: orange,
              size: 19,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.05,
                    color: textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Colors.red,
          ),
          const SizedBox(height: 10),
          const Text(
            'Unable to load workspace details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            errorMessage ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: textGrey,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: loadWorkspaceDetails,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 17,
            ),
            label: const Text(
              'Try Again',
              style: TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

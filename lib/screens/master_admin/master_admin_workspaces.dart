import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'master_admin_dashboard.dart';
import 'master_admin_workspace_details.dart';
import 'master_admin_users.dart';
import 'master_admin_subscriptions.dart';
import 'master_admin_reports.dart';
import 'master_admin_settings.dart';
import 'master_admin_sidebar.dart';
import 'master_admin_finance.dart';

class MasterAdminWorkspaces extends StatefulWidget {
  const MasterAdminWorkspaces({super.key});

  @override
  State<MasterAdminWorkspaces> createState() =>
      _MasterAdminWorkspacesState();
}

class _MasterAdminWorkspacesState
    extends State<MasterAdminWorkspaces> {
  final supabase = Supabase.instance.client;

  static const Color orange = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  bool loading = true;
  String? errorMessage;

  List<Map<String, dynamic>> workspaces = [];

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadWorkspaces();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  Future<void> loadWorkspaces() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final workspaceRows = await supabase
          .from('workspaces')
          .select(
            'id, workspace_name, subscription_status, '
            'trial_ends_at, current_period_end, is_active',
          );

      final profileRows = await supabase
          .from('profiles')
          .select(
            'id, full_name, email, role, workspace_id, is_active',
          );

      final workspaceList =
          List<Map<String, dynamic>>.from(workspaceRows);

      final profiles =
          List<Map<String, dynamic>>.from(profileRows);

      final List<Map<String, dynamic>> prepared = [];

      for (final workspace in workspaceList) {
        final workspaceId =
            workspace['id']?.toString() ?? '';

        final members = profiles.where((profile) {
          return profile['workspace_id']?.toString() ==
              workspaceId;
        }).toList();

        final admins = members.where((profile) {
          return profile['role']
                  ?.toString()
                  .toLowerCase() ==
              'admin';
        }).toList();

        final employees = members.where((profile) {
          return profile['role']
                  ?.toString()
                  .toLowerCase() ==
              'employee';
        }).toList();

        final activeEmployees =
            employees.where((profile) {
          return profile['is_active'] == true;
        }).toList();

        final admin =
            admins.isNotEmpty
                ? admins.first
                : null;

        prepared.add({
          ...workspace,
          'admin_name':
              admin?['full_name']?.toString() ?? '',
          'admin_email':
              admin?['email']?.toString() ?? '',
          'employee_count': employees.length,
          'active_employee_count':
              activeEmployees.length,
        });
      }

      prepared.sort((a, b) {
        final aName =
            a['workspace_name']?.toString() ?? '';

        final bName =
            b['workspace_name']?.toString() ?? '';

        return aName
            .toLowerCase()
            .compareTo(
              bName.toLowerCase(),
            );
      });

      if (!mounted) return;

      setState(() {
        workspaces = prepared;
        loading = false;
      });
    } catch (error) {
      debugPrint(
        'MASTER ADMIN WORKSPACES ERROR: $error',
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

    final date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) return '-';

    final localDate =
        date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();

    final filteredWorkspaces = workspaces.where((workspace) {
      if (query.isEmpty) return true;

      final workspaceName =
          workspace['workspace_name']?.toString().toLowerCase() ?? '';

      final adminName =
          workspace['admin_name']?.toString().toLowerCase() ?? '';

      final adminEmail =
          workspace['admin_email']?.toString().toLowerCase() ?? '';

      final subscription =
          workspace['subscription_status']?.toString().toLowerCase() ?? '';

      final workspaceActive = workspace['is_active'] != false
          ? 'active enabled'
          : 'disabled inactive';

      return workspaceName.contains(query) ||
          adminName.contains(query) ||
          adminEmail.contains(query) ||
          subscription.contains(query) ||
          workspaceActive.contains(query);
    }).toList();

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
            onWorkspaces: () {},
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
            onLogout: logout,
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: orange,
                    ),
                  )
                : errorMessage != null
                    ? _buildError()
                    : _buildContent(filteredWorkspaces),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<Map<String, dynamic>> filteredWorkspaces,
  ) {
    return RefreshIndicator(
      color: orange,
      onRefresh: loadWorkspaces,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Workspaces',
              style: TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
                color: textDark,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'View and manage all ClockMetric companies.',
              style: TextStyle(
                fontSize: 13,
                color: textGrey,
              ),
            ),

            const SizedBox(height: 16),

            _searchBox(),

            const SizedBox(height: 14),

            _summaryCard(
              'Total Workspaces',
              workspaces.length.toString(),
              Icons.business_rounded,
            ),

            const SizedBox(height: 18),

            _buildWorkspaceTable(
              filteredWorkspaces,
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox() {
    return SizedBox(
      width: 420,
      child: TextField(
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
              'Search workspace, admin, email, subscription or status...',
          hintStyle: const TextStyle(
            fontSize: 12,
            color: textGrey,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: orange,
            size: 19,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    setState(() {
                      searchQuery = '';
                    });
                  },
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
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
            borderSide:
                const BorderSide(
              color: border,
            ),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(11),
            borderSide:
                const BorderSide(
              color: border,
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(11),
            borderSide:
                const BorderSide(
              color: orange,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      width: 185,
      height: 84,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(9),
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildWorkspaceTable(
    List<Map<String, dynamic>> visibleWorkspaces,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
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
                    'Workspace',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Admin',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Employees',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Active',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Subscription',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Trial Ends',
                    style: headerStyle,
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: Text(
                    'Action',
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

          if (visibleWorkspaces.isEmpty)
            Padding(
              padding: const EdgeInsets.all(26),
              child: Text(
                searchQuery.isEmpty
                    ? 'No workspaces found.'
                    : 'No matching workspaces found.',
                style: const TextStyle(
                  fontSize: 12,
                  color: textGrey,
                ),
              ),
            ),

          ...visibleWorkspaces.map(
            (workspace) {
              final name =
                  workspace['workspace_name']
                          ?.toString() ??
                      'Unnamed Workspace';

              final adminName =
                  workspace['admin_name']
                          ?.toString() ??
                      '';

              final adminEmail =
                  workspace['admin_email']
                          ?.toString() ??
                      '';

              final employeeCount =
                  workspace['employee_count'] ?? 0;

              final activeCount =
                  workspace['active_employee_count'] ?? 0;

              final subscriptionStatus =
                  workspace['subscription_status']
                          ?.toString() ??
                      'unknown';

              final trialEnd =
                  formatDate(workspace['trial_ends_at']);

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
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adminName.isEmpty
                                ? 'No admin'
                                : adminName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                          if (adminEmail.isNotEmpty)
                            Text(
                              adminEmail,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: textGrey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        employeeCount.toString(),
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        activeCount.toString(),
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _statusBadge(
                        subscriptionStatus,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        trialEnd,
                        style: cellStyle,
                      ),
                    ),
                    SizedBox(
                      width: 82,
                      height: 32,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MasterAdminWorkspaceDetails(
                                workspace: workspace,
                              ),
                            ),
                          );
                        },
                        child: const Text('Open'),
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

  Widget _statusBadge(
    String status,
  ) {
    final value =
        status.toLowerCase();

    Color badgeBackground;
    Color badgeText;

    if (value == 'active') {
      badgeBackground =
          const Color(0xFFDCFCE7);
      badgeText =
          const Color(0xFF15803D);
    } else if (value == 'trialing') {
      badgeBackground =
          const Color(0xFFFEF3C7);
      badgeText =
          const Color(0xFFB45309);
    } else if (value == 'cancelled') {
      badgeBackground =
          const Color(0xFFFEE2E2);
      badgeText =
          const Color(0xFFB91C1C);
    } else {
      badgeBackground =
          const Color(0xFFF3F4F6);
      badgeText = textGrey;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: badgeBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: badgeText,
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Colors.red,
          ),
          const SizedBox(height: 10),
          const Text(
            'Unable to load workspaces',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            errorMessage ?? '',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 12,
              color: textGrey,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed:
                loadWorkspaces,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 17,
            ),
            label:
                const Text(
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
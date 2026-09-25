import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'master_admin_dashboard.dart';
import 'master_admin_workspaces.dart';
import 'master_admin_subscriptions.dart';
import 'master_admin_reports.dart';
import 'master_admin_settings.dart';
import 'master_admin_sidebar.dart';
import 'master_admin_finance.dart';

class MasterAdminUsers extends StatefulWidget {
  const MasterAdminUsers({super.key});

  @override
  State<MasterAdminUsers> createState() =>
      _MasterAdminUsersState();
}

class _MasterAdminUsersState
    extends State<MasterAdminUsers> {
  final supabase = Supabase.instance.client;

  static const Color orange = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  bool loading = true;
  String? errorMessage;

  List<Map<String, dynamic>> users = [];
  List<String> workspaceOptions = [];

  String searchQuery = '';
  String selectedWorkspace = 'All Workspaces';

  final TextEditingController searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final profileRows = await supabase
          .from('profiles')
          .select(
            'id, full_name, email, role, workspace_id, '
            'approval_status, is_active, created_at',
          );

      final workspaceRows = await supabase
          .from('workspaces')
          .select(
            'id, workspace_name, is_active',
          );

      final profiles =
          List<Map<String, dynamic>>.from(profileRows);

      final workspaces =
          List<Map<String, dynamic>>.from(workspaceRows);

      final Map<String, Map<String, dynamic>>
          workspaceMap = {};

      final List<String> names = [];

      for (final workspace in workspaces) {
        final id =
            workspace['id']?.toString() ?? '';

        final name =
            workspace['workspace_name']
                    ?.toString() ??
                'Unnamed Workspace';

        if (id.isNotEmpty) {
          workspaceMap[id] = workspace;

          if (!names.contains(name)) {
            names.add(name);
          }
        }
      }

      names.sort(
        (a, b) => a
            .toLowerCase()
            .compareTo(b.toLowerCase()),
      );

      final List<Map<String, dynamic>> prepared = [];

      for (final profile in profiles) {
        final workspaceId =
            profile['workspace_id']?.toString() ?? '';

        final role =
            profile['role']
                    ?.toString()
                    .toLowerCase() ??
                '';

        String workspaceName = '-';
        bool workspaceActive = true;

        if (role == 'master_admin') {
          workspaceName = 'Platform';
          workspaceActive = true;
        } else if (workspaceId.isNotEmpty) {
          final matchingWorkspace =
              workspaceMap[workspaceId];

          workspaceName =
              matchingWorkspace?['workspace_name']
                      ?.toString() ??
                  'Unknown Workspace';

          workspaceActive =
              matchingWorkspace?['is_active'] != false;
        }

        prepared.add({
          ...profile,
          'workspace_name': workspaceName,
          'workspace_is_active':
              workspaceActive,
        });
      }

      prepared.sort((a, b) {
        final aRole =
            a['role']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final bRole =
            b['role']
                    ?.toString()
                    .toLowerCase() ??
                '';

        if (aRole == 'master_admin' &&
            bRole != 'master_admin') {
          return -1;
        }

        if (bRole == 'master_admin' &&
            aRole != 'master_admin') {
          return 1;
        }

        if (aRole == 'admin' &&
            bRole == 'employee') {
          return -1;
        }

        if (bRole == 'admin' &&
            aRole == 'employee') {
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
        users = prepared;

        workspaceOptions = [
          'All Workspaces',
          ...names,
          'Platform',
        ];

        if (!workspaceOptions
            .contains(selectedWorkspace)) {
          selectedWorkspace =
              'All Workspaces';
        }

        loading = false;
      });
    } catch (error) {
      debugPrint(
        'MASTER ADMIN USERS ERROR: $error',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceFilteredUsers = users.where((user) {
      if (selectedWorkspace == 'All Workspaces') {
        return true;
      }

      return user['workspace_name']?.toString() == selectedWorkspace;
    }).toList();

    final query = searchQuery.trim().toLowerCase();

    final filteredUsers = workspaceFilteredUsers.where((user) {
      if (query.isEmpty) return true;

      final name =
          user['full_name']?.toString().toLowerCase() ?? '';

      final email =
          user['email']?.toString().toLowerCase() ?? '';

      final role =
          user['role']?.toString().toLowerCase() ?? '';

      final workspace =
          user['workspace_name']?.toString().toLowerCase() ?? '';

      final approval =
          user['approval_status']?.toString().toLowerCase() ?? '';

      final userStatus = user['is_active'] == true
          ? 'active enabled'
          : 'disabled inactive';

      final workspaceStatus = user['workspace_is_active'] != false
          ? 'workspace enabled'
          : 'workspace disabled';

      return name.contains(query) ||
          email.contains(query) ||
          role.contains(query) ||
          workspace.contains(query) ||
          approval.contains(query) ||
          userStatus.contains(query) ||
          workspaceStatus.contains(query);
    }).toList();

    final admins = workspaceFilteredUsers.where((user) {
      return user['role']?.toString().toLowerCase() == 'admin';
    }).length;

    final employees = workspaceFilteredUsers.where((user) {
      return user['role']?.toString().toLowerCase() == 'employee';
    }).length;

    final masterAdmins = workspaceFilteredUsers.where((user) {
      return user['role']?.toString().toLowerCase() == 'master_admin';
    }).length;

    final activeUsers = workspaceFilteredUsers.where((user) {
      return user['is_active'] == true;
    }).length;

    final disabledUsers = workspaceFilteredUsers.length - activeUsers;

    return Scaffold(
      backgroundColor: background,
      body: Row(
        children: [
          MasterAdminSidebar(
            currentPage: 'users',
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
            onUsers: () {},
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
                    : _buildContent(
                        filteredUsers,
                        workspaceFilteredUsers.length,
                        admins,
                        employees,
                        masterAdmins,
                        activeUsers,
                        disabledUsers,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<Map<String, dynamic>> filteredUsers,
    int totalUsers,
    int admins,
    int employees,
    int masterAdmins,
    int activeUsers,
    int disabledUsers,
  ) {
    return RefreshIndicator(
      color: orange,
      onRefresh: loadUsers,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Users',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'View all ClockMetric users across every workspace.',
              style: TextStyle(
                fontSize: 13,
                color: textGrey,
              ),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment:
                  WrapCrossAlignment.center,
              children: [
                _searchBox(),
                _workspaceDropdown(),
              ],
            ),

            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  title: selectedWorkspace ==
                          'All Workspaces'
                      ? 'Total Users'
                      : 'Users in Workspace',
                  value: totalUsers.toString(),
                  icon:
                      Icons.people_alt_rounded,
                ),
                _summaryCard(
                  title: 'Master Admins',
                  value:
                      masterAdmins.toString(),
                  icon:
                      Icons.admin_panel_settings_rounded,
                ),
                _summaryCard(
                  title: 'Admins',
                  value: admins.toString(),
                  icon:
                      Icons.manage_accounts_rounded,
                ),
                _summaryCard(
                  title: 'Employees',
                  value:
                      employees.toString(),
                  icon: Icons.badge_rounded,
                ),
                _summaryCard(
                  title: 'Active Users',
                  value:
                      activeUsers.toString(),
                  icon:
                      Icons.check_circle_rounded,
                ),
                _summaryCard(
                  title: 'Disabled Users',
                  value:
                      disabledUsers.toString(),
                  icon: Icons.block_rounded,
                ),
              ],
            ),

            const SizedBox(height: 18),

            _buildUsersTable(
              filteredUsers,
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
              'Search name, email, role, approval or status...',
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

  Widget _workspaceDropdown() {
    return Container(
      width: 230,
      height: 46,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(11),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.business_rounded,
            color: orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedWorkspace,
                isExpanded: true,
                isDense: true,
                style: const TextStyle(
                  fontSize: 12,
                  color: textDark,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                ),
                items: workspaceOptions
                    .map(
                      (workspace) =>
                          DropdownMenuItem<String>(
                        value: workspace,
                        child: Text(
                          workspace,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedWorkspace = value;
                  });
                },
              ),
            ),
          ),
        ],
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
              color: const Color(0xFFFFEDD5),
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

  Widget _buildUsersTable(
    List<Map<String, dynamic>> visibleUsers,
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
                  flex: 3,
                  child: Text(
                    'Workspace',
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
                    'User Status',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Workspace Access',
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

          if (visibleUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(26),
              child: Text(
                searchQuery.isEmpty
                    ? 'No users found for this workspace.'
                    : 'No matching users found.',
                style: const TextStyle(
                  fontSize: 12,
                  color: textGrey,
                ),
              ),
            ),

          ...visibleUsers.map(
            (user) {
              final name =
                  user['full_name']
                          ?.toString() ??
                      '-';

              final email =
                  user['email']
                          ?.toString() ??
                      '-';

              final workspace =
                  user['workspace_name']
                          ?.toString() ??
                      '-';

              final role =
                  user['role']
                          ?.toString() ??
                      '-';

              final approval =
                  user['approval_status']
                          ?.toString() ??
                      '-';

              final active =
                  user['is_active'] == true;

              final workspaceActive =
                  user['workspace_is_active'] !=
                      false;

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
                      flex: 3,
                      child: Text(
                        workspace,
                        overflow:
                            TextOverflow.ellipsis,
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _roleBadge(role),
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
                      child: _statusLabel(
                        active,
                        active
                            ? 'Active'
                            : 'Disabled',
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _statusLabel(
                        workspaceActive,
                        role.toLowerCase() ==
                                'master_admin'
                            ? 'Platform'
                            : workspaceActive
                                ? 'Enabled'
                                : 'Disabled',
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

  Widget _statusLabel(
    bool enabled,
    String text,
  ) {
    return Row(
      children: [
        Icon(
          enabled
              ? Icons.check_circle_rounded
              : Icons.cancel_rounded,
          size: 16,
          color: enabled
              ? Colors.green
              : Colors.red,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _roleBadge(String role) {
    final value =
        role.toLowerCase();

    Color badgeBackground;
    Color badgeText;

    if (value == 'master_admin') {
      badgeBackground =
          const Color(0xFFFFEDD5);
      badgeText = orange;
    } else if (value == 'admin') {
      badgeBackground =
          const Color(0xFFFEF3C7);
      badgeText =
          const Color(0xFFB45309);
    } else {
      badgeBackground =
          const Color(0xFFEFF6FF);
      badgeText =
          const Color(0xFF2563EB);
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
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Text(
          value == 'master_admin'
              ? 'MASTER ADMIN'
              : role.toUpperCase(),
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
            'Unable to load users',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
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
            onPressed: loadUsers,
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

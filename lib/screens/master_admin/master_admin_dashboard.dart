import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'master_admin_users.dart';
import 'master_admin_subscriptions.dart';
import 'master_admin_reports.dart';
import 'master_admin_settings.dart';
import 'master_admin_finance.dart';

import 'master_admin_workspaces.dart';
import 'master_admin_sidebar.dart';

class MasterAdminDashboard extends StatefulWidget {
  const MasterAdminDashboard({super.key});

  @override
  State<MasterAdminDashboard> createState() =>
      _MasterAdminDashboardState();
}

class _MasterAdminDashboardState
    extends State<MasterAdminDashboard> {
  final supabase = Supabase.instance.client;

  static const Color orange = Color(0xFFF97316);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  bool loading = true;
  String? errorMessage;

  int totalWorkspaces = 0;
  int totalEmployees = 0;
  int activeSubscriptions = 0;

  double estimatedMonthlyRevenue = 0;

 String billingCurrency = 'AUD';
 
  List<Map<String, dynamic>> workspaceData = [];

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

Future<void> loadDashboard() async {
  if (!mounted) return;

  setState(() {
    loading = true;
    errorMessage = null;
  });

  try {
    final workspaceRows = await supabase
        .from('workspaces')
        .select(
          'id, workspace_name, is_active, '
          'trial_ends_at, current_period_end',
        );

    final profileRows = await supabase
        .from('profiles')
        .select(
          'id, role, workspace_id',
        );

    final billingRows = await supabase
        .from('workspace_billing_summary')
        .select();

    final workspaces =
        List<Map<String, dynamic>>.from(
      workspaceRows,
    );

    final profiles =
        List<Map<String, dynamic>>.from(
      profileRows,
    );

    final billing =
        List<Map<String, dynamic>>.from(
      billingRows,
    );

    final employees = profiles.where((profile) {
      final role =
          profile['role']
                  ?.toString()
                  .toLowerCase() ??
              '';

      return role == 'employee';
    }).toList();

    final billingByWorkspace =
        <String, Map<String, dynamic>>{};

    for (final row in billing) {
      final workspaceId =
          row['workspace_id']?.toString() ?? '';

      if (workspaceId.isNotEmpty) {
        billingByWorkspace[workspaceId] = row;
      }
    }

    double monthlyRevenue = 0;
    int activeSubscriptionCount = 0;

    final List<Map<String, dynamic>>
        preparedWorkspaces = [];

    for (final workspace in workspaces) {
      final workspaceId =
          workspace['id']?.toString() ?? '';

      final employeesInWorkspace =
          employees.where((employee) {
        return employee['workspace_id']
                ?.toString() ==
            workspaceId;
      }).toList();

      final billingRow =
          billingByWorkspace[workspaceId];

      final status =
          billingRow?['subscription_status']
                  ?.toString()
                  .toLowerCase() ??
              'unknown';

      final activeEmployeeCount =
          (billingRow?[
                      'active_employee_count']
                  as num?)
              ?.toInt() ??
          0;

      final pricePerEmployee =
          (billingRow?[
                      'price_per_employee']
                  as num?)
              ?.toDouble() ??
          0.0;

      final workspaceRevenue =
          status == 'active'
              ? (billingRow?['monthly_amount']
                          as num?)
                      ?.toDouble() ??
                  0.0
              : 0.0;

      if (status == 'active') {
        activeSubscriptionCount++;
        monthlyRevenue += workspaceRevenue;
      }

      preparedWorkspaces.add({
        ...workspace,
        'subscription_status': status,
        'plan_type':
            billingRow?['plan_type'],
        'plan_price':
            pricePerEmployee,
        'employee_count':
            employeesInWorkspace.length,
        'active_employee_count':
            activeEmployeeCount,
        'estimated_revenue':
            workspaceRevenue,
      });
    }

    if (!mounted) return;

    setState(() {
      totalWorkspaces = workspaces.length;
      totalEmployees = employees.length;

      activeSubscriptions =
          activeSubscriptionCount;

      estimatedMonthlyRevenue =
          monthlyRevenue;

      workspaceData =
          preparedWorkspaces;

      loading = false;
    });
  } catch (error) {
    debugPrint(
      'MASTER ADMIN DASHBOARD ERROR: $error',
    );

    if (!mounted) return;

    setState(() {
      loading = false;
      errorMessage = error.toString();
    });
  }
}

  Future<void> logout() async {
  await supabase.auth.signOut();

  if (!mounted) return;

  Navigator.of(context).pushNamedAndRemoveUntil(
    '/',
    (route) => false,
  );
}

  Future<void> toggleWorkspaceAccess(
    Map<String, dynamic> workspace,
    bool enabled,
  ) async {
    final workspaceId =
        workspace['id']?.toString() ?? '';

    if (workspaceId.isEmpty) return;

    try {
      await supabase
          .from('workspaces')
          .update({
            'is_active': enabled,
          })
          .eq('id', workspaceId);

      if (!mounted) return;

      setState(() {
        final index = workspaceData.indexWhere(
          (item) =>
              item['id']?.toString() ==
              workspaceId,
        );

        if (index != -1) {
          workspaceData[index] = {
            ...workspaceData[index],
            'is_active': enabled,
          };
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Workspace enabled.'
                : 'Workspace disabled.',
          ),
          backgroundColor:
              enabled ? Colors.green : Colors.orange,
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
    }
  }

  String formatMoney(double amount) {
    switch (billingCurrency) {
      case 'AUD':
        return 'A\$${amount.toStringAsFixed(0)}';
      case 'USD':
        return '\$${amount.toStringAsFixed(0)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(0)}';
      case 'GBP':
        return '£${amount.toStringAsFixed(0)}';
      default:
        return '$billingCurrency ${amount.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final query =
        searchQuery.trim().toLowerCase();

    final filteredWorkspaces =
        workspaceData.where((workspace) {
      if (query.isEmpty) return true;

      final name =
          workspace['workspace_name']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final status =
          workspace['subscription_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      return name.contains(query) ||
          status.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          MasterAdminSidebar(
            currentPage: 'dashboard',
            onDashboard: () {},
            onWorkspaces: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminWorkspaces(),
                ),
              );
            },
            onUsers: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminUsers(),
                ),
              );
            },
            onSubscriptions: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminSubscriptions(),
                ),
              );
            },
            onReports: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminReports(),
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
            onSettings: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminSettings(),
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
                    : _buildDashboard(
                        filteredWorkspaces,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(
    List<Map<String, dynamic>> filteredWorkspaces,
  ) {
    return RefreshIndicator(
      color: orange,
      onRefresh: loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Master Dashboard',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage the complete ClockMetric platform.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: 'Refresh',
                  onPressed: loadDashboard,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: orange,
                    size: 20,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _searchBox(
              hint: 'Search workspaces or subscription status...',
            ),

            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(
                  title: 'Total Workspaces',
                  value: totalWorkspaces.toString(),
                  icon: Icons.business_rounded,
                ),
                _statCard(
                  title: 'Total Employees',
                  value: totalEmployees.toString(),
                  icon: Icons.people_alt_rounded,
                ),
                _statCard(
                  title: 'Active Subscriptions',
                  value: activeSubscriptions.toString(),
                  icon: Icons.credit_card_rounded,
                ),
                _statCard(
                  title: 'Est. Monthly Revenue',
                  value:
                      formatMoney(estimatedMonthlyRevenue),
                  icon: Icons.payments_rounded,
                ),
              ],
            ),

            const SizedBox(height: 18),

            _buildWorkspaceTable(filteredWorkspaces),
          ],
        ),
      ),
    );
  }

  Widget _searchBox({
    required String hint,
  }) {
    return SizedBox(
      width: 420,
      height: 46,
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
          hintText: hint,
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
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: orange,
              width: 1.2,
            ),
          ),
        ),
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
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            child: Text(
              'Workspaces',
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
                    'Workspace',
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
                    'Workspace Access',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Subscription',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Est. Revenue',
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
              child: Center(
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
            ),

          ...visibleWorkspaces.map(
            (workspace) {
              final name =
                  workspace['workspace_name']?.toString() ??
                      'Unnamed Workspace';

              final status =
                  workspace['subscription_status']?.toString() ??
                      'unknown';

              final employeeCount =
                  workspace['employee_count'] ?? 0;

              final activeEmployeeCount =
                  workspace['active_employee_count'] ?? 0;

              final workspaceActive =
                  workspace['is_active'] != false;

              final revenue =
                  (workspace['estimated_revenue'] ?? 0) as num;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: border),
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
                      child: Text(
                        employeeCount.toString(),
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        activeEmployeeCount.toString(),
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Transform.scale(
                            scale: 0.78,
                            child: Switch(
                              value: workspaceActive,
                              activeThumbColor: Colors.white,
                              activeTrackColor: Colors.green,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor:
                                  Colors.grey.shade400,
                              materialTapTargetSize:
                                  MaterialTapTargetSize
                                      .shrinkWrap,
                              onChanged: (value) {
                                toggleWorkspaceAccess(
                                  workspace,
                                  value,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            workspaceActive
                                ? 'Enabled'
                                : 'Disabled',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w600,
                              color: workspaceActive
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _statusBadge(status),
                    ),
                    Expanded(
                      child: Text(
                        formatMoney(revenue.toDouble()),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
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

  Widget _statusBadge(String status) {
    final value = status.toLowerCase();

    Color background;
    Color foreground;

    if (value == 'active') {
      background = const Color(0xFFDCFCE7);
      foreground = const Color(0xFF15803D);
    } else if (value == 'trialing') {
      background = const Color(0xFFFEF3C7);
      foreground = const Color(0xFFB45309);
    } else if (value == 'cancelled') {
      background = const Color(0xFFFEE2E2);
      foreground = const Color(0xFFB91C1C);
    } else {
      background = const Color(0xFFF3F4F6);
      foreground = textGrey;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: foreground,
          ),
        ),
      ),
    );
  }

  Widget _statCard({
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
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
                    fontSize: 18,
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'Unable to load Master Admin data',
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
              onPressed: loadDashboard,
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
      ),
    );
  }
}

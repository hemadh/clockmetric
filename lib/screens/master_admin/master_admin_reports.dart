import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'master_admin_sidebar.dart';
import 'master_admin_dashboard.dart';
import 'master_admin_workspaces.dart';
import 'master_admin_users.dart';
import 'master_admin_subscriptions.dart';
import 'master_admin_settings.dart';
import 'master_admin_finance.dart';

class MasterAdminReports extends StatefulWidget {
  const MasterAdminReports({super.key});

  @override
  State<MasterAdminReports> createState() =>
      _MasterAdminReportsState();
}

class _MasterAdminReportsState
    extends State<MasterAdminReports> {
  final supabase = Supabase.instance.client;

  static const Color orange = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  bool loading = true;
  String? errorMessage;

  List<Map<String, dynamic>> reports = [];
  List<String> workspaceOptions = [];

  String searchQuery = '';
  String selectedWorkspace = 'All Workspaces';
  String selectedDateRange = 'All Time';

  final TextEditingController searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadReports() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final workspaceRows = await supabase
          .from('workspaces')
          .select(
            'id, workspace_name, created_at, is_active, '
            'trial_ends_at, current_period_end',
          );

      final profileRows = await supabase
          .from('profiles')
          .select(
            'id, role, workspace_id',
          );

      final billingRows = await supabase
          .from('workspace_billing_summary')
          .select(
            'workspace_id, workspace_name, plan_type, '
            'price_per_employee, currency, subscription_status, '
            'active_employee_count, monthly_amount',
          );

      final workspaces =
          List<Map<String, dynamic>>.from(workspaceRows);
      final profiles =
          List<Map<String, dynamic>>.from(profileRows);
      final billing =
          List<Map<String, dynamic>>.from(billingRows);

      final billingByWorkspace =
          <String, Map<String, dynamic>>{};

      for (final row in billing) {
        final workspaceId =
            row['workspace_id']?.toString() ?? '';
        if (workspaceId.isNotEmpty) {
          billingByWorkspace[workspaceId] = row;
        }
      }

      final List<Map<String, dynamic>> prepared = [];
      final List<String> names = [];

      for (final workspace in workspaces) {
        final workspaceId =
            workspace['id']?.toString() ?? '';
        final billingRow =
            billingByWorkspace[workspaceId];

        final workspaceName =
            billingRow?['workspace_name']?.toString() ??
                workspace['workspace_name']?.toString() ??
                'Unnamed Workspace';

        if (!names.contains(workspaceName)) {
          names.add(workspaceName);
        }

        final workspaceProfiles = profiles.where((profile) {
          return profile['workspace_id']?.toString() == workspaceId;
        }).toList();

        final admins = workspaceProfiles.where((profile) {
          return profile['role']?.toString().toLowerCase() == 'admin';
        }).length;

        final employees = workspaceProfiles.where((profile) {
          return profile['role']?.toString().toLowerCase() == 'employee';
        }).length;

        final rawStatus =
            billingRow?['subscription_status']
                    ?.toString()
                    .toLowerCase() ??
                'unknown';

        final status = effectiveSubscriptionStatus(
          rawStatus,
          workspace['trial_ends_at'],
        );

        final rawPlan =
            billingRow?['plan_type']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final planType = rawPlan == 'with_ai'
            ? 'with_ai'
            : rawPlan == 'without_ai'
                ? 'without_ai'
                : 'unassigned';

        final planPrice =
            (billingRow?['price_per_employee'] as num?)
                    ?.toDouble() ??
                0.0;

        final activeEmployees =
            (billingRow?['active_employee_count'] as num?)
                    ?.toInt() ??
                0;

        final monthlyAmount =
            (billingRow?['monthly_amount'] as num?)
                    ?.toDouble() ??
                0.0;

        final currency =
            billingRow?['currency']
                    ?.toString()
                    .trim()
                    .toUpperCase() ??
                'AUD';

        final estimatedRevenue =
            status == 'active' ? monthlyAmount : 0.0;

        prepared.add({
          ...workspace,
          'workspace_name': workspaceName,
          'admin_count': admins,
          'employee_count': employees,
          'active_employee_count': activeEmployees,
          'plan_type': planType,
          'plan_price': planPrice,
          'billing_currency': currency,
          'display_status': status,
          'estimated_revenue': estimatedRevenue,
        });
      }

      names.sort(
        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );

      prepared.sort((a, b) {
        final aName = a['workspace_name']?.toString() ?? '';
        final bName = b['workspace_name']?.toString() ?? '';
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

      if (!mounted) return;

      setState(() {
        reports = prepared;
        workspaceOptions = [
          'All Workspaces',
          ...names,
        ];

        if (!workspaceOptions.contains(selectedWorkspace)) {
          selectedWorkspace = 'All Workspaces';
        }

        loading = false;
      });
    } catch (error) {
      debugPrint('MASTER ADMIN REPORTS ERROR: $error');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = error.toString();
      });
    }
  }

  String effectiveSubscriptionStatus(
    String rawStatus,
    dynamic trialEndValue,
  ) {
    final status =
        rawStatus.trim().toLowerCase();

    if (status == 'trialing' &&
        trialEndValue != null) {
      final trialEnd =
          DateTime.tryParse(
        trialEndValue.toString(),
      );

      if (trialEnd != null &&
          trialEnd.toUtc().isBefore(
                DateTime.now().toUtc(),
              )) {
        return 'expired';
      }
    }

    return status;
  }

  String _planLabel(String planType) {
    switch (planType.trim().toLowerCase()) {
      case 'with_ai':
        return 'With AI';
      case 'without_ai':
        return 'Without AI';
      default:
        return 'Unassigned';
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return '-';

    final date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) return '-';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  bool matchesDateRange(dynamic createdAt) {
    if (selectedDateRange == 'All Time') {
      return true;
    }

    if (createdAt == null) {
      return false;
    }

    final date =
        DateTime.tryParse(
      createdAt.toString(),
    );

    if (date == null) {
      return false;
    }

    final now = DateTime.now().toUtc();
    final created = date.toUtc();

    int days;

    switch (selectedDateRange) {
      case 'Last 7 Days':
        days = 7;
        break;

      case 'Last 30 Days':
        days = 30;
        break;

      case 'Last 90 Days':
        days = 90;
        break;

      default:
        return true;
    }

    return created.isAfter(
      now.subtract(
        Duration(days: days),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports =
        reports.where((report) {
      if (selectedWorkspace !=
              'All Workspaces' &&
          report['workspace_name']
                  ?.toString() !=
              selectedWorkspace) {
        return false;
      }

      if (!matchesDateRange(
        report['created_at'],
      )) {
        return false;
      }

      final query =
          searchQuery.trim().toLowerCase();

      if (query.isEmpty) {
        return true;
      }

      final workspace =
          report['workspace_name']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final status =
          report['display_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final access =
          report['is_active'] != false
              ? 'enabled active'
              : 'disabled inactive';

      final plan =
          report['plan_type']
                  ?.toString()
                  .toLowerCase() ??
              '';

      return workspace.contains(query) ||
          status.contains(query) ||
          access.contains(query) ||
          plan.contains(query) ||
          _planLabel(plan)
              .toLowerCase()
              .contains(query);
    }).toList();

    final totalEmployees =
        filteredReports.fold<int>(
      0,
      (total, report) {
        final count =
            report['employee_count'];

        return total +
            (count is num
                ? count.toInt()
                : 0);
      },
    );

    final activeEmployees =
        filteredReports.fold<int>(
      0,
      (total, report) {
        final count =
            report[
                'active_employee_count'];

        return total +
            (count is num
                ? count.toInt()
                : 0);
      },
    );

    final activeSubscriptions =
        filteredReports.where((report) {
      return report['display_status'] ==
          'active';
    }).length;

    final trialing =
        filteredReports.where((report) {
      return report['display_status'] ==
          'trialing';
    }).length;

    final expired =
        filteredReports.where((report) {
      return report['display_status'] ==
          'expired';
    }).length;

    final revenue =
        filteredReports.fold<double>(
      0,
      (total, report) {
        final value =
            report['estimated_revenue'];

        return total +
            (value is num
                ? value.toDouble()
                : 0.0);
      },
    );

    return Scaffold(
      backgroundColor: background,
      body: Row(
        children: [
          MasterAdminSidebar(
            currentPage: 'reports',
            onDashboard: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminDashboard(),
                ),
              );
            },
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
            onFinance: () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const MasterAdminFinance(),
    ),
  );
},
            onReports: () {},
            onSettings: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminSettings(),
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
                        filteredReports,
                        totalEmployees,
                        activeEmployees,
                        activeSubscriptions,
                        trialing,
                        expired,
                        revenue,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<Map<String, dynamic>> filteredReports,
    int totalEmployees,
    int activeEmployees,
    int activeSubscriptions,
    int trialing,
    int expired,
    double revenue,
  ) {
    return RefreshIndicator(
      color: orange,
      onRefresh: loadReports,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Platform overview and workspace performance report.',
              style: TextStyle(
                fontSize: 13,
                color: textGrey,
              ),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _searchBox(),
                _workspaceDropdown(),
                _dateDropdown(),
              ],
            ),

            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  title: 'Workspaces',
                  value: filteredReports.length.toString(),
                  icon: Icons.business_rounded,
                ),
                _summaryCard(
                  title: 'Employees',
                  value: totalEmployees.toString(),
                  icon: Icons.people_alt_rounded,
                ),
                _summaryCard(
                  title: 'Active Employees',
                  value: activeEmployees.toString(),
                  icon: Icons.check_circle_rounded,
                ),
                _summaryCard(
                  title: 'Active Subscriptions',
                  value: activeSubscriptions.toString(),
                  icon: Icons.credit_card_rounded,
                ),
                _summaryCard(
                  title: 'Trialing',
                  value: trialing.toString(),
                  icon: Icons.schedule_rounded,
                ),
                _summaryCard(
                  title: 'Expired',
                  value: expired.toString(),
                  icon: Icons.timer_off_rounded,
                ),
                _summaryCard(
                  title: 'Est. Monthly Revenue',
                  value: 'A\$${revenue.toStringAsFixed(0)}',
                  icon: Icons.payments_rounded,
                ),
              ],
            ),

            const SizedBox(height: 18),

            _buildReportTable(filteredReports),
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
          hintText: 'Search workspace, subscription or access...',
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
            minWidth: 38,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    searchController.clear();
                    setState(() {
                      searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: textGrey,
                    size: 19,
                  ),
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
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
    return _dropdownContainer(
      width: 230,
      icon: Icons.business_rounded,
      child: DropdownButton<String>(
        value: selectedWorkspace,
        isExpanded: true,
        isDense: true,
        style: const TextStyle(
          fontSize: 12,
          color: textDark,
        ),
        underline: const SizedBox.shrink(),
        items: workspaceOptions.map(
          (item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            selectedWorkspace = value;
          });
        },
      ),
    );
  }

  Widget _dateDropdown() {
    const ranges = [
      'All Time',
      'Last 7 Days',
      'Last 30 Days',
      'Last 90 Days',
    ];

    return _dropdownContainer(
      width: 185,
      icon: Icons.date_range_rounded,
      child: DropdownButton<String>(
        value: selectedDateRange,
        isExpanded: true,
        isDense: true,
        style: const TextStyle(
          fontSize: 12,
          color: textDark,
        ),
        underline: const SizedBox.shrink(),
        items: ranges.map(
          (item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          },
        ).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            selectedDateRange = value;
          });
        },
      ),
    );
  }

  Widget _dropdownContainer({
    required double width,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: width,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: orange,
          ),
          const SizedBox(width: 7),
          Expanded(child: child),
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
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: orange,
              size: 19,
            ),
          ),
          const SizedBox(width: 8),
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
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
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

  Widget _buildReportTable(
    List<Map<String, dynamic>> visibleReports,
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
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
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
                    'Admins',
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
                    'Plan / Status',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Access',
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
                Expanded(
                  flex: 2,
                  child: Text(
                    'Est. Revenue',
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Created',
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

          if (visibleReports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matching report data found.',
                style: TextStyle(
                  fontSize: 12,
                  color: textGrey,
                ),
              ),
            ),

          ...visibleReports.map(
            (report) {
              final workspace =
                  report['workspace_name']?.toString() ?? '-';

              final admins =
                  report['admin_count'] ?? 0;

              final employees =
                  report['employee_count'] ?? 0;

              final active =
                  report['active_employee_count'] ?? 0;

              final status =
                  report['display_status']?.toString() ?? 'unknown';

              final planType =
                  report['plan_type']?.toString() ??
                      'unassigned';

              final planPrice =
                  (report['plan_price'] as num?)
                          ?.toDouble() ??
                      0.0;

              final rowCurrency =
                  report['billing_currency']
                          ?.toString()
                          .toUpperCase() ??
                      'AUD';

              final access =
                  report['is_active'] != false;

              final trialEnd =
                  formatDate(report['trial_ends_at']);

              final created =
                  formatDate(report['created_at']);

              final revenue =
                  report['estimated_revenue'];

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
                        workspace,
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
                        '$admins',
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$employees',
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$active',
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Text(
                            '${_planLabel(planType)} · '
                            '${rowCurrency == 'AUD' ? 'A\$' : '$rowCurrency '}'
                            '${planPrice.toStringAsFixed(0)}',
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight:
                                  FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _statusBadge(status),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _accessLabel(access),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        trialEnd,
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'A\$${(revenue is num ? revenue : 0).toStringAsFixed(0)}',
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        created,
                        style: cellStyle,
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

  Widget _accessLabel(bool enabled) {
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
        Text(
          enabled ? 'Enabled' : 'Disabled',
          style: const TextStyle(
            fontSize: 11,
            color: textDark,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final value = status.toLowerCase();

    Color bg;
    Color fg;

    if (value == 'active') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (value == 'trialing') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (value == 'expired') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = textGrey;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          status.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
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
            size: 38,
            color: Colors.red,
          ),
          const SizedBox(height: 10),
          const Text(
            'Unable to load reports',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            errorMessage ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: textGrey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: loadReports,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
            ),
            label: const Text(
              'Try Again',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

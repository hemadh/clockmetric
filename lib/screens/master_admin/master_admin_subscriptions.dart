import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'master_admin_sidebar.dart';
import 'master_admin_dashboard.dart';
import 'master_admin_workspaces.dart';
import 'master_admin_users.dart';
import 'master_admin_reports.dart';
import 'master_admin_settings.dart';
import 'master_admin_workspace_details.dart';
import 'master_admin_finance.dart';

class MasterAdminSubscriptions extends StatefulWidget {
  const MasterAdminSubscriptions({super.key});

  @override
  State<MasterAdminSubscriptions> createState() =>
      _MasterAdminSubscriptionsState();
}

class _MasterAdminSubscriptionsState
    extends State<MasterAdminSubscriptions> {
  final supabase = Supabase.instance.client;

  static const Color orange = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  bool loading = true;
  String? errorMessage;

  List<Map<String, dynamic>> subscriptions = [];
  List<String> workspaceOptions = [];

  String billingCurrency = 'AUD';

  String searchQuery = '';
  String selectedWorkspace = 'All Workspaces';
  String selectedStatus = 'All Statuses';

  final TextEditingController searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSubscriptions();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadSubscriptions() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      // Billing is now calculated centrally in Supabase.
      // This view already counts only approved + active employees
      // whose role is "employee".
      final billingRows = await supabase
          .from('workspace_billing_summary')
          .select(
            'workspace_id, workspace_name, plan_type, '
            'price_per_employee, currency, subscription_status, '
            'active_employee_count, monthly_amount',
          );

      // Keep workspace operational fields here because the billing
      // view currently focuses only on billing calculations.
      final workspaceRows = await supabase
          .from('workspaces')
          .select(
            'id, workspace_name, is_active, '
            'trial_ends_at, current_period_end, '
            'stripe_customer_id, stripe_subscription_id',
          );

      final billing =
          List<Map<String, dynamic>>.from(
        billingRows,
      );

      final workspaces =
          List<Map<String, dynamic>>.from(
        workspaceRows,
      );

      final workspaceById =
          <String, Map<String, dynamic>>{
        for (final workspace in workspaces)
          if (workspace['id'] != null)
            workspace['id'].toString(): workspace,
      };

      final List<Map<String, dynamic>> prepared = [];
      final List<String> names = [];

      for (final billingRow in billing) {
        final workspaceId =
            billingRow['workspace_id']?.toString() ?? '';

        final workspace =
            workspaceById[workspaceId] ??
                <String, dynamic>{};

        final workspaceName =
            billingRow['workspace_name']
                    ?.toString() ??
                workspace['workspace_name']
                    ?.toString() ??
                'Unnamed Workspace';

        if (!names.contains(workspaceName)) {
          names.add(workspaceName);
        }

        final rawStatus =
            billingRow['subscription_status']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                'unknown';

        final displayStatus =
            effectiveSubscriptionStatus(
          rawStatus,
          workspace['trial_ends_at'],
        );

        final rawPlan =
            billingRow['plan_type']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final planType =
            rawPlan == 'with_ai'
                ? 'with_ai'
                : rawPlan == 'without_ai'
                    ? 'without_ai'
                    : 'unassigned';

        final planPrice =
            (billingRow['price_per_employee'] as num?)
                    ?.toDouble() ??
                0.0;

        final activeEmployees =
            (billingRow['active_employee_count'] as num?)
                    ?.toInt() ??
                0;

        final monthlyAmount =
            (billingRow['monthly_amount'] as num?)
                    ?.toDouble() ??
                0.0;

        final rowCurrency =
            billingRow['currency']
                    ?.toString()
                    .trim()
                    .toUpperCase() ??
                'AUD';

        final revenue =
            displayStatus == 'active'
                ? monthlyAmount
                : 0.0;

        prepared.add({
          ...workspace,
          ...billingRow,
          'id': workspaceId,
          'workspace_name': workspaceName,
          'plan_type': planType,
          'plan_price': planPrice,
          'active_employee_count':
              activeEmployees,
          'display_status': displayStatus,
          'estimated_revenue': revenue,
          'billing_currency': rowCurrency,
        });
      }

      names.sort(
        (a, b) => a
            .toLowerCase()
            .compareTo(
              b.toLowerCase(),
            ),
      );

      prepared.sort((a, b) {
        final aName =
            a['workspace_name']
                    ?.toString() ??
                '';

        final bName =
            b['workspace_name']
                    ?.toString() ??
                '';

        return aName
            .toLowerCase()
            .compareTo(
              bName.toLowerCase(),
            );
      });

      final loadedCurrency =
          prepared.isNotEmpty
              ? prepared.first['billing_currency']
                      ?.toString()
                      .trim()
                      .toUpperCase() ??
                  'AUD'
              : 'AUD';

      if (!mounted) return;

      setState(() {
        subscriptions = prepared;
        billingCurrency = loadedCurrency;

        workspaceOptions = [
          'All Workspaces',
          ...names,
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
        'MASTER ADMIN SUBSCRIPTIONS ERROR: $error',
      );

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

    if (status == 'trialing') {
      if (trialEndValue != null) {
        final trialEnd = DateTime.tryParse(
          trialEndValue.toString(),
        );

        if (trialEnd != null &&
            trialEnd.toUtc().isBefore(
                  DateTime.now().toUtc(),
                )) {
          return 'expired';
        }
      }
    }

    return status;
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

  @override
  Widget build(BuildContext context) {
    final filtered =
        subscriptions.where((item) {
      if (selectedWorkspace !=
              'All Workspaces' &&
          item['workspace_name']
                  ?.toString() !=
              selectedWorkspace) {
        return false;
      }

      final displayStatus =
          item['display_status']
                  ?.toString()
                  .toLowerCase() ??
              'unknown';

      final selectedStatusValue =
          selectedStatus
              .toLowerCase()
              .replaceAll(' ', '_');

      if (selectedStatus != 'All Statuses' &&
          displayStatus != selectedStatusValue) {
        return false;
      }

      final query =
          searchQuery.trim().toLowerCase();

      if (query.isEmpty) return true;

      final workspace =
          item['workspace_name']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final customerId =
          item['stripe_customer_id']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final subscriptionId =
          item['stripe_subscription_id']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final access =
          item['is_active'] != false
              ? 'enabled active'
              : 'disabled inactive';

      final planType =
          item['plan_type']
                  ?.toString()
                  .toLowerCase() ??
              'unassigned';

      final planSearch =
          planType == 'with_ai'
              ? 'with ai ai 13'
              : planType == 'without_ai'
                  ? 'without ai no ai 10'
                  : 'unassigned no plan';

      return workspace.contains(query) ||
          displayStatus.contains(query) ||
          customerId.contains(query) ||
          subscriptionId.contains(query) ||
          access.contains(query) ||
          planType.contains(query) ||
          planSearch.contains(query);
    }).toList();

    final activeCount =
        subscriptions.where((item) {
      return item['display_status'] == 'active';
    }).length;

    final aiPlanCount =
        subscriptions.where((item) {
      return item['plan_type'] == 'with_ai';
    }).length;

    final corePlanCount =
        subscriptions.where((item) {
      return item['plan_type'] == 'without_ai';
    }).length;

    final trialingCount =
        subscriptions.where((item) {
      return item['display_status'] ==
          'trialing';
    }).length;

    final expiredCount =
        subscriptions.where((item) {
      return item['display_status'] ==
          'expired';
    }).length;

    final billingIssueCount =
        subscriptions.where((item) {
      final status =
          item['display_status']
                  ?.toString()
                  .toLowerCase() ??
              'unknown';

      if (status == 'expired' ||
          status == 'past_due' ||
          status == 'unpaid') {
        return true;
      }

      if (status == 'cancelled') {
        final periodEndText =
            item['current_period_end']?.toString();

        final periodEnd = periodEndText == null
            ? null
            : DateTime.tryParse(periodEndText);

        return periodEnd != null &&
            DateTime.now().toUtc().isAfter(
                  periodEnd.toUtc(),
                );
      }

      return false;
    }).length;

    final totalRevenue =
        subscriptions.fold<double>(
      0,
      (total, item) {
        final value =
            item['estimated_revenue'];

        if (value is num) {
          return total + value.toDouble();
        }

        return total;
      },
    );

    return Scaffold(
      backgroundColor: background,
      body: Row(
        children: [
          MasterAdminSidebar(
            currentPage: 'subscriptions',
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
            onSubscriptions: () {},
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
                        filtered,
                        activeCount,
                        aiPlanCount,
                        corePlanCount,
                        trialingCount,
                        expiredCount,
                        billingIssueCount,
                        totalRevenue,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<Map<String, dynamic>> filtered,
    int activeCount,
    int aiPlanCount,
    int corePlanCount,
    int trialingCount,
    int expiredCount,
    int billingIssueCount,
    double totalRevenue,
  ) {
    return RefreshIndicator(
      color: orange,
      onRefresh: loadSubscriptions,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Subscriptions',
              style: TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'View subscription and billing status across all ClockMetric workspaces.',
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
                _statusDropdown(),
              ],
            ),

            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  title: 'Total Workspaces',
                  value:
                      subscriptions.length
                          .toString(),
                  icon:
                      Icons.business_rounded,
                ),
                _summaryCard(
                  title:
                      'Active Subscriptions',
                  value:
                      activeCount.toString(),
                  icon:
                      Icons.credit_card_rounded,
                ),
                _summaryCard(
                  title: 'With AI Plan',
                  value: aiPlanCount.toString(),
                  icon: Icons.auto_awesome_rounded,
                ),
                _summaryCard(
                  title: 'Without AI Plan',
                  value: corePlanCount.toString(),
                  icon: Icons.schedule_rounded,
                ),
                _summaryCard(
                  title: 'Trialing',
                  value:
                      trialingCount.toString(),
                  icon:
                      Icons.schedule_rounded,
                ),
                _summaryCard(
                  title: 'Expired Trials',
                  value:
                      expiredCount.toString(),
                  icon:
                      Icons.timer_off_rounded,
                ),
                _summaryCard(
                  title: 'Billing Issues',
                  value:
                      billingIssueCount.toString(),
                  icon:
                      Icons.warning_amber_rounded,
                ),
                _summaryCard(
                  title:
                      'Est. Monthly Revenue',
                  value:
                      _formatMoney(totalRevenue),
                  icon:
                      Icons.payments_rounded,
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (billingIssueCount > 0) ...[
              _billingIssueBanner(
                billingIssueCount,
              ),
              const SizedBox(height: 14),
            ],

            _buildSubscriptionsTable(
              filtered,
            ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(num value) {
    final amount = value.toDouble();

    final amountText =
        amount == amount.roundToDouble()
            ? amount.toStringAsFixed(0)
            : amount.toStringAsFixed(2);

    if (billingCurrency == 'AUD') {
      return 'A\$$amountText';
    }

    return '$billingCurrency $amountText';
  }

  Widget _billingIssueBanner(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFC2410C),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count workspace${count == 1 ? '' : 's'} currently '
              'need billing attention. Use the status filter and Open '
              'the workspace to review access or extend a trial.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openWorkspaceDetails(
    Map<String, dynamic> workspace,
  ) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MasterAdminWorkspaceDetails(
          workspace: workspace,
        ),
      ),
    );
  }

  Future<void> _changeWorkspacePlan(
    Map<String, dynamic> workspace,
  ) async {
    final workspaceId =
        workspace['workspace_id']?.toString() ??
            workspace['id']?.toString() ??
            '';

    if (workspaceId.isEmpty) {
      return;
    }

    final currentPlan =
        workspace['plan_type']
                ?.toString()
                .toLowerCase() ??
            'with_ai';

    final selectedPlan =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Change Plan',
            style: TextStyle(
              color: textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.auto_awesome_rounded,
                    color: orange,
                  ),
                  title: const Text(
                    'With AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'A\$13 per active employee / month',
                  ),
                  trailing: currentPlan == 'with_ai'
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(
                      dialogContext,
                      'with_ai',
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.schedule_rounded,
                    color: textGrey,
                  ),
                  title: const Text(
                    'Without AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'A\$10 per active employee / month',
                  ),
                  trailing: currentPlan == 'without_ai'
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(
                      dialogContext,
                      'without_ai',
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedPlan == null ||
        selectedPlan == currentPlan) {
      return;
    }

    try {
      await supabase.rpc(
        'master_admin_set_workspace_plan',
        params: {
          'p_workspace_id': workspaceId,
          'p_plan_type': selectedPlan,
        },
      );

      await loadSubscriptions();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              selectedPlan == 'with_ai'
                  ? 'Plan changed to With AI — A\$13 per employee.'
                  : 'Plan changed to Without AI — A\$10 per employee.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Unable to change plan: $error',
            ),
          ),
        );
    }
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
              'Search workspace, Stripe ID, status or access...',
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
    return _dropdownBox(
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
        underline:
            const SizedBox.shrink(),
        items: workspaceOptions.map(
          (item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                overflow:
                    TextOverflow.ellipsis,
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

  Widget _statusDropdown() {
    const statuses = [
      'All Statuses',
      'Active',
      'Trialing',
      'Expired',
      'Cancelled',
      'Past Due',
      'Unpaid',
      'Unknown',
    ];

    return _dropdownBox(
      width: 190,
      icon:
          Icons.filter_alt_rounded,
      child: DropdownButton<String>(
        value: selectedStatus,
        isExpanded: true,
        isDense: true,
        style: const TextStyle(
          fontSize: 12,
          color: textDark,
        ),
        underline:
            const SizedBox.shrink(),
        items: statuses.map(
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
            selectedStatus = value;
          });
        },
      ),
    );
  }

  Widget _dropdownBox({
    required double width,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: width,
      height: 46,
      padding:
          const EdgeInsets.symmetric(
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
          Icon(
            icon,
            size: 18,
            color: orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: child,
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
      padding:
          const EdgeInsets.symmetric(
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
                  style:
                      const TextStyle(
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
                  style:
                      const TextStyle(
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

  Widget _buildSubscriptionsTable(
    List<Map<String, dynamic>>
        visibleSubscriptions,
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            minWidth: 1700,
          ),
          child: Column(
            children: [
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: Text(
                        'Workspace',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        'Active Emp.',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        'Plan',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 135,
                      child: Text(
                        'Subscription',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        'Access',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 125,
                      child: Text(
                        'Trial Ends',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        'Period End',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 125,
                      child: Text(
                        'Est. Revenue',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: Text(
                        'Stripe Customer',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 205,
                      child: Text(
                        'Stripe Subscription',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 200,
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

              if (visibleSubscriptions
                  .isEmpty)
                const SizedBox(
                  width: 1700,
                  height: 78,
                  child: Center(
                    child: Text(
                      'No matching subscriptions found.',
                      style: TextStyle(
                        fontSize: 12,
                        color: textGrey,
                      ),
                    ),
                  ),
                ),

              ...visibleSubscriptions.map(
                (item) {
                  final workspace =
                      item['workspace_name']
                              ?.toString() ??
                          '-';

                  final activeEmployees =
                      item['active_employee_count'] ??
                          0;

                  final status =
                      item['display_status']
                              ?.toString() ??
                          'unknown';

                  final rawPlanType =
                      item['plan_type']
                              ?.toString()
                              .toLowerCase() ??
                          '';

                  final planType =
                      rawPlanType == 'with_ai'
                          ? 'with_ai'
                          : rawPlanType == 'without_ai'
                              ? 'without_ai'
                              : 'unassigned';

                  final planPrice =
                      (item['price_per_employee'] as num?)
                              ?.toDouble() ??
                          (item['plan_price'] as num?)
                              ?.toDouble() ??
                          0.0;

                  final access =
                      item['is_active'] != false;

                  final trialEnd =
                      formatDate(
                    item['trial_ends_at'],
                  );

                  final periodEnd =
                      formatDate(
                    item['current_period_end'],
                  );

                  final revenue =
                      item['estimated_revenue'];

                  final customerId =
                      item['stripe_customer_id']
                              ?.toString() ??
                          '-';

                  final stripeSubscription =
                      item['stripe_subscription_id']
                              ?.toString() ??
                          '-';

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration:
                        const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: border,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 200,
                          child: Text(
                            workspace,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            activeEmployees
                                .toString(),
                            style: cellStyle,
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: _planBadge(
                            planType,
                            planPrice,
                          ),
                        ),
                        SizedBox(
                          width: 135,
                          child:
                              _statusBadge(
                            status,
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child:
                              _accessLabel(
                            access,
                          ),
                        ),
                        SizedBox(
                          width: 125,
                          child: Text(
                            trialEnd,
                            style: cellStyle,
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: Text(
                            periodEnd,
                            style: cellStyle,
                          ),
                        ),
                        SizedBox(
                          width: 125,
                          child: Text(
                            _formatMoney(
                              revenue is num ? revenue : 0,
                            ),
                            style: cellStyle,
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: SelectableText(
                            customerId,
                            maxLines: 1,
                            style: cellStyle,
                          ),
                        ),
                        SizedBox(
                          width: 205,
                          child: SelectableText(
                            stripeSubscription,
                            maxLines: 1,
                            style: cellStyle,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  _changeWorkspacePlan(item);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: orange,
                                  side: const BorderSide(
                                    color: orange,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  visualDensity:
                                      VisualDensity.compact,
                                ),
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 15,
                                ),
                                label: const Text(
                                  'Plan',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  _openWorkspaceDetails(item);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  visualDensity:
                                      VisualDensity.compact,
                                ),
                                child: const Text(
                                  'Open',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ],
          ),
        ),
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
          enabled
              ? 'Enabled'
              : 'Disabled',
          style: const TextStyle(
            fontSize: 12,
            color: textDark,
          ),
        ),
      ],
    );
  }

  Widget _planBadge(
    String planType,
    double price,
  ) {
    final isAi = planType == 'with_ai';
    final isWithoutAi = planType == 'without_ai';

    final label = isAi
        ? 'With AI · ${_formatMoney(price)}'
        : isWithoutAi
            ? 'Without AI · ${_formatMoney(price)}'
            : 'Unassigned';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: isAi
              ? const Color(0xFFFFF7ED)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAi
                ? const Color(0xFFFED7AA)
                : border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isAi
                ? const Color(0xFFC2410C)
                : textDark,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final value =
        status.toLowerCase();

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
    } else if (value == 'past_due') {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFFC2410C);
    } else if (value == 'unpaid') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (value == 'cancelled') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF1D4ED8);
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = textGrey;
    }

    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Text(
          status
              .replaceAll('_', ' ')
              .toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight:
                FontWeight.bold,
            color: fg,
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
            'Unable to load subscriptions',
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
            onPressed:
                loadSubscriptions,
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

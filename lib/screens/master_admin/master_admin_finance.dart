import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'master_admin_sidebar.dart';
import 'master_admin_dashboard.dart';
import 'master_admin_workspaces.dart';
import 'master_admin_users.dart';
import 'master_admin_subscriptions.dart';
import 'master_admin_reports.dart';
import 'master_admin_settings.dart';

class MasterAdminFinance extends StatefulWidget {
  const MasterAdminFinance({super.key});

  @override
  State<MasterAdminFinance> createState() =>
      _MasterAdminFinanceState();
}

class _MasterAdminFinanceState
    extends State<MasterAdminFinance> {
  final supabase = Supabase.instance.client;

  static const Color orange = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  bool loading = true;
  String? errorMessage;

  List<Map<String, dynamic>> billingRows = [];

  String searchQuery = '';
  String selectedPlan = 'All Plans';
  String selectedStatus = 'All Statuses';

  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadFinance();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadFinance() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await supabase
          .from('workspace_billing_summary')
          .select()
          .order('workspace_name');

      final rows =
          List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        billingRows = rows;
        loading = false;
      });
    } catch (error) {
      debugPrint(
        'MASTER ADMIN FINANCE ERROR: $error',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = error.toString();
      });
    }
  }

  List<Map<String, dynamic>> get filteredRows {
    return billingRows.where((row) {
      final workspace =
          row['workspace_name']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final plan =
          row['plan_type']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final status =
          row['subscription_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final query =
          searchQuery.trim().toLowerCase();

      if (query.isNotEmpty &&
          !workspace.contains(query) &&
          !plan.contains(query) &&
          !status.contains(query)) {
        return false;
      }

      if (selectedPlan == 'With AI' &&
          plan != 'with_ai') {
        return false;
      }

      if (selectedPlan == 'Without AI' &&
          plan != 'without_ai') {
        return false;
      }

      if (selectedStatus != 'All Statuses') {
        final expected =
            selectedStatus
                .toLowerCase()
                .replaceAll(' ', '_');

        if (status != expected) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double get estimatedMonthlyRevenue {
    double total = 0;

    for (final row in billingRows) {
      final status =
          row['subscription_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      if (status != 'active') {
        continue;
      }

      final amount =
          row['monthly_amount'];

      if (amount is num) {
        total += amount.toDouble();
      }
    }

    return total;
  }

  int get activeBillableEmployees {
    int total = 0;

    for (final row in billingRows) {
      final status =
          row['subscription_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      if (status != 'active') {
        continue;
      }

      final value =
          row['active_employee_count'];

      if (value is num) {
        total += value.toInt();
      }
    }

    return total;
  }

  double get withAiRevenue {
    double total = 0;

    for (final row in billingRows) {
      final status =
          row['subscription_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final plan =
          row['plan_type']
                  ?.toString()
                  .toLowerCase() ??
              '';

      if (status != 'active' ||
          plan != 'with_ai') {
        continue;
      }

      final value = row['monthly_amount'];

      if (value is num) {
        total += value.toDouble();
      }
    }

    return total;
  }

  double get withoutAiRevenue {
    double total = 0;

    for (final row in billingRows) {
      final status =
          row['subscription_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final plan =
          row['plan_type']
                  ?.toString()
                  .toLowerCase() ??
              '';

      if (status != 'active' ||
          plan != 'without_ai') {
        continue;
      }

      final value = row['monthly_amount'];

      if (value is num) {
        total += value.toDouble();
      }
    }

    return total;
  }

  int get activeSubscriptions {
    return billingRows.where((row) {
      return row['subscription_status']
              ?.toString()
              .toLowerCase() ==
          'active';
    }).length;
  }

  String _formatMoney(
    num value, {
    String currency = 'AUD',
  }) {
    final amount = value.toDouble();

    final text =
        amount == amount.roundToDouble()
            ? amount.toStringAsFixed(0)
            : amount.toStringAsFixed(2);

    if (currency.toUpperCase() == 'AUD') {
      return 'A\$$text';
    }

    return '${currency.toUpperCase()} $text';
  }

  String _planName(dynamic value) {
    final plan =
        value?.toString().toLowerCase() ?? '';

    if (plan == 'without_ai') {
      return 'Without AI';
    }

    if (plan == 'with_ai') {
      return 'With AI';
    }

    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Row(
        children: [
          MasterAdminSidebar(
            currentPage: 'finance',

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

            onFinance: () {},

            onReports: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminReports(),
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
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final visible = filteredRows;

    return RefreshIndicator(
      color: orange,
      onRefresh: loadFinance,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Finance',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Monitor ClockMetric revenue, billable employees and workspace billing.',
              style: TextStyle(
                fontSize: 13,
                color: textGrey,
              ),
            ),

            const SizedBox(height: 18),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  title:
                      'Est. Monthly Revenue',
                  value: _formatMoney(
                    estimatedMonthlyRevenue,
                  ),
                  icon:
                      Icons.payments_rounded,
                ),

                _summaryCard(
                  title:
                      'Billable Employees',
                  value:
                      activeBillableEmployees
                          .toString(),
                  icon:
                      Icons.people_alt_rounded,
                ),

                _summaryCard(
                  title:
                      'Active Subscriptions',
                  value:
                      activeSubscriptions
                          .toString(),
                  icon:
                      Icons.credit_card_rounded,
                ),

                _summaryCard(
                  title:
                      'With AI Revenue',
                  value: _formatMoney(
                    withAiRevenue,
                  ),
                  icon:
                      Icons.auto_awesome_rounded,
                ),

                _summaryCard(
                  title:
                      'Without AI Revenue',
                  value: _formatMoney(
                    withoutAiRevenue,
                  ),
                  icon:
                      Icons.schedule_rounded,
                ),
              ],
            ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _searchBox(),
                _planDropdown(),
                _statusDropdown(),
              ],
            ),

            const SizedBox(height: 18),

            _financeTable(visible),
          ],
        ),
      ),
    );
  }

  Widget _searchBox() {
    return SizedBox(
      width: 390,
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
              'Search workspace, plan or status...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: orange,
            size: 19,
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
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

  Widget _planDropdown() {
    const plans = [
      'All Plans',
      'With AI',
      'Without AI',
    ];

    return _dropdownBox(
      width: 180,
      icon: Icons.layers_rounded,
      child: DropdownButton<String>(
        value: selectedPlan,
        isExpanded: true,
        underline:
            const SizedBox.shrink(),
        items: plans.map((plan) {
          return DropdownMenuItem(
            value: plan,
            child: Text(
              plan,
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;

          setState(() {
            selectedPlan = value;
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
      'Past Due',
      'Cancelled',
      'Inactive',
    ];

    return _dropdownBox(
      width: 185,
      icon: Icons.filter_alt_rounded,
      child: DropdownButton<String>(
        value: selectedStatus,
        isExpanded: true,
        underline:
            const SizedBox.shrink(),
        items: statuses.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(
              status,
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
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
      width: 205,
      height: 92,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
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
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFFFEDD5),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: orange,
              size: 20,
            ),
          ),

          const SizedBox(width: 10),

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

                const SizedBox(height: 3),

                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 10.5,
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

  Widget _financeTable(
    List<Map<String, dynamic>> rows,
  ) {
    const headerStyle = TextStyle(
      fontSize: 11,
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
            minWidth: 1050,
          ),
          child: Column(
            children: [
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 245,
                      child: Text(
                        'Workspace',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        'Plan',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 125,
                      child: Text(
                        'Status',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 145,
                      child: Text(
                        'Billable Employees',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        'Price / Employee',
                        style: headerStyle,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        'Monthly Revenue',
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

              if (rows.isEmpty)
                const SizedBox(
                  height: 90,
                  width: 1050,
                  child: Center(
                    child: Text(
                      'No finance records found.',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

              ...rows.map((row) {
                final workspace =
                    row['workspace_name']
                            ?.toString() ??
                        '-';

                final plan =
                    _planName(
                  row['plan_type'],
                );

                final status =
                    row['subscription_status']
                            ?.toString() ??
                        '-';

                final employees =
                    row['active_employee_count'] ??
                        0;

                final currency =
                    row['currency']
                            ?.toString() ??
                        'AUD';

                final price =
                    row['price_per_employee'];

                final monthly =
                    row['monthly_amount'];

                return Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
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
                        width: 245,
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
                        width: 150,
                        child: Text(
                          plan,
                          style: cellStyle,
                        ),
                      ),

                      SizedBox(
                        width: 125,
                        child:
                            _statusBadge(status),
                      ),

                      SizedBox(
                        width: 145,
                        child: Text(
                          employees.toString(),
                          style: cellStyle,
                        ),
                      ),

                      SizedBox(
                        width: 150,
                        child: Text(
                          _formatMoney(
                            price is num
                                ? price
                                : 0,
                            currency:
                                currency,
                          ),
                          style: cellStyle,
                        ),
                      ),

                      SizedBox(
                        width: 150,
                        child: Text(
                          _formatMoney(
                            monthly is num
                                ? monthly
                                : 0,
                            currency:
                                currency,
                          ),
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final value =
        status.toLowerCase();

    Color backgroundColor;
    Color foregroundColor;

    switch (value) {
      case 'active':
        backgroundColor =
            const Color(0xFFDCFCE7);
        foregroundColor =
            const Color(0xFF15803D);
        break;

      case 'trialing':
        backgroundColor =
            const Color(0xFFFEF3C7);
        foregroundColor =
            const Color(0xFFB45309);
        break;

      case 'past_due':
        backgroundColor =
            const Color(0xFFFFEDD5);
        foregroundColor =
            const Color(0xFFC2410C);
        break;

      case 'cancelled':
        backgroundColor =
            const Color(0xFFEFF6FF);
        foregroundColor =
            const Color(0xFF1D4ED8);
        break;

      default:
        backgroundColor =
            const Color(0xFFF3F4F6);
        foregroundColor = textGrey;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Text(
          status
              .replaceAll('_', ' ')
              .toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: foregroundColor,
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
            color: Colors.red,
            size: 42,
          ),

          const SizedBox(height: 12),

          const Text(
            'Unable to load finance data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
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
            onPressed: loadFinance,
            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
            label:
                const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
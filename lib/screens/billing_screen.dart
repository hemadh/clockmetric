import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillingScreen extends StatefulWidget {
  final String workspaceId;

  const BillingScreen({
    super.key,
    required this.workspaceId,
  });

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final supabase = Supabase.instance.client;

  int activeEmployeeCount = 0;


  double billingPricePerEmployee = 5.0;
String billingCurrency = 'AUD';
String subscriptionStatus = 'trialing';

DateTime? trialStartedAt;
DateTime? trialEndsAt;
DateTime? currentPeriodEnd;


bool get isTrialExpired {
  if (trialEndsAt == null) return false;

  return subscriptionStatus == 'trialing' &&
      DateTime.now().isAfter(trialEndsAt!);
}


  @override
void initState() {
  super.initState();
  _loadActiveEmployeeCount();
  _loadBillingDetails();
}

Future<void> _loadActiveEmployeeCount() async {
  try {
    final response = await supabase
        .from('profiles')
        .select('id')
        .eq('workspace_id', widget.workspaceId)
        .eq('approval_status', 'approved')
        .eq('is_active', true)
        .neq('role', 'admin');

    if (!mounted) return;

    setState(() {
      activeEmployeeCount = response.length;
    });
  } catch (e) {
    debugPrint('Billing employee count error: $e');
  }
}

Future<void> _loadBillingDetails() async {
  try {
    final response = await supabase
        .from('workspaces')
        .select(
          'billing_price_per_employee, billing_currency, '
'subscription_status, trial_started_at, trial_ends_at, current_period_end',
        )
        .eq('id', widget.workspaceId)
        .single();

    if (!mounted) return;

    setState(() {
      billingPricePerEmployee =
          (response['billing_price_per_employee'] as num?)?.toDouble() ?? 5.0;

      billingCurrency =
          response['billing_currency']?.toString() ?? 'AUD';

      subscriptionStatus =
          response['subscription_status']?.toString() ?? 'trialing';

      final trialStart = response['trial_started_at']?.toString();
      final trialEnd = response['trial_ends_at']?.toString();

      trialStartedAt =
          trialStart == null ? null : DateTime.tryParse(trialStart);

      trialEndsAt =
          trialEnd == null ? null : DateTime.tryParse(trialEnd);

      final periodEnd = response['current_period_end']?.toString();

currentPeriodEnd =
    periodEnd == null ? null : DateTime.tryParse(periodEnd);
    });
  } catch (e) {
    debugPrint('Billing details error: $e');
  }
}


  static const orange = Color(0xFFF97316);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: const Color(0xFFF9FAFB),
          padding: const EdgeInsets.all(12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: constraints.maxWidth - 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================
                  // HEADER
                  // =========================
                  const Text(
                    'Billing & Subscription',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),

                  const SizedBox(height: 3),

                  const Text(
                    'Manage your subscription, billing information and invoices.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textGrey,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // =========================
                  // CURRENT PLAN
                  // =========================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CURRENT PLAN',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textGrey,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: .8,
                                ),
                              ),

                              const SizedBox(height: 5),

                              const Text(
                                'ClockMetric Standard',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'A\$5',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: orange,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '/ active employee / month',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textGrey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 5),

                              const Text(
                                'Pay only for active employees.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          height: 92,
                          width: 1,
                          color: border,
                        ),

                        const SizedBox(width: 22),

                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
  subscriptionStatus == 'trialing'
      ? 'TRIAL'
      : subscriptionStatus == 'active'
          ? 'ACTIVE'
          : subscriptionStatus == 'past_due'
              ? 'PAST DUE'
              : subscriptionStatus == 'cancelled'
                  ? 'CANCELLED'
                  : subscriptionStatus.toUpperCase(),
  style: const TextStyle(
    color: Color(0xFF15803D),
    fontWeight: FontWeight.bold,
    fontSize: 9,
  ),
),
                              ),

                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    color: Color(0xFF22C55E),
                                    size: 19,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
  isTrialExpired
      ? 'Trial ended'
      : subscriptionStatus == 'trialing' && trialEndsAt != null
          ? '${trialEndsAt!.difference(DateTime.now()).inDays.clamp(0, 14)} days left in free trial'
          : subscriptionStatus == 'active'
              ? 'Subscription active'
              : subscriptionStatus == 'past_due'
                  ? 'Payment issue'
                  : subscriptionStatus == 'cancelled'
                      ? 'Subscription cancelled'
                      : 'Subscription status',
  style: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: textDark,
  ),
),
                                ],
                              ),

                              const SizedBox(height: 6),

                              Text(
                                subscriptionStatus == 'active'
    ? 'Your subscription is active.'
    : subscriptionStatus == 'past_due'
        ? 'Please update your payment information.'
        : subscriptionStatus == 'cancelled'
            ? 'Your subscription has been cancelled.'
            : isTrialExpired
                ? 'Your free trial has ended.'
                : 'No payment required during your trial.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // =========================
                  // SUMMARY CARDS
                  // =========================
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          icon: Icons.people_alt_rounded,
                          iconColor: orange,
                          title: 'Active Employees',
                          value: '$activeEmployeeCount',
                          subtitle: 'Employees counted for billing',
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _summaryCard(
                          icon: Icons.calculate_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          title: 'Estimated Monthly Bill',
                          value:
    '${billingCurrency == 'AUD' ? 'A\$' : billingCurrency} '
    '${(activeEmployeeCount * billingPricePerEmployee).toStringAsFixed(0)}',
                          subtitle:
    '${billingCurrency == 'AUD' ? 'A\$' : billingCurrency}'
    '${billingPricePerEmployee.toStringAsFixed(0)} × '
    '$activeEmployeeCount active employees',
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _summaryCard(
                          icon: Icons.credit_card_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Billing Status',
                          value: isTrialExpired
    ? 'Trial Ended'
    : subscriptionStatus == 'trialing'
        ? 'Trial'
    : subscriptionStatus == 'active'
        ? 'Active'
        : subscriptionStatus == 'past_due'
            ? 'Past Due'
            : subscriptionStatus == 'cancelled'
                ? 'Cancelled'
                : subscriptionStatus,
                          subtitle: isTrialExpired
    ? 'Subscription required'
    : subscriptionStatus == 'trialing'
        ? 'No payment required yet'
    : subscriptionStatus == 'active'
        ? 'Subscription active'
        : subscriptionStatus == 'past_due'
            ? 'Payment issue requires attention'
            : subscriptionStatus == 'cancelled'
                ? 'Subscription cancelled'
                : 'Subscription status',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =========================
                  // LOWER AREA
                  // =========================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =========================
                      // BILLING DETAILS
                      // =========================
                      Expanded(
                        flex: 6,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Billing Details',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),

                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  Expanded(
                                    child: _detailRow(
                                      icon: Icons.event_rounded,
                                      iconColor: orange,
                                      title: subscriptionStatus == 'cancelled'
    ? 'Access until'
    : subscriptionStatus == 'active' || subscriptionStatus == 'past_due'
        ? 'Next billing date'
        : 'Trial ends',

value: (subscriptionStatus == 'active' ||
            subscriptionStatus == 'past_due' ||
            subscriptionStatus == 'cancelled') &&
        currentPeriodEnd != null
    ? '${currentPeriodEnd!.day.toString().padLeft(2, '0')}/'
      '${currentPeriodEnd!.month.toString().padLeft(2, '0')}/'
      '${currentPeriodEnd!.year}'
    : trialEndsAt == null
        ? 'Not set'
        : '${trialEndsAt!.day.toString().padLeft(2, '0')}/'
          '${trialEndsAt!.month.toString().padLeft(2, '0')}/'
          '${trialEndsAt!.year}',
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: _detailRow(
                                      icon: Icons.autorenew_rounded,
                                      iconColor:
                                          const Color(0xFF8B5CF6),
                                      title: 'Billing cycle',
                                      value: 'Monthly',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              _detailRow(
                                icon: Icons.payment_rounded,
                                iconColor: const Color(0xFF22C55E),
                                title: 'Payment method',
                                value: 'No payment method added',
                              ),

                              const SizedBox(height: 13),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isTrialExpired
    ? 'Your free trial has ended. Please activate a subscription to continue.'
    : subscriptionStatus == 'active'
        ? 'Your subscription is active.'
        : subscriptionStatus == 'past_due'
            ? 'There is a payment issue with your subscription.'
            : subscriptionStatus == 'cancelled'
                ? 'Your subscription has been cancelled.'
                : 'Free trial active — you will not be charged until the trial ends.',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: textDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 11),

                              SizedBox(
                                width: double.infinity,
                                height: 38,
                                child: ElevatedButton.icon(
                                  onPressed: () {
  showDialog(
    context: context,
    builder: (context) {
      final estimatedMonthly =
          activeEmployeeCount * billingPricePerEmployee;

      return AlertDialog(
        title: const Text(
          'Subscription Summary',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogRow(
                'Plan',
                'ClockMetric Standard',
              ),
              _dialogRow(
                'Active employees',
                '$activeEmployeeCount',
              ),
              _dialogRow(
                'Price per employee',
                '${billingCurrency == 'AUD' ? 'A\$' : billingCurrency}'
                    '${billingPricePerEmployee.toStringAsFixed(0)} / month',
              ),
              _dialogRow(
                'Estimated monthly total',
                '${billingCurrency == 'AUD' ? 'A\$' : billingCurrency}'
                    '${estimatedMonthly.toStringAsFixed(0)}',
              ),
              _dialogRow(
                'Subscription status',
                isTrialExpired
                    ? 'Trial ended'
                    : subscriptionStatus == 'trialing'
                        ? 'Trial'
                        : subscriptionStatus,
              ),

              _dialogRow(
  subscriptionStatus == 'cancelled'
      ? 'Access until'
      : subscriptionStatus == 'active' || subscriptionStatus == 'past_due'
          ? 'Billing period ends'
          : 'Trial ends',
  (subscriptionStatus == 'active' ||
              subscriptionStatus == 'past_due' ||
              subscriptionStatus == 'cancelled') &&
          currentPeriodEnd != null
      ? '${currentPeriodEnd!.day.toString().padLeft(2, '0')}/'
        '${currentPeriodEnd!.month.toString().padLeft(2, '0')}/'
        '${currentPeriodEnd!.year}'
      : trialEndsAt != null
          ? '${trialEndsAt!.day.toString().padLeft(2, '0')}/'
            '${trialEndsAt!.month.toString().padLeft(2, '0')}/'
            '${trialEndsAt!.year}'
          : 'Not set',
),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Payment setup is not connected yet. '
                  'Your subscription details are ready, and a payment provider '
                  'can be connected later.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
},
                                  icon: const Icon(
                                    Icons.credit_card_rounded,
                                    size: 17,
                                  ),
                                  label: const Text(
                                    'Manage Subscription',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: orange,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(9),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 7),

                              const Center(
                                child: Text(
                                  '🔒 Secure subscription billing',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: textGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // =========================
                      // RIGHT SIDE
                      // =========================
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            // INVOICES
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Invoices',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textDark,
                                        ),
                                      ),
                                      Text(
                                        'View all',
                                        style: TextStyle(
                                          color: orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(color: border),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(
                                          Icons.receipt_long_rounded,
                                          size: 27,
                                          color: Color(0xFF9CA3AF),
                                        ),

                                        SizedBox(height: 6),

                                        Text(
                                          'No invoices yet',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),

                                        SizedBox(height: 3),

                                        Text(
                                          'Invoices will appear here after billing begins.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // HOW BILLING WORKS
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFED7AA),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: orange,
                                    size: 20,
                                  ),

                                  SizedBox(width: 9),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'How billing works',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),

                                        SizedBox(height: 5),

                                        Text(
                                          'A\$5 per active employee/month.\n'
                                          'Disabled employees stop counting from the next billing cycle.',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: textGrey,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================
  // SUMMARY CARD
  // =========================
  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
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
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: textGrey,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
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

  // =========================
  // DETAIL ROW
  // =========================
  Widget _detailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 17,
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: textGrey,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _dialogRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: textGrey,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
      ],
    ),
  );
}
}
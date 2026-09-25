import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static const double withoutAiPrice = 10.0;
  static const double withAiPrice = 13.0;

  String selectedPlanType = 'with_ai';
  double billingPricePerEmployee = withAiPrice;
  String billingCurrency = 'AUD';
  String subscriptionStatus = 'trialing';

  DateTime? trialStartedAt;
  DateTime? trialEndsAt;
  DateTime? currentPeriodEnd;

  String stripeCustomerId = '';
  String stripeSubscriptionId = '';

  bool loadingBilling = true;
  bool billingActionLoading = false;


  bool get isTrialExpired {
    if (trialEndsAt == null) return false;

    return subscriptionStatus == 'trialing' &&
        DateTime.now().toUtc().isAfter(
              trialEndsAt!.toUtc(),
            );
  }

  bool get subscriptionAccessEnded {
    if (isTrialExpired) return true;

    if (subscriptionStatus == 'expired' ||
        subscriptionStatus == 'unpaid') {
      return true;
    }

    if (subscriptionStatus == 'cancelled' &&
        currentPeriodEnd != null) {
      return DateTime.now().toUtc().isAfter(
            currentPeriodEnd!.toUtc(),
          );
    }

    return false;
  }

  bool get canOpenBillingPortal =>
      stripeCustomerId.isNotEmpty &&
      stripeSubscriptionId.isNotEmpty &&
      (subscriptionStatus == 'active' ||
          subscriptionStatus == 'past_due' ||
          subscriptionStatus == 'cancelled');

  String get planDisplayName =>
      selectedPlanType == 'with_ai'
          ? 'ClockMetric AI'
          : 'ClockMetric Standard';

  String get planShortLabel =>
      selectedPlanType == 'with_ai'
          ? 'With AI'
          : 'Without AI';

  double get selectedPlanPrice =>
      selectedPlanType == 'with_ai'
          ? withAiPrice
          : withoutAiPrice;

  void _selectPlan(String planType) {
    if (canOpenBillingPortal || billingActionLoading) return;

    setState(() {
      selectedPlanType = planType;
      billingPricePerEmployee =
          planType == 'with_ai'
              ? withAiPrice
              : withoutAiPrice;
    });
  }

  String get billingActionLabel {
    if (billingActionLoading) {
      return 'Opening...';
    }

    if (canOpenBillingPortal) {
      return subscriptionStatus == 'past_due'
          ? 'Update Payment'
          : 'Manage Subscription';
    }

    return 'Subscribe Now';
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
          .eq('role', 'employee')
          .eq('approval_status', 'approved')
          .eq('is_active', true);

      if (!mounted) return;

      setState(() {
        activeEmployeeCount = response.length;
      });
    } catch (e) {
      debugPrint('Billing employee count error: $e');
    }
  }

  Future<void> _loadBillingDetails() async {
    if (mounted) {
      setState(() {
        loadingBilling = true;
      });
    }

    try {
      final subscriptionResponse = await supabase
          .from('workspace_subscriptions')
          .select(
            'plan_type, price_per_employee, currency, status, '
            'trial_start, trial_end, current_period_end, '
            'stripe_customer_id, stripe_subscription_id, stripe_price_id',
          )
          .eq('workspace_id', widget.workspaceId)
          .maybeSingle();

      if (!mounted) return;

      final rowPlanType =
          subscriptionResponse?['plan_type']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              'with_ai';

      final normalizedPlanType =
          rowPlanType == 'without_ai'
              ? 'without_ai'
              : 'with_ai';

      final trialStartText =
          subscriptionResponse?['trial_start']?.toString();
      final trialEndText =
          subscriptionResponse?['trial_end']?.toString();
      final periodEndText =
          subscriptionResponse?['current_period_end']?.toString();

      final parsedTrialStart = trialStartText == null
          ? null
          : DateTime.tryParse(trialStartText);
      final parsedTrialEnd = trialEndText == null
          ? null
          : DateTime.tryParse(trialEndText);
      final parsedPeriodEnd = periodEndText == null
          ? null
          : DateTime.tryParse(periodEndText);

      final customerId =
          subscriptionResponse?['stripe_customer_id']
                  ?.toString()
                  .trim() ??
              '';

      final subscriptionId =
          subscriptionResponse?['stripe_subscription_id']
                  ?.toString()
                  .trim() ??
              '';

      var loadedStatus =
          subscriptionResponse?['status']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              'trialing';

      // Until Stripe has actually created a subscription, a workspace
      // with a trial date is still a trial even if old seed/test data
      // says "active".
      if (subscriptionId.isEmpty && parsedTrialEnd != null) {
        loadedStatus = 'trialing';
      }

      setState(() {
        selectedPlanType = normalizedPlanType;
        billingPricePerEmployee =
            normalizedPlanType == 'with_ai'
                ? withAiPrice
                : withoutAiPrice;

        billingCurrency =
            subscriptionResponse?['currency']
                    ?.toString()
                    .trim()
                    .toUpperCase() ??
                'AUD';

        subscriptionStatus = loadedStatus;
        trialStartedAt = parsedTrialStart;
        trialEndsAt = parsedTrialEnd;
        currentPeriodEnd = parsedPeriodEnd;
        stripeCustomerId = customerId;
        stripeSubscriptionId = subscriptionId;
        loadingBilling = false;
      });
    } catch (e) {
      debugPrint('Billing details error: $e');

      if (!mounted) return;

      setState(() {
        loadingBilling = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load billing details: $e',
          ),
        ),
      );
    }
  }


  static const orange = Color(0xFFF97316);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);



  Future<void> _openStripeCheckout() async {
    if (billingActionLoading) return;

    if (activeEmployeeCount <= 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one active employee before subscribing.',
          ),
        ),
      );

      return;
    }

    setState(() {
      billingActionLoading = true;
    });

    try {
      final response = await supabase.functions.invoke(
        'create-checkout-session',
        body: {
          'workspaceId': widget.workspaceId,
          'quantity': activeEmployeeCount,
          'planType': selectedPlanType,
        },
      );

      final data = response.data;

      if (data == null || data['url'] == null) {
        throw Exception(
          'Stripe checkout URL was not returned.',
        );
      }

      final checkoutUrl =
          Uri.parse(data['url'].toString());

      final opened = await launchUrl(
        checkoutUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception(
          'Could not open Stripe Checkout.',
        );
      }
    } catch (e) {
      debugPrint('Stripe checkout error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open payment page: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          billingActionLoading = false;
        });
      }
    }
  }

  Future<void> _openBillingPortal() async {
    if (billingActionLoading) return;

    setState(() {
      billingActionLoading = true;
    });

    try {
      final response = await supabase.functions.invoke(
        'create-billing-portal-session',
        body: {
          'workspaceId': widget.workspaceId,
        },
      );

      final data = response.data;

      if (data == null || data['url'] == null) {
        throw Exception(
          'Stripe billing portal URL was not returned.',
        );
      }

      final portalUrl =
          Uri.parse(data['url'].toString());

      final opened = await launchUrl(
        portalUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception(
          'Could not open Stripe Billing Portal.',
        );
      }
    } catch (e) {
      debugPrint('Stripe portal error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open subscription management: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          billingActionLoading = false;
        });
      }
    }
  }

  Future<void> _handleBillingAction() async {
    if (canOpenBillingPortal) {
      await _openBillingPortal();
      return;
    }

    await _openStripeCheckout();
  }

  Future<void> _refreshBilling() async {
    await Future.wait([
      _loadActiveEmployeeCount(),
      _loadBillingDetails(),
    ]);
  }

  String _money(num value) {
    final amount = value.toDouble();
    final text = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

    if (billingCurrency == 'AUD') {
      return 'A\$$text';
    }

    return '$billingCurrency $text';
  }

  String _dateText(DateTime? value) {
    if (value == null) return 'Not set';

    final local = value.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  int get trialDaysRemaining {
    if (trialEndsAt == null) return 0;

    final now = DateTime.now().toUtc();
    final end = trialEndsAt!.toUtc();

    if (!end.isAfter(now)) return 0;

    final difference = end.difference(now);

    return (difference.inHours / 24).ceil();
  }

  Color get statusBadgeBackground {
    if (subscriptionStatus == 'active') {
      return const Color(0xFFDCFCE7);
    }

    if (subscriptionStatus == 'trialing' &&
        !isTrialExpired) {
      return const Color(0xFFFEF3C7);
    }

    if (subscriptionStatus == 'past_due') {
      return const Color(0xFFFFEDD5);
    }

    if (subscriptionAccessEnded) {
      return const Color(0xFFFEE2E2);
    }

    return const Color(0xFFEFF6FF);
  }

  Color get statusBadgeForeground {
    if (subscriptionStatus == 'active') {
      return const Color(0xFF15803D);
    }

    if (subscriptionStatus == 'trialing' &&
        !isTrialExpired) {
      return const Color(0xFFB45309);
    }

    if (subscriptionStatus == 'past_due') {
      return const Color(0xFFC2410C);
    }

    if (subscriptionAccessEnded) {
      return const Color(0xFFB91C1C);
    }

    return const Color(0xFF1D4ED8);
  }

  String get displaySubscriptionStatus {
    if (isTrialExpired) return 'TRIAL ENDED';

    switch (subscriptionStatus) {
      case 'trialing':
        return 'TRIAL';
      case 'active':
        return 'ACTIVE';
      case 'past_due':
        return 'PAST DUE';
      case 'cancelled':
        return 'CANCELLED';
      case 'unpaid':
        return 'UNPAID';
      case 'expired':
        return 'EXPIRED';
      default:
        return subscriptionStatus
            .replaceAll('_', ' ')
            .toUpperCase();
    }
  }


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
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Billing & Subscription',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight:
                                    FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Manage your subscription, billing information and invoices.',
                              style: TextStyle(
                                fontSize: 12,
                                color: textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh billing',
                        onPressed: loadingBilling
                            ? null
                            : _refreshBilling,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: orange,
                          size: 20,
                        ),
                      ),
                    ],
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
                              Text(
                                canOpenBillingPortal
                                    ? 'CURRENT PLAN'
                                    : 'SELECTED PLAN',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: textGrey,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: .8,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                planDisplayName,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _money(
                                      billingPricePerEmployee,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: orange,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Padding(
                                    padding:
                                        EdgeInsets.only(bottom: 4),
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
                                  color:
                                      statusBadgeBackground,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  displaySubscriptionStatus,
                                  style: TextStyle(
                                    color:
                                        statusBadgeForeground,
                                    fontWeight:
                                        FontWeight.bold,
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
          ? '$trialDaysRemaining days left in free trial'
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
            : subscriptionStatus == 'unpaid'
                ? 'Payment is required to restore access.'
                : subscriptionStatus == 'expired'
                    ? 'Your subscription has expired.'
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

                  if (!canOpenBillingPortal) ...[
                    Container(
                      width: double.infinity,
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
                            'CHOOSE YOUR PLAN',
                            style: TextStyle(
                              fontSize: 10,
                              color: textGrey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'You can choose a plan before continuing to secure payment.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: textGrey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _planOption(
                                  planType: 'without_ai',
                                  title: 'Without AI',
                                  price: withoutAiPrice,
                                  subtitle:
                                      'Time tracking, screenshots and reports',
                                  icon: Icons.timer_outlined,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _planOption(
                                  planType: 'with_ai',
                                  title: 'With AI',
                                  price: withAiPrice,
                                  subtitle:
                                      'Includes AI activity summaries and insights',
                                  icon: Icons.auto_awesome_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                          value: _money(
                            activeEmployeeCount *
                                billingPricePerEmployee,
                          ),
                          subtitle:
                              '${_money(billingPricePerEmployee)} × '
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
                : subscriptionStatus == 'unpaid'
                    ? 'Payment required'
                    : subscriptionStatus == 'expired'
                        ? 'Subscription expired'
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
            subscriptionStatus == 'cancelled')
        ? _dateText(currentPeriodEnd)
        : _dateText(trialEndsAt),
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
                                value: stripeCustomerId.isEmpty
                                    ? 'Not added yet'
                                    : 'Managed securely in Stripe',
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
                ? currentPeriodEnd != null &&
                        DateTime.now().toUtc().isBefore(
                              currentPeriodEnd!.toUtc(),
                            )
                    ? 'Your subscription is cancelled. Access remains available until ${_dateText(currentPeriodEnd)}.'
                    : 'Your subscription has ended.'
                : subscriptionStatus == 'unpaid'
                    ? 'Payment is required before ClockMetric access can continue.'
                    : subscriptionStatus == 'expired'
                        ? 'Your subscription has expired. Subscribe to restore access.'
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
                                  onPressed: billingActionLoading
                                      ? null
                                      : _handleBillingAction,
                                  icon: const Icon(
                                    Icons.credit_card_rounded,
                                    size: 17,
                                  ),
                                  label: Text(
                                    billingActionLabel,
                                    style: const TextStyle(
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
                                      TextButton(
                                        onPressed:
                                            canOpenBillingPortal &&
                                                    !billingActionLoading
                                                ? _openBillingPortal
                                                : null,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize:
                                              const Size(0, 28),
                                          visualDensity:
                                              VisualDensity.compact,
                                        ),
                                        child: const Text(
                                          'View in Stripe',
                                          style: TextStyle(
                                            color: orange,
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
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
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      const Color(0xFFFED7AA),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'How billing works',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '$planShortLabel: ${_money(billingPricePerEmployee)} per active employee/month.\n'
                                          'Disabled employees stop counting from the next billing cycle.',
                                          style:
                                              const TextStyle(
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

  Widget _planOption({
    required String planType,
    required String title,
    required double price,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = selectedPlanType == planType;

    return InkWell(
      onTap: billingActionLoading
          ? null
          : () => _selectPlan(planType),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFF7ED)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? orange : border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFEDD5)
                    : Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                color: selected ? orange : textGrey,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: orange,
                          size: 17,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_money(price)} / active employee / month',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: textGrey,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
}

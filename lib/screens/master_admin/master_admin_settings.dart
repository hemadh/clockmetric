import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'master_admin_sidebar.dart';
import 'master_admin_dashboard.dart';
import 'master_admin_workspaces.dart';
import 'master_admin_users.dart';
import 'master_admin_subscriptions.dart';
import 'master_admin_reports.dart';
import 'master_admin_finance.dart';

class MasterAdminSettings extends StatefulWidget {
  const MasterAdminSettings({super.key});

  @override
  State<MasterAdminSettings> createState() =>
      _MasterAdminSettingsState();
}

class _MasterAdminSettingsState
    extends State<MasterAdminSettings> {
  final supabase = Supabase.instance.client;

  static const Color orange = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  final TextEditingController searchController =
      TextEditingController();

  final TextEditingController priceController =
      TextEditingController();
  final TextEditingController trialDaysController =
      TextEditingController();
  final TextEditingController currencyController =
      TextEditingController();

  String searchQuery = '';

  bool loadingSettings = true;
  bool editingPlatformSettings = false;
  bool actionLoading = false;

  String? settingsError;

  Map<String, dynamic> platformSettings = {};

  String get currentEmail =>
      supabase.auth.currentUser?.email ?? '-';

  @override
  void initState() {
    super.initState();
    loadPlatformSettings();
  }

  @override
  void dispose() {
    searchController.dispose();
    priceController.dispose();
    trialDaysController.dispose();
    currencyController.dispose();
    super.dispose();
  }

  Future<void> loadPlatformSettings() async {
    if (!mounted) return;

    setState(() {
      loadingSettings = true;
      settingsError = null;
    });

    try {
      final row = await supabase
          .from('platform_settings')
          .select(
            'id, platform_name, price_per_active_employee, '
            'default_trial_days, currency, updated_at',
          )
          .eq('id', 1)
          .maybeSingle();

      if (row == null) {
        throw Exception(
          'Platform settings row could not be found.',
        );
      }

      final settings =
          Map<String, dynamic>.from(row);

      if (!mounted) return;

      setState(() {
        platformSettings = settings;
        _fillPlatformControllers(settings);
        loadingSettings = false;
      });
    } catch (error) {
      debugPrint(
        'MASTER ADMIN PLATFORM SETTINGS ERROR: $error',
      );

      if (!mounted) return;

      setState(() {
        loadingSettings = false;
        settingsError = error.toString();
      });
    }
  }

  void _fillPlatformControllers(
    Map<String, dynamic> settings,
  ) {
    final price =
        settings['price_per_active_employee'];

    if (price is num) {
      priceController.text =
          price.toDouble().toStringAsFixed(2);
    } else {
      priceController.text =
          price?.toString() ?? '5.00';
    }

    trialDaysController.text =
        settings['default_trial_days']
                ?.toString() ??
            '14';

    currencyController.text =
        settings['currency']
                ?.toString()
                .toUpperCase() ??
            'AUD';
  }

  Future<void> savePlatformSettings() async {
    if (actionLoading) return;

    final price = double.tryParse(
      priceController.text.trim(),
    );

    final trialDays = int.tryParse(
      trialDaysController.text.trim(),
    );

    final currency =
        currencyController.text.trim().toUpperCase();

    if (price == null || price < 0) {
      _showError(
        'Enter a valid price of 0 or more.',
      );
      return;
    }

    if (trialDays == null || trialDays < 0) {
      _showError(
        'Enter valid trial days of 0 or more.',
      );
      return;
    }

    if (currency.length != 3) {
      _showError(
        'Currency must be a 3-letter code, for example AUD.',
      );
      return;
    }

    setState(() {
      actionLoading = true;
    });

    try {
      await supabase
          .from('platform_settings')
          .update({
            'price_per_active_employee': price,
            'default_trial_days': trialDays,
            'currency': currency,
            'updated_at':
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', 1);

      await loadPlatformSettings();

      if (!mounted) return;

      setState(() {
        editingPlatformSettings = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Platform settings saved.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        'Unable to save platform settings: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  void cancelPlatformEditing() {
    _fillPlatformControllers(platformSettings);

    setState(() {
      editingPlatformSettings = false;
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _matches(String text) {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) return true;

    return text.toLowerCase().contains(query);
  }

  bool get showAccount =>
      _matches(
        'account master admin email password security',
      );

  bool get showPlatform =>
      _matches(
        'platform clockmetric pricing billing price employee '
        'subscription trial currency aud settings',
      );

  bool get showSecurity =>
      _matches(
        'security session password authentication sign out logout',
      );

  Future<void> _showChangePasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    bool hidePassword = true;
    bool hideConfirm = true;
    String? dialogError;

    final newPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Change Password',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 390,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: hideConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              hideConfirm = !hideConfirm;
                            });
                          },
                          icon: Icon(
                            hideConfirm
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dialogError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
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
                FilledButton(
                  onPressed: () {
                    final password =
                        passwordController.text.trim();

                    final confirm =
                        confirmController.text.trim();

                    if (password.length < 6) {
                      setDialogState(() {
                        dialogError =
                            'Password must be at least 6 characters.';
                      });
                      return;
                    }

                    if (password != confirm) {
                      setDialogState(() {
                        dialogError =
                            'Passwords do not match.';
                      });
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      password,
                    );
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    confirmController.dispose();

    if (newPassword == null ||
        newPassword.isEmpty) {
      return;
    }

    setState(() {
      actionLoading = true;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password updated successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        'Unable to update password: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text(
            'You will be signed out of the Master Admin account.',
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
              child: const Text('Logout'),
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
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
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
    return Scaffold(
      backgroundColor: background,
      body: Row(
        children: [
          MasterAdminSidebar(
            currentPage: 'settings',
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
            onReports: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminReports(),
                ),
              );
            },
            onSettings: () {},
            onLogout: _logout,
          ),
          Expanded(
            child: RefreshIndicator(
              color: orange,
              onRefresh: loadPlatformSettings,
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage Master Admin account and platform settings.',
                      style: TextStyle(
                        fontSize: 13,
                        color: textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _searchBox(),

                    const SizedBox(height: 18),

                    if (showAccount)
                      _buildAccountSection(),

                    if (showAccount &&
                        (showPlatform ||
                            showSecurity))
                      const SizedBox(height: 14),

                    if (showPlatform)
                      _buildPlatformSection(),

                    if (showPlatform &&
                        showSecurity)
                      const SizedBox(height: 14),

                    if (showSecurity)
                      _buildSecuritySection(),

                    if (!showAccount &&
                        !showPlatform &&
                        !showSecurity)
                      _buildNoResults(),
                  ],
                ),
              ),
            ),
          ),
        ],
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
              'Search settings, billing, password, security...',
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

  Widget _buildAccountSection() {
    return _sectionCard(
      title: 'Master Admin Account',
      icon: Icons.person_rounded,
      child: Column(
        children: [
          _settingRow(
            title: 'Email',
            subtitle:
                'Signed-in Master Admin account',
            value: currentEmail,
            icon: Icons.email_rounded,
          ),
          const Divider(
            height: 1,
            color: border,
          ),
          _settingRow(
            title: 'Password',
            subtitle:
                'Update the password for this account',
            value: 'Change password',
            icon: Icons.lock_rounded,
            trailing: OutlinedButton(
              onPressed: actionLoading
                  ? null
                  : _showChangePasswordDialog,
              child: const Text(
                'Change',
                style: TextStyle(
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformSection() {
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 13,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFFEDD5),
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Platform Settings',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const Spacer(),

                if (loadingSettings)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: orange,
                    ),
                  )
                else if (!editingPlatformSettings)
                  OutlinedButton.icon(
                    onPressed: settingsError != null
                        ? null
                        : () {
                            setState(() {
                              editingPlatformSettings =
                                  true;
                            });
                          },
                    icon: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                    ),
                    label: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      TextButton(
                        onPressed: actionLoading
                            ? null
                            : cancelPlatformEditing,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: actionLoading
                            ? null
                            : savePlatformSettings,
                        icon: actionLoading
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_rounded,
                                size: 15,
                              ),
                        label: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: border,
          ),

          if (settingsError != null)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      settingsError!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed:
                        loadPlatformSettings,
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _settingRow(
              title: 'Platform Name',
              subtitle:
                  'Fixed application name',
              value: 'ClockMetric',
              icon: Icons.timer_outlined,
            ),

            const Divider(
              height: 1,
              color: border,
            ),

            _editableSettingRow(
              title: 'Pricing',
              subtitle:
                  'Monthly charge per active employee',
              icon: Icons.payments_rounded,
              controller:
                  priceController,
              prefixText: 'A\$ ',
              suffixText:
                  ' / active employee / month',
              displayValue:
                  'A\$${_displayPrice()} / active employee / month',
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}'),
                ),
              ],
            ),

            const Divider(
              height: 1,
              color: border,
            ),

            _editableSettingRow(
              title: 'Default Trial',
              subtitle:
                  'Trial period for new workspaces',
              icon: Icons.schedule_rounded,
              controller:
                  trialDaysController,
              suffixText: ' days',
              displayValue:
                  '${platformSettings['default_trial_days'] ?? '-'} days',
              keyboardType:
                  TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter
                    .digitsOnly,
              ],
            ),

            const Divider(
              height: 1,
              color: border,
            ),

            _editableSettingRow(
              title: 'Currency',
              subtitle:
                  'Billing currency',
              icon:
                  Icons.currency_exchange_rounded,
              controller:
                  currencyController,
              displayValue:
                  platformSettings['currency']
                          ?.toString()
                          .toUpperCase() ??
                      '-',
              maxLength: 3,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp('[a-zA-Z]'),
                ),
                LengthLimitingTextInputFormatter(
                  3,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _displayPrice() {
    final value =
        platformSettings['price_per_active_employee'];

    if (value is num) {
      final doublePrice =
          value.toDouble();

      if (doublePrice ==
          doublePrice.roundToDouble()) {
        return doublePrice
            .toStringAsFixed(0);
      }

      return doublePrice
          .toStringAsFixed(2);
    }

    return value?.toString() ?? '-';
  }

  Widget _editableSettingRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required TextEditingController controller,
    required String displayValue,
    String? prefixText,
    String? suffixText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 11,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: textGrey,
          ),
          const SizedBox(width: 12),

          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: textGrey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            flex: 4,
            child: editingPlatformSettings
                ? SizedBox(
                    height: 40,
                    child: TextField(
                      controller: controller,
                      keyboardType:
                          keyboardType,
                      inputFormatters:
                          inputFormatters,
                      maxLength: maxLength,
                      textCapitalization:
                          title == 'Currency'
                              ? TextCapitalization
                                  .characters
                              : TextCapitalization
                                  .none,
                      textAlign:
                          TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: textDark,
                      ),
                      decoration:
                          InputDecoration(
                        counterText: '',
                        prefixText:
                            prefixText,
                        suffixText:
                            suffixText,
                        isDense: true,
                        filled: true,
                        fillColor:
                            background,
                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(9),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(9),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(9),
                          borderSide:
                              const BorderSide(
                            color: orange,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  )
                : Text(
                    displayValue,
                    textAlign:
                        TextAlign.right,
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
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return _sectionCard(
      title: 'Security & Session',
      icon:
          Icons.security_rounded,
      child: Column(
        children: [
          _settingRow(
            title: 'Authentication',
            subtitle:
                'Master Admin access is protected by Supabase Auth',
            value: 'Enabled',
            icon:
                Icons.verified_user_rounded,
          ),
          const Divider(
            height: 1,
            color: border,
          ),
          _settingRow(
            title: 'Logout',
            subtitle:
                'Sign out of the Master Admin account',
            value: 'Sign out',
            icon:
                Icons.logout_rounded,
            danger: true,
            trailing: OutlinedButton(
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.red,
              ),
              onPressed: actionLoading
                  ? null
                  : _logout,
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 13,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFFEDD5),
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    color: orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            color: border,
          ),
          child,
        ],
      ),
    );
  }

  Widget _settingRow({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    Widget? trailing,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: danger
                ? Colors.red
                : textGrey,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                    color: danger
                        ? Colors.red
                        : textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color: textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
                color: danger
                    ? Colors.red
                    : textDark,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 14),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: border,
        ),
      ),
      child: const Center(
        child: Text(
          'No matching settings found.',
          style: TextStyle(
            fontSize: 12,
            color: textGrey,
          ),
        ),
      ),
    );
  }
}

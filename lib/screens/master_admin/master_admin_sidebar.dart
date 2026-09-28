import 'package:flutter/material.dart';

class MasterAdminSidebar extends StatelessWidget {
  final String currentPage;

  final VoidCallback onDashboard;
  final VoidCallback onWorkspaces;
  final VoidCallback onUsers;
  final VoidCallback onSubscriptions;
  final VoidCallback? onFinance;
  final VoidCallback onReports;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const MasterAdminSidebar({
    super.key,
    required this.currentPage,
    required this.onDashboard,
    required this.onWorkspaces,
    required this.onUsers,
    required this.onSubscriptions,
    this.onFinance,
    required this.onReports,
    required this.onSettings,
    required this.onLogout,
  });

  static const Color orange = Color(0xFFF97316);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: border,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 22),

          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: orange,
              borderRadius: BorderRadius.circular(21),
              boxShadow: [
                BoxShadow(
                  color: orange.withValues(alpha: 0.14),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'ClockMetric',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),

          const SizedBox(height: 3),

          const Text(
            'MASTER ADMIN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: orange,
              letterSpacing: 1.0,
            ),
          ),

          const SizedBox(height: 24),

          _menuItem(
            icon: Icons.dashboard_rounded,
            title: 'Dashboard',
            active: currentPage == 'dashboard',
            onTap: onDashboard,
          ),

          _menuItem(
            icon: Icons.business_rounded,
            title: 'Workspaces',
            active: currentPage == 'workspaces',
            onTap: onWorkspaces,
          ),

          _menuItem(
            icon: Icons.people_alt_rounded,
            title: 'Users',
            active: currentPage == 'users',
            onTap: onUsers,
          ),

          _menuItem(
            icon: Icons.credit_card_rounded,
            title: 'Subscriptions',
            active: currentPage == 'subscriptions',
            onTap: onSubscriptions,
          ),

          _menuItem(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Finance',
            active: currentPage == 'finance',
            onTap: onFinance,
          ),

          _menuItem(
            icon: Icons.analytics_rounded,
            title: 'Reports',
            active: currentPage == 'reports',
            onTap: onReports,
          ),

          _menuItem(
            icon: Icons.settings_rounded,
            title: 'Settings',
            active: currentPage == 'settings',
            onTap: onSettings,
          ),

          const Spacer(),

          const Divider(
            height: 1,
            color: border,
          ),

          const SizedBox(height: 6),

          _menuItem(
            icon: Icons.logout_rounded,
            title: 'Logout',
            danger: true,
            onTap: onLogout,
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    bool active = false,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 3,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFFEDD5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: danger
                    ? Colors.red
                    : active
                        ? orange
                        : textGrey,
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: danger
                      ? Colors.red
                      : active
                          ? orange
                          : textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
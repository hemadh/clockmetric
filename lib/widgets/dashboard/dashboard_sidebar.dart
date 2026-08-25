import 'package:flutter/material.dart';
import '../../main.dart';

class DashboardSidebar extends StatelessWidget {
  final String workspaceName;
  final String currentPage;
  final bool isAdmin;

  final bool isCollapsed;
  final VoidCallback? onToggle;

  final VoidCallback onDashboard;
  final VoidCallback onTimer;
  final VoidCallback onTimesheet;
  final VoidCallback onScreenshots;
  final VoidCallback? onKeyboardActivity;
  final VoidCallback onLeave;
  final VoidCallback onEmployees;
  final VoidCallback onProjects;
  final VoidCallback onWorkspace;
  final VoidCallback onReports;
  final VoidCallback onApprovals;
  final VoidCallback onBilling;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const DashboardSidebar({
    super.key,
    required this.workspaceName,
    required this.currentPage,
    required this.isAdmin,
    this.isCollapsed = false,
    this.onToggle,
    required this.onDashboard,
    required this.onTimer,
    required this.onTimesheet,
    required this.onScreenshots,
    this.onKeyboardActivity,
    required this.onLeave,
    required this.onEmployees,
    required this.onProjects,
    required this.onWorkspace,
    required this.onReports,
    required this.onApprovals,
    required this.onBilling,
    required this.onChangePassword,
    required this.onLogout,
  });

  static const orange = Color(0xFFF97316);
  static const orangeDark = Color(0xFFEA580C);
  static const orangeLight = Color(0xFFFFEDD5);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: isCollapsed ? 82 : 270,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: border),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            const SizedBox(height: 18),

            // Collapse / Expand button
            Align(
              alignment: isCollapsed
                  ? Alignment.center
                  : Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(
                  right: isCollapsed ? 0 : 12,
                ),
                child: IconButton(
                  tooltip: isCollapsed
                      ? 'Expand sidebar'
                      : 'Collapse sidebar',
                  onPressed: onToggle,
                  icon: Icon(
                    isCollapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: textGrey,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Logo
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isCollapsed ? 48 : 76,
              height: isCollapsed ? 48 : 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [orangeDark, orange],
                ),
                borderRadius: BorderRadius.circular(
                  isCollapsed ? 16 : 24,
                ),
                boxShadow: [
                  BoxShadow(
                    color: orange.withOpacity(.25),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.access_time_filled_rounded,
                color: Colors.white,
                size: isCollapsed ? 27 : 40,
              ),
            ),

            if (!isCollapsed) ...[
              const SizedBox(height: 18),

              const Text(
                'ClockMetric',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),

              const SizedBox(height: 6),

              Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: ValueListenableBuilder<String>(
    valueListenable: currentWorkspaceNameNotifier,
    builder: (context, value, _) {
      final name = value.isEmpty ? workspaceName : value;

      return Text(
        name.isEmpty ? 'Workspace' : name,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: textGrey,
          fontWeight: FontWeight.w600,
        ),
      );
    },
  ),
),
            ],

            SizedBox(height: isCollapsed ? 22 : 30),

            _menuItem(
              icon: Icons.dashboard_rounded,
              title: 'Dashboard',
              active: currentPage == 'dashboard',
              onTap: onDashboard,
            ),

            if (!isAdmin)
  _menuItem(
    icon: Icons.timer_rounded,
    title: 'Timer',
    active: currentPage == 'timer',
    onTap: onTimer,
  ),

            _menuItem(
              icon: Icons.assignment_rounded,
              title: 'Timesheet',
              active: currentPage == 'timesheet',
              onTap: onTimesheet,
            ),

            _menuItem(
              icon: Icons.photo_library_rounded,
              title: 'Screenshots',
              active: currentPage == 'screenshots',
              onTap: onScreenshots,
            ),

            _menuItem(
              icon: Icons.keyboard_alt_rounded,
              title: 'Keyboard Activity',
              active: currentPage == 'keyboard_activity',
              onTap: onKeyboardActivity ?? () {},
            ),

            _menuItem(
              icon: Icons.beach_access_rounded,
              title: 'Leave',
              active: currentPage == 'leave',
              onTap: onLeave,
            ),

            if (isAdmin) ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCollapsed ? 16 : 22,
                  vertical: 18,
                ),
                child: const Divider(),
              ),

              if (!isCollapsed) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ADMIN',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              _menuItem(
                icon: Icons.people_alt_rounded,
                title: 'Employees',
                active: currentPage == 'employees',
                onTap: onEmployees,
              ),

              _menuItem(
                icon: Icons.work_rounded,
                title: 'Projects',
                active: currentPage == 'projects',
                onTap: onProjects,
              ),

              _menuItem(
                icon: Icons.business_rounded,
                title: 'Workspace',
                active: currentPage == 'workspace',
                onTap: onWorkspace,
              ),

              _menuItem(
                icon: Icons.insert_chart_rounded,
                title: 'Reports',
                active: currentPage == 'reports',
                onTap: onReports,
              ),

              _menuItem(
                icon: Icons.fact_check_rounded,
                title: 'Approvals',
                active: currentPage == 'approvals',
                onTap: onApprovals,
              ),
              _menuItem(
  icon: Icons.credit_card_rounded,
  title: 'Billing',
  active: currentPage == 'billing',
  onTap: onBilling,
),
            ],

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 16 : 22,
                vertical: 18,
              ),
              child: const Divider(),
            ),

            _menuItem(
              icon: Icons.password_rounded,
              title: 'Change Password',
              active: currentPage == 'change_password',
              onTap: onChangePassword,
            ),

            _menuItem(
              icon: Icons.logout_rounded,
              title: 'Logout',
              active: false,
              danger: true,
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required bool active,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final item = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 10 : 18,
        vertical: 5,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 8 : 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: active ? orangeLight : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                      active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: danger
                      ? Colors.red
                      : active
                          ? orange
                          : textGrey,
                ),
              ),

              if (!isCollapsed) ...[
                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: danger
                          ? Colors.red
                          : active
                              ? orange
                              : textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(
        message: title,
        waitDuration: const Duration(milliseconds: 300),
        child: item,
      );
    }

    return item;
  }
}
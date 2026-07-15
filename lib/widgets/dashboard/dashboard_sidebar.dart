import 'package:flutter/material.dart';

class DashboardSidebar extends StatelessWidget {
  final String workspaceName;
  final String currentPage;
  final bool isAdmin;

  final VoidCallback onDashboard;
  final VoidCallback onTimer;
  final VoidCallback onTimesheet;
  final VoidCallback onScreenshots;
  final VoidCallback onLeave;
  final VoidCallback onEmployees;
  final VoidCallback onProjects;
  final VoidCallback onWorkspace;
  final VoidCallback onReports;
  final VoidCallback onApprovals;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const DashboardSidebar({
    super.key,
    required this.workspaceName,
    required this.currentPage,
    required this.isAdmin,
    required this.onDashboard,
    required this.onTimer,
    required this.onTimesheet,
    required this.onScreenshots,
    required this.onLeave,
    required this.onEmployees,
    required this.onProjects,
    required this.onWorkspace,
    required this.onReports,
    required this.onApprovals,
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
    return Container(
      width: 270,
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
            const SizedBox(height: 34),

            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [orangeDark, orange],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: orange.withOpacity(.25),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.access_time_filled_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              "Time Tracker Pro",
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),

            const SizedBox(height: 6),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                workspaceName.isEmpty ? "Workspace" : workspaceName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 30),

            _menuItem(
              icon: Icons.dashboard_rounded,
              title: "Dashboard",
              active: currentPage == "dashboard",
              onTap: onDashboard,
            ),
            _menuItem(
              icon: Icons.timer_rounded,
              title: "Timer",
              active: currentPage == "timer",
              onTap: onTimer,
            ),
            _menuItem(
              icon: Icons.assignment_rounded,
              title: "Timesheet",
              active: currentPage == "timesheet",
              onTap: onTimesheet,
            ),
            _menuItem(
              icon: Icons.photo_library_rounded,
              title: "Screenshots",
              active: currentPage == "screenshots",
              onTap: onScreenshots,
            ),
            _menuItem(
              icon: Icons.beach_access_rounded,
              title: "Leave",
              active: currentPage == "leave",
              onTap: onLeave,
            ),

            if (isAdmin) ...[
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                child: Divider(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "ADMIN",
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
              _menuItem(
                icon: Icons.people_alt_rounded,
                title: "Employees",
                active: currentPage == "employees",
                onTap: onEmployees,
              ),
              _menuItem(
                icon: Icons.work_rounded,
                title: "Projects",
                active: currentPage == "projects",
                onTap: onProjects,
              ),
              _menuItem(
                icon: Icons.business_rounded,
                title: "Workspace",
                active: currentPage == "workspace",
                onTap: onWorkspace,
              ),
              _menuItem(
                icon: Icons.insert_chart_rounded,
                title: "Reports",
                active: currentPage == "reports",
                onTap: onReports,
              ),
              _menuItem(
                icon: Icons.fact_check_rounded,
                title: "Approvals",
                active: currentPage == "approvals",
                onTap: onApprovals,
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 18,
              ),
              child: Divider(),
            ),

            _menuItem(
              icon: Icons.password_rounded,
              title: "Change Password",
              active: currentPage == "change_password",
              onTap: onChangePassword,
            ),

            _menuItem(
              icon: Icons.logout_rounded,
              title: "Logout",
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 5,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: active ? orangeLight : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
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
          ),
        ),
      ),
    );
  }
}
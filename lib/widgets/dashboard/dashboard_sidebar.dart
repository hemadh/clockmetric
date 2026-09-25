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
  final VoidCallback? onAiSummary;
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
    this.onAiSummary,
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

  static const Color orange = Color(0xFFF97316);
  static const Color orangeLight = Color(0xFFFFEDD5);

  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  bool get isEmployee =>
      currentUserRole.trim().toLowerCase() == 'employee';

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: isCollapsed ? 82 : 270,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFCF9),
            Color(0xFFFFF4E8),
            Color(0xFFFFF8F2),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: Color(0xFFFFE0C2),
            width: 1,
          ),
          right: BorderSide(
            color: Color(0xFFF97316),
            width: 1.4,
          ),
          bottom: BorderSide(
            color: Color(0xFFFFE0C2),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          bottom: 20,
        ),
        child: Column(
          children: [
            const SizedBox(height: 18),

            // --------------------------------------------------
            // COLLAPSE / EXPAND BUTTON
            // --------------------------------------------------
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

            // --------------------------------------------------
            // CLOCKMETRIC APP ICON
            // CLICKING ICON RETURNS TO DASHBOARD
            // --------------------------------------------------
            Tooltip(
              message: 'Go to Dashboard',
              child: InkWell(
                onTap: onDashboard,
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 220,
                  ),
                  width: isCollapsed ? 46 : 68,
                  height: isCollapsed ? 46 : 68,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const Icon(
                        Icons.access_time_filled_rounded,
                        color: orange,
                        size: 38,
                      );
                    },
                  ),
                ),
              ),
            ),

            // --------------------------------------------------
            // CLOCKMETRIC NAME / WORKSPACE
            // --------------------------------------------------
            if (!isCollapsed) ...[
              const SizedBox(height: 16),

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable:
                      currentWorkspaceNameNotifier,
                  builder: (
                    context,
                    value,
                    _,
                  ) {
                    final name = value.isEmpty
                        ? workspaceName
                        : value;

                    return Text(
                      name.isEmpty
                          ? 'Workspace'
                          : name,
                      textAlign: TextAlign.center,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textGrey,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ],

            if (!isCollapsed) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                ),
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFFFDBA74),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 22),

            // --------------------------------------------------
            // DASHBOARD
            // --------------------------------------------------
            _menuItem(
              icon: Icons.dashboard_rounded,
              title: 'Dashboard',
              active:
                  currentPage == 'dashboard',
              onTap: onDashboard,
            ),

            // --------------------------------------------------
            // TIMER - EMPLOYEE ONLY
            // --------------------------------------------------
            if (isEmployee)
              _menuItem(
                icon: Icons.timer_rounded,
                title: 'Timer',
                active:
                    currentPage == 'timer',
                onTap: onTimer,
              ),

            // --------------------------------------------------
            // TIMESHEET
            // --------------------------------------------------
            _menuItem(
              icon: Icons.assignment_rounded,
              title: 'Timesheet',
              active:
                  currentPage == 'timesheet',
              onTap: onTimesheet,
            ),

            // --------------------------------------------------
            // SCREENSHOTS
            // --------------------------------------------------
            _menuItem(
              icon:
                  Icons.photo_library_rounded,
              title: 'Screenshots',
              active:
                  currentPage == 'screenshots',
              onTap: onScreenshots,
            ),

            // --------------------------------------------------
            // ACTIVITIES
            // --------------------------------------------------
            _menuItem(
              icon: Icons.insights_rounded,
              title: 'Activities',
              active:
                  currentPage ==
                      'keyboard_activity',
              onTap:
                  onKeyboardActivity ?? () {},
            ),

            // --------------------------------------------------
            // AI SUMMARY - ADMIN ONLY
            // --------------------------------------------------
            if (isAdmin)
              _menuItem(
                icon:
                    Icons.auto_awesome_rounded,
                title: 'AI Summary',
                active:
                    currentPage ==
                        'ai_summary',
                onTap: onAiSummary ?? () {},
              ),

            // --------------------------------------------------
            // LEAVE
            // --------------------------------------------------
            _menuItem(
              icon:
                  Icons.beach_access_rounded,
              title: 'Leave',
              active:
                  currentPage == 'leave',
              onTap: onLeave,
            ),

            // --------------------------------------------------
            // ADMIN SECTION
            // --------------------------------------------------
            if (isAdmin) ...[
              Padding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal:
                      isCollapsed ? 16 : 22,
                  vertical: 18,
                ),
                child: const Divider(),
              ),

              if (!isCollapsed) ...[
                const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    horizontal: 30,
                  ),
                  child: Align(
                    alignment:
                        Alignment.centerLeft,
                    child: Text(
                      'ADMIN',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],

              _menuItem(
                icon:
                    Icons.people_alt_rounded,
                title: 'Employees',
                active:
                    currentPage ==
                        'employees',
                onTap: onEmployees,
              ),

              _menuItem(
                icon: Icons.work_rounded,
                title: 'Projects',
                active:
                    currentPage ==
                        'projects',
                onTap: onProjects,
              ),

              _menuItem(
                icon:
                    Icons.business_rounded,
                title: 'Workspace',
                active:
                    currentPage ==
                        'workspace',
                onTap: onWorkspace,
              ),

              _menuItem(
                icon:
                    Icons.insert_chart_rounded,
                title: 'Reports',
                active:
                    currentPage == 'reports',
                onTap: onReports,
              ),

              _menuItem(
                icon:
                    Icons.fact_check_rounded,
                title: 'Approvals',
                active:
                    currentPage ==
                        'approvals',
                onTap: onApprovals,
              ),

              _menuItem(
                icon:
                    Icons.credit_card_rounded,
                title: 'Billing',
                active:
                    currentPage == 'billing',
                onTap: onBilling,
              ),
            ],

            // --------------------------------------------------
            // ACCOUNT SECTION
            // --------------------------------------------------
            Padding(
              padding:
                  EdgeInsets.symmetric(
                horizontal:
                    isCollapsed ? 16 : 22,
                vertical: 18,
              ),
              child: const Divider(),
            ),

            _menuItem(
              icon: Icons.password_rounded,
              title: 'Change Password',
              active:
                  currentPage ==
                      'change_password',
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

  // ==========================================================
  // SIDEBAR MENU ITEM
  // ==========================================================
  Widget _menuItem({
    required IconData icon,
    required String title,
    required bool active,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final item = Padding(
      padding: EdgeInsets.symmetric(
        horizontal:
            isCollapsed ? 10 : 18,
        vertical: 5,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          padding:
              EdgeInsets.symmetric(
            horizontal:
                isCollapsed ? 8 : 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: active
                ? orangeLight
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(18),
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
                  color: active
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
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
                      fontWeight:
                          FontWeight.bold,
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
        waitDuration:
            const Duration(
          milliseconds: 300,
        ),
        child: item,
      );
    }

    return item;
  }
}

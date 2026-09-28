import 'package:flutter/material.dart';

class KPICards extends StatelessWidget {
  final int todayMinutes;
  final int thisWeekMinutes;
  final int lastWeekMinutes;
  final int totalEmployees;
  final int activeProjects;
  final double percentChange;

  const KPICards({
    super.key,
    required this.todayMinutes,
    required this.thisWeekMinutes,
    required this.lastWeekMinutes,
    required this.totalEmployees,
    required this.activeProjects,
    required this.percentChange,
  });

  static const orange = Color(0xFFF97316);
  static const orangeLight = Color(0xFFFFEDD5);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);

  String formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;

    if (h == 0) return "$m min";
    if (m == 0) return "$h hr";
    return "$h hr $m min";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _card(
            icon: Icons.today_rounded,
            title: "Today",
            value: formatHours(todayMinutes),
            subtitle: "Tracked Today",
            positive: true,
          ),
        ),

        const SizedBox(width: 20),

        Expanded(
          child: _card(
            icon: Icons.schedule_rounded,
            title: "This Week",
            value: formatHours(thisWeekMinutes),
            subtitle:
                "${percentChange >= 0 ? "↑" : "↓"} ${percentChange.abs().toStringAsFixed(1)}%",
            positive: percentChange >= 0,
          ),
        ),

        const SizedBox(width: 20),

        Expanded(
          child: _card(
            icon: Icons.calendar_month_rounded,
            title: "Last Week",
            value: formatHours(lastWeekMinutes),
            subtitle: "Previous Week",
            positive: false,
          ),
        ),

        const SizedBox(width: 20),

        Expanded(
          child: _card(
            icon: Icons.groups_rounded,
            title: "Employees",
            value: totalEmployees.toString(),
            subtitle: "Workspace",
            positive: true,
          ),
        ),

        const SizedBox(width: 20),

        Expanded(
          child: _card(
            icon: Icons.folder_copy_rounded,
            title: "Projects",
            value: activeProjects.toString(),
            subtitle: "Active",
            positive: true,
          ),
        ),
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required bool positive,
  }) {
    return Container(
      height: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: orangeLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: orange,
              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 6),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      positive
                          ? Icons.trending_up
                          : Icons.trending_flat,
                      size: 16,
                      color:
                          positive ? Colors.green : Colors.grey,
                    ),

                    const SizedBox(width: 4),

                    Expanded(
                      child: Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              positive ? Colors.green : textGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
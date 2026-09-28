import 'package:flutter/material.dart';

class HeroHeader extends StatelessWidget {
  final String userName;
  final String workspaceName;
  final String greeting;
  final String date;
  final String time;
  final int onlineEmployees;
  final int totalProjects;
  final int notificationCount;
  final VoidCallback onNotificationTap;
  final List<String> notifications;

  const HeroHeader({
    super.key,
    required this.userName,
    required this.workspaceName,
    required this.greeting,
    required this.date,
    required this.time,
    required this.onlineEmployees,
    required this.totalProjects,
    required this.notificationCount,
    required this.onNotificationTap,
    this.notifications = const [],
  });

  static const orange = Color(0xFFF97316);
  static const orangeLight = Color(0xFFFFEDD5);
  static const textDark = Color(0xFF111827);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF7ED),
            Color(0xFFFFEDD5),
            Color(0xFFFFFFFF),
          ],
        ),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: orange.withValues(alpha: .13),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$greeting, $userName 👋",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Here's what's happening in $workspaceName today.",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _pill(Icons.calendar_today_rounded, date),
                    const SizedBox(width: 12),
                    _pill(Icons.access_time_rounded, time),
                  ],
                ),
              ],
            ),
          ),
          _metricBox(Icons.groups_rounded, onlineEmployees.toString(), "Online"),
          const SizedBox(width: 14),
          _metricBox(Icons.folder_rounded, totalProjects.toString(), "Projects"),
          const SizedBox(width: 18),
          _notificationButton(),
          const SizedBox(width: 18),
          CircleAvatar(
            radius: 30,
            backgroundColor: orange,
            child: Text(
              userName.isEmpty ? "U" : userName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationButton() {
    return PopupMenuButton<int>(
      tooltip: "Notifications",
      offset: const Offset(0, 55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      itemBuilder: (_) {
        if (notifications.isEmpty) {
          return const [
            PopupMenuItem(
              enabled: false,
              child: SizedBox(
                width: 320,
                child: Text("No notifications"),
              ),
            ),
          ];
        }

        return notifications.asMap().entries.map((entry) {
          return PopupMenuItem<int>(
            value: entry.key,
            child: SizedBox(
              width: 340,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: orangeLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.notifications_rounded, color: textDark),
          ),
          if (notificationCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: orange,
                child: Text(
                  notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textGrey),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(IconData icon, String value, String label) {
    return Container(
      width: 130,
      height: 112,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: orange, size: 24),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: textDark,
            ),
          ),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
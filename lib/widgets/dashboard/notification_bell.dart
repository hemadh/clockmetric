import 'package:flutter/material.dart';

class NotificationBell extends StatelessWidget {
  final List<String> notifications;

  const NotificationBell({
    super.key,
    required this.notifications,
  });

  static const orange = Color(0xFFF97316);
  static const orangeLight = Color(0xFFFFEDD5);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: "Notifications",
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      itemBuilder: (context) {
        if (notifications.isEmpty) {
          return [
            const PopupMenuItem(
              enabled: false,
              child: Text("No notifications"),
            ),
          ];
        }

        return notifications.asMap().entries.map((entry) {
          return PopupMenuItem<int>(
            value: entry.key,
            child: SizedBox(
              width: 320,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        color: textDark,
                        fontWeight: FontWeight.w600,
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: textDark,
              size: 26,
            ),
          ),
          if (notifications.isNotEmpty)
            Positioned(
              right: -3,
              top: -3,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: orange,
                child: Text(
                  notifications.length.toString(),
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
}
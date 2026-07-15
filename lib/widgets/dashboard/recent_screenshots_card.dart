import 'package:flutter/material.dart';

class RecentScreenshotsCard extends StatelessWidget {
  final List<Map<String, dynamic>> screenshots;

  const RecentScreenshotsCard({
    super.key,
    required this.screenshots,
  });

  static const orange = Color(0xFFF97316);
  static const orangeLight = Color(0xFFFFEDD5);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  String formatTime(dynamic raw) {
    if (raw == null) return "";

    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return "";

    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final displayHour = hour == 0 ? 12 : hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? "PM" : "AM";

    return "$displayHour:$minute $suffix";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.screenshot_monitor_rounded, color: orange),
              SizedBox(width: 8),
              Text(
                "Recent Screenshots",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (screenshots.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No recent screenshot records.",
                  style: TextStyle(color: textGrey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: screenshots.length,
                separatorBuilder: (_, __) => const Divider(height: 18),
                itemBuilder: (_, index) {
                  final item = screenshots[index];

                  final employee =
                      item['employee_name']?.toString() ?? "Employee";

                  final time = formatTime(item['created_at']);

                  return Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: orangeLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.image_rounded,
                          color: orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          employee,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          color: textGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

class LeaderboardCard extends StatelessWidget {
  final Map<String, int> employeeWeeklyMinutes;

  const LeaderboardCard({
    super.key,
    required this.employeeWeeklyMinutes,
  });

  static const orange = Color(0xFFF97316);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  String formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;

    if (h == 0) return "$m min";
    if (m == 0) return "$h hr";
    return "$h hr $m min";
  }

  @override
  Widget build(BuildContext context) {
    final entries = employeeWeeklyMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
              Icon(Icons.emoji_events_rounded, color: orange),
              SizedBox(width: 8),
              Text(
                "Employee Leaderboard",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No leaderboard data available.",
                  style: TextStyle(color: textGrey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 18),
                itemBuilder: (_, index) {
                  final item = entries[index];

                  final medal = index == 0
                      ? "🥇"
                      : index == 1
                          ? "🥈"
                          : index == 2
                              ? "🥉"
                              : "${index + 1}.";

                  return Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          medal,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: orange.withOpacity(.14),
                        child: Text(
                          item.key.isEmpty ? "U" : item.key[0].toUpperCase(),
                          style: const TextStyle(
                            color: orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.key,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      Text(
                        formatHours(item.value),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textGrey,
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
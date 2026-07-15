import 'package:flutter/material.dart';

class RunningTimersCard extends StatelessWidget {
  final List<Map<String, dynamic>> liveEmployees;
  final DateTime now;

  const RunningTimersCard({
    super.key,
    required this.liveEmployees,
    required this.now,
  });

  static const orange = Color(0xFFF97316);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  String runningFor(dynamic rawStart) {
    if (rawStart == null) return "0m";

    final start = DateTime.tryParse(rawStart.toString());
    if (start == null) return "0m";

    final diff = now.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;

    if (h <= 0) return "${m}m";
    return "${h}h ${m}m";
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
              Icon(Icons.timer_rounded, color: orange),
              SizedBox(width: 8),
              Text(
                "Running Timers",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (liveEmployees.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No active timers right now.",
                  style: TextStyle(color: textGrey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: liveEmployees.length,
                separatorBuilder: (_, __) => const Divider(height: 18),
                itemBuilder: (_, index) {
                  final row = liveEmployees[index];
                  final employee = row['employee_name'] ?? 'Employee';
                  final project =
                      row['projects']?['project_name']?.toString() ??
                          'Unknown Project';

                  return Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.toString(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            Text(
                              project,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: textGrey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        runningFor(row['start_time']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: orange,
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
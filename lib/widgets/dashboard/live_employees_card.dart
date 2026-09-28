import 'package:flutter/material.dart';

class LiveEmployeesCard extends StatelessWidget {
  final List<Map<String, dynamic>> liveEmployees;

  const LiveEmployeesCard({
    super.key,
    required this.liveEmployees,
  });

  static const orange = Color(0xFFF97316);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  String runningFor(dynamic rawStart) {
    if (rawStart == null) return "Running";

    final start = DateTime.tryParse(rawStart.toString());
    if (start == null) return "Running";

    final diff = DateTime.now().difference(start);
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
            color: Colors.black.withValues(alpha: .04),
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
              Icon(Icons.people_alt_rounded, color: orange),
              SizedBox(width: 8),
              Text(
                "Live Employees",
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
                  "No employees are currently tracking time.",
                  style: TextStyle(color: textGrey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: liveEmployees.length,
                separatorBuilder: (_, _) => const Divider(height: 18),
                itemBuilder: (_, index) {
                  final row = liveEmployees[index];

                  final name = row['employee_name']?.toString() ?? "Employee";
                  final project =
                      row['projects']?['project_name']?.toString() ??
                          "No Project";

                  return Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: orange.withValues(alpha: .14),
                            child: Text(
                              name.isEmpty ? "U" : name[0].toUpperCase(),
                              style: const TextStyle(
                                color: orange,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              project,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: textGrey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            runningFor(row['start_time']),
                            style: const TextStyle(
                              color: orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "LIVE",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
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
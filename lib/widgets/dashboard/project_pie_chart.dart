import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ProjectPieChart extends StatelessWidget {
  final Map<String, int> projectMinutes;
  final int totalMinutes;

  const ProjectPieChart({
    super.key,
    required this.projectMinutes,
    required this.totalMinutes,
  });

  static const orange = Color(0xFFF97316);
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
    final entries = projectMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.amber,
      Colors.indigo,
    ];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Project Distribution",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),

          const SizedBox(height: 18),

          if (entries.isEmpty || totalMinutes == 0)
            const Expanded(
              child: Center(
                child: Text(
                  "No project data",
                  style: TextStyle(color: textGrey),
                ),
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 165,
                    height: 165,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            centerSpaceRadius: 48,
                            sectionsSpace: 3,
                            sections: List.generate(entries.length, (index) {
                              final item = entries[index];

                              return PieChartSectionData(
                                value: item.value.toDouble(),
                                color: colors[index % colors.length],
                                radius: 35,
                                title: '',
                              );
                            }),
                          ),
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatHours(totalMinutes),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            const Text(
                              "Total",
                              style: TextStyle(
                                color: textGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 22),

                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final item = entries[index];

                        final percent =
                            (item.value / totalMinutes) * 100;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: colors[index % colors.length],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Text(
                                  item.key,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                ),
                              ),

                              Text(
                                "${formatHours(item.value)} (${percent.toStringAsFixed(0)}%)",
                                style: const TextStyle(
                                  color: textGrey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../services/report_service.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  Map<String, int> projectTotals = {};
  Map<String, int> employeeTotals = {};

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    final projectData = await ReportService().getWeeklyByProject();
    final employeeData = await ReportService().getWeeklyByEmployee();

    final Map<String, int> pTotals = {};
    final Map<String, int> eTotals = {};

    for (final item in projectData) {
      final projectId = item['project_id'].toString();
      final minutes = item['duration_minutes'] ?? 0;
      pTotals[projectId] = (pTotals[projectId] ?? 0) + minutes as int;
    }

    for (final item in employeeData) {
      final employee = item['employee_name'] ?? 'Unknown';
      final minutes = item['duration_minutes'] ?? 0;
      eTotals[employee] = (eTotals[employee] ?? 0) + minutes as int;
    }

    setState(() {
      projectTotals = pTotals;
      employeeTotals = eTotals;
    });
  }

  String hoursText(int minutes) {
    return "${(minutes / 60).toStringAsFixed(2)} hrs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Weekly Reports"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Weekly Hours by Employee",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            ...employeeTotals.entries.map(
              (e) => ListTile(
                title: Text(e.key),
                trailing: Text(hoursText(e.value)),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Weekly Hours by Project",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            ...projectTotals.entries.map(
              (e) => ListTile(
                title: Text("Project ID: ${e.key}"),
                trailing: Text(hoursText(e.value)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
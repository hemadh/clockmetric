import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AdminEmployeeWeekSummary {
  final String employeeId;
  final String employeeName;
  final Duration thisWeek;
  final Duration previousWeek;
  final bool isWorking;

  const AdminEmployeeWeekSummary({
    required this.employeeId,
    required this.employeeName,
    required this.thisWeek,
    required this.previousWeek,
    required this.isWorking,
  });
}

class AdminWeeklyOverview extends StatelessWidget {
  final List<AdminEmployeeWeekSummary> employees;

  const AdminWeeklyOverview({
    super.key,
    required this.employees,
  });

  static const Color _orange = Color(0xFFF97316);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  static const List<Color> _chartColors = [
    Color(0xFFF97316),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFF8B5CF6),
    Color(0xFFEAB308),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFF6366F1),
  ];

  String _formatDuration(Duration duration) {
    final safe = duration.isNegative
        ? Duration.zero
        : duration;

    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1020;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: _buildComparisonCard(),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: _buildPieCard(),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildComparisonCard(),
            const SizedBox(height: 20),
            _buildPieCard(),
          ],
        );
      },
    );
  }

  Widget _buildPieCard() {
    final currentEmployees = employees
        .where((employee) => employee.thisWeek.inSeconds > 0)
        .toList();

    final totalSeconds = currentEmployees.fold<int>(
      0,
      (sum, employee) =>
          sum + employee.thisWeek.inSeconds,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFED7AA),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THIS WEEK – EMPLOYEE TIME',
            style: TextStyle(
              color: _darkText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Each employee’s tracked time',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          if (currentEmployees.isEmpty)
            _buildEmptyChart()
          else ...[
            SizedBox(
              height: 290,
              child: PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 3,
                  centerSpaceRadius: 46,
                  sections: List.generate(
                    currentEmployees.length,
                    (index) {
                      final employee =
                          currentEmployees[index];

                      final percentage =
                          totalSeconds <= 0
                              ? 0.0
                              : employee
                                      .thisWeek
                                      .inSeconds /
                                  totalSeconds *
                                  100;

                      final labelFontSize =
                          currentEmployees.length <= 4
                              ? 11.0
                              : currentEmployees.length <= 6
                                  ? 9.5
                                  : 8.0;

                      return PieChartSectionData(
                        color: _chartColors[
                            index %
                                _chartColors.length],
                        value: employee
                            .thisWeek.inSeconds
                            .toDouble(),
                        radius: 82,
                        titlePositionPercentageOffset:
                            0.61,
                        title:
                            '${employee.employeeName}\n'
                            '${_formatDuration(employee.thisWeek)}\n'
                            '${percentage.toStringAsFixed(1)}%',
                        titleStyle: TextStyle(
                          color: Colors.white,
                          fontSize: labelFontSize,
                          height: 1.28,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: List.generate(
                currentEmployees.length,
                (index) {
                  final employee =
                      currentEmployees[index];

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _chartColors[
                              index %
                                  _chartColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${employee.employeeName}  '
                        '${_formatDuration(employee.thisWeek)}',
                        style: const TextStyle(
                          color: _darkText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      height: 390,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 52,
            color: Color(0xFFCBD5E1),
          ),
          SizedBox(height: 12),
          Text(
            'No tracked time this week',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFED7AA),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EMPLOYEE WEEKLY HOURS',
            style: TextStyle(
              color: _darkText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'This week compared with the previous week',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          if (employees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 50,
              ),
              child: Center(
                child: Text(
                  'No employee time data found.',
                  style: TextStyle(
                    color: _secondaryText,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 720,
                child: Column(
                  children: [
                    _buildTableHeader(),
                    const Divider(
                      height: 20,
                      color: _borderColor,
                    ),
                    ...employees.map(
                      _buildEmployeeRow,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      color: _secondaryText,
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    );

    return const Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            'EMPLOYEE',
            style: headerStyle,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'THIS WEEK',
            style: headerStyle,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'PREVIOUS WEEK',
            style: headerStyle,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'CHANGE',
            style: headerStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeRow(
    AdminEmployeeWeekSummary employee,
  ) {
    final difference =
        employee.thisWeek - employee.previousWeek;

    final increased =
        difference.inSeconds >= 0;

    final differenceText =
        _formatDuration(
      Duration(
        seconds: difference.inSeconds.abs(),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: employee.isWorking
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                CircleAvatar(
                  radius: 17,
                  backgroundColor:
                      const Color(0xFFFFE8D5),
                  child: Text(
                    employee.employeeName.isEmpty
                        ? '?'
                        : employee
                            .employeeName[0]
                            .toUpperCase(),
                    style: const TextStyle(
                      color: _orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    employee.employeeName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _darkText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _formatDuration(employee.thisWeek),
              style: const TextStyle(
                color: _darkText,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _formatDuration(employee.previousWeek),
              style: const TextStyle(
                color: _secondaryText,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(
                  increased
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: increased
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    differenceText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: increased
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
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

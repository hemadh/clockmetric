import 'package:flutter/material.dart';

class MiniCalendarCard extends StatelessWidget {
  final DateTime selectedDate;

  const MiniCalendarCard({
    super.key,
    required this.selectedDate,
  });

  static const orange = Color(0xFFF97316);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final firstDay =
        DateTime(selectedDate.year, selectedDate.month, 1);

    final daysInMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0).day;

    final startOffset = firstDay.weekday % 7;

    final List<Widget> cells = [];

    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }

    for (int i = 1; i <= daysInMonth; i++) {
      final today = i == selectedDate.day;

      cells.add(
        Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: today ? orange : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "$i",
            style: TextStyle(
              color: today ? Colors.white : textDark,
              fontWeight:
                  today ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
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
              Icon(Icons.calendar_month, color: orange),
              SizedBox(width: 8),
              Text(
                "Calendar",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}",
            style: const TextStyle(
              color: textGrey,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text("S"),
              Text("M"),
              Text("T"),
              Text("W"),
              Text("T"),
              Text("F"),
              Text("S"),
            ],
          ),

          const SizedBox(height: 8),

          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              children: cells,
            ),
          ),

        ],
      ),
    );
  }
}
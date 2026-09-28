import 'package:flutter/material.dart';

class PendingLeaveCard extends StatelessWidget {
  final int pendingLeaves;

  const PendingLeaveCard({
    super.key,
    required this.pendingLeaves,
  });

  static const orange = Color(0xFFF97316);
  static const orangeLight = Color(0xFFFFEDD5);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

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
              Icon(Icons.beach_access_rounded, color: orange),
              SizedBox(width: 8),
              Text(
                "Pending Leave",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: orangeLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  pendingLeaves.toString(),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: orange,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Request(s) waiting",
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Expanded(
            child: Text(
              "Review employee leave requests from the approvals screen.",
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textGrey,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
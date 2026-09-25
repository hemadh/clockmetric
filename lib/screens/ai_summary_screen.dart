import 'package:flutter/material.dart';

class AiSummaryScreen extends StatelessWidget {
  const AiSummaryScreen({super.key});

  static const Color orange = Color(0xFFF97316);
  static const Color darkText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Summary',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: darkText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AI-generated summaries of employee activity.',
              style: TextStyle(
                fontSize: 14,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFED7AA),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 48,
                    color: orange,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'AI activity summaries will appear here',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'We will connect this page to employee activity and screenshot summaries next.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
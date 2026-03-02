import 'package:flutter/material.dart';
import '../models/disaster_enums.dart';

/// Displays the real-time triage score with colour-coded category.
class TriageScoreDisplay extends StatelessWidget {
  final int score;
  final TriageCategory category;

  const TriageScoreDisplay({
    super.key,
    required this.score,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final colour = category.color;
    final fraction = (score / 255).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colour.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        children: [
          // Score number
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Triyaj Skoru: ',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              Text(
                '$score',
                style: TextStyle(
                  color: colour,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              Text(
                ' / 255',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(colour),
            ),
          ),
          const SizedBox(height: 10),

          // Category label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              category.label,
              style: TextStyle(
                color: colour,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ScoreDisplay extends StatelessWidget {
  final int totalScore;
  final int maxScore;

  const ScoreDisplay({
    super.key,
    required this.totalScore,
    required this.maxScore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'סה"כ',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          textDirection: TextDirection.rtl,
        ),
        Text(
          totalScore.toString(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class ScoreBreakdown extends StatelessWidget {
  final Map<String, int> scores;
  final int maxScorePerField;

  const ScoreBreakdown({
    super.key,
    required this.scores,
    this.maxScorePerField = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'פירוט ניקוד',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            ...scores.entries.map((entry) => _buildScoreRow(
                  context,
                  entry.key,
                  entry.value,
                  maxScorePerField,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(
    BuildContext context,
    String label,
    int score,
    int maxScore,
  ) {
    final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              textDirection: TextDirection.rtl,
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor(percentage),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$score/$maxScore',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
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

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) {
      return Colors.green;
    } else if (percentage >= 60) {
      return Colors.blue;
    } else if (percentage >= 40) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
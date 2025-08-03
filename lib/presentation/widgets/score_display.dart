import 'package:flutter/material.dart';

class ScoreDisplay extends StatelessWidget {
  final int totalScore;
  final int maxScore;
  final bool showPercentage;
  final bool showProgressBar;

  const ScoreDisplay({
    super.key,
    required this.totalScore,
    required this.maxScore,
    this.showPercentage = true,
    this.showProgressBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = maxScore > 0 ? (totalScore / maxScore) * 100 : 0.0;
    final progressValue = maxScore > 0 ? totalScore / maxScore : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getScoreColor(percentage).withValues(alpha: 0.1),
            _getScoreColor(percentage).withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getScoreColor(percentage).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'סה"כ ציון',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textDirection: TextDirection.rtl,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    totalScore.toString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: _getScoreColor(percentage),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    ' / $maxScore',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  if (showPercentage)
                    Text(
                      ' (${percentage.toInt()}%)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                ],
              ),
            ],
          ),
          if (showProgressBar) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getScoreColor(percentage),
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getScoreDescription(percentage),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getScoreColor(percentage),
                        fontWeight: FontWeight.w500,
                      ),
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  '${totalScore.toString().padLeft(2, '0')} נקודות',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 90) {
      return Colors.green;
    } else if (percentage >= 70) {
      return Colors.blue;
    } else if (percentage >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getScoreDescription(double percentage) {
    if (percentage >= 90) {
      return 'מצוין';
    } else if (percentage >= 70) {
      return 'טוב מאוד';
    } else if (percentage >= 50) {
      return 'טוב';
    } else {
      return 'זקוק לשיפור';
    }
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
              'פירוט ציונים',
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
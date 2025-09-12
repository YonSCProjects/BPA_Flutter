import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/google_sheets_service.dart';
import '../../core/theme/app_colors.dart';

/// Widget to indicate when the spreadsheet is read-only (service account owned)
class ReadOnlyIndicator extends StatelessWidget {
  const ReadOnlyIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show if service account ownership is enabled
    if (!AppConfig.useServiceAccount) {
      return const SizedBox.shrink();
    }

    return Consumer<GoogleSheetsService>(
      builder: (context, sheetsService, child) {
        if (!sheetsService.isInitialized) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility,
                size: 16,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'צפייה בלבד',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-width banner to explain read-only mode
class ReadOnlyBanner extends StatelessWidget {
  final VoidCallback? onDismiss;
  
  const ReadOnlyBanner({
    Key? key,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show if service account ownership is enabled
    if (!AppConfig.useServiceAccount) {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      backgroundColor: Colors.blue.shade50,
      content: const Text(
        'הגיליון שלך מוגן מעריכה ידנית. כל השינויים נשמרים אוטומטית דרך האפליקציה.',
        textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 14),
      ),
      leading: Icon(
        Icons.info_outline,
        color: Colors.blue.shade700,
      ),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: const Text('הבנתי'),
          ),
      ],
    );
  }
}

/// Dialog to explain the read-only protection
class ReadOnlyExplanationDialog extends StatelessWidget {
  const ReadOnlyExplanationDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => const ReadOnlyExplanationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('הגנה על הנתונים'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'הגיליון שלך מוגן במצב "צפייה בלבד" כדי:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint('למנוע מחיקה או עריכה בטעות'),
            _buildBulletPoint('להבטיח שהנתונים תמיד מסונכרנים'),
            _buildBulletPoint('לשמור על אחידות בפורמט הנתונים'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'כל השינויים נשמרים אוטומטית דרך האפליקציה',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ניתן לצפות בגיליון ב-Google Sheets אך לא לערוך אותו ישירות.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('סגור'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
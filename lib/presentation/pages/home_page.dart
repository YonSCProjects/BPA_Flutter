import 'package:flutter/material.dart';
import '../../core/constants/hebrew_strings.dart';
import '../../core/theme/hebrew_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(HebrewStrings.appTitle),
      ),
      body: const Padding(
        padding: EdgeInsets.all(HebrewTheme.spacingMedium),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ברוכים הבאים ל-BPApp',
                style: HebrewTheme.hebrewTitleStyle,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: HebrewTheme.spacingLarge),
              Text(
                'מערכת מעקב תלמידים בעברית',
                style: HebrewTheme.hebrewSubtitleStyle,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: HebrewTheme.spacingXLarge),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(HebrewTheme.spacingMedium),
                  child: Column(
                    children: [
                      Text(
                        'שלבי הפיתוח:',
                        style: HebrewTheme.hebrewSubtitleStyle,
                      ),
                      SizedBox(height: HebrewTheme.spacingMedium),
                      Text(
                        '✅ הגדרת פרויקט Flutter\n'
                        '✅ תמיכה מלאה בעברית RTL\n'
                        '✅ תבנית עיצוב עברית\n'
                        '🔄 בשלבי פיתוח: טפסי קלט\n'
                        '⏳ הבא: חיבור Google Sheets',
                        style: HebrewTheme.hebrewBodyStyle,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
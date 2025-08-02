// Basic Flutter widget test for BPApp
// Testing Hebrew RTL support and app initialization

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bpapp/main.dart';

void main() {
  testWidgets('BPApp loads correctly with Hebrew RTL support', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BPApp());

    // Verify that the app title contains Hebrew text
    expect(find.text('BPApp - מעקב תלמידים'), findsOneWidget);
    
    // Verify that Hebrew welcome text is displayed
    expect(find.text('ברוכים הבאים ל-BPApp'), findsOneWidget);
    
    // Verify that Hebrew subtitle is displayed
    expect(find.text('מערכת מעקב תלמידים בעברית'), findsOneWidget);
  });

  testWidgets('Hebrew RTL direction is properly set', (WidgetTester tester) async {
    await tester.pumpWidget(const BPApp());
    
    // Find the Directionality widget and verify RTL direction
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first
    );
    
    expect(directionality.textDirection, TextDirection.rtl);
  });
}
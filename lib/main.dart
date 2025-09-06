import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/hebrew_theme.dart';
import 'core/constants/hebrew_strings.dart';
import 'core/educator_mappings.dart';
import 'services/google_auth_service.dart';
import 'services/google_sheets_service.dart';
import 'services/firebase_data_service.dart';
import 'presentation/providers/form_provider.dart';
import 'presentation/pages/student_form_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize educator mappings from shared preferences
  await EducatorMappings.initialize();
  
  runApp(const BPApp());
}

class BPApp extends StatelessWidget {
  const BPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GoogleAuthService()..initialize(),
        ),
        ChangeNotifierProxyProvider<GoogleAuthService, GoogleSheetsService>(
          create: (context) => GoogleSheetsService(
            context.read<GoogleAuthService>(),
          ),
          update: (context, authService, sheetsService) =>
              sheetsService ?? GoogleSheetsService(authService),
        ),
        ChangeNotifierProvider(
          create: (_) => FirebaseDataService(),
        ),
        ChangeNotifierProvider(
          create: (_) => FormProvider(),
        ),
      ],
      child: MaterialApp(
        title: HebrewStrings.appTitle,
        
        // Hebrew RTL Configuration
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('he', 'IL'), // Hebrew (Israel)
        ],
        locale: const Locale('he', 'IL'),
        
        // RTL Text Direction
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        
        // Hebrew Theme
        theme: HebrewTheme.hebrewThemeData,
        
        // Debug Banner
        debugShowCheckedModeBanner: false,
        
        // Home Page
        home: const StudentFormPage(),
      ),
    );
  }
}
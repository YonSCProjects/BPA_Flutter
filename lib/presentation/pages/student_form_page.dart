import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/google_auth_service.dart';
import '../../services/google_sheets_service.dart';
import '../widgets/hebrew_text_field.dart';
import '../widgets/hebrew_number_picker.dart';
import '../widgets/hebrew_date_picker.dart';
import '../widgets/score_display.dart';
import '../providers/form_provider.dart';
import '../../core/educator_mappings.dart';
import 'educator_settings_page.dart';

class StudentFormPage extends StatefulWidget {
  const StudentFormPage({super.key});

  @override
  State<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<StudentFormPage> {
  final _formKey = GlobalKey<FormState>();
  late GoogleAuthService _authService;
  late GoogleSheetsService _sheetsService;
  late FormProvider _formProvider;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _authService = context.read<GoogleAuthService>();
    _sheetsService = context.read<GoogleSheetsService>();
    _formProvider = context.read<FormProvider>();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeForm();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeForm() async {
    debugPrint('[FORM] _initializeForm called - isAuthenticated: ${_authService.isAuthenticated}');
    
    // Ensure authentication service is fully initialized
    await _authService.initialize();
    debugPrint('[FORM] After auth initialize - isAuthenticated: ${_authService.isAuthenticated}');
    
    if (!_authService.isAuthenticated) {
      debugPrint('[FORM] Not authenticated, prompting sign-in');
      await _promptSignIn();
    }
    
    if (_authService.isAuthenticated && !_sheetsService.isInitialized) {
      debugPrint('[FORM] Authenticated, initializing sheets service');
      await _sheetsService.initialize();
    }
    
    if (_authService.isAuthenticated) {
      debugPrint('[FORM] Initializing form provider with defaults');
      await _formProvider.initializeWithDefaults(_sheetsService);
    }
  }

  Future<void> _promptSignIn() async {
    final shouldSignIn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'נדרשת התחברות',
          textDirection: TextDirection.rtl,
        ),
        content: const Text(
          'יש להתחבר לחשבון גוגל כדי לגשת לגיליונות האלקטרוניים',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('התחבר'),
          ),
        ],
      ),
    );

    if (shouldSignIn == true) {
      debugPrint('[FORM] Starting Google Sign-In process...');
      final success = await _authService.signIn();
      debugPrint('[FORM] Google Sign-In result: $success, isAuthenticated: ${_authService.isAuthenticated}');
      
      if (success && _authService.isAuthenticated) {
        debugPrint('[FORM] Sign-in successful, initializing sheets service...');
        if (!_sheetsService.isInitialized) {
          await _sheetsService.initialize();
        }
        await _formProvider.initializeWithDefaults(_sheetsService);
      } else {
        debugPrint('[FORM] Sign-in failed: ${_authService.error}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _authService.error ?? 'שגיאה בהתחברות',
                textDirection: TextDirection.rtl,
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('תכנית התנהגותית - ניקוד'),
        // Using theme's default app bar color for better contrast
        actions: [
          Consumer<GoogleAuthService>(
            builder: (context, authService, child) {
              if (authService.isAuthenticated) {
                return PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'signout') {
                      await authService.signOut();
                    } else if (value == 'educator_settings') {
                      // Navigate to educator settings page
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EducatorSettingsPage(),
                        ),
                      );
                      // Reload mappings if settings were changed
                      if (result == true) {
                        await EducatorMappings.initialize();
                        setState(() {}); // Refresh UI to show updated indicators
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'educator_settings',
                      child: Row(
                        children: [
                          Icon(Icons.share),
                          SizedBox(width: 8),
                          Text('הגדרות שיתוף למחנכות/ים'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'signout',
                      child: Row(
                        children: [
                          const Icon(Icons.exit_to_app),
                          const SizedBox(width: 8),
                          Text('התנתק (${authService.getUserEmail()})'),
                        ],
                      ),
                    ),
                  ],
                  child: const Icon(Icons.account_circle),
                );
              }
              return IconButton(
                onPressed: () async {
                  debugPrint('Login button pressed');
                  final success = await _authService.signIn();
                  debugPrint('Direct sign-in result: $success');
                  if (success) {
                    debugPrint('Direct sign-in successful, reinitializing...');
                    await _initializeForm();
                  }
                },
                icon: const Icon(Icons.login),
                tooltip: 'התחבר לגוגל',
              );
            },
          ),
        ],
      ),
      body: Consumer3<GoogleAuthService, GoogleSheetsService, FormProvider>(
        builder: (context, authService, sheetsService, formProvider, child) {
          debugPrint('[UI] Building UI - isAuth: ${authService.isAuthenticated}, isLoading: ${authService.isLoading}, currentUser: ${authService.currentUser?.email}');
          
          if (authService.isLoading || sheetsService.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'טוען...',
                    style: TextStyle(fontSize: 16),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            );
          }

          if (!authService.isAuthenticated) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'נדרשת התחברות לחשבון גוגל',
                    style: TextStyle(fontSize: 18),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      debugPrint('[UI] Center login button pressed');
                      debugPrint('[UI] Before sign-in - isAuth: ${authService.isAuthenticated}');
                      final success = await authService.signIn();
                      debugPrint('[UI] Center sign-in result: $success');
                      debugPrint('[UI] After sign-in - isAuth: ${authService.isAuthenticated}');
                      if (success) {
                        debugPrint('[UI] Center sign-in successful, reinitializing...');
                        await _initializeForm();
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('התחבר'),
                  ),
                ],
              ),
            );
          }

          if (authService.error != null || sheetsService.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authService.error ?? sheetsService.error!,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _initializeForm(),
                    child: const Text('נסה שוב'),
                  ),
                ],
              ),
            );
          }

          return _buildForm(formProvider);
        },
      ),
    );
  }

  Widget _buildForm(FormProvider formProvider) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Show recovery message if available
          Consumer<GoogleSheetsService>(
            builder: (context, sheetsService, child) {
              if (sheetsService.recoveryMessage != null) {
                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restore,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sheetsService.recoveryMessage!,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                      IconButton(
                        onPressed: () => sheetsService.clearRecoveryMessage(),
                        icon: Icon(
                          Icons.close,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDateField(formProvider),
                  const SizedBox(height: 16),
                  _buildStudentNameField(formProvider),
                  const SizedBox(height: 16),
                  _buildClassNameField(formProvider),
                  const SizedBox(height: 16),
                  _buildClassNumberField(formProvider),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildScoreFields(formProvider),
                  const SizedBox(height: 24),
                  _buildCommentsField(formProvider),
                  const SizedBox(height: 24),
                  _buildScoreDisplay(formProvider),
                  const SizedBox(height: 100), // Extra space for keyboard
                ],
              ),
            ),
          ),
          _buildBottomSection(formProvider),
        ],
      ),
    );
  }

  Widget _buildDateField(FormProvider formProvider) {
    return HebrewDatePicker(
      label: 'תאריך',
      value: formProvider.currentRecord.date,
      onChanged: (date) {
        formProvider.updateField('date', date);
        _checkForExistingRecord(formProvider);
      },
      isRequired: true,
    );
  }

  Widget _buildStudentNameField(FormProvider formProvider) {
    return HebrewTextField(
      label: 'שם התלמיד',
      value: formProvider.currentRecord.studentName,
      onChanged: (value) {
        formProvider.updateField('studentName', value);
        _checkForExistingRecord(formProvider);
      },
      suggestions: _sheetsService.getStudentSuggestions,
      isRequired: true,
      onSuggestionSelected: (suggestion) {
        formProvider.updateField('studentName', suggestion);
        _checkForExistingRecord(formProvider);
      },
    );
  }

  Widget _buildClassNameField(FormProvider formProvider) {
    final hasEducator = EducatorMappings.hasEducator(formProvider.currentRecord.className);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HebrewTextField(
          label: 'שם הכיתה',
          value: formProvider.currentRecord.className,
          onChanged: (value) {
            formProvider.updateField('className', value);
            _checkForExistingRecord(formProvider);
          },
          suggestions: _sheetsService.getClassSuggestions,
          isRequired: true,
          onSuggestionSelected: (suggestion) {
            formProvider.updateField('className', suggestion);
            _checkForExistingRecord(formProvider);
          },
        ),
        if (hasEducator)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.share,
                  size: 14,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  'הנתונים ישותפו עם המחנך/ת',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildClassNumberField(FormProvider formProvider) {
    return HebrewNumberPicker(
      label: 'מספר השיעור',
      value: formProvider.currentRecord.classNumber,
      onChanged: (value) {
        formProvider.updateField('classNumber', value);
        _checkForExistingRecord(formProvider);
      },
      minValue: 1,
      maxValue: 7,
      isRequired: true,
    );
  }

  Widget _buildScoreFields(FormProvider formProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ניקוד',
          style: Theme.of(context).textTheme.headlineSmall,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: HebrewNumberPicker(
                label: 'כניסה',
                value: formProvider.currentRecord.entry,
                onChanged: (value) => formProvider.updateField('entry', value),
                minValue: 0,
                maxValue: 1,
                isRequired: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HebrewNumberPicker(
                label: 'שהייה',
                value: formProvider.currentRecord.staying,
                onChanged: (value) => formProvider.updateField('staying', value),
                minValue: 0,
                maxValue: 3,
                isRequired: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: HebrewNumberPicker(
                label: 'אווירה',
                value: formProvider.currentRecord.attitude,
                onChanged: (value) => formProvider.updateField('attitude', value),
                minValue: 0,
                maxValue: 2,
                isRequired: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HebrewNumberPicker(
                label: 'ביצוע',
                value: formProvider.currentRecord.performance,
                onChanged: (value) => formProvider.updateField('performance', value),
                minValue: 0,
                maxValue: 2,
                isRequired: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: HebrewNumberPicker(
                label: 'מטרה אישית',
                value: formProvider.currentRecord.personalGoal,
                onChanged: (value) => formProvider.updateField('personalGoal', value),
                minValue: 0,
                maxValue: 2,
                isRequired: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HebrewNumberPicker(
                label: 'בונוס',
                value: formProvider.currentRecord.bonus,
                onChanged: (value) => formProvider.updateField('bonus', value),
                minValue: 0,
                maxValue: 1,
                isRequired: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsField(FormProvider formProvider) {
    return HebrewTextField(
      label: 'הערות',
      value: formProvider.currentRecord.comments,
      onChanged: (value) => formProvider.updateField('comments', value),
      maxLines: 3,
      isRequired: false,
      hintText: 'הערות נוספות (אופציונלי)',
    );
  }

  Widget _buildScoreDisplay(FormProvider formProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: ScoreDisplay(
        totalScore: formProvider.currentRecord.calculateTotalScore(),
        maxScore: 11,
      ),
    );
  }

  Widget _buildBottomSection(FormProvider formProvider) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom, // Add system navigation bar padding
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: formProvider.isLoading ? null : () => formProvider.resetForm(),
                  child: const Text('נקה טופס'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: formProvider.isLoading ? null : () => _saveRecord(formProvider),
                  child: formProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(formProvider.isUpdateMode ? 'עדכן רשומה' : 'שמור רשומה'),
                ),
              ),
            ],
          ),
          if (formProvider.isUpdateMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'מצב עדכון - רשומה קיימת תתעדכן',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                    ),
                textDirection: TextDirection.rtl,
              ),
            ),
        ],
      ),
    );
  }

  void _checkForExistingRecord(FormProvider formProvider) {
    // Cancel any existing timer
    _debounceTimer?.cancel();
    
    // Only proceed if all required fields are filled
    if (formProvider.canCheckForExistingRecord()) {
      debugPrint('🔄 [UI] Debouncing record check (0.5s delay)');
      
      // Set a new timer for 0.5 seconds
      _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        debugPrint('🔄 [UI] Executing debounced record check');
        await formProvider.checkForExistingRecord(_sheetsService);
      });
    } else {
      debugPrint('🔄 [UI] Not all required fields filled - skipping check');
    }
  }

  Future<void> _saveRecord(FormProvider formProvider) async {
    if (_formKey.currentState?.validate() ?? false) {
      final success = await formProvider.saveRecord(_sheetsService);
      
      if (mounted) {
        if (success) {
          // Check if this class has an associated educator
          final className = formProvider.currentRecord.className;
          final hasEducator = EducatorMappings.hasEducator(className);
          
          String message = 'הרשומה נשמרה בהצלחה';
          if (hasEducator) {
            message += '\n✅ נשלח גם למחנך/ת של כיתה $className';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message,
                textDirection: TextDirection.rtl,
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: hasEducator ? 4 : 2),
            ),
          );
          formProvider.resetForm();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'שגיאה בשמירת הרשומה: ${formProvider.error ?? "שגיאה לא ידועה"}',
                textDirection: TextDirection.rtl,
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
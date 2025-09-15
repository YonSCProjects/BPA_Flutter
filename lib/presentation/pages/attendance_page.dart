import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_data_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/attendance_sheet_service.dart';
import '../../services/secretary_service.dart';
import '../../data/models/attendance_record.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final FirebaseDataService _firebaseService = FirebaseDataService();
  late final AttendanceSheetService _attendanceService;
  late final SecretaryService _secretaryService;

  String? _selectedClass;
  List<String> _availableClasses = [];
  Map<String, List<String>> _classStudents = {}; // Class -> List of students
  Map<String, bool> _attendance = {}; // Student name -> present/absent
  Map<String, bool> _lateArrivals = {}; // Student name -> is late arrival
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _userRole;
  bool _hasSubmittedToday = false; // Track if attendance was already submitted today
  String _todayDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<GoogleAuthService>(context, listen: false);
    _attendanceService = AttendanceSheetService(authService);
    _secretaryService = SecretaryService(authService);
    _loadUserRoleAndData();
  }

  Future<void> _loadUserRoleAndData() async {
    setState(() => _isLoading = true);

    try {
      // Get current user
      final authService = Provider.of<GoogleAuthService>(context, listen: false);
      final userEmail = authService.currentUser?.email;

      if (userEmail == null) {
        _showError('משתמש לא מחובר');
        return;
      }

      // Initialize Firebase service first
      debugPrint('🔥 [ATTENDANCE] Initializing Firebase service...');
      final firebaseInitialized = await _firebaseService.initialize();
      if (!firebaseInitialized) {
        debugPrint('⚠️ [ATTENDANCE] Firebase initialization failed or disabled');
      }

      // Check if current user is a secretary and initialize secretary service if needed
      debugPrint('👩‍💼 [ATTENDANCE] Checking if user is secretary...');
      final secretaryInitialized = await _secretaryService.initializeSecretary();
      if (secretaryInitialized) {
        debugPrint('✅ [ATTENDANCE] Secretary services initialized with attendance spreadsheet');
      }

      // Initialize attendance service (will send to secretary's spreadsheet)
      debugPrint('🚀 [ATTENDANCE] Initializing attendance service...');
      await _attendanceService.initialize();

      // Check if initialization was successful
      if (!_attendanceService.isInitialized) {
        debugPrint('❌ [ATTENDANCE] Service initialization failed');
        if (_attendanceService.error != null) {
          debugPrint('❌ [ATTENDANCE] Error: ${_attendanceService.error}');
          _showError(_attendanceService.error!);
        } else {
          _showError('שירות הנוכחות לא הופעל');
        }

        // Check if it's because secretary hasn't created the spreadsheet
        if (_attendanceService.error?.contains('מזכירה') ?? false) {
          _showError('המזכירה צריכה להתחבר תחילה כדי ליצור את גיליון הנוכחות');
        }
        return;
      }

      debugPrint('✅ [ATTENDANCE] Service initialized successfully');

      // Load classes and students
      await _loadClassesAndStudents();
    } catch (e) {
      _showError('שגיאה בטעינת נתונים: $e');
      debugPrint('❌ [ATTENDANCE] Error in _loadUserRoleAndData: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClassesAndStudents() async {
    try {
      debugPrint('📚 [ATTENDANCE] Loading classes and students from Firebase...');

      // Ensure Firebase is initialized
      if (!_firebaseService.isInitialized) {
        debugPrint('⚠️ [ATTENDANCE] Firebase not initialized, initializing now...');
        final initialized = await _firebaseService.initialize();
        if (!initialized) {
          debugPrint('❌ [ATTENDANCE] Firebase initialization failed');
          // Fall back to hardcoded test data if Firebase fails
          _loadTestData();
          return;
        }
      }

      // Get all classes from Firebase
      final classesData = await _firebaseService.getAllClasses();
      final studentsData = await _firebaseService.getAllStudents();

      debugPrint('📊 [ATTENDANCE] Got ${classesData.length} classes and ${studentsData.length} students');

      // Show debug info in UI
      if (classesData.isEmpty && studentsData.isEmpty) {
        debugPrint('⚠️ [ATTENDANCE] No data from Firebase, using test data');
        _showError('אין נתונים מ-Firebase. טוען נתוני בדיקה...');
        _loadTestData();
        return;
      }

      final classes = <String>{};
      final classStudentsMap = <String, List<String>>{};

      // Organize students by class
      for (final student in studentsData) {
        final className = student['className'] ?? '';
        final studentName = student['name'] ?? '';

        if (className.isNotEmpty && studentName.isNotEmpty) {
          classes.add(className);
          classStudentsMap.putIfAbsent(className, () => []).add(studentName);
          debugPrint('  Student: $studentName -> Class: $className');
        }
      }

      // Sort students in each class alphabetically
      for (final studentsList in classStudentsMap.values) {
        studentsList.sort();
      }

      debugPrint('✅ [ATTENDANCE] Found ${classes.length} unique classes');
      for (final className in classes) {
        debugPrint('  Class: $className (${classStudentsMap[className]?.length ?? 0} students)');
      }

      setState(() {
        _availableClasses = classes.toList()..sort();
        _classStudents = classStudentsMap;
      });
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error loading classes and students: $e');
      _showError('שגיאה בטעינת רשימת כיתות: $e');
      // Fall back to test data on error
      _loadTestData();
    }
  }

  void _loadTestData() {
    debugPrint('🧪 [ATTENDANCE] Loading test data for attendance');

    // Test data with Hebrew class names and students
    final testClasses = {
      'תאיר': [
        'ליאם סולומון',
        'אורי כהן',
        'נועה לוי',
        'יועל ישראלי',
      ],
      'נטלי': [
        'איתן דוד',
        'מאיה שמעון',
        'דניאל אברהם',
        'שירה מזרחי',
      ],
      'כיתה ג': [
        'רוני שמש',
        'טל ברק',
        'מיכל גולד',
        'אור סילבר',
      ],
      'כיתה ד': [
        'עומר יעקב',
        'לילך מרדכי',
        'תמר בן דוד',
        'אדם שורץ',
      ],
    };

    setState(() {
      _availableClasses = testClasses.keys.toList()..sort();
      _classStudents = testClasses;
    });

    debugPrint('✅ [ATTENDANCE] Test data loaded: ${_availableClasses.length} classes');
  }

  void _onClassSelected(String? className) {
    if (className == null) return;

    setState(() {
      _selectedClass = className;
      _attendance.clear();

      // Initialize all students as absent by default
      final students = _classStudents[className] ?? [];
      for (final student in students) {
        _attendance[student] = false;
      }
    });
  }

  void _toggleAttendance(String studentName) {
    setState(() {
      _attendance[studentName] = !(_attendance[studentName] ?? false);
    });
  }

  Future<void> _submitAttendance() async {
    if (_selectedClass == null || _attendance.isEmpty) {
      _showError('נא לבחור כיתה ולסמן נוכחות');
      return;
    }

    // Confirm submission
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('אישור שליחת נוכחות'),
        content: Text(
          'לשלוח נוכחות עבור $_selectedClass?\n'
          'נוכחים: ${_attendance.values.where((v) => v).length}\n'
          'חסרים: ${_attendance.values.where((v) => !v).length}'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('שלח'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      debugPrint('📤 [ATTENDANCE] Starting attendance submission...');

      final authService = Provider.of<GoogleAuthService>(context, listen: false);
      final userEmail = authService.currentUser?.email ?? '';

      debugPrint('👤 [ATTENDANCE] User: $userEmail');
      debugPrint('🏫 [ATTENDANCE] Class: $_selectedClass');
      debugPrint('👥 [ATTENDANCE] Students: ${_attendance.length}');

      // Create attendance record
      final record = AttendanceRecord(
        date: DateFormat('dd/MM/yyyy').format(DateTime.now()),
        className: _selectedClass!,
        studentAttendance: Map.from(_attendance),
        submittedBy: userEmail,
        timestamp: DateTime.now(),
      );

      debugPrint('📅 [ATTENDANCE] Date: ${record.date}');
      debugPrint('✅ [ATTENDANCE] Present: ${_attendance.values.where((v) => v).length}');
      debugPrint('❌ [ATTENDANCE] Absent: ${_attendance.values.where((v) => !v).length}');

      // Check if attendance service is initialized
      if (!_attendanceService.isInitialized) {
        debugPrint('⚠️ [ATTENDANCE] Service not initialized, trying to initialize...');
        await _attendanceService.initialize();

        // Check again after initialization attempt
        if (!_attendanceService.isInitialized) {
          debugPrint('❌ [ATTENDANCE] Service initialization failed during submission');
          final error = _attendanceService.error ?? 'שירות הנוכחות לא הופעל';
          _showError(error);
          return;
        }
      }

      // Submit to spreadsheet
      debugPrint('📨 [ATTENDANCE] Submitting to spreadsheet...');
      final success = await _attendanceService.submitAttendance(record);

      if (success) {
        _showSuccess('נוכחות נשלחה בהצלחה!');
        debugPrint('✅ [ATTENDANCE] Submission successful!');

        // Mark as submitted today but keep the class selected for late arrivals
        setState(() {
          _hasSubmittedToday = true;
          // Don't clear the class or attendance - keep them for late arrivals
        });
      } else {
        final error = _attendanceService.error ?? 'שגיאה לא ידועה';
        _showError('שגיאה בשליחת נוכחות: $error');
        debugPrint('❌ [ATTENDANCE] Submission failed: $error');
      }
    } catch (e) {
      _showError('שגיאה: $e');
      debugPrint('🔴 [ATTENDANCE] Exception during submission: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAddLateStudentsDialog() async {
    if (_selectedClass == null) {
      _showError('נא לבחור כיתה תחילה');
      return;
    }

    final students = _classStudents[_selectedClass!] ?? [];
    // Filter out students who are already marked as present
    final absentStudents = students.where((student) =>
      !(_attendance[student] ?? false)
    ).toList();

    if (absentStudents.isEmpty) {
      _showError('כל התלמידים כבר סומנו כנוכחים');
      return;
    }

    // Create a temporary map for late arrivals selection
    Map<String, bool> tempLateArrivals = {};
    for (final student in absentStudents) {
      tempLateArrivals[student] = false;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('הוספת תלמידים מאחרים'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'סמן תלמידים שהגיעו מאוחר:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: absentStudents.length,
                    itemBuilder: (context, index) {
                      final student = absentStudents[index];
                      return CheckboxListTile(
                        title: Text(student),
                        value: tempLateArrivals[student],
                        onChanged: (value) {
                          setDialogState(() {
                            tempLateArrivals[student] = value ?? false;
                          });
                        },
                        secondary: const Icon(
                          Icons.access_time,
                          color: Colors.orange,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _submitLateArrivals(tempLateArrivals);
              },
              child: const Text('עדכן נוכחות'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitLateArrivals(Map<String, bool> lateArrivals) async {
    // Filter only selected late students
    final selectedLateStudents = lateArrivals.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();

    if (selectedLateStudents.isEmpty) {
      _showError('לא נבחרו תלמידים');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Update attendance for late students
      for (final student in selectedLateStudents) {
        _attendance[student] = true;
        _lateArrivals[student] = true;
      }

      // Create a new attendance record with late arrival indicator
      final authService = Provider.of<GoogleAuthService>(context, listen: false);
      final userEmail = authService.currentUser?.email ?? '';

      final record = AttendanceRecord(
        date: _todayDate,
        className: _selectedClass!,
        studentAttendance: Map.from(_attendance),
        submittedBy: userEmail,
        timestamp: DateTime.now(),
        isLateUpdate: true, // Mark as late update
        lateArrivals: Map.from(_lateArrivals), // Include late arrival info
      );

      // Submit the updated attendance
      final success = await _attendanceService.submitAttendance(record);

      if (success) {
        _showSuccess('נוכחות עודכנה בהצלחה - נוספו ${selectedLateStudents.length} תלמידים מאחרים');
        setState(() {
          _hasSubmittedToday = true;
        });
      } else {
        _showError(_attendanceService.error ?? 'שגיאה בעדכון נוכחות');
      }
    } catch (e) {
      _showError('שגיאה בעדכון נוכחות: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('רישום נוכחות'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final students = _selectedClass != null
      ? (_classStudents[_selectedClass!] ?? [])
      : <String>[];

    final presentCount = _attendance.values.where((v) => v).length;
    final totalCount = students.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('רישום נוכחות'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
            // Date display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, dd/MM/yyyy', 'he').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Class dropdown
            DropdownButtonFormField<String>(
              value: _selectedClass,
              decoration: InputDecoration(
                labelText: _availableClasses.isEmpty
                  ? 'טוען כיתות...'
                  : 'בחר כיתה',
                prefixIcon: const Icon(Icons.class_),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              hint: _availableClasses.isEmpty
                ? const Text('אין כיתות זמינות')
                : null,
              items: _availableClasses.isEmpty
                ? null
                : _availableClasses.map((className) {
                    return DropdownMenuItem(
                      value: className,
                      child: Text(className),
                    );
                  }).toList(),
              onChanged: _availableClasses.isEmpty ? null : _onClassSelected,
              disabledHint: Text(
                _availableClasses.isEmpty
                  ? 'אין כיתות במערכת'
                  : 'בחר כיתה',
              ),
            ),
            const SizedBox(height: 16),

            // Attendance summary
            if (_selectedClass != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryItem(
                      'סה"כ תלמידים',
                      totalCount.toString(),
                      Colors.blue,
                    ),
                    _buildSummaryItem(
                      'נוכחים',
                      presentCount.toString(),
                      Colors.green,
                    ),
                    _buildSummaryItem(
                      'חסרים',
                      (totalCount - presentCount).toString(),
                      Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Students list
            Expanded(
              child: _selectedClass == null
                ? const Center(
                    child: Text(
                      'בחר כיתה להצגת רשימת התלמידים',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : students.isEmpty
                  ? const Center(
                      child: Text(
                        'אין תלמידים בכיתה זו',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final studentName = students[index];
                        final isPresent = _attendance[studentName] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPresent ? Colors.green : Colors.grey,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    studentName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isPresent ? Colors.black : Colors.grey,
                                    ),
                                  ),
                                ),
                                // Show late arrival indicator
                                if (_lateArrivals[studentName] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'מאחר',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Checkbox(
                              value: isPresent,
                              onChanged: (_) => _toggleAttendance(studentName),
                              activeColor: Colors.green,
                            ),
                            onTap: () => _toggleAttendance(studentName),
                          ),
                        );
                      },
                    ),
            ),

            // Submit and Late Arrival buttons
            if (_selectedClass != null) ...[
              // Submit button
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitAttendance,
                    icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                    label: Text(
                      _isSubmitting ? 'שולח...' : 'שלח נוכחות',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),

              // Add Late Students button
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _showAddLateStudentsDialog,
                    icon: const Icon(Icons.person_add, color: Colors.orange),
                    label: const Text(
                      'הוספת תלמידים מאחרים',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.orange, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
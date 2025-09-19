import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'google_auth_service.dart';
import 'service_account_sheets_service.dart';
import 'drive_folder_service.dart';
import '../data/models/attendance_record.dart';
import '../config/app_config.dart';

class AttendanceSheetService extends ChangeNotifier {
  static const String attendanceSpreadsheetName = 'BPApp_Attendance';
  static const String attendanceMainSheet = 'סיכום נוכחות';

  final GoogleAuthService _authService;
  final ServiceAccountSheetsService _serviceAccountService = ServiceAccountSheetsService();

  sheets.SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi;
  DriveFolderService? _folderService;
  String? _spreadsheetId;
  Map<String, int?> _classSheetIds = {}; // Class name -> Sheet ID
  Map<String, List<String>> _classStudentHeaders = {}; // Class -> ordered student list

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  AttendanceSheetService(this._authService);

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get spreadsheetId => _spreadsheetId;

  /// Refresh the spreadsheet ID from Firestore
  Future<void> refreshSpreadsheetId() async {
    debugPrint('🔄 [ATTENDANCE] Refreshing spreadsheet ID from Firestore...');
    await _findOrCreateAttendanceSpreadsheet();
    if (_spreadsheetId != null) {
      debugPrint('✅ [ATTENDANCE] Spreadsheet ID refreshed: $_spreadsheetId');
    } else {
      debugPrint('⚠️ [ATTENDANCE] No spreadsheet ID found in Firestore');
    }
    notifyListeners();
  }

  /// Manually set the attendance spreadsheet ID (for debugging/recovery)
  Future<void> manuallySetSpreadsheetId(String spreadsheetId) async {
    debugPrint('🔧 [ATTENDANCE] Manually setting spreadsheet ID: $spreadsheetId');
    _spreadsheetId = spreadsheetId;

    // Try to store it in Firestore
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('config').doc('attendance').set({
        'spreadsheetId': spreadsheetId,
        'manuallySet': true,
        'setBy': _authService.currentUser?.email,
        'setAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ [ATTENDANCE] Manually stored spreadsheet ID in Firestore');
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Failed to store manual spreadsheet ID: $e');
    }

    notifyListeners();
  }

  Future<void> initialize() async {
    _setLoading(true);
    _setError(null);

    try {
      debugPrint('🚀 [ATTENDANCE] Starting attendance service initialization');

      // Initialize service account if enabled
      if (AppConfig.useServiceAccount) {
        debugPrint('🔐 [ATTENDANCE] Attempting to initialize service account');
        try {
          await _serviceAccountService.initialize();
          debugPrint('🔐 [ATTENDANCE] Service account initialized: ${_serviceAccountService.isInitialized}');
        } catch (e) {
          debugPrint('⚠️ [ATTENDANCE] Service account initialization failed: $e');
          debugPrint('🔄 [ATTENDANCE] Will fall back to OAuth');
          // Don't throw, let it fall back to OAuth
        }
      }

      final userEmail = _authService.currentUser?.email;
      if (userEmail == null) {
        throw Exception('משתמש לא מחובר');
      }
      debugPrint('👤 [ATTENDANCE] Current user: $userEmail');

      // Always use service account for attendance to send to secretary's spreadsheet
      // If service account not available, fall back to OAuth
      if (_serviceAccountService.isInitialized && AppConfig.useServiceAccount) {
        debugPrint('🔐 [ATTENDANCE] Using service account for centralized attendance');
        final client = await _serviceAccountService.getAuthenticatedClient();
        if (client != null) {
          _sheetsApi = sheets.SheetsApi(client);
          _driveApi = drive.DriveApi(client);
          _folderService = DriveFolderService(_driveApi!);
          debugPrint('✅ [ATTENDANCE] Service account APIs initialized');
        } else {
          debugPrint('⚠️ [ATTENDANCE] Service account client is null');
        }
      }

      // Fall back to OAuth if service account didn't work
      if (_sheetsApi == null || _driveApi == null) {
        debugPrint('🔑 [ATTENDANCE] Using OAuth for attendance (will create in current user\'s drive)');
        final client = await _authService.getAuthenticatedClient();
        if (client != null) {
          _sheetsApi = sheets.SheetsApi(client);
          _driveApi = drive.DriveApi(client);
          _folderService = DriveFolderService(_driveApi!);
          debugPrint('✅ [ATTENDANCE] OAuth APIs initialized');
        } else {
          debugPrint('❌ [ATTENDANCE] OAuth client is null');
        }
      }

      if (_sheetsApi == null || _driveApi == null) {
        throw Exception('לא ניתן להתחבר לשירותי Google');
      }

      // Find or create the centralized attendance spreadsheet
      debugPrint('🔍 [ATTENDANCE] Finding or creating attendance spreadsheet');
      await _findOrCreateAttendanceSpreadsheet();

      _isInitialized = true;
      debugPrint('✅ [ATTENDANCE] Service initialized successfully - spreadsheet ID: $_spreadsheetId');
    } catch (e, stackTrace) {
      _setError('שגיאה באתחול שירות נוכחות: $e');
      debugPrint('❌ [ATTENDANCE] Initialization error: $e');
      debugPrint('📚 [ATTENDANCE] Stack trace: $stackTrace');
      _isInitialized = false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _findOrCreateAttendanceSpreadsheet() async {
    try {
      debugPrint('🔍 [ATTENDANCE] Looking for secretary\'s attendance spreadsheet in Firestore');

      // First, try to get the attendance spreadsheet ID from Firestore
      final firestore = FirebaseFirestore.instance;
      debugPrint('📂 [ATTENDANCE] Checking config/attendance document...');

      final configDoc = await firestore.collection('config').doc('attendance').get();
      debugPrint('📄 [ATTENDANCE] Document exists: ${configDoc.exists}');

      if (configDoc.exists) {
        final data = configDoc.data();
        debugPrint('📄 [ATTENDANCE] Document data: $data');
        _spreadsheetId = data?['spreadsheetId'];

        if (_spreadsheetId != null) {
          debugPrint('✅ [ATTENDANCE] Found secretary\'s attendance spreadsheet: $_spreadsheetId');
          debugPrint('👤 [ATTENDANCE] Created by: ${data?['createdBy']}');
          debugPrint('📅 [ATTENDANCE] Created at: ${data?['createdAt']}');
          return;
        } else {
          debugPrint('⚠️ [ATTENDANCE] Document exists but spreadsheetId is null');
        }
      } else {
        debugPrint('⚠️ [ATTENDANCE] No config/attendance document found in Firestore');
      }

      // FALLBACK: Try to find the attendance sheet directly in Drive
      if (_driveApi != null) {
        debugPrint('🔍 [ATTENDANCE] Fallback: Searching for BPApp_Attendance in Drive...');
        debugPrint('🔍 [ATTENDANCE] Using Drive API: ${_driveApi != null ? "Initialized" : "NULL"}');
        debugPrint('🔍 [ATTENDANCE] Service account mode: ${_serviceAccountService.isInitialized}');

        _spreadsheetId = await _searchForAttendanceSheetInDrive();

        if (_spreadsheetId != null) {
          debugPrint('✅ [ATTENDANCE] Found attendance sheet in Drive: $_spreadsheetId');

          // Try to store it in Firestore for next time
          try {
            await firestore.collection('config').doc('attendance').set({
              'spreadsheetId': _spreadsheetId,
              'foundInDrive': true,
              'foundBy': _authService.currentUser?.email,
              'foundAt': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ [ATTENDANCE] Stored found sheet ID in Firestore');
          } catch (e) {
            debugPrint('⚠️ [ATTENDANCE] Could not store in Firestore: $e');
          }
          return;
        }
      }

      // If no spreadsheet in Firestore or Drive, secretary needs to log in first
      debugPrint('⚠️ [ATTENDANCE] No attendance spreadsheet found in Firestore or Drive');
      debugPrint('👩‍💼 [ATTENDANCE] Secretary needs to log in first to create the attendance spreadsheet');
      _spreadsheetId = null;

    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error getting attendance spreadsheet: $e');
      _spreadsheetId = null;
    }
  }

  Future<String?> _searchForAttendanceSheetInDrive() async {
    if (_driveApi == null || _folderService == null) return null;

    try {
      debugPrint('🔍 [ATTENDANCE] Starting Drive search for: $attendanceSpreadsheetName');

      // Step 1: Check in BPApp folder first (preferred location)
      debugPrint('📁 [ATTENDANCE] Checking BPApp folder for attendance spreadsheet...');
      final folderSpreadsheets = await _folderService!.findSpreadsheetsInFolder(attendanceSpreadsheetName);

      if (folderSpreadsheets.isNotEmpty) {
        final file = folderSpreadsheets.first;
        debugPrint('✅ [ATTENDANCE] Found attendance spreadsheet in BPApp folder:');
        debugPrint('   ID: ${file.id}');
        debugPrint('   Name: ${file.name}');
        return file.id;
      }

      // Step 2: Check root and shared locations for legacy spreadsheets
      debugPrint('📁 [ATTENDANCE] Checking for legacy attendance spreadsheet...');

      // Try multiple search approaches for backward compatibility
      // Approach 1: Exact name match in any location
      var fileList = await _driveApi!.files.list(
        q: "name='$attendanceSpreadsheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id, name, parents, owners, permissions)',
      );

      // If not found, try approach 2: Contains search
      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('⚠️ [ATTENDANCE] Exact match failed, trying contains search...');
        fileList = await _driveApi!.files.list(
          q: "name contains 'BPApp_Attendance' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
          spaces: 'drive',
          $fields: 'files(id, name, parents, owners, permissions)',
        );
      }

      // If still not found, try approach 3: Just spreadsheets shared with me
      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('⚠️ [ATTENDANCE] Contains search failed, trying shared with me...');
        fileList = await _driveApi!.files.list(
          q: "mimeType='application/vnd.google-apps.spreadsheet' and trashed=false and sharedWithMe",
          spaces: 'drive',
          pageSize: 50,
          $fields: 'files(id, name, parents, owners, permissions)',
        );

        // Manually filter for attendance sheet
        if (fileList.files != null) {
          debugPrint('📋 [ATTENDANCE] Found ${fileList.files!.length} shared spreadsheets');
          final attendanceFiles = fileList.files!.where((f) =>
            f.name != null && f.name!.contains('BPApp_Attendance')
          ).toList();

          if (attendanceFiles.isNotEmpty) {
            fileList.files = attendanceFiles;
            debugPrint('✅ [ATTENDANCE] Found attendance sheet in shared files');
          }
        }
      }

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final file = fileList.files!.first;
        debugPrint('📋 [ATTENDANCE] Found legacy attendance spreadsheet:');
        debugPrint('   ID: ${file.id}');
        debugPrint('   Name: ${file.name}');
        debugPrint('   Owners: ${file.owners?.map((o) => o.emailAddress).join(', ')}');

        // Check if it's not already in the BPApp folder
        final folderId = _folderService!.bpAppFolderId ?? await _folderService!.ensureBPAppFolder();
        final isInFolder = file.parents?.contains(folderId) ?? false;

        if (!isInFolder && folderId != null) {
          // Migrate to BPApp folder
          debugPrint('📁 [ATTENDANCE] Migrating attendance spreadsheet to BPApp folder...');
          final moved = await _folderService!.moveSpreadsheetToFolder(file.id!);
          if (moved) {
            debugPrint('✅ [ATTENDANCE] Successfully migrated attendance spreadsheet to BPApp folder');
          } else {
            debugPrint('⚠️ [ATTENDANCE] Could not migrate spreadsheet, will continue using it in current location');
          }
        }

        // Check if service account has access
        bool hasServiceAccountAccess = false;
        if (file.permissions != null) {
          for (var permission in file.permissions!) {
            if (permission.emailAddress == 'bpapp-service-account@bpapp-firebase-485c1.iam.gserviceaccount.com') {
              hasServiceAccountAccess = true;
              debugPrint('✅ [ATTENDANCE] Service account already has access');
              break;
            }
          }
        }

        if (!hasServiceAccountAccess) {
          debugPrint('⚠️ [ATTENDANCE] Service account doesn\'t have access - will need to be shared');
        }

        return file.id;
      }

      debugPrint('ℹ️ [ATTENDANCE] No attendance spreadsheet found in Drive');
      return null;
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error searching Drive: $e');
      return null;
    }
  }

  Future<void> _createAttendanceSpreadsheet() async {
    if (_sheetsApi == null || _folderService == null) return;

    try {
      // Ensure BPApp folder exists
      final folderId = await _folderService!.ensureBPAppFolder();
      if (folderId == null) {
        throw Exception('Could not create or find BPApp folder');
      }

      debugPrint('📁 [ATTENDANCE] Creating attendance spreadsheet in BPApp folder: $folderId');

      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: attendanceSpreadsheetName,
          locale: 'en_US',
          timeZone: 'Asia/Jerusalem',
        ),
        sheets: [
          sheets.Sheet(
            properties: sheets.SheetProperties(
              title: attendanceMainSheet,
              rightToLeft: true,
              gridProperties: sheets.GridProperties(
                frozenRowCount: 1,
                frozenColumnCount: 1,
              ),
            ),
          ),
        ],
      );

      final response = await _sheetsApi!.spreadsheets.create(spreadsheet);
      _spreadsheetId = response.spreadsheetId!;

      // Move spreadsheet to BPApp folder
      debugPrint('📁 [ATTENDANCE] Moving attendance spreadsheet to BPApp folder...');
      final moved = await _folderService!.moveSpreadsheetToFolder(_spreadsheetId!);
      if (moved) {
        debugPrint('✅ [ATTENDANCE] Attendance spreadsheet created in BPApp folder: $_spreadsheetId');
      } else {
        debugPrint('⚠️ [ATTENDANCE] Created attendance spreadsheet but could not move to folder');
      }

      // Add summary headers
      await _addSummaryHeaders();

      debugPrint('✅ [ATTENDANCE] Created attendance spreadsheet: $_spreadsheetId');
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error creating spreadsheet: $e');
      throw e;
    }
  }

  Future<void> _addSummaryHeaders() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final headers = ['תאריך', 'כיתה', 'נוכחים', 'חסרים', 'סה"כ', 'אחוז נוכחות'];

      final valueRange = sheets.ValueRange(
        values: [headers],
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        '$attendanceMainSheet!A1:F1',
        valueInputOption: 'RAW',
      );

      // Format headers and add protection
      await _formatHeaders(attendanceMainSheet, 0);
      await _addAttendanceProtection();
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error adding summary headers: $e');
    }
  }

  Future<void> _addAttendanceProtection() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      debugPrint('🔐 [ATTENDANCE] Adding warning protection to attendance spreadsheet');

      // Get all sheets in the spreadsheet
      final spreadsheet = await _sheetsApi!.spreadsheets.get(_spreadsheetId!);
      final requests = <sheets.Request>[];

      // Add warning protection to each sheet
      for (final sheet in spreadsheet.sheets ?? []) {
        if (sheet.properties?.sheetId != null) {
          requests.add(sheets.Request(
            addProtectedRange: sheets.AddProtectedRangeRequest(
              protectedRange: sheets.ProtectedRange(
                range: sheets.GridRange(
                  sheetId: sheet.properties!.sheetId,
                  startRowIndex: 0,
                  endRowIndex: 1000,
                ),
                description: 'אזהרה: גיליון הנוכחות מנוהל אוטומטית על ידי מערכת BPApp. עריכה ידנית עלולה לגרום לבעיות בסנכרון. השתמשו באפליקציה בלבד.',
                warningOnly: true,
              ),
            ),
          ));
        }
      }

      if (requests.isNotEmpty) {
        final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
          requests: requests,
        );

        await _sheetsApi!.spreadsheets.batchUpdate(
          batchUpdateRequest,
          _spreadsheetId!,
        );

        debugPrint('✅ [ATTENDANCE] Warning protection added to attendance spreadsheet');
      }
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error adding protection: $e');
    }
  }

  Future<void> _ensureClassSheet(String className, List<String> students) async {
    if (_sheetsApi == null || _spreadsheetId == null) {
      throw Exception('Sheets API or Spreadsheet ID is null');
    }

    try {
      debugPrint('🔍 [ATTENDANCE] Checking if sheet exists for class: $className');

      // Check if sheet exists
      final spreadsheet = await _sheetsApi!.spreadsheets.get(_spreadsheetId!);
      final existingSheet = spreadsheet.sheets?.firstWhere(
        (sheet) => sheet.properties?.title == className,
        orElse: () => sheets.Sheet(),
      );

      if (existingSheet != null && existingSheet.properties?.sheetId != null) {
        debugPrint('✅ [ATTENDANCE] Sheet exists for class: $className (ID: ${existingSheet.properties!.sheetId})');
        _classSheetIds[className] = existingSheet.properties!.sheetId;

        // Update student headers if needed
        await _updateClassHeaders(className, students);
      } else {
        debugPrint('🆕 [ATTENDANCE] Creating new sheet for class: $className');
        // Create new sheet for this class
        await _createClassSheet(className, students);

        // Update student headers if needed
        await _updateClassHeaders(className, students);
      }
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error ensuring class sheet: $e');
      throw Exception('Failed to ensure class sheet: $e');
    }
  }

  Future<void> _createClassSheet(String className, List<String> students) async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      debugPrint('📝 [ATTENDANCE] Creating sheet for class: $className');

      // Create new sheet
      final addSheetRequest = sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(
            title: className,
            rightToLeft: true,
            gridProperties: sheets.GridProperties(
              frozenRowCount: 1,
              frozenColumnCount: 1,
              columnCount: students.length + 2, // Date + students + summary
            ),
          ),
        ),
      );

      final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
        requests: [addSheetRequest],
      );

      final response = await _sheetsApi!.spreadsheets.batchUpdate(
        batchUpdateRequest,
        _spreadsheetId!,
      );

      // Get the new sheet ID
      if (response.replies != null && response.replies!.isNotEmpty) {
        final addSheetReply = response.replies!.first.addSheet;
        if (addSheetReply != null && addSheetReply.properties != null) {
          _classSheetIds[className] = addSheetReply.properties!.sheetId;
        }
      }

      // Add headers
      await _updateClassHeaders(className, students);

      // Add protection to the new sheet
      await _addAttendanceProtection();

      debugPrint('✅ [ATTENDANCE] Created sheet for class: $className');
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error creating class sheet: $e');
    }
  }

  Future<void> _updateClassHeaders(String className, List<String> students) async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      // Sort students alphabetically
      final sortedStudents = List<String>.from(students)..sort();
      _classStudentHeaders[className] = sortedStudents;

      // Create headers: Date + student names + summary columns
      final headers = ['תאריך', ...sortedStudents, 'נוכחים', 'חסרים', 'אחוז'];

      final valueRange = sheets.ValueRange(
        values: [headers],
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        '$className!A1:${_columnLetter(headers.length)}1',
        valueInputOption: 'RAW',
      );

      // Format headers
      await _formatHeaders(className, _classSheetIds[className]);
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error updating class headers: $e');
    }
  }

  Future<void> _formatHeaders(String sheetName, int? sheetId) async {
    if (_sheetsApi == null || _spreadsheetId == null || sheetId == null) return;

    try {
      final requests = [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: sheetId,
              startRowIndex: 0,
              endRowIndex: 1,
            ),
            cell: sheets.CellData(
              userEnteredFormat: sheets.CellFormat(
                backgroundColor: sheets.Color(red: 0.2, green: 0.3, blue: 0.8),
                textFormat: sheets.TextFormat(
                  foregroundColor: sheets.Color(red: 1.0, green: 1.0, blue: 1.0),
                  bold: true,
                  fontSize: 11,
                ),
                horizontalAlignment: 'CENTER',
              ),
            ),
            fields: 'userEnteredFormat',
          ),
        ),
      ];

      final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
        requests: requests,
      );

      await _sheetsApi!.spreadsheets.batchUpdate(
        batchUpdateRequest,
        _spreadsheetId!,
      );
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error formatting headers: $e');
    }
  }

  Future<bool> submitAttendance(AttendanceRecord record) async {
    if (!_isInitialized) {
      debugPrint('❌ [ATTENDANCE] Service not initialized');
      _setError('שירות הנוכחות לא הופעל');
      return false;
    }

    if (_sheetsApi == null) {
      debugPrint('❌ [ATTENDANCE] Sheets API is null');
      _setError('לא ניתן להתחבר ל-Google Sheets');
      return false;
    }

    // If no spreadsheet ID, try to reload from Firestore in case secretary just created it
    if (_spreadsheetId == null) {
      debugPrint('⚠️ [ATTENDANCE] No spreadsheet ID cached, checking Firestore again...');
      await _findOrCreateAttendanceSpreadsheet();

      if (_spreadsheetId == null) {
        debugPrint('❌ [ATTENDANCE] No attendance spreadsheet found after refresh');
        _setError('לא נמצא גיליון נוכחות. המזכירה צריכה להתחבר תחילה ליצור את הגיליון');
        return false;
      } else {
        debugPrint('✅ [ATTENDANCE] Found spreadsheet after refresh: $_spreadsheetId');
      }
    }

    try {
      debugPrint('📤 [ATTENDANCE] Submitting attendance for ${record.className}');
      debugPrint('📋 [ATTENDANCE] Spreadsheet ID: $_spreadsheetId');
      debugPrint('👥 [ATTENDANCE] Students count: ${record.studentAttendance.length}');

      // Get sorted student list for this class
      final students = record.studentAttendance.keys.toList()..sort();
      debugPrint('📝 [ATTENDANCE] Sorted students: $students');

      // Ensure class sheet exists
      debugPrint('🔍 [ATTENDANCE] Ensuring class sheet exists for: ${record.className}');
      await _ensureClassSheet(record.className, students);

      // Add attendance record to class sheet
      debugPrint('➕ [ATTENDANCE] Adding attendance to class sheet');
      await _addAttendanceToClassSheet(record, students);

      // Update summary sheet
      debugPrint('📊 [ATTENDANCE] Updating summary sheet');
      await _updateSummarySheet(record);

      debugPrint('✅ [ATTENDANCE] Attendance submitted successfully');
      return true;
    } catch (e, stackTrace) {
      final errorMessage = _parseErrorMessage(e);
      _setError(errorMessage);
      debugPrint('❌ [ATTENDANCE] Error submitting attendance: $e');
      debugPrint('📚 [ATTENDANCE] Stack trace: $stackTrace');
      return false;
    }
  }

  String _parseErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('403') || errorStr.contains('Forbidden')) {
      return 'אין הרשאות לגיליון הנוכחות';
    } else if (errorStr.contains('404') || errorStr.contains('Not Found')) {
      return 'גיליון הנוכחות לא נמצא';
    } else if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
      return 'נדרשת הזדהות מחדש';
    } else if (errorStr.contains('NetworkException') || errorStr.contains('SocketException')) {
      return 'בעיית חיבור לאינטרנט';
    } else if (errorStr.contains('PERMISSION_DENIED')) {
      return 'אין הרשאות מספיקות';
    } else {
      return 'שגיאה בשליחת נוכחות: ${errorStr.length > 100 ? errorStr.substring(0, 100) : errorStr}';
    }
  }

  Future<void> _addAttendanceToClassSheet(AttendanceRecord record, List<String> students) async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      // Check for existing record for this date
      final existingRow = await _findExistingDateRow(record.className, record.date);

      // Prepare row data
      final row = [record.date];
      int presentCount = 0;
      int absentCount = 0;

      // Use the stored header order for this class
      final headerOrder = _classStudentHeaders[record.className] ?? students;

      for (final student in headerOrder) {
        final isPresent = record.studentAttendance[student] ?? false;
        row.add(isPresent ? '✓' : '✗');
        if (isPresent) presentCount++; else absentCount++;
      }

      // Add summary columns
      row.add(presentCount.toString());
      row.add(absentCount.toString());
      row.add('${((presentCount / (presentCount + absentCount)) * 100).toStringAsFixed(1)}%');

      final valueRange = sheets.ValueRange(
        values: [row],
      );

      if (existingRow != null) {
        // Update existing row
        await _sheetsApi!.spreadsheets.values.update(
          valueRange,
          _spreadsheetId!,
          '${record.className}!A$existingRow:${_columnLetter(row.length)}$existingRow',
          valueInputOption: 'RAW',
        );
        debugPrint('📝 [ATTENDANCE] Updated existing row $existingRow');
      } else {
        // Append new row
        await _sheetsApi!.spreadsheets.values.append(
          valueRange,
          _spreadsheetId!,
          '${record.className}!A:A',
          valueInputOption: 'RAW',
          insertDataOption: 'INSERT_ROWS',
        );
        debugPrint('➕ [ATTENDANCE] Added new attendance row');
      }
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error adding to class sheet: $e');
      throw e;
    }
  }

  Future<int?> _findExistingDateRow(String className, String date) async {
    if (_sheetsApi == null || _spreadsheetId == null) return null;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$className!A:A',
      );

      if (response.values != null) {
        for (int i = 0; i < response.values!.length; i++) {
          if (response.values![i].isNotEmpty && response.values![i][0] == date) {
            return i + 1; // Sheet rows are 1-indexed
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ATTENDANCE] Error finding existing date: $e');
    }

    return null;
  }

  Future<void> _updateSummarySheet(AttendanceRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      // First, check if a row with this date and class already exists
      debugPrint('🔍 [ATTENDANCE] Checking for existing summary row for date: ${record.date}, class: ${record.className}');
      final existingRow = await _findExistingSummaryRow(record.date, record.className);

      final presentCount = record.studentAttendance.values.where((v) => v).length;
      final totalCount = record.studentAttendance.length;
      final absentCount = totalCount - presentCount;
      final percentage = totalCount > 0
        ? ((presentCount / totalCount) * 100).toStringAsFixed(1)
        : '0';

      final summaryRow = [
        record.date,
        record.className,
        presentCount.toString(),
        absentCount.toString(),
        totalCount.toString(),
        '$percentage%',
      ];

      final valueRange = sheets.ValueRange(
        values: [summaryRow],
      );

      if (existingRow != null) {
        // Update existing row
        debugPrint('📝 [ATTENDANCE] Updating existing summary row $existingRow');
        await _sheetsApi!.spreadsheets.values.update(
          valueRange,
          _spreadsheetId!,
          '$attendanceMainSheet!A$existingRow:F$existingRow',
          valueInputOption: 'RAW',
        );
        debugPrint('✅ [ATTENDANCE] Updated existing summary row');
      } else {
        // Append new row
        debugPrint('➕ [ATTENDANCE] Adding new summary row');
        await _sheetsApi!.spreadsheets.values.append(
          valueRange,
          _spreadsheetId!,
          '$attendanceMainSheet!A:F',
          valueInputOption: 'RAW',
          insertDataOption: 'INSERT_ROWS',
        );
        debugPrint('✅ [ATTENDANCE] Added new summary row');
      }
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error updating summary: $e');
    }
  }

  /// Find existing row in summary sheet with matching date and class
  Future<int?> _findExistingSummaryRow(String date, String className) async {
    if (_sheetsApi == null || _spreadsheetId == null) return null;

    try {
      // Get all data from summary sheet
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$attendanceMainSheet!A:B',  // Only need date and class columns
      );

      if (response.values != null) {
        // Skip header row (index 0) and search for matching date+class
        for (int i = 1; i < response.values!.length; i++) {
          final row = response.values![i];
          if (row.length >= 2) {
            final rowDate = row[0].toString();
            final rowClass = row[1].toString();

            if (rowDate == date && rowClass == className) {
              debugPrint('🔍 [ATTENDANCE] Found existing summary row at position ${i + 1}');
              return i + 1; // Sheet rows are 1-indexed
            }
          }
        }
      }

      debugPrint('🔍 [ATTENDANCE] No existing summary row found for date: $date, class: $className');
      return null;
    } catch (e) {
      debugPrint('❌ [ATTENDANCE] Error searching for existing summary row: $e');
      return null;
    }
  }

  String _columnLetter(int columnNumber) {
    String letter = '';
    while (columnNumber > 0) {
      columnNumber--;
      letter = String.fromCharCode(65 + (columnNumber % 26)) + letter;
      columnNumber ~/= 26;
    }
    return letter;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
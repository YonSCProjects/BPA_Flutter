import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;

import '../config/app_config.dart';
import '../data/models/student_record.dart';
import '../data/models/autocomplete_data.dart';
import 'google_auth_service.dart';
import 'local_storage_service.dart';
import 'educator_initialization_service.dart';
import 'service_account_sheets_service.dart';
import 'summary_sheet_service.dart';
// import 'backup_setup_service.dart'; // Removed - backup feature disabled

class GoogleSheetsService extends ChangeNotifier {
  static const String spreadsheetName = 'BPApp';
  static const String worksheetName = 'נתוני תלמידים';
  
  static const List<String> hebrewHeaders = [
    'תאריך',
    'שם התלמיד',
    'שם הכיתה',
    'מספר השיעור',
    'כניסה',
    'שהייה',
    'אווירה',
    'ביצוע',
    'מטרה אישית',
    'בונוס',
    'סה"כ',
    'הערות',
  ];

  final GoogleAuthService _authService;
  final LocalStorageService _localStorageService = LocalStorageService();
  late final EducatorInitializationService _educatorInitService;
  final ServiceAccountSheetsService _serviceAccountService = ServiceAccountSheetsService();
  SummarySheetService? _summarySheetService;
  
  /// Access to the authentication service for multi-destination saving
  GoogleAuthService get authService => _authService;
  
  sheets.SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi;
  String? _spreadsheetId;
  int? _sheetId;
  bool _isLoading = false;
  String? _error;
  String? _recoveryMessage;
  AutocompleteData _autocompleteData = AutocompleteData.empty();

  // Feature flag for safe rollback
  static const bool _offlineFirstEnabled = true;

  GoogleSheetsService(this._authService) {
    _educatorInitService = EducatorInitializationService(_authService);
    _authService.addListener(_onAuthStateChanged);
    // Initialize service account if enabled
    if (AppConfig.useServiceAccount) {
      _initializeServiceAccount();
    }
  }
  
  Future<void> _initializeServiceAccount() async {
    debugPrint('🔐 [SHEETS] Initializing service account for all operations');
    await _serviceAccountService.initialize();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get recoveryMessage => _recoveryMessage;
  String? get spreadsheetId => _spreadsheetId;
  AutocompleteData get autocompleteData => _autocompleteData;
  bool get isInitialized => _spreadsheetId != null && _sheetsApi != null;

  Future<bool> initialize() async {
    _setLoading(true);
    _setError(null);
    _setRecoveryMessage(null);

    try {
      // Initialize local storage first (always try this)
      if (_offlineFirstEnabled) {
        try {
          await _localStorageService.initialize();
          debugPrint('✅ [OFFLINE] Local storage initialized');
        } catch (e) {
          debugPrint('⚠️ [OFFLINE] Local storage failed, continuing with online-only: $e');
        }
      }

      if (!_authService.isAuthenticated) {
        _setError('לא מחובר לגוגל - נדרשת התחברות');
        return false;
      }

      await _initializeApis();
      await _findOrCreateSpreadsheet();
      await _loadAutocompleteData();
      
      // Sync any pending local records
      if (_offlineFirstEnabled && _localStorageService.isInitialized) {
        _syncPendingRecordsInBackground();
      }
      
      debugPrint('GoogleSheetsService initialized successfully');
      return true;
    } catch (e) {
      _setError('שגיאה באתחול שירות הגיליונות: ${e.toString()}');
      debugPrint('GoogleSheetsService initialization error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _initializeApis() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      throw Exception('לא ניתן לקבל חיבור מאומת');
    }

    _sheetsApi = sheets.SheetsApi(client);
    _driveApi = drive.DriveApi(client);
  }

  Future<void> _findOrCreateSpreadsheet() async {
    debugPrint('🔍 [INIT] Starting spreadsheet discovery process...');
    
    // ALWAYS use user's own OAuth spreadsheet for teacher records
    // Service account is only for saving to educator spreadsheets
    debugPrint('👤 [INIT] Using USER ownership mode for teacher\'s own spreadsheet');
    
    // Step 1: Look for user's own BPApp spreadsheet
    await _findExistingSpreadsheet();
      
    if (_spreadsheetId == null) {
      debugPrint('🔍 [INIT] No owned spreadsheet found - checking trash...');
      
      // Step 2: Check if spreadsheet exists in trash before creating new one
      final recoveredFromTrash = await _checkAndRecoverFromTrash();
      if (!recoveredFromTrash) {
        debugPrint('🔍 [INIT] No recoverable spreadsheet found - creating new one...');
        await _createSpreadsheet();
      }
    } else {
      debugPrint('✅ [INIT] Using existing spreadsheet: $_spreadsheetId');
    }
    
    // Get sheet ID for API operations
    if (_spreadsheetId != null && _sheetId == null) {
      await _getSheetId();
    }
    
    // Note: Protection removed as per user request
    // Service account handles educator spreadsheets separately
    
    // Check if this user is an educator and auto-initialize their spreadsheet ID
    if (_spreadsheetId != null && _authService.currentUser?.email != null) {
      await _educatorInitService.checkAndInitializeEducator(
        userEmail: _authService.currentUser!.email!,
        spreadsheetId: _spreadsheetId!,
      );
    }
    
    debugPrint('✅ [INIT] Spreadsheet setup complete: $_spreadsheetId');
  }

  Future<void> _findExistingSpreadsheet() async {
    if (_driveApi == null) return;

    try {
      final currentUser = _authService.currentUser;
      if (currentUser?.email == null) {
        debugPrint('Cannot find existing spreadsheet: no current user email');
        return;
      }

      final userEmail = currentUser!.email;
      debugPrint('🔍 [INIT] Looking for BPApp spreadsheet owned by: $userEmail');

      // Search for BPApp spreadsheet OWNED by current user (not shared)
      final response = await _driveApi!.files.list(
        q: "name='$spreadsheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false and '$userEmail' in owners",
        spaces: 'drive',
        $fields: 'files(id,name,owners)',
      );

      debugPrint('🔍 [INIT] Found ${response.files?.length ?? 0} spreadsheets owned by user');

      if (response.files != null && response.files!.isNotEmpty) {
        // Verify the first result is actually owned by the current user
        final file = response.files!.first;
        final isOwnedByCurrentUser = file.owners?.any((owner) => owner.emailAddress == userEmail) ?? false;
        
        if (isOwnedByCurrentUser) {
          _spreadsheetId = file.id!;
          debugPrint('✅ [INIT] Found existing spreadsheet owned by user: $_spreadsheetId');

          // Initialize summary sheet service for existing spreadsheet
          if (_sheetsApi != null) {
            _summarySheetService = SummarySheetService(_sheetsApi!, _spreadsheetId!);
            await _summarySheetService!.ensureSummarySheetExists();
          }
        } else {
          debugPrint('⚠️ [INIT] Found spreadsheet but not owned by current user - will create new one');
        }
      } else {
        debugPrint('ℹ️ [INIT] No existing BPApp spreadsheet found owned by user - will create new one');
      }
    } catch (e) {
      debugPrint('❌ [INIT] Error finding existing spreadsheet: $e');
    }
  }

  Future<void> _createSpreadsheet() async {
    if (_sheetsApi == null) return;

    try {
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: spreadsheetName,
          locale: 'en_US',
          timeZone: 'Asia/Jerusalem',
        ),
        sheets: [
          sheets.Sheet(
            properties: sheets.SheetProperties(
              title: worksheetName,
              rightToLeft: true,
              gridProperties: sheets.GridProperties(
                frozenRowCount: 1,
                columnCount: hebrewHeaders.length,
              ),
            ),
          ),
        ],
      );

      final response = await _sheetsApi!.spreadsheets.create(spreadsheet);
      _spreadsheetId = response.spreadsheetId!;

      await _addHeaders();
      await _protectSpreadsheet();

      // Initialize summary sheet service and create summary sheet
      _summarySheetService = SummarySheetService(_sheetsApi!, _spreadsheetId!);
      await _summarySheetService!.ensureSummarySheetExists();

      debugPrint('Created new spreadsheet with summary sheet: $_spreadsheetId');

      // Backup setup removed - no longer adding instructions sheet
    } catch (e) {
      throw Exception('שגיאה ביצירת גיליון אלקטרוני: ${e.toString()}');
    }
  }

  Future<void> _addHeaders() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final range = '$worksheetName!A1:${String.fromCharCode(65 + hebrewHeaders.length - 1)}1';
      final valueRange = sheets.ValueRange(
        values: [hebrewHeaders],
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        range,
        valueInputOption: 'RAW',
      );

      await _formatHeaders();
      
      debugPrint('Headers added successfully');
    } catch (e) {
      debugPrint('Error adding headers: $e');
    }
  }

  Future<void> _getSheetId() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final response = await _sheetsApi!.spreadsheets.get(_spreadsheetId!);
      if (response.sheets != null && response.sheets!.isNotEmpty) {
        // Find the sheet with our worksheet name
        final targetSheet = response.sheets!.firstWhere(
          (sheet) => sheet.properties?.title == worksheetName,
          orElse: () => response.sheets!.first, // fallback to first sheet
        );
        _sheetId = targetSheet.properties?.sheetId ?? 0;
        debugPrint('Found sheet ID: $_sheetId');
      }
    } catch (e) {
      debugPrint('Error getting sheet ID: $e');
      _sheetId = 0; // fallback to 0
    }
  }

  Future<bool> _checkAndRecoverFromTrash() async {
    if (_driveApi == null) return false;

    try {
      debugPrint('Checking for BPApp spreadsheet in trash...');
      
      // Search for the spreadsheet in trash
      final response = await _driveApi!.files.list(
        q: "name='$spreadsheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=true",
        spaces: 'drive',
        orderBy: 'modifiedTime desc', // Get most recently deleted first
      );

      if (response.files != null && response.files!.isNotEmpty) {
        final deletedFile = response.files!.first;
        debugPrint('Found BPApp spreadsheet in trash: ${deletedFile.id}');
        
        // Attempt to recover the file from trash
        return await _recoverFromTrash(deletedFile.id!, deletedFile.name!);
      }
      
      debugPrint('No BPApp spreadsheet found in trash');
      return false;
    } catch (e) {
      debugPrint('Error checking trash for spreadsheet: $e');
      return false;
    }
  }

  Future<bool> _recoverFromTrash(String fileId, String fileName) async {
    if (_driveApi == null) return false;

    try {
      debugPrint('Attempting to recover spreadsheet from trash: $fileId');
      
      // Create an update request to untrash the file
      final fileUpdate = drive.File();
      fileUpdate.trashed = false;
      
      // Restore the file from trash
      await _driveApi!.files.update(
        fileUpdate,
        fileId,
      );
      
      // Set the recovered spreadsheet ID
      _spreadsheetId = fileId;

      debugPrint('Successfully recovered BPApp spreadsheet from trash: $fileId');

      // Apply protection to recovered spreadsheet
      await _protectSpreadsheet();

      // Initialize summary sheet service for recovered spreadsheet
      if (_sheetsApi != null) {
        _summarySheetService = SummarySheetService(_sheetsApi!, _spreadsheetId!);
        await _summarySheetService!.ensureSummarySheetExists();
      }
      
      // Set recovery success message
      _recoveryMessage = 'הגיליון האלקטרוני שלך שוחזר בהצלחה מהפח! כל הנתונים שלך נשמרו.';
      
      // Notify about recovery (this could trigger UI notification)
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error recovering spreadsheet from trash: $e');
      return false;
    }
  }

  Future<void> _formatHeaders() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final requests = [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: 0,
              startRowIndex: 0,
              endRowIndex: 1,
              startColumnIndex: 0,
              endColumnIndex: hebrewHeaders.length,
            ),
            cell: sheets.CellData(
              userEnteredFormat: sheets.CellFormat(
                backgroundColor: sheets.Color(
                  red: 0.9,
                  green: 0.9,
                  blue: 0.9,
                ),
                textFormat: sheets.TextFormat(
                  bold: true,
                  fontSize: 12,
                ),
                horizontalAlignment: 'CENTER',
              ),
            ),
            fields: 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)',
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
      debugPrint('Error formatting headers: $e');
    }
  }

  /// Fix existing spreadsheet protection to allow app writes to data rows
  Future<void> _fixExistingProtection() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final currentUser = _authService.currentUser;
      if (currentUser?.email == null) {
        debugPrint('Cannot fix protection: no current user email');
        return;
      }

      final userEmail = currentUser!.email;
      debugPrint('🔧 [PROTECTION] Fixing existing protection for: $userEmail');

      // Get current spreadsheet structure including existing protected ranges
      final spreadsheet = await _sheetsApi!.spreadsheets.get(_spreadsheetId!);
      
      final requests = <sheets.Request>[];
      
      // Find and remove existing broad protection that blocks data writes
      if (spreadsheet.sheets != null) {
        for (final sheet in spreadsheet.sheets!) {
          final protectedRanges = sheet.protectedRanges;
          if (protectedRanges != null) {
            for (final range in protectedRanges) {
              final gridRange = range.range;
              if (gridRange != null && 
                  gridRange.sheetId == (_sheetId ?? 0) &&
                  gridRange.endRowIndex != null && 
                  gridRange.endRowIndex! > 10) { // Broad protection (more than just headers)
                
                debugPrint('🔧 [PROTECTION] Removing broad protection range: ${range.protectedRangeId}');
                
                // Remove the problematic protection
                requests.add(sheets.Request(
                  deleteProtectedRange: sheets.DeleteProtectedRangeRequest(
                    protectedRangeId: range.protectedRangeId!,
                  ),
                ));
              }
            }
          }
        }
      }
      
      // Add proper header-only protection
      requests.add(sheets.Request(
        addProtectedRange: sheets.AddProtectedRangeRequest(
          protectedRange: sheets.ProtectedRange(
            range: sheets.GridRange(
              sheetId: _sheetId ?? 0,
              startRowIndex: 0, // Row 1 (0-indexed)
              endRowIndex: 1,   // Only protect the header row
              startColumnIndex: 0,
              endColumnIndex: hebrewHeaders.length,
            ),
            description: 'הגנה על שורת כותרות BPApp - רק האפליקציה יכולה לערוך',
            warningOnly: false,
            editors: sheets.Editors(
              users: [userEmail],
              domainUsersCanEdit: false,
            ),
          ),
        ),
      ));

      if (requests.isNotEmpty) {
        final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
          requests: requests,
        );

        await _sheetsApi!.spreadsheets.batchUpdate(
          batchUpdateRequest,
          _spreadsheetId!,
        );

        debugPrint('🔧 [PROTECTION] Successfully fixed spreadsheet protection - data rows now writable');
      } else {
        debugPrint('🔧 [PROTECTION] No protection changes needed');
      }
      
    } catch (e) {
      debugPrint('⚠️ [PROTECTION] Could not fix existing protection: $e');
      debugPrint('ℹ️ [PROTECTION] Existing spreadsheet has protection that cannot be modified by app');
      debugPrint('ℹ️ [PROTECTION] App will work with existing protection as-is');
      // Don't try to add more protection if we can't fix existing protection
      // The spreadsheet already has some form of protection in place
    }
  }

  Future<void> _protectSpreadsheet() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      // Get current user's email for setting edit permissions
      final currentUser = _authService.currentUser;
      if (currentUser?.email == null) {
        debugPrint('Cannot protect sheet: no current user email');
        return;
      }

      final userEmail = currentUser!.email;
      debugPrint('Protecting spreadsheet with edit access for: $userEmail');

      final requests = <sheets.Request>[];

      // 1. Protect the header row with hard protection
      requests.add(sheets.Request(
        addProtectedRange: sheets.AddProtectedRangeRequest(
          protectedRange: sheets.ProtectedRange(
            range: sheets.GridRange(
              sheetId: _sheetId ?? 0,
              startRowIndex: 0, // Row 1 (0-indexed)
              endRowIndex: 1,   // Only protect the header row
              startColumnIndex: 0,
              endColumnIndex: hebrewHeaders.length,
            ),
            description: 'הגנה על שורת כותרות BPApp - רק האפליקציה יכולה לערוך',
            warningOnly: false, // Hard protection for headers
            editors: sheets.Editors(
              users: [userEmail], // Only the authenticated user (app) can edit headers
              domainUsersCanEdit: false,
            ),
          ),
        ),
      ));

      // 2. Add warning-only protection for the entire data area
      requests.add(sheets.Request(
        addProtectedRange: sheets.AddProtectedRangeRequest(
          protectedRange: sheets.ProtectedRange(
            range: sheets.GridRange(
              sheetId: _sheetId ?? 0,
              startRowIndex: 1, // Start from row 2 (after headers)
              endRowIndex: 1000, // Protect up to row 1000
              startColumnIndex: 0,
              endColumnIndex: hebrewHeaders.length,
            ),
            description: 'אזהרה: הגיליון הזה מנוהל אוטומטית על ידי אפליקציית BPApp. עריכה ידנית עלולה לגרום לבעיות בסנכרון הנתונים. מומלץ להשתמש רק באפליקציה לעדכון נתונים.',
            warningOnly: true, // Warning only - shows alert but allows editing
          ),
        ),
      ));

      final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
        requests: requests,
      );

      await _sheetsApi!.spreadsheets.batchUpdate(
        batchUpdateRequest,
        _spreadsheetId!,
      );

      debugPrint('Successfully protected BPApp spreadsheet headers - data rows remain writable');
    } catch (e) {
      debugPrint('Warning: Could not protect spreadsheet (this is non-critical): $e');
      // Don't throw error as protection is nice-to-have but not critical
    }
  }

  Future<void> _loadAutocompleteData() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:L',
      );

      if (response.values != null) {
        final studentNames = <String>{};
        final classNames = <String>{};

        for (final row in response.values!) {
          if (row.length >= 3) {
            final studentName = row[1]?.toString().trim();
            final className = row[2]?.toString().trim();

            if (studentName != null && studentName.isNotEmpty) {
              studentNames.add(studentName);
            }
            if (className != null && className.isNotEmpty) {
              classNames.add(className);
            }
          }
        }

        _autocompleteData = AutocompleteData(
          studentNames: studentNames,
          classNames: classNames,
          lastUpdated: DateTime.now(),
        );

        debugPrint('Loaded autocomplete data: ${studentNames.length} students, ${classNames.length} classes');
      }
    } catch (e) {
      debugPrint('Error loading autocomplete data: $e');
    }
  }

  Future<StudentRecord?> findMatchingRecord(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return null;

    debugPrint('🔍 [MATCH] ========== STARTING RECORD MATCH ==========');
    debugPrint('🔍 [MATCH] Looking for:');
    debugPrint('🔍 [MATCH]   Date="${record.date}" (length=${record.date.length})');
    debugPrint('🔍 [MATCH]   Student="${record.studentName}" (length=${record.studentName.length})');
    debugPrint('🔍 [MATCH]   Class="${record.className}" (length=${record.className.length})');
    debugPrint('🔍 [MATCH]   ClassNum=${record.classNumber}');

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:L',
      );

      if (response.values != null) {
        debugPrint('🔍 [MATCH] Found ${response.values!.length} existing rows to check');
        debugPrint('🔍 [MATCH] Raw spreadsheet data:');
        for (int i = 0; i < response.values!.length; i++) {
          debugPrint('🔍 [MATCH] Raw row ${i + 2}: ${response.values![i]}');
        }
        debugPrint('🔍 [MATCH] ==========================================');
        
        for (int i = 0; i < response.values!.length; i++) {
          final row = response.values![i];
          if (row.length >= 4) {
            final existingDate = row[0]?.toString().trim() ?? '';
            final existingStudent = row[1]?.toString().trim() ?? '';
            final existingClass = row[2]?.toString().trim() ?? '';
            final existingClassNumber = int.tryParse(row[3]?.toString() ?? '0') ?? 0;
            
            debugPrint('🔍 [MATCH] --- Row ${i + 2} ---');
            debugPrint('🔍 [MATCH]   Date="$existingDate" (len=${existingDate.length})');
            debugPrint('🔍 [MATCH]   Student="$existingStudent" (len=${existingStudent.length})');
            debugPrint('🔍 [MATCH]   Class="$existingClass" (len=${existingClass.length})');
            debugPrint('🔍 [MATCH]   ClassNum=$existingClassNumber');

            // Normalize strings for comparison
            final recordDateNorm = record.date.trim();
            final recordStudentNorm = record.studentName.trim();
            final recordClassNorm = record.className.trim();

            // Detailed comparison with exact values shown
            final dateMatch = existingDate == recordDateNorm;
            final studentMatch = existingStudent == recordStudentNorm;
            final classMatch = existingClass == recordClassNorm;
            final classNumberMatch = existingClassNumber == record.classNumber;

            debugPrint('🔍 [MATCH] Row ${i + 2} detailed comparison:');
            debugPrint('  📅 Date: "$existingDate" == "$recordDateNorm" ? $dateMatch');
            debugPrint('  👤 Student: "$existingStudent" == "$recordStudentNorm" ? $studentMatch');
            debugPrint('  🏫 Class: "$existingClass" == "$recordClassNorm" ? $classMatch');
            debugPrint('  🔢 ClassNum: $existingClassNumber == ${record.classNumber} ? $classNumberMatch');
            
            if (!dateMatch || !studentMatch || !classMatch || !classNumberMatch) {
              debugPrint('  ❌ Row ${i + 2}: NO MATCH');
            } else {
              debugPrint('  ✅ Row ${i + 2}: EXACT MATCH FOUND!');
            }

            if (dateMatch && studentMatch && classMatch && classNumberMatch) {
              debugPrint('✅ [MATCH] FOUND EXACT MATCH at row ${i + 2}!');
              
              try {
                final existingRecord = StudentRecord.fromSheetRow(row);
                debugPrint('✅ [MATCH] Successfully parsed existing record');
                return existingRecord;
              } catch (e) {
                debugPrint('❌ [MATCH] Error parsing existing record: $e');
                continue;
              }
            }
          }
        }
        
        debugPrint('❌ [MATCH] No matching record found');
      } else {
        debugPrint('❌ [MATCH] No existing data found');
      }
    } catch (e) {
      debugPrint('❌ [MATCH] Error finding matching record: $e');
    }

    return null;
  }

  Future<bool> saveRecord(StudentRecord record) async {
    _setLoading(true);
    _setError(null);

    debugPrint('💾 [SAVE] Starting offline-first save process...');

    try {
      final recordWithScore = record.withCalculatedScore();
      
      // Step 1: ALWAYS save locally first (instant feedback to teacher)
      bool localSaveSuccess = false;
      if (_offlineFirstEnabled && _localStorageService.isInitialized) {
        try {
          await _localStorageService.saveRecord(recordWithScore);
          localSaveSuccess = true;
          debugPrint('✅ [SAVE] Saved locally - teacher has instant confirmation');
        } catch (e) {
          debugPrint('⚠️ [SAVE] Local save failed, continuing with online-only: $e');
        }
      }

      // Step 2: Attempt online sync
      bool onlineSuccess = false;
      
      // Ensure spreadsheet exists before attempting save
      if (_spreadsheetId == null) {
        debugPrint('⚠️ [SAVE] No spreadsheet ID found, attempting to discover/create spreadsheet');
        await _findExistingSpreadsheet();
        
        if (_spreadsheetId == null) {
          debugPrint('🔍 [SAVE] No owned spreadsheet found - creating new one...');
          await _createSpreadsheet();
        }
        
        if (_spreadsheetId != null && _sheetId == null) {
          await _getSheetId();
        }
      }
      
      // Save using the available method
      if (_sheetsApi != null && _spreadsheetId != null) {
        // Use OAuth for the teacher's own spreadsheet
        debugPrint('👤 [SAVE] Using USER OAuth for save operation');
        try {
          onlineSuccess = await _originalSaveRecord(recordWithScore);
        } catch (e) {
          debugPrint('❌ [SAVE] Error in user-owned save: $e');
        }
      } else if (AppConfig.useServiceAccount && _serviceAccountService.isInitialized) {
        // Use service account if OAuth is not available
        debugPrint('🔐 [SAVE] Using SERVICE ACCOUNT for save operation');
        final userEmail = _authService.currentUser?.email;
        final userName = _authService.currentUser?.displayName ?? userEmail?.split('@')[0] ?? 'User';
        
        if (userEmail != null) {
          onlineSuccess = await _serviceAccountService.saveRecordForUser(recordWithScore, userEmail, userName);
        }
      } else {
        debugPrint('❌ [SAVE] No save method available');
      }
      
      if (onlineSuccess) {
        // Mark as synced in local storage
        if (localSaveSuccess) {
          await _localStorageService.markAsSynced(recordWithScore);
        }
        
        // Update autocomplete data (preserve original behavior)
        _autocompleteData = _autocompleteData.addFromRecord(recordWithScore);
        notifyListeners();
        
        debugPrint('✅ [SAVE] Online sync successful');
      } else {
        // Mark as pending sync in local storage
        if (localSaveSuccess) {
          await _localStorageService.markAsPendingSync(recordWithScore);
        }
        debugPrint('⏳ [SAVE] Online sync failed, marked for retry');
      }

      // Step 3: Return success based on strategy
      if (_offlineFirstEnabled && localSaveSuccess) {
        // Offline-first: Success if saved locally (teacher gets instant feedback)
        return true;
      } else {
        // Fallback: Original behavior (only success if online sync worked)
        return onlineSuccess;
      }

    } catch (e) {
      _setError('שגיאה בשמירת הרשומה: ${e.toString()}');
      debugPrint('❌ [SAVE] Critical error in save process: $e');
      
      // Emergency fallback: Try original save method
      if (_sheetsApi != null && _spreadsheetId != null) {
        debugPrint('🚨 [SAVE] Attempting emergency fallback to original save method');
        return await _originalSaveRecord(record.withCalculatedScore());
      }
      
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Original save record logic preserved for fallback
  Future<bool> _originalSaveRecord(StudentRecord record) async {
    debugPrint('💾 [SAVE] Using original save logic');
    
    // Ensure spreadsheet exists before attempting save
    if (_spreadsheetId == null) {
      debugPrint('⚠️ [SAVE] No spreadsheet ID found, attempting to discover/create spreadsheet');
      // Step 1: Look for user's own BPApp spreadsheet
      await _findExistingSpreadsheet();
      
      if (_spreadsheetId == null) {
        debugPrint('🔍 [SAVE] No owned spreadsheet found - checking trash...');
        
        // Step 2: Check if spreadsheet exists in trash before creating new one
        final recoveredFromTrash = await _checkAndRecoverFromTrash();
        if (!recoveredFromTrash) {
          debugPrint('🔍 [SAVE] No recoverable spreadsheet found - creating new one...');
          await _createSpreadsheet();
        }
      }
      
      if (_spreadsheetId == null) {
        debugPrint('❌ [SAVE] Failed to discover or create spreadsheet');
        return false;
      }
      
      // Get sheet ID for API operations
      if (_sheetId == null) {
        await _getSheetId();
      }
      
      debugPrint('✅ [SAVE] Spreadsheet setup complete: $_spreadsheetId');
    }
    
    try {
      debugPrint('💾 [SAVE] Record with score: ${record.toString()}');
      
      final existingRecord = await findMatchingRecord(record);

      bool success;
      if (existingRecord != null) {
        debugPrint('💾 [SAVE] Existing record found - UPDATING existing row');
        success = await _updateRecord(record);
        debugPrint(success ? '✅ [SAVE] Updated existing record successfully' : '❌ [SAVE] Failed to update existing record');
      } else {
        debugPrint('💾 [SAVE] No existing record - CREATING new row');
        success = await _appendRecord(record);
        debugPrint(success ? '✅ [SAVE] Created new record successfully' : '❌ [SAVE] Failed to create new record');
      }

      return success;
    } catch (e) {
      debugPrint('❌ [SAVE] Original save method error: $e');
      return false;
    }
  }

  Future<bool> _updateRecord(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return false;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:L',
      );

      if (response.values != null) {
        for (int i = 0; i < response.values!.length; i++) {
          final row = response.values![i];
          if (row.length >= 4 &&
              row[0]?.toString() == record.date &&
              row[1]?.toString() == record.studentName &&
              row[2]?.toString() == record.className &&
              int.tryParse(row[3]?.toString() ?? '') == record.classNumber) {
            
            final rowNumber = i + 2;
            final range = '$worksheetName!A$rowNumber:L$rowNumber';
            
            final valueRange = sheets.ValueRange(
              values: [record.toSheetRow()],
            );

            await _sheetsApi!.spreadsheets.values.update(
              valueRange,
              _spreadsheetId!,
              range,
              valueInputOption: 'RAW',
            );

            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating record: $e');
    }

    return false;
  }

  Future<bool> _appendRecord(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return false;

    try {
      final insertPosition = await _findInsertPosition(record);
      
      if (insertPosition == -1) {
        return await _appendToEnd(record);
      } else {
        return await _insertRecordAtPosition(record, insertPosition);
      }
    } catch (e) {
      debugPrint('Error appending record: $e');
      return false;
    }
  }

  Future<int> _findInsertPosition(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return -1;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:D',
      );

      if (response.values == null || response.values!.isEmpty) {
        return 2; // Insert after header row
      }

      final recordDate = _parseDate(record.date);
      if (recordDate == null) {
        debugPrint('❌ [SORT] Could not parse record date: "${record.date}"');
        return -1;
      }

      debugPrint('🔄 [SORT] Finding position for record: ${record.date} (class ${record.classNumber})');
      debugPrint('🔄 [SORT] Parsed record date: $recordDate');

      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        if (row.isEmpty) continue;

        final existingDateStr = row[0]?.toString() ?? '';
        final existingDate = _parseDate(existingDateStr);
        if (existingDate == null) {
          debugPrint('⚠️ [SORT] Could not parse existing date: "$existingDateStr" at row ${i + 2}');
          continue;
        }

        final existingClassNumber = int.tryParse(row[3]?.toString() ?? '0') ?? 0;

        debugPrint('🔄 [SORT] Comparing with row ${i + 2}: $existingDateStr (class $existingClassNumber)');
        
        // Compare dates first (primary sort)
        if (recordDate.isBefore(existingDate)) {
          debugPrint('✅ [SORT] Found position by date: inserting at row ${i + 2}');
          return i + 2; // +2 because sheet is 1-indexed and has header row
        }
        
        // If same date, compare class numbers (secondary sort)
        if (recordDate.isAtSameMomentAs(existingDate)) {
          if (record.classNumber < existingClassNumber) {
            debugPrint('✅ [SORT] Found position by class number: inserting at row ${i + 2}');
            return i + 2;
          }
        }
      }

      debugPrint('🔄 [SORT] No position found, inserting at end');
      return -1; // Insert at end
    } catch (e) {
      debugPrint('❌ [SORT] Error finding insert position: $e');
      return -1;
    }
  }

  DateTime? _parseDate(String dateString) {
    if (dateString.isEmpty) return null;
    
    try {
      // Handle DD/MM/YYYY format (Hebrew/Israeli convention)
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      }
      // Fallback to standard parsing for YYYY-MM-DD
      return DateTime.parse(dateString);
    } catch (e) {
      debugPrint('📅 [SORT] Error parsing date "$dateString": $e');
      return null;
    }
  }

  Future<bool> _insertRecordAtPosition(StudentRecord record, int rowPosition) async {
    if (_sheetsApi == null || _spreadsheetId == null || _sheetId == null) return false;

    try {
      // Insert empty row at the target position
      final insertRequest = sheets.Request(
        insertRange: sheets.InsertRangeRequest(
          range: sheets.GridRange(
            sheetId: _sheetId!, // Use the actual sheet ID
            startRowIndex: rowPosition - 1, // 0-indexed for API
            endRowIndex: rowPosition,
            startColumnIndex: 0,
            endColumnIndex: hebrewHeaders.length,
          ),
          shiftDimension: 'ROWS',
        ),
      );

      final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
        requests: [insertRequest],
      );

      await _sheetsApi!.spreadsheets.batchUpdate(
        batchUpdateRequest,
        _spreadsheetId!,
      );

      // Now populate the new row with data
      final range = '$worksheetName!A$rowPosition:L$rowPosition';
      final valueRange = sheets.ValueRange(
        values: [record.toSheetRow()],
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        range,
        valueInputOption: 'RAW',
      );

      // Update summary sheet
      if (_summarySheetService != null) {
        await _summarySheetService!.mirrorRecordToSummary(record);
      }

      debugPrint('✅ [SAVE] Inserted record at position $rowPosition');
      return true;
    } catch (e) {
      debugPrint('❌ [SAVE] Error inserting record at position $rowPosition: $e');
      
      // Check if this is a protection error
      if (e.toString().contains('protected cell') || e.toString().contains('protection')) {
        debugPrint('🔧 [SAVE] Protection error on insert - trying fallback append');
        return await _appendToEndWithFallback(record);
      }
      
      return false;
    }
  }

  Future<bool> _appendToEnd(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return false;

    try {
      final valueRange = sheets.ValueRange(
        values: [record.toSheetRow()],
      );

      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        _spreadsheetId!,
        '$worksheetName!A:L',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );

      // Update summary sheet
      if (_summarySheetService != null) {
        await _summarySheetService!.mirrorRecordToSummary(record);
      }

      debugPrint('✅ [SAVE] Successfully appended record to end');
      return true;
    } catch (e) {
      debugPrint('❌ [SAVE] Error appending record to end: $e');
      
      // Check if this is a protection error
      if (e.toString().contains('protected cell') || e.toString().contains('protection')) {
        debugPrint('🔧 [SAVE] Protection error detected - trying fallback approach');
        return await _appendToEndWithFallback(record);
      }
      
      return false;
    }
  }
  
  /// Fallback append method that handles protection issues
  Future<bool> _appendToEndWithFallback(StudentRecord record) async {
    try {
      // Try a simple values update to a specific range instead of append
      // First, find the next empty row
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A:A',
      );
      
      int nextRow = 2; // Start after header
      if (response.values != null) {
        nextRow = response.values!.length + 1;
      }
      
      final range = '$worksheetName!A$nextRow:L$nextRow';
      final valueRange = sheets.ValueRange(
        values: [record.toSheetRow()],
      );
      
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        range,
        valueInputOption: 'RAW',
      );

      // Update summary sheet
      if (_summarySheetService != null) {
        await _summarySheetService!.mirrorRecordToSummary(record);
      }

      debugPrint('✅ [SAVE] Successfully saved using fallback method at row $nextRow');
      return true;
      
    } catch (e) {
      debugPrint('❌ [SAVE] Fallback append also failed: $e');
      return false;
    }
  }

  Future<int> getNextClassNumber(String date) async {
    if (_sheetsApi == null || _spreadsheetId == null) return 1;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:D',
      );

      if (response.values != null) {
        final classNumbers = <int>{};
        
        for (final row in response.values!) {
          if (row.length >= 4 && row[0]?.toString() == date) {
            final classNumber = int.tryParse(row[3]?.toString() ?? '');
            if (classNumber != null) {
              classNumbers.add(classNumber);
            }
          }
        }

        for (int i = 1; i <= 7; i++) {
          if (!classNumbers.contains(i)) {
            return i;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting next class number: $e');
    }

    return 1;
  }

  List<String> getStudentSuggestions(String query) {
    return _autocompleteData.getStudentSuggestions(query);
  }

  List<String> getClassSuggestions(String query) {
    return _autocompleteData.getClassSuggestions(query);
  }

  Future<void> refreshAutocompleteData() async {
    if (!isInitialized) return;

    try {
      await _loadAutocompleteData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing autocomplete data: $e');
    }
  }

  void _onAuthStateChanged() {
    if (!_authService.isAuthenticated) {
      _reset();
    }
  }

  void _reset() {
    _sheetsApi = null;
    _driveApi = null;
    _spreadsheetId = null;
    _sheetId = null;
    _autocompleteData = AutocompleteData.empty();
    _setError(null);
    _setRecoveryMessage(null);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _setRecoveryMessage(String? message) {
    _recoveryMessage = message;
    notifyListeners();
  }

  void clearRecoveryMessage() {
    _setRecoveryMessage(null);
  }

  /// Sync pending records in background (non-blocking)
  void _syncPendingRecordsInBackground() {
    if (!_offlineFirstEnabled || !_localStorageService.isInitialized) return;

    // Run sync in background without blocking initialization
    Future.microtask(() async {
      try {
        await syncPendingRecords();
      } catch (e) {
        debugPrint('🔄 [SYNC] Background sync failed: $e');
      }
    });
  }

  /// Sync all pending records with Google Sheets
  Future<void> syncPendingRecords() async {
    if (!_offlineFirstEnabled || !_localStorageService.isInitialized) {
      debugPrint('🔄 [SYNC] Sync not available - offline storage not initialized');
      return;
    }

    if (_sheetsApi == null || _spreadsheetId == null) {
      debugPrint('🔄 [SYNC] Sync not available - Google Sheets not initialized');
      return;
    }

    try {
      final pendingRecords = await _localStorageService.getPendingRecords();
      
      if (pendingRecords.isEmpty) {
        debugPrint('🔄 [SYNC] No pending records to sync');
        return;
      }

      debugPrint('🔄 [SYNC] Starting sync of ${pendingRecords.length} pending records');
      int successCount = 0;
      int failCount = 0;

      for (final localRecord in pendingRecords) {
        try {
          // Convert back to StudentRecord for syncing
          final studentRecord = StudentRecord(
            date: localRecord.date,
            studentName: localRecord.studentName,
            className: localRecord.className,
            classNumber: localRecord.classNumber,
            entry: localRecord.entry,
            staying: localRecord.staying,
            attitude: localRecord.attitude,
            performance: localRecord.performance,
            personalGoal: localRecord.personalGoal,
            bonus: localRecord.bonus,
            comments: localRecord.comments,
            totalScore: localRecord.totalScore,
          );

          final success = await _originalSaveRecord(studentRecord);
          
          if (success) {
            await _localStorageService.markAsSynced(studentRecord);
            successCount++;
            debugPrint('✅ [SYNC] Synced record: ${studentRecord.getMatchingKey()}');
            
            // Update autocomplete data
            _autocompleteData = _autocompleteData.addFromRecord(studentRecord);
          } else {
            await _localStorageService.incrementRetryCount(localRecord);
            failCount++;
            debugPrint('❌ [SYNC] Failed to sync record: ${studentRecord.getMatchingKey()}');
          }
          
          // Small delay to avoid overwhelming the API
          await Future.delayed(const Duration(milliseconds: 100));
          
        } catch (e) {
          await _localStorageService.incrementRetryCount(localRecord);
          failCount++;
          debugPrint('❌ [SYNC] Error syncing record ${localRecord.getMatchingKey()}: $e');
        }
      }

      debugPrint('🔄 [SYNC] Sync complete: $successCount success, $failCount failed');
      
      if (successCount > 0) {
        notifyListeners(); // Notify UI of autocomplete data updates
      }
      
    } catch (e) {
      debugPrint('❌ [SYNC] Critical sync error: $e');
    }
  }

  /// Get sync status information for UI
  Future<Map<String, int>> getSyncStatus() async {
    if (!_offlineFirstEnabled || !_localStorageService.isInitialized) {
      return {'synced': 0, 'pending': 0, 'failed': 0};
    }

    try {
      final counts = await _localStorageService.getSyncStatusCounts();
      return {
        'synced': counts[SyncStatus.synced] ?? 0,
        'pending': counts[SyncStatus.pending] ?? 0,
        'failed': counts[SyncStatus.failed] ?? 0,
      };
    } catch (e) {
      debugPrint('❌ [SYNC] Error getting sync status: $e');
      return {'synced': 0, 'pending': 0, 'failed': 0};
    }
  }

  /// Manual sync trigger for UI
  Future<bool> manualSync() async {
    try {
      await syncPendingRecords();
      return true;
    } catch (e) {
      debugPrint('❌ [SYNC] Manual sync failed: $e');
      return false;
    }
  }

  /// Offer backup setup for new spreadsheets
  // Backup setup removed - no longer adding instructions sheet
  // Future<void> _offerBackupSetup() async { /* Removed */ }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _localStorageService.dispose();
    super.dispose();
  }
}
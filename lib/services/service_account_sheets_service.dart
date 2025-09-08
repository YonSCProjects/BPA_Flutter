import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/models/student_record.dart';
import 'service_account_jwt_auth.dart';

// Extension for DateTime comparison
extension DateTimeComparison on DateTime {
  bool isEqual(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

/// Service Account based Google Sheets Service
/// 
/// This service uses service account credentials for centralized
/// spreadsheet management instead of individual OAuth per user.
/// 
/// **IMPORTANT**: Only used when AppConfig.useServiceAccount = true
/// Falls back to GoogleSheetsService when disabled.
class ServiceAccountSheetsService extends ChangeNotifier {
  static const String _serviceAccountAssetPath = 'assets/service_account.json';
  
  // Google Workspace admin email for impersonation
  static const String adminEmail = 'admin@bpappedu.com'; // YOUR WORKSPACE EMAIL
  
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.metadata.readonly',
  ];

  // Service account components
  AuthClient? _authClient; // Changed to support custom JWT auth
  sheets.SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi;
  ServiceAccountCredentials? _credentials;
  Map<String, dynamic>? _credentialsJson; // Store full JSON for JWT auth
  
  // State management
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEnabled => AppConfig.useServiceAccount && !AppConfig.emergencyDisable;
  
  /// Initialize service account authentication
  Future<bool> initialize() async {
    print('🚀🚀🚀 [SERVICE-ACCOUNT] === INITIALIZATION STARTING ===');
    print('🚀 isEnabled check: $isEnabled');
    print('🚀 useServiceAccount: ${AppConfig.useServiceAccount}');
    print('🚀 emergencyDisable: ${AppConfig.emergencyDisable}');
    
    if (!isEnabled) {
      print('❌ Service account disabled in config - skipping initialization');
      return false;
    }
    
    _setLoading(true);
    _setError(null);
    
    try {
      print('🚀 Step 1: Loading credentials...');
      
      // Load service account credentials from assets
      await _loadCredentials();
      print('✅ Credentials loaded: ${_credentials?.email}');
      
      print('🚀 Step 2: Creating authenticated client...');
      // Create authenticated client
      await _createAuthenticatedClient();
      print('✅ Auth client created');
      
      print('🚀 Step 3: Initializing Google APIs...');
      // Initialize APIs
      _initializeApis();
      print('✅ APIs initialized');
      
      _isInitialized = true;
      print('✅✅✅ SERVICE ACCOUNT READY!');
      print('   Email: ${_credentials?.email}');
      print('   Initialized: $_isInitialized');
      print('🚀 === INITIALIZATION COMPLETE ===\n');
      return true;
      
    } catch (e, stackTrace) {
      print('❌❌❌ SERVICE ACCOUNT INITIALIZATION FAILED');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      _setError('שגיאה באתחול שירות החשבון: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Load service account credentials from assets
  Future<void> _loadCredentials() async {
    try {
      _logDebug('Loading service account credentials from $_serviceAccountAssetPath');
      print('🔐 Loading service account from: $_serviceAccountAssetPath');
      
      final String credentialsJson = await rootBundle.loadString(_serviceAccountAssetPath);
      _credentialsJson = jsonDecode(credentialsJson); // Store full JSON
      
      _credentials = ServiceAccountCredentials.fromJson(_credentialsJson!);
      _logDebug('Service account credentials loaded successfully');
      _logDebug('Client Email: ${_credentials!.email}');
      print('✅ Service account loaded: ${_credentials!.email}');
      
    } catch (e) {
      print('❌ Failed to load service account: $e');
      throw Exception('Failed to load service account credentials: $e');
    }
  }
  
  /// Create authenticated HTTP client using service account WITHOUT impersonation
  Future<void> _createAuthenticatedClient() async {
    if (_credentials == null || _credentialsJson == null) {
      throw Exception('Service account credentials not loaded');
    }
    
    try {
      print('🔐 Creating authenticated client WITHOUT impersonation');
      print('   Service account: ${_credentials!.email}');
      print('   Scopes: $_scopes');
      
      // Use direct service account authentication (no impersonation)
      _authClient = await clientViaServiceAccount(_credentials!, _scopes);
      
      print('✅ Authenticated client created successfully!');
      print('   Service account ready: ${_credentials!.email}');
      
    } catch (e) {
      throw Exception('Failed to create authenticated client: $e');
    }
  }
  
  /// Initialize Google APIs with authenticated client
  void _initializeApis() {
    if (_authClient == null) {
      throw Exception('Authenticated client not available');
    }
    
    _sheetsApi = sheets.SheetsApi(_authClient!);
    _driveApi = drive.DriveApi(_authClient!);
    _logDebug('Google APIs initialized successfully');
  }
  
  /// Access educator's existing spreadsheet (educator-owned)
  /// 
  /// This method only FINDS existing educator spreadsheets
  /// Educators must create their own spreadsheets through self-initialization
  Future<String?> createOrAccessEducatorSpreadsheet(String educatorEmail, String educatorName) async {
    if (!_isInitialized) {
      _setError('שירות החשבון לא מאותחל');
      return null;
    }
    
    try {
      _logDebug('Accessing educator spreadsheet for: $educatorName ($educatorEmail)');
      
      // Only search for existing educator spreadsheet - NO CREATION
      final existingSpreadsheetId = await findEducatorSpreadsheet(educatorEmail);
      
      if (existingSpreadsheetId != null) {
        _logDebug('✅ Found existing educator-owned spreadsheet: $existingSpreadsheetId');
        return existingSpreadsheetId;
      }
      
      // No spreadsheet found - educator needs to sign in first
      _logDebug('⚠️ No educator spreadsheet found');
      _logDebug('ℹ️ Educator must sign in to create their BPApp first');
      _setError('המחנך צריך להתחבר לאפליקציה כדי ליצור את הגיליון שלו');
      
      return null;
      
    } catch (e) {
      _setError('שגיאה בגישה לגיליון המחנך: ${e.toString()}');
      _logDebug('Error accessing educator spreadsheet: $e');
      return null;
    }
  }
  
  /// Find existing spreadsheet for educator
  Future<String?> _findEducatorSpreadsheet(String educatorEmail) async {
    if (_driveApi == null) return null;
    
    try {
      // Search for spreadsheet with specific naming convention
      // Format: "BPApp - [Educator Name]"
      final response = await _driveApi!.files.list(
        q: "name contains 'BPApp -' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false and '$educatorEmail' in writers",
        spaces: 'drive',
        $fields: 'files(id,name,owners,writers)',
      );
      
      if (response.files != null && response.files!.isNotEmpty) {
        return response.files!.first.id;
      }
      
      return null;
    } catch (e) {
      _logDebug('Error finding educator spreadsheet: $e');
      return null;
    }
  }
  
  /// Find existing educator spreadsheet
  Future<String?> findEducatorSpreadsheet(String educatorEmail) async {
    print('🔍🔍🔍 [SERVICE-ACCOUNT] === FINDING EDUCATOR SPREADSHEET ===');
    print('🔍 Target educator email: $educatorEmail');
    print('🔍 Service account initialized: $_isInitialized');
    print('🔍 Service account email: ${_credentials?.email}');
    
    if (!_isInitialized || _driveApi == null) {
      print('❌ Service account not initialized for spreadsheet search');
      print('   _isInitialized: $_isInitialized');
      print('   _driveApi null: ${_driveApi == null}');
      return null;
    }
    
    try {
      print('🔍 Step 1: Listing ALL files service account can see...');
      
      // First, let's see ALL files the service account has access to
      final allFilesResponse = await _driveApi!.files.list(
        q: "mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name,owners,permissions,capabilities)',
        pageSize: 100,
      );
      
      print('📋 Service account can see ${allFilesResponse.files?.length ?? 0} total spreadsheets');
      
      if (allFilesResponse.files != null) {
        for (int i = 0; i < allFilesResponse.files!.length; i++) {
          final file = allFilesResponse.files![i];
          print('📄 File $i: ${file.name}');
          print('   ID: ${file.id}');
          if (file.owners != null) {
            print('   Owners: ${file.owners!.map((o) => o.emailAddress).join(", ")}');
          }
          print('   Can Edit: ${file.capabilities?.canEdit}');
          print('   Can Share: ${file.capabilities?.canShare}');
        }
      }
      
      print('\n🔍 Step 2: Looking for BPApp files specifically...');
      
      // Now search for BPApp files
      final query = "name = 'BPApp' and "
                   "mimeType='application/vnd.google-apps.spreadsheet' and "
                   "trashed=false";
      
      print('🔍 Search query: $query');
      
      final response = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name,owners,permissions,capabilities)',
      );
      
      print('📋 Found ${response.files?.length ?? 0} BPApp files');
      
      if (response.files != null && response.files!.isNotEmpty) {
        // Look through all BPApp files to find one owned by educator
        for (int i = 0; i < response.files!.length; i++) {
          final file = response.files![i];
          print('\n🔍 Checking BPApp file $i:');
          print('   Name: ${file.name}');
          print('   ID: ${file.id}');
          print('   Can Edit: ${file.capabilities?.canEdit}');
          
          // Check owners
          if (file.owners != null) {
            print('   Owners:');
            for (final owner in file.owners!) {
              print('     - ${owner.emailAddress} ${owner.emailAddress == educatorEmail ? "✅ MATCH!" : ""}');
              if (owner.emailAddress == educatorEmail) {
                print('✅✅✅ FOUND educator-owned BPApp!');
                print('   Spreadsheet ID: ${file.id}');
                print('   Service account can edit: ${file.capabilities?.canEdit}');
                
                // Check permissions in detail
                if (file.permissions != null) {
                  print('   Permissions on this file:');
                  for (final perm in file.permissions!) {
                    print('     - ${perm.emailAddress}: ${perm.role}');
                  }
                }
                
                return file.id;
              }
            }
          } else {
            print('   No owner information available');
          }
        }
      } else {
        print('❌ No BPApp files found at all');
      }
      
      print('❌ No educator-owned BPApp found for: $educatorEmail');
      print('🔍 === END SEARCH ===\n');
      return null;
      
    } catch (e) {
      print('❌❌❌ Error searching for educator spreadsheet');
      print('   Error type: ${e.runtimeType}');
      print('   Error message: $e');
      return null;
    }
  }
  
  /// Public method to create educator spreadsheet - DISABLED
  /// Educators must create their own spreadsheets through self-initialization
  Future<String?> createEducatorSpreadsheet(String educatorEmail) async {
    _logDebug('⚠️ Service account spreadsheet creation DISABLED');
    _logDebug('ℹ️ Educators must sign in to create their own BPApp');
    _logDebug('ℹ️ The educator self-init service handles this automatically');
    return null;
    
    // OLD CODE DISABLED - educators create their own spreadsheets
    // if (!_isInitialized || _sheetsApi == null || _driveApi == null) {
    //   _logDebug('Service account not initialized for educator spreadsheet creation');
    //   return null;
    // }
    // final educatorName = educatorEmail.split('@')[0];
    // return await _createEducatorSpreadsheet(educatorEmail, educatorName);
  }
  
  /// Create new spreadsheet for educator - DISABLED
  /// This method is no longer used as educators create their own spreadsheets
  Future<String?> _createEducatorSpreadsheet(String educatorEmail, String educatorName) async {
    _logDebug('⚠️ _createEducatorSpreadsheet called but DISABLED');
    _logDebug('Educators must create their own spreadsheets');
    return null;
    
    // OLD CODE DISABLED - keeping for reference
    // Service account should NOT create educator spreadsheets
    // Educators create and own their spreadsheets, then share with service account
  }
  
  /// Add Hebrew headers to spreadsheet
  Future<void> _addHeadersToSpreadsheet(String spreadsheetId) async {
    if (_sheetsApi == null) return;
    
    try {
      const hebrewHeaders = [
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
      
      final range = 'נתוני תלמידים!A1:L1';
      final valueRange = sheets.ValueRange(values: [hebrewHeaders]);
      
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'RAW',
      );
      
      // Format headers (bold, centered, gray background)
      await _formatHeaders(spreadsheetId);
      
    } catch (e) {
      _logDebug('Error adding headers: $e');
    }
  }
  
  /// Format headers with styling
  Future<void> _formatHeaders(String spreadsheetId) async {
    if (_sheetsApi == null) return;
    
    try {
      final requests = [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: 0,
              startRowIndex: 0,
              endRowIndex: 1,
              startColumnIndex: 0,
              endColumnIndex: 12,
            ),
            cell: sheets.CellData(
              userEnteredFormat: sheets.CellFormat(
                backgroundColor: sheets.Color(red: 0.9, green: 0.9, blue: 0.9),
                textFormat: sheets.TextFormat(bold: true, fontSize: 12),
                horizontalAlignment: 'CENTER',
              ),
            ),
            fields: 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)',
          ),
        ),
      ];
      
      final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(requests: requests);
      await _sheetsApi!.spreadsheets.batchUpdate(batchUpdateRequest, spreadsheetId);
      
    } catch (e) {
      _logDebug('Error formatting headers: $e');
    }
  }
  
  /// Transfer spreadsheet ownership to educator - DISABLED
  /// This is no longer needed as educators create their own spreadsheets
  Future<void> _shareSpreadsheetWithEducator(String spreadsheetId, String educatorEmail) async {
    _logDebug('⚠️ _shareSpreadsheetWithEducator called but DISABLED');
    _logDebug('Ownership transfer not needed - educators own their spreadsheets');
    return;
    
    // OLD CODE DISABLED - ownership transfer not needed
    // Educators create and own their spreadsheets from the start
    // They share them with the service account during self-initialization
  }
  
  /// Save student record to educator spreadsheet using spreadsheet ID
  /// This is used when we already have the spreadsheet ID
  Future<bool> saveRecordToSpreadsheetById(
    StudentRecord record,
    String spreadsheetId,
    String educatorEmail,
  ) async {
    if (!_isInitialized) {
      _logDebug('❌ Service account not initialized for saving');
      return false;
    }
    
    try {
      _logDebug('💾 Saving record to educator spreadsheet ID: $spreadsheetId');
      _logDebug('📋 Record details: ${record.studentName} - ${record.className}');
      
      // Save record to spreadsheet
      final success = await _saveRecordToSpreadsheet(spreadsheetId, record);
      
      if (success) {
        _logDebug('✅ Successfully saved record to educator spreadsheet');
      } else {
        _logDebug('❌ Failed to save record to educator spreadsheet');
      }
      
      return success;
      
    } catch (e) {
      _logDebug('❌ Error saving to educator spreadsheet: $e');
      return false;
    }
  }
  
  /// Save student record to centralized educator spreadsheet
  /// 
  /// This replaces the individual OAuth approach with centralized management
  Future<bool> saveRecordToEducatorSpreadsheet(
    StudentRecord record,
    String educatorEmail,
    String educatorName,
  ) async {
    if (!_isInitialized) {
      _setError('שירות החשבון לא מאותחל');
      return false;
    }
    
    try {
      _logDebug('Saving record to educator spreadsheet: $educatorName');
      
      // Get or create educator spreadsheet
      final spreadsheetId = await createOrAccessEducatorSpreadsheet(educatorEmail, educatorName);
      if (spreadsheetId == null) {
        _setError('לא ניתן לגשת לגיליון של המחנך');
        return false;
      }
      
      // Save record to spreadsheet
      final success = await _saveRecordToSpreadsheet(spreadsheetId, record);
      
      if (success) {
        _logDebug('Successfully saved record to educator spreadsheet');
      } else {
        _logDebug('Failed to save record to educator spreadsheet');
      }
      
      return success;
      
    } catch (e) {
      _setError('שגיאה בשמירה לגיליון המחנך: ${e.toString()}');
      _logDebug('Error saving to educator spreadsheet: $e');
      return false;
    }
  }
  
  /// Save record to specific spreadsheet with intelligent insertion
  Future<bool> _saveRecordToSpreadsheet(String spreadsheetId, StudentRecord record) async {
    if (_sheetsApi == null) {
      _logDebug('❌ Sheets API is null - cannot save');
      return false;
    }
    
    try {
      _logDebug('📝 Preparing to save record to spreadsheet: $spreadsheetId');
      _logDebug('📋 Student: ${record.studentName}, Class: ${record.className}');
      _logDebug('📊 Scores: Entry=${record.entry}, Stay=${record.staying}, Attitude=${record.attitude}');
      
      // First check if record already exists (4-field matching)
      final existingRowNumber = await _findExistingRow(spreadsheetId, record);
      
      if (existingRowNumber != null) {
        // Update existing record
        _logDebug('📝 Updating existing record at row $existingRowNumber');
        return await _updateRow(spreadsheetId, record, existingRowNumber);
      } else {
        // Find correct position for new record
        _logDebug('🆕 Adding new record with intelligent sorting');
        final insertPosition = await _findInsertPosition(spreadsheetId, record);
        
        if (insertPosition == -1) {
          // Append to end
          _logDebug('➕ Appending record to end of spreadsheet');
          return await _appendToEnd(spreadsheetId, record);
        } else {
          // Insert at specific position
          _logDebug('📍 Inserting record at position $insertPosition');
          return await _insertAtPosition(spreadsheetId, record, insertPosition);
        }
      }
      
    } catch (e) {
      _logDebug('❌ Error saving record: $e');
      return false;
    }
  }
  
  /// Find existing row using 4-field matching
  Future<int?> _findExistingRow(String spreadsheetId, StudentRecord record) async {
    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        'נתוני תלמידים!A2:D',
      );
      
      if (response.values == null) return null;
      
      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        if (row.length >= 4 &&
            row[0]?.toString() == record.date &&
            row[1]?.toString() == record.studentName &&
            row[2]?.toString() == record.className &&
            int.tryParse(row[3]?.toString() ?? '') == record.classNumber) {
          return i + 2; // +2 because we start from row 2
        }
      }
      
      return null;
    } catch (e) {
      _logDebug('Error finding existing row: $e');
      return null;
    }
  }
  
  /// Update existing row
  Future<bool> _updateRow(String spreadsheetId, StudentRecord record, int rowNumber) async {
    try {
      final dataRow = record.withCalculatedScore().toSheetRow();
      final valueRange = sheets.ValueRange(
        values: [dataRow],
      );
      
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        'נתוני תלמידים!A$rowNumber:L$rowNumber',
        valueInputOption: 'RAW',
      );
      
      _logDebug('✅ Updated row $rowNumber successfully');
      return true;
    } catch (e) {
      _logDebug('❌ Error updating row: $e');
      return false;
    }
  }
  
  /// Find the correct position to insert the record based on date and class number
  Future<int> _findInsertPosition(String spreadsheetId, StudentRecord record) async {
    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        'נתוני תלמידים!A2:D',
      );
      
      if (response.values == null || response.values!.isEmpty) {
        return -1; // Empty sheet, append to end
      }
      
      _logDebug('🔄 [SORT] Finding position for record: ${record.date} (class ${record.classNumber})');
      
      // Parse the new record's date
      final newRecordDate = _parseDate(record.date);
      _logDebug('🔄 [SORT] Parsed record date: $newRecordDate');
      
      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        if (row.isEmpty) continue;
        
        final existingDate = _parseDate(row[0]?.toString() ?? '');
        final existingClassNum = int.tryParse(row[3]?.toString() ?? '') ?? 0;
        
        _logDebug('🔄 [SORT] Comparing with row ${i + 2}: ${row[0]} (class $existingClassNum)');
        
        // First sort by date (newer dates first)
        if (newRecordDate != null && existingDate != null) {
          if (newRecordDate.isAfter(existingDate)) {
            _logDebug('✅ [SORT] Found position by date: inserting at row ${i + 2}');
            return i + 2; // Insert before this row
          } else if (newRecordDate.isEqual(existingDate)) {
            // Same date, sort by class number (ascending)
            if (record.classNumber < existingClassNum) {
              _logDebug('✅ [SORT] Found position by class number: inserting at row ${i + 2}');
              return i + 2; // Insert before this row
            }
          }
        }
      }
      
      return -1; // Append to end
    } catch (e) {
      _logDebug('Error finding insert position: $e');
      return -1;
    }
  }
  
  /// Parse date string to DateTime for comparison
  DateTime? _parseDate(String dateStr) {
    try {
      // Expected format: DD/MM/YYYY
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      _logDebug('Error parsing date "$dateStr": $e');
    }
    return null;
  }
  
  /// Insert record at specific position
  Future<bool> _insertAtPosition(String spreadsheetId, StudentRecord record, int rowNumber) async {
    try {
      // First, get the sheet ID
      final spreadsheet = await _sheetsApi!.spreadsheets.get(spreadsheetId);
      final sheetId = spreadsheet.sheets?.first.properties?.sheetId ?? 0;
      _logDebug('📋 Using sheet ID: $sheetId for insertion');
      
      // Insert a blank row at the position
      final insertRequest = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            insertDimension: sheets.InsertDimensionRequest(
              range: sheets.DimensionRange(
                sheetId: sheetId, // Use actual sheet ID
                dimension: 'ROWS',
                startIndex: rowNumber - 1, // 0-indexed
                endIndex: rowNumber,
              ),
              inheritFromBefore: false,
            ),
          ),
        ],
      );
      
      await _sheetsApi!.spreadsheets.batchUpdate(
        insertRequest,
        spreadsheetId,
      );
      
      // Then update the new row with data
      final dataRow = record.withCalculatedScore().toSheetRow();
      final valueRange = sheets.ValueRange(
        values: [dataRow],
      );
      
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        'נתוני תלמידים!A$rowNumber:L$rowNumber',
        valueInputOption: 'RAW',
      );
      
      _logDebug('✅ Inserted record at position $rowNumber');
      return true;
    } catch (e) {
      _logDebug('❌ Error inserting at position: $e');
      return false;
    }
  }
  
  /// Append record to end of spreadsheet
  Future<bool> _appendToEnd(String spreadsheetId, StudentRecord record) async {
    try {
      final dataRow = record.withCalculatedScore().toSheetRow();
      final valueRange = sheets.ValueRange(
        values: [dataRow],
      );
      
      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        'נתוני תלמידים!A:L',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );
      
      _logDebug('✅ Appended record to end of spreadsheet');
      return true;
    } catch (e) {
      _logDebug('❌ Error appending to end: $e');
      return false;
    }
  }
  
  /// Get all educator spreadsheets managed by service account
  /// Used for admin/monitoring purposes
  Future<List<Map<String, String>>> getManagedSpreadsheets() async {
    if (!_isInitialized || _driveApi == null) return [];
    
    try {
      final response = await _driveApi!.files.list(
        q: "name contains 'BPApp -' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name,createdTime,modifiedTime)',
      );
      
      if (response.files == null) return [];
      
      return response.files!.map((file) => {
        'id': file.id ?? '',
        'name': file.name ?? '',
        'createdTime': file.createdTime?.toIso8601String() ?? '',
        'modifiedTime': file.modifiedTime?.toIso8601String() ?? '',
      }).toList();
      
    } catch (e) {
      _logDebug('Error getting managed spreadsheets: $e');
      return [];
    }
  }
  
  /// Health check for service account
  Future<bool> healthCheck() async {
    if (!_isInitialized) return false;
    
    try {
      // Test API access by listing drive files (minimal operation)
      await _driveApi?.files.list(pageSize: 1);
      return true;
    } catch (e) {
      _logDebug('Service account health check failed: $e');
      return false;
    }
  }
  
  // ===== HELPER METHODS =====
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  void _logDebug(String message) {
    if (AppConfig.debugEnterpriseFeatures) {
      debugPrint('[SERVICE_ACCOUNT] $message');
    }
  }
  
  @override
  void dispose() {
    _authClient?.close();
    super.dispose();
  }
}
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
    if (!isEnabled) {
      _logDebug('Service account disabled in config - skipping initialization');
      _logDebug('AppConfig.useServiceAccount: ${AppConfig.useServiceAccount}');
      _logDebug('AppConfig.emergencyDisable: ${AppConfig.emergencyDisable}');
      return false;
    }
    
    _setLoading(true);
    _setError(null);
    
    try {
      _logDebug('🚀 Starting service account initialization...');
      _logDebug('Config: useServiceAccount=${AppConfig.useServiceAccount}, emergencyDisable=${AppConfig.emergencyDisable}');
      
      // Load service account credentials from assets
      await _loadCredentials();
      
      // Create authenticated client
      await _createAuthenticatedClient();
      
      // Initialize APIs
      _initializeApis();
      
      _isInitialized = true;
      _logDebug('✅ Service account initialization successful!');
      _logDebug('Ready to create educator spreadsheets with ownership transfer');
      return true;
      
    } catch (e, stackTrace) {
      _setError('שגיאה באתחול שירות החשבון: ${e.toString()}');
      _logDebug('❌ Service account initialization failed: $e');
      _logDebug('Stack trace: $stackTrace');
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
  
  /// Create authenticated HTTP client using service account with impersonation
  Future<void> _createAuthenticatedClient() async {
    if (_credentials == null || _credentialsJson == null) {
      throw Exception('Service account credentials not loaded');
    }
    
    try {
      _logDebug('Creating authenticated client with JWT impersonation');
      _logDebug('Service account: ${_credentials!.email}');
      _logDebug('Impersonating user: $adminEmail');
      _logDebug('Scopes: $_scopes');
      
      // Use custom JWT authentication with impersonation
      _authClient = await ServiceAccountJWTAuth.createImpersonatedClient(
        serviceAccountJson: _credentialsJson!,
        scopes: _scopes,
        impersonatedUser: adminEmail, // admin@bpappedu.com - NOW WITH PROPER IMPERSONATION!
      );
      
      _logDebug('✅ Authenticated client created with impersonation!');
      _logDebug('✅ Service account is now acting as: $adminEmail');
      print('🎯 IMPERSONATION ACTIVE: Service account is now admin@bpappedu.com');
      
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
  
  /// Create or access centralized spreadsheet for educator
  /// 
  /// Unlike OAuth approach, this creates/manages spreadsheets centrally
  /// with service account as owner and educators as editors
  Future<String?> createOrAccessEducatorSpreadsheet(String educatorEmail, String educatorName) async {
    if (!_isInitialized) {
      _setError('שירות החשבון לא מאותחל');
      return null;
    }
    
    try {
      _logDebug('Creating/accessing spreadsheet for educator: $educatorName ($educatorEmail)');
      
      // Search for existing educator spreadsheet
      final existingSpreadsheetId = await _findEducatorSpreadsheet(educatorEmail);
      
      if (existingSpreadsheetId != null) {
        _logDebug('Found existing spreadsheet: $existingSpreadsheetId');
        return existingSpreadsheetId;
      }
      
      // Create new spreadsheet for educator
      final spreadsheetId = await _createEducatorSpreadsheet(educatorEmail, educatorName);
      _logDebug('Created new spreadsheet: $spreadsheetId');
      
      return spreadsheetId;
      
    } catch (e) {
      _setError('שגיאה ביצירת גיליון למחנך: ${e.toString()}');
      _logDebug('Error creating/accessing educator spreadsheet: $e');
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
    if (!_isInitialized || _driveApi == null) {
      _logDebug('Service account not initialized for spreadsheet search');
      return null;
    }
    
    try {
      _logDebug('🔍 Searching for educator spreadsheet owned by: $educatorEmail');
      
      // Search for BPApp files owned by the educator
      final query = "name = 'BPApp' and "
                   "mimeType='application/vnd.google-apps.spreadsheet' and "
                   "trashed=false and "
                   "'$educatorEmail' in owners";
      
      final response = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name,owners)',
      );
      
      if (response.files != null && response.files!.isNotEmpty) {
        final spreadsheetId = response.files!.first.id!;
        _logDebug('✅ Found existing educator spreadsheet: $spreadsheetId');
        return spreadsheetId;
      }
      
      _logDebug('No existing educator spreadsheet found');
      return null;
      
    } catch (e) {
      _logDebug('Error searching for educator spreadsheet: $e');
      return null;
    }
  }
  
  /// Public method to create educator spreadsheet with ownership transfer
  Future<String?> createEducatorSpreadsheet(String educatorEmail) async {
    if (!_isInitialized || _sheetsApi == null || _driveApi == null) {
      _logDebug('Service account not initialized for educator spreadsheet creation');
      return null;
    }
    
    // Use educator email as name if no specific name provided
    final educatorName = educatorEmail.split('@')[0];
    return await _createEducatorSpreadsheet(educatorEmail, educatorName);
  }
  
  /// Create new spreadsheet for educator
  Future<String?> _createEducatorSpreadsheet(String educatorEmail, String educatorName) async {
    if (_sheetsApi == null) return null;
    
    try {
      // Create spreadsheet with Hebrew RTL support
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: 'BPApp',
          locale: 'en_US',
          timeZone: 'Asia/Jerusalem',
        ),
        sheets: [
          sheets.Sheet(
            properties: sheets.SheetProperties(
              title: 'נתוני תלמידים',
              rightToLeft: true,
              gridProperties: sheets.GridProperties(
                frozenRowCount: 1,
                columnCount: 12, // Same as original headers
              ),
            ),
          ),
        ],
      );
      
      final response = await _sheetsApi!.spreadsheets.create(spreadsheet);
      final spreadsheetId = response.spreadsheetId!;
      
      // Add headers to new spreadsheet
      await _addHeadersToSpreadsheet(spreadsheetId);
      
      // Share with educator (give edit access)
      await _shareSpreadsheetWithEducator(spreadsheetId, educatorEmail);
      
      return spreadsheetId;
      
    } catch (e) {
      _logDebug('Error creating educator spreadsheet: $e');
      return null;
    }
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
  
  /// Transfer spreadsheet ownership to educator (appears in their My Drive)
  Future<void> _shareSpreadsheetWithEducator(String spreadsheetId, String educatorEmail) async {
    if (_driveApi == null) return;
    
    try {
      _logDebug('=== SERVICE ACCOUNT OWNERSHIP TRANSFER ===');
      _logDebug('Spreadsheet ID: $spreadsheetId');
      _logDebug('Target educator: $educatorEmail');
      _logDebug('Service account email: ${_credentials?.email}');
      
      // Check current permissions first
      try {
        final currentPermissions = await _driveApi!.permissions.list(spreadsheetId);
        _logDebug('Current permissions before transfer:');
        if (currentPermissions.permissions != null) {
          for (final perm in currentPermissions.permissions!) {
            _logDebug('  ${perm.type}/${perm.role} - ${perm.emailAddress}');
          }
        }
      } catch (e) {
        _logDebug('Could not read current permissions: $e');
      }
      
      // WITH PROPER IMPERSONATION, WE CAN NOW TRANSFER OWNERSHIP!
      _logDebug('🚀 OWNERSHIP TRANSFER WITH IMPERSONATION');
      _logDebug('Service account impersonating: $adminEmail');
      
      // Transfer ownership to educator (will appear in their My Drive)
      final ownerPermission = drive.Permission(
        type: 'user',
        role: 'owner',
        emailAddress: educatorEmail,
      );
      
      _logDebug('Transferring ownership to educator: $educatorEmail');
      
      final result = await _driveApi!.permissions.create(
        ownerPermission,
        spreadsheetId,
        transferOwnership: true,
        sendNotificationEmail: true,
        emailMessage: 'גיליון BPApp נוצר עבורך וזמין ב"הכונן שלי".',
      );
      
      _logDebug('✅ Drive API call completed successfully');
      _logDebug('✅ Result permission ID: ${result.id}');
      _logDebug('✅ Result role: ${result.role}');
      
      // Verify transfer by checking file ownership
      try {
        final fileInfo = await _driveApi!.files.get(spreadsheetId, $fields: 'owners,shared') as drive.File;
        _logDebug('POST-TRANSFER verification:');
        _logDebug('  Owners: ${fileInfo.owners?.map((o) => o.emailAddress).toList()}');
        _logDebug('  Shared: ${fileInfo.shared}');
        
        final isEducatorOwner = fileInfo.owners?.any((o) => o.emailAddress == educatorEmail) == true;
        if (isEducatorOwner) {
          _logDebug('✅✅✅ VERIFICATION SUCCESS: Educator is now owner!');
        } else {
          _logDebug('❌❌❌ VERIFICATION FAILED: Educator not found in owners!');
        }
      } catch (e) {
        _logDebug('Could not verify ownership transfer: $e');
      }
      
      // STEP 2: Ensure service account retains writer access
      try {
        if (_credentials?.email != null) {
          final servicePermission = drive.Permission(
            type: 'user',
            role: 'writer',
            emailAddress: _credentials!.email,
          );
          
          await _driveApi!.permissions.create(
            servicePermission,
            spreadsheetId,
            sendNotificationEmail: false,
          );
          
          _logDebug('✅ Service account retained writer access');
        }
      } catch (serviceError) {
        _logDebug('⚠️ Could not retain service account access: $serviceError');
      }
      
    } catch (e) {
      _logDebug('❌❌❌ === OWNERSHIP TRANSFER FAILED ===');
      _logDebug('❌❌❌ Error type: ${e.runtimeType}');
      _logDebug('❌❌❌ Error details: $e');
      _logDebug('❌❌❌ Full error string: ${e.toString()}');
      
      // Analyze the error
      final errorStr = e.toString();
      if (errorStr.contains('403')) {
        _logDebug('🔒 DIAGNOSIS: 403 Forbidden - Service account lacks ownership transfer permission');
        _logDebug('🔒 SOLUTION: Service account needs domain-wide delegation or different approach');
      } else if (errorStr.contains('400')) {
        _logDebug('⚠️ DIAGNOSIS: 400 Bad Request - Invalid API call parameters');
      } else if (errorStr.contains('404')) {
        _logDebug('📂 DIAGNOSIS: 404 Not Found - Spreadsheet or user not found');
      }
      
      _logDebug('⚠️ Falling back to sharing (file will be in Shared with me)');
      
      // Fallback: Just share if ownership transfer fails
      try {
        final writerPermission = drive.Permission(
          type: 'user',
          role: 'writer',
          emailAddress: educatorEmail,
        );
        
        await _driveApi!.permissions.create(
          writerPermission,
          spreadsheetId,
          sendNotificationEmail: true,
          emailMessage: 'גיליון BPApp שותף איתך. הוא יופיע ב"שותף איתי".',
        );
        
        _logDebug('📁 Shared spreadsheet as fallback');
      } catch (shareError) {
        _logDebug('❌ Could not share spreadsheet: $shareError');
      }
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
  
  /// Save record to specific spreadsheet
  Future<bool> _saveRecordToSpreadsheet(String spreadsheetId, StudentRecord record) async {
    if (_sheetsApi == null) return false;
    
    try {
      // Use append operation for simplicity in Phase 1
      // TODO: Add matching/updating logic in future iterations
      final valueRange = sheets.ValueRange(
        values: [record.withCalculatedScore().toSheetRow()],
      );
      
      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        'נתוני תלמידים!A:L',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );
      
      return true;
      
    } catch (e) {
      _logDebug('Error saving record to spreadsheet: $e');
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
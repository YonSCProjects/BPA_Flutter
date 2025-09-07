import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';
import 'google_sheets_service.dart';
import '../core/educator_mappings.dart';

/// Service for educators to self-initialize their BPApp spreadsheet
/// Creates the spreadsheet in their own drive and shares with service account
class EducatorSelfInitService extends ChangeNotifier {
  final GoogleAuthService _authService;
  
  // Service account email that needs editor access
  static const String serviceAccountEmail = 'bpapp-service-account@bpapp-firebase-485c1.iam.gserviceaccount.com';
  
  EducatorSelfInitService(this._authService);
  
  /// Check if current user is an educator
  Future<bool> isEducator() async {
    final currentUserEmail = _authService.currentUser?.email;
    if (currentUserEmail == null) return false;
    
    // Check if this email is registered as an educator
    final educatorEmails = EducatorMappings.getAllEducatorEmails();
    return educatorEmails.contains(currentUserEmail);
  }
  
  /// Check if educator already has a BPApp spreadsheet
  Future<String?> findEducatorSpreadsheet() async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) return null;
      
      final driveApi = drive.DriveApi(client);
      final currentUserEmail = _authService.currentUser?.email;
      
      debugPrint('🔍 [EDUCATOR-INIT] Searching for existing BPApp for: $currentUserEmail');
      
      // Search for BPApp owned by the educator
      final query = "name = 'BPApp' and "
                   "mimeType='application/vnd.google-apps.spreadsheet' and "
                   "trashed=false and "
                   "'me' in owners"; // 'me' means the authenticated user
      
      final response = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name,owners)',
      );
      
      if (response.files != null && response.files!.isNotEmpty) {
        final spreadsheetId = response.files!.first.id!;
        debugPrint('✅ [EDUCATOR-INIT] Found existing BPApp: $spreadsheetId');
        return spreadsheetId;
      }
      
      debugPrint('❌ [EDUCATOR-INIT] No existing BPApp found');
      return null;
      
    } catch (e) {
      debugPrint('❌ [EDUCATOR-INIT] Error searching for spreadsheet: $e');
      return null;
    }
  }
  
  /// Initialize educator's BPApp spreadsheet
  /// Creates it in their drive and shares with service account
  Future<String?> initializeEducatorSpreadsheet() async {
    try {
      final currentUserEmail = _authService.currentUser?.email;
      if (currentUserEmail == null) {
        debugPrint('❌ [EDUCATOR-INIT] No authenticated user');
        return null;
      }
      
      debugPrint('🚀 [EDUCATOR-INIT] Starting initialization for educator: $currentUserEmail');
      
      // Check if already exists
      final existingId = await findEducatorSpreadsheet();
      if (existingId != null) {
        debugPrint('ℹ️ [EDUCATOR-INIT] Spreadsheet already exists, ensuring service account access');
        await _ensureServiceAccountAccess(existingId);
        return existingId;
      }
      
      // Create new spreadsheet in educator's drive
      final spreadsheetId = await _createEducatorSpreadsheet();
      if (spreadsheetId == null) {
        debugPrint('❌ [EDUCATOR-INIT] Failed to create spreadsheet');
        return null;
      }
      
      // Share with service account
      await _shareWithServiceAccount(spreadsheetId);
      
      debugPrint('✅ [EDUCATOR-INIT] Successfully initialized educator spreadsheet');
      return spreadsheetId;
      
    } catch (e) {
      debugPrint('❌ [EDUCATOR-INIT] Error initializing: $e');
      return null;
    }
  }
  
  /// Create BPApp spreadsheet in educator's drive
  Future<String?> _createEducatorSpreadsheet() async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) return null;
      
      final sheetsApi = sheets.SheetsApi(client);
      final currentUserEmail = _authService.currentUser?.email;
      
      debugPrint('📝 [EDUCATOR-INIT] Creating BPApp for educator: $currentUserEmail');
      
      // Create spreadsheet with Hebrew setup
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
                columnCount: 12,
              ),
            ),
          ),
        ],
      );
      
      final response = await sheetsApi.spreadsheets.create(spreadsheet);
      final spreadsheetId = response.spreadsheetId!;
      
      debugPrint('✅ [EDUCATOR-INIT] Created spreadsheet: $spreadsheetId');
      
      // Add headers
      await _addHeaders(sheetsApi, spreadsheetId);
      
      return spreadsheetId;
      
    } catch (e) {
      debugPrint('❌ [EDUCATOR-INIT] Error creating spreadsheet: $e');
      return null;
    }
  }
  
  /// Add Hebrew headers to the spreadsheet
  Future<void> _addHeaders(sheets.SheetsApi sheetsApi, String spreadsheetId) async {
    try {
      final headers = [
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
        'הערות',
        'סה"כ',
      ];
      
      final values = sheets.ValueRange(
        range: 'נתוני תלמידים!A1:L1',
        majorDimension: 'ROWS',
        values: [headers],
      );
      
      await sheetsApi.spreadsheets.values.update(
        values,
        spreadsheetId,
        'נתוני תלמידים!A1:L1',
        valueInputOption: 'USER_ENTERED',
      );
      
      debugPrint('✅ [EDUCATOR-INIT] Headers added');
      
    } catch (e) {
      debugPrint('⚠️ [EDUCATOR-INIT] Error adding headers: $e');
    }
  }
  
  /// Share the spreadsheet with service account as editor
  Future<void> _shareWithServiceAccount(String spreadsheetId) async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('❌ [EDUCATOR-INIT] No authenticated client for sharing');
        return;
      }
      
      final driveApi = drive.DriveApi(client);
      
      debugPrint('🔗 [EDUCATOR-INIT] Sharing with service account: $serviceAccountEmail');
      debugPrint('🔗 [EDUCATOR-INIT] Spreadsheet ID: $spreadsheetId');
      
      // Create permission for service account
      final permission = drive.Permission(
        type: 'user',
        role: 'writer', // Editor access
        emailAddress: serviceAccountEmail,
      );
      
      debugPrint('🔗 [EDUCATOR-INIT] Creating permission: type=user, role=writer, email=$serviceAccountEmail');
      
      await driveApi.permissions.create(
        permission,
        spreadsheetId,
        sendNotificationEmail: false, // Don't send email to service account
      );
      
      debugPrint('✅ [EDUCATOR-INIT] Successfully shared with service account');
      
    } catch (e) {
      debugPrint('❌ [EDUCATOR-INIT] Error sharing with service account: $e');
      debugPrint('❌ [EDUCATOR-INIT] Error type: ${e.runtimeType}');
      if (e.toString().contains('403')) {
        debugPrint('❌ [EDUCATOR-INIT] Permission denied - may need broader OAuth scope');
        debugPrint('❌ [EDUCATOR-INIT] Current scopes may not include drive sharing permissions');
      }
      // Don't throw - allow spreadsheet creation to succeed even if sharing fails
      // User can manually share later
      debugPrint('⚠️ [EDUCATOR-INIT] Spreadsheet created but not shared - educator must share manually');
    }
  }
  
  /// Ensure service account has access to existing spreadsheet
  Future<void> _ensureServiceAccountAccess(String spreadsheetId) async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) return;
      
      final driveApi = drive.DriveApi(client);
      
      // Check if service account already has access
      final permissions = await driveApi.permissions.list(spreadsheetId);
      
      bool hasAccess = false;
      if (permissions.permissions != null) {
        for (final perm in permissions.permissions!) {
          if (perm.emailAddress == serviceAccountEmail) {
            hasAccess = true;
            debugPrint('✅ [EDUCATOR-INIT] Service account already has access');
            break;
          }
        }
      }
      
      // Add permission if not already there
      if (!hasAccess) {
        debugPrint('🔗 [EDUCATOR-INIT] Adding service account access');
        await _shareWithServiceAccount(spreadsheetId);
      }
      
    } catch (e) {
      debugPrint('⚠️ [EDUCATOR-INIT] Error checking permissions: $e');
    }
  }
}
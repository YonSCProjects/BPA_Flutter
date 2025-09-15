import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'google_auth_service.dart';
import '../config/app_config.dart';

/// Secretary Service - Handles secretary-specific operations
///
/// Creates and manages the centralized attendance spreadsheet
/// that all teachers will use through the service account
class SecretaryService extends ChangeNotifier {
  static const String attendanceSpreadsheetName = 'BPApp_Attendance';
  static const String attendanceMainSheet = 'סיכום נוכחות';
  static const String serviceAccountEmail = 'bpapp-service-account@bpapp-firebase-485c1.iam.gserviceaccount.com';

  final GoogleAuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  sheets.SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi;
  String? _attendanceSpreadsheetId;
  bool _isInitialized = false;
  String? _error;

  SecretaryService(this._authService);

  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get attendanceSpreadsheetId => _attendanceSpreadsheetId;

  /// Initialize secretary services and create attendance spreadsheet if needed
  Future<bool> initializeSecretary() async {
    try {
      debugPrint('👩‍💼 [SECRETARY] ==========================================');
      debugPrint('👩‍💼 [SECRETARY] Starting secretary service initialization');
      debugPrint('👩‍💼 [SECRETARY] ==========================================');

      final userEmail = _authService.currentUser?.email;
      debugPrint('👩‍💼 [SECRETARY] Current user email: $userEmail');

      if (userEmail == null) {
        _error = 'משתמש לא מחובר';
        debugPrint('❌ [SECRETARY] No user email found - not signed in');
        return false;
      }

      // Check if user has secretary role
      final isSecretary = await _checkSecretaryRole(userEmail);
      if (!isSecretary) {
        debugPrint('ℹ️ [SECRETARY] User is not a secretary, skipping initialization');
        return false;
      }

      debugPrint('✅ [SECRETARY] User confirmed as secretary: $userEmail');

      // Initialize Google APIs with user's OAuth
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        _error = 'לא ניתן להתחבר לשירותי Google';
        return false;
      }

      _sheetsApi = sheets.SheetsApi(client);
      _driveApi = drive.DriveApi(client);

      // Check if attendance spreadsheet already exists in Firestore
      _attendanceSpreadsheetId = await _getStoredAttendanceSheetId();

      if (_attendanceSpreadsheetId != null) {
        debugPrint('📋 [SECRETARY] Found existing attendance sheet: $_attendanceSpreadsheetId');
        // Verify it still exists and is accessible
        if (!await _verifySpreadsheetExists(_attendanceSpreadsheetId!)) {
          debugPrint('⚠️ [SECRETARY] Stored spreadsheet no longer exists, creating new one');
          _attendanceSpreadsheetId = null;
        }
      }

      if (_attendanceSpreadsheetId == null) {
        // Try to find existing BPApp_Attendance spreadsheet first
        debugPrint('🔍 [SECRETARY] Looking for existing attendance spreadsheet in Drive');
        _attendanceSpreadsheetId = await _findExistingAttendanceSheet();

        if (_attendanceSpreadsheetId != null) {
          debugPrint('📋 [SECRETARY] Found existing attendance sheet: $_attendanceSpreadsheetId');
          // Share with service account if not already shared
          await _shareWithServiceAccount();
          // Store the spreadsheet ID in Firestore
          await _storeAttendanceSheetId(_attendanceSpreadsheetId!);
        } else {
          // Create new attendance spreadsheet
          debugPrint('🆕 [SECRETARY] Creating new attendance spreadsheet');
          await _createAttendanceSpreadsheet();

          if (_attendanceSpreadsheetId != null) {
            // Share with service account
            await _shareWithServiceAccount();
            // Store the spreadsheet ID in Firestore
            await _storeAttendanceSheetId(_attendanceSpreadsheetId!);
          }
        }
      }

      _isInitialized = true;
      debugPrint('✅ [SECRETARY] Secretary initialization complete');
      return true;

    } catch (e) {
      _error = 'שגיאה באתחול שירותי מזכירות: $e';
      debugPrint('❌ [SECRETARY] Initialization error: $e');
      return false;
    }
  }

  /// Check if user has secretary role
  Future<bool> _checkSecretaryRole(String email) async {
    try {
      debugPrint('🔍 [SECRETARY] Checking role for email: $email');

      // First try by document ID (legacy)
      final userDoc = await _firestore.collection('users').doc(email).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final role = data?['role'];
        debugPrint('📄 [SECRETARY] Found user by document ID: $email');
        debugPrint('📄 [SECRETARY] User data: $data');
        debugPrint('📄 [SECRETARY] Role value: $role');
        if (role == 'secretary' || role == 'מזכירה') {
          debugPrint('✅ [SECRETARY] User is a secretary (by document ID)');
          return true;
        }
      } else {
        debugPrint('ℹ️ [SECRETARY] No document found with ID: $email');
      }

      // If not found by ID, search by email field
      debugPrint('🔍 [SECRETARY] Searching by email field...');

      // Also check for ALL users to debug
      final allUsersSnapshot = await _firestore.collection('users').get();
      debugPrint('📋 [SECRETARY] Total users in collection: ${allUsersSnapshot.docs.length}');
      for (var doc in allUsersSnapshot.docs) {
        final data = doc.data();
        debugPrint('📋 [SECRETARY] User doc: ID=${doc.id}, email=${data['email']}, role=${data['role']}');
      }

      // Search for ALL documents with this email (not just first one)
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();  // Remove .limit(1) to get all matching documents

      if (querySnapshot.docs.isNotEmpty) {
        debugPrint('📄 [SECRETARY] Found ${querySnapshot.docs.length} users with email: $email');

        // Check all documents for secretary role
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final role = data['role'];
          final docId = doc.id;
          debugPrint('📄 [SECRETARY] Checking document ID: $docId');
          debugPrint('📄 [SECRETARY] User data: $data');
          debugPrint('📄 [SECRETARY] Role value: $role');

          if (role == 'secretary' || role == 'מזכירה') {
            debugPrint('✅ [SECRETARY] User is a secretary (found in document: $docId)');
            return true;
          }
        }

        debugPrint('❌ [SECRETARY] User has ${querySnapshot.docs.length} documents but none with secretary role');
      } else {
        debugPrint('❌ [SECRETARY] No user found with email: $email');
      }

      debugPrint('❌ [SECRETARY] User not found or not a secretary');
      return false;
    } catch (e) {
      debugPrint('❌ [SECRETARY] Error checking role: $e');
      return false;
    }
  }

  /// Find existing attendance spreadsheet in Drive
  Future<String?> _findExistingAttendanceSheet() async {
    if (_driveApi == null) return null;

    try {
      debugPrint('🔍 [SECRETARY] Searching for existing BPApp_Attendance spreadsheet');

      // Search for spreadsheets with the exact name
      final fileList = await _driveApi!.files.list(
        q: "name='$attendanceSpreadsheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id, name, owners)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final file = fileList.files!.first;
        debugPrint('✅ [SECRETARY] Found existing attendance spreadsheet:');
        debugPrint('   ID: ${file.id}');
        debugPrint('   Name: ${file.name}');
        debugPrint('   Owners: ${file.owners?.map((o) => o.emailAddress).join(', ')}');
        return file.id;
      }

      debugPrint('ℹ️ [SECRETARY] No existing attendance spreadsheet found');
      return null;
    } catch (e) {
      debugPrint('❌ [SECRETARY] Error searching for existing sheet: $e');
      return null;
    }
  }

  /// Get stored attendance sheet ID from Firestore
  Future<String?> _getStoredAttendanceSheetId() async {
    try {
      final configDoc = await _firestore.collection('config').doc('attendance').get();
      if (configDoc.exists) {
        return configDoc.data()?['spreadsheetId'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ [SECRETARY] Error getting stored sheet ID: $e');
      return null;
    }
  }

  /// Store attendance sheet ID in Firestore
  Future<void> _storeAttendanceSheetId(String spreadsheetId) async {
    try {
      debugPrint('📝 [SECRETARY] Attempting to store sheet ID: $spreadsheetId');
      debugPrint('📝 [SECRETARY] Current user: ${_authService.currentUser?.email}');

      await _firestore.collection('config').doc('attendance').set({
        'spreadsheetId': spreadsheetId,
        'createdBy': _authService.currentUser?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'sharedWithServiceAccount': true,
      });

      debugPrint('✅ [SECRETARY] Stored attendance sheet ID in Firestore');

      // Verify it was stored
      final verifyDoc = await _firestore.collection('config').doc('attendance').get();
      if (verifyDoc.exists) {
        debugPrint('✅ [SECRETARY] Verified sheet ID stored: ${verifyDoc.data()?['spreadsheetId']}');
      } else {
        debugPrint('❌ [SECRETARY] Failed to verify stored sheet ID');
      }
    } catch (e) {
      debugPrint('❌ [SECRETARY] Error storing sheet ID: $e');
      debugPrint('❌ [SECRETARY] Error details: ${e.toString()}');
      rethrow; // Rethrow to handle it in the calling function
    }
  }

  /// Verify spreadsheet still exists
  Future<bool> _verifySpreadsheetExists(String spreadsheetId) async {
    try {
      await _sheetsApi!.spreadsheets.get(spreadsheetId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create the attendance spreadsheet
  Future<void> _createAttendanceSpreadsheet() async {
    if (_sheetsApi == null) return;

    try {
      debugPrint('📝 [SECRETARY] Creating attendance spreadsheet for all teachers');

      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: attendanceSpreadsheetName,
          locale: 'en_US',  // Use en_US instead of he_IL which is not supported
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
      _attendanceSpreadsheetId = response.spreadsheetId;

      // Add headers
      await _addSummaryHeaders();

      debugPrint('✅ [SECRETARY] Created attendance spreadsheet: $_attendanceSpreadsheetId');

    } catch (e) {
      debugPrint('❌ [SECRETARY] Error creating spreadsheet: $e');
      throw e;
    }
  }

  /// Add headers to summary sheet
  Future<void> _addSummaryHeaders() async {
    if (_sheetsApi == null || _attendanceSpreadsheetId == null) return;

    try {
      final headers = ['תאריך', 'כיתה', 'נוכחים', 'חסרים', 'סה"כ', 'אחוז נוכחות', 'מורה מדווח'];

      final valueRange = sheets.ValueRange(
        values: [headers],
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _attendanceSpreadsheetId!,
        '$attendanceMainSheet!A1:G1',
        valueInputOption: 'RAW',
      );

      // Format headers
      await _formatHeaders();

    } catch (e) {
      debugPrint('❌ [SECRETARY] Error adding headers: $e');
    }
  }

  /// Format headers
  Future<void> _formatHeaders() async {
    if (_sheetsApi == null || _attendanceSpreadsheetId == null) return;

    try {
      final requests = [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: 0,
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
        _attendanceSpreadsheetId!,
      );

    } catch (e) {
      debugPrint('❌ [SECRETARY] Error formatting headers: $e');
    }
  }

  /// Share spreadsheet with service account
  Future<void> _shareWithServiceAccount() async {
    if (_driveApi == null || _attendanceSpreadsheetId == null) return;

    try {
      debugPrint('🔗 [SECRETARY] Sharing attendance sheet with service account');

      final permission = drive.Permission(
        type: 'user',
        role: 'writer',
        emailAddress: serviceAccountEmail,
      );

      await _driveApi!.permissions.create(
        permission,
        _attendanceSpreadsheetId!,
        sendNotificationEmail: false,
      );

      debugPrint('✅ [SECRETARY] Successfully shared with service account: $serviceAccountEmail');

    } catch (e) {
      debugPrint('❌ [SECRETARY] Error sharing with service account: $e');
      throw e;
    }
  }
}
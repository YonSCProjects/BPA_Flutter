import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';
import 'google_sheets_service.dart';
import 'drive_folder_service.dart';
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

      // CRITICAL: First search entire Drive for ANY BPApp spreadsheet owned by user
      // This prevents duplicates even if folder structure changes
      debugPrint('🔍 [EDUCATOR-INIT] Searching entire Drive for BPApp spreadsheets...');

      try {
        final query = "name='BPApp' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false and 'me' in owners";
        final response = await driveApi.files.list(
          q: query,
          spaces: 'drive',
          $fields: 'files(id,name,parents,owners(emailAddress,displayName))',
        );

        if (response.files != null && response.files!.isNotEmpty) {
          final spreadsheetId = response.files!.first.id!;
          debugPrint('✅ [EDUCATOR-INIT] Found existing BPApp (Drive search): $spreadsheetId');

          // Warn if duplicates exist
          if (response.files!.length > 1) {
            debugPrint('⚠️⚠️⚠️ [EDUCATOR-INIT] WARNING: ${response.files!.length} duplicate BPApp spreadsheets found!');
            debugPrint('⚠️ [EDUCATOR-INIT] Using: $spreadsheetId');
            debugPrint('⚠️ [EDUCATOR-INIT] Duplicates: ${response.files!.skip(1).map((f) => f.id).join(", ")}');
          }

          return spreadsheetId;
        }
      } catch (e) {
        debugPrint('⚠️ [EDUCATOR-INIT] Drive search error: $e');
      }

      // Then try to find in the BPApp folder (secondary check)
      final folderService = DriveFolderService(driveApi);
      final folderId = await folderService.ensureBPAppFolder();

      if (folderId != null) {
        debugPrint('📁 [EDUCATOR-INIT] Searching in BPApp folder: $folderId');

        // Search for ALL BPApp spreadsheets in the folder first
        final allSpreadsheets = await folderService.findSpreadsheetsInFolder(
          'BPApp',
          userEmail: null, // Get ALL BPApp spreadsheets first
        );

        debugPrint('📊 [EDUCATOR-INIT] Found ${allSpreadsheets.length} total BPApp spreadsheet(s) in folder');

        // Now filter by ownership
        final ownedSpreadsheets = allSpreadsheets.where((file) {
          final isOwned = file.owners?.any((owner) =>
            owner.emailAddress?.toLowerCase() == currentUserEmail?.toLowerCase()
          ) ?? false;

          if (isOwned) {
            debugPrint('✅ [EDUCATOR-INIT] Spreadsheet ${file.id} IS owned by $currentUserEmail');
          } else {
            debugPrint('❌ [EDUCATOR-INIT] Spreadsheet ${file.id} is NOT owned by $currentUserEmail');
          }
          return isOwned;
        }).toList();

        debugPrint('📊 [EDUCATOR-INIT] Found ${ownedSpreadsheets.length} spreadsheet(s) owned by $currentUserEmail');

        if (ownedSpreadsheets.isNotEmpty) {
          final spreadsheetId = ownedSpreadsheets.first.id!;
          debugPrint('✅ [EDUCATOR-INIT] Using existing BPApp in folder: $spreadsheetId');

          // Warn about duplicates
          if (ownedSpreadsheets.length > 1) {
            debugPrint('⚠️⚠️⚠️ [EDUCATOR-INIT] WARNING: Found ${ownedSpreadsheets.length} duplicate BPApp spreadsheets!');
            debugPrint('⚠️ [EDUCATOR-INIT] Using: $spreadsheetId');
            debugPrint('⚠️ [EDUCATOR-INIT] Duplicates: ${ownedSpreadsheets.skip(1).map((f) => f.id).join(", ")}');
          }

          return spreadsheetId;
        }
      }

      // Fallback: Search in entire Drive (for legacy spreadsheets)
      final query = "name = 'BPApp' and "
                   "mimeType='application/vnd.google-apps.spreadsheet' and "
                   "trashed=false and "
                   "'me' in owners"; // 'me' means the authenticated user

      final response = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name,owners,parents)',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        final spreadsheetId = response.files!.first.id!;
        debugPrint('✅ [EDUCATOR-INIT] Found existing BPApp (not in folder): $spreadsheetId');

        // Try to move it to the folder if it's not there
        if (folderId != null && response.files!.first.parents?.contains(folderId) != true) {
          try {
            await driveApi.files.update(
              drive.File(),
              spreadsheetId,
              addParents: folderId,
              $fields: 'id,parents',
            );
            debugPrint('✅ [EDUCATOR-INIT] Moved existing spreadsheet to folder');
          } catch (e) {
            debugPrint('⚠️ [EDUCATOR-INIT] Could not move to folder: $e');
          }
        }

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

      // CRITICAL: Check multiple times to prevent duplicates
      debugPrint('⚠️ [EDUCATOR-INIT] Checking for existing spreadsheet (attempt 1)...');
      var existingId = await findEducatorSpreadsheet();
      if (existingId != null) {
        debugPrint('ℹ️ [EDUCATOR-INIT] Spreadsheet already exists: $existingId');
        await _ensureServiceAccountAccess(existingId);
        return existingId;
      }

      // Wait and check again to handle race conditions
      debugPrint('⏳ [EDUCATOR-INIT] Waiting 2 seconds and checking again...');
      await Future.delayed(const Duration(seconds: 2));

      debugPrint('⚠️ [EDUCATOR-INIT] Checking for existing spreadsheet (attempt 2)...');
      existingId = await findEducatorSpreadsheet();
      if (existingId != null) {
        debugPrint('ℹ️ [EDUCATOR-INIT] Found spreadsheet on second check: $existingId');
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

      final driveApi = drive.DriveApi(client);
      final sheetsApi = sheets.SheetsApi(client);
      final currentUserEmail = _authService.currentUser?.email;

      debugPrint('📝 [EDUCATOR-INIT] Creating BPApp for educator: $currentUserEmail');

      // First, ensure we have the BPApp folder
      final folderService = DriveFolderService(driveApi);
      final folderId = await folderService.ensureBPAppFolder();

      if (folderId == null) {
        debugPrint('❌ [EDUCATOR-INIT] Could not create/find BPApp folder');
        return null;
      }

      debugPrint('📁 [EDUCATOR-INIT] Using BPApp folder: $folderId');

      // Try to create spreadsheet directly in the folder using Drive API
      try {
        debugPrint('📝 [EDUCATOR-INIT] Attempting to create spreadsheet directly in folder...');

        // Create the spreadsheet metadata with parent folder
        final fileMetadata = drive.File()
          ..name = 'BPApp'
          ..mimeType = 'application/vnd.google-apps.spreadsheet'
          ..parents = [folderId];

        // Create the file in Drive
        final driveFile = await driveApi.files.create(
          fileMetadata,
          $fields: 'id,name,parents',
        );

        if (driveFile.id == null) {
          throw Exception('No ID returned from Drive API');
        }

        final spreadsheetId = driveFile.id!;
        debugPrint('✅ [EDUCATOR-INIT] Created spreadsheet in folder via Drive API: $spreadsheetId');

        // Now set up the spreadsheet structure using Sheets API
        await _setupSpreadsheetStructure(sheetsApi, spreadsheetId);

        // Add headers
        await _addHeaders(sheetsApi, spreadsheetId);

        return spreadsheetId;

      } catch (e) {
        debugPrint('⚠️ [EDUCATOR-INIT] Drive API creation failed, trying Sheets API with move: $e');

        // Fallback: Create with Sheets API then move
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

        // Move to folder
        try {
          await driveApi.files.update(
            drive.File(),
            spreadsheetId,
            addParents: folderId,
            $fields: 'id,parents',
          );
          debugPrint('✅ [EDUCATOR-INIT] Moved spreadsheet to folder');
        } catch (moveError) {
          debugPrint('⚠️ [EDUCATOR-INIT] Could not move to folder: $moveError');
        }

        // Add headers
        await _addHeaders(sheetsApi, spreadsheetId);

        return spreadsheetId;
      }
      
    } catch (e) {
      debugPrint('❌ [EDUCATOR-INIT] Error creating spreadsheet: $e');
      return null;
    }
  }
  
  /// Set up spreadsheet structure for Drive API created sheets
  Future<void> _setupSpreadsheetStructure(sheets.SheetsApi sheetsApi, String spreadsheetId) async {
    try {
      debugPrint('📋 [EDUCATOR-INIT] Setting up spreadsheet structure...');

      // Get current spreadsheet to check structure
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);

      // Check if we need to rename the first sheet
      if (spreadsheet.sheets != null && spreadsheet.sheets!.isNotEmpty) {
        final firstSheet = spreadsheet.sheets!.first;
        final sheetId = firstSheet.properties?.sheetId;

        if (sheetId != null) {
          // Update the first sheet with Hebrew properties
          final updateRequest = sheets.BatchUpdateSpreadsheetRequest(
            requests: [
              sheets.Request(
                updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
                  properties: sheets.SheetProperties(
                    sheetId: sheetId,
                    title: 'נתוני תלמידים',
                    rightToLeft: true,
                    gridProperties: sheets.GridProperties(
                      frozenRowCount: 1,
                      columnCount: 12,
                    ),
                  ),
                  fields: 'title,rightToLeft,gridProperties.frozenRowCount,gridProperties.columnCount',
                ),
              ),
            ],
          );

          await sheetsApi.spreadsheets.batchUpdate(updateRequest, spreadsheetId);
          debugPrint('✅ [EDUCATOR-INIT] Updated sheet structure');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [EDUCATOR-INIT] Error setting up structure: $e');
      // Non-critical error, continue
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

      // Use RAW to avoid any automatic formatting
      await sheetsApi.spreadsheets.values.update(
        values,
        spreadsheetId,
        'נתוני תלמידים!A1:L1',
        valueInputOption: 'RAW',
      );

      // Format headers without bold
      await _formatHeaders(sheetsApi, spreadsheetId);

      debugPrint('✅ [EDUCATOR-INIT] Headers added and formatted');
      
    } catch (e) {
      debugPrint('⚠️ [EDUCATOR-INIT] Error adding headers: $e');
    }
  }

  /// Format headers without bold font
  Future<void> _formatHeaders(sheets.SheetsApi sheetsApi, String spreadsheetId) async {
    try {
      debugPrint('🎨 [EDUCATOR-INIT] Formatting headers without bold...');

      // Get the sheet ID
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      final sheetId = spreadsheet.sheets?.first.properties?.sheetId ?? 0;

      // Create formatting request - NO BOLD
      final requests = [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: sheetId,
              startRowIndex: 0,
              endRowIndex: 1,
              startColumnIndex: 0,
              endColumnIndex: 12,
            ),
            cell: sheets.CellData(
              userEnteredFormat: sheets.CellFormat(
                backgroundColor: sheets.Color(
                  red: 0.95,
                  green: 0.95,
                  blue: 0.95,
                ),
                textFormat: sheets.TextFormat(
                  bold: false,  // Explicitly set to NOT bold
                  fontSize: 11,
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

      await sheetsApi.spreadsheets.batchUpdate(
        batchUpdateRequest,
        spreadsheetId,
      );

      debugPrint('✅ [EDUCATOR-INIT] Headers formatted without bold');
    } catch (e) {
      debugPrint('⚠️ [EDUCATOR-INIT] Error formatting headers: $e');
      // Non-critical error, continue
    }
  }

  /// Share the spreadsheet with service account as editor
  Future<void> _shareWithServiceAccount(String spreadsheetId) async {
    try {
      print('🔗🔗🔗 [EDUCATOR-INIT] === SHARING WITH SERVICE ACCOUNT ===');
      print('🔗 Service account email: $serviceAccountEmail');
      print('🔗 Spreadsheet ID: $spreadsheetId');
      
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        print('❌ No authenticated client for sharing');
        return;
      }
      
      final driveApi = drive.DriveApi(client);
      
      // First, let's check current permissions
      print('🔗 Checking current permissions...');
      try {
        final currentPerms = await driveApi.permissions.list(spreadsheetId);
        print('📋 Current permissions on spreadsheet:');
        if (currentPerms.permissions != null) {
          for (final perm in currentPerms.permissions!) {
            print('   - ${perm.emailAddress}: ${perm.role} (${perm.type})');
          }
        }
      } catch (e) {
        print('⚠️ Could not list current permissions: $e');
      }
      
      // Create permission for service account
      final permission = drive.Permission(
        type: 'user',
        role: 'writer', // Editor access
        emailAddress: serviceAccountEmail,
      );
      
      print('🔗 Creating new permission:');
      print('   Type: user');
      print('   Role: writer (editor)');
      print('   Email: $serviceAccountEmail');
      
      await driveApi.permissions.create(
        permission,
        spreadsheetId,
        sendNotificationEmail: false, // Don't send email to service account
      );
      
      print('✅✅✅ Successfully shared with service account!');
      
      // Verify the permission was added
      try {
        final updatedPerms = await driveApi.permissions.list(spreadsheetId);
        print('📋 Updated permissions:');
        if (updatedPerms.permissions != null) {
          for (final perm in updatedPerms.permissions!) {
            print('   - ${perm.emailAddress}: ${perm.role} ${perm.emailAddress == serviceAccountEmail ? "✅" : ""}');
          }
        }
      } catch (e) {
        print('⚠️ Could not verify permissions: $e');
      }
      
      print('🔗 === SHARING COMPLETE ===\n');
      
    } catch (e) {
      print('❌❌❌ Error sharing with service account');
      print('   Error: $e');
      print('   Error type: ${e.runtimeType}');
      
      if (e.toString().contains('403')) {
        print('🔒 Permission denied - OAuth scope issue');
        print('   May need https://www.googleapis.com/auth/drive scope');
      }
      
      print('⚠️ Spreadsheet created but not shared');
      print('   Educator must manually share with: $serviceAccountEmail');
      print('🔗 === SHARING FAILED ===\n');
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
import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';
import 'google_sheets_service.dart';
import 'service_account_sheets_service.dart';
import '../data/models/student_record.dart';
import '../core/educator_mappings.dart';
import '../config/app_config.dart';

/// Service for handling multi-destination spreadsheet saves
/// Manages dual saving to both teacher and educator spreadsheets
class MultiDestinationSheetsService extends ChangeNotifier {
  final GoogleAuthService _authService;
  final GoogleSheetsService _sheetsService;
  final ServiceAccountSheetsService _serviceAccountService = ServiceAccountSheetsService();
  
  // Cache educator spreadsheet IDs to avoid repeated searches
  final Map<String, String> _educatorSpreadsheetIds = {};
  
  MultiDestinationSheetsService(this._authService, this._sheetsService);
  
  /// Initialize the service (including service account if enabled)
  Future<void> initialize() async {
    // Initialize service account if enabled
    if (AppConfig.useServiceAccount && !AppConfig.emergencyDisable) {
      await _initializeServiceAccount();
    }
  }
  
  Future<void> _initializeServiceAccount() async {
    debugPrint('🔐 [MULTI-SAVE] Initializing service account...');
    print('🔐 [MULTI-SAVE] Initializing service account...'); // Also use print for visibility
    final success = await _serviceAccountService.initialize();
    if (success) {
      debugPrint('✅ [MULTI-SAVE] Service account initialized successfully');
      print('✅ [MULTI-SAVE] Service account initialized successfully');
    } else {
      debugPrint('❌ [MULTI-SAVE] Service account initialization failed');
      print('❌ [MULTI-SAVE] Service account initialization failed');
      print('Error: ${_serviceAccountService.error}');
    }
  }
  
  /// Save record to multiple destinations (teacher + educator)
  Future<bool> saveToMultipleDestinations(StudentRecord record) async {
    try {
      debugPrint('🎯 [MULTI-SAVE] Starting multi-destination save');
      debugPrint('📋 [MULTI-SAVE] Record: ${record.studentName} from class ${record.classNumber}');
      
      // Step 1: Always save to the primary teacher's spreadsheet FIRST
      debugPrint('💾 [MULTI-SAVE] Step 1: Saving to teacher\'s primary spreadsheet...');
      final primarySaved = await _sheetsService.saveRecord(record);
      
      if (!primarySaved) {
        debugPrint('❌ [MULTI-SAVE] Failed to save to primary teacher spreadsheet');
        return false;
      }
      
      debugPrint('✅ [MULTI-SAVE] Successfully saved to teacher\'s spreadsheet');
      
      // Step 2: Check if this class has an associated educator
      debugPrint('🔍 [MULTI-SAVE] Looking for educator for class name: "${record.className}"');
      debugPrint('📋 [MULTI-SAVE] Available educator mappings: ${EducatorMappings.getMappings()}');
      
      final educatorEmail = EducatorMappings.getEducatorEmail(record.className);
      
      if (educatorEmail == null) {
        debugPrint('ℹ️ [MULTI-SAVE] No educator mapped for class name: "${record.className}"');
        debugPrint('✅ [MULTI-SAVE] Completed: Saved to teacher spreadsheet only (no educator)');
        return true; // Success - saved to teacher's sheet
      }
      
      debugPrint('👨‍🏫 [MULTI-SAVE] Found educator for class ${record.classNumber}: $educatorEmail');
      
      // Step 3: Check if we're already the educator (avoid duplicate saves)
      final currentUserEmail = _authService.currentUser?.email;
      if (currentUserEmail == educatorEmail) {
        debugPrint('ℹ️ [MULTI-SAVE] Current user IS the educator - no duplicate save needed');
        debugPrint('✅ [MULTI-SAVE] Completed: Single save (teacher is educator)');
        return true;
      }
      
      // Step 4: Save to educator's spreadsheet
      debugPrint('💾 [MULTI-SAVE] Step 2: Saving to educator\'s spreadsheet...');
      final educatorSaved = await _saveToEducatorSpreadsheet(record, educatorEmail);
      
      if (!educatorSaved) {
        debugPrint('⚠️ [MULTI-SAVE] Failed to save to educator spreadsheet');
        debugPrint('✅ [MULTI-SAVE] Completed: Saved to teacher only (educator save failed)');
        return true; // Still return true as primary save succeeded
      }
      
      debugPrint('✅ [MULTI-SAVE] Successfully saved to educator\'s spreadsheet');
      debugPrint('🎉 [MULTI-SAVE] Completed: Saved to BOTH teacher and educator spreadsheets');
      return true;
      
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error in multi-destination save: $e');
      return false;
    }
  }
  
  /// Save record to educator's spreadsheet
  Future<bool> _saveToEducatorSpreadsheet(StudentRecord record, String educatorEmail) async {
    try {
      print('🔄🔄🔄 [MULTI-SAVE] === EDUCATOR SAVE STARTING ===');
      print('🔄 Educator email: $educatorEmail');
      print('🔄 Service account initialized: ${_serviceAccountService.isInitialized}');
      
      // Find or create educator's spreadsheet
      print('🔄 Finding educator spreadsheet...');
      final spreadsheetId = await _findOrCreateEducatorSpreadsheet(educatorEmail);
      
      if (spreadsheetId == null) {
        print('❌ Could not find educator spreadsheet');
        print('   Educator must sign in first to create their BPApp');
        return false;
      }
      
      print('✅ Found educator spreadsheet: $spreadsheetId');
      print('📝 Attempting to save record...');
      
      // Save the record to the educator's spreadsheet
      final success = await _saveToSpreadsheet(record, spreadsheetId, educatorEmail);
      
      if (success) {
        print('✅✅✅ Record saved to educator spreadsheet!');
      } else {
        print('❌❌❌ Failed to save to educator spreadsheet');
      }
      
      print('🔄 === EDUCATOR SAVE COMPLETE ===\n');
      return success;
      
    } catch (e) {
      print('❌❌❌ Error in educator save');
      print('   Error: $e');
      return false;
    }
  }
  
  /// Find educator's existing BPApp (educators must create their own)
  Future<String?> _findOrCreateEducatorSpreadsheet(String educatorEmail) async {
    try {
      // With the new approach, we only FIND educator spreadsheets, not create them
      // Educators must sign in and create their own spreadsheet first
      
      if (_serviceAccountService.isInitialized && AppConfig.useServiceAccount) {
        debugPrint('🔐 [MULTI-SAVE] Using SERVICE ACCOUNT to find educator spreadsheet');
        
        // Try to find existing spreadsheet that educator created and shared
        final existingId = await _serviceAccountService.findEducatorSpreadsheet(educatorEmail);
        if (existingId != null) {
          debugPrint('✅ [MULTI-SAVE] Found educator spreadsheet (educator-owned): $existingId');
          _educatorSpreadsheetIds[educatorEmail] = existingId;
          return existingId;
        }
        
        // If not found, educator needs to sign in and initialize
        debugPrint('⚠️ [MULTI-SAVE] Educator spreadsheet not found');
        debugPrint('ℹ️ [MULTI-SAVE] Educator must sign in to the app to initialize their BPApp');
        return null;
      }
      
      // Fallback to OAuth
      debugPrint('🔑 [MULTI-SAVE] Using OAUTH to find/create educator spreadsheet');
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('❌ [MULTI-SAVE] No authenticated client');
        return null;
      }
      
      final driveApi = drive.DriveApi(client);
      
      // CRITICAL: Search for educator-owned BPApp files FIRST
      // This prevents creating duplicates
      debugPrint('🔍 [MULTI-SAVE] Searching for educator\'s existing BPApp in their My Drive...');
      
      // Search for BPApp files owned by the educator
      final query = "name = 'BPApp' and "
                   "mimeType='application/vnd.google-apps.spreadsheet' and "
                   "trashed=false and "
                   "'$educatorEmail' in owners";
      
      debugPrint('🔍 [MULTI-SAVE] Search query: $query');
      debugPrint('🔍 [MULTI-SAVE] Executing search for educator-owned BPApp files...');
      
      final response = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name,owners,capabilities,parents,shared,createdTime)',
      );
      
      debugPrint('🔍 [MULTI-SAVE] Search results: ${response.files?.length ?? 0} files found');
      
      // Log all found files for debugging
      if (response.files != null && response.files!.isNotEmpty) {
        for (int i = 0; i < response.files!.length; i++) {
          final file = response.files![i];
          debugPrint('📋 [MULTI-SAVE] File $i details:');
          debugPrint('   - Name: ${file.name}');
          debugPrint('   - ID: ${file.id}');
          debugPrint('   - Created: ${file.createdTime}');
          debugPrint('   - Shared: ${file.shared}');
          debugPrint('   - Owners: ${file.owners?.map((o) => o.emailAddress).toList()}');
          debugPrint('   - Parents: ${file.parents}');
          debugPrint('   - Can Edit: ${file.capabilities?.canEdit}');
        }
      }
      
      if (response.files != null && response.files!.isNotEmpty) {
        // Found educator's existing BPApp!
        final file = response.files!.first;
        final spreadsheetId = file.id!;
        
        debugPrint('✅ [MULTI-SAVE] Using existing educator BPApp: $spreadsheetId');
        
        // Check if we have edit permission
        final canEdit = file.capabilities?.canEdit ?? false;
        
        if (!canEdit) {
          debugPrint('⚠️ [MULTI-SAVE] Found educator\'s BPApp but no edit permission');
          debugPrint('📧 [MULTI-SAVE] Requesting educator to share their BPApp with service account');
          
          // Try to request access
          await _requestAccessToSpreadsheet(driveApi, spreadsheetId, educatorEmail);
          
          // Check permission again after request
          final updatedFile = await driveApi.files.get(
            spreadsheetId,
            $fields: 'capabilities',
          );
          
          final updatedCanEdit = (updatedFile as drive.File).capabilities?.canEdit ?? false;
          
          if (!updatedCanEdit) {
            debugPrint('❌ [MULTI-SAVE] Still no edit permission after request');
            return null;
          }
        }
        
        debugPrint('✅✅✅ [MULTI-SAVE] FOUND EDUCATOR\'S EXISTING BPAPP IN THEIR MY DRIVE!');
        debugPrint('✅ [MULTI-SAVE] Spreadsheet ID: $spreadsheetId');
        debugPrint('✅ [MULTI-SAVE] Will add entries to this existing spreadsheet');
        
        // Cache the spreadsheet ID
        _educatorSpreadsheetIds[educatorEmail] = spreadsheetId;
        
        return spreadsheetId;
      }
      
      // No existing BPApp found - educator needs to sign in first
      debugPrint('⚠️ [MULTI-SAVE] No existing BPApp found for educator: $educatorEmail');
      debugPrint('ℹ️ [MULTI-SAVE] Educator must sign in to the app to create their BPApp');
      debugPrint('ℹ️ [MULTI-SAVE] The BPApp will be automatically created and shared with service account');
      debugPrint('ℹ️ [MULTI-SAVE] After educator signs in once, teacher entries will be saved to their BPApp');
      
      // Do NOT create spreadsheet - educator must do it themselves
      return null;
      
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error finding/creating educator spreadsheet: $e');
      return null;
    }
  }
  
  /// Request access to a spreadsheet
  Future<void> _requestAccessToSpreadsheet(drive.DriveApi driveApi, String spreadsheetId, String educatorEmail) async {
    try {
      debugPrint('📧 [MULTI-SAVE] Requesting access to educator\'s spreadsheet...');
      
      // Create a permission request
      final permission = drive.Permission(
        type: 'user',
        role: 'writer',
        emailAddress: _authService.currentUser?.email,
      );
      
      await driveApi.permissions.create(
        permission,
        spreadsheetId,
        sendNotificationEmail: true,
        emailMessage: 'The BPApp system needs access to your BPApp spreadsheet to add student entries from other teachers.',
      );
      
      debugPrint('✅ [MULTI-SAVE] Access request sent to educator');
      
    } catch (e) {
      debugPrint('⚠️ [MULTI-SAVE] Could not request access: $e');
    }
  }
  
  /// Create a new BPApp spreadsheet and place it in educator's My Drive
  Future<String?> _createEducatorSpreadsheet(String educatorEmail) async {
    // IMPORTANT: Educators now create their own spreadsheets through educator_self_init_service
    // This method should not create spreadsheets anymore
    debugPrint('ℹ️ [MULTI-SAVE] Educator spreadsheet creation disabled');
    debugPrint('ℹ️ [MULTI-SAVE] Educators must create their own BPApp when they sign in');
    debugPrint('ℹ️ [MULTI-SAVE] The spreadsheet will be auto-shared with service account');
    return null;
    
    // OLD CODE DISABLED - Keeping for reference
    /*
    try {
      // Use service account if available and enabled, otherwise fall back to OAuth
      if (_serviceAccountService.isInitialized && AppConfig.useServiceAccount) {
        debugPrint('🔐 [MULTI-SAVE] Using SERVICE ACCOUNT for educator spreadsheet creation');
        return await _serviceAccountService.createEducatorSpreadsheet(educatorEmail);
      }
      
      // Fallback to OAuth if service account not available
      debugPrint('🔑 [MULTI-SAVE] Using OAUTH for educator spreadsheet creation (service account not available)');
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('❌ [MULTI-SAVE] No authenticated client for spreadsheet creation');
        return null;
      }

      final sheetsApi = sheets.SheetsApi(client);
      final driveApi = drive.DriveApi(client);

      debugPrint('🆕 [MULTI-SAVE] Creating new BPApp spreadsheet for educator: $educatorEmail');

      // Create the spreadsheet with proper Hebrew RTL setup
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
                columnCount: GoogleSheetsService.hebrewHeaders.length,
              ),
            ),
          ),
        ],
      );

      final response = await sheetsApi.spreadsheets.create(spreadsheet);
      final spreadsheetId = response.spreadsheetId!;
      
      debugPrint('✅ [MULTI-SAVE] Created spreadsheet with ID: $spreadsheetId');

      // Add Hebrew headers
      await _addEducatorHeaders(sheetsApi, spreadsheetId);
      
      // CRITICAL: Make the educator the owner so it appears in their My Drive
      await _makeEducatorOwner(driveApi, spreadsheetId, educatorEmail);
      
      debugPrint('✅ [MULTI-SAVE] Successfully set up educator\'s BPApp in their My Drive');
      
      return spreadsheetId;

    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error creating educator spreadsheet: $e');
      return null;
    }
  }
  
  /// Make educator the owner of the spreadsheet so it appears in their My Drive
  Future<void> _makeEducatorOwner(drive.DriveApi driveApi, String spreadsheetId, String educatorEmail) async {
    try {
      debugPrint('👑 [MULTI-SAVE] === OWNERSHIP TRANSFER ATTEMPT ===');
      debugPrint('👑 [MULTI-SAVE] Target spreadsheet ID: $spreadsheetId');
      debugPrint('👑 [MULTI-SAVE] Target educator email: $educatorEmail');
      debugPrint('👑 [MULTI-SAVE] Creating ownership permission...');
      
      // First, let's check current permissions
      try {
        final currentPermissions = await driveApi.permissions.list(spreadsheetId);
        debugPrint('🔐 [MULTI-SAVE] Current permissions:');
        if (currentPermissions.permissions != null) {
          for (int i = 0; i < currentPermissions.permissions!.length; i++) {
            final perm = currentPermissions.permissions![i];
            debugPrint('   Permission $i: ${perm.type}/${perm.role} - ${perm.emailAddress} (${perm.id})');
          }
        }
      } catch (permError) {
        debugPrint('⚠️ [MULTI-SAVE] Could not read current permissions: $permError');
      }
      
      // STEP 1: Transfer ownership to educator (moves file to their My Drive)
      final ownerPermission = drive.Permission(
        type: 'user',
        role: 'owner',
        emailAddress: educatorEmail,
      );
      
      // CRITICAL: First ensure admin@bpappedu.com retains editor access
      debugPrint('👑 [MULTI-SAVE] Step 1: Ensuring admin retains editor access...');
      try {
        final adminPermission = drive.Permission(
          type: 'user',
          role: 'writer',
          emailAddress: 'admin@bpappedu.com', // Service account's impersonated user
        );
        
        await driveApi.permissions.create(
          adminPermission,
          spreadsheetId,
          sendNotificationEmail: false,
        );
        debugPrint('✅ [MULTI-SAVE] Admin editor access ensured');
      } catch (e) {
        debugPrint('⚠️ [MULTI-SAVE] Could not ensure admin access: $e');
      }
      
      // Now safe to transfer ownership
      debugPrint('👑 [MULTI-SAVE] Step 2: Transferring ownership to educator...');
      debugPrint('👑 [MULTI-SAVE] Permission: type=${ownerPermission.type}, role=${ownerPermission.role}, email=${ownerPermission.emailAddress}');
      debugPrint('👑 [MULTI-SAVE] transferOwnership=true, sendNotificationEmail=true');
      
      final permissionResult = await driveApi.permissions.create(
        ownerPermission,
        spreadsheetId,
        transferOwnership: true,
        sendNotificationEmail: true,
        emailMessage: 'גיליון BPApp נוצר עבורך וזמין ב"הכונן שלי". הוא יופיע בתיקיית "הכונן שלי" שלך.',
      );
      
      debugPrint('✅✅✅ [MULTI-SAVE] PERMISSIONS.CREATE COMPLETED!');
      debugPrint('✅✅✅ [MULTI-SAVE] Result permission ID: ${permissionResult.id}');
      debugPrint('✅✅✅ [MULTI-SAVE] Result role: ${permissionResult.role}');
      
      // Verify the transfer worked by checking file info again
      try {
        debugPrint('🔍 [MULTI-SAVE] Verifying ownership transfer by reading file info...');
        final fileInfo = await driveApi.files.get(
          spreadsheetId, 
          $fields: 'id,name,owners,shared,parents'
        ) as drive.File;
        debugPrint('📋 [MULTI-SAVE] POST-TRANSFER file info:');
        debugPrint('   - Shared: ${fileInfo.shared}');
        debugPrint('   - Owners: ${fileInfo.owners?.map((o) => o.emailAddress).toList()}');
        debugPrint('   - Parents: ${fileInfo.parents}');
        
        if (fileInfo.owners?.any((o) => o.emailAddress == educatorEmail) == true) {
          debugPrint('✅✅✅ [MULTI-SAVE] VERIFICATION: Educator is now listed as owner!');
        } else {
          debugPrint('❌❌❌ [MULTI-SAVE] VERIFICATION FAILED: Educator not found in owners list!');
        }
      } catch (verifyError) {
        debugPrint('⚠️ [MULTI-SAVE] Could not verify ownership transfer: $verifyError');
      }
      debugPrint('📁 [MULTI-SAVE] Educator can find BPApp in their "My Drive" folder');
      
      // STEP 2: Ensure current user/service maintains writer access
      try {
        final currentUserEmail = _authService.currentUser?.email;
        if (currentUserEmail != null && currentUserEmail != educatorEmail) {
          final writerPermission = drive.Permission(
            type: 'user',
            role: 'writer',
            emailAddress: currentUserEmail,
          );
          
          await driveApi.permissions.create(
            writerPermission,
            spreadsheetId,
            sendNotificationEmail: false,
          );
          
          debugPrint('✅ [MULTI-SAVE] Current user retained writer access to educator\'s BPApp');
        }
      } catch (accessError) {
        debugPrint('⚠️ [MULTI-SAVE] Could not retain current user access: $accessError');
        debugPrint('ℹ️ [MULTI-SAVE] This is OK - educator still has full control');
      }
      
    } catch (e) {
      debugPrint('❌❌❌ [MULTI-SAVE] === OWNERSHIP TRANSFER FAILED ===');
      debugPrint('❌❌❌ [MULTI-SAVE] Error type: ${e.runtimeType}');
      debugPrint('❌❌❌ [MULTI-SAVE] Error message: $e');
      debugPrint('❌❌❌ [MULTI-SAVE] Full error: ${e.toString()}');
      
      if (e.toString().contains('403')) {
        debugPrint('🔒 [MULTI-SAVE] ERROR ANALYSIS: 403 Forbidden - Service account lacks permission');
        debugPrint('🔒 [MULTI-SAVE] This means service account cannot transfer file ownership');
        debugPrint('🔒 [MULTI-SAVE] Possible causes:');
        debugPrint('🔒 [MULTI-SAVE]   1. Service account needs domain-wide delegation');
        debugPrint('🔒 [MULTI-SAVE]   2. Service account lacks Drive API ownership permissions');
        debugPrint('🔒 [MULTI-SAVE]   3. Target user domain restrictions');
      }
      
      if (e.toString().contains('400')) {
        debugPrint('⚠️ [MULTI-SAVE] ERROR ANALYSIS: 400 Bad Request - Invalid API usage');
        debugPrint('⚠️ [MULTI-SAVE] This means API call structure is incorrect');
      }
      
      debugPrint('⚠️ [MULTI-SAVE] FALLBACK: Will share as editor (file goes to Shared with me)');
      
      // Fallback: Share as writer if ownership transfer fails
      try {
        final writerPermission = drive.Permission(
          type: 'user',
          role: 'writer',
          emailAddress: educatorEmail,
        );
        
        await driveApi.permissions.create(
          writerPermission,
          spreadsheetId,
          sendNotificationEmail: true,
          emailMessage: 'גיליון BPApp שותף איתך. הוא יופיע ב"שותף איתי".',
        );
        
        debugPrint('📁 [MULTI-SAVE] FALLBACK: Shared as writer (Shared with me)');
        debugPrint('⚠️ [MULTI-SAVE] Educator will find BPApp in "Shared with me" instead of "My Drive"');
        
      } catch (shareError) {
        debugPrint('❌ [MULTI-SAVE] CRITICAL: Could not share OR transfer ownership: $shareError');
      }
    }
    */
  }

  /// Add Hebrew headers to educator's spreadsheet
  Future<void> _addEducatorHeaders(sheets.SheetsApi sheetsApi, String spreadsheetId) async {
    try {
      debugPrint('📝 [MULTI-SAVE] Adding Hebrew headers to educator spreadsheet');
      
      final values = sheets.ValueRange(
        range: 'נתוני תלמידים!A1:K1',
        majorDimension: 'ROWS',
        values: [GoogleSheetsService.hebrewHeaders],
      );

      await sheetsApi.spreadsheets.values.update(
        values,
        spreadsheetId,
        'נתוני תלמידים!A1:K1',
        valueInputOption: 'USER_ENTERED',
      );
      
      debugPrint('✅ [MULTI-SAVE] Headers added successfully');
    } catch (e) {
      debugPrint('⚠️ [MULTI-SAVE] Error adding headers: $e');
    }
  }
  
  /// Save record to a specific spreadsheet
  Future<bool> _saveToSpreadsheet(StudentRecord record, String spreadsheetId, String educatorEmail) async {
    try {
      // Use service account if available for educator spreadsheets
      if (_serviceAccountService.isInitialized && AppConfig.useServiceAccount) {
        debugPrint('🔐 [MULTI-SAVE] Using SERVICE ACCOUNT to save to educator spreadsheet');
        debugPrint('🔐 [MULTI-SAVE] Spreadsheet ID: $spreadsheetId');
        debugPrint('🔐 [MULTI-SAVE] Educator Email: $educatorEmail');
        
        // Use the new method that takes spreadsheet ID directly
        return await _serviceAccountService.saveRecordToSpreadsheetById(
          record,
          spreadsheetId,
          educatorEmail,
        );
      }
      
      // Fallback to OAuth
      debugPrint('🔑 [MULTI-SAVE] Using OAUTH to save to educator spreadsheet');
      final client = await _authService.getAuthenticatedClient();
      if (client == null) return false;
      
      final sheetsApi = sheets.SheetsApi(client);
      
      // Check for existing record (4-field matching)
      final existingRowNumber = await _findExistingRow(sheetsApi, spreadsheetId, record);
      
      if (existingRowNumber != null) {
        // Update existing record
        debugPrint('📝 [MULTI-SAVE] Updating existing record at row $existingRowNumber');
        return await _updateRow(sheetsApi, spreadsheetId, record, existingRowNumber);
      } else {
        // Add new record with intelligent sorting
        debugPrint('➕ [MULTI-SAVE] Adding new record to educator sheet');
        return await _appendWithSorting(sheetsApi, spreadsheetId, record);
      }
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error saving to spreadsheet: $e');
      return false;
    }
  }

  /// Find existing row using 4-field matching
  Future<int?> _findExistingRow(sheets.SheetsApi sheetsApi, String spreadsheetId, StudentRecord record) async {
    try {
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        'נתוני תלמידים!A2:D',
      );
      
      if (response.values == null) return null;
      
      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        if (row.length >= 4 &&
            row[0] == record.date &&
            row[1] == record.classNumber &&
            row[2] == record.studentName &&
            row[3].toString() == record.classNumber.toString()) {
          return i + 2; // +2 because we start from row 2
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error finding existing row: $e');
      return null;
    }
  }
  
  /// Update existing row
  Future<bool> _updateRow(sheets.SheetsApi sheetsApi, String spreadsheetId, StudentRecord record, int rowNumber) async {
    try {
      final values = sheets.ValueRange(
        range: 'נתוני תלמידים!A$rowNumber:K$rowNumber',
        majorDimension: 'ROWS',
        values: [record.toSheetRow()],
      );

      await sheetsApi.spreadsheets.values.update(
        values,
        spreadsheetId,
        'נתוני תלמידים!A$rowNumber:K$rowNumber',
        valueInputOption: 'USER_ENTERED',
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error updating row: $e');
      return false;
    }
  }
  
  /// Append record with intelligent sorting
  Future<bool> _appendWithSorting(sheets.SheetsApi sheetsApi, String spreadsheetId, StudentRecord record) async {
    try {
      // For now, just append to the end
      // TODO: Implement intelligent date-based sorting
      
      final values = sheets.ValueRange(
        range: 'נתוני תלמידים!A:K',
        majorDimension: 'ROWS',
        values: [record.toSheetRow()],
      );

      await sheetsApi.spreadsheets.values.append(
        values,
        spreadsheetId,
        'נתוני תלמידים!A:K',
        valueInputOption: 'USER_ENTERED',
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error appending record: $e');
      return false;
    }
  }
  
  /// Parse date string to DateTime
  DateTime? _parseDate(String dateStr) {
    try {
      // Expected format: DD/MM/YYYY
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }
}
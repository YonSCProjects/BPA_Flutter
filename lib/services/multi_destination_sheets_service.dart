import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';
import 'google_sheets_service.dart';
import '../data/models/student_record.dart';
import '../core/educator_mappings.dart';

/// Service for handling multi-destination spreadsheet saves
/// Manages dual saving to both teacher and educator spreadsheets
class MultiDestinationSheetsService extends ChangeNotifier {
  final GoogleAuthService _authService;
  final GoogleSheetsService _sheetsService;
  
  // Cache educator spreadsheet IDs to avoid repeated searches
  final Map<String, String> _educatorSpreadsheetIds = {};
  
  MultiDestinationSheetsService(this._authService, this._sheetsService);
  
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
      final educatorEmail = EducatorMappings.getEducatorEmail(record.className);
      
      if (educatorEmail == null) {
        debugPrint('ℹ️ [MULTI-SAVE] No educator mapped for class: ${record.classNumber}');
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
      debugPrint('🔄 [MULTI-SAVE] Initiating educator spreadsheet save');
      
      // Find or create educator's spreadsheet
      final spreadsheetId = await _findOrCreateEducatorSpreadsheet(educatorEmail);
      
      if (spreadsheetId == null) {
        debugPrint('❌ [MULTI-SAVE] Could not find or create educator spreadsheet');
        return false;
      }
      
      debugPrint('📝 [MULTI-SAVE] Saving record to educator spreadsheet: $spreadsheetId');
      
      // Save the record to the educator's spreadsheet
      final success = await _saveToSpreadsheet(record, spreadsheetId, educatorEmail);
      
      if (success) {
        debugPrint('✅ [MULTI-SAVE] Record saved to educator spreadsheet');
      } else {
        debugPrint('❌ [MULTI-SAVE] Failed to save to educator spreadsheet');
      }
      
      return success;
      
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error in educator save: $e');
      return false;
    }
  }
  
  /// Find educator's existing BPApp or create new one in their My Drive
  Future<String?> _findOrCreateEducatorSpreadsheet(String educatorEmail) async {
    try {
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
      
      final response = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name,owners,capabilities)',
      );
      
      debugPrint('🔍 [MULTI-SAVE] Search results: ${response.files?.length ?? 0} files found');
      
      if (response.files != null && response.files!.isNotEmpty) {
        // Found educator's existing BPApp!
        final file = response.files!.first;
        final spreadsheetId = file.id!;
        
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
      
      // No existing BPApp found - create new one
      debugPrint('🆕 [MULTI-SAVE] No existing BPApp found for educator');
      debugPrint('🆕 [MULTI-SAVE] Creating new BPApp in educator\'s My Drive...');
      
      final newSpreadsheetId = await _createEducatorSpreadsheet(educatorEmail);
      
      if (newSpreadsheetId != null) {
        _educatorSpreadsheetIds[educatorEmail] = newSpreadsheetId;
        debugPrint('✅ [MULTI-SAVE] Created new BPApp for educator: $newSpreadsheetId');
        return newSpreadsheetId;
      } else {
        debugPrint('❌ [MULTI-SAVE] Failed to create new BPApp for educator');
        return null;
      }
      
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
    try {
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
      debugPrint('👑 [MULTI-SAVE] Transferring ownership to educator for My Drive placement...');
      
      // STEP 1: Transfer ownership to educator (moves file to their My Drive)
      final ownerPermission = drive.Permission(
        type: 'user',
        role: 'owner',
        emailAddress: educatorEmail,
      );
      
      await driveApi.permissions.create(
        ownerPermission,
        spreadsheetId,
        transferOwnership: true,
        sendNotificationEmail: true,
        emailMessage: 'גיליון BPApp נוצר עבורך וזמין ב"הכונן שלי". הוא יופיע בתיקיית "הכונן שלי" שלך.',
      );
      
      debugPrint('✅✅✅ [MULTI-SAVE] OWNERSHIP TRANSFERRED - FILE NOW IN EDUCATOR\'S MY DRIVE!');
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
      debugPrint('❌ [MULTI-SAVE] ERROR: Ownership transfer failed: $e');
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
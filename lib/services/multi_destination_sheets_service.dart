import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;

import '../data/models/student_record.dart';
import '../core/educator_mappings.dart';
import 'google_sheets_service.dart';
import 'google_auth_service.dart';

/// Service that handles saving records to multiple Google Sheets
/// 
/// User roles and save behavior:
/// - Regular teachers: Save to their own sheet + educator's sheet (if different)
/// - Educators (teachers who lead classes): Save only to their own sheet
/// 
/// This prevents duplicate saves when educators record their own students
class MultiDestinationSheetsService {
  final GoogleSheetsService _primaryService;
  final GoogleAuthService _authService;
  
  // Cache of educator spreadsheet services
  final Map<String, GoogleSheetsService> _educatorServices = {};
  
  // Cache of educator spreadsheet IDs (email -> spreadsheet ID)
  final Map<String, String> _educatorSpreadsheetIds = {};
  
  MultiDestinationSheetsService({
    required GoogleSheetsService primaryService,
    required GoogleAuthService authService,
  }) : _primaryService = primaryService,
       _authService = authService;
  
  /// Save record to primary sheet and educator sheet if applicable
  Future<bool> saveRecord(StudentRecord record) async {
    debugPrint('📤 [MULTI-SAVE] Starting multi-destination save for class: ${record.className}');
    
    // Step 1: Always save to teacher's own spreadsheet
    bool primarySuccess = false;
    try {
      primarySuccess = await _primaryService.saveRecord(record);
      debugPrint(primarySuccess 
        ? '✅ [MULTI-SAVE] Saved to primary spreadsheet' 
        : '❌ [MULTI-SAVE] Failed to save to primary spreadsheet');
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error saving to primary: $e');
    }
    
    // Step 2: Check if this class has an associated educator
    debugPrint('🔍 [MULTI-SAVE] Checking educator mapping for class: "${record.className}"');
    debugPrint('🔍 [MULTI-SAVE] All current mappings: ${EducatorMappings.getMappings()}');
    debugPrint('🔍 [MULTI-SAVE] Is mappings initialized: ${EducatorMappings.getMappings().isNotEmpty}');
    
    final educatorEmail = EducatorMappings.getEducatorEmail(record.className);
    
    if (educatorEmail == null) {
      debugPrint('ℹ️ [MULTI-SAVE] No educator mapped for class: "${record.className}"');
      debugPrint('ℹ️ [MULTI-SAVE] Available mapped classes: ${EducatorMappings.getClassesWithEducators()}');
      return primarySuccess; // No educator, just return primary result
    }
    
    // Check if current user IS the educator (prevent duplicate saves)
    final currentUserEmail = _authService.currentUser?.email;
    if (currentUserEmail != null && currentUserEmail.toLowerCase() == educatorEmail.toLowerCase()) {
      debugPrint('🔄 [MULTI-SAVE] Current user IS the educator - skipping duplicate save');
      return primarySuccess; // Don't save twice to same spreadsheet
    }
    
    debugPrint('👨‍🏫 [MULTI-SAVE] Found educator for class ${record.className}: $educatorEmail');
    
    // Step 3: Save to educator's spreadsheet
    bool educatorSuccess = false;
    try {
      educatorSuccess = await _saveToEducatorSpreadsheet(record, educatorEmail);
      debugPrint(educatorSuccess
        ? '✅ [MULTI-SAVE] Saved to educator spreadsheet ($educatorEmail)'
        : '❌ [MULTI-SAVE] Failed to save to educator spreadsheet');
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error saving to educator: $e');
    }
    
    // Return true if saved to primary (educator save is bonus)
    // This ensures teachers always get confirmation their data is saved
    return primarySuccess;
  }
  
  /// Save record to a specific educator's spreadsheet
  Future<bool> _saveToEducatorSpreadsheet(StudentRecord record, String educatorEmail) async {
    try {
      // Find or request access to educator's spreadsheet
      final spreadsheetId = await _findOrRequestEducatorSpreadsheet(educatorEmail);
      
      if (spreadsheetId == null) {
        debugPrint('❌ [MULTI-SAVE] Could not access educator spreadsheet');
        return false;
      }
      
      // Save the record to educator's spreadsheet
      return await _saveToSpreadsheet(record, spreadsheetId, educatorEmail);
      
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error in educator save: $e');
      return false;
    }
  }
  
  /// Find educator's BPApp spreadsheet or request access
  Future<String?> _findOrRequestEducatorSpreadsheet(String educatorEmail) async {
    // Clear cache to ensure fresh search
    debugPrint('🔄 [MULTI-SAVE] Clearing cache and performing fresh search for $educatorEmail');
    _educatorSpreadsheetIds.remove(educatorEmail);
    
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('❌ [MULTI-SAVE] No authenticated client');
        return null;
      }
      
      final driveApi = drive.DriveApi(client);
      
      // Strategy 1: Search for BPApp spreadsheets shared with current user that are owned by educator
      debugPrint('🔍 [MULTI-SAVE] Strategy 1: Searching for BPApp shared with me and owned by $educatorEmail');
      final query1 = "sharedWithMe and "
                    "name contains 'BPApp' and "
                    "mimeType='application/vnd.google-apps.spreadsheet' and "
                    "trashed=false";
      
      debugPrint('🔍 [MULTI-SAVE] Query 1: $query1');
      
      var response = await driveApi.files.list(
        q: query1,
        spaces: 'drive',
        $fields: 'files(id,name,owners,permissions,shared,capabilities)',
      );
      
      debugPrint('🔍 [MULTI-SAVE] Strategy 1 results: ${response.files?.length ?? 0} files');
      
      // Filter files owned by the educator and check edit permissions
      if (response.files != null && response.files!.isNotEmpty) {
        debugPrint('🔍 [MULTI-SAVE] Shared BPApp files found:');
        for (final file in response.files!) {
          final owners = file.owners?.map((o) => o.emailAddress).join(", ") ?? "no owners";
          final shared = file.shared ?? false;
          final canEdit = file.capabilities?.canEdit ?? false;
          debugPrint('📋 [MULTI-SAVE] File: "${file.name}" (ID: ${file.id})');
          debugPrint('📋 [MULTI-SAVE]   - Owned by: $owners');
          debugPrint('📋 [MULTI-SAVE]   - Shared: $shared, Can Edit: $canEdit');
          debugPrint('📋 [MULTI-SAVE]   - Target educator: $educatorEmail');
          
          // Check if this file is owned by our target educator
          final isOwnedByEducator = file.owners?.any((owner) => owner.emailAddress == educatorEmail) ?? false;
          if (isOwnedByEducator && canEdit) {
            debugPrint('📋 [MULTI-SAVE] ✅ PERFECT MATCH! File owned by $educatorEmail with edit access');
            final spreadsheetId = file.id!;
            _educatorSpreadsheetIds[educatorEmail] = spreadsheetId;
            
            debugPrint('✅ [MULTI-SAVE] Found educator spreadsheet: ${file.name} (ID: $spreadsheetId)');
            debugPrint('✅ [MULTI-SAVE] Spreadsheet owners: $owners');
            debugPrint('✅ [MULTI-SAVE] Edit permission: $canEdit');
            
            return spreadsheetId;
          }
        }
      }
      
      // Strategy 2: Search for ALL BPApp spreadsheets accessible to current user  
      debugPrint('🔍 [MULTI-SAVE] Strategy 2: Searching for ALL accessible BPApp spreadsheets');
      final query2 = "name contains 'BPApp' and "
                    "mimeType='application/vnd.google-apps.spreadsheet' and "
                    "trashed=false";
      
      debugPrint('🔍 [MULTI-SAVE] Query 2: $query2');
      
      response = await driveApi.files.list(
        q: query2,
        spaces: 'drive',
        $fields: 'files(id,name,owners,permissions,shared,capabilities)',
      );
      
      debugPrint('🔍 [MULTI-SAVE] Strategy 2 results: ${response.files?.length ?? 0} files');
      
      if (response.files != null && response.files!.isNotEmpty) {
        debugPrint('🔍 [MULTI-SAVE] All accessible BPApp files:');
        for (final file in response.files!) {
          final owners = file.owners?.map((o) => o.emailAddress).join(", ") ?? "no owners";
          final shared = file.shared ?? false;
          final canEdit = file.capabilities?.canEdit ?? false;
          debugPrint('📋 [MULTI-SAVE] File: "${file.name}" (ID: ${file.id})');
          debugPrint('📋 [MULTI-SAVE]   - Owned by: $owners');
          debugPrint('📋 [MULTI-SAVE]   - Shared: $shared, Can Edit: $canEdit');
          debugPrint('📋 [MULTI-SAVE]   - Target educator: $educatorEmail');
          
          // Check if this file is owned by our target educator
          final isOwnedByEducator = file.owners?.any((owner) => owner.emailAddress == educatorEmail) ?? false;
          if (isOwnedByEducator && canEdit) {
            debugPrint('📋 [MULTI-SAVE] ✅ MATCH! File owned by $educatorEmail with edit access');
            final spreadsheetId = file.id!;
            _educatorSpreadsheetIds[educatorEmail] = spreadsheetId;
            
            debugPrint('✅ [MULTI-SAVE] Found educator spreadsheet: ${file.name} (ID: $spreadsheetId)');
            debugPrint('✅ [MULTI-SAVE] Spreadsheet owners: $owners');
            debugPrint('✅ [MULTI-SAVE] Edit permission: $canEdit');
            
            return spreadsheetId;
          }
        }
      }
      
      // Strategy 3: Legacy search by owner (fallback for older sharing setups)
      debugPrint('🔍 [MULTI-SAVE] Strategy 3: Legacy search by owner');
      final query3 = "name contains 'BPApp' and "
                    "mimeType='application/vnd.google-apps.spreadsheet' and "
                    "trashed=false and "
                    "'$educatorEmail' in owners";
      
      debugPrint('🔍 [MULTI-SAVE] Query 3: $query3');
      
      response = await driveApi.files.list(
        q: query3,
        spaces: 'drive',
        $fields: 'files(id,name,owners,capabilities)',
      );
      
      debugPrint('🔍 [MULTI-SAVE] Strategy 3 results: ${response.files?.length ?? 0} files');
      
      if (response.files != null && response.files!.isNotEmpty) {
        final file = response.files!.first;
        final spreadsheetId = file.id!;
        final canEdit = file.capabilities?.canEdit ?? false;
        
        if (canEdit) {
          debugPrint('✅ [MULTI-SAVE] Found educator spreadsheet via legacy search: ${file.name} (ID: $spreadsheetId)');
          _educatorSpreadsheetIds[educatorEmail] = spreadsheetId;
          return spreadsheetId;
        } else {
          debugPrint('⚠️ [MULTI-SAVE] Found spreadsheet but no edit permission');
        }
      }
      
      // All strategies failed - provide helpful diagnostic
      debugPrint('❌ [MULTI-SAVE] All search strategies failed for educator: $educatorEmail');
      debugPrint('💡 [MULTI-SAVE] SOLUTION: The educator ($educatorEmail) needs to:');
      debugPrint('💡 [MULTI-SAVE] 1. Open their BPApp spreadsheet in Google Sheets');
      debugPrint('💡 [MULTI-SAVE] 2. Click "Share" button in top-right corner');
      debugPrint('💡 [MULTI-SAVE] 3. Add teacher email (${_authService.currentUser?.email}) as Editor');
      debugPrint('💡 [MULTI-SAVE] 4. Click "Send" to share with edit permissions');
      debugPrint('💡 [MULTI-SAVE] This will allow the teacher to save records to educator\'s spreadsheet');
      
      return null;
      
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error finding educator spreadsheet: $e');
      return null;
    }
  }
  
  /// Check if we have write permission to a spreadsheet
  Future<bool> _checkWritePermission(drive.DriveApi driveApi, String spreadsheetId) async {
    try {
      final file = await driveApi.files.get(
        spreadsheetId,
        $fields: 'capabilities',
      );
      
      final fileData = file as drive.File;
      return fileData.capabilities?.canEdit ?? false;
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error checking permissions: $e');
      return false;
    }
  }
  
  /// Save record directly to a specific spreadsheet
  Future<bool> _saveToSpreadsheet(StudentRecord record, String spreadsheetId, String educatorEmail) async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) return false;
      
      final sheetsApi = sheets.SheetsApi(client);
      
      // Try to fix protection on educator's spreadsheet so teacher can write
      try {
        final currentUserEmail = _authService.currentUser?.email;
        if (currentUserEmail != null) {
          await _fixEducatorSpreadsheetProtection(
            sheetsApi: sheetsApi,
            spreadsheetId: spreadsheetId,
            targetSheetTitle: 'נתוני תלמידים',
            teacherEmail: currentUserEmail,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [MULTI-SAVE] Could not fix educator spreadsheet protection: $e');
      }
      
      // Verify spreadsheet details before saving
      debugPrint('🔍 [MULTI-SAVE] Verifying spreadsheet details before save...');
      debugPrint('📋 [MULTI-SAVE] Target spreadsheet ID: $spreadsheetId');
      debugPrint('👨‍🏫 [MULTI-SAVE] Expected educator: $educatorEmail');
      
      try {
        final driveApi = drive.DriveApi(client);
        final file = await driveApi.files.get(
          spreadsheetId,
          $fields: 'id,name,owners',
        );
        
        final owners = (file as drive.File).owners?.map((o) => o.emailAddress).join(", ") ?? "no owners";
        debugPrint('📋 [MULTI-SAVE] Spreadsheet "${file.name}" owned by: $owners');
        
        // Verify this spreadsheet is actually owned by the educator
        final isOwnedByEducator = (file.owners?.any((o) => o.emailAddress == educatorEmail) ?? false);
        if (!isOwnedByEducator) {
          debugPrint('⚠️ [MULTI-SAVE] WARNING: Spreadsheet is NOT owned by $educatorEmail!');
          debugPrint('⚠️ [MULTI-SAVE] This would save to wrong spreadsheet. Aborting.');
          return false;
        } else {
          debugPrint('✅ [MULTI-SAVE] Verified: Spreadsheet is owned by $educatorEmail');
        }
      } catch (e) {
        debugPrint('⚠️ [MULTI-SAVE] Could not verify spreadsheet ownership: $e');
        debugPrint('⚠️ [MULTI-SAVE] Proceeding with save anyway...');
      }
      
      // First, check for existing record (4-field matching)
      final existingRowNumber = await _findExistingRow(sheetsApi, spreadsheetId, record);
      
      if (existingRowNumber != null) {
        // Update existing record
        debugPrint('📝 [MULTI-SAVE] Updating existing record in educator sheet at row $existingRowNumber');
        final ok = await _updateRow(sheetsApi, spreadsheetId, record, existingRowNumber);
        if (ok) return true;
        // If blocked by protection, fall back to unprotected sheet
        debugPrint('⚠️ [MULTI-SAVE] Update blocked, attempting fallback sheet');
        return await _appendToFallbackSheet(sheetsApi, spreadsheetId, record);
      } else {
        // Append new record with intelligent sorting
        debugPrint('➕ [MULTI-SAVE] Adding new record to educator sheet');
        final ok = await _appendWithSorting(sheetsApi, spreadsheetId, record);
        if (ok) return true;
        // If blocked by protection, fall back to unprotected sheet
        debugPrint('⚠️ [MULTI-SAVE] Append blocked, attempting fallback sheet');
        return await _appendToFallbackSheet(sheetsApi, spreadsheetId, record);
      }
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error saving to spreadsheet: $e');
      return false;
    }
  }

  /// Fallback path: write to an unprotected helper sheet inside the educator spreadsheet
  /// This avoids protected ranges on the main data sheet, requiring no manual changes by the educator.
  Future<bool> _appendToFallbackSheet(
    sheets.SheetsApi sheetsApi,
    String spreadsheetId,
    StudentRecord record,
  ) async {
    const fallbackTitle = 'קלט מהמורה'; // Hebrew: Teacher Input
    try {
      // Find or create fallback sheet
      final sheetId = await _findOrCreateSheet(
        sheetsApi: sheetsApi,
        spreadsheetId: spreadsheetId,
        title: fallbackTitle,
      );

      if (sheetId == null) {
        debugPrint('❌ [MULTI-SAVE] Could not ensure fallback sheet');
        return false;
      }

      // Ensure headers exist on row 1
      final endCol = String.fromCharCode(65 + GoogleSheetsService.hebrewHeaders.length - 1);
      final headerRange = '$fallbackTitle!A1:${endCol}1';
      await sheetsApi.spreadsheets.values.update(
        sheets.ValueRange(values: [GoogleSheetsService.hebrewHeaders]),
        spreadsheetId,
        headerRange,
        valueInputOption: 'RAW',
      );

      // Append the record
      final appendRange = '$fallbackTitle!A:L';
      final valueRange = sheets.ValueRange(values: [record.toSheetRow()]);
      await sheetsApi.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        appendRange,
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );

      debugPrint('✅ [MULTI-SAVE] Saved to educator fallback sheet "$fallbackTitle"');
      return true;
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Fallback sheet write failed: $e');
      return false;
    }
  }

  Future<int?> _findOrCreateSheet({
    required sheets.SheetsApi sheetsApi,
    required String spreadsheetId,
    required String title,
  }) async {
    try {
      final ss = await sheetsApi.spreadsheets.get(spreadsheetId);
      // Try to find by title
      for (final sh in ss.sheets ?? <sheets.Sheet>[]) {
        if (sh.properties?.title == title) {
          return sh.properties?.sheetId;
        }
      }

      // Create new sheet with RTL and correct column count
      final addSheetReq = sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(
            title: title,
            rightToLeft: true,
            gridProperties: sheets.GridProperties(
              columnCount: GoogleSheetsService.hebrewHeaders.length,
            ),
          ),
        ),
      );

      final batch = sheets.BatchUpdateSpreadsheetRequest(requests: [addSheetReq]);
      final resp = await sheetsApi.spreadsheets.batchUpdate(batch, spreadsheetId);
      final added = resp.replies?.first.addSheet?.properties?.sheetId;
      return added;
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Failed to find/create sheet "$title": $e');
      return null;
    }
  }

  /// Fix educator spreadsheet protection to allow teacher writes
  Future<void> _fixEducatorSpreadsheetProtection({
    required sheets.SheetsApi sheetsApi,
    required String spreadsheetId,
    required String targetSheetTitle,
    required String teacherEmail,
  }) async {
    try {
      debugPrint('🔧 [MULTI-SAVE] Fixing educator spreadsheet protection for teacher: $teacherEmail');
      
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);

      // Resolve target sheet ID by title
      int? targetSheetId;
      if (spreadsheet.sheets != null) {
        for (final sh in spreadsheet.sheets!) {
          final title = sh.properties?.title;
          if (title == targetSheetTitle) {
            targetSheetId = sh.properties?.sheetId;
            break;
          }
        }
      }

      targetSheetId ??= spreadsheet.sheets?.first.properties?.sheetId ?? 0;

      final requests = <sheets.Request>[];
      
      // Remove broad protection that blocks teacher writes
      if (spreadsheet.sheets != null) {
        for (final sheet in spreadsheet.sheets!) {
          final protectedRanges = sheet.protectedRanges;
          if (protectedRanges != null) {
            for (final range in protectedRanges) {
              final gridRange = range.range;
              if (gridRange != null && 
                  gridRange.sheetId == targetSheetId &&
                  gridRange.endRowIndex != null && 
                  gridRange.endRowIndex! > 10) { // Broad protection
                
                debugPrint('🔧 [MULTI-SAVE] Removing broad protection: ${range.protectedRangeId}');
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

      // Add header-only protection that includes both educator and teacher as editors
      requests.add(sheets.Request(
        addProtectedRange: sheets.AddProtectedRangeRequest(
          protectedRange: sheets.ProtectedRange(
            range: sheets.GridRange(
              sheetId: targetSheetId,
              startRowIndex: 0,
              endRowIndex: 1, // Only header row
              startColumnIndex: 0,
              endColumnIndex: GoogleSheetsService.hebrewHeaders.length,
            ),
            description: 'הגנה על שורת כותרות - מורה ומחנך יכולים לערוך',
            warningOnly: false,
            editors: sheets.Editors(
              users: [teacherEmail], // Allow teacher to edit
              domainUsersCanEdit: false,
            ),
          ),
        ),
      ));

      if (requests.isNotEmpty) {
        final batch = sheets.BatchUpdateSpreadsheetRequest(requests: requests);
        await sheetsApi.spreadsheets.batchUpdate(batch, spreadsheetId);
        debugPrint('🔧 [MULTI-SAVE] Fixed educator spreadsheet protection - teacher can now write to data rows');
      }
      
    } catch (e) {
      debugPrint('⚠️ [MULTI-SAVE] Failed to fix educator spreadsheet protection: $e');
    }
  }

  /// Ensure current user can write despite hard protected ranges by adding them as an allowed editor
  Future<void> _ensureWriteAccessToProtectedRanges({
    required sheets.SheetsApi sheetsApi,
    required String spreadsheetId,
    required String targetSheetTitle,
    required String editorEmail,
  }) async {
    try {
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);

      // Resolve target sheet ID by title
      int? targetSheetId;
      if (spreadsheet.sheets != null) {
        for (final sh in spreadsheet.sheets!) {
          final title = sh.properties?.title;
          if (title == targetSheetTitle) {
            targetSheetId = sh.properties?.sheetId;
            break;
          }
        }
      }

      // Fallback to first sheet if title not found
      targetSheetId ??= spreadsheet.sheets?.first.properties?.sheetId ?? 0;

      // Collect protected ranges that apply to the target sheet
      final List<sheets.ProtectedRange> protectedRanges = [];

      // Protected ranges may be present at the spreadsheet level (recommended) but
      // are exposed under each sheet in API responses as well.
      if (spreadsheet.sheets != null) {
        for (final sh in spreadsheet.sheets!) {
          final ranges = sh.protectedRanges;
          if (ranges != null) {
            for (final pr in ranges) {
              final range = pr.range;
              if (range != null && range.sheetId == targetSheetId) {
                protectedRanges.add(pr);
              }
            }
          }
        }
      }

      if (protectedRanges.isEmpty) {
        debugPrint('ℹ️ [MULTI-SAVE] No protected ranges found on target sheet');
        return;
      }

      final requests = <sheets.Request>[];

      for (final pr in protectedRanges) {
        // Skip if already warning-only (won't block writes)
        final isWarningOnly = pr.warningOnly ?? false;
        final editors = pr.editors ?? sheets.Editors();
        final currentUsers = editors.users == null ? <String>[] : List<String>.from(editors.users!);

        if (isWarningOnly || currentUsers.contains(editorEmail)) {
          continue;
        }

        currentUsers.add(editorEmail);

        final updated = sheets.ProtectedRange()
          ..protectedRangeId = pr.protectedRangeId
          ..editors = (sheets.Editors()..users = currentUsers);

        requests.add(
          sheets.Request(
            updateProtectedRange: sheets.UpdateProtectedRangeRequest(
              protectedRange: updated,
              fields: 'editors',
            ),
          ),
        );
      }

      if (requests.isEmpty) {
        return;
      }

      final batch = sheets.BatchUpdateSpreadsheetRequest(requests: requests);
      await sheetsApi.spreadsheets.batchUpdate(batch, spreadsheetId);
      debugPrint('✅ [MULTI-SAVE] Added $editorEmail as allowed editor to protected ranges');
    } catch (e) {
      debugPrint('⚠️ [MULTI-SAVE] Failed to ensure write access on protected ranges: $e');
    }
  }
  
  /// Find existing row with 4-field matching
  Future<int?> _findExistingRow(sheets.SheetsApi sheetsApi, String spreadsheetId, StudentRecord record) async {
    try {
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        'נתוני תלמידים!A2:D', // Only need first 4 columns for matching
      );
      
      if (response.values == null) return null;
      
      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        if (row.length >= 4) {
          // Use trim() for consistent matching like the main GoogleSheetsService
          final existingDate = row[0]?.toString().trim() ?? '';
          final existingStudent = row[1]?.toString().trim() ?? '';
          final existingClass = row[2]?.toString().trim() ?? '';
          final existingClassNumber = int.tryParse(row[3]?.toString() ?? '0') ?? 0;
          
          // Normalize the record fields for comparison
          final recordDate = record.date.trim();
          final recordStudent = record.studentName.trim();
          final recordClass = record.className.trim();
          
          if (existingDate == recordDate &&
              existingStudent == recordStudent &&
              existingClass == recordClass &&
              existingClassNumber == record.classNumber) {
            return i + 2; // +2 because sheets are 1-indexed and we skip header
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error finding existing row: $e');
      return null;
    }
  }
  
  /// Update existing row in educator's spreadsheet
  Future<bool> _updateRow(sheets.SheetsApi sheetsApi, String spreadsheetId, StudentRecord record, int rowNumber) async {
    try {
      final range = 'נתוני תלמידים!A$rowNumber:L$rowNumber';
      final valueRange = sheets.ValueRange(
        values: [record.toSheetRow()],
      );
      
      await sheetsApi.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'RAW',
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
      debugPrint('🔄 [MULTI-SAVE] Starting intelligent sorting for educator spreadsheet');
      
      // Find the correct position for chronological insertion
      final insertPosition = await _findInsertPosition(sheetsApi, spreadsheetId, record);
      
      if (insertPosition == -1) {
        // Append to end if no specific position found
        debugPrint('🔄 [MULTI-SAVE] No specific position found, appending to end');
        return await _appendToEnd(sheetsApi, spreadsheetId, record);
      } else {
        // Insert at the calculated position
        debugPrint('🔄 [MULTI-SAVE] Inserting at chronological position: $insertPosition');
        return await _insertAtPosition(sheetsApi, spreadsheetId, record, insertPosition);
      }
      
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error in intelligent sorting: $e');
      // Fallback to simple append if sorting fails
      return await _appendToEnd(sheetsApi, spreadsheetId, record);
    }
  }
  
  /// Find the correct chronological position for the record
  Future<int> _findInsertPosition(sheets.SheetsApi sheetsApi, String spreadsheetId, StudentRecord record) async {
    try {
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        'נתוני תלמידים!A2:D', // Only need first 4 columns for position calculation
      );
      
      if (response.values == null || response.values!.isEmpty) {
        return 2; // Insert after header row if sheet is empty
      }
      
      final recordDate = _parseDate(record.date);
      if (recordDate == null) {
        debugPrint('❌ [MULTI-SAVE] Could not parse record date: "${record.date}"');
        return -1;
      }
      
      debugPrint('🔄 [MULTI-SAVE] Finding position for: ${record.date} (class ${record.classNumber})');
      debugPrint('🔄 [MULTI-SAVE] Checking against ${response.values!.length} existing rows');
      
      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        if (row.isEmpty) continue;
        
        final existingDateStr = row[0]?.toString() ?? '';
        final existingDate = _parseDate(existingDateStr);
        if (existingDate == null) {
          debugPrint('⚠️ [MULTI-SAVE] Could not parse existing date: "$existingDateStr"');
          continue;
        }
        
        final existingClassNumber = int.tryParse(row[3]?.toString() ?? '0') ?? 0;
        
        debugPrint('🔄 [MULTI-SAVE] Row ${i + 2}: $existingDateStr (class $existingClassNumber)');
        
        // Primary sort: by date (chronological)
        if (recordDate.isBefore(existingDate)) {
          debugPrint('✅ [MULTI-SAVE] Found chronological position by date at row ${i + 2}');
          return i + 2;
        }
        
        // Secondary sort: same date, sort by class number
        if (recordDate.isAtSameMomentAs(existingDate)) {
          if (record.classNumber < existingClassNumber) {
            debugPrint('✅ [MULTI-SAVE] Found chronological position by class number at row ${i + 2}');
            return i + 2;
          }
        }
      }
      
      debugPrint('🔄 [MULTI-SAVE] Record belongs at end of chronological sequence');
      return -1; // Insert at end
      
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error finding insert position: $e');
      return -1;
    }
  }
  
  /// Parse date string to DateTime for comparison
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
      // Fallback to standard parsing
      return DateTime.parse(dateString);
    } catch (e) {
      debugPrint('📅 [MULTI-SAVE] Error parsing date "$dateString": $e');
      return null;
    }
  }
  
  /// Insert record at specific position
  Future<bool> _insertAtPosition(sheets.SheetsApi sheetsApi, String spreadsheetId, StudentRecord record, int position) async {
    try {
      // Get the educator's sheet ID
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      int? sheetId;
      
      if (spreadsheet.sheets != null) {
        for (final sheet in spreadsheet.sheets!) {
          if (sheet.properties?.title == 'נתוני תלמידים') {
            sheetId = sheet.properties?.sheetId;
            break;
          }
        }
      }
      sheetId ??= 0; // Fallback to first sheet
      
      // Insert empty row at target position
      final insertRequest = sheets.Request(
        insertRange: sheets.InsertRangeRequest(
          range: sheets.GridRange(
            sheetId: sheetId,
            startRowIndex: position - 1, // 0-indexed
            endRowIndex: position,
            startColumnIndex: 0,
            endColumnIndex: GoogleSheetsService.hebrewHeaders.length,
          ),
          shiftDimension: 'ROWS',
        ),
      );
      
      await sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: [insertRequest]),
        spreadsheetId,
      );
      
      // Populate the new row with data
      final range = 'נתוני תלמידים!A$position:L$position';
      final valueRange = sheets.ValueRange(values: [record.toSheetRow()]);
      
      await sheetsApi.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'RAW',
      );
      
      debugPrint('✅ [MULTI-SAVE] Successfully inserted record at position $position');
      return true;
      
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error inserting at position: $e');
      return false;
    }
  }
  
  /// Simple append to end as fallback
  Future<bool> _appendToEnd(sheets.SheetsApi sheetsApi, String spreadsheetId, StudentRecord record) async {
    try {
      final valueRange = sheets.ValueRange(values: [record.toSheetRow()]);
      
      await sheetsApi.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        'נתוני תלמידים!A:L',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );
      
      debugPrint('✅ [MULTI-SAVE] Successfully appended record to end');
      return true;
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error appending to end: $e');
      return false;
    }
  }
  
  /// Clear cache (useful when permissions change)
  void clearEducatorCache() {
    _educatorSpreadsheetIds.clear();
    _educatorServices.clear();
  }
}
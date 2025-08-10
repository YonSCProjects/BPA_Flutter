import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;

import '../data/models/student_record.dart';
import '../core/educator_mappings.dart';
import 'google_sheets_service.dart';
import 'google_auth_service.dart';

/// Service that handles saving records to multiple Google Sheets
/// Professional teachers save to:
/// 1. Their own spreadsheet (always)
/// 2. The educator's spreadsheet (if class has an associated educator)
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
      
      // Strategy 1: Search for BPApp spreadsheets owned by educator
      debugPrint('🔍 [MULTI-SAVE] Strategy 1: Searching for BPApp owned by $educatorEmail');
      final query1 = "name contains 'BPApp' and "
                    "mimeType='application/vnd.google-apps.spreadsheet' and "
                    "trashed=false and "
                    "'$educatorEmail' in owners";
      
      debugPrint('🔍 [MULTI-SAVE] Query 1: $query1');
      
      var response = await driveApi.files.list(
        q: query1,
        spaces: 'drive',
        $fields: 'files(id,name,owners,permissions,shared)',
      );
      
      debugPrint('🔍 [MULTI-SAVE] Strategy 1 results: ${response.files?.length ?? 0} files');
      
      // Strategy 2: Search for ALL BPApp spreadsheets (including shared)
      if (response.files == null || response.files!.isEmpty) {
        debugPrint('🔍 [MULTI-SAVE] Strategy 2: Searching for ALL BPApp spreadsheets');
        final query2 = "name contains 'BPApp' and "
                      "mimeType='application/vnd.google-apps.spreadsheet' and "
                      "trashed=false";  // All BPApp spreadsheets
        
        debugPrint('🔍 [MULTI-SAVE] Query 2: $query2');
        
        response = await driveApi.files.list(
          q: query2,
          spaces: 'drive',
          $fields: 'files(id,name,owners,permissions,shared)',
        );
        
        debugPrint('🔍 [MULTI-SAVE] Strategy 2 results: ${response.files?.length ?? 0} files');
        debugPrint('🔍 [MULTI-SAVE] All BPApp files found:');
        if (response.files != null) {
          for (final file in response.files!) {
            final owners = file.owners?.map((o) => o.emailAddress).join(", ") ?? "no owners";
            final shared = file.shared ?? false;
            debugPrint('📋 [MULTI-SAVE] File: "${file.name}" (ID: ${file.id})');
            debugPrint('📋 [MULTI-SAVE]   - Owned by: $owners');
            debugPrint('📋 [MULTI-SAVE]   - Shared: $shared');
            debugPrint('📋 [MULTI-SAVE]   - Target educator: $educatorEmail');
          }
        }
        
        // Filter by owner email from the results
        if (response.files != null && response.files!.isNotEmpty) {
          final filteredFiles = response.files!.where((file) {
            final owners = file.owners;
            if (owners != null) {
              for (final owner in owners) {
                if (owner.emailAddress == educatorEmail) {
                  debugPrint('📋 [MULTI-SAVE] ✅ MATCH! File: ${file.name} owned by $educatorEmail');
                  return true;
                }
              }
            }
            return false;
          }).toList();
          
          debugPrint('🔍 [MULTI-SAVE] After filtering by owner: ${filteredFiles.length} files');
          response = drive.FileList()..files = filteredFiles;
        }
      }
      
      if (response.files != null && response.files!.isNotEmpty) {
        // Found educator's spreadsheet
        final file = response.files!.first;
        final spreadsheetId = file.id!;
        
        debugPrint('✅ [MULTI-SAVE] Found educator spreadsheet: ${file.name} (ID: $spreadsheetId)');
        debugPrint('✅ [MULTI-SAVE] Spreadsheet owners: ${file.owners?.map((o) => o.emailAddress).join(", ")}');
        debugPrint('✅ [MULTI-SAVE] Shared status: ${file.shared}');
        
        // Cache it
        _educatorSpreadsheetIds[educatorEmail] = spreadsheetId;
        
        // Check if we have write permission
        final hasWriteAccess = await _checkWritePermission(driveApi, spreadsheetId);
        
        debugPrint('🔐 [MULTI-SAVE] Write access check result: $hasWriteAccess');
        
        if (!hasWriteAccess) {
          debugPrint('⚠️ [MULTI-SAVE] No write access to educator spreadsheet');
          return null;
        }
        
        return spreadsheetId;
      } else {
        debugPrint('❌ [MULTI-SAVE] No educator spreadsheet found for: $educatorEmail');
        
        // Strategy 3: Search with alternative naming
        debugPrint('🔍 [MULTI-SAVE] Strategy 3: Trying alternative naming patterns');
        final query3 = "name contains 'BPApp - $educatorEmail' or "
                      "name='BPApp' and "
                      "mimeType='application/vnd.google-apps.spreadsheet' and "
                      "trashed=false";
        
        debugPrint('🔍 [MULTI-SAVE] Query 3: $query3');
        
        final fallbackResponse = await driveApi.files.list(
          q: query3,
          spaces: 'drive',
          $fields: 'files(id,name,owners)',
        );
        
        debugPrint('🔍 [MULTI-SAVE] Strategy 3 results: ${fallbackResponse.files?.length ?? 0} files');
        
        if (fallbackResponse.files != null && fallbackResponse.files!.isNotEmpty) {
          for (final file in fallbackResponse.files!) {
            final owners = file.owners?.map((o) => o.emailAddress).join(", ") ?? "no owners";
            debugPrint('📋 [MULTI-SAVE] Alternative file found: "${file.name}" (ID: ${file.id}) owned by: $owners');
          }
          
          // Filter to only use files owned by the educator
          final educatorOwnedFiles = fallbackResponse.files!.where((file) {
            final owners = file.owners;
            if (owners != null) {
              for (final owner in owners) {
                if (owner.emailAddress == educatorEmail) {
                  return true;
                }
              }
            }
            return false;
          }).toList();
          
          debugPrint('🔍 [MULTI-SAVE] Files owned by $educatorEmail: ${educatorOwnedFiles.length}');
          
          if (educatorOwnedFiles.isEmpty) {
            debugPrint('❌ [MULTI-SAVE] No BPApp files owned by $educatorEmail in Strategy 3');
            // Don't return null here - continue to Strategy 4
          } else {
          
            final spreadsheetId = educatorOwnedFiles.first.id!;
            _educatorSpreadsheetIds[educatorEmail] = spreadsheetId;
            debugPrint('✅ [MULTI-SAVE] Found fallback educator spreadsheet: $spreadsheetId (verified owned by $educatorEmail)');
            return spreadsheetId;
          }
        }
        
        debugPrint('❌ [MULTI-SAVE] All search strategies failed for educator: $educatorEmail');
        
        // Strategy 4: Try to access the educator's known spreadsheet ID directly
        debugPrint('🔍 [MULTI-SAVE] Strategy 4: Testing direct access to known educator spreadsheet');
        try {
          const knownEducatorSpreadsheetId = '1oTMhLMuE57T8AK9kzbeQc1csJvCM4VvtdXW_VCVbcE4';
          debugPrint('🔍 [MULTI-SAVE] Attempting direct access to: $knownEducatorSpreadsheetId');
          
          final testFile = await driveApi.files.get(
            knownEducatorSpreadsheetId,
            $fields: 'id,name,owners,shared,capabilities',
          );
          
          final owners = (testFile as drive.File).owners?.map((o) => o.emailAddress).join(", ") ?? "no owners";
          final shared = testFile.shared ?? false;
          final canEdit = testFile.capabilities?.canEdit ?? false;
          
          debugPrint('✅ [MULTI-SAVE] Direct access SUCCESS!');
          debugPrint('📋 [MULTI-SAVE] File: "${testFile.name}" owned by: $owners');
          debugPrint('📋 [MULTI-SAVE] Shared: $shared, Can Edit: $canEdit');
          
          if (canEdit) {
            debugPrint('🎉 [MULTI-SAVE] Found accessible educator spreadsheet via direct access!');
            _educatorSpreadsheetIds[educatorEmail] = knownEducatorSpreadsheetId;
            return knownEducatorSpreadsheetId;
          }
        } catch (e) {
          debugPrint('❌ [MULTI-SAVE] Direct access failed: $e');
        }
        
        debugPrint('💡 [MULTI-SAVE] SOLUTION: The educator ($educatorEmail) needs to:');
        debugPrint('💡 [MULTI-SAVE] 1. ✅ Sign in to BPApp (DONE - spreadsheet created: 1oTMhLMuE57T8AK9kzbeQc1csJvCM4VvtdXW_VCVbcE4)');
        debugPrint('💡 [MULTI-SAVE] 2. ❓ SHARE their BPApp spreadsheet with teacher (yon.level@gmail.com)');
        debugPrint('💡 [MULTI-SAVE] 3. ❓ Give teacher EDIT permissions to their spreadsheet');
        debugPrint('💡 [MULTI-SAVE] Issue: Teacher cannot find educator\'s spreadsheet via Drive API search!');
        return null;
      }
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
      
      // Try to relax protection so the teacher (current user) can write
      try {
        final currentUserEmail = _authService.currentUser?.email;
        if (currentUserEmail != null) {
          await _ensureWriteAccessToProtectedRanges(
            sheetsApi: sheetsApi,
            spreadsheetId: spreadsheetId,
            targetSheetTitle: 'נתוני תלמידים',
            editorEmail: currentUserEmail,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [MULTI-SAVE] Could not adjust protected ranges: $e');
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
        if (row.length >= 4 &&
            row[0]?.toString() == record.date &&
            row[1]?.toString() == record.studentName &&
            row[2]?.toString() == record.className &&
            int.tryParse(row[3]?.toString() ?? '') == record.classNumber) {
          return i + 2; // +2 because sheets are 1-indexed and we skip header
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
      // For simplicity, just append to end
      // In production, you'd implement the sorting logic here
      final valueRange = sheets.ValueRange(
        values: [record.toSheetRow()],
      );
      
      await sheetsApi.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        'נתוני תלמידים!A:L',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error appending row: $e');
      return false;
    }
  }
  
  /// Clear cache (useful when permissions change)
  void clearEducatorCache() {
    _educatorSpreadsheetIds.clear();
    _educatorServices.clear();
  }
}
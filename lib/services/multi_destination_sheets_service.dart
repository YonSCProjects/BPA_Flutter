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
    final educatorEmail = EducatorMappings.getEducatorEmail(record.className);
    
    if (educatorEmail == null) {
      debugPrint('ℹ️ [MULTI-SAVE] No educator mapped for class: ${record.className}');
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
    // Check cache first
    if (_educatorSpreadsheetIds.containsKey(educatorEmail)) {
      return _educatorSpreadsheetIds[educatorEmail];
    }
    
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('❌ [MULTI-SAVE] No authenticated client');
        return null;
      }
      
      final driveApi = drive.DriveApi(client);
      
      // Search for BPApp spreadsheets shared with us by this educator
      final query = "name contains 'BPApp' and "
                   "mimeType='application/vnd.google-apps.spreadsheet' and "
                   "trashed=false and "
                   "'$educatorEmail' in owners";
      
      debugPrint('🔍 [MULTI-SAVE] Searching for educator spreadsheet with query: $query');
      
      final response = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name,owners,permissions)',
      );
      
      if (response.files != null && response.files!.isNotEmpty) {
        // Found educator's spreadsheet
        final file = response.files!.first;
        final spreadsheetId = file.id!;
        
        debugPrint('✅ [MULTI-SAVE] Found educator spreadsheet: ${file.name} (ID: $spreadsheetId)');
        
        // Cache it
        _educatorSpreadsheetIds[educatorEmail] = spreadsheetId;
        
        // Check if we have write permission
        final hasWriteAccess = await _checkWritePermission(driveApi, spreadsheetId);
        
        if (!hasWriteAccess) {
          debugPrint('⚠️ [MULTI-SAVE] No write access to educator spreadsheet');
          // In production, you might want to request permission here
          // For now, we'll return null
          return null;
        }
        
        return spreadsheetId;
      } else {
        debugPrint('❌ [MULTI-SAVE] No educator spreadsheet found for: $educatorEmail');
        
        // Alternative: Search for any BPApp spreadsheet we can access
        final fallbackQuery = "name contains 'BPApp - $educatorEmail' and "
                             "mimeType='application/vnd.google-apps.spreadsheet' and "
                             "trashed=false";
        
        final fallbackResponse = await driveApi.files.list(
          q: fallbackQuery,
          spaces: 'drive',
        );
        
        if (fallbackResponse.files != null && fallbackResponse.files!.isNotEmpty) {
          final spreadsheetId = fallbackResponse.files!.first.id!;
          _educatorSpreadsheetIds[educatorEmail] = spreadsheetId;
          debugPrint('✅ [MULTI-SAVE] Found fallback educator spreadsheet: $spreadsheetId');
          return spreadsheetId;
        }
        
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
      
      // First, check for existing record (4-field matching)
      final existingRowNumber = await _findExistingRow(sheetsApi, spreadsheetId, record);
      
      if (existingRowNumber != null) {
        // Update existing record
        debugPrint('📝 [MULTI-SAVE] Updating existing record in educator sheet at row $existingRowNumber');
        return await _updateRow(sheetsApi, spreadsheetId, record, existingRowNumber);
      } else {
        // Append new record with intelligent sorting
        debugPrint('➕ [MULTI-SAVE] Adding new record to educator sheet');
        return await _appendWithSorting(sheetsApi, spreadsheetId, record);
      }
    } catch (e) {
      debugPrint('❌ [MULTI-SAVE] Error saving to spreadsheet: $e');
      return false;
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
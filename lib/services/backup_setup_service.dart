import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';
import 'apps_script_backup_code.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to set up automatic backups for new users
class BackupSetupService extends ChangeNotifier {
  final GoogleAuthService _authService;
  sheets.SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi;
  
  static const String _backupSetupKey = 'backup_setup_offered';
  static const String _backupEnabledKey = 'backup_enabled';
  
  BackupSetupService(this._authService);
  
  /// Check if we should offer backup setup to the user
  Future<bool> shouldOfferBackupSetup() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we've already offered
    final offered = prefs.getBool(_backupSetupKey) ?? false;
    if (offered) return false;
    
    // Check if user is authenticated
    if (!_authService.isAuthenticated) return false;
    
    return true;
  }
  
  /// Mark that we've offered backup setup
  Future<void> markBackupSetupOffered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupSetupKey, true);
  }
  
  /// Mark that backup is enabled
  Future<void> markBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupEnabledKey, enabled);
  }
  
  /// Set up automatic backups by adding instructions to the spreadsheet
  Future<bool> setupAutomaticBackups(String spreadsheetId) async {
    try {
      debugPrint('🔧 [BACKUP_SETUP] Starting automatic backup setup...');
      
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('❌ [BACKUP_SETUP] No authenticated client');
        return false;
      }
      
      _sheetsApi = sheets.SheetsApi(client);
      _driveApi = drive.DriveApi(client);
      
      // Step 1: Create backup instructions sheet
      await _createBackupInstructionsSheet(spreadsheetId);
      
      // Step 2: Create backup folder
      await _createBackupFolder();
      
      // Step 3: Add backup menu (through sheet formulas)
      await _addBackupFormulas(spreadsheetId);
      
      // Mark as enabled
      await markBackupEnabled(true);
      
      debugPrint('✅ [BACKUP_SETUP] Backup setup completed successfully');
      return true;
      
    } catch (e) {
      debugPrint('❌ [BACKUP_SETUP] Error setting up backups: $e');
      return false;
    }
  }
  
  /// Create a sheet with backup instructions and script
  Future<void> _createBackupInstructionsSheet(String spreadsheetId) async {
    if (_sheetsApi == null) return;
    
    try {
      // Add new sheet for backup setup
      final addSheetRequest = sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(
            title: 'הגדרת גיבויים',
            index: 1,
            rightToLeft: true,
          ),
        ),
      );
      
      await _sheetsApi!.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: [addSheetRequest]),
        spreadsheetId,
      );
      
      // Add instructions and script to the sheet
      final instructions = [
        ['🔒 הגדרת גיבויים אוטומטיים ל-BPApp'],
        [''],
        ['מערכת הגיבויים תיצור 7 גיבויים ביום בשעות קבועות'],
        ['הגיבויים יישמרו בתיקייה BPApp_Backups ב-Google Drive שלך'],
        [''],
        ['📋 הוראות הגדרה:'],
        ['1. לחץ על הרחבות (Extensions) → Apps Script'],
        ['2. מחק את הקוד הקיים'],
        ['3. העתק את הקוד מהתא הבא והדבק בעורך'],
        ['4. לחץ על שמור (Ctrl+S)'],
        ['5. לחץ על Run ליד installBackupSystem'],
        ['6. אשר את ההרשאות'],
        [''],
        ['✂️ === העתק מכאן === ✂️'],
        [''],
        [AppsScriptBackupCode.getBackupScript()],
        [''],
        ['✂️ === עד כאן === ✂️'],
        [''],
        ['✅ לאחר ההתקנה:'],
        ['• יופיע תפריט "BPApp גיבויים" בגיליון'],
        ['• גיבויים אוטומטיים יתבצעו 7 פעמים ביום'],
        ['• ניתן לבצע גיבוי ידני בכל עת מהתפריט'],
        [''],
        ['❓ תמיכה: yon.level@gmail.com'],
      ];
      
      final valueRange = sheets.ValueRange(
        values: instructions,
      );
      
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        'הגדרת גיבויים!A1',
        valueInputOption: 'USER_ENTERED',
      );
      
      // Format the sheet
      await _formatInstructionsSheet(spreadsheetId);
      
    } catch (e) {
      debugPrint('⚠️ [BACKUP_SETUP] Error creating instructions sheet: $e');
    }
  }
  
  /// Format the instructions sheet for better readability
  Future<void> _formatInstructionsSheet(String spreadsheetId) async {
    if (_sheetsApi == null) return;
    
    try {
      // Get sheet ID
      final spreadsheet = await _sheetsApi!.spreadsheets.get(spreadsheetId);
      final backupSheet = spreadsheet.sheets?.firstWhere(
        (sheet) => sheet.properties?.title == 'הגדרת גיבויים',
      );
      
      if (backupSheet == null) return;
      final sheetId = backupSheet.properties?.sheetId;
      
      final requests = [
        // Format title
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: sheetId,
              startRowIndex: 0,
              endRowIndex: 1,
              startColumnIndex: 0,
              endColumnIndex: 1,
            ),
            cell: sheets.CellData(
              userEnteredFormat: sheets.CellFormat(
                backgroundColor: sheets.Color(red: 0.2, green: 0.6, blue: 1.0),
                textFormat: sheets.TextFormat(
                  fontSize: 16,
                  bold: true,
                  foregroundColor: sheets.Color(red: 1.0, green: 1.0, blue: 1.0),
                ),
                horizontalAlignment: 'CENTER',
              ),
            ),
            fields: 'userEnteredFormat',
          ),
        ),
        
        // Format script code cell
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: sheetId,
              startRowIndex: 15,
              endRowIndex: 16,
              startColumnIndex: 0,
              endColumnIndex: 1,
            ),
            cell: sheets.CellData(
              userEnteredFormat: sheets.CellFormat(
                backgroundColor: sheets.Color(red: 0.95, green: 0.95, blue: 0.95),
                textFormat: sheets.TextFormat(
                  fontFamily: 'Courier New',
                  fontSize: 9,
                ),
                wrapStrategy: 'WRAP',
              ),
            ),
            fields: 'userEnteredFormat',
          ),
        ),
        
        // Auto-resize columns
        sheets.Request(
          autoResizeDimensions: sheets.AutoResizeDimensionsRequest(
            dimensions: sheets.DimensionRange(
              sheetId: sheetId,
              dimension: 'COLUMNS',
              startIndex: 0,
              endIndex: 1,
            ),
          ),
        ),
      ];
      
      await _sheetsApi!.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        spreadsheetId,
      );
      
    } catch (e) {
      debugPrint('⚠️ [BACKUP_SETUP] Error formatting sheet: $e');
    }
  }
  
  /// Create the backup folder in Google Drive
  Future<void> _createBackupFolder() async {
    if (_driveApi == null) return;
    
    try {
      // Check if folder already exists
      final query = "name = 'BPApp_Backups' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final response = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
      );
      
      if (response.files != null && response.files!.isNotEmpty) {
        debugPrint('📁 [BACKUP_SETUP] Backup folder already exists');
        return;
      }
      
      // Create new folder
      final folder = drive.File()
        ..name = 'BPApp_Backups'
        ..mimeType = 'application/vnd.google-apps.folder'
        ..description = 'גיבויים אוטומטיים של BPApp - נוצרים 7 פעמים ביום';
      
      await _driveApi!.files.create(folder);
      debugPrint('✅ [BACKUP_SETUP] Created backup folder');
      
    } catch (e) {
      debugPrint('⚠️ [BACKUP_SETUP] Error creating folder: $e');
    }
  }
  
  /// Add backup reminder formulas to the main sheet
  Future<void> _addBackupFormulas(String spreadsheetId) async {
    if (_sheetsApi == null) return;
    
    try {
      // Add a note to cell A1 about backups
      final note = sheets.Request(
        updateCells: sheets.UpdateCellsRequest(
          range: sheets.GridRange(
            sheetId: 0, // Main sheet
            startRowIndex: 0,
            endRowIndex: 1,
            startColumnIndex: 0,
            endColumnIndex: 1,
          ),
          rows: [
            sheets.RowData(
              values: [
                sheets.CellData(
                  note: 'גיבויים אוטומטיים: ראה הוראות בגיליון "הגדרת גיבויים"',
                ),
              ],
            ),
          ],
          fields: 'note',
        ),
      );
      
      await _sheetsApi!.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: [note]),
        spreadsheetId,
      );
      
    } catch (e) {
      debugPrint('⚠️ [BACKUP_SETUP] Error adding formulas: $e');
    }
  }
}

/// Dialog to offer backup setup to new users
class BackupSetupDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  
  const BackupSetupDialog({
    Key? key,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '🔒 הגדרת גיבויים אוטומטיים',
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'האם תרצה/י להגדיר גיבויים אוטומטיים לנתונים שלך?',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          SizedBox(height: 16),
          Text(
            '✅ 7 גיבויים ביום',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 14),
          ),
          Text(
            '✅ שמירה ל-30 יום',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 14),
          ),
          Text(
            '✅ ניקוי אוטומטי',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          Text(
            'ניתן להגדיר מאוחר יותר דרך הגיליון האלקטרוני',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDecline,
          child: const Text('לא עכשיו'),
        ),
        ElevatedButton(
          onPressed: onAccept,
          child: const Text('הגדר גיבויים'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.start,
    );
  }
}
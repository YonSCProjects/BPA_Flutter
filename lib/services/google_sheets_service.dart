import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;

import '../data/models/student_record.dart';
import '../data/models/autocomplete_data.dart';
import 'google_auth_service.dart';

class GoogleSheetsService extends ChangeNotifier {
  static const String spreadsheetName = 'BPApp';
  static const String worksheetName = 'נתוני תלמידים';
  
  static const List<String> hebrewHeaders = [
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

  final GoogleAuthService _authService;
  
  sheets.SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi;
  String? _spreadsheetId;
  int? _sheetId;
  bool _isLoading = false;
  String? _error;
  String? _recoveryMessage;
  AutocompleteData _autocompleteData = AutocompleteData.empty();

  GoogleSheetsService(this._authService) {
    _authService.addListener(_onAuthStateChanged);
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get recoveryMessage => _recoveryMessage;
  String? get spreadsheetId => _spreadsheetId;
  AutocompleteData get autocompleteData => _autocompleteData;
  bool get isInitialized => _spreadsheetId != null && _sheetsApi != null;

  Future<bool> initialize() async {
    _setLoading(true);
    _setError(null);
    _setRecoveryMessage(null);

    try {
      if (!_authService.isAuthenticated) {
        _setError('לא מחובר לגוגל - נדרשת התחברות');
        return false;
      }

      await _initializeApis();
      await _findOrCreateSpreadsheet();
      await _loadAutocompleteData();
      
      debugPrint('GoogleSheetsService initialized successfully');
      return true;
    } catch (e) {
      _setError('שגיאה באתחול שירות הגיליונות: ${e.toString()}');
      debugPrint('GoogleSheetsService initialization error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _initializeApis() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      throw Exception('לא ניתן לקבל חיבור מאומת');
    }

    _sheetsApi = sheets.SheetsApi(client);
    _driveApi = drive.DriveApi(client);
  }

  Future<void> _findOrCreateSpreadsheet() async {
    await _findExistingSpreadsheet();
    
    if (_spreadsheetId == null) {
      // Check if spreadsheet exists in trash before creating new one
      final recoveredFromTrash = await _checkAndRecoverFromTrash();
      if (!recoveredFromTrash) {
        await _createSpreadsheet();
      }
    }
    
    // Get sheet ID for API operations
    if (_spreadsheetId != null && _sheetId == null) {
      await _getSheetId();
    }
  }

  Future<void> _findExistingSpreadsheet() async {
    if (_driveApi == null) return;

    try {
      final response = await _driveApi!.files.list(
        q: "name='$spreadsheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
        spaces: 'drive',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        _spreadsheetId = response.files!.first.id!;
        debugPrint('Found existing spreadsheet: $_spreadsheetId');
      }
    } catch (e) {
      debugPrint('Error finding existing spreadsheet: $e');
    }
  }

  Future<void> _createSpreadsheet() async {
    if (_sheetsApi == null) return;

    try {
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: spreadsheetName,
          locale: 'en_US',
          timeZone: 'Asia/Jerusalem',
        ),
        sheets: [
          sheets.Sheet(
            properties: sheets.SheetProperties(
              title: worksheetName,
              rightToLeft: true,
              gridProperties: sheets.GridProperties(
                frozenRowCount: 1,
                columnCount: hebrewHeaders.length,
              ),
            ),
          ),
        ],
      );

      final response = await _sheetsApi!.spreadsheets.create(spreadsheet);
      _spreadsheetId = response.spreadsheetId!;
      
      await _addHeaders();
      
      debugPrint('Created new spreadsheet: $_spreadsheetId');
    } catch (e) {
      throw Exception('שגיאה ביצירת גיליון אלקטרוני: ${e.toString()}');
    }
  }

  Future<void> _addHeaders() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final range = '$worksheetName!A1:${String.fromCharCode(65 + hebrewHeaders.length - 1)}1';
      final valueRange = sheets.ValueRange(
        values: [hebrewHeaders],
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        range,
        valueInputOption: 'RAW',
      );

      await _formatHeaders();
      
      debugPrint('Headers added successfully');
    } catch (e) {
      debugPrint('Error adding headers: $e');
    }
  }

  Future<void> _getSheetId() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final response = await _sheetsApi!.spreadsheets.get(_spreadsheetId!);
      if (response.sheets != null && response.sheets!.isNotEmpty) {
        // Find the sheet with our worksheet name
        final targetSheet = response.sheets!.firstWhere(
          (sheet) => sheet.properties?.title == worksheetName,
          orElse: () => response.sheets!.first, // fallback to first sheet
        );
        _sheetId = targetSheet.properties?.sheetId ?? 0;
        debugPrint('Found sheet ID: $_sheetId');
      }
    } catch (e) {
      debugPrint('Error getting sheet ID: $e');
      _sheetId = 0; // fallback to 0
    }
  }

  Future<bool> _checkAndRecoverFromTrash() async {
    if (_driveApi == null) return false;

    try {
      debugPrint('Checking for BPApp spreadsheet in trash...');
      
      // Search for the spreadsheet in trash
      final response = await _driveApi!.files.list(
        q: "name='$spreadsheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=true",
        spaces: 'drive',
        orderBy: 'modifiedTime desc', // Get most recently deleted first
      );

      if (response.files != null && response.files!.isNotEmpty) {
        final deletedFile = response.files!.first;
        debugPrint('Found BPApp spreadsheet in trash: ${deletedFile.id}');
        
        // Attempt to recover the file from trash
        return await _recoverFromTrash(deletedFile.id!, deletedFile.name!);
      }
      
      debugPrint('No BPApp spreadsheet found in trash');
      return false;
    } catch (e) {
      debugPrint('Error checking trash for spreadsheet: $e');
      return false;
    }
  }

  Future<bool> _recoverFromTrash(String fileId, String fileName) async {
    if (_driveApi == null) return false;

    try {
      debugPrint('Attempting to recover spreadsheet from trash: $fileId');
      
      // Create an update request to untrash the file
      final fileUpdate = drive.File();
      fileUpdate.trashed = false;
      
      // Restore the file from trash
      await _driveApi!.files.update(
        fileUpdate,
        fileId,
      );
      
      // Set the recovered spreadsheet ID
      _spreadsheetId = fileId;
      
      debugPrint('Successfully recovered BPApp spreadsheet from trash: $fileId');
      
      // Set recovery success message
      _recoveryMessage = 'הגיליון האלקטרוני שלך שוחזר בהצלחה מהפח! כל הנתונים שלך נשמרו.';
      
      // Notify about recovery (this could trigger UI notification)
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error recovering spreadsheet from trash: $e');
      return false;
    }
  }

  Future<void> _formatHeaders() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final requests = [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: 0,
              startRowIndex: 0,
              endRowIndex: 1,
              startColumnIndex: 0,
              endColumnIndex: hebrewHeaders.length,
            ),
            cell: sheets.CellData(
              userEnteredFormat: sheets.CellFormat(
                backgroundColor: sheets.Color(
                  red: 0.9,
                  green: 0.9,
                  blue: 0.9,
                ),
                textFormat: sheets.TextFormat(
                  bold: true,
                  fontSize: 12,
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

      await _sheetsApi!.spreadsheets.batchUpdate(
        batchUpdateRequest,
        _spreadsheetId!,
      );
    } catch (e) {
      debugPrint('Error formatting headers: $e');
    }
  }

  Future<void> _loadAutocompleteData() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:L',
      );

      if (response.values != null) {
        final studentNames = <String>{};
        final classNames = <String>{};

        for (final row in response.values!) {
          if (row.length >= 3) {
            final studentName = row[1]?.toString().trim();
            final className = row[2]?.toString().trim();

            if (studentName != null && studentName.isNotEmpty) {
              studentNames.add(studentName);
            }
            if (className != null && className.isNotEmpty) {
              classNames.add(className);
            }
          }
        }

        _autocompleteData = AutocompleteData(
          studentNames: studentNames,
          classNames: classNames,
          lastUpdated: DateTime.now(),
        );

        debugPrint('Loaded autocomplete data: ${studentNames.length} students, ${classNames.length} classes');
      }
    } catch (e) {
      debugPrint('Error loading autocomplete data: $e');
    }
  }

  Future<StudentRecord?> findMatchingRecord(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return null;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:L',
      );

      if (response.values != null) {
        for (int i = 0; i < response.values!.length; i++) {
          final row = response.values![i];
          if (row.length >= 4) {
            final existingDate = row[0]?.toString();
            final existingStudent = row[1]?.toString();
            final existingClass = row[2]?.toString();
            final existingClassNumber = int.tryParse(row[3]?.toString() ?? '');

            if (existingDate == record.date &&
                existingStudent == record.studentName &&
                existingClass == record.className &&
                existingClassNumber == record.classNumber) {
              
              try {
                return StudentRecord.fromSheetRow(row);
              } catch (e) {
                debugPrint('Error parsing existing record: $e');
                continue;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding matching record: $e');
    }

    return null;
  }

  Future<bool> saveRecord(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      final recordWithScore = record.withCalculatedScore();
      final existingRecord = await findMatchingRecord(recordWithScore);

      bool success;
      if (existingRecord != null) {
        success = await _updateRecord(recordWithScore);
        debugPrint('Updated existing record');
      } else {
        success = await _appendRecord(recordWithScore);
        debugPrint('Created new record');
      }

      if (success) {
        _autocompleteData = _autocompleteData.addFromRecord(recordWithScore);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('שגיאה בשמירת הרשומה: ${e.toString()}');
      debugPrint('Error saving record: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _updateRecord(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return false;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:L',
      );

      if (response.values != null) {
        for (int i = 0; i < response.values!.length; i++) {
          final row = response.values![i];
          if (row.length >= 4 &&
              row[0]?.toString() == record.date &&
              row[1]?.toString() == record.studentName &&
              row[2]?.toString() == record.className &&
              int.tryParse(row[3]?.toString() ?? '') == record.classNumber) {
            
            final rowNumber = i + 2;
            final range = '$worksheetName!A$rowNumber:L$rowNumber';
            
            final valueRange = sheets.ValueRange(
              values: [record.toSheetRow()],
            );

            await _sheetsApi!.spreadsheets.values.update(
              valueRange,
              _spreadsheetId!,
              range,
              valueInputOption: 'RAW',
            );

            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating record: $e');
    }

    return false;
  }

  Future<bool> _appendRecord(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return false;

    try {
      final insertPosition = await _findInsertPosition(record);
      
      if (insertPosition == -1) {
        return await _appendToEnd(record);
      } else {
        return await _insertRecordAtPosition(record, insertPosition);
      }
    } catch (e) {
      debugPrint('Error appending record: $e');
      return false;
    }
  }

  Future<int> _findInsertPosition(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return -1;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:D',
      );

      if (response.values == null || response.values!.isEmpty) {
        return 2; // Insert after header row
      }

      final recordDate = DateTime.tryParse(record.date);
      if (recordDate == null) return -1;

      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        if (row.isEmpty) continue;

        final existingDate = DateTime.tryParse(row[0]?.toString() ?? '');
        if (existingDate == null) continue;

        final existingClassNumber = int.tryParse(row[3]?.toString() ?? '0') ?? 0;

        // Compare dates first (primary sort)
        if (recordDate.isBefore(existingDate)) {
          return i + 2; // +2 because sheet is 1-indexed and has header row
        }
        
        // If same date, compare class numbers (secondary sort)
        if (recordDate.isAtSameMomentAs(existingDate)) {
          if (record.classNumber < existingClassNumber) {
            return i + 2;
          }
        }
      }

      return -1; // Insert at end
    } catch (e) {
      debugPrint('Error finding insert position: $e');
      return -1;
    }
  }

  Future<bool> _insertRecordAtPosition(StudentRecord record, int rowPosition) async {
    if (_sheetsApi == null || _spreadsheetId == null || _sheetId == null) return false;

    try {
      // Insert empty row at the target position
      final insertRequest = sheets.Request(
        insertRange: sheets.InsertRangeRequest(
          range: sheets.GridRange(
            sheetId: _sheetId!, // Use the actual sheet ID
            startRowIndex: rowPosition - 1, // 0-indexed for API
            endRowIndex: rowPosition,
            startColumnIndex: 0,
            endColumnIndex: hebrewHeaders.length,
          ),
          shiftDimension: 'ROWS',
        ),
      );

      final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
        requests: [insertRequest],
      );

      await _sheetsApi!.spreadsheets.batchUpdate(
        batchUpdateRequest,
        _spreadsheetId!,
      );

      // Now populate the new row with data
      final range = '$worksheetName!A$rowPosition:L$rowPosition';
      final valueRange = sheets.ValueRange(
        values: [record.toSheetRow()],
      );

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId!,
        range,
        valueInputOption: 'RAW',
      );

      debugPrint('Inserted record at position $rowPosition');
      return true;
    } catch (e) {
      debugPrint('Error inserting record at position $rowPosition: $e');
      return false;
    }
  }

  Future<bool> _appendToEnd(StudentRecord record) async {
    if (_sheetsApi == null || _spreadsheetId == null) return false;

    try {
      final valueRange = sheets.ValueRange(
        values: [record.toSheetRow()],
      );

      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        _spreadsheetId!,
        '$worksheetName!A:L',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );

      return true;
    } catch (e) {
      debugPrint('Error appending record to end: $e');
      return false;
    }
  }

  Future<int> getNextClassNumber(String date) async {
    if (_sheetsApi == null || _spreadsheetId == null) return 1;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId!,
        '$worksheetName!A2:D',
      );

      if (response.values != null) {
        final classNumbers = <int>{};
        
        for (final row in response.values!) {
          if (row.length >= 4 && row[0]?.toString() == date) {
            final classNumber = int.tryParse(row[3]?.toString() ?? '');
            if (classNumber != null) {
              classNumbers.add(classNumber);
            }
          }
        }

        for (int i = 1; i <= 7; i++) {
          if (!classNumbers.contains(i)) {
            return i;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting next class number: $e');
    }

    return 1;
  }

  List<String> getStudentSuggestions(String query) {
    return _autocompleteData.getStudentSuggestions(query);
  }

  List<String> getClassSuggestions(String query) {
    return _autocompleteData.getClassSuggestions(query);
  }

  Future<void> refreshAutocompleteData() async {
    if (!isInitialized) return;

    try {
      await _loadAutocompleteData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing autocomplete data: $e');
    }
  }

  void _onAuthStateChanged() {
    if (!_authService.isAuthenticated) {
      _reset();
    }
  }

  void _reset() {
    _sheetsApi = null;
    _driveApi = null;
    _spreadsheetId = null;
    _sheetId = null;
    _autocompleteData = AutocompleteData.empty();
    _setError(null);
    _setRecoveryMessage(null);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _setRecoveryMessage(String? message) {
    _recoveryMessage = message;
    notifyListeners();
  }

  void clearRecoveryMessage() {
    _setRecoveryMessage(null);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }
}
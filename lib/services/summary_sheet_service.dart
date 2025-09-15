import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../data/models/student_record.dart';

class SummarySheetService {
  static const String summarySheetName = 'סיכום';

  static const List<String> summaryHeaders = [
    'תאריך',
    'שם התלמיד',
    'סוג רשומה',  // רגיל/יומי/שבועי/חודשי
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

  final sheets.SheetsApi _sheetsApi;
  final String _spreadsheetId;
  int? _summarySheetId;

  // Cache for performance optimization
  List<StudentRecord>? _cachedRecords;
  DateTime? _lastCacheUpdate;

  SummarySheetService(this._sheetsApi, this._spreadsheetId);

  /// Refresh the entire summary sheet from main sheet data
  Future<void> refreshSummaryFromMainSheet() async {
    try {
      debugPrint('🔄 [SUMMARY] Full refresh of summary sheet from main data');

      // Ensure summary sheet exists
      if (_summarySheetId == null) {
        await ensureSummarySheetExists();
        if (_summarySheetId == null) {
          debugPrint('❌ [SUMMARY] Cannot create summary sheet');
          return;
        }
      }

      // Get all records from main sheet
      final allRecords = await _getAllMainSheetRecords();
      if (allRecords.isEmpty) {
        debugPrint('⚠️ [SUMMARY] No records in main sheet to summarize');
        return;
      }

      // Group and rebuild
      final groupedRecords = _groupAndSortRecords(allRecords);
      await _rebuildSummarySheet(groupedRecords);

      debugPrint('✅ [SUMMARY] Full refresh complete with ${allRecords.length} records');
    } catch (e) {
      debugPrint('❌ [SUMMARY] Error during full refresh: $e');
    }
  }

  /// Batch process multiple records at once for better performance
  Future<void> batchMirrorRecords(List<StudentRecord> newRecords) async {
    if (newRecords.isEmpty) return;

    try {
      // Ensure summary sheet exists
      if (_summarySheetId == null) {
        await ensureSummarySheetExists();
        if (_summarySheetId == null) {
          debugPrint('❌ [SUMMARY] Cannot create summary sheet, skipping batch');
          return;
        }
      }

      // Get all existing records
      final existingRecords = await _getAllSummaryRecords();

      // Create a map for faster duplicate checking
      final existingKeys = <String, StudentRecord>{};
      for (final record in existingRecords) {
        final key = '${record.date}|${record.studentName}|${record.className}|${record.classNumber}';
        existingKeys[key] = record;
      }

      // Process new records
      final updatedRecords = <StudentRecord>[...existingRecords];
      for (final newRecord in newRecords) {
        final key = '${newRecord.date}|${newRecord.studentName}|${newRecord.className}|${newRecord.classNumber}';

        if (existingKeys.containsKey(key)) {
          // Update existing record
          updatedRecords.remove(existingKeys[key]);
        }
        updatedRecords.add(newRecord);
      }

      // Group and rebuild
      final groupedRecords = _groupAndSortRecords(updatedRecords);
      await _rebuildSummarySheet(groupedRecords);

      debugPrint('✅ [SUMMARY] Batch processed ${newRecords.length} records');
    } catch (e) {
      debugPrint('❌ [SUMMARY] Error in batch mirror: $e');
    }
  }

  Future<void> ensureSummarySheetExists() async {
    try {
      final spreadsheet = await _sheetsApi.spreadsheets.get(_spreadsheetId);

      // Check if summary sheet already exists
      final existingSheet = spreadsheet.sheets?.firstWhere(
        (sheet) => sheet.properties?.title == summarySheetName,
        orElse: () => sheets.Sheet(),
      );

      if (existingSheet != null && existingSheet.properties?.sheetId != null) {
        _summarySheetId = existingSheet.properties!.sheetId;
        debugPrint('✅ [SUMMARY] Summary sheet already exists with ID: $_summarySheetId');
        return;
      }

      // Create summary sheet if it doesn't exist
      await _createSummarySheet();
    } catch (e) {
      debugPrint('❌ [SUMMARY] Error ensuring summary sheet exists: $e');
    }
  }

  Future<void> _createSummarySheet() async {
    try {
      final addSheetRequest = sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(
            title: summarySheetName,
            rightToLeft: true,
            gridProperties: sheets.GridProperties(
              frozenRowCount: 1,
              columnCount: summaryHeaders.length,
            ),
          ),
        ),
      );

      final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
        requests: [addSheetRequest],
      );

      final response = await _sheetsApi.spreadsheets.batchUpdate(
        batchUpdateRequest,
        _spreadsheetId,
      );

      // Get the new sheet ID from the response
      if (response.replies != null && response.replies!.isNotEmpty) {
        final addSheetReply = response.replies!.first.addSheet;
        if (addSheetReply != null && addSheetReply.properties != null) {
          _summarySheetId = addSheetReply.properties!.sheetId;
          debugPrint('✅ [SUMMARY] Created summary sheet with ID: $_summarySheetId');
        }

        // Add headers to the new sheet
        await _addSummaryHeaders();
        await _formatSummarySheet();

        // Populate with existing data from main sheet
        debugPrint('📊 [SUMMARY] Populating new summary sheet with existing data');
        await refreshSummaryFromMainSheet();
      }
    } catch (e) {
      debugPrint('❌ [SUMMARY] Error creating summary sheet: $e');
    }
  }

  Future<void> _addSummaryHeaders() async {
    try {
      final range = '$summarySheetName!A1:${String.fromCharCode(65 + summaryHeaders.length - 1)}1';
      final valueRange = sheets.ValueRange(
        values: [summaryHeaders],
      );

      await _sheetsApi.spreadsheets.values.update(
        valueRange,
        _spreadsheetId,
        range,
        valueInputOption: 'RAW',
      );

      debugPrint('✅ [SUMMARY] Headers added to summary sheet');
    } catch (e) {
      debugPrint('❌ [SUMMARY] Error adding headers: $e');
    }
  }

  Future<void> _formatSummarySheet() async {
    if (_summarySheetId == null) return;

    try {
      final requests = <sheets.Request>[
        // Format headers
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: _summarySheetId,
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
        // Auto-resize columns
        sheets.Request(
          autoResizeDimensions: sheets.AutoResizeDimensionsRequest(
            dimensions: sheets.DimensionRange(
              sheetId: _summarySheetId,
              dimension: 'COLUMNS',
              startIndex: 0,
              endIndex: summaryHeaders.length,
            ),
          ),
        ),
        // Add warning-only protection for summary sheet
        sheets.Request(
          addProtectedRange: sheets.AddProtectedRangeRequest(
            protectedRange: sheets.ProtectedRange(
              range: sheets.GridRange(
                sheetId: _summarySheetId,
                startRowIndex: 0,
                endRowIndex: 1000, // Protect entire sheet
              ),
              description: 'אזהרה: גיליון הסיכום מחושב אוטומטית על ידי אפליקציית BPApp. עריכה ידנית תגרום לחוסר סנכרון בנתונים.',
              warningOnly: true, // Warning only - shows alert but allows editing
            ),
          ),
        ),
      ];

      final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
        requests: requests,
      );

      await _sheetsApi.spreadsheets.batchUpdate(
        batchUpdateRequest,
        _spreadsheetId,
      );

      debugPrint('✅ [SUMMARY] Summary sheet formatted and protected successfully');
    } catch (e) {
      debugPrint('❌ [SUMMARY] Error formatting summary sheet: $e');
    }
  }

  Future<void> mirrorRecordToSummary(StudentRecord record) async {
    try {
      debugPrint('🔄 [SUMMARY] Starting mirror for record: ${record.studentName} - ${record.date}');

      // Ensure summary sheet exists before operations
      if (_summarySheetId == null) {
        await ensureSummarySheetExists();
        if (_summarySheetId == null) {
          debugPrint('❌ [SUMMARY] Cannot create summary sheet, skipping');
          return;
        }
      }

      // Get all records from the MAIN sheet, not the summary sheet!
      final existingRecords = await _getAllMainSheetRecords();
      debugPrint('🔄 [SUMMARY] Found ${existingRecords.length} existing records in MAIN sheet');

      // Since we're getting records from main sheet, the new record might already be there
      // Check if it's already included
      final alreadyIncluded = existingRecords.any((r) =>
        r.date == record.date &&
        r.studentName == record.studentName &&
        r.className == record.className &&
        r.classNumber == record.classNumber
      );

      final allRecords = alreadyIncluded ? existingRecords : [...existingRecords, record];
      debugPrint('🔄 [SUMMARY] Total records for summary: ${allRecords.length}');

      // Group records by student and sort
      final groupedRecords = _groupAndSortRecords(allRecords);
      debugPrint('🔄 [SUMMARY] Grouped into ${groupedRecords.length} students');
      for (final entry in groupedRecords.entries) {
        debugPrint('  - ${entry.key}: ${entry.value.length} records');
      }

      // Clear cache since data is changing
      _clearCache();

      // Clear and rebuild the summary sheet with sorted data and summaries
      await _rebuildSummarySheet(groupedRecords);

    } catch (e) {
      debugPrint('❌ [SUMMARY] Error mirroring record to summary: $e');
      // Don't let summary sheet errors break the main save operation
    }
  }

  Future<List<StudentRecord>> _getAllMainSheetRecords() async {
    try {
      debugPrint('📖 [SUMMARY] Reading records from MAIN sheet');

      // Import the main worksheet name from GoogleSheetsService
      const mainSheetName = 'נתוני תלמידים';
      final range = '$mainSheetName!A2:L';

      final response = await _sheetsApi.spreadsheets.values.get(
        _spreadsheetId,
        range,
      );

      if (response.values == null) {
        debugPrint('⚠️ [SUMMARY] No data in main sheet');
        return [];
      }

      final records = <StudentRecord>[];
      for (final row in response.values!) {
        if (row.length < 11) continue; // Skip incomplete rows

        try {
          // Parse main sheet row (no record type column in main sheet)
          final record = StudentRecord(
            date: row[0]?.toString() ?? '',
            studentName: row[1]?.toString() ?? '',
            className: row[2]?.toString() ?? '',
            classNumber: int.tryParse(row[3]?.toString() ?? '') ?? 0,
            entry: int.tryParse(row[4]?.toString() ?? '') ?? 0,
            staying: int.tryParse(row[5]?.toString() ?? '') ?? 0,
            attitude: int.tryParse(row[6]?.toString() ?? '') ?? 0,
            performance: int.tryParse(row[7]?.toString() ?? '') ?? 0,
            personalGoal: int.tryParse(row[8]?.toString() ?? '') ?? 0,
            bonus: int.tryParse(row[9]?.toString() ?? '') ?? 0,
            totalScore: int.tryParse(row[10]?.toString() ?? '') ?? 0,
            comments: row.length > 11 ? row[11]?.toString() ?? '' : '',
          );
          records.add(record);
        } catch (e) {
          debugPrint('⚠️ [SUMMARY] Error parsing main sheet row: $e');
        }
      }

      debugPrint('✅ [SUMMARY] Retrieved ${records.length} records from MAIN sheet');
      return records;
    } catch (e) {
      debugPrint('❌ [SUMMARY] Error getting main sheet records: $e');
      return [];
    }
  }

  Future<List<StudentRecord>> _getAllSummaryRecords() async {
    try {
      // Use cache if available and recent (within 5 seconds)
      if (_cachedRecords != null && _lastCacheUpdate != null) {
        final cacheAge = DateTime.now().difference(_lastCacheUpdate!).inSeconds;
        if (cacheAge < 5) {
          debugPrint('⚡ [SUMMARY] Using cached records (${_cachedRecords!.length} records, age: ${cacheAge}s)');
          return _cachedRecords!;
        }
      }

      // Check if summary sheet exists
      if (_summarySheetId == null) {
        debugPrint('⚠️ [SUMMARY] No summary sheet ID, returning empty list');
        return [];
      }

      final range = '$summarySheetName!A2:M';
      final response = await _sheetsApi.spreadsheets.values.get(
        _spreadsheetId,
        range,
      );

      if (response.values == null) return [];

      final records = <StudentRecord>[];
      int rowCount = 0;
      int skippedCount = 0;
      for (final row in response.values!) {
        rowCount++;

        // Debug log first few rows
        if (rowCount <= 3) {
          debugPrint('🔍 [SUMMARY] Row $rowCount: ${row.take(5)}...');
        }

        // Skip summary rows (check record type column)
        if (row.length > 2 && row[2] != 'רגיל') {
          skippedCount++;
          debugPrint('🚫 [SUMMARY] Skipping summary row $rowCount: type=${row[2]}');
          continue;
        }

        try {
          final record = _parseRowToRecord(row);
          if (record != null) {
            records.add(record);
            if (records.length <= 3) {
              debugPrint('✅ [SUMMARY] Parsed record: ${record.studentName} - ${record.date}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ [SUMMARY] Error parsing row $rowCount: $e');
        }
      }

      debugPrint('📋 [SUMMARY] Total rows: $rowCount, Skipped: $skippedCount, Records: ${records.length}');

      debugPrint('✅ [SUMMARY] Retrieved ${records.length} records from summary sheet');

      // Update cache
      _cachedRecords = records;
      _lastCacheUpdate = DateTime.now();

      return records;
    } catch (e) {
      // Check if it's a 404 error (sheet doesn't exist)
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        debugPrint('⚠️ [SUMMARY] Summary sheet not found, will create on next save');
        _summarySheetId = null; // Reset ID to trigger recreation
        return [];
      }
      debugPrint('❌ [SUMMARY] Error getting existing records: $e');
      return [];
    }
  }

  /// Clear the cache when data changes
  void _clearCache() {
    _cachedRecords = null;
    _lastCacheUpdate = null;
  }

  StudentRecord? _parseRowToRecord(List<dynamic> row) {
    if (row.length < 12) return null;

    try {
      final totalScore = int.tryParse(row[11]?.toString() ?? '') ?? 0;
      return StudentRecord(
        date: row[0]?.toString() ?? '',
        studentName: row[1]?.toString() ?? '',
        className: row[3]?.toString() ?? '',
        classNumber: int.tryParse(row[4]?.toString() ?? '') ?? 0,
        entry: int.tryParse(row[5]?.toString() ?? '') ?? 0,
        staying: int.tryParse(row[6]?.toString() ?? '') ?? 0,
        attitude: int.tryParse(row[7]?.toString() ?? '') ?? 0,
        performance: int.tryParse(row[8]?.toString() ?? '') ?? 0,
        personalGoal: int.tryParse(row[9]?.toString() ?? '') ?? 0,
        bonus: int.tryParse(row[10]?.toString() ?? '') ?? 0,
        comments: row[12]?.toString() ?? '',
        totalScore: totalScore,
      );
    } catch (e) {
      debugPrint('⚠️ [SUMMARY] Error parsing record: $e');
      return null;
    }
  }

  Map<String, List<StudentRecord>> _groupAndSortRecords(List<StudentRecord> records) {
    final grouped = <String, List<StudentRecord>>{};

    for (final record in records) {
      grouped.putIfAbsent(record.studentName, () => []).add(record);
    }

    // Sort each student's records by date, then class number
    for (final studentRecords in grouped.values) {
      studentRecords.sort((a, b) {
        final dateCompare = _compareDates(a.date, b.date);
        if (dateCompare != 0) return dateCompare;
        return a.classNumber.compareTo(b.classNumber);
      });
    }

    return grouped;
  }

  int _compareDates(String date1, String date2) {
    try {
      final parts1 = date1.split('/');
      final parts2 = date2.split('/');

      if (parts1.length == 3 && parts2.length == 3) {
        final d1 = DateTime(
          int.parse(parts1[2]),
          int.parse(parts1[1]),
          int.parse(parts1[0]),
        );
        final d2 = DateTime(
          int.parse(parts2[2]),
          int.parse(parts2[1]),
          int.parse(parts2[0]),
        );
        return d1.compareTo(d2);
      }
    } catch (e) {
      debugPrint('⚠️ [SUMMARY] Error comparing dates: $e');
    }
    return date1.compareTo(date2);
  }

  Future<void> _rebuildSummarySheet(Map<String, List<StudentRecord>> groupedRecords) async {
    final allRows = <List<dynamic>>[];
    final calculator = SummaryCalculator();
    final now = DateTime.now();
    final currentDay = '${now.day}/${now.month}/${now.year}';
    final currentWeek = _getWeekNumber(now);
    final currentMonth = now.month;
    final currentYear = now.year;

    debugPrint('📊 [SUMMARY] Rebuilding with ${groupedRecords.length} students');

    // Sort student names alphabetically
    final sortedStudents = groupedRecords.keys.toList()..sort();

    for (final studentName in sortedStudents) {
      final studentRecords = groupedRecords[studentName]!;
      debugPrint('📊 [SUMMARY] Processing $studentName with ${studentRecords.length} records');

      for (int i = 0; i < studentRecords.length; i++) {
        final record = studentRecords[i];
        final recordDate = _parseDate(record.date);

        if (recordDate != null) {
          final day = '${recordDate.day}/${recordDate.month}/${recordDate.year}';
          final week = _getWeekNumber(recordDate);
          final month = recordDate.month;
          final year = recordDate.year;

          // Add the regular record
          allRows.add(_recordToRow(record, 'רגיל'));
          debugPrint('📊 [SUMMARY] Added record: ${record.date} - ${record.studentName} - Score: ${record.totalScore}');

          // Check if we need to add summaries
          final nextRecordDate = i < studentRecords.length - 1 ? _parseDate(studentRecords[i + 1].date) : null;

          final isLastRecordOfDay = i == studentRecords.length - 1 ||
              (nextRecordDate != null && (nextRecordDate.day != recordDate.day ||
               nextRecordDate.month != recordDate.month ||
               nextRecordDate.year != recordDate.year));

          final isLastRecordOfWeek = i == studentRecords.length - 1 ||
              (nextRecordDate != null && (_getWeekNumber(nextRecordDate) != week ||
               nextRecordDate.year != year));

          final isLastRecordOfMonth = i == studentRecords.length - 1 ||
              (nextRecordDate != null && (nextRecordDate.month != month ||
               nextRecordDate.year != year));

          // Add daily summary if needed (only for current day)
          if (isLastRecordOfDay && day == currentDay) {
            final dailyRecords = studentRecords.where((r) =>
              _parseDate(r.date)?.day == recordDate.day &&
              _parseDate(r.date)?.month == recordDate.month &&
              _parseDate(r.date)?.year == recordDate.year
            ).toList();

            final dailySummary = calculator.calculateDailySummary(
              studentName,
              recordDate,
              dailyRecords
            );
            allRows.add(_summaryToRow(dailySummary, 'יומי'));
          }

          // Add weekly summary if needed (only for current week)
          if (isLastRecordOfWeek && week == currentWeek && year == currentYear) {
            final weeklyRecords = studentRecords.where((r) {
              final rDate = _parseDate(r.date);
              return rDate != null &&
                     _getWeekNumber(rDate) == week &&
                     rDate.year == year;
            }).toList();

            final weeklySummary = calculator.calculateWeeklySummary(
              studentName,
              _getWeekStart(recordDate),
              weeklyRecords
            );
            allRows.add(_summaryToRow(weeklySummary, 'שבועי'));
          }

          // Add monthly summary if needed (only for current month)
          if (isLastRecordOfMonth && month == currentMonth && year == currentYear) {
            final monthlyRecords = studentRecords.where((r) {
              final rDate = _parseDate(r.date);
              return rDate != null &&
                     rDate.month == month &&
                     rDate.year == year;
            }).toList();

            final monthlySummary = calculator.calculateMonthlySummary(
              studentName,
              month,
              year,
              monthlyRecords
            );
            allRows.add(_summaryToRow(monthlySummary, 'חודשי'));
          }
        }
      }
    }

    debugPrint('📊 [SUMMARY] Total rows to write: ${allRows.length}');

    // Write all rows to the sheet
    await _writeSummaryRows(allRows);
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [SUMMARY] Error parsing date: $e');
    }
    return null;
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).floor() + 1;
  }

  DateTime _getWeekStart(DateTime date) {
    // Israeli week starts on Sunday (weekday 7 in Dart)
    final daysFromSunday = date.weekday == 7 ? 0 : date.weekday;
    return date.subtract(Duration(days: daysFromSunday));
  }

  List<dynamic> _recordToRow(StudentRecord record, String recordType) {
    return [
      record.date,
      record.studentName,
      recordType,
      record.className,
      record.classNumber.toString(),
      record.entry.toString(),
      record.staying.toString(),
      record.attitude.toString(),
      record.performance.toString(),
      record.personalGoal.toString(),
      record.bonus.toString(),
      record.totalScore.toString(),
      record.comments,
    ];
  }

  List<dynamic> _summaryToRow(Map<String, dynamic> summary, String summaryType) {
    return [
      summary['date'] ?? '',
      summary['studentName'] ?? '',
      summaryType,
      '', // No class name for summaries
      '', // No class number for summaries
      '', // No individual scores for summaries
      '',
      '',
      '',
      '',
      '',
      summary['totalScore']?.toString() ?? '0',
      summary['period'] ?? '',
    ];
  }

  Future<void> _writeSummaryRows(List<List<dynamic>> rows) async {
    try {
      // Check if summary sheet exists
      if (_summarySheetId == null) {
        debugPrint('⚠️ [SUMMARY] No summary sheet ID, cannot write rows');
        return;
      }

      // Clear existing data (except headers)
      try {
        await _sheetsApi.spreadsheets.values.clear(
          sheets.ClearValuesRequest(),
          _spreadsheetId,
          '$summarySheetName!A2:M',
        );
      } catch (clearError) {
        debugPrint('⚠️ [SUMMARY] Error clearing sheet, continuing: $clearError');
      }

      if (rows.isEmpty) {
        debugPrint('ℹ️ [SUMMARY] No rows to write to summary sheet');
        return;
      }

      // Batch rows for better performance (Google Sheets API limit is 40,000 cells per request)
      const maxCellsPerBatch = 30000; // Conservative limit
      const cellsPerRow = 13; // Number of columns
      final maxRowsPerBatch = maxCellsPerBatch ~/ cellsPerRow;

      for (int i = 0; i < rows.length; i += maxRowsPerBatch) {
        final batchEnd = (i + maxRowsPerBatch > rows.length) ? rows.length : i + maxRowsPerBatch;
        final batch = rows.sublist(i, batchEnd);
        final startRow = i + 2; // +2 for header and 1-based indexing

        final valueRange = sheets.ValueRange(
          values: batch,
        );

        await _sheetsApi.spreadsheets.values.update(
          valueRange,
          _spreadsheetId,
          '$summarySheetName!A$startRow',
          valueInputOption: 'RAW',
        );

        debugPrint('✅ [SUMMARY] Written batch ${i ~/ maxRowsPerBatch + 1}: rows $startRow-${startRow + batch.length - 1}');
      }

      // Format summary rows with different colors
      await _formatSummaryRows(rows);

      debugPrint('✅ [SUMMARY] Written ${rows.length} total rows to summary sheet');

      // Debug: Print first few rows to verify
      if (rows.isNotEmpty) {
        debugPrint('📊 [SUMMARY] Sample rows written:');
        for (int i = 0; i < rows.length && i < 5; i++) {
          debugPrint('  Row ${i+1}: ${rows[i]}');
        }
      }
    } catch (e) {
      debugPrint('❌ [SUMMARY] Error writing summary rows: $e');
      // Don't throw - let the main save continue even if summary fails
    }
  }

  Future<void> _formatSummaryRows(List<List<dynamic>> rows) async {
    if (_summarySheetId == null) return;

    final requests = <sheets.Request>[];

    for (int i = 0; i < rows.length; i++) {
      final rowIndex = i + 1; // +1 for header row
      final recordType = rows[i].length > 2 ? rows[i][2] : '';

      sheets.Color? backgroundColor;
      bool bold = false;

      switch (recordType) {
        case 'יומי':
          backgroundColor = sheets.Color(red: 0.89, green: 0.95, blue: 0.99); // Light blue
          bold = true;
          break;
        case 'שבועי':
          backgroundColor = sheets.Color(red: 0.91, green: 0.96, blue: 0.91); // Light green
          bold = true;
          break;
        case 'חודשי':
          backgroundColor = sheets.Color(red: 1.0, green: 0.98, blue: 0.77); // Light yellow
          bold = true;
          break;
      }

      if (backgroundColor != null) {
        requests.add(
          sheets.Request(
            repeatCell: sheets.RepeatCellRequest(
              range: sheets.GridRange(
                sheetId: _summarySheetId,
                startRowIndex: rowIndex,
                endRowIndex: rowIndex + 1,
              ),
              cell: sheets.CellData(
                userEnteredFormat: sheets.CellFormat(
                  backgroundColor: backgroundColor,
                  textFormat: sheets.TextFormat(
                    bold: bold,
                  ),
                ),
              ),
              fields: 'userEnteredFormat.backgroundColor,userEnteredFormat.textFormat.bold',
            ),
          ),
        );
      }
    }

    if (requests.isNotEmpty) {
      try {
        final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
          requests: requests,
        );

        await _sheetsApi.spreadsheets.batchUpdate(
          batchUpdateRequest,
          _spreadsheetId,
        );

        debugPrint('✅ [SUMMARY] Formatted ${requests.length} summary rows');
      } catch (e) {
        debugPrint('❌ [SUMMARY] Error formatting summary rows: $e');
      }
    }
  }
}

class SummaryCalculator {
  Map<String, dynamic> calculateDailySummary(
    String studentName,
    DateTime date,
    List<StudentRecord> records,
  ) {
    int totalScore = 0;
    for (final record in records) {
      totalScore += record.totalScore;
    }

    return {
      'date': '${date.day}/${date.month}/${date.year}',
      'studentName': studentName,
      'totalScore': totalScore,
      'period': 'סיכום יומי - ${date.day}/${date.month}',
    };
  }

  Map<String, dynamic> calculateWeeklySummary(
    String studentName,
    DateTime weekStart,
    List<StudentRecord> records,
  ) {
    int totalScore = 0;
    for (final record in records) {
      totalScore += record.totalScore;
    }

    final weekEnd = weekStart.add(const Duration(days: 6));
    return {
      'date': '${weekStart.day}/${weekStart.month}/${weekStart.year}',
      'studentName': studentName,
      'totalScore': totalScore,
      'period': 'סיכום שבועי ${weekStart.day}/${weekStart.month} - ${weekEnd.day}/${weekEnd.month}',
    };
  }

  Map<String, dynamic> calculateMonthlySummary(
    String studentName,
    int month,
    int year,
    List<StudentRecord> records,
  ) {
    int totalScore = 0;
    for (final record in records) {
      totalScore += record.totalScore;
    }

    final monthNames = [
      '', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
      'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'
    ];

    return {
      'date': '01/$month/$year',
      'studentName': studentName,
      'totalScore': totalScore,
      'period': 'סיכום חודשי - ${monthNames[month]} $year',
    };
  }
}
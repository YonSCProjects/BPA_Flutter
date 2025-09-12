import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'google_sheets_service.dart';
import 'google_auth_service.dart';
import '../data/models/student_record.dart';

/// Service for backing up and recovering BPApp data
/// Provides export/import functionality for spreadsheet data
class BackupRecoveryService extends ChangeNotifier {
  final GoogleSheetsService _sheetsService;
  final GoogleAuthService _authService;
  
  bool _isProcessing = false;
  String? _lastBackupPath;
  String? _error;
  
  bool get isProcessing => _isProcessing;
  String? get lastBackupPath => _lastBackupPath;
  String? get error => _error;
  
  BackupRecoveryService({
    required GoogleSheetsService sheetsService,
    required GoogleAuthService authService,
  }) : _sheetsService = sheetsService,
       _authService = authService;
  
  /// Create a backup of all spreadsheet data
  Future<bool> createBackup({bool shareAfterCreation = true}) async {
    _setProcessing(true);
    _setError(null);
    
    try {
      debugPrint('📦 [BACKUP] Starting backup process...');
      
      // Check if user is authenticated and sheets service is initialized
      if (!_authService.isAuthenticated) {
        _setError('לא מחובר - נדרשת התחברות לגוגל');
        return false;
      }
      
      if (!_sheetsService.isInitialized) {
        _setError('שירות הגיליונות לא מאותחל');
        return false;
      }
      
      // Get all data from spreadsheet
      final backupData = await _fetchAllSpreadsheetData();
      if (backupData == null) {
        _setError('לא ניתן לקרוא את נתוני הגיליון');
        return false;
      }
      
      // Create backup metadata
      final backupMetadata = {
        'version': '1.0',
        'created_at': DateTime.now().toIso8601String(),
        'user_email': _authService.currentUser?.email,
        'user_name': _authService.currentUser?.displayName,
        'spreadsheet_id': _sheetsService.spreadsheetId,
        'total_records': backupData['records'].length,
        'app_version': 'BPApp v1.0',
      };
      
      // Combine metadata and data
      final fullBackup = {
        'metadata': backupMetadata,
        'data': backupData,
      };
      
      // Save to file
      final filePath = await _saveBackupToFile(fullBackup);
      if (filePath == null) {
        _setError('שגיאה בשמירת קובץ הגיבוי');
        return false;
      }
      
      _lastBackupPath = filePath;
      debugPrint('✅ [BACKUP] Backup created successfully: $filePath');
      
      // Share the backup file if requested
      if (shareAfterCreation) {
        await shareBackup(filePath);
      }
      
      return true;
      
    } catch (e) {
      _setError('שגיאה ביצירת גיבוי: ${e.toString()}');
      debugPrint('❌ [BACKUP] Error creating backup: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }
  
  /// Fetch all data from the spreadsheet
  Future<Map<String, dynamic>?> _fetchAllSpreadsheetData() async {
    try {
      final sheetsApi = await _authService.getSheetsApi();
      if (sheetsApi == null) return null;
      
      final spreadsheetId = _sheetsService.spreadsheetId;
      if (spreadsheetId == null) return null;
      
      debugPrint('📊 [BACKUP] Fetching data from spreadsheet: $spreadsheetId');
      
      // Get all values from the main worksheet
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        '${GoogleSheetsService.worksheetName}!A2:L', // Skip header row
      );
      
      final records = <Map<String, dynamic>>[];
      
      if (response.values != null) {
        for (final row in response.values!) {
          if (row.isNotEmpty) {
            try {
              // Parse each row into a StudentRecord
              final record = StudentRecord.fromSheetRow(row);
              records.add(record.toJson());
            } catch (e) {
              debugPrint('⚠️ [BACKUP] Skipping invalid row: $row');
            }
          }
        }
      }
      
      debugPrint('📊 [BACKUP] Fetched ${records.length} records');
      
      return {
        'spreadsheet_name': GoogleSheetsService.spreadsheetName,
        'worksheet_name': GoogleSheetsService.worksheetName,
        'headers': GoogleSheetsService.hebrewHeaders,
        'records': records,
      };
      
    } catch (e) {
      debugPrint('❌ [BACKUP] Error fetching spreadsheet data: $e');
      return null;
    }
  }
  
  /// Save backup data to a file
  Future<String?> _saveBackupToFile(Map<String, dynamic> backupData) async {
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted && !status.isLimited) {
          debugPrint('⚠️ [BACKUP] Storage permission denied');
        }
      }
      
      // Get the documents directory
      final Directory directory;
      if (Platform.isAndroid) {
        // Try to get external storage first, fall back to app documents
        final externalDir = await getExternalStorageDirectory();
        directory = externalDir ?? await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      // Create backups subdirectory
      final backupsDir = Directory('${directory.path}/BPApp_Backups');
      if (!await backupsDir.exists()) {
        await backupsDir.create(recursive: true);
      }
      
      // Generate filename with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'BPApp_Backup_$timestamp.json';
      final file = File('${backupsDir.path}/$fileName');
      
      // Write JSON data to file
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      await file.writeAsString(jsonString);
      
      debugPrint('💾 [BACKUP] Saved to: ${file.path}');
      return file.path;
      
    } catch (e) {
      debugPrint('❌ [BACKUP] Error saving backup file: $e');
      return null;
    }
  }
  
  /// Share the backup file
  Future<void> shareBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('⚠️ [BACKUP] File not found for sharing: $filePath');
        return;
      }
      
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'BPApp Backup',
        text: 'גיבוי נתוני BPApp מתאריך ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      );
      
      debugPrint('📤 [BACKUP] Backup shared successfully');
    } catch (e) {
      debugPrint('❌ [BACKUP] Error sharing backup: $e');
    }
  }
  
  /// Restore data from a backup file
  Future<bool> restoreFromBackup(String filePath) async {
    _setProcessing(true);
    _setError(null);
    
    try {
      debugPrint('📥 [RESTORE] Starting restore from: $filePath');
      
      // Read the backup file
      final file = File(filePath);
      if (!await file.exists()) {
        _setError('קובץ הגיבוי לא נמצא');
        return false;
      }
      
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate backup structure
      if (!_validateBackupData(backupData)) {
        _setError('קובץ גיבוי לא תקין');
        return false;
      }
      
      // Get metadata and data
      final metadata = backupData['metadata'] as Map<String, dynamic>;
      final data = backupData['data'] as Map<String, dynamic>;
      final records = data['records'] as List<dynamic>;
      
      debugPrint('📥 [RESTORE] Restoring ${records.length} records');
      debugPrint('📥 [RESTORE] Backup created: ${metadata['created_at']}');
      debugPrint('📥 [RESTORE] Original user: ${metadata['user_email']}');
      
      // Restore each record
      int successCount = 0;
      int failCount = 0;
      
      for (final recordJson in records) {
        try {
          final record = StudentRecord.fromJson(recordJson as Map<String, dynamic>);
          final success = await _sheetsService.saveRecord(record);
          
          if (success) {
            successCount++;
          } else {
            failCount++;
          }
          
          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 100));
          
        } catch (e) {
          failCount++;
          debugPrint('⚠️ [RESTORE] Failed to restore record: $e');
        }
      }
      
      debugPrint('✅ [RESTORE] Restore complete: $successCount success, $failCount failed');
      
      if (failCount > 0) {
        _setError('השחזור הושלם חלקית: $successCount הצליחו, $failCount נכשלו');
      }
      
      return failCount == 0;
      
    } catch (e) {
      _setError('שגיאה בשחזור מגיבוי: ${e.toString()}');
      debugPrint('❌ [RESTORE] Error restoring from backup: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }
  
  /// Validate backup data structure
  bool _validateBackupData(Map<String, dynamic> backupData) {
    try {
      // Check for required top-level keys
      if (!backupData.containsKey('metadata') || !backupData.containsKey('data')) {
        return false;
      }
      
      final metadata = backupData['metadata'] as Map<String, dynamic>;
      final data = backupData['data'] as Map<String, dynamic>;
      
      // Check metadata fields
      if (!metadata.containsKey('version') || 
          !metadata.containsKey('created_at') ||
          !metadata.containsKey('total_records')) {
        return false;
      }
      
      // Check data fields
      if (!data.containsKey('records') || 
          !data.containsKey('headers')) {
        return false;
      }
      
      // Validate records is a list
      if (data['records'] is! List) {
        return false;
      }
      
      return true;
      
    } catch (e) {
      debugPrint('⚠️ [BACKUP] Invalid backup structure: $e');
      return false;
    }
  }
  
  /// Get list of available backup files
  Future<List<BackupFileInfo>> getAvailableBackups() async {
    try {
      final Directory directory;
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        directory = externalDir ?? await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final backupsDir = Directory('${directory.path}/BPApp_Backups');
      if (!await backupsDir.exists()) {
        return [];
      }
      
      final files = await backupsDir.list().toList();
      final backups = <BackupFileInfo>[];
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final stat = await file.stat();
          final name = file.path.split('/').last;
          
          // Try to read metadata
          String? userEmail;
          int? recordCount;
          DateTime? createdAt;
          
          try {
            final content = await file.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;
            final metadata = data['metadata'] as Map<String, dynamic>;
            
            userEmail = metadata['user_email'] as String?;
            recordCount = metadata['total_records'] as int?;
            createdAt = DateTime.tryParse(metadata['created_at'] as String? ?? '');
          } catch (e) {
            // Ignore metadata read errors
          }
          
          backups.add(BackupFileInfo(
            path: file.path,
            name: name,
            size: stat.size,
            modified: stat.modified,
            created: createdAt ?? stat.modified,
            userEmail: userEmail,
            recordCount: recordCount,
          ));
        }
      }
      
      // Sort by creation date (newest first)
      backups.sort((a, b) => b.created.compareTo(a.created));
      
      return backups;
      
    } catch (e) {
      debugPrint('❌ [BACKUP] Error listing backups: $e');
      return [];
    }
  }
  
  /// Delete a backup file
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ [BACKUP] Deleted backup: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ [BACKUP] Error deleting backup: $e');
      return false;
    }
  }
  
  /// Export backup to CSV format
  Future<String?> exportToCSV() async {
    try {
      final backupData = await _fetchAllSpreadsheetData();
      if (backupData == null) return null;
      
      final records = backupData['records'] as List<dynamic>;
      final headers = GoogleSheetsService.hebrewHeaders;
      
      // Build CSV content
      final csvLines = <String>[];
      
      // Add headers
      csvLines.add(headers.join(','));
      
      // Add records
      for (final recordJson in records) {
        final record = StudentRecord.fromJson(recordJson as Map<String, dynamic>);
        final row = record.toSheetRow();
        csvLines.add(row.map((e) => '"$e"').join(','));
      }
      
      // Save to file
      final Directory directory;
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        directory = externalDir ?? await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'BPApp_Export_$timestamp.csv';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(csvLines.join('\n'), encoding: utf8);
      
      debugPrint('📊 [BACKUP] Exported to CSV: ${file.path}');
      return file.path;
      
    } catch (e) {
      debugPrint('❌ [BACKUP] Error exporting to CSV: $e');
      return null;
    }
  }
  
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}

/// Information about a backup file
class BackupFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final DateTime created;
  final String? userEmail;
  final int? recordCount;
  
  BackupFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.created,
    this.userEmail,
    this.recordCount,
  });
  
  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  String get createdFormatted {
    return DateFormat('dd/MM/yyyy HH:mm').format(created);
  }
}
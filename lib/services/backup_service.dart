import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'google_auth_service.dart';

/// Service for managing BPApp spreadsheet backups
class BackupService extends ChangeNotifier {
  final GoogleAuthService _authService;
  drive.DriveApi? _driveApi;
  String? _backupFolderId;
  bool _isInitialized = false;
  String? _error;
  
  BackupService(this._authService);
  
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  
  /// Initialize the backup service
  Future<void> initialize() async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        _setError('לא מחובר לחשבון Google');
        return;
      }
      
      _driveApi = drive.DriveApi(client);
      
      // Get or create backup folder
      _backupFolderId = await _getOrCreateBackupFolder();
      
      _isInitialized = true;
      _setError(null);
      debugPrint('✅ [BACKUP] Service initialized');
    } catch (e) {
      _setError('שגיאה באתחול שירות גיבוי: $e');
      debugPrint('❌ [BACKUP] Initialization error: $e');
    }
  }
  
  /// Create a manual backup of the BPApp spreadsheet
  Future<bool> createManualBackup(String spreadsheetId, {String? customName}) async {
    if (!_isInitialized || _driveApi == null) {
      await initialize();
      if (!_isInitialized) return false;
    }
    
    try {
      debugPrint('🔄 [BACKUP] Creating manual backup...');
      
      // Generate backup name with timestamp
      final now = DateTime.now();
      final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
                       '_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
      final backupName = customName ?? 'BPApp_Backup_$timestamp';
      
      // Copy the spreadsheet to backup folder
      final copyRequest = drive.File()
        ..name = backupName
        ..parents = _backupFolderId != null ? [_backupFolderId!] : null;
      
      final backup = await _driveApi!.files.copy(
        copyRequest,
        spreadsheetId,
        $fields: 'id,name,createdTime',
      );
      
      debugPrint('✅ [BACKUP] Created backup: ${backup.name} (ID: ${backup.id})');
      
      // Clean old backups (keep last 30 days worth = ~210 backups)
      await _cleanOldBackups(210);
      
      return true;
    } catch (e) {
      _setError('שגיאה ביצירת גיבוי: $e');
      debugPrint('❌ [BACKUP] Error creating backup: $e');
      return false;
    }
  }
  
  /// Get or create the BPApp_Backups folder
  Future<String?> _getOrCreateBackupFolder() async {
    if (_driveApi == null) return null;
    
    try {
      // Search for existing backup folder
      final query = "name = 'BPApp_Backups' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final response = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name)',
      );
      
      if (response.files != null && response.files!.isNotEmpty) {
        final folderId = response.files!.first.id!;
        debugPrint('✅ [BACKUP] Found existing backup folder: $folderId');
        return folderId;
      }
      
      // Create new backup folder
      final folder = drive.File()
        ..name = 'BPApp_Backups'
        ..mimeType = 'application/vnd.google-apps.folder'
        ..description = 'גיבויים של BPApp';
      
      final created = await _driveApi!.files.create(
        folder,
        $fields: 'id',
      );
      
      debugPrint('✅ [BACKUP] Created backup folder: ${created.id}');
      return created.id;
    } catch (e) {
      debugPrint('❌ [BACKUP] Error with folder: $e');
      return null;
    }
  }
  
  /// Clean old backups, keeping only the most recent ones
  Future<void> _cleanOldBackups(int maxBackups) async {
    if (_driveApi == null || _backupFolderId == null) return;
    
    try {
      // List all backup files in the folder
      final query = "'$_backupFolderId' in parents and name contains 'BPApp_Backup' and trashed = false";
      final response = await _driveApi!.files.list(
        q: query,
        orderBy: 'createdTime desc',
        $fields: 'files(id,name,createdTime)',
      );
      
      if (response.files == null || response.files!.length <= maxBackups) {
        return; // Nothing to clean
      }
      
      // Delete old backups
      final filesToDelete = response.files!.skip(maxBackups);
      for (final file in filesToDelete) {
        try {
          await _driveApi!.files.delete(file.id!);
          debugPrint('🗑️ [BACKUP] Deleted old backup: ${file.name}');
        } catch (e) {
          debugPrint('⚠️ [BACKUP] Failed to delete ${file.name}: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [BACKUP] Error cleaning old backups: $e');
    }
  }
  
  /// Get list of existing backups
  Future<List<BackupInfo>> getBackupList() async {
    if (!_isInitialized || _driveApi == null || _backupFolderId == null) {
      await initialize();
      if (!_isInitialized) return [];
    }
    
    try {
      final query = "'$_backupFolderId' in parents and name contains 'Backup' and trashed = false";
      final response = await _driveApi!.files.list(
        q: query,
        orderBy: 'createdTime desc',
        pageSize: 20,
        $fields: 'files(id,name,createdTime,size)',
      );
      
      if (response.files == null) return [];
      
      return response.files!.map((file) => BackupInfo(
        id: file.id!,
        name: file.name!,
        createdTime: file.createdTime ?? DateTime.now(),
        sizeBytes: int.tryParse(file.size ?? '0') ?? 0,
      )).toList();
    } catch (e) {
      debugPrint('❌ [BACKUP] Error getting backup list: $e');
      return [];
    }
  }
  
  /// Restore from a backup
  Future<bool> restoreFromBackup(String backupId, String targetSpreadsheetId) async {
    if (!_isInitialized || _driveApi == null) {
      await initialize();
      if (!_isInitialized) return false;
    }
    
    try {
      debugPrint('🔄 [BACKUP] Restoring from backup $backupId...');
      
      // This would require more complex logic to copy data from backup to target
      // For now, we'll just note that the user can open the backup directly
      
      _setError('לשחזור, פתח את הגיבוי ישירות מ-Google Drive');
      return false;
    } catch (e) {
      _setError('שגיאה בשחזור: $e');
      return false;
    }
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}

/// Information about a backup file
class BackupInfo {
  final String id;
  final String name;
  final DateTime createdTime;
  final int sizeBytes;
  
  BackupInfo({
    required this.id,
    required this.name,
    required this.createdTime,
    required this.sizeBytes,
  });
  
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdTime);
    
    if (diff.inMinutes < 60) return 'לפני ${diff.inMinutes} דקות';
    if (diff.inHours < 24) return 'לפני ${diff.inHours} שעות';
    if (diff.inDays < 7) return 'לפני ${diff.inDays} ימים';
    
    return '${createdTime.day}/${createdTime.month}/${createdTime.year}';
  }
}
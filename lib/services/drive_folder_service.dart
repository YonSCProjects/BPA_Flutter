import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Service for managing Google Drive folders for BPApp
/// Ensures all BPApp spreadsheets are organized in a dedicated folder
class DriveFolderService {
  static const String bpAppFolderName = 'BPApp';

  // Global singleton to ensure only ONE folder across all services
  static String? _globalFolderId;
  static bool _isCreatingFolder = false;
  static Future<String?>? _globalPendingOperation;
  static final Map<String, DriveFolderService> _instances = {};

  drive.DriveApi _driveApi;  // Made non-final to allow updates
  final String _driveApiKey;  // Unique key for this DriveApi instance
  String? _bpAppFolderId;

  // Private constructor for singleton pattern
  DriveFolderService._(this._driveApi, this._driveApiKey);

  // Factory constructor to ensure single instance per DriveApi
  factory DriveFolderService(drive.DriveApi driveApi) {
    // Create a unique key for this DriveApi instance
    final key = driveApi.hashCode.toString();

    // Return existing instance if available
    if (_instances.containsKey(key)) {
      final existing = _instances[key]!;
      existing._driveApi = driveApi;  // Update the API reference

      // If we have a global folder ID, use it
      if (_globalFolderId != null) {
        existing._bpAppFolderId = _globalFolderId;
      }

      return existing;
    }

    // Create new instance
    final instance = DriveFolderService._(driveApi, key);

    // If we have a global folder ID, use it
    if (_globalFolderId != null) {
      instance._bpAppFolderId = _globalFolderId;
      debugPrint('📁 [FOLDER] New instance using global folder: $_globalFolderId');
    }

    _instances[key] = instance;
    return instance;
  }

  /// Get or create the BPApp folder in the user's My Drive
  Future<String?> ensureBPAppFolder() async {
    try {
      // First check global folder ID
      if (_globalFolderId != null) {
        if (await _verifyFolderExists(_globalFolderId!)) {
          debugPrint('📁 [FOLDER] Using global folder ID: $_globalFolderId');
          _bpAppFolderId = _globalFolderId;
          return _globalFolderId;
        } else {
          debugPrint('⚠️ [FOLDER] Global folder no longer exists');
          _globalFolderId = null;
        }
      }

      // Then check local cached folder ID
      if (_bpAppFolderId != null && _bpAppFolderId != _globalFolderId) {
        if (await _verifyFolderExists(_bpAppFolderId!)) {
          debugPrint('📁 [FOLDER] Using cached folder ID: $_bpAppFolderId');
          _globalFolderId = _bpAppFolderId;  // Update global
          return _bpAppFolderId;
        } else {
          debugPrint('⚠️ [FOLDER] Cached folder no longer exists');
          _bpAppFolderId = null;
        }
      }

      // Check if there's already a global pending operation
      if (_globalPendingOperation != null) {
        debugPrint('⏳ [FOLDER] Waiting for global pending folder operation...');
        final result = await _globalPendingOperation!;
        _bpAppFolderId = result;
        _globalFolderId = result;
        return result;
      }

      // Create a new global pending operation
      _globalPendingOperation = _ensureFolderInternal();

      try {
        final result = await _globalPendingOperation!;
        _bpAppFolderId = result;
        _globalFolderId = result;  // Update global
        return result;
      } finally {
        _globalPendingOperation = null;
      }
    } catch (e) {
      debugPrint('❌ [FOLDER] Error ensuring BPApp folder: $e');
      return null;
    }
  }

  /// Internal method to ensure folder exists
  Future<String?> _ensureFolderInternal() async {
    debugPrint('📁 [FOLDER] ========== FOLDER OPERATION START ==========');
    debugPrint('📁 [FOLDER] Called by API key: $_driveApiKey');
    debugPrint('📁 [FOLDER] Current global folder: $_globalFolderId');
    debugPrint('📁 [FOLDER] Ensuring BPApp folder exists in My Drive');

    // First, try to find ALL existing folders (in case of duplicates)
    final existingFolders = await _findAllBPAppFolders();

    if (existingFolders.isNotEmpty) {
      // Use the first folder and log if there are duplicates
      _bpAppFolderId = existingFolders.first.id;

      if (existingFolders.length > 1) {
        debugPrint('⚠️ [FOLDER] Found ${existingFolders.length} BPApp folders! Using first: $_bpAppFolderId');
        debugPrint('📁 [FOLDER] Duplicate folder IDs: ${existingFolders.map((f) => f.id).join(", ")}');

        // Automatically clean up duplicates in the background
        debugPrint('🧹 [FOLDER] Starting automatic cleanup of duplicate folders...');
        cleanupDuplicateFolders().then((_) {
          debugPrint('✅ [FOLDER] Background cleanup completed');
        }).catchError((e) {
          debugPrint('❌ [FOLDER] Background cleanup failed: $e');
        });
      } else {
        debugPrint('✅ [FOLDER] Found existing BPApp folder: $_bpAppFolderId');
      }

      return _bpAppFolderId;
    }

    // Check if folder was deleted (in trash)
    _bpAppFolderId = await checkAndRecoverFolder();

    if (_bpAppFolderId == null) {
      // Prevent race condition during folder creation
      if (_isCreatingFolder) {
        debugPrint('⏳ [FOLDER] Another folder creation in progress, waiting...');
        await Future.delayed(Duration(seconds: 2));
        // Try finding again after wait
        final folders = await _findAllBPAppFolders();
        if (folders.isNotEmpty) {
          _bpAppFolderId = folders.first.id;
          debugPrint('✅ [FOLDER] Found folder after waiting: $_bpAppFolderId');
          return _bpAppFolderId;
        }
      }

      // Create new folder if not found anywhere
      _isCreatingFolder = true;
      try {
        _bpAppFolderId = await _createBPAppFolder();
      } finally {
        _isCreatingFolder = false;
      }
    }

    debugPrint('📁 [FOLDER] BPApp folder ready: $_bpAppFolderId');
    debugPrint('📁 [FOLDER] ========== FOLDER OPERATION END ==========');
    return _bpAppFolderId;
  }

  /// Find ALL existing BPApp folders in My Drive (to detect duplicates)
  Future<List<drive.File>> _findAllBPAppFolders() async {
    try {
      debugPrint('🔍 [FOLDER] Searching for ALL BPApp folders');

      // Search for folders with name "BPApp" in My Drive (not in trash)
      final response = await _driveApi.files.list(
        q: "name='$bpAppFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false and 'root' in parents",
        spaces: 'drive',
        $fields: 'files(id,name,parents,createdTime)',
        orderBy: 'createdTime',  // Order by creation time to use the oldest
      );

      if (response.files != null && response.files!.isNotEmpty) {
        debugPrint('📁 [FOLDER] Found ${response.files!.length} BPApp folder(s)');
        return response.files!;
      }

      debugPrint('ℹ️ [FOLDER] No existing BPApp folders found');
      return [];
    } catch (e) {
      debugPrint('❌ [FOLDER] Error finding BPApp folders: $e');
      return [];
    }
  }

  /// Verify if a folder still exists
  Future<bool> _verifyFolderExists(String folderId) async {
    try {
      final file = await _driveApi.files.get(
        folderId,
        $fields: 'id,trashed',
      );

      final trashed = (file as drive.File).trashed ?? false;
      return !trashed;
    } catch (e) {
      debugPrint('⚠️ [FOLDER] Folder verification failed: $e');
      return false;
    }
  }

  /// Create new BPApp folder in My Drive
  Future<String?> _createBPAppFolder() async {
    try {
      debugPrint('📝 [FOLDER] === CREATING FOLDER ===');
      debugPrint('📝 [FOLDER] Creator API key: $_driveApiKey');

      // Double-check one more time before creating (in case of race condition)
      final existingFolders = await _findAllBPAppFolders();
      if (existingFolders.isNotEmpty) {
        debugPrint('✅ [FOLDER] Found folder during final check: ${existingFolders.first.id}');
        _globalFolderId = existingFolders.first.id;
        return existingFolders.first.id;
      }

      debugPrint('📝 [FOLDER] No existing folders found, creating new BPApp folder in My Drive');

      final folder = drive.File()
        ..name = bpAppFolderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = ['root']; // Create in root of My Drive

      final createdFolder = await _driveApi.files.create(
        folder,
        $fields: 'id,name',
      );

      debugPrint('✅ [FOLDER] Created BPApp folder: ${createdFolder.id}');
      return createdFolder.id;
    } catch (e) {
      // Check if error is due to duplicate creation
      if (e.toString().contains('already exists')) {
        debugPrint('⚠️ [FOLDER] Folder already exists, searching again...');
        final folders = await _findAllBPAppFolders();
        if (folders.isNotEmpty) {
          return folders.first.id;
        }
      }

      debugPrint('❌ [FOLDER] Error creating BPApp folder: $e');
      return null;
    }
  }

  /// Check if folder was deleted and recover from trash if needed
  Future<String?> checkAndRecoverFolder() async {
    try {
      debugPrint('🔍 [FOLDER] Checking for BPApp folder in trash');

      // Search for the folder in trash
      final response = await _driveApi.files.list(
        q: "name='$bpAppFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=true",
        spaces: 'drive',
        orderBy: 'modifiedTime desc',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        final trashedFolder = response.files!.first;
        debugPrint('📁 [FOLDER] Found BPApp folder in trash: ${trashedFolder.id}');

        // Recover from trash
        final fileUpdate = drive.File()..trashed = false;

        await _driveApi.files.update(
          fileUpdate,
          trashedFolder.id!,
        );

        debugPrint('✅ [FOLDER] Recovered BPApp folder from trash');
        return trashedFolder.id;
      }

      return null;
    } catch (e) {
      debugPrint('❌ [FOLDER] Error checking/recovering folder: $e');
      return null;
    }
  }

  /// Search for BPApp spreadsheets in the folder
  Future<List<drive.File>> findSpreadsheetsInFolder(String spreadsheetName, {String? userEmail}) async {
    try {
      if (_bpAppFolderId == null) {
        _bpAppFolderId = await ensureBPAppFolder();
      }

      if (_bpAppFolderId == null) {
        debugPrint('⚠️ [FOLDER] Cannot search - no folder available');
        return [];
      }

      debugPrint('🔍 [FOLDER] Searching for "$spreadsheetName" in BPApp folder');
      if (userEmail != null && userEmail.isNotEmpty) {
        debugPrint('🔍 [FOLDER] Filtering by owner: $userEmail');
      }

      // Build basic query without ownership filter (we'll filter after fetching)
      // The 'in owners' query doesn't work reliably with email addresses in Drive API v3
      String query = "name='$spreadsheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false and '$_bpAppFolderId' in parents";

      // Search for spreadsheets with specific name in BPApp folder
      final response = await _driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,name,parents,owners(emailAddress,displayName))',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        debugPrint('✅ [FOLDER] Found ${response.files!.length} total spreadsheet(s) in folder');

        // Debug: Print all found spreadsheets with their owners
        for (final file in response.files!) {
          debugPrint('📋 [FOLDER] Spreadsheet: ${file.id}');
          if (file.owners != null && file.owners!.isNotEmpty) {
            for (final owner in file.owners!) {
              debugPrint('   👤 Owner: ${owner.emailAddress} (${owner.displayName})');
            }
          }
        }

        // If userEmail was provided, filter by ownership
        if (userEmail != null && userEmail.isNotEmpty) {
          final ownedFiles = response.files!.where((file) {
            // Check if the user owns this file
            final isOwned = file.owners?.any((owner) =>
              owner.emailAddress?.toLowerCase() == userEmail.toLowerCase()
            ) ?? false;

            if (isOwned) {
              debugPrint('✅ [FOLDER] Spreadsheet ${file.id} IS owned by $userEmail');
            } else {
              debugPrint('❌ [FOLDER] Spreadsheet ${file.id} is NOT owned by $userEmail');
            }

            return isOwned;
          }).toList();

          debugPrint('📊 [FOLDER] Final result: Found ${ownedFiles.length} spreadsheet(s) owned by $userEmail');

          if (ownedFiles.isEmpty && response.files!.isNotEmpty) {
            debugPrint('⚠️ [FOLDER] WARNING: Found spreadsheets but none owned by $userEmail');
            debugPrint('⚠️ [FOLDER] This might cause a new spreadsheet to be created');
          }

          return ownedFiles;
        }

        return response.files!;
      }

      debugPrint('ℹ️ [FOLDER] No spreadsheets found in folder');
      return [];
    } catch (e) {
      debugPrint('❌ [FOLDER] Error searching in folder: $e');
      return [];
    }
  }

  /// Search for legacy spreadsheets in root (for backward compatibility)
  Future<List<drive.File>> findLegacySpreadsheetsInRoot(String spreadsheetName, String userEmail) async {
    try {
      debugPrint('🔍 [FOLDER] Searching for legacy "$spreadsheetName" in root');

      // Search for spreadsheets owned by user in root
      final response = await _driveApi.files.list(
        q: "name='$spreadsheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false and 'root' in parents and '$userEmail' in owners",
        spaces: 'drive',
        $fields: 'files(id,name,parents,owners)',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        debugPrint('📋 [FOLDER] Found ${response.files!.length} legacy spreadsheet(s) in root');
        return response.files!;
      }

      debugPrint('ℹ️ [FOLDER] No legacy spreadsheets found in root');
      return [];
    } catch (e) {
      debugPrint('❌ [FOLDER] Error searching for legacy sheets: $e');
      return [];
    }
  }

  /// Move an existing spreadsheet to the BPApp folder
  Future<bool> moveSpreadsheetToFolder(String spreadsheetId) async {
    try {
      if (_bpAppFolderId == null) {
        _bpAppFolderId = await ensureBPAppFolder();
      }

      if (_bpAppFolderId == null) {
        debugPrint('⚠️ [FOLDER] Cannot move spreadsheet - no folder available');
        return false;
      }

      debugPrint('📁 [FOLDER] Moving spreadsheet $spreadsheetId to BPApp folder');

      // Get current parents
      final file = await _driveApi.files.get(
        spreadsheetId,
        $fields: 'parents',
      );

      final previousParents = (file as drive.File).parents?.join(',') ?? '';

      // Move to BPApp folder
      await _driveApi.files.update(
        drive.File(),
        spreadsheetId,
        addParents: _bpAppFolderId,
        removeParents: previousParents.isNotEmpty ? previousParents : null,
        $fields: 'id,parents',
      );

      debugPrint('✅ [FOLDER] Moved spreadsheet to BPApp folder');
      return true;
    } catch (e) {
      debugPrint('❌ [FOLDER] Error moving spreadsheet: $e');
      return false;
    }
  }

  String? get bpAppFolderId => _bpAppFolderId;

  /// Clean up duplicate BPApp folders (keeps the oldest one)
  Future<void> cleanupDuplicateFolders() async {
    try {
      final folders = await _findAllBPAppFolders();

      if (folders.length <= 1) {
        debugPrint('✅ [FOLDER] No duplicate folders to clean up');
        return;
      }

      debugPrint('🧹 [FOLDER] Found ${folders.length} BPApp folders, cleaning up duplicates...');

      // Keep the first folder (oldest due to orderBy: 'createdTime')
      final keepFolder = folders.first;
      debugPrint('📁 [FOLDER] Keeping folder: ${keepFolder.id} (oldest)');

      // Check contents of each duplicate folder before deletion
      for (int i = 1; i < folders.length; i++) {
        final duplicateFolder = folders[i];
        debugPrint('🔍 [FOLDER] Checking duplicate folder: ${duplicateFolder.id}');

        // Check if the duplicate folder has any files
        final contents = await _driveApi.files.list(
          q: "'${duplicateFolder.id}' in parents and trashed=false",
          spaces: 'drive',
          $fields: 'files(id,name)',
        );

        if (contents.files != null && contents.files!.isNotEmpty) {
          debugPrint('⚠️ [FOLDER] Duplicate folder ${duplicateFolder.id} has ${contents.files!.length} files');
          debugPrint('📦 [FOLDER] Moving contents to main folder...');

          // Move all files from duplicate to main folder
          for (final file in contents.files!) {
            try {
              await _driveApi.files.update(
                drive.File(),
                file.id!,
                addParents: keepFolder.id,
                removeParents: duplicateFolder.id,
                $fields: 'id,parents',
              );
              debugPrint('✅ [FOLDER] Moved file: ${file.name}');
            } catch (e) {
              debugPrint('❌ [FOLDER] Failed to move file ${file.name}: $e');
            }
          }
        } else {
          debugPrint('📭 [FOLDER] Duplicate folder ${duplicateFolder.id} is empty');
        }

        // Delete the duplicate folder
        try {
          await _driveApi.files.delete(duplicateFolder.id!);
          debugPrint('🗑️ [FOLDER] Deleted duplicate folder: ${duplicateFolder.id}');
        } catch (e) {
          debugPrint('❌ [FOLDER] Failed to delete duplicate folder: $e');
        }
      }

      debugPrint('✅ [FOLDER] Cleanup complete, kept folder: ${keepFolder.id}');
    } catch (e) {
      debugPrint('❌ [FOLDER] Error cleaning up duplicate folders: $e');
    }
  }
}
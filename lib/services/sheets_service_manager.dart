import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/student_record.dart';
import '../data/models/autocomplete_data.dart';
import 'google_sheets_service.dart';
import 'google_auth_service.dart';
import 'backend_sheets_service.dart';

/// Service manager that controls which sheets service to use
/// This provides a single interface for the app while allowing
/// switching between the original and backend implementations
class SheetsServiceManager extends ChangeNotifier {
  static const String _backendEnabledKey = 'backend_sheets_enabled';
  
  // Singleton instance
  static final SheetsServiceManager _instance = SheetsServiceManager._internal();
  factory SheetsServiceManager() => _instance;
  SheetsServiceManager._internal();
  
  // Services
  late final GoogleSheetsService _originalService;
  late final BackendSheetsService _backendService;
  
  // Auth service reference
  GoogleAuthService? _authService;
  
  // Current configuration
  bool _useBackend = false;
  bool _initialized = false;
  
  /// Set the auth service (must be called before initialize)
  void setAuthService(GoogleAuthService authService) {
    _authService = authService;
    _originalService = GoogleSheetsService(authService);
    _backendService = BackendSheetsService(authService);
    
    // Forward change notifications from the active service
    _originalService.addListener(_forwardNotification);
  }
  
  /// Forward notifications from underlying services to UI
  void _forwardNotification() {
    notifyListeners();
  }
  
  /// Initialize the service manager
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Make sure auth service is set
    if (_authService == null) {
      throw Exception('Auth service must be set before initializing SheetsServiceManager');
    }
    
    // Load preference from storage
    final prefs = await SharedPreferences.getInstance();
    _useBackend = prefs.getBool(_backendEnabledKey) ?? true; // Default to ENABLED
    
    // Initialize the appropriate service
    debugPrint('SheetsServiceManager: _useBackend=$_useBackend, backendService.isEnabled=${_backendService.isEnabled}');
    if (_useBackend && _backendService.isEnabled) {
      debugPrint('SheetsServiceManager: Using backend service');
      await _backendService.initialize();
    } else {
      debugPrint('SheetsServiceManager: Using original service (backend disabled or unavailable)');
      await _originalService.initialize();
    }
    
    _initialized = true;
  }
  
  /// Enable or disable backend service
  Future<void> setBackendEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backendEnabledKey, enabled);
    _useBackend = enabled;
    
    // Reinitialize with new service
    _initialized = false;
    await initialize();
  }
  
  /// Check if backend service is enabled
  bool get isBackendEnabled => _useBackend && _backendService.isEnabled;
  
  /// Get the active service name for UI display
  String get activeServiceName => isBackendEnabled ? 'Backend Service' : 'Direct Google Sheets';
  
  /// Save a student record using the active service
  Future<bool> saveRecord(StudentRecord record) async {
    if (!_initialized) await initialize();
    
    if (isBackendEnabled) {
      return await _backendService.saveRecord(record);
    } else {
      return await _originalService.saveRecord(record);
    }
  }
  
  /// Find matching record
  Future<StudentRecord?> findMatchingRecord(StudentRecord record) async {
    if (!_initialized) await initialize();
    
    if (isBackendEnabled) {
      // Backend service would convert this to Map
      final result = await _backendService.findMatchingRecord(
        record.date, 
        record.studentName, 
        record.className, 
        record.classNumber,
      );
      if (result != null) {
        // Convert map back to StudentRecord
        return StudentRecord(
          date: record.date,
          studentName: record.studentName,
          className: record.className,
          classNumber: record.classNumber,
          entry: result['entry'] ?? 0,
          staying: result['staying'] ?? 0,
          attitude: result['attitude'] ?? 0,
          performance: result['performance'] ?? 0,
          personalGoal: result['personalGoal'] ?? 0,
          bonus: result['bonus'] ?? 0,
          comments: result['comments'] ?? '',
          totalScore: result['totalScore'] ?? 0,
        );
      }
      return null;
    } else {
      return await _originalService.findMatchingRecord(record);
    }
  }
  
  
  /// Get user's spreadsheet URL (if available)
  String? get userSpreadsheetUrl {
    if (isBackendEnabled) {
      return _backendService.userSpreadsheetUrl;
    }
    // Original service doesn't expose URL directly
    return null;
  }
  
  /// Check if service has valid authentication
  Future<bool> hasValidAuth() async {
    if (!_initialized) await initialize();
    
    if (isBackendEnabled) {
      return await _backendService.hasValidAuth();
    } else {
      // GoogleSheetsService doesn't have hasValidToken, check via auth service
      return await _authService?.hasValidToken() ?? false;
    }
  }
  
  /// Sync pending local records
  Future<void> syncPendingRecords() async {
    if (!_initialized) await initialize();
    
    // Both services can sync pending records
    if (isBackendEnabled) {
      await _backendService.syncPendingRecords();
    } else {
      await _originalService.syncPendingRecords();
    }
  }
  
  /// Get sync status for UI display
  Future<Map<String, int>> getSyncStatus() async {
    // This always uses the original service since it manages local storage
    return await _originalService.getSyncStatus();
  }
  
  /// Get next class number for a date
  Future<int> getNextClassNumber(String date) async {
    if (!_initialized) await initialize();
    return await _originalService.getNextClassNumber(date);
  }
  
  /// Check if service is initialized
  bool get isInitialized => _initialized;
  
  /// Get student name suggestions
  List<String> Function(String) get getStudentSuggestions => _originalService.getStudentSuggestions;
  
  /// Get class name suggestions
  List<String> Function(String) get getClassSuggestions => _originalService.getClassSuggestions;
  
  /// Check if service is loading
  bool get isLoading {
    if (isBackendEnabled) {
      return false; // BackendSheetsService doesn't expose loading state
    } else {
      return _originalService.isLoading;
    }
  }
  
  /// Get service error
  String? get error {
    if (isBackendEnabled) {
      return null; // BackendSheetsService doesn't expose error state
    } else {
      return _originalService.error;
    }
  }
  
  /// Get recovery message
  String? get recoveryMessage => _originalService.recoveryMessage;
  
  /// Clear recovery message
  void clearRecoveryMessage() => _originalService.clearRecoveryMessage();
  
  /// Clear corrupted data from spreadsheet
  Future<void> clearCorruptedData() async {
    if (!_initialized) await initialize();
    
    // Only the original service has the cleanup method
    await _originalService.clearCorruptedData();
  }
}
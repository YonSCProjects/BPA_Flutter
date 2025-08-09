import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../data/models/student_record.dart';
import '../data/models/autocomplete_data.dart';
import 'google_sheets_service.dart';
import 'google_auth_service.dart';

/// Backend service for centralized Google Sheets management
/// Works in parallel with existing GoogleSheetsService
/// Falls back to GoogleSheetsService if backend is unavailable
class BackendSheetsService {
  // Firebase Functions URL for bpapp-hebrew project
  static const String _backendUrl = 'https://us-central1-bpapp-hebrew.cloudfunctions.net/api';
  
  // Feature flag to enable/disable backend service
  static const bool _useBackendService = false; // TODO: Fix method signatures first
  
  // Fallback to existing service
  late final GoogleSheetsService _fallbackService;
  
  // Google Auth service for Firebase tokens
  final GoogleAuthService _authService;
  
  // Cache for user spreadsheet URL
  String? _userSpreadsheetUrl;
  
  BackendSheetsService(this._authService) {
    _fallbackService = GoogleSheetsService(_authService);
  }
  
  /// Check if backend service is enabled
  bool get isEnabled => _useBackendService;
  
  /// Initialize the service
  Future<void> initialize() async {
    if (!_useBackendService) {
      // Use existing service
      await _fallbackService.initialize();
      return;
    }
    
    try {
      // Setup user spreadsheet on backend
      await _setupUserSpreadsheet();
      
      // Fallback initialization in case backend setup fails
    } catch (e) {
      debugPrint('Backend initialization failed, using fallback: $e');
      await _fallbackService.initialize();
    }
  }
  
  /// Get current user's ID token for authentication
  Future<String?> _getIdToken() async {
    try {
      return await _authService.getFirebaseIdToken();
    } catch (e) {
      debugPrint('Failed to get ID token: $e');
      return null;
    }
  }
  
  /// Setup user spreadsheet on backend
  Future<void> _setupUserSpreadsheet() async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }
    
    final userEmail = _authService.getUserEmail();
    if (userEmail == null) {
      throw Exception('User email not available');
    }
    
    final response = await http.post(
      Uri.parse('$_backendUrl/setup-user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userEmail': userEmail,
      }),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Backend timeout'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _userSpreadsheetUrl = data['spreadsheetUrl'];
      debugPrint('User spreadsheet setup successful: $_userSpreadsheetUrl');
    } else {
      throw Exception('Backend setup failed: ${response.statusCode}');
    }
  }
  
  /// Save a student record
  Future<bool> saveRecord(StudentRecord record) async {
    if (!_useBackendService) {
      return await _fallbackService.saveRecord(record);
    }
    
    try {
      final token = await _getIdToken();
      if (token == null) {
        debugPrint('No auth token, falling back to existing service');
        return await _fallbackService.saveRecord(record);
      }
      
      final userEmail = _authService.getUserEmail();
      if (userEmail == null) {
        return await _fallbackService.saveRecord(record);
      }
      
      final response = await http.post(
        Uri.parse('$_backendUrl/save-record'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userEmail': userEmail,
          'record': {
            'date': record.date,
            'studentName': record.studentName,
            'className': record.className,
            'classNumber': record.classNumber,
            'entry': record.entry,
            'staying': record.staying,
            'attitude': record.attitude,
            'performance': record.performance,
            'personalGoal': record.personalGoal,
            'bonus': record.bonus,
            'totalScore': record.totalScore,
            'comments': record.comments,
          },
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Save timeout'),
      );
      
      if (response.statusCode == 200) {
        debugPrint('Record saved via backend successfully');
        return true;
      } else {
        debugPrint('Backend save failed: ${response.statusCode}, falling back');
        return await _fallbackService.saveRecord(record);
      }
    } catch (e) {
      debugPrint('Backend save error, using fallback: $e');
      return await _fallbackService.saveRecord(record);
    }
  }
  
  /// Find matching record using 4-field combination
  Future<Map<String, dynamic>?> findMatchingRecord(
    String date,
    String studentName,
    String className,
    int classNumber,
  ) async {
    if (!_useBackendService) {
      // Convert to StudentRecord for fallback service
      final record = StudentRecord(
        date: date,
        studentName: studentName,
        className: className,
        classNumber: classNumber,
        entry: 0,
        staying: 0,
        attitude: 0,
        performance: 0,
        personalGoal: 0,
        bonus: 0,
        comments: '',
        totalScore: 0,
      );
      final result = await _fallbackService.findMatchingRecord(record);
      if (result != null) {
        return {
          'entry': result.entry,
          'staying': result.staying,
          'attitude': result.attitude,
          'performance': result.performance,
          'personalGoal': result.personalGoal,
          'bonus': result.bonus,
          'comments': result.comments,
        };
      }
      return null;
    }
    
    try {
      final token = await _getIdToken();
      if (token == null) {
        // Convert to StudentRecord for fallback service
        final record = StudentRecord(
          date: date,
          studentName: studentName,
          className: className,
          classNumber: classNumber,
          entry: 0,
          staying: 0,
          attitude: 0,
          performance: 0,
          personalGoal: 0,
          bonus: 0,
          comments: '',
          totalScore: 0,
        );
        final result = await _fallbackService.findMatchingRecord(record);
        if (result != null) {
          return {
            'entry': result.entry,
            'staying': result.staying,
            'attitude': result.attitude,
            'performance': result.performance,
            'personalGoal': result.personalGoal,
            'bonus': result.bonus,
            'comments': result.comments,
          };
        }
        return null;
      }
      
      final userEmail = _authService.getUserEmail();
      if (userEmail == null) {
        // Convert to StudentRecord for fallback service
        final record = StudentRecord(
          date: date,
          studentName: studentName,
          className: className,
          classNumber: classNumber,
          entry: 0,
          staying: 0,
          attitude: 0,
          performance: 0,
          personalGoal: 0,
          bonus: 0,
          comments: '',
          totalScore: 0,
        );
        final result = await _fallbackService.findMatchingRecord(record);
        if (result != null) {
          return {
            'entry': result.entry,
            'staying': result.staying,
            'attitude': result.attitude,
            'performance': result.performance,
            'personalGoal': result.personalGoal,
            'bonus': result.bonus,
            'comments': result.comments,
          };
        }
        return null;
      }
      
      final response = await http.post(
        Uri.parse('$_backendUrl/find-record'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userEmail': userEmail,
          'matchFields': {
            'date': date,
            'studentName': studentName,
            'className': className,
            'classNumber': classNumber,
          },
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Find timeout'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['found'] == true) {
          return data['data'];
        }
        return null;
      } else {
        // Convert to StudentRecord for fallback service
        final record = StudentRecord(
          date: date,
          studentName: studentName,
          className: className,
          classNumber: classNumber,
          entry: 0,
          staying: 0,
          attitude: 0,
          performance: 0,
          personalGoal: 0,
          bonus: 0,
          comments: '',
          totalScore: 0,
        );
        final result = await _fallbackService.findMatchingRecord(record);
        if (result != null) {
          return {
            'entry': result.entry,
            'staying': result.staying,
            'attitude': result.attitude,
            'performance': result.performance,
            'personalGoal': result.personalGoal,
            'bonus': result.bonus,
            'comments': result.comments,
          };
        }
        return null;
      }
    } catch (e) {
      debugPrint('Backend find error, using fallback: $e');
      // Convert to StudentRecord for fallback service
      final record = StudentRecord(
        date: date,
        studentName: studentName,
        className: className,
        classNumber: classNumber,
        entry: 0,
        staying: 0,
        attitude: 0,
        performance: 0,
        personalGoal: 0,
        bonus: 0,
        comments: '',
        totalScore: 0,
      );
      final result = await _fallbackService.findMatchingRecord(record);
      if (result != null) {
        return {
          'entry': result.entry,
          'staying': result.staying,
          'attitude': result.attitude,
          'performance': result.performance,
          'personalGoal': result.personalGoal,
          'bonus': result.bonus,
          'comments': result.comments,
        };
      }
      return null;
    }
  }
  
  /* TODO: Fix these methods after getting basic app working
  /// Fetch autocomplete data
  Future<AutocompleteData> fetchAutocompleteData() async {
    if (!_useBackendService) {
      return await _fallbackService.fetchAutocompleteData();
    }
    
    try {
      final token = await _getIdToken();
      if (token == null) {
        return await _fallbackService.fetchAutocompleteData();
      }
      
      final userEmail = _authService.getUserEmail();
      if (userEmail == null) {
        return await _fallbackService.fetchAutocompleteData();
      }
      
      final response = await http.get(
        Uri.parse('$_backendUrl/autocomplete-data?userEmail=${user!.email}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Autocomplete timeout'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AutocompleteData(
          studentNames: List<String>.from(data['studentNames'] ?? []),
          classNames: List<String>.from(data['classNames'] ?? []),
        );
      } else {
        return await _fallbackService.fetchAutocompleteData();
      }
    } catch (e) {
      debugPrint('Backend autocomplete error, using fallback: $e');
      return await _fallbackService.fetchAutocompleteData();
    }
  }
  
  */
  
  /// Get user's spreadsheet URL
  String? get userSpreadsheetUrl {
    if (!_useBackendService) {
      // For existing service, construct URL from known spreadsheet ID
      // This would need to be stored/retrieved from the existing service
      return null;
    }
    return _userSpreadsheetUrl;
  }
  
  /// Check if service has valid authentication
  Future<bool> hasValidAuth() async {
    if (!_useBackendService) {
      return await _authService.hasValidToken();
    }
    
    final token = await _getIdToken();
    return token != null;
  }
  
  /// Sync pending local records (delegates to appropriate service)
  Future<void> syncPendingRecords() async {
    // This always uses the fallback service since local storage is managed there
    await _fallbackService.syncPendingRecords();
  }
}
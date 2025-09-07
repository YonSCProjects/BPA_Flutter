import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/firebase_data_service.dart';

/// Configuration for mapping class names to educator emails
/// 
/// In the school system:
/// - Classes are named after their educator (e.g., "מחנך א")
/// - Educators are also teachers who use the app
/// - When other teachers record data for students in an educator's class,
///   the data is also saved to that educator's spreadsheet
/// - When educators record their own students, data saves only once
class EducatorMappings {
  static Map<String, String> _classToEducator = {};
  static bool _isInitialized = false;
  
  /// Initialize mappings from Firebase and shared preferences
  static Future<void> initialize({FirebaseDataService? firebaseService}) async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final mappingsJson = prefs.getString('educator_mappings');
    
    // Load mappings from shared preferences first
    if (mappingsJson != null) {
      _classToEducator = Map<String, String>.from(json.decode(mappingsJson));
    }
    
    // Try to load from Firebase if service is provided and initialized
    if (firebaseService != null && firebaseService.isInitialized) {
      try {
        await _loadFromFirebase(firebaseService);
        // Save updated mappings to preferences
        await prefs.setString('educator_mappings', json.encode(_classToEducator));
        print('[EDUCATOR_MAPPINGS] Loaded ${_classToEducator.length} mappings from Firebase');
      } catch (e) {
        print('[EDUCATOR_MAPPINGS] Error loading from Firebase: $e');
        // Continue with cached/empty mappings
      }
    } else {
      print('[EDUCATOR_MAPPINGS] Firebase service not available, using cached mappings');
    }
    
    _isInitialized = true;
  }
  
  /// Load educator mappings from Firebase data
  static Future<void> _loadFromFirebase(FirebaseDataService firebaseService) async {
    final educators = firebaseService.getCachedEducators();
    
    // Clear existing mappings and rebuild from Firebase
    _classToEducator.clear();
    
    // Map educator names to their emails
    for (final educator in educators) {
      if (educator.name.isNotEmpty && educator.email.isNotEmpty && educator.active) {
        _classToEducator[educator.name] = educator.email;
        print('[EDUCATOR_MAPPINGS] Mapped "${educator.name}" -> "${educator.email}"');
      }
    }
  }
  
  /// Get educator email for a given class name
  static String? getEducatorEmail(String className) {
    if (className.isEmpty) return null;
    // Ensure we're initialized
    if (!_isInitialized) {
      // In async context, should call initialize() first
      // For sync context, return null if not initialized
      return null;
    }
    return _classToEducator[className.trim()];
  }
  
  /// Check if a class has an associated educator
  static bool hasEducator(String className) {
    return getEducatorEmail(className) != null;
  }
  
  /// Get all educator emails (unique)
  static Set<String> getAllEducatorEmails() {
    return _classToEducator.values.toSet();
  }
  
  /// Get all class names that have educators
  static Set<String> getClassesWithEducators() {
    return _classToEducator.keys.toSet();
  }
  
  /// Update mappings (used by settings page)
  static Future<void> updateMappings(Map<String, String> newMappings) async {
    _classToEducator = Map<String, String>.from(newMappings);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('educator_mappings', json.encode(_classToEducator));
  }
  
  /// Get current mappings
  static Map<String, String> getMappings() {
    return Map<String, String>.from(_classToEducator);
  }
}
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Configuration for mapping class names to educator emails
/// Each class name is associated with an educator who receives copies of records
class EducatorMappings {
  static Map<String, String> _classToEducator = {};
  static bool _isInitialized = false;
  
  /// Initialize mappings from shared preferences
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final mappingsJson = prefs.getString('educator_mappings');
    
    if (mappingsJson != null) {
      _classToEducator = Map<String, String>.from(json.decode(mappingsJson));
    }
    
    _isInitialized = true;
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
/// Application configuration and feature flags
/// 
/// This file controls enterprise features rollout safely
/// All flags default to false for backward compatibility
class AppConfig {
  // ===== ENTERPRISE FEATURES FLAGS =====
  
  /// Service Account Integration (Phase 1)
  /// When true: Uses service account for centralized spreadsheet management
  /// When false: Uses existing OAuth flow
  static const bool useServiceAccount = true;
  
  /// Firebase Backend Integration (Phase 2)
  /// When true: Fetches students/educators from Firebase
  /// When false: Uses existing text input fields
  static const bool useFirebaseBackend = true;
  
  /// Dynamic Dropdowns (Phase 3) 
  /// When true: Shows Firebase-powered dropdowns for students/classes
  /// When false: Uses existing Hebrew text fields
  static const bool useFirebaseDropdowns = true;
  
  // ===== EXISTING FEATURES (Keep Working) =====
  
  /// Offline-first storage (already implemented and working)
  static const bool offlineFirstEnabled = true;
  
  /// Multi-destination sheets (already working)
  static const bool multiDestinationEnabled = true;
  
  // ===== DEVELOPMENT & DEBUG =====
  
  /// Enable debug logging for enterprise features
  static const bool debugEnterpriseFeatures = true;
  
  /// Firebase project configuration (DO NOT CHANGE)
  static const String firebaseProjectId = 'bpapp-firebase-485c1';
  
  // ===== ROLLBACK SAFETY =====
  
  /// Emergency disable for all enterprise features
  /// Set to true to immediately disable all new features
  static const bool emergencyDisable = false;
  
  // ===== HELPER METHODS =====
  
  /// Check if any enterprise feature is enabled
  static bool get hasAnyEnterpriseFeature => 
    !emergencyDisable && (useServiceAccount || useFirebaseBackend || useFirebaseDropdowns);
  
  /// Check if we should show enterprise UI elements
  static bool get showEnterpriseUI => hasAnyEnterpriseFeature;
  
  /// Get configuration summary for debugging
  static Map<String, dynamic> get configSummary => {
    'serviceAccount': useServiceAccount && !emergencyDisable,
    'firebaseBackend': useFirebaseBackend && !emergencyDisable,
    'firebaseDropdowns': useFirebaseDropdowns && !emergencyDisable,
    'offlineFirst': offlineFirstEnabled,
    'multiDestination': multiDestinationEnabled,
    'emergencyDisable': emergencyDisable,
    'firebaseProject': firebaseProjectId,
  };
  
  /// Log current configuration (for debugging)
  static void logConfig() {
    if (debugEnterpriseFeatures) {
      print('🚀 [CONFIG] BPApp Configuration:');
      configSummary.forEach((key, value) {
        print('   $key: $value');
      });
    }
  }
}
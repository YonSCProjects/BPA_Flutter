import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

/// Service to handle educator self-initialization
/// 
/// When an educator logs in for the first time and doesn't have a spreadsheetId,
/// this service will automatically update their Firestore document with the
/// spreadsheet ID created by the Google Sheets service.
class EducatorInitializationService {
  static const String _educatorsCollection = 'educators';
  static const String _usersCollection = 'users';
  static const String serviceAccountEmail = 'bpapp-service-account@bpapp-firebase-485c1.iam.gserviceaccount.com';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleAuthService? _authService;
  
  EducatorInitializationService([this._authService]);
  
  /// Check if current user is an educator and needs initialization
  Future<bool> checkAndInitializeEducator({
    required String userEmail,
    String? spreadsheetId,
  }) async {
    if (spreadsheetId == null || spreadsheetId.isEmpty) {
      debugPrint('[EDUCATOR_INIT] No spreadsheet ID to update');
      return false;
    }
    
    try {
      // First check educators collection
      final educatorQuery = await _firestore
          .collection(_educatorsCollection)
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      
      if (educatorQuery.docs.isNotEmpty) {
        final educatorDoc = educatorQuery.docs.first;
        final currentSpreadsheetId = educatorDoc.data()['spreadsheetId'];
        
        // Only update if spreadsheetId is missing or empty
        if (currentSpreadsheetId == null || currentSpreadsheetId.toString().isEmpty) {
          await _updateEducatorSpreadsheet(
            docId: educatorDoc.id,
            spreadsheetId: spreadsheetId,
            collection: _educatorsCollection,
          );
          
          // Also share the spreadsheet with service account
          await _shareWithServiceAccount(spreadsheetId);
          
          debugPrint('[EDUCATOR_INIT] ✅ Updated educator spreadsheet ID in educators collection');
          return true;
        } else {
          debugPrint('[EDUCATOR_INIT] Educator already has spreadsheet ID: $currentSpreadsheetId');
        }
      }
      
      // Also check users collection (for future migration)
      final userQuery = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: userEmail)
          .where('role', isEqualTo: 'educator')
          .limit(1)
          .get();
      
      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        final currentSpreadsheetId = userDoc.data()['spreadsheetId'];
        
        if (currentSpreadsheetId == null || currentSpreadsheetId.toString().isEmpty) {
          await _updateEducatorSpreadsheet(
            docId: userDoc.id,
            spreadsheetId: spreadsheetId,
            collection: _usersCollection,
          );
          
          // Also share the spreadsheet with service account
          await _shareWithServiceAccount(spreadsheetId);
          
          debugPrint('[EDUCATOR_INIT] ✅ Updated educator spreadsheet ID in users collection');
          return true;
        }
      }
      
      debugPrint('[EDUCATOR_INIT] User is not an educator or already initialized');
      return false;
      
    } catch (e) {
      debugPrint('[EDUCATOR_INIT] ❌ Error checking/updating educator: $e');
      return false;
    }
  }
  
  /// Update educator document with spreadsheet ID
  Future<void> _updateEducatorSpreadsheet({
    required String docId,
    required String spreadsheetId,
    required String collection,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(docId)
          .update({
            'spreadsheetId': spreadsheetId,
            'updatedAt': FieldValue.serverTimestamp(),
            'autoInitialized': true, // Flag to track auto-initialization
          });
      
      debugPrint('[EDUCATOR_INIT] Successfully updated $collection/$docId with spreadsheet ID: $spreadsheetId');
    } catch (e) {
      debugPrint('[EDUCATOR_INIT] Failed to update educator spreadsheet: $e');
      throw e;
    }
  }
  
  /// Get educator's spreadsheet ID if they have one
  Future<String?> getEducatorSpreadsheetId(String userEmail) async {
    try {
      // Check educators collection first
      final educatorQuery = await _firestore
          .collection(_educatorsCollection)
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      
      if (educatorQuery.docs.isNotEmpty) {
        final spreadsheetId = educatorQuery.docs.first.data()['spreadsheetId'];
        if (spreadsheetId != null && spreadsheetId.toString().isNotEmpty) {
          return spreadsheetId.toString();
        }
      }
      
      // Check users collection as fallback
      final userQuery = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: userEmail)
          .where('role', isEqualTo: 'educator')
          .limit(1)
          .get();
      
      if (userQuery.docs.isNotEmpty) {
        final spreadsheetId = userQuery.docs.first.data()['spreadsheetId'];
        if (spreadsheetId != null && spreadsheetId.toString().isNotEmpty) {
          return spreadsheetId.toString();
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('[EDUCATOR_INIT] Error getting educator spreadsheet ID: $e');
      return null;
    }
  }
  
  /// Share the spreadsheet with service account as editor
  Future<void> _shareWithServiceAccount(String spreadsheetId) async {
    if (_authService == null) {
      debugPrint('[EDUCATOR_INIT] Cannot share - no auth service available');
      return;
    }
    
    try {
      debugPrint('[EDUCATOR_INIT] 🔗 Sharing spreadsheet with service account...');
      
      final client = await _authService!.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[EDUCATOR_INIT] ❌ No authenticated client for sharing');
        return;
      }
      
      final driveApi = drive.DriveApi(client);
      
      // Check if service account already has access
      try {
        final currentPerms = await driveApi.permissions.list(spreadsheetId);
        if (currentPerms.permissions != null) {
          for (final perm in currentPerms.permissions!) {
            if (perm.emailAddress == serviceAccountEmail) {
              debugPrint('[EDUCATOR_INIT] ✅ Service account already has access');
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('[EDUCATOR_INIT] ⚠️ Could not check permissions: $e');
      }
      
      // Create permission for service account
      final permission = drive.Permission()
        ..type = 'user'
        ..role = 'writer'
        ..emailAddress = serviceAccountEmail;
      
      await driveApi.permissions.create(
        permission,
        spreadsheetId,
        sendNotificationEmail: false,
      );
      
      debugPrint('[EDUCATOR_INIT] ✅ Successfully shared spreadsheet with service account');
      
    } catch (e) {
      debugPrint('[EDUCATOR_INIT] ❌ Error sharing with service account: $e');
      // Don't throw - this is not critical for the main flow
    }
  }
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

class GoogleAuthService extends ChangeNotifier {
  static const String _userInfoKey = 'google_user_info';
  
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    // Web OAuth client ID from Firebase project (client_type: 3)
    serverClientId: '579440030749-4hs2mhr7egcafqok2looja0vqditnodp.apps.googleusercontent.com',
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  GoogleSignInAccount? _currentUser;
  User? _firebaseUser;
  bool _isLoading = false;
  String? _error;

  GoogleSignInAccount? get currentUser => _currentUser;
  User? get firebaseUser => _firebaseUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<String?> getFirebaseIdToken() async {
    debugPrint('[AUTH] getFirebaseIdToken called - firebaseUser: ${_firebaseUser?.email ?? "NULL"}');
    
    // Check if Firebase user exists
    if (_firebaseUser == null) {
      debugPrint('[AUTH] No Firebase user found, checking FirebaseAuth instance...');
      
      // Try to get current user from FirebaseAuth instance
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        debugPrint('[AUTH] Found Firebase user in instance: ${currentUser.email}');
        _firebaseUser = currentUser;
      } else {
        debugPrint('[AUTH] No Firebase user in instance either');
        return null;
      }
    }
    
    try {
      // Force token refresh to ensure it's valid
      final token = await _firebaseUser!.getIdToken(true);
      debugPrint('[AUTH] Firebase ID token obtained successfully');
      return token;
    } catch (e) {
      debugPrint('[AUTH] Failed to get Firebase ID token: $e');
      debugPrint('[AUTH] Error type: ${e.runtimeType}');
      
      // Clear invalid Firebase user
      _firebaseUser = null;
      return null;
    }
  }

  GoogleAuthService() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      debugPrint('[AUTH] onCurrentUserChanged fired: ${account?.email}');
      _currentUser = account;
      debugPrint('[AUTH] After listener update - isAuthenticated: $isAuthenticated');
      notifyListeners();
    });
  }

  Future<void> initialize() async {
    _setLoading(true);
    _setError(null);

    try {
      debugPrint('[AUTH] Starting initialization...');
      final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      debugPrint('[AUTH] Silent sign-in result: ${account?.email}');
      
      if (account != null) {
        _currentUser = account;
        debugPrint('[AUTH] Silent sign-in successful: ${account.email}');
        debugPrint('[AUTH] After silent sign-in - isAuthenticated: $isAuthenticated');
        
        // Verify token is valid
        final hasValidToken = await this.hasValidToken();
        debugPrint('[AUTH] Token validation result: $hasValidToken');
        
        if (!hasValidToken) {
          debugPrint('[AUTH] Token invalid, clearing current user');
          _currentUser = null;
        }
      } else {
        debugPrint('[AUTH] No cached account found');
      }
    } catch (e) {
      _setError('שגיאה באתחול השירות: ${e.toString()}');
      debugPrint('[AUTH] GoogleAuthService initialization error: $e');
    } finally {
      _setLoading(false);
      debugPrint('[AUTH] Initialization complete - isAuthenticated: $isAuthenticated');
      notifyListeners(); // Single notification at the end
    }
  }

  Future<bool> signIn() async {
    debugPrint('[AUTH] Starting sign-in process...');
    debugPrint('[AUTH] Current user before sign-in: $_currentUser');
    
    _setLoading(true);
    _setError(null);

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      debugPrint('[AUTH] Sign-in returned account: ${account?.email}');
      
      if (account == null) {
        debugPrint('[AUTH] Sign-in cancelled by user');
        _setError('ההתחברות בוטלה על ידי המשתמש');
        return false;
      }

      _currentUser = account;
      debugPrint('[AUTH] Current user set to: ${_currentUser?.email}');
      debugPrint('[AUTH] isAuthenticated: $isAuthenticated');
      
      // Sign in to Firebase with Google credentials
      await _signInToFirebase(account);
      
      await _storeUserInfo();
      notifyListeners(); // Notify UI of authentication state change
      
      debugPrint('[AUTH] Google Sign-In successful for: ${account.email}');
      debugPrint('[AUTH] Firebase user: ${_firebaseUser?.email}');
      debugPrint('[AUTH] Final isAuthenticated: $isAuthenticated');
      return true;
    } catch (e) {
      _setError('שגיאה בהתחברות: ${e.toString()}');
      debugPrint('[AUTH] Google Sign-In error: $e');
      debugPrint('[AUTH] Error type: ${e.runtimeType}');
      if (e.toString().contains('ApiException')) {
        debugPrint('[AUTH] This is an ApiException - likely a configuration issue');
        debugPrint('[AUTH] Check: 1) OAuth client exists 2) SHA-1 matches 3) App is in test users');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _setError(null);

    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      _currentUser = null;
      _firebaseUser = null;
      await _clearStoredCredentials();
      notifyListeners(); // Notify UI of authentication state change
      
      debugPrint('Google Sign-Out successful');
    } catch (e) {
      _setError('שגיאה בהתנתקות: ${e.toString()}');
      debugPrint('Google Sign-Out error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<http.Client?> getAuthenticatedClient() async {
    if (!isAuthenticated) {
      _setError('לא מחובר - נדרשת התחברות מחדש');
      return null;
    }

    try {
      final GoogleSignInAuthentication auth = await _currentUser!.authentication;
      
      return GoogleAuthClient(auth.accessToken!);
    } catch (e) {
      _setError('שגיאה ביצירת חיבור מאומת: ${e.toString()}');
      debugPrint('Authenticated client error: $e');
      return null;
    }
  }

  Future<sheets.SheetsApi?> getSheetsApi() async {
    final client = await getAuthenticatedClient();
    if (client == null) return null;

    return sheets.SheetsApi(client);
  }

  Future<void> _signInToFirebase(GoogleSignInAccount account) async {
    try {
      debugPrint('[AUTH] Starting Firebase sign-in for: ${account.email}');
      
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      debugPrint('[AUTH] Got Google auth tokens - accessToken: ${googleAuth.accessToken != null ? "FOUND" : "NULL"}, idToken: ${googleAuth.idToken != null ? "FOUND" : "NULL"}');
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('[AUTH] Missing required tokens for Firebase Auth');
        return;
      }
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      debugPrint('[AUTH] Created Firebase credential');
      
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      _firebaseUser = userCredential.user;
      
      debugPrint('[AUTH] Firebase sign-in successful: ${_firebaseUser?.email}');
      debugPrint('[AUTH] Firebase user ID: ${_firebaseUser?.uid}');
    } catch (e, stackTrace) {
      debugPrint('[AUTH] Firebase sign-in error: $e');
      debugPrint('[AUTH] Stack trace: $stackTrace');
      debugPrint('[AUTH] Error type: ${e.runtimeType}');
      
      // Clear Firebase user on error
      _firebaseUser = null;
      
      // Don't fail the whole sign-in if Firebase fails - Google Sign-In still works
      debugPrint('[AUTH] Continuing with Google Sign-In only (Firebase disabled)');
    }
  }

  Future<void> _storeUserInfo() async {
    if (_currentUser == null) return;

    try {
      final userInfo = {
        'id': _currentUser!.id,
        'email': _currentUser!.email,
        'displayName': _currentUser!.displayName,
        'photoUrl': _currentUser!.photoUrl,
      };

      await _secureStorage.write(
        key: _userInfoKey,
        value: jsonEncode(userInfo),
      );

      debugPrint('User info stored securely');
    } catch (e) {
      debugPrint('Failed to store user info: $e');
    }
  }

  Future<void> _clearStoredCredentials() async {
    try {
      await _secureStorage.delete(key: _userInfoKey);
      debugPrint('Stored credentials cleared');
    } catch (e) {
      debugPrint('Failed to clear credentials: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<bool> hasValidToken() async {
    if (_currentUser == null) return false;
    
    try {
      final auth = await _currentUser!.authentication;
      return auth.accessToken != null;
    } catch (e) {
      return false;
    }
  }

  /// Get Google OAuth access token for API calls
  Future<String?> getAccessToken() async {
    if (_currentUser == null) return null;
    
    try {
      final auth = await _currentUser!.authentication;
      return auth.accessToken;
    } catch (e) {
      debugPrint('[AUTH] Failed to get access token: $e');
      return null;
    }
  }

  String? getUserEmail() {
    return _currentUser?.email;
  }

  String? getUserDisplayName() {
    return _currentUser?.displayName;
  }
}

class GoogleAuthClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
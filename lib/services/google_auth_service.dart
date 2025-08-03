import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    // serverClientId is only for mobile platforms, not web
    serverClientId: kIsWeb ? null : '302221962392-fpgmic64q39baml2nfnqkhc586n5r6me.apps.googleusercontent.com',
    // For web, we need to specify the client ID
    clientId: kIsWeb ? '302221962392-fpgmic64q39baml2nfnqkhc586n5r6me.apps.googleusercontent.com' : null,
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  GoogleSignInAccount? _currentUser;
  bool _isLoading = false;
  String? _error;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  GoogleAuthService() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
      notifyListeners();
    });
  }

  Future<void> initialize() async {
    _setLoading(true);
    _setError(null);

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        debugPrint('Silent sign-in successful: ${account.email}');
      }
    } catch (e) {
      _setError('שגיאה באתחול השירות: ${e.toString()}');
      debugPrint('GoogleAuthService initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn() async {
    _setLoading(true);
    _setError(null);

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        _setError('ההתחברות בוטלה על ידי המשתמש');
        return false;
      }

      _currentUser = account;
      await _storeUserInfo();
      
      debugPrint('Google Sign-In successful for: ${account.email}');
      return true;
    } catch (e) {
      _setError('שגיאה בהתחברות: ${e.toString()}');
      debugPrint('Google Sign-In error: $e');
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
      _currentUser = null;
      await _clearStoredCredentials();
      
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
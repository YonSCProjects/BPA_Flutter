import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

/// Custom JWT authentication for service account with user impersonation
/// This is required for domain-wide delegation to work properly
class ServiceAccountJWTAuth {
  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const int _expirySeconds = 3600; // 1 hour
  
  /// Create JWT and exchange for access token with impersonation
  static Future<AccessToken> getAccessToken({
    required Map<String, dynamic> serviceAccountJson,
    required List<String> scopes,
    required String impersonatedUser, // The user to impersonate (if domain-wide delegation is enabled)
  }) async {
    final String clientEmail = serviceAccountJson['client_email'];
    final String privateKeyPem = serviceAccountJson['private_key'];
    
    // Create JWT with impersonation claim
    final jwt = JWT(
      {
        'iss': clientEmail, // Service account email
        'sub': impersonatedUser, // User to impersonate - THIS IS THE KEY!
        'scope': scopes.join(' '),
        'aud': _tokenUrl,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + _expirySeconds,
      },
    );
    
    // Sign JWT with private key
    final key = RSAPrivateKey(privateKeyPem);
    final token = jwt.sign(key, algorithm: JWTAlgorithm.RS256);
    
    // Exchange JWT for access token
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': token,
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get access token: ${response.body}');
    }
    
    final data = json.decode(response.body);
    final accessToken = data['access_token'] as String;
    final expiresIn = data['expires_in'] as int;
    
    return AccessToken(
      'Bearer',
      accessToken,
      DateTime.now().add(Duration(seconds: expiresIn)).toUtc(),
    );
  }
  
  /// Create authenticated HTTP client with impersonation
  static Future<AuthClient> createImpersonatedClient({
    required Map<String, dynamic> serviceAccountJson,
    required List<String> scopes,
    required String impersonatedUser,
  }) async {
    final accessToken = await getAccessToken(
      serviceAccountJson: serviceAccountJson,
      scopes: scopes,
      impersonatedUser: impersonatedUser,
    );
    
    return _ImpersonatedAuthClient(
      baseClient: http.Client(),
      credentials: AccessCredentials(
        accessToken,
        null, // No refresh token
        scopes,
      ),
      serviceAccountJson: serviceAccountJson,
      impersonatedUser: impersonatedUser,
    );
  }
}

/// Custom AuthClient that handles token refresh with impersonation
class _ImpersonatedAuthClient extends http.BaseClient implements AuthClient {
  final http.Client _baseClient;
  AccessCredentials _credentials;
  final Map<String, dynamic> _serviceAccountJson;
  final String _impersonatedUser;
  
  _ImpersonatedAuthClient({
    required http.Client baseClient,
    required AccessCredentials credentials,
    required Map<String, dynamic> serviceAccountJson,
    required String impersonatedUser,
  })  : _baseClient = baseClient,
        _credentials = credentials,
        _serviceAccountJson = serviceAccountJson,
        _impersonatedUser = impersonatedUser;
  
  @override
  AccessCredentials get credentials => _credentials;
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Check if token expired and refresh if needed
    if (_credentials.accessToken.expiry.isBefore(DateTime.now().toUtc())) {
      await _refreshToken();
    }
    
    // Add authorization header
    request.headers['Authorization'] = 
        '${_credentials.accessToken.type} ${_credentials.accessToken.data}';
    
    return _baseClient.send(request);
  }
  
  Future<void> _refreshToken() async {
    final newToken = await ServiceAccountJWTAuth.getAccessToken(
      serviceAccountJson: _serviceAccountJson,
      scopes: _credentials.scopes,
      impersonatedUser: _impersonatedUser,
    );
    
    _credentials = AccessCredentials(
      newToken,
      _credentials.refreshToken,
      _credentials.scopes,
    );
  }
  
  @override
  void close() {
    _baseClient.close();
  }
}
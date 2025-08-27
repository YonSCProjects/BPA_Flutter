import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Firebase Data Service for Enterprise Features
/// 
/// Manages educators and students data from Firestore.
/// Only active when AppConfig.useFirebaseBackend = true
class FirebaseDataService extends ChangeNotifier {
  static const String _educatorsCollection = 'educators';
  static const String _studentsCollection = 'students';
  static const String _configCollection = 'config';
  
  // Firestore instance
  FirebaseFirestore? _firestore;
  
  // Cache for offline usage
  List<EducatorData> _cachedEducators = [];
  List<StudentData> _cachedStudents = [];
  DateTime? _lastCacheUpdate;
  
  // State management
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEnabled => AppConfig.useFirebaseBackend && !AppConfig.emergencyDisable;
  List<EducatorData> get cachedEducators => _cachedEducators;
  List<StudentData> get cachedStudents => _cachedStudents;
  
  /// Initialize Firebase connection
  Future<bool> initialize() async {
    if (!isEnabled) {
      _logDebug('Firebase backend disabled in config - skipping initialization');
      return false;
    }
    
    _setLoading(true);
    _setError(null);
    
    try {
      _logDebug('Starting Firebase data service initialization...');
      
      _firestore = FirebaseFirestore.instance;
      
      // Enable offline persistence
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // Test connection and load initial data
      await _loadInitialData();
      
      _isInitialized = true;
      _logDebug('Firebase data service initialization successful');
      return true;
      
    } catch (e) {
      _setError('שגיאה באתחול שירות Firebase: ${e.toString()}');
      _logDebug('Firebase data service initialization failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Load initial educators and students data
  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadEducators(),
        _loadStudents(),
      ]);
      
      _lastCacheUpdate = DateTime.now();
      _logDebug('Initial data loaded - ${_cachedEducators.length} educators, ${_cachedStudents.length} students');
      
    } catch (e) {
      _logDebug('Error loading initial data: $e');
      throw e;
    }
  }
  
  /// Load educators from Firestore
  Future<void> _loadEducators() async {
    if (_firestore == null) return;
    
    try {
      final snapshot = await _firestore!
          .collection(_educatorsCollection)
          .where('active', isEqualTo: true)
          .orderBy('name')
          .get();
      
      _cachedEducators = snapshot.docs
          .map((doc) => EducatorData.fromFirestore(doc))
          .toList();
      
      _logDebug('Loaded ${_cachedEducators.length} educators');
      
    } catch (e) {
      _logDebug('Error loading educators: $e');
      throw e;
    }
  }
  
  /// Load students from Firestore
  Future<void> _loadStudents() async {
    if (_firestore == null) return;
    
    try {
      final snapshot = await _firestore!
          .collection(_studentsCollection)
          .where('active', isEqualTo: true)
          .orderBy('educatorName')
          .orderBy('name')
          .get();
      
      _cachedStudents = snapshot.docs
          .map((doc) => StudentData.fromFirestore(doc))
          .toList();
      
      _logDebug('Loaded ${_cachedStudents.length} students');
      
    } catch (e) {
      _logDebug('Error loading students: $e');
      throw e;
    }
  }
  
  /// Get educators stream for real-time updates
  Stream<List<EducatorData>> getEducatorsStream() {
    if (!_isInitialized || _firestore == null) {
      return Stream.value(_cachedEducators);
    }
    
    return _firestore!
        .collection(_educatorsCollection)
        .where('active', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final educators = snapshot.docs
          .map((doc) => EducatorData.fromFirestore(doc))
          .toList();
      
      // Update cache
      _cachedEducators = educators;
      return educators;
    });
  }
  
  /// Get students stream for specific educator
  Stream<List<StudentData>> getStudentsForEducatorStream(String educatorId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.value(_cachedStudents.where((s) => s.educatorId == educatorId).toList());
    }
    
    return _firestore!
        .collection(_studentsCollection)
        .where('educatorId', isEqualTo: educatorId)
        .where('active', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => StudentData.fromFirestore(doc))
          .toList();
    });
  }
  
  /// Get all students stream
  Stream<List<StudentData>> getAllStudentsStream() {
    if (!_isInitialized || _firestore == null) {
      return Stream.value(_cachedStudents);
    }
    
    return _firestore!
        .collection(_studentsCollection)
        .where('active', isEqualTo: true)
        .orderBy('educatorName')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final students = snapshot.docs
          .map((doc) => StudentData.fromFirestore(doc))
          .toList();
      
      // Update cache
      _cachedStudents = students;
      return students;
    });
  }
  
  /// Get cached educators (for offline usage)
  List<EducatorData> getCachedEducators() {
    return List.from(_cachedEducators);
  }
  
  /// Get cached students for educator (for offline usage)
  List<StudentData> getCachedStudentsForEducator(String educatorId) {
    return _cachedStudents.where((student) => student.educatorId == educatorId).toList();
  }
  
  /// Get educator by ID
  EducatorData? getEducatorById(String educatorId) {
    try {
      return _cachedEducators.firstWhere((educator) => educator.id == educatorId);
    } catch (e) {
      return null;
    }
  }
  
  /// Get student by ID
  StudentData? getStudentById(String studentId) {
    try {
      return _cachedStudents.firstWhere((student) => student.id == studentId);
    } catch (e) {
      return null;
    }
  }
  
  /// Refresh cache manually
  Future<void> refreshCache() async {
    if (!_isInitialized) return;
    
    _setLoading(true);
    try {
      await _loadInitialData();
      notifyListeners();
    } catch (e) {
      _setError('שגיאה ברענון הנתונים: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Health check for Firebase connection
  Future<bool> healthCheck() async {
    if (!_isInitialized || _firestore == null) return false;
    
    try {
      await _firestore!.collection(_configCollection).limit(1).get();
      return true;
    } catch (e) {
      _logDebug('Firebase health check failed: $e');
      return false;
    }
  }
  
  /// Get cache age in minutes
  int getCacheAgeMinutes() {
    if (_lastCacheUpdate == null) return -1;
    return DateTime.now().difference(_lastCacheUpdate!).inMinutes;
  }
  
  // ===== HELPER METHODS =====
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  void _logDebug(String message) {
    if (AppConfig.debugEnterpriseFeatures) {
      debugPrint('[FIREBASE_DATA] $message');
    }
  }
}

/// Data models for Firestore entities

class EducatorData {
  final String id;
  final String name;
  final String email;
  final bool active;
  final DateTime createdAt;
  
  EducatorData({
    required this.id,
    required this.name,
    required this.email,
    required this.active,
    required this.createdAt,
  });
  
  factory EducatorData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EducatorData(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      active: data['active'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
  
  @override
  String toString() {
    return 'EducatorData(id: $id, name: $name, email: $email, active: $active)';
  }
}

class StudentData {
  final String id;
  final String name;
  final String educatorId;
  final String educatorName;
  final bool active;
  final DateTime createdAt;
  final String? grade;
  final String? notes;
  
  StudentData({
    required this.id,
    required this.name,
    required this.educatorId,
    required this.educatorName,
    required this.active,
    required this.createdAt,
    this.grade,
    this.notes,
  });
  
  factory StudentData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentData(
      id: doc.id,
      name: data['name'] ?? '',
      educatorId: data['educatorId'] ?? '',
      educatorName: data['educatorName'] ?? '',
      active: data['active'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      grade: data['grade'],
      notes: data['notes'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'educatorId': educatorId,
      'educatorName': educatorName,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'grade': grade,
      'notes': notes,
    };
  }
  
  @override
  String toString() {
    return 'StudentData(id: $id, name: $name, educatorName: $educatorName, active: $active)';
  }
}
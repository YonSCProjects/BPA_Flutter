import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../data/models/student_record.dart';

enum SyncStatus {
  pending('pending'),
  synced('synced'),
  failed('failed');
  
  const SyncStatus(this.value);
  final String value;
  
  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere((e) => e.value == value);
  }
}

class LocalStudentRecord extends StudentRecord {
  final int? localId;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final int retryCount;

  const LocalStudentRecord({
    this.localId,
    required this.syncStatus,
    required this.createdAt,
    this.syncedAt,
    this.retryCount = 0,
    required super.date,
    required super.studentName,
    required super.className,
    required super.classNumber,
    required super.entry,
    required super.staying,
    required super.attitude,
    required super.performance,
    required super.personalGoal,
    required super.bonus,
    required super.comments,
    required super.totalScore,
  });

  factory LocalStudentRecord.fromStudentRecord(
    StudentRecord record, {
    int? localId,
    SyncStatus syncStatus = SyncStatus.pending,
    DateTime? createdAt,
    DateTime? syncedAt,
    int retryCount = 0,
  }) {
    return LocalStudentRecord(
      localId: localId,
      syncStatus: syncStatus,
      createdAt: createdAt ?? DateTime.now(),
      syncedAt: syncedAt,
      retryCount: retryCount,
      date: record.date,
      studentName: record.studentName,
      className: record.className,
      classNumber: record.classNumber,
      entry: record.entry,
      staying: record.staying,
      attitude: record.attitude,
      performance: record.performance,
      personalGoal: record.personalGoal,
      bonus: record.bonus,
      comments: record.comments,
      totalScore: record.totalScore,
    );
  }

  LocalStudentRecord copyWithSyncStatus({
    SyncStatus? syncStatus,
    DateTime? syncedAt,
    int? retryCount,
  }) {
    return LocalStudentRecord(
      localId: localId,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      retryCount: retryCount ?? this.retryCount,
      date: date,
      studentName: studentName,
      className: className,
      classNumber: classNumber,
      entry: entry,
      staying: staying,
      attitude: attitude,
      performance: performance,
      personalGoal: personalGoal,
      bonus: bonus,
      comments: comments,
      totalScore: totalScore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': localId,
      'date': date,
      'student_name': studentName,
      'class_name': className,
      'class_number': classNumber,
      'entry': entry,
      'staying': staying,
      'attitude': attitude,
      'performance': performance,
      'personal_goal': personalGoal,
      'bonus': bonus,
      'total_score': totalScore,
      'comments': comments,
      'sync_status': syncStatus.value,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory LocalStudentRecord.fromMap(Map<String, dynamic> map) {
    return LocalStudentRecord(
      localId: map['id'] as int?,
      date: map['date'] as String,
      studentName: map['student_name'] as String,
      className: map['class_name'] as String,
      classNumber: map['class_number'] as int,
      entry: map['entry'] as int,
      staying: map['staying'] as int,
      attitude: map['attitude'] as int,
      performance: map['performance'] as int,
      personalGoal: map['personal_goal'] as int,
      bonus: map['bonus'] as int,
      totalScore: map['total_score'] as int,
      comments: map['comments'] as String,
      syncStatus: SyncStatus.fromString(map['sync_status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      syncedAt: map['synced_at'] != null 
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      retryCount: map['retry_count'] as int,
    );
  }
}

class LocalStorageService extends ChangeNotifier {
  static const String _dbName = 'bpapp_local.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'student_records';
  
  Database? _database;
  bool _isInitialized = false;
  
  // Feature flag for safe rollback
  static const bool _offlineStorageEnabled = true;
  
  bool get isEnabled => _offlineStorageEnabled;
  bool get isInitialized => _isInitialized;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> initialize() async {
    if (!_offlineStorageEnabled) {
      debugPrint('🗄️ [LOCAL] Offline storage disabled by feature flag');
      return;
    }

    try {
      await database; // This will initialize the database
      _isInitialized = true;
      debugPrint('🗄️ [LOCAL] LocalStorageService initialized successfully');
    } catch (e) {
      debugPrint('❌ [LOCAL] Failed to initialize LocalStorageService: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _dbName);

    debugPrint('🗄️ [LOCAL] Initializing SQLite database at: $path');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('🗄️ [LOCAL] Creating student_records table');
    
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        student_name TEXT NOT NULL,
        class_name TEXT NOT NULL,
        class_number INTEGER NOT NULL,
        entry INTEGER NOT NULL,
        staying INTEGER NOT NULL,
        attitude INTEGER NOT NULL,
        performance INTEGER NOT NULL,
        personal_goal INTEGER NOT NULL,
        bonus INTEGER NOT NULL,
        total_score INTEGER NOT NULL,
        comments TEXT,
        sync_status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        synced_at TEXT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // Create indices for efficient queries
    await db.execute('''
      CREATE INDEX idx_sync_status ON $_tableName(sync_status)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_created_at ON $_tableName(created_at)
    ''');

    // Create unique index for the 4-field combination (same as spreadsheet matching)
    await db.execute('''
      CREATE INDEX idx_record_key ON $_tableName(date, student_name, class_name, class_number)
    ''');

    debugPrint('✅ [LOCAL] Database schema created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🗄️ [LOCAL] Upgrading database from $oldVersion to $newVersion');
    // Future database migrations will go here
  }

  /// Save a record locally (always succeeds unless database error)
  Future<LocalStudentRecord> saveRecord(StudentRecord record) async {
    if (!_offlineStorageEnabled || !_isInitialized) {
      throw Exception('Local storage not available');
    }

    try {
      final db = await database;
      final localRecord = LocalStudentRecord.fromStudentRecord(record);
      
      debugPrint('💾 [LOCAL] Saving record locally: ${record.getMatchingKey()}');
      
      // Check if record already exists locally (same matching logic as Google Sheets)
      final existingRecord = await _findLocalRecord(record);
      
      if (existingRecord != null) {
        // Update existing local record
        final updatedRecord = LocalStudentRecord.fromStudentRecord(
          record,
          localId: existingRecord.localId,
          syncStatus: SyncStatus.pending, // Reset to pending when updated
          createdAt: existingRecord.createdAt,
          retryCount: 0, // Reset retry count
        );
        
        await db.update(
          _tableName,
          updatedRecord.toMap(),
          where: 'id = ?',
          whereArgs: [existingRecord.localId],
        );
        
        debugPrint('✅ [LOCAL] Updated existing local record ID: ${existingRecord.localId}');
        return updatedRecord;
      } else {
        // Insert new local record
        final id = await db.insert(_tableName, localRecord.toMap());
        
        debugPrint('✅ [LOCAL] Saved new local record ID: $id');
        return LocalStudentRecord.fromStudentRecord(
          record,
          localId: id,
          syncStatus: SyncStatus.pending,
          createdAt: localRecord.createdAt,
        );
      }
    } catch (e) {
      debugPrint('❌ [LOCAL] Error saving record locally: $e');
      rethrow;
    }
  }

  /// Find local record using same 4-field matching as Google Sheets
  Future<LocalStudentRecord?> _findLocalRecord(StudentRecord record) async {
    try {
      final db = await database;
      final results = await db.query(
        _tableName,
        where: 'date = ? AND student_name = ? AND class_name = ? AND class_number = ?',
        whereArgs: [record.date, record.studentName, record.className, record.classNumber],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return LocalStudentRecord.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [LOCAL] Error finding local record: $e');
      return null;
    }
  }

  /// Mark a record as successfully synced
  Future<void> markAsSynced(StudentRecord record) async {
    if (!_offlineStorageEnabled || !_isInitialized) return;

    try {
      final db = await database;
      final now = DateTime.now();
      
      await db.update(
        _tableName,
        {
          'sync_status': SyncStatus.synced.value,
          'synced_at': now.toIso8601String(),
        },
        where: 'date = ? AND student_name = ? AND class_name = ? AND class_number = ?',
        whereArgs: [record.date, record.studentName, record.className, record.classNumber],
      );
      
      debugPrint('✅ [LOCAL] Marked record as synced: ${record.getMatchingKey()}');
    } catch (e) {
      debugPrint('❌ [LOCAL] Error marking record as synced: $e');
    }
  }

  /// Mark a record as pending sync (after failed upload)
  Future<void> markAsPendingSync(StudentRecord record, {int? retryCount}) async {
    if (!_offlineStorageEnabled || !_isInitialized) return;

    try {
      final db = await database;
      
      await db.update(
        _tableName,
        {
          'sync_status': SyncStatus.pending.value,
          'retry_count': retryCount ?? 0,
        },
        where: 'date = ? AND student_name = ? AND class_name = ? AND class_number = ?',
        whereArgs: [record.date, record.studentName, record.className, record.classNumber],
      );
      
      debugPrint('⏳ [LOCAL] Marked record as pending sync: ${record.getMatchingKey()}');
    } catch (e) {
      debugPrint('❌ [LOCAL] Error marking record as pending: $e');
    }
  }

  /// Get all records that need to be synced
  Future<List<LocalStudentRecord>> getPendingRecords() async {
    if (!_offlineStorageEnabled || !_isInitialized) return [];

    try {
      final db = await database;
      final results = await db.query(
        _tableName,
        where: 'sync_status = ?',
        whereArgs: [SyncStatus.pending.value],
        orderBy: 'created_at ASC', // Sync in creation order
      );

      final records = results.map((map) => LocalStudentRecord.fromMap(map)).toList();
      debugPrint('🔄 [LOCAL] Found ${records.length} pending records to sync');
      return records;
    } catch (e) {
      debugPrint('❌ [LOCAL] Error getting pending records: $e');
      return [];
    }
  }

  /// Get count of records by sync status
  Future<Map<SyncStatus, int>> getSyncStatusCounts() async {
    if (!_offlineStorageEnabled || !_isInitialized) {
      return {for (var status in SyncStatus.values) status: 0};
    }

    try {
      final db = await database;
      final counts = <SyncStatus, int>{};
      
      for (final status in SyncStatus.values) {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $_tableName WHERE sync_status = ?',
          [status.value],
        );
        counts[status] = result.first['count'] as int;
      }
      
      return counts;
    } catch (e) {
      debugPrint('❌ [LOCAL] Error getting sync status counts: $e');
      return {for (var status in SyncStatus.values) status: 0};
    }
  }

  /// Increment retry count for failed sync
  Future<void> incrementRetryCount(LocalStudentRecord record) async {
    if (!_offlineStorageEnabled || !_isInitialized || record.localId == null) return;

    try {
      final db = await database;
      await db.update(
        _tableName,
        {
          'retry_count': record.retryCount + 1,
          'sync_status': SyncStatus.failed.value,
        },
        where: 'id = ?',
        whereArgs: [record.localId],
      );
    } catch (e) {
      debugPrint('❌ [LOCAL] Error incrementing retry count: $e');
    }
  }

  /// Clear old synced records (cleanup)
  Future<void> cleanupOldRecords({int daysToKeep = 30}) async {
    if (!_offlineStorageEnabled || !_isInitialized) return;

    try {
      final db = await database;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      final deletedCount = await db.delete(
        _tableName,
        where: 'sync_status = ? AND synced_at < ?',
        whereArgs: [SyncStatus.synced.value, cutoffDate.toIso8601String()],
      );
      
      debugPrint('🧹 [LOCAL] Cleaned up $deletedCount old synced records');
    } catch (e) {
      debugPrint('❌ [LOCAL] Error cleaning up old records: $e');
    }
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}
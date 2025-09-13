import 'package:flutter/foundation.dart';

import '../../data/models/student_record.dart';
import '../../services/google_sheets_service.dart';
import '../../services/multi_destination_sheets_service.dart';
import '../../services/google_auth_service.dart';

class FormProvider extends ChangeNotifier {
  StudentRecord _currentRecord = StudentRecord.empty();
  StudentRecord? _originalRecord;
  bool _isLoading = false;
  String? _error;
  bool _isUpdateMode = false;
  
  // Batch mode fields
  final List<StudentRecord> _pendingRecords = [];
  bool _isBatchMode = false;
  int _currentBatchIndex = -1; // -1 means editing new record
  StudentRecord? _removedRecord; // For undo functionality

  StudentRecord get currentRecord => _currentRecord;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUpdateMode => _isUpdateMode;
  
  // Batch mode getters
  List<StudentRecord> get pendingRecords => List.unmodifiable(_pendingRecords);
  bool get isBatchMode => _isBatchMode && _pendingRecords.isNotEmpty;
  int get pendingCount => _pendingRecords.length;
  bool get hasPendingRecords => _pendingRecords.isNotEmpty;
  int get currentBatchIndex => _currentBatchIndex;
  bool get isEditingPendingRecord => _currentBatchIndex >= 0;

  Future<void> initializeWithDefaults(GoogleSheetsService sheetsService) async {
    _setLoading(true);
    _setError(null);

    try {
      // Format today's date as DD/MM/YYYY
      final now = DateTime.now();
      final today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final nextClassNumber = await sheetsService.getNextClassNumber(today);
      
      _currentRecord = StudentRecord.empty().copyWith(
        date: today,
        classNumber: nextClassNumber,
      );
      
      _isUpdateMode = false;
      notifyListeners();
    } catch (e) {
      _setError('שגיאה באתחול הטופס: ${e.toString()}');
      debugPrint('Form initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  void updateField(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case 'date':
        _currentRecord = _currentRecord.copyWith(date: value as String);
        break;
      case 'studentName':
        _currentRecord = _currentRecord.copyWith(studentName: value as String);
        break;
      case 'className':
        _currentRecord = _currentRecord.copyWith(className: value as String);
        break;
      case 'classNumber':
        _currentRecord = _currentRecord.copyWith(classNumber: value as int);
        break;
      case 'entry':
        _currentRecord = _currentRecord.copyWith(entry: value as int);
        break;
      case 'staying':
        _currentRecord = _currentRecord.copyWith(staying: value as int);
        break;
      case 'attitude':
        _currentRecord = _currentRecord.copyWith(attitude: value as int);
        break;
      case 'performance':
        _currentRecord = _currentRecord.copyWith(performance: value as int);
        break;
      case 'personalGoal':
        _currentRecord = _currentRecord.copyWith(personalGoal: value as int);
        break;
      case 'bonus':
        _currentRecord = _currentRecord.copyWith(bonus: value as int);
        break;
      case 'comments':
        _currentRecord = _currentRecord.copyWith(comments: value as String);
        break;
    }
    notifyListeners();
  }

  bool canCheckForExistingRecord() {
    return _currentRecord.date.isNotEmpty &&
        _currentRecord.studentName.trim().isNotEmpty &&
        _currentRecord.className.trim().isNotEmpty &&
        _currentRecord.classNumber > 0;
  }

  Future<void> checkForExistingRecord(GoogleSheetsService sheetsService) async {
    if (!canCheckForExistingRecord()) {
      debugPrint('🔄 [FORM] Cannot check for existing record - missing required fields');
      return;
    }

    debugPrint('🔄 [FORM] Checking for existing record with current data...');

    try {
      final existingRecord = await sheetsService.findMatchingRecord(_currentRecord);
      
      if (existingRecord != null) {
        _originalRecord = existingRecord;
        
        // Only update the score fields, keep the key fields as user entered them
        _currentRecord = _currentRecord.copyWith(
          entry: existingRecord.entry,
          staying: existingRecord.staying,
          attitude: existingRecord.attitude,
          performance: existingRecord.performance,
          personalGoal: existingRecord.personalGoal,
          bonus: existingRecord.bonus,
          comments: existingRecord.comments,
          totalScore: existingRecord.totalScore,
        );
        
        _isUpdateMode = true;
        
        debugPrint('✅ [FORM] Found existing record, switched to UPDATE mode');
        debugPrint('✅ [FORM] Populated score fields from existing record');
      } else {
        _originalRecord = null;
        _isUpdateMode = false;
        
        debugPrint('🆕 [FORM] No existing record found, staying in CREATE mode');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [FORM] Error checking for existing record: $e');
    }
  }

  Future<bool> saveRecord(GoogleSheetsService sheetsService) async {
    _setLoading(true);
    _setError(null);

    try {
      // For classes 1 and 7, ensure personal goal is 0
      var recordToSave = _currentRecord;
      if (recordToSave.classNumber == 1 || recordToSave.classNumber == 7) {
        recordToSave = recordToSave.copyWith(personalGoal: 0);
      }
      recordToSave = recordToSave.withCalculatedScore();
      
      // Use multi-destination service with the required services
      final multiService = MultiDestinationSheetsService(
        sheetsService.authService,
        sheetsService,
      );
      
      // Initialize the service (including service account if enabled)
      _setError('אתחול שירות חשבון...');
      await multiService.initialize();
      _setError(null);
      
      // Use multi-destination service which handles both primary and educator sheets
      final success = await multiService.saveToMultipleDestinations(recordToSave);
      
      if (success) {
        debugPrint('Record saved successfully');
        return true;
      } else {
        _setError('שגיאה בשמירת הרשומה');
        return false;
      }
    } catch (e) {
      _setError('שגיאה בשמירת הרשומה: ${e.toString()}');
      debugPrint('Save record error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void resetForm({bool keepBatchData = false}) {
    // Format today's date as DD/MM/YYYY
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    
    if (keepBatchData && _currentRecord.className.isNotEmpty) {
      // Keep date, class name, and class number for batch mode
      _currentRecord = StudentRecord.empty().copyWith(
        date: _currentRecord.date.isNotEmpty ? _currentRecord.date : today,
        className: _currentRecord.className,
        classNumber: _currentRecord.classNumber,
      );
    } else {
      _currentRecord = StudentRecord.empty().copyWith(date: today);
    }
    
    _originalRecord = null;
    _isUpdateMode = false;
    _currentBatchIndex = -1;
    _setError(null);
    notifyListeners();
  }

  void restoreOriginal() {
    if (_originalRecord != null) {
      _currentRecord = _originalRecord!;
      notifyListeners();
    }
  }

  bool hasUnsavedChanges() {
    if (_originalRecord == null) {
      return !_isEmptyRecord(_currentRecord);
    }
    return _currentRecord != _originalRecord;
  }

  bool _isEmptyRecord(StudentRecord record) {
    final empty = StudentRecord.empty();
    return record.studentName.trim().isEmpty &&
        record.className.trim().isEmpty &&
        record.comments.trim().isEmpty &&
        record.entry == empty.entry &&
        record.staying == empty.staying &&
        record.attitude == empty.attitude &&
        record.performance == empty.performance &&
        record.personalGoal == empty.personalGoal &&
        record.bonus == empty.bonus;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // ===== BATCH MODE METHODS =====
  
  bool isCurrentRecordValid() {
    return _currentRecord.studentName.trim().isNotEmpty &&
           _currentRecord.className.trim().isNotEmpty &&
           _currentRecord.classNumber > 0;
  }
  
  Future<bool> addToQueueAndMoveNext() async {
    // Validate current record
    if (!isCurrentRecordValid()) {
      _setError('יש למלא את כל השדות הנדרשים');
      return false;
    }
    
    // Calculate score for classes 1 and 7
    var recordToAdd = _currentRecord;
    if (recordToAdd.classNumber == 1 || recordToAdd.classNumber == 7) {
      recordToAdd = recordToAdd.copyWith(personalGoal: 0);
    }
    recordToAdd = recordToAdd.withCalculatedScore();
    
    if (_currentBatchIndex == -1) {
      // New record - add to queue
      _pendingRecords.add(recordToAdd);
      debugPrint('[BATCH] Added new record to queue: ${recordToAdd.studentName}');
    } else {
      // Editing existing pending record - update it
      _pendingRecords[_currentBatchIndex] = recordToAdd;
      debugPrint('[BATCH] Updated pending record at index $_currentBatchIndex');
    }
    
    // Enter batch mode
    _isBatchMode = true;
    
    // Reset form keeping batch data
    resetForm(keepBatchData: true);
    
    return true;
  }
  
  Future<bool> saveBatchRecords(GoogleSheetsService sheetsService) async {
    // Check if we have anything to save
    if (_pendingRecords.isEmpty && !isCurrentRecordValid()) {
      _setError('אין רשומות לשמירה');
      return false;
    }
    
    _setLoading(true);
    _setError(null);
    
    try {
      // Add current record if valid
      final recordsToSave = List<StudentRecord>.from(_pendingRecords);
      if (isCurrentRecordValid()) {
        var currentToSave = _currentRecord;
        if (currentToSave.classNumber == 1 || currentToSave.classNumber == 7) {
          currentToSave = currentToSave.copyWith(personalGoal: 0);
        }
        recordsToSave.add(currentToSave.withCalculatedScore());
      }
      
      debugPrint('[BATCH] Saving ${recordsToSave.length} records...');
      
      // Initialize multi-destination service
      final multiService = MultiDestinationSheetsService(
        sheetsService.authService,
        sheetsService,
      );
      
      _setError('אתחול שירות חשבון...');
      await multiService.initialize();
      _setError(null);
      
      // Save all records
      int successCount = 0;
      final List<String> errors = [];
      
      for (int i = 0; i < recordsToSave.length; i++) {
        try {
          debugPrint('[BATCH] Saving record ${i + 1}/${recordsToSave.length}: ${recordsToSave[i].studentName}');
          final success = await multiService.saveToMultipleDestinations(recordsToSave[i]);
          
          if (success) {
            successCount++;
          } else {
            errors.add('${recordsToSave[i].studentName}: שגיאה בשמירה');
          }
        } catch (e) {
          errors.add('${recordsToSave[i].studentName}: $e');
          debugPrint('[BATCH] Error saving record: $e');
        }
      }
      
      // Handle results
      if (successCount > 0) {
        // Clear batch on any success
        _pendingRecords.clear();
        _isBatchMode = false;
        _currentBatchIndex = -1;
        resetForm();
        
        if (errors.isNotEmpty) {
          // Partial success
          _setError('נשמרו $successCount מתוך ${recordsToSave.length} רשומות\n${errors.join('\n')}');
          return false;
        }
        
        debugPrint('[BATCH] All records saved successfully');
        return true;
      } else {
        // Complete failure
        _setError('שגיאה בשמירת הרשומות:\n${errors.join('\n')}');
        return false;
      }
      
    } catch (e) {
      _setError('שגיאה בשמירת הרשומות: ${e.toString()}');
      debugPrint('[BATCH] Fatal error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  void loadPendingRecord(int index) {
    if (index >= 0 && index < _pendingRecords.length) {
      _currentRecord = _pendingRecords[index];
      _currentBatchIndex = index;
      _isUpdateMode = false; // Not updating from sheets, just editing pending
      notifyListeners();
      debugPrint('[BATCH] Loaded pending record at index $index for editing');
    }
  }
  
  void removePendingRecord(StudentRecord record) {
    final index = _pendingRecords.indexOf(record);
    if (index != -1) {
      _removedRecord = record;
      _pendingRecords.removeAt(index);
      
      // Exit batch mode if no more pending
      if (_pendingRecords.isEmpty) {
        _isBatchMode = false;
        _currentBatchIndex = -1;
      }
      
      notifyListeners();
      debugPrint('[BATCH] Removed pending record: ${record.studentName}');
    }
  }
  
  void undoRemove() {
    if (_removedRecord != null) {
      _pendingRecords.add(_removedRecord!);
      _isBatchMode = true;
      _removedRecord = null;
      notifyListeners();
      debugPrint('[BATCH] Restored removed record');
    }
  }
  
  void clearBatch() {
    _pendingRecords.clear();
    _isBatchMode = false;
    _currentBatchIndex = -1;
    _removedRecord = null;
    resetForm();
    debugPrint('[BATCH] Cleared all pending records');
  }

}
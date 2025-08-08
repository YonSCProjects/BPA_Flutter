import 'package:flutter/foundation.dart';

import '../../data/models/student_record.dart';
import '../../services/google_sheets_service.dart';

class FormProvider extends ChangeNotifier {
  StudentRecord _currentRecord = StudentRecord.empty();
  StudentRecord? _originalRecord;
  bool _isLoading = false;
  String? _error;
  bool _isUpdateMode = false;

  StudentRecord get currentRecord => _currentRecord;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUpdateMode => _isUpdateMode;

  Future<void> initializeWithDefaults(GoogleSheetsService sheetsService) async {
    _setLoading(true);
    _setError(null);

    try {
      final today = DateTime.now().toString().substring(0, 10);
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
        _currentRecord = existingRecord;
        _isUpdateMode = true;
        
        debugPrint('✅ [FORM] Found existing record, switched to UPDATE mode');
        debugPrint('✅ [FORM] Existing record: ${existingRecord.toString()}');
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
      final recordToSave = _currentRecord.withCalculatedScore();
      final success = await sheetsService.saveRecord(recordToSave);
      
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

  void resetForm() {
    final today = DateTime.now().toString().substring(0, 10);
    _currentRecord = StudentRecord.empty().copyWith(date: today);
    _originalRecord = null;
    _isUpdateMode = false;
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

}
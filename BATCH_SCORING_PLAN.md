# Batch Scoring Implementation Plan

## Overview
Enable teachers to score multiple students sequentially before saving all records at once to Google Sheets. This improves workflow efficiency for end-of-class scoring sessions.

## Current Flow Analysis
1. **Single Student Flow**: User fills form → Save → Immediate sheets write → Form reset
2. **State Management**: FormProvider manages single StudentRecord
3. **Save Logic**: Direct save through MultiDestinationSheetsService
4. **Update Mode**: Supports editing existing records via 4-field matching

## Proposed Architecture

### 1. Data Structure Changes

#### FormProvider Enhancements
```dart
class FormProvider extends ChangeNotifier {
  // Existing fields
  StudentRecord _currentRecord = StudentRecord.empty();
  
  // New fields for batch mode
  List<StudentRecord> _pendingRecords = [];
  bool _isBatchMode = false;
  int _currentBatchIndex = -1; // -1 means editing new record
  
  // Getters
  List<StudentRecord> get pendingRecords => _pendingRecords;
  bool get isBatchMode => _isBatchMode && _pendingRecords.isNotEmpty;
  int get pendingCount => _pendingRecords.length;
  bool get hasPendingRecords => _pendingRecords.isNotEmpty;
}
```

### 2. Core Functionality

#### A. Next Student Button Logic
```dart
Future<void> addToQueueAndMoveNext() {
  // Validate current record
  if (!isCurrentRecordValid()) return false;
  
  // Add current record to pending queue
  if (_currentBatchIndex == -1) {
    // New record - add to queue
    _pendingRecords.add(_currentRecord.withCalculatedScore());
  } else {
    // Editing existing pending record - update it
    _pendingRecords[_currentBatchIndex] = _currentRecord.withCalculatedScore();
  }
  
  // Reset for next student
  _currentRecord = StudentRecord.empty().copyWith(
    date: _currentRecord.date,      // Keep date
    className: _currentRecord.className, // Keep class
    classNumber: _currentRecord.classNumber, // Keep class number
  );
  
  _currentBatchIndex = -1;
  _isUpdateMode = false;
  _isBatchMode = true;
  
  notifyListeners();
}
```

#### B. Batch Save Logic
```dart
Future<bool> saveBatchRecords(GoogleSheetsService sheetsService) async {
  if (_pendingRecords.isEmpty && !isCurrentRecordValid()) {
    return false;
  }
  
  _setLoading(true);
  _setError(null);
  
  try {
    // Add current record if valid
    if (isCurrentRecordValid()) {
      _pendingRecords.add(_currentRecord.withCalculatedScore());
    }
    
    // Initialize multi-destination service
    final multiService = MultiDestinationSheetsService(
      sheetsService.authService,
      sheetsService,
    );
    await multiService.initialize();
    
    // Save all records
    int successCount = 0;
    List<String> errors = [];
    
    for (int i = 0; i < _pendingRecords.length; i++) {
      try {
        final success = await multiService.saveToMultipleDestinations(
          _pendingRecords[i]
        );
        if (success) {
          successCount++;
        } else {
          errors.add('${_pendingRecords[i].studentName}: שגיאה בשמירה');
        }
      } catch (e) {
        errors.add('${_pendingRecords[i].studentName}: $e');
      }
    }
    
    // Clear batch on success
    if (successCount > 0) {
      _pendingRecords.clear();
      _isBatchMode = false;
      resetForm();
    }
    
    // Report results
    if (errors.isNotEmpty) {
      _setError('${successCount}/${_pendingRecords.length} רשומות נשמרו\n${errors.join('\n')}');
      return false;
    }
    
    return true;
    
  } catch (e) {
    _setError('שגיאה בשמירת הרשומות: ${e.toString()}');
    return false;
  } finally {
    _setLoading(false);
  }
}
```

### 3. UI Changes

#### A. Button Layout (student_form_page.dart)
```dart
Widget _buildBottomSection(FormProvider formProvider) {
  return Container(
    child: Column(
      children: [
        // Pending students indicator
        if (formProvider.hasPendingRecords)
          _buildPendingIndicator(formProvider),
          
        // Main action buttons
        Row(
          children: [
            // Clear button (1 part)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _handleClearForm,
                child: const Text('נקה'),
              ),
            ),
            
            // Next Student button (2 parts)
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _handleNextStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                icon: const Icon(Icons.arrow_forward),
                label: Text('תלמיד הבא (${formProvider.pendingCount})'),
              ),
            ),
            
            // Save button (2 parts)
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                icon: const Icon(Icons.save),
                label: Text(
                  formProvider.hasPendingRecords 
                    ? 'שמור הכל (${formProvider.pendingCount + 1})'
                    : 'שמור'
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

#### B. Pending Students Indicator
```dart
Widget _buildPendingIndicator(FormProvider formProvider) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.orange.shade300),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(Icons.group, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(
              'תלמידים ממתינים לשמירה: ${formProvider.pendingCount}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // List of pending students
        ...formProvider.pendingRecords.map((record) => 
          InkWell(
            onTap: () => _editPendingRecord(record),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 4),
                  Text('${record.studentName} - ${record.className}'),
                  const Spacer(),
                  Text('ניקוד: ${record.totalScore}'),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 16),
                    onPressed: () => _removePendingRecord(record),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
```

### 4. Edge Cases & Handling

#### A. Navigation Prevention
```dart
// In student_form_page.dart
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: !formProvider.hasPendingRecords,
    onPopInvoked: (didPop) async {
      if (!didPop && formProvider.hasPendingRecords) {
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('רשומות לא נשמרו'),
            content: Text(
              'יש ${formProvider.pendingCount} תלמידים שטרם נשמרו. האם לצאת בכל זאת?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('הישאר'),
              ),
              TextButton(
                onPressed: () {
                  formProvider.clearBatch();
                  Navigator.pop(context, true);
                },
                child: const Text('צא ללא שמירה'),
              ),
            ],
          ),
        );
        
        if (shouldLeave == true && context.mounted) {
          Navigator.pop(context);
        }
      }
    },
    child: Scaffold(...),
  );
}
```

#### B. Clear Form Behavior
```dart
void _handleClearForm() {
  if (formProvider.hasPendingRecords) {
    // Show warning about pending records
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('נקה טופס'),
        content: const Text('האם לנקות רק את הטופס הנוכחי או גם את הרשומות הממתינות?'),
        actions: [
          TextButton(
            onPressed: () {
              formProvider.resetForm(); // Clear current only
              Navigator.pop(context);
            },
            child: const Text('רק טופס נוכחי'),
          ),
          TextButton(
            onPressed: () {
              formProvider.clearBatch(); // Clear everything
              Navigator.pop(context);
            },
            child: const Text('נקה הכל'),
          ),
        ],
      ),
    );
  } else {
    formProvider.resetForm();
  }
}
```

### 5. Additional Features

#### A. Edit Pending Record
```dart
void _editPendingRecord(StudentRecord record) {
  final index = formProvider.pendingRecords.indexOf(record);
  if (index != -1) {
    formProvider.loadPendingRecord(index);
  }
}

// In FormProvider
void loadPendingRecord(int index) {
  if (index >= 0 && index < _pendingRecords.length) {
    _currentRecord = _pendingRecords[index];
    _currentBatchIndex = index;
    notifyListeners();
  }
}
```

#### B. Remove Pending Record
```dart
void _removePendingRecord(StudentRecord record) {
  formProvider.removePendingRecord(record);
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${record.studentName} הוסר מהרשימה'),
      action: SnackBarAction(
        label: 'בטל',
        onPressed: () => formProvider.undoRemove(record),
      ),
    ),
  );
}
```

### 6. State Persistence (Optional Enhancement)

Consider adding local persistence for pending records to handle app crashes:

```dart
// Save pending records to SharedPreferences
Future<void> _persistPendingRecords() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = _pendingRecords.map((r) => r.toJson()).toList();
  await prefs.setString('pending_records', jsonEncode(jsonList));
}

// Restore on app launch
Future<void> _restorePendingRecords() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('pending_records');
  if (jsonString != null) {
    final jsonList = jsonDecode(jsonString) as List;
    _pendingRecords = jsonList.map((j) => StudentRecord.fromJson(j)).toList();
    _isBatchMode = _pendingRecords.isNotEmpty;
  }
}
```

## Implementation Steps

1. **Phase 1: Core State Management**
   - Extend FormProvider with batch fields
   - Implement addToQueueAndMoveNext method
   - Implement saveBatchRecords method

2. **Phase 2: UI Components**
   - Add Next Student button
   - Implement pending students indicator
   - Update Save button text dynamically

3. **Phase 3: Advanced Features**
   - Edit pending records
   - Remove pending records with undo
   - Navigation prevention dialog

4. **Phase 4: Testing & Polish**
   - Handle educator mappings correctly
   - Test multi-destination saving
   - Verify sorting/update logic works

## Benefits

1. **Efficiency**: Score multiple students without network delays between each
2. **Flexibility**: Review and edit pending records before final save
3. **Safety**: Batch indicator prevents accidental data loss
4. **Consistency**: Maintains all existing features (sorting, multi-destination, updates)

## Risks & Mitigations

1. **Data Loss**: Mitigate with navigation prevention and optional persistence
2. **Memory Usage**: Unlikely issue for typical batch sizes (5-30 students)
3. **Complexity**: Clear UI indicators help users understand batch mode
4. **Network Failures**: Batch save provides clear feedback on partial failures

## Success Metrics

- Reduced time to score a full class by 30-50%
- Clear visual feedback for pending records
- Zero data loss from navigation/crashes
- Maintains all existing functionality
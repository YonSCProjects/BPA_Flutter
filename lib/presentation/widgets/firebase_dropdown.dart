import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_data_service.dart';
import '../../core/theme/hebrew_theme.dart';

enum FirebaseFieldType {
  educator,
  student,
}

class FirebaseDropdown extends StatefulWidget {
  final String label;
  final FirebaseFieldType fieldType;
  final String? value;
  final Function(String?) onChanged;
  final bool isRequired;
  final String? filterByEducator;  // New parameter for filtering students

  const FirebaseDropdown({
    Key? key,
    required this.label,
    required this.fieldType,
    this.value,
    required this.onChanged,
    this.isRequired = false,
    this.filterByEducator,  // Optional filter
  }) : super(key: key);

  @override
  State<FirebaseDropdown> createState() => _FirebaseDropdownState();
}

class _FirebaseDropdownState extends State<FirebaseDropdown> {
  List<DropdownItem> items = [];
  bool isLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(FirebaseDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fieldType != widget.fieldType || 
        oldWidget.filterByEducator != widget.filterByEducator) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final firebaseService = context.read<FirebaseDataService>();
      
      if (!firebaseService.isInitialized) {
        // Use cached data if Firebase not initialized
        _loadCachedData();
        return;
      }

      // Load from Firebase based on field type
      if (widget.fieldType == FirebaseFieldType.educator) {
        final educators = firebaseService.getCachedEducators();
        setState(() {
          items = educators
              .map((e) => DropdownItem(
                    id: e.name,  // Use name as ID for educators
                    name: e.name,
                    data: {'email': e.email},
                  ))
              .toList();
          isLoading = false;
        });
      } else if (widget.fieldType == FirebaseFieldType.student) {
        // Load all students or filter by educator if specified
        var students = firebaseService.cachedStudents;
        
        // Apply filter if educator is specified
        if (widget.filterByEducator != null && widget.filterByEducator!.isNotEmpty) {
          students = students.where((s) => 
            s.educatorName == widget.filterByEducator
          ).toList();
        }
        
        setState(() {
          items = students
              .map((s) => DropdownItem(
                    id: s.name,  // Use name as ID for students
                    name: s.name,
                    data: {
                      'educatorId': s.educatorId,
                      'educatorName': s.educatorName,
                      'grade': s.grade,
                    },
                  ))
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'שגיאה בטעינת נתונים';
        isLoading = false;
      });
    }
  }

  void _loadCachedData() {
    // This would load from local SQLite cache
    // For now, show empty state
    setState(() {
      items = [];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Row(
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.isRequired)
                  const Text(
                    ' *',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Dropdown
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: error != null
                      ? Colors.red.shade300
                      : HebrewTheme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: (widget.value != null && widget.value!.isNotEmpty && 
                             items.any((item) => item.id == widget.value)) 
                             ? widget.value : null,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintText: widget.fieldType == FirebaseFieldType.student 
                            ? 'בחר/י תלמיד/ה'
                            : widget.fieldType == FirebaseFieldType.educator
                            ? 'בחר/י כיתה'
                            : 'בחר ${widget.label}',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                      isExpanded: true,
                      items: items.isNotEmpty ? items.map((item) {
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            item.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList() : [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('אין נתונים זמינים'),
                        ),
                      ],
                      onChanged: (value) {
                        final selectedItem = items.firstWhere(
                          (item) => item.id == value,
                          orElse: () => DropdownItem(
                            id: '',
                            name: '',
                            data: {},
                          ),
                        );
                        widget.onChanged(value);
                      },
                    ),
            ),
            
            // Error message
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DropdownItem {
  final String id;
  final String name;
  final Map<String, dynamic> data;

  DropdownItem({
    required this.id,
    required this.name,
    required this.data,
  });
}
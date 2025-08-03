import 'student_record.dart';

class AutocompleteData {
  final Set<String> studentNames;
  final Set<String> classNames;
  final DateTime lastUpdated;

  const AutocompleteData({
    required this.studentNames,
    required this.classNames,
    required this.lastUpdated,
  });

  factory AutocompleteData.empty() {
    return AutocompleteData(
      studentNames: <String>{},
      classNames: <String>{},
      lastUpdated: DateTime.now(),
    );
  }

  AutocompleteData copyWith({
    Set<String>? studentNames,
    Set<String>? classNames,
    DateTime? lastUpdated,
  }) {
    return AutocompleteData(
      studentNames: studentNames ?? this.studentNames,
      classNames: classNames ?? this.classNames,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  AutocompleteData addStudentName(String name) {
    if (name.trim().isEmpty) return this;
    
    final updatedNames = Set<String>.from(studentNames);
    updatedNames.add(name.trim());
    
    return copyWith(
      studentNames: updatedNames,
      lastUpdated: DateTime.now(),
    );
  }

  AutocompleteData addClassName(String name) {
    if (name.trim().isEmpty) return this;
    
    final updatedNames = Set<String>.from(classNames);
    updatedNames.add(name.trim());
    
    return copyWith(
      classNames: updatedNames,
      lastUpdated: DateTime.now(),
    );
  }

  AutocompleteData addFromRecord(StudentRecord record) {
    return addStudentName(record.studentName)
        .addClassName(record.className);
  }

  List<String> getStudentSuggestions(String query) {
    if (query.length < 2) return [];
    
    final lowercaseQuery = query.toLowerCase();
    return studentNames
        .where((name) => name.toLowerCase().contains(lowercaseQuery))
        .toList()
      ..sort();
  }

  List<String> getClassSuggestions(String query) {
    if (query.length < 2) return [];
    
    final lowercaseQuery = query.toLowerCase();
    return classNames
        .where((name) => name.toLowerCase().contains(lowercaseQuery))
        .toList()
      ..sort();
  }

  bool isStale(Duration maxAge) {
    return DateTime.now().difference(lastUpdated) > maxAge;
  }

  Map<String, dynamic> toJson() {
    return {
      'studentNames': studentNames.toList(),
      'classNames': classNames.toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory AutocompleteData.fromJson(Map<String, dynamic> json) {
    return AutocompleteData(
      studentNames: Set<String>.from(json['studentNames'] ?? []),
      classNames: Set<String>.from(json['classNames'] ?? []),
      lastUpdated: DateTime.tryParse(json['lastUpdated'] ?? '') ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AutocompleteData &&
        other.studentNames.length == studentNames.length &&
        other.classNames.length == classNames.length &&
        other.studentNames.containsAll(studentNames) &&
        other.classNames.containsAll(classNames);
  }

  @override
  int get hashCode {
    return Object.hash(
      studentNames.length,
      classNames.length,
      lastUpdated,
    );
  }

  @override
  String toString() {
    return 'AutocompleteData(students: ${studentNames.length}, classes: ${classNames.length}, updated: $lastUpdated)';
  }
}
class AttendanceRecord {
  final String date;              // DD/MM/YYYY format
  final String className;         // שם הכיתה
  final Map<String, bool> studentAttendance; // Student name -> present/absent
  final String submittedBy;       // Secretary email
  final DateTime timestamp;       // When submitted
  final bool isLateUpdate;        // Whether this is a late arrival update
  final Map<String, bool>? lateArrivals; // Student name -> is late arrival

  const AttendanceRecord({
    required this.date,
    required this.className,
    required this.studentAttendance,
    required this.submittedBy,
    required this.timestamp,
    this.isLateUpdate = false,
    this.lateArrivals,
  });

  // Convert to row for spreadsheet
  List<dynamic> toSheetRow(List<String> studentNames) {
    final row = [date]; // First column is date

    // Add attendance status for each student in order
    for (final studentName in studentNames) {
      final isPresent = studentAttendance[studentName] ?? false;
      final isLate = lateArrivals?[studentName] ?? false;

      // Mark late arrivals with a special indicator
      if (isPresent && isLate) {
        row.add('✓ (מאחר)');
      } else {
        row.add(isPresent ? '✓' : '✗');
      }
    }

    return row;
  }

  // Create from map (for Firestore)
  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      date: map['date'] ?? '',
      className: map['className'] ?? '',
      studentAttendance: Map<String, bool>.from(map['studentAttendance'] ?? {}),
      submittedBy: map['submittedBy'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      isLateUpdate: map['isLateUpdate'] ?? false,
      lateArrivals: map['lateArrivals'] != null
        ? Map<String, bool>.from(map['lateArrivals'])
        : null,
    );
  }

  // Convert to map (for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'className': className,
      'studentAttendance': studentAttendance,
      'submittedBy': submittedBy,
      'timestamp': timestamp.toIso8601String(),
      'isLateUpdate': isLateUpdate,
      if (lateArrivals != null) 'lateArrivals': lateArrivals,
    };
  }
}
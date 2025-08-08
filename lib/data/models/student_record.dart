class StudentRecord {
  final String date;              // תאריך
  final String studentName;       // שם התלמיד
  final String className;         // שם הכיתה
  final int classNumber;          // מספר השיעור (1-7)
  final int entry;                // כניסה (0-1)
  final int staying;              // שהייה (0-3)
  final int attitude;             // אווירה (0-2)
  final int performance;          // ביצוע (0-2)
  final int personalGoal;         // מטרה אישית (0-2)
  final int bonus;                // בונוס (0-1)
  final String comments;          // הערות
  final int totalScore;           // סה"כ (calculated)

  const StudentRecord({
    required this.date,
    required this.studentName,
    required this.className,
    required this.classNumber,
    required this.entry,
    required this.staying,
    required this.attitude,
    required this.performance,
    required this.personalGoal,
    required this.bonus,
    required this.comments,
    required this.totalScore,
  });

  StudentRecord copyWith({
    String? date,
    String? studentName,
    String? className,
    int? classNumber,
    int? entry,
    int? staying,
    int? attitude,
    int? performance,
    int? personalGoal,
    int? bonus,
    String? comments,
    int? totalScore,
  }) {
    return StudentRecord(
      date: date ?? this.date,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      classNumber: classNumber ?? this.classNumber,
      entry: entry ?? this.entry,
      staying: staying ?? this.staying,
      attitude: attitude ?? this.attitude,
      performance: performance ?? this.performance,
      personalGoal: personalGoal ?? this.personalGoal,
      bonus: bonus ?? this.bonus,
      comments: comments ?? this.comments,
      totalScore: totalScore ?? this.totalScore,
    );
  }

  factory StudentRecord.empty() {
    // Format date as DD/MM/YYYY for Hebrew/Israeli convention
    final now = DateTime.now();
    final dateFormatted = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    
    return StudentRecord(
      date: dateFormatted,
      studentName: '',
      className: '',
      classNumber: 1,
      entry: 1,
      staying: 3,
      attitude: 2,
      performance: 2,
      personalGoal: 2,
      bonus: 0,
      comments: '',
      totalScore: 0,
    );
  }

  int calculateTotalScore() {
    return entry + staying + attitude + performance + personalGoal + bonus;
  }

  StudentRecord withCalculatedScore() {
    return copyWith(totalScore: calculateTotalScore());
  }

  List<dynamic> toSheetRow() {
    return [
      date,
      studentName,
      className,
      classNumber,
      entry,
      staying,
      attitude,
      performance,
      personalGoal,
      bonus,
      totalScore,
      comments,
    ];
  }

  factory StudentRecord.fromSheetRow(List<dynamic> row) {
    if (row.length < 12) {
      throw ArgumentError('Sheet row must have at least 12 columns');
    }
    
    return StudentRecord(
      date: row[0]?.toString() ?? '',
      studentName: row[1]?.toString() ?? '',
      className: row[2]?.toString() ?? '',
      classNumber: int.tryParse(row[3]?.toString() ?? '1') ?? 1,
      entry: int.tryParse(row[4]?.toString() ?? '0') ?? 0,
      staying: int.tryParse(row[5]?.toString() ?? '0') ?? 0,
      attitude: int.tryParse(row[6]?.toString() ?? '0') ?? 0,
      performance: int.tryParse(row[7]?.toString() ?? '0') ?? 0,
      personalGoal: int.tryParse(row[8]?.toString() ?? '0') ?? 0,
      bonus: int.tryParse(row[9]?.toString() ?? '0') ?? 0,
      totalScore: int.tryParse(row[10]?.toString() ?? '0') ?? 0,
      comments: row[11]?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'studentName': studentName,
      'className': className,
      'classNumber': classNumber,
      'entry': entry,
      'staying': staying,
      'attitude': attitude,
      'performance': performance,
      'personalGoal': personalGoal,
      'bonus': bonus,
      'comments': comments,
      'totalScore': totalScore,
    };
  }

  factory StudentRecord.fromJson(Map<String, dynamic> json) {
    return StudentRecord(
      date: json['date'] ?? '',
      studentName: json['studentName'] ?? '',
      className: json['className'] ?? '',
      classNumber: json['classNumber'] ?? 1,
      entry: json['entry'] ?? 0,
      staying: json['staying'] ?? 0,
      attitude: json['attitude'] ?? 0,
      performance: json['performance'] ?? 0,
      personalGoal: json['personalGoal'] ?? 0,
      bonus: json['bonus'] ?? 0,
      comments: json['comments'] ?? '',
      totalScore: json['totalScore'] ?? 0,
    );
  }

  String getMatchingKey() {
    return '$date|$studentName|$className|$classNumber';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentRecord &&
        other.date == date &&
        other.studentName == studentName &&
        other.className == className &&
        other.classNumber == classNumber &&
        other.entry == entry &&
        other.staying == staying &&
        other.attitude == attitude &&
        other.performance == performance &&
        other.personalGoal == personalGoal &&
        other.bonus == bonus &&
        other.comments == comments &&
        other.totalScore == totalScore;
  }

  @override
  int get hashCode {
    return Object.hash(
      date,
      studentName,
      className,
      classNumber,
      entry,
      staying,
      attitude,
      performance,
      personalGoal,
      bonus,
      comments,
      totalScore,
    );
  }

  @override
  String toString() {
    return 'StudentRecord(date: $date, studentName: $studentName, className: $className, classNumber: $classNumber, totalScore: $totalScore)';
  }
}
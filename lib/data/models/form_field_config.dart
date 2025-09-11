enum FieldType {
  date,
  text,
  numberPicker,
  textArea,
}

class FormFieldConfig {
  final String hebrewLabel;
  final String fieldKey;
  final FieldType type;
  final int? minValue;
  final int? maxValue;
  final List<int>? allowedValues;
  final bool isRequired;
  final String? hintText;
  final bool hasAutocomplete;

  const FormFieldConfig({
    required this.hebrewLabel,
    required this.fieldKey,
    required this.type,
    this.minValue,
    this.maxValue,
    this.allowedValues,
    this.isRequired = true,
    this.hintText,
    this.hasAutocomplete = false,
  });

  static const List<FormFieldConfig> allFields = [
    FormFieldConfig(
      hebrewLabel: 'תאריך',
      fieldKey: 'date',
      type: FieldType.date,
      isRequired: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'שם התלמיד',
      fieldKey: 'studentName',
      type: FieldType.text,
      isRequired: true,
      hintText: 'הזן שם התלמיד',
      hasAutocomplete: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'שם הכיתה',
      fieldKey: 'className',
      type: FieldType.text,
      isRequired: true,
      hintText: 'הזן שם הכיתה',
      hasAutocomplete: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'מספר השיעור',
      fieldKey: 'classNumber',
      type: FieldType.numberPicker,
      minValue: 1,
      maxValue: 7,
      allowedValues: [1, 2, 3, 4, 5, 6, 7],
      isRequired: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'כניסה',
      fieldKey: 'entry',
      type: FieldType.numberPicker,
      minValue: 0,
      maxValue: 1,
      allowedValues: [0, 1],
      isRequired: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'שהייה',
      fieldKey: 'staying',
      type: FieldType.numberPicker,
      minValue: 0,
      maxValue: 2,
      allowedValues: [0, 1, 2],
      isRequired: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'אווירה',
      fieldKey: 'attitude',
      type: FieldType.numberPicker,
      minValue: 0,
      maxValue: 1,
      allowedValues: [0, 1],
      isRequired: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'ביצוע',
      fieldKey: 'performance',
      type: FieldType.numberPicker,
      minValue: 0,
      maxValue: 1,
      allowedValues: [0, 1],
      isRequired: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'מטרה אישית',
      fieldKey: 'personalGoal',
      type: FieldType.numberPicker,
      minValue: 0,
      maxValue: 1,
      allowedValues: [0, 1],
      isRequired: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'בונוס',
      fieldKey: 'bonus',
      type: FieldType.numberPicker,
      minValue: 0,
      maxValue: 1,
      allowedValues: [0, 1],
      isRequired: true,
    ),
    FormFieldConfig(
      hebrewLabel: 'הערות',
      fieldKey: 'comments',
      type: FieldType.textArea,
      isRequired: false,
      hintText: 'הערות נוספות (אופציונלי)',
    ),
  ];

  static FormFieldConfig? getFieldConfig(String fieldKey) {
    try {
      return allFields.firstWhere((field) => field.fieldKey == fieldKey);
    } catch (e) {
      return null;
    }
  }

  static List<FormFieldConfig> getRequiredFields() {
    return allFields.where((field) => field.isRequired).toList();
  }

  static List<FormFieldConfig> getNumericFields() {
    return allFields
        .where((field) => field.type == FieldType.numberPicker)
        .toList();
  }

  static List<FormFieldConfig> getAutocompleteFields() {
    return allFields.where((field) => field.hasAutocomplete).toList();
  }

  bool isValidValue(dynamic value) {
    switch (type) {
      case FieldType.date:
        return value is String && value.isNotEmpty;
      case FieldType.text:
        if (isRequired) {
          return value is String && value.trim().isNotEmpty;
        }
        return value is String;
      case FieldType.textArea:
        return value is String;
      case FieldType.numberPicker:
        if (value is! int) return false;
        if (allowedValues != null) {
          return allowedValues!.contains(value);
        }
        if (minValue != null && value < minValue!) return false;
        if (maxValue != null && value > maxValue!) return false;
        return true;
    }
  }

  String? getValidationError(dynamic value) {
    if (isRequired && (value == null || (value is String && value.trim().isEmpty))) {
      return 'שדה $hebrewLabel הוא חובה';
    }

    if (!isValidValue(value)) {
      switch (type) {
        case FieldType.numberPicker:
          if (allowedValues != null) {
            return '$hebrewLabel חייב להיות אחד מהערכים: ${allowedValues!.join(', ')}';
          }
          return '$hebrewLabel חייב להיות בין $minValue ל-$maxValue';
        case FieldType.text:
        case FieldType.textArea:
          return '$hebrewLabel חייב להכיל טקסט תקין';
        case FieldType.date:
          return '$hebrewLabel חייב להכיל תאריך תקין';
      }
    }

    return null;
  }
}
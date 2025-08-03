import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HebrewDatePicker extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool isRequired;

  const HebrewDatePicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRequired)
              const Icon(Icons.star, color: Colors.red, size: 12),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
      controller: TextEditingController(
        text: _formatDateForDisplay(value),
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'שדה $label הוא חובה';
              }
              return null;
            }
          : null,
      onTap: () => _selectDate(context),
    );
  }

  String _formatDateForDisplay(String dateString) {
    if (dateString.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateString);
      final formatter = DateFormat('dd/MM/yyyy');
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateForStorage(DateTime date) {
    return date.toString().substring(0, 10);
  }

  Future<void> _selectDate(BuildContext context) async {
    final currentDate = _parseDate(value) ?? DateTime.now();
    
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (selectedDate != null) {
      onChanged(_formatDateForStorage(selectedDate));
    }
  }

  DateTime? _parseDate(String dateString) {
    if (dateString.isEmpty) return null;
    
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }
}
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
    
    // Handle both formats: DD/MM/YYYY and YYYY-MM-DD
    try {
      DateTime date;
      if (dateString.contains('/')) {
        // Already in DD/MM/YYYY format
        return dateString;
      } else {
        // Parse from YYYY-MM-DD format
        date = DateTime.parse(dateString);
        final formatter = DateFormat('dd/MM/yyyy');
        return formatter.format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateForStorage(DateTime date) {
    // Store in DD/MM/YYYY format to match Hebrew/Israeli convention
    final formatter = DateFormat('dd/MM/yyyy');
    final formatted = formatter.format(date);
    debugPrint('📅 [DATE] Storing date as: "$formatted"');
    return formatted;
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
      // Handle DD/MM/YYYY format
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      }
      // Fallback to standard parsing for YYYY-MM-DD
      return DateTime.parse(dateString);
    } catch (e) {
      debugPrint('📅 [DATE] Error parsing date "$dateString": $e');
      return null;
    }
  }
}
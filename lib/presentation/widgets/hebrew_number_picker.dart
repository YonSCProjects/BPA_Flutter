import 'package:flutter/material.dart';

class HebrewNumberPicker extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int minValue;
  final int maxValue;
  final bool isRequired;
  final String? description;

  const HebrewNumberPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.minValue,
    required this.maxValue,
    this.isRequired = true,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          textDirection: TextDirection.rtl,
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textDirection: TextDirection.rtl,
            ),
          ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: _buildNumberButtons(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildNumberButtons(BuildContext context) {
    final buttons = <Widget>[];
    
    for (int i = minValue; i <= maxValue; i++) {
      if (buttons.isNotEmpty) {
        buttons.add(
          Container(
            width: 1,
            height: 48,
            color: Theme.of(context).dividerColor,
          ),
        );
      }
      
      buttons.add(
        Expanded(
          child: InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: value == i
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  i.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: value == i
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return buttons;
  }
}

class HebrewNumberPickerFormField extends FormField<int> {
  HebrewNumberPickerFormField({
    super.key,
    required String label,
    required int initialValue,
    required int minValue,
    required int maxValue,
    required ValueChanged<int> onChanged,
    bool isRequired = true,
    String? description,
    super.validator,
  }) : super(
          initialValue: initialValue,
          builder: (FormFieldState<int> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HebrewNumberPicker(
                  label: label,
                  value: state.value ?? initialValue,
                  onChanged: (value) {
                    state.didChange(value);
                    onChanged(value);
                  },
                  minValue: minValue,
                  maxValue: maxValue,
                  isRequired: isRequired,
                  description: description,
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(
                        color: Theme.of(state.context).colorScheme.error,
                        fontSize: 12,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
              ],
            );
          },
        );
}
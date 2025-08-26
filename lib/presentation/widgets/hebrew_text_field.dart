import 'package:flutter/material.dart';

class HebrewTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> Function(String)? suggestions;
  final ValueChanged<String>? onSuggestionSelected;
  final bool isRequired;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;

  const HebrewTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suggestions,
    this.onSuggestionSelected,
    this.isRequired = true,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  State<HebrewTextField> createState() => _HebrewTextFieldState();
}

class _HebrewTextFieldState extends State<HebrewTextField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  List<String> _currentSuggestions = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isSelectingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(HebrewTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller if the value changed from outside AND controller doesn't have focus AND not selecting suggestion
    if (oldWidget.value != widget.value && !_focusNode.hasFocus && !_isSelectingSuggestion) {
      debugPrint('didUpdateWidget: Updating controller from "${_controller.text}" to "${widget.value}"');
      _controller.text = widget.value;
    } else if (_isSelectingSuggestion) {
      debugPrint('didUpdateWidget: Skipping update during suggestion selection');
    }
    
    // Reset flag after a brief delay to ensure the suggestion selection completes
    if (_isSelectingSuggestion) {
      Future.microtask(() {
        if (mounted) {
          _isSelectingSuggestion = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideSuggestions();
    }
  }

  void _onTextChanged(String value) {
    // Only call onChanged if the value actually changed to avoid loops
    if (value != widget.value) {
      widget.onChanged(value);
    }
    
    if (widget.suggestions != null && value.length >= 2) {
      _currentSuggestions = widget.suggestions!(value);
      if (_currentSuggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      } else {
        _hideSuggestions();
      }
    } else {
      _hideSuggestions();
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _getSuggestionsWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _currentSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _currentSuggestions[index];
                  return InkWell(
                    onTap: () => _selectSuggestion(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        suggestion,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  double _getSuggestionsWidth() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 200;
  }

  void _selectSuggestion(String suggestion) {
    debugPrint('_selectSuggestion called with: "$suggestion"');
    _isSelectingSuggestion = true; // Set flag to prevent didUpdateWidget interference
    
    // Set the controller text first
    _controller.text = suggestion;
    debugPrint('Controller text set to: "${_controller.text}"');
    _hideSuggestions();
    
    // Call onSuggestionSelected which should handle the state update
    if (widget.onSuggestionSelected != null) {
      debugPrint('Calling onSuggestionSelected with: "$suggestion"');
      widget.onSuggestionSelected!(suggestion);
    } else {
      // Fallback to onChanged if no specific handler
      debugPrint('Calling onChanged with: "$suggestion"');
      widget.onChanged(suggestion);
    }
  }

  void _hideSuggestions() {
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        validator: widget.isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'שדה ${widget.label} הוא חובה';
                }
                return null;
              }
            : null,
        onChanged: _onTextChanged,
      ),
    );
  }
}
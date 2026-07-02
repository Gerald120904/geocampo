import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeInputField extends StatefulWidget {
  const CodeInputField({
    super.key,
    required this.onChanged,
    this.enabled = true,
  });

  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<CodeInputField> createState() => _CodeInputFieldState();
}

class _CodeInputFieldState extends State<CodeInputField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_controllers.map((controller) => controller.text).join());
  }

  void _handleChanged(String value, int index) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      for (var i = 0; i < _controllers.length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final next = digits.length.clamp(0, 5);
      _focusNodes[next].requestFocus();
      _emit();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(6, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: index == 5
                  ? TextInputAction.done
                  : TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) => _handleChanged(value, index),
            ),
          ),
        );
      }),
    );
  }
}

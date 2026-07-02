import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final Duration debounce;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final controller = TextEditingController();
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    timer?.cancel();
    timer = Timer(widget.debounce, () => widget.onChanged(value));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: _changed,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar busqueda',
                onPressed: () {
                  controller.clear();
                  timer?.cancel();
                  widget.onChanged('');
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        fillColor: AppColors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5E2D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
    );
  }
}

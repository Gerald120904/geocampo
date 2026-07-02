import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class AppDropdown<T> extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?>? onChanged;
  final String label;
  final IconData? icon;
  final bool enabled;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  late final ValueNotifier<T?> valueNotifier;

  @override
  void initState() {
    super.initState();
    valueNotifier = ValueNotifier<T?>(widget.value);
  }

  @override
  void didUpdateWidget(covariant AppDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      valueNotifier.value = widget.value;
    }
  }

  @override
  void dispose() {
    valueNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField2<T>(
      valueListenable: valueNotifier,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
        contentPadding: EdgeInsets.zero,
      ),
      items: widget.items
          .map(
            (item) => DropdownItem<T>(
              value: item,
              height: 50,
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_copy_outlined,
                    size: 18,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.itemLabel(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: widget.enabled
          ? (value) {
              valueNotifier.value = value;
              widget.onChanged?.call(value);
            }
          : null,
      buttonStyleData: const FormFieldButtonStyleData(
        height: 58,
        padding: EdgeInsets.only(right: 14),
      ),
      iconStyleData: const IconStyleData(
        icon: Icon(Icons.keyboard_arrow_down_rounded),
        iconSize: 24,
        iconEnabledColor: AppColors.darkGreen,
      ),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 320,
        elevation: 8,
        offset: const Offset(0, -4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDE5DF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
      ),
      menuItemStyleData: const MenuItemStyleData(
        padding: EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }
}

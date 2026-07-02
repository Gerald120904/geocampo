import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';

class ConfirmActionSheet extends StatefulWidget {
  const ConfirmActionSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = 'Cancelar',
    this.icon = Icons.warning_rounded,
    this.danger = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Future<void> Function() onConfirm;
  final String cancelLabel;
  final IconData icon;
  final bool danger;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
    String cancelLabel = 'Cancelar',
    IconData icon = Icons.warning_rounded,
    bool danger = false,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      isDismissible: false,
      child: ConfirmActionSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        onConfirm: onConfirm,
        cancelLabel: cancelLabel,
        icon: icon,
        danger: danger,
      ),
    );
  }

  @override
  State<ConfirmActionSheet> createState() => _ConfirmActionSheetState();
}

class _ConfirmActionSheetState extends State<ConfirmActionSheet> {
  bool _loading = false;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? AppColors.dangerRed : AppColors.primaryGreen;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBottomSheetHeader(
          icon: widget.icon,
          title: widget.title,
          message: widget.message,
          color: color,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: widget.cancelLabel,
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                variant: AppButtonVariant.ghost,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: widget.confirmLabel,
                onPressed: _loading ? null : _confirm,
                loading: _loading,
                variant: widget.danger
                    ? AppButtonVariant.danger
                    : AppButtonVariant.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

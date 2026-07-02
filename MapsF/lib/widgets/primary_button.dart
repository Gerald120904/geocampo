import 'package:flutter/material.dart';

import 'app_button.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: loading ? null : onPressed,
      icon: icon,
      loading: loading,
      fullWidth: true,
    );
  }
}

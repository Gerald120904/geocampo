import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../services/service_providers.dart';
import '../widgets/auth/auth_buttons.dart';
import '../widgets/auth/auth_card.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/auth/auth_background.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;
  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;
  String? error;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (currentPasswordController.text.isEmpty ||
        newPasswordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      setState(() => error = 'Completa todos los campos.');
      return;
    }
    if (newPasswordController.text != confirmPasswordController.text) {
      setState(() => error = 'Las contrasenas no coinciden.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: currentPasswordController.text,
            newPassword: newPasswordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contrasena actualizada.')));
      context.go('/login');
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: loading ? null : () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const AuthHeader(
                      title: 'Cambiar contrasena',
                      subtitle:
                          'Actualiza tu acceso para mantener segura la cuenta.',
                      icon: Icons.security_rounded,
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      controller: currentPasswordController,
                      label: 'Contrasena actual',
                      hint: 'tu clave actual',
                      icon: Icons.lock_outline_rounded,
                      enabled: !loading,
                      obscureText: obscureCurrent,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscureCurrent = !obscureCurrent),
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    AuthTextField(
                      controller: newPasswordController,
                      label: 'Nueva contrasena',
                      hint: 'Password123!',
                      icon: Icons.password_outlined,
                      enabled: !loading,
                      obscureText: obscureNew,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscureNew = !obscureNew),
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    AuthTextField(
                      controller: confirmPasswordController,
                      label: 'Confirmar',
                      hint: 'repite la nueva contrasena',
                      icon: Icons.lock_reset_outlined,
                      enabled: !loading,
                      obscureText: obscureConfirm,
                      onSubmitted: (_) => loading ? null : submit(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscureConfirm = !obscureConfirm),
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    if (error != null) _ErrorBox(error!),
                    PrimaryButton(
                      label: loading ? 'Guardando...' : 'Guardar',
                      icon: Icons.check_rounded,
                      loading: loading,
                      onPressed: submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.dangerRed,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

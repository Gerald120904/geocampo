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

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final TextEditingController emailController;
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  String? error;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (emailController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      setState(() => error = 'Completa todos los campos.');
      return;
    }
    if (codeController.text.trim().length != 6) {
      setState(() => error = 'El codigo debe tener 6 digitos.');
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
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
          .resetPassword(
            email: emailController.text,
            code: codeController.text,
            newPassword: passwordController.text,
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
                    const AuthHeader(
                      title: 'Nueva contrasena',
                      subtitle:
                          'Usa el codigo enviado al correo y define tu nueva clave.',
                      icon: Icons.password_rounded,
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      controller: emailController,
                      label: 'Correo',
                      hint: 'nombre@empresa.com',
                      icon: Icons.mail_outline_rounded,
                      enabled: !loading,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    AuthTextField(
                      controller: codeController,
                      label: 'Codigo',
                      hint: '6 digitos',
                      icon: Icons.pin_outlined,
                      enabled: !loading,
                      keyboardType: TextInputType.number,
                    ),
                    AuthTextField(
                      controller: passwordController,
                      label: 'Nueva contrasena',
                      hint: 'Password123!',
                      icon: Icons.lock_outline_rounded,
                      enabled: !loading,
                      obscureText: obscurePassword,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    AuthTextField(
                      controller: confirmPasswordController,
                      label: 'Confirmar contrasena',
                      hint: 'repite tu contrasena',
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
                    if (error != null) _StatusBox(error!),
                    PrimaryButton(
                      label: loading ? 'Guardando...' : 'Resetear contrasena',
                      icon: Icons.check_rounded,
                      loading: loading,
                      onPressed: submit,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: loading ? null : () => context.go('/login'),
                      child: const Text('Volver a login'),
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

class _StatusBox extends StatelessWidget {
  const _StatusBox(this.message);

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

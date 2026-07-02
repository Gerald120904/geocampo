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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final companyNameController = TextEditingController();
  final companyIdentifierController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  String? error;

  @override
  void dispose() {
    companyNameController.dispose();
    companyIdentifierController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (companyNameController.text.trim().isEmpty ||
        companyIdentifierController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      setState(() => error = 'Completa todos los campos.');
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
          .register(
            companyName: companyNameController.text,
            companyIdentifier: companyIdentifierController.text,
            name: nameController.text,
            email: emailController.text,
            password: passwordController.text,
          );
      if (!mounted) return;
      context.go(
        '/verify-email?email=${Uri.encodeComponent(emailController.text.trim())}',
      );
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeader(
                      title: 'Crea tu cuenta',
                      subtitle:
                          'Comienza a gestionar tus mapas, proyectos y trabajo en campo.',
                      icon: Icons.grass_outlined,
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      controller: companyNameController,
                      label: 'Nombre empresa',
                      hint: 'Finca La Esperanza',
                      icon: Icons.agriculture_outlined,
                      enabled: !loading,
                    ),
                    AuthTextField(
                      controller: companyIdentifierController,
                      label: 'Identificador empresa',
                      hint: 'finca-la-esperanza',
                      icon: Icons.badge_outlined,
                      enabled: !loading,
                    ),
                    AuthTextField(
                      controller: nameController,
                      label: 'Nombre usuario',
                      hint: 'Gerald Alvarez',
                      icon: Icons.person_outline,
                      enabled: !loading,
                    ),
                    AuthTextField(
                      controller: emailController,
                      label: 'Correo',
                      hint: 'nombre@empresa.com',
                      icon: Icons.mail_outline_rounded,
                      enabled: !loading,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    AuthTextField(
                      controller: passwordController,
                      label: 'Contrasena',
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
                      label: loading ? 'Creando...' : 'Crear cuenta',
                      icon: Icons.person_add_alt_1_rounded,
                      loading: loading,
                      onPressed: submit,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: loading ? null : () => context.go('/login'),
                      child: const Text('Ya tengo cuenta'),
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

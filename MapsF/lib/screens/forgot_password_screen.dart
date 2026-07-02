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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (emailController.text.trim().isEmpty) {
      setState(() => error = 'Escribe tu correo.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .forgotPassword(emailController.text);
      if (!mounted) return;
      context.go(
        '/reset-password?email=${Uri.encodeComponent(emailController.text.trim())}',
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
              constraints: const BoxConstraints(maxWidth: 440),
              child: AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeader(
                      title: 'Recuperar contrasena',
                      subtitle:
                          'Enviaremos un codigo para crear una nueva clave.',
                      icon: Icons.lock_reset_rounded,
                    ),
                    const SizedBox(height: 26),
                    AuthTextField(
                      controller: emailController,
                      label: 'Correo',
                      hint: 'nombre@empresa.com',
                      icon: Icons.mail_outline_rounded,
                      enabled: !loading,
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => loading ? null : submit(),
                    ),
                    if (error != null) _StatusBox(error!),
                    PrimaryButton(
                      label: loading ? 'Enviando...' : 'Enviar codigo',
                      icon: Icons.outgoing_mail,
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

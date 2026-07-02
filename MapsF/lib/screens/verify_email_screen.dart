import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../services/service_providers.dart';
import '../widgets/auth/auth_buttons.dart';
import '../widgets/auth/auth_card.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/code_input.dart';
import '../widgets/auth/auth_background.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late String email;
  String code = '';
  bool loading = false;
  String? error;
  String? message;

  @override
  void initState() {
    super.initState();
    email = widget.email ?? '';
  }

  Future<void> verify() async {
    if (email.trim().isEmpty) {
      setState(() => error = 'Primero indica el correo de la cuenta.');
      return;
    }
    if (code.length != 6) {
      setState(() => error = 'Ingresa el codigo de 6 digitos.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
      message = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(email, code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo verificado. Inicia sesion.')),
      );
      context.go('/login');
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> resend() async {
    if (email.trim().isEmpty) {
      setState(() => error = 'Primero indica el correo de la cuenta.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
      message = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendVerificationCode(email);
      setState(() {
        message = 'Enviamos un nuevo codigo a $email.';
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> changeEmail() async {
    final controller = TextEditingController(text: email);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar correo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'nombre@empresa.com',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() {
        email = result;
        error = null;
        message = null;
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
                      title: 'Revisa tu correo',
                      subtitle: 'Te enviamos un codigo de 6 digitos.',
                      icon: Icons.mark_email_read_outlined,
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFF3E3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.eco_outlined,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              email.isEmpty
                                  ? 'Ingresa el codigo enviado a tu correo.'
                                  : 'Codigo enviado a $email',
                              style: const TextStyle(
                                color: AppColors.forestGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    CodeInputField(
                      enabled: !loading,
                      onChanged: (value) => code = value,
                    ),
                    const SizedBox(height: 16),
                    if (error != null) _StatusBox(error!, isError: true),
                    if (message != null) _StatusBox(message!, isError: false),
                    PrimaryButton(
                      label: loading ? 'Verificando...' : 'Verificar',
                      icon: Icons.verified_rounded,
                      loading: loading,
                      onPressed: verify,
                    ),
                    const SizedBox(height: 10),
                    SecondaryButton(
                      label: 'Reenviar codigo',
                      icon: Icons.refresh_rounded,
                      onPressed: loading ? null : resend,
                    ),
                    TextButton(
                      onPressed: loading ? null : changeEmail,
                      child: const Text('Cambiar correo'),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => context.go('/login'),
                      child: const Text('Ir a login'),
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
  const _StatusBox(this.message, {required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.dangerRed : AppColors.primaryGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

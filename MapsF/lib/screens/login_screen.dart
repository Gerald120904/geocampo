import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../services/service_providers.dart';
import '../widgets/auth/auth_background.dart';
import '../widgets/auth/auth_buttons.dart';
import '../widgets/auth/auth_card.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectPath});

  final String? redirectPath;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscure = true;
  bool loading = false;
  bool rememberMe = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadRememberedLogin();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> enter() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      setState(() => error = 'Escribe correo y contrasena.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final tokenStorage = ref.read(tokenStorageProvider);
      await ref
          .read(authControllerProvider.notifier)
          .login(emailController.text, passwordController.text);
      if (rememberMe) {
        await tokenStorage.saveRememberedLogin(
          email: emailController.text,
          password: passwordController.text,
        );
      } else {
        await tokenStorage.clearRememberedLogin();
      }
      if (!mounted) return;
      final redirect = widget.redirectPath;
      context.go(
        redirect == null || redirect.trim().isEmpty ? '/projects' : redirect,
      );
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> loadRememberedLogin() async {
    final remembered = await ref
        .read(tokenStorageProvider)
        .getRememberedLogin();
    if (!mounted || remembered == null) return;
    setState(() {
      emailController.text = remembered.email;
      passwordController.text = remembered.password;
      rememberMe = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeader(
                      title: 'Bienvenido a GeoCampo',
                      subtitle: 'Gestiona mapas, lotes y trabajo de campo.',
                    ),
                    const SizedBox(height: 28),
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
                      hint: 'minimo 8 caracteres',
                      icon: Icons.lock_outline_rounded,
                      enabled: !loading,
                      obscureText: obscure,
                      onSubmitted: (_) => loading ? null : enter(),
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Mostrar clave' : 'Ocultar clave',
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    _RememberToggle(
                      value: rememberMe,
                      enabled: !loading,
                      onChanged: (value) {
                        setState(() {
                          rememberMe = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (error != null) _StatusBox(error!, isError: true),
                    PrimaryButton(
                      label: loading ? 'Iniciando...' : 'Iniciar sesion',
                      icon: Icons.login_rounded,
                      loading: loading,
                      onPressed: enter,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => context.go('/forgot-password'),
                      child: const Text('Olvide mi contrasena'),
                    ),
                    SecondaryButton(
                      label: 'Crear cuenta',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: loading ? null : () => context.go('/register'),
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

class _RememberToggle extends StatefulWidget {
  const _RememberToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  State<_RememberToggle> createState() => _RememberToggleState();
}

class _RememberToggleState extends State<_RememberToggle> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.value;
    return AnimatedScale(
      scale: pressed && widget.enabled ? .98 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Material(
        color: active ? AppColors.paleGreen : const Color(0xFFF7FAF7),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.enabled ? () => widget.onChanged(!widget.value) : null,
          onTapDown: widget.enabled
              ? (_) => setState(() => pressed = true)
              : null,
          onTapCancel: () => setState(() => pressed = false),
          onTapUp: (_) => setState(() => pressed = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? AppColors.primaryGreen.withValues(alpha: .42)
                    : const Color(0xFFD7E2DA),
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: active
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 140),
                    child: active
                        ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey('checked'),
                            color: Colors.white,
                            size: 17,
                          )
                        : const SizedBox(key: ValueKey('empty')),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Recordarme',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: active
                      ? AppColors.primaryGreen
                      : AppColors.textSecondary,
                ),
              ],
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
    final color = isError ? Colors.red : AppColors.primaryGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Text(
          message,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../widgets/app_button.dart';

class EnterShareCodeScreen extends StatefulWidget {
  const EnterShareCodeScreen({super.key});

  @override
  State<EnterShareCodeScreen> createState() => _EnterShareCodeScreenState();
}

class _EnterShareCodeScreenState extends State<EnterShareCodeScreen> {
  final controller = TextEditingController();
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void continueWithCode() {
    final code = controller.text.trim().toUpperCase().replaceAll(' ', '');

    if (code.isEmpty) {
      setState(() => error = 'Ingresa el codigo compartido.');
      return;
    }
    if (!code.startsWith('GC-')) {
      setState(() => error = 'El codigo debe iniciar con GC-.');
      return;
    }

    context.push('/share/project/$code');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar codigo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(
              Icons.password_rounded,
              size: 52,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 18),
            const Text(
              'Importar proyecto por codigo',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escribe el codigo que te compartieron para importar el proyecto a tu cuenta.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Codigo',
                hintText: 'GC-8F3K-92',
                prefixIcon: Icon(Icons.pin_rounded),
              ),
              onChanged: (_) {
                if (error != null) setState(() => error = null);
              },
              onSubmitted: (_) => continueWithCode(),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: const TextStyle(
                  color: AppColors.dangerRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 22),
            AppButton(
              label: 'Continuar',
              icon: Icons.arrow_forward_rounded,
              fullWidth: true,
              onPressed: continueWithCode,
            ),
          ],
        ),
      ),
    );
  }
}

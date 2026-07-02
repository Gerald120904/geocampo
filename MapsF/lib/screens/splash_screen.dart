import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../services/service_providers.dart';
import '../widgets/brand.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  late GoRouter router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    router = GoRouter.of(context);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authControllerProvider.notifier).restoreSession();
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      router.go(auth.isAuthenticated ? '/projects' : '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forestGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              const BrandMark(size: 94, light: true),
              const SizedBox(height: 24),
              const Text(
                'GeoCampo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mapas de campo offline',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Revisando sesión guardada…',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

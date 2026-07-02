import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../services/service_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          const Text(
            'Configuracion',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Personaliza GeoCampo para tu trabajo.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          const _GroupTitle('CUENTA'),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () => context.push('/profile'),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFEAF5EC),
                    child: Text(
                      _initials(user?.name ?? 'Usuario'),
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: Text(
                    user?.name ?? 'Usuario GeoCampo',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(user?.email ?? 'Cuenta activa'),
                  trailing: const Icon(Icons.chevron_right),
                ),
                const Divider(height: 1, indent: 66),
                _SettingTile(
                  Icons.edit_outlined,
                  'Editar nombre',
                  'Actualizar datos del perfil',
                  onTap: () => context.push('/profile'),
                ),
                const Divider(height: 1, indent: 66),
                _SettingTile(
                  Icons.password_outlined,
                  'Cambiar contrasena',
                  'Actualizar clave de acceso',
                  onTap: () => context.push('/change-password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _GroupTitle('SEGURIDAD'),
          Card(
            child: Column(
              children: [
                _SettingTile(
                  Icons.logout_rounded,
                  'Cerrar sesion',
                  'Salir de esta cuenta',
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _GroupTitle('UBICACION'),
          Card(
            child: Column(
              children: [
                _SettingTile(
                  Icons.location_on_outlined,
                  'Permiso de ubicacion',
                  'Revisar o solicitar acceso',
                  onTap: () => _checkLocationPermission(context),
                ),
                const Divider(height: 1, indent: 66),
                _SettingTile(
                  Icons.gps_fixed,
                  'Estado del GPS',
                  'Comprobar servicio del dispositivo',
                  onTap: () => _checkGpsStatus(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _checkLocationPermission(BuildContext context) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  final message = switch (permission) {
    LocationPermission.always ||
    LocationPermission.whileInUse => 'Permiso de ubicacion activo.',
    LocationPermission.denied => 'Permiso de ubicacion denegado.',
    LocationPermission.deniedForever =>
      'Permiso bloqueado. Revisalo en ajustes del sistema.',
    LocationPermission.unableToDetermine =>
      'No se pudo determinar el permiso de ubicacion.',
  };

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<void> _checkGpsStatus(BuildContext context) async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled ? 'GPS activo.' : 'El GPS esta desactivado.'),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 5, bottom: 9),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    ),
  );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile(this.icon, this.title, this.subtitle, {this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primaryGreen),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}

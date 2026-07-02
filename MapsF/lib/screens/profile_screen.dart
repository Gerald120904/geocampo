import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app/app_colors.dart';
import '../models/app_user.dart';
import '../services/service_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(authControllerProvider.notifier).refreshProfile(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Row(
              children: [
                IconButton.outlined(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Volver',
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Perfil',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                ),
                if (auth.isRefreshingProfile)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (user == null)
              const _EmptyProfileCard()
            else ...[
              _HeaderCard(user: user),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                _StatusCard(message: auth.error!),
              ],
              const SizedBox(height: 16),
              _ProfileInfo(user: user),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: auth.isSavingProfile
                    ? null
                    : () => _showEditProfileSheet(context, ref, user),
                icon: auth.isSavingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(
                  auth.isSavingProfile ? 'Guardando...' : 'Editar perfil',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('/change-password'),
                icon: const Icon(Icons.password_outlined),
                label: const Text('Cambiar contrasena'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesion'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.paleGreen,
              child: Text(
                _initials(user.name),
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final lastLogin = user.lastLoginAt;

    return Card(
      child: Column(
        children: [
          _InfoTile(icon: Icons.badge_outlined, label: 'Rol', value: user.role),
          const Divider(height: 1, indent: 66),
          _InfoTile(
            icon: Icons.business_outlined,
            label: 'Empresa',
            value: user.companyName ?? user.companyId ?? 'Sin empresa',
          ),
          const Divider(height: 1, indent: 66),
          _InfoTile(
            icon: user.isVerified
                ? Icons.verified_outlined
                : Icons.mark_email_unread_outlined,
            label: 'Estado verificado',
            value: user.isVerified ? 'Verificado' : 'Pendiente',
          ),
          if (lastLogin != null) ...[
            const Divider(height: 1, indent: 66),
            _InfoTile(
              icon: Icons.history_outlined,
              label: 'Ultimo inicio de sesion',
              value: DateFormat('dd/MM/yyyy HH:mm').format(lastLogin.toLocal()),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Icon(icon, color: AppColors.primaryGreen),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
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

class _EmptyProfileCard extends StatelessWidget {
  const _EmptyProfileCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('No hay usuario cargado.'),
      ),
    );
  }
}

Future<void> _showEditProfileSheet(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EditProfileSheet(user: user),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});

  final AppUser user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();

    if (name.length < 2) {
      setState(() => error = 'El nombre debe tener al menos 2 caracteres.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfileName(name)
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        saving = false;
        error =
            'El cambio se guardo lento o la app no recibio respuesta. Actualiza la pantalla.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        saving = false;
        error = 'No se pudo guardar el perfil.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Editar perfil',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            enabled: !saving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => saving ? null : _saveName(),
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(
                color: AppColors.dangerRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : _saveName,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(saving ? 'Guardando...' : 'Guardar'),
          ),
        ],
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

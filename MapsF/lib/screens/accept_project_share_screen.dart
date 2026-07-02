import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../models/shared_project_preview.dart';
import '../services/service_providers.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';

class AcceptProjectShareScreen extends ConsumerStatefulWidget {
  const AcceptProjectShareScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<AcceptProjectShareScreen> createState() =>
      _AcceptProjectShareScreenState();
}

class _AcceptProjectShareScreenState
    extends ConsumerState<AcceptProjectShareScreen> {
  bool loading = true;
  bool accepting = false;
  String? error;
  SharedProjectPreview? preview;
  String? importedProjectId;
  String? importedProjectName;

  @override
  void initState() {
    super.initState();
    loadPreview();
  }

  Future<void> loadPreview() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await ref
          .read(projectShareServiceProvider)
          .getPreview(widget.token);
      if (!mounted) return;
      setState(() {
        preview = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> accept() async {
    setState(() {
      accepting = true;
      error = null;
    });

    try {
      final hasToken = await ref.read(authServiceProvider).hasAccessToken();
      if (!hasToken) {
        if (!mounted) return;
        context.go(
          Uri(
            path: '/login',
            queryParameters: {'redirect': '/share/project/${widget.token}'},
          ).toString(),
        );
        return;
      }

      final response = await ref
          .read(projectShareServiceProvider)
          .acceptShare(widget.token);
      if (!mounted) return;
      final projectId = response['project_id'].toString();
      final projectName = response['project_name']?.toString() ?? 'Proyecto';

      ref.read(projectListRefreshProvider.notifier).markChanged();
      setState(() {
        importedProjectId = projectId;
        importedProjectName = projectName;
        accepting = false;
      });
      await showImportedProjectSheet(projectId, projectName);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        accepting = false;
      });
    }
  }

  Future<void> showImportedProjectSheet(
    String projectId,
    String projectName,
  ) async {
    await AppBottomSheet.show<void>(
      context: context,
      isDismissible: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBottomSheetHeader(
            icon: Icons.check_circle_rounded,
            title: 'Proyecto importado correctamente',
            message: '$projectName ya esta listo en tu cuenta.',
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Abrir proyecto',
            icon: Icons.folder_open_rounded,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/projects/$projectId');
            },
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Ver proyectos',
            icon: Icons.folder_copy_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/projects');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = preview;
    final projectId = importedProjectId;
    final projectName = importedProjectName;

    return Scaffold(
      appBar: AppBar(title: const Text('Proyecto compartido')),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (error != null) ...[
                    Text(
                      error!,
                      style: const TextStyle(color: AppColors.dangerRed),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Reintentar',
                      icon: Icons.refresh_rounded,
                      onPressed: loadPreview,
                    ),
                  ],
                  if (item != null && projectId == null) ...[
                    const Icon(
                      Icons.folder_shared_outlined,
                      size: 48,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '${item.ownerName} te compartio un proyecto',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.projectName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.projectDescription != null &&
                        item.projectDescription!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.projectDescription!,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.mapsCount} mapas disponibles',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Se importara una copia a tu cuenta. El proyecto original no se modifica.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      label: accepting
                          ? 'Importando...'
                          : 'Importar a mi cuenta',
                      icon: Icons.download_done_rounded,
                      loading: accepting,
                      fullWidth: true,
                      onPressed: accepting ? null : accept,
                    ),
                  ],
                  if (projectId != null) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 54,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      projectName == null
                          ? 'Proyecto importado correctamente'
                          : '$projectName importado correctamente',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      label: 'Abrir proyecto',
                      icon: Icons.folder_open_rounded,
                      fullWidth: true,
                      onPressed: () => context.go('/projects/$projectId'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

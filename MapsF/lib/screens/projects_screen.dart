import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app/app_colors.dart';
import '../models/project.dart';
import '../services/service_providers.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon_button.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  late Future<List<Project>> future;
  String? pendingDeleteProjectId;
  final locallyDeletedProjectIds = <String>{};

  @override
  void initState() {
    super.initState();
    future = _loadProjects();
  }

  Future<void> reload() async {
    setState(() {
      future = _loadProjects();
    });
    await future;
  }

  Future<List<Project>> _loadProjects() async {
    final projects = await ref.read(projectServiceProvider).listProjects();
    return projects
        .where((project) => !locallyDeletedProjectIds.contains(project.id))
        .toList();
  }

  Future<void> saveProject({Project? project}) async {
    final result = await showDialog<_ProjectFormResult>(
      context: context,
      builder: (_) => _ProjectFormDialog(project: project),
    );
    if (result == null) return;

    try {
      final service = ref.read(projectServiceProvider);
      if (project == null) {
        final companies = await ref
            .read(companyServiceProvider)
            .listCompanies();
        final company = companies.isNotEmpty
            ? companies.first
            : await ref
                  .read(companyServiceProvider)
                  .createCompany(
                    name: 'GeoCampo',
                    legalName: 'GeoCampo',
                    identifier: 'geocampo',
                  );
        await service.createProject(
          companyId: company.id,
          name: result.name,
          description: result.description,
        );
      } else {
        await service.updateProject(
          projectId: project.id,
          name: result.name,
          description: result.description,
        );
      }
      await reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> deleteProject(Project project) async {
    try {
      await ref.read(projectServiceProvider).deleteProject(project.id);
      if (!mounted) return;
      setState(() {
        locallyDeletedProjectIds.add(project.id);
        pendingDeleteProjectId = null;
      });
      await reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(projectListRefreshProvider, (previous, next) {
      if (previous != next && mounted) reload();
    });

    final user = ref.watch(authControllerProvider).user;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Proyectos',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        user == null ? 'GeoCampo' : user.email,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: Icons.password_rounded,
                  tooltip: 'Ingresar codigo',
                  tone: AppIconButtonTone.open,
                  onPressed: () => context.push('/share/code'),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => saveProject(),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  tooltip: 'Crear proyecto',
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout),
                  tooltip: 'Cerrar sesion',
                ),
              ],
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<Project>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 90),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _ErrorCard(
                    message: snapshot.error.toString(),
                    onRetry: reload,
                  );
                }

                final projects = snapshot.data ?? [];
                if (projects.isEmpty) {
                  return _EmptyProjects(onCreate: () => saveProject());
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 860 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: pendingDeleteProjectId == null
                            ? 230
                            : 300,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        return _ProjectCard(
                              project: project,
                              onOpen: () =>
                                  context.go('/projects/${project.id}'),
                              onEdit: () => saveProject(project: project),
                              confirmingDelete:
                                  pendingDeleteProjectId == project.id,
                              onAskDelete: () => setState(
                                () => pendingDeleteProjectId = project.id,
                              ),
                              onCancelDelete: () =>
                                  setState(() => pendingDeleteProjectId = null),
                              onConfirmDelete: () => deleteProject(project),
                            )
                            .animate()
                            .fadeIn(duration: 260.ms)
                            .slideY(
                              begin: .04,
                              end: 0,
                              duration: 260.ms,
                              curve: Curves.easeOutCubic,
                            );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onEdit,
    required this.confirmingDelete,
    required this.onAskDelete,
    required this.onCancelDelete,
    required this.onConfirmDelete,
  });

  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final bool confirmingDelete;
  final VoidCallback onAskDelete;
  final VoidCallback onCancelDelete;
  final VoidCallback onConfirmDelete;

  @override
  Widget build(BuildContext context) {
    final updated = project.updatedAt == null
        ? 'Sin actualizacion'
        : DateFormat('dd/MM/yyyy HH:mm').format(project.updatedAt!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_copy, color: AppColors.primaryGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              project.description ?? 'Sin descripcion',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(label: 'Mapas', value: project.mapsCount.toString()),
                _Metric(
                  label: 'Listos',
                  value: project.readyMapsCount.toString(),
                  color: AppColors.primaryGreen,
                ),
                _Metric(
                  label: 'Procesando',
                  value: project.processingMapsCount.toString(),
                  color: AppColors.warningYellow,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Actualizado: $updated',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AppButton(
                  label: 'Abrir',
                  icon: Icons.open_in_new_rounded,
                  onPressed: onOpen,
                ),
                const SizedBox(width: 8),
                AppIconButton(
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                  tooltip: 'Editar',
                  tone: AppIconButtonTone.edit,
                ),
                const SizedBox(width: 8),
                AppIconButton(
                  icon: Icons.delete_outline,
                  onPressed: onAskDelete,
                  tooltip: 'Eliminar',
                  tone: AppIconButtonTone.danger,
                ),
              ],
            ),
            if (confirmingDelete) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Eliminar tambien ocultara ${project.mapsCount} mapas.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onCancelDelete,
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: onConfirmDelete,
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: effectiveColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProjectFormResult {
  const _ProjectFormResult({required this.name, this.description});

  final String name;
  final String? description;
}

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({this.project});

  final Project? project;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  late final nameController = TextEditingController(
    text: widget.project?.name ?? '',
  );
  late final descriptionController = TextEditingController(
    text: widget.project?.description ?? '',
  );
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void submit() {
    final name = nameController.text.trim();
    if (name.length < 2) {
      setState(() => error = 'El nombre debe tener al menos 2 caracteres.');
      return;
    }
    Navigator.of(context, rootNavigator: true).pop(
      _ProjectFormResult(
        name: name,
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.project == null ? 'Crear proyecto' : 'Editar proyecto',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripcion'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: AppColors.dangerRed)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No hay proyectos disponibles.',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Crear proyecto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(message),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

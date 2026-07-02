import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../models/project_detail.dart';
import '../models/remote_map.dart';
import '../services/service_providers.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/status_chip.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.highlightedMapId,
  });

  final String projectId;
  final String? highlightedMapId;

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  ProjectDetail? project;
  bool loading = true;
  bool silentReloading = false;
  String? error;
  final selectedMapIds = <String>{};
  bool selectionMode = false;
  String? pendingDeleteMapId;
  String? highlightedMapId;
  bool waitingForHighlightedMap = false;
  DateTime? forceRefreshUntil;
  Timer? processingTimer;

  @override
  void initState() {
    super.initState();
    applyHighlightedMap(widget.highlightedMapId);
    loadProject();
  }

  @override
  void didUpdateWidget(covariant ProjectDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.highlightedMapId != widget.highlightedMapId) {
      applyHighlightedMap(widget.highlightedMapId);
      processingTimer?.cancel();
      processingTimer = null;
      project = null;
      loadProject();
    }
  }

  void applyHighlightedMap(String? mapId) {
    highlightedMapId = mapId;
    waitingForHighlightedMap = mapId != null;
    forceRefreshUntil = mapId == null
        ? null
        : DateTime.now().add(const Duration(minutes: 5));
  }

  @override
  void dispose() {
    processingTimer?.cancel();
    super.dispose();
  }

  Future<void> loadProject({bool silent = false}) async {
    if (silentReloading) return;

    if (!silent && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    silentReloading = true;
    try {
      final loadedProject = await ref
          .read(projectServiceProvider)
          .getProject(widget.projectId);
      prunePendingMaps(loadedProject);
      if (!mounted) return;
      setState(() {
        project = loadedProject;
        loading = false;
        error = null;
      });
      if (highlightedMapId != null) {
        final appeared = loadedProject.maps.any(
          (map) => map.id == highlightedMapId,
        );
        if (appeared && waitingForHighlightedMap) {
          setState(() => waitingForHighlightedMap = false);
          Future<void>.delayed(const Duration(seconds: 7), () {
            if (mounted) setState(() => highlightedMapId = null);
          });
        }
      }
      syncProcessingTimer(loadedProject);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    } finally {
      silentReloading = false;
    }
  }

  void prunePendingMaps(ProjectDetail project) {
    final pendingByProject = ref.read(pendingProjectMapsProvider);
    final pending = pendingByProject[widget.projectId] ?? const <RemoteMap>[];
    if (pending.isEmpty) return;

    final realIds = project.maps.map((map) => map.id).toSet();
    final now = DateTime.now();
    final remaining = pending.where((map) {
      if (realIds.contains(map.id)) return false;
      final createdAt = map.createdAt;
      return createdAt == null || now.difference(createdAt).inMinutes < 10;
    }).toList();

    if (remaining.length == pending.length) return;
    ref
        .read(pendingProjectMapsProvider.notifier)
        .replace(widget.projectId, remaining);
  }

  void syncProcessingTimer(ProjectDetail loadedProject) {
    final pendingMaps =
        ref.read(pendingProjectMapsProvider)[widget.projectId] ??
        const <RemoteMap>[];
    final hasActiveMaps = loadedProject.maps.any((map) => map.isProcessing);
    final waitingForNewMap =
        highlightedMapId != null &&
        !loadedProject.maps.any((map) => map.id == highlightedMapId);
    final forceRefreshActive =
        forceRefreshUntil != null &&
        DateTime.now().isBefore(forceRefreshUntil!);
    if (!hasActiveMaps &&
        !waitingForNewMap &&
        !forceRefreshActive &&
        pendingMaps.isEmpty) {
      processingTimer?.cancel();
      processingTimer = null;
      return;
    }
    processingTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => loadProject(silent: true),
    );
  }

  Future<void> reload() async {
    await loadProject();
  }

  Future<void> deleteMap(RemoteMap map) async {
    try {
      await ref.read(mapServiceProvider).deleteMap(map.id);
      if (!mounted) return;
      setState(() => pendingDeleteMapId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El mapa fue eliminado correctamente.')),
      );
      await reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> retryMap(RemoteMap map) async {
    try {
      await ref.read(mapServiceProvider).retryMap(map.id);
      if (!mounted) return;
      context.push('/maps/${map.id}/processing');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> optimizeMap(RemoteMap map) async {
    try {
      await ref.read(mapServiceProvider).optimizeMap(map.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Optimizacion iniciada.')));
      await reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void openSelected() {
    if (selectedMapIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un mapa listo.')),
      );
      return;
    }
    context.push(
      '/projects/${widget.projectId}/viewer?map_ids=${selectedMapIds.join(',')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading && project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del proyecto')),
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (error != null && project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del proyecto')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: reload,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentProject = project!;
    final pendingMaps =
        ref.watch(pendingProjectMapsProvider)[widget.projectId] ??
        const <RemoteMap>[];
    final displayedMaps = _mergeMaps(currentProject.maps, pendingMaps);
    final readyMaps = displayedMaps.where((map) => map.isReady);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del proyecto')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                currentProject.name,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (currentProject.description != null) ...[
                const SizedBox(height: 6),
                Text(
                  currentProject.description!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SummaryTile('Mapas', displayedMaps.length.toString()),
                  _SummaryTile(
                    'Listos',
                    displayedMaps.where((map) => map.isReady).length.toString(),
                  ),
                  _SummaryTile(
                    'Procesando',
                    displayedMaps
                        .where((map) => map.isProcessing)
                        .length
                        .toString(),
                  ),
                  _SummaryTile(
                    'Con error',
                    displayedMaps
                        .where((map) => map.isFailed)
                        .length
                        .toString(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AppButton(
                    label: 'Agregar mapa',
                    icon: Icons.add_rounded,
                    onPressed: () =>
                        context.push('/projects/${currentProject.id}/upload'),
                  ),
                  AppButton(
                    label: 'Abrir todos',
                    icon: Icons.layers_outlined,
                    variant: AppButtonVariant.ghost,
                    onPressed: readyMaps.isEmpty
                        ? null
                        : () => context.push(
                            '/projects/${currentProject.id}/viewer',
                          ),
                  ),
                  AppButton(
                    label: selectionMode ? 'Cancelar seleccion' : 'Seleccionar',
                    icon: selectionMode
                        ? Icons.close_rounded
                        : Icons.checklist_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => setState(() {
                      selectionMode = !selectionMode;
                      selectedMapIds.clear();
                    }),
                  ),
                  AppButton(
                    label: 'Compartir',
                    icon: Icons.ios_share_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.push(
                      Uri(
                        path: '/projects/${currentProject.id}/share',
                        queryParameters: {
                          'name': currentProject.name,
                          'ready_maps': currentProject.readyMapsCount
                              .toString(),
                        },
                      ).toString(),
                    ),
                  ),
                  if (selectionMode)
                    FilledButton.icon(
                      onPressed: openSelected,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir seleccionados'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (waitingForHighlightedMap && pendingMaps.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _PendingMapCard(),
                ),
              if (displayedMaps.isEmpty && !waitingForHighlightedMap)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Este proyecto todavia no tiene mapas.'),
                  ),
                )
              else if (displayedMaps.isNotEmpty)
                ...displayedMaps.map(
                  (map) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProjectMapRow(
                      map: map,
                      highlighted: highlightedMapId == map.id,
                      selected: selectedMapIds.contains(map.id),
                      selectionMode: selectionMode,
                      onSelectedChanged: map.isReady
                          ? (value) => setState(() {
                              if (value == true) {
                                selectedMapIds.add(map.id);
                              } else {
                                selectedMapIds.remove(map.id);
                              }
                            })
                          : null,
                      onOpen: () => context.push('/maps/${map.id}/viewer'),
                      onDownload: () => context.push('/maps/${map.id}'),
                      confirmingDelete: pendingDeleteMapId == map.id,
                      onAskDelete: () =>
                          setState(() => pendingDeleteMapId = map.id),
                      onCancelDelete: () =>
                          setState(() => pendingDeleteMapId = null),
                      onConfirmDelete: () => deleteMap(map),
                      onRetry: () => retryMap(map),
                      onOptimize: () => optimizeMap(map),
                      onReviewDuplicate: () =>
                          context.push('/maps/${map.id}/duplicate-review'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

List<RemoteMap> _mergeMaps(
  List<RemoteMap> realMaps,
  List<RemoteMap> pendingMaps,
) {
  if (pendingMaps.isEmpty) return realMaps;
  final realIds = realMaps.map((map) => map.id).toSet();
  return [
    ...pendingMaps.where((map) => !realIds.contains(map.id)),
    ...realMaps,
  ];
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: .08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingMapCard extends StatelessWidget {
  const _PendingMapCard();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        color: AppColors.paleGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.primaryGreen.withValues(alpha: .24),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recibiendo mapa',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Lo estamos agregando al proyecto. Aparecera aqui en unos segundos.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectMapRow extends StatelessWidget {
  const _ProjectMapRow({
    required this.map,
    required this.highlighted,
    required this.selected,
    required this.selectionMode,
    required this.onSelectedChanged,
    required this.onOpen,
    required this.onDownload,
    required this.confirmingDelete,
    required this.onAskDelete,
    required this.onCancelDelete,
    required this.onConfirmDelete,
    required this.onRetry,
    required this.onOptimize,
    required this.onReviewDuplicate,
  });

  final RemoteMap map;
  final bool highlighted;
  final bool selected;
  final bool selectionMode;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final bool confirmingDelete;
  final VoidCallback onAskDelete;
  final VoidCallback onCancelDelete;
  final VoidCallback onConfirmDelete;
  final VoidCallback onRetry;
  final VoidCallback onOptimize;
  final VoidCallback onReviewDuplicate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: highlighted ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final glow = 1 - value;
        return Transform.translate(
          offset: Offset(0, 10 * glow),
          child: Card(
            color: Color.lerp(
              AppColors.paleGreen,
              Theme.of(context).cardColor,
              value,
            ),
            elevation: highlighted ? 2 + (6 * glow) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: AppColors.primaryGreen.withValues(
                  alpha: highlighted ? .24 + (.36 * glow) : .06,
                ),
              ),
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 640;
                final actions = _buildActions(context);
                final mapInfo = _MapRowInfo(map: map);

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (selectionMode)
                            Checkbox(
                              value: selected,
                              onChanged: onSelectedChanged,
                            ),
                          _MapPreviewThumbnail(map: map),
                          const SizedBox(width: 12),
                          Expanded(child: mapInfo),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusChip(map: map),
                          ...actions,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (selectionMode)
                      Checkbox(value: selected, onChanged: onSelectedChanged),
                    _MapPreviewThumbnail(map: map),
                    const SizedBox(width: 14),
                    Expanded(child: mapInfo),
                    const SizedBox(width: 12),
                    _StatusChip(map: map),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actions,
                    ),
                  ],
                );
              },
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
                        'El mapa sera eliminado de la vista normal.',
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

  List<Widget> _buildActions(BuildContext context) {
    if (map.canOpen) {
      return [
        AppIconButton(
          onPressed: onOpen,
          icon: Icons.open_in_new,
          tone: AppIconButtonTone.open,
          tooltip: map.viewMode == 'quick' ? 'Abrir vista rapida' : 'Abrir',
        ),
        if (map.optimizedAvailable)
          AppIconButton(
            onPressed: onDownload,
            icon: Icons.download_outlined,
            tone: AppIconButtonTone.download,
            tooltip: 'Descargar',
          ),
        if (map.isOptimizing)
          OutlinedButton(
            onPressed: () => context.push('/maps/${map.id}/processing'),
            child: const Text('Ver estado'),
          ),
        if (map.canOptimize)
          AppButton(
            label: 'Optimizar',
            onPressed: onOptimize,
            icon: Icons.auto_fix_high_rounded,
          ),
        AppIconButton(
          onPressed: onAskDelete,
          icon: Icons.delete_outline,
          tone: AppIconButtonTone.danger,
          tooltip: 'Eliminar',
        ),
      ];
    }

    if (map.isDuplicateReview) {
      return [
        FilledButton(
          onPressed: onReviewDuplicate,
          child: const Text('Revisar'),
        ),
      ];
    }

    if (map.isFailed) {
      return [
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        AppIconButton(
          onPressed: onAskDelete,
          icon: Icons.delete_outline,
          tone: AppIconButtonTone.danger,
          tooltip: 'Eliminar',
        ),
      ];
    }

    return [
      OutlinedButton(
        onPressed: () => context.push('/maps/${map.id}/processing'),
        child: const Text('Ver estado'),
      ),
    ];
  }
}

class _MapRowInfo extends StatelessWidget {
  const _MapRowInfo({required this.map});

  final RemoteMap map;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          map.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          map.sourceType,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        if (map.processingMessage != null ||
            map.processingProgress != null) ...[
          const SizedBox(height: 6),
          Text(
            [
              if (map.processingProgress != null)
                '${map.processingProgress!.clamp(0, 100)}%',
              if (map.processingMessage != null) map.processingMessage!,
            ].join(' ? '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _MapPreviewThumbnail extends ConsumerStatefulWidget {
  const _MapPreviewThumbnail({required this.map});

  final RemoteMap map;

  @override
  ConsumerState<_MapPreviewThumbnail> createState() =>
      _MapPreviewThumbnailState();
}

class _MapPreviewThumbnailState extends ConsumerState<_MapPreviewThumbnail> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPreview();
  }

  @override
  void didUpdateWidget(covariant _MapPreviewThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.map.id != widget.map.id ||
        oldWidget.map.previewUrl != widget.map.previewUrl) {
      _future = _loadPreview();
    }
  }

  Future<Uint8List?> _loadPreview() async {
    if (widget.map.previewUrl == null) return null;
    return ref.read(mapServiceProvider).downloadPreview(widget.map.id);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 112,
        height: 72,
        child: FutureBuilder<Uint8List?>(
          future: _future,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes != null && bytes.isNotEmpty) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes, fit: BoxFit.cover),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.black.withValues(alpha: .08),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                widget.map.previewUrl != null) {
              return Container(
                color: AppColors.paleGreen,
                alignment: Alignment.center,
                child: const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            return Container(
              color: AppColors.paleGreen,
              alignment: Alignment.center,
              child: Icon(
                widget.map.isReady
                    ? Icons.image_not_supported_outlined
                    : Icons.hourglass_top_rounded,
                color: AppColors.primaryGreen,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.map});

  final RemoteMap map;

  @override
  Widget build(BuildContext context) {
    final color = map.isReady
        ? AppColors.primaryGreen
        : map.isFailed
        ? AppColors.dangerRed
        : map.isDuplicateReview
        ? AppColors.gpsBlue
        : map.isRawReady
        ? AppColors.gpsBlue
        : map.isQuickReady
        ? AppColors.gpsBlue
        : AppColors.warningYellow;
    return StatusChip(
      label: map.processingStatusLabel,
      color: color,
      pulse: map.isProcessing || map.isOptimizing,
      bounceOnBuild: map.isFailed,
    );
  }
}

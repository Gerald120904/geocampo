import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../models/remote_map.dart';
import '../services/service_providers.dart';
import '../widgets/app_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_banner.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_search_field.dart';

class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key, required this.projectId, this.projectName});

  final String projectId;
  final String? projectName;

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  String query = '';
  List<RemoteMap> maps = const [];
  bool loading = true;
  bool silentReloading = false;
  String? error;
  Timer? processingTimer;

  @override
  void initState() {
    super.initState();
    loadMaps();
  }

  @override
  void didUpdateWidget(covariant MapsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      processingTimer?.cancel();
      processingTimer = null;
      maps = const [];
      loadMaps();
    }
  }

  @override
  void dispose() {
    processingTimer?.cancel();
    super.dispose();
  }

  Future<void> loadMaps({bool silent = false}) async {
    if (silentReloading) return;

    if (!silent && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    silentReloading = true;
    try {
      final loadedMaps = await ref
          .read(mapServiceProvider)
          .listProjectMaps(widget.projectId);
      if (!mounted) return;
      setState(() {
        maps = loadedMaps;
        loading = false;
        error = null;
      });
      syncProcessingTimer(loadedMaps);
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

  void syncProcessingTimer(List<RemoteMap> loadedMaps) {
    final hasProcessingMap = loadedMaps.any((map) => map.isProcessing);

    if (!hasProcessingMap) {
      processingTimer?.cancel();
      processingTimer = null;
      return;
    }

    processingTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => loadMaps(silent: true),
    );
  }

  Future<void> reload() async {
    await loadMaps();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.projectName ?? 'Mapas',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Mapas cargados desde el backend',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Subir',
                  icon: Icons.add_rounded,
                  onPressed: () => context.go('/upload'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: AppSearchField(
              hintText: 'Buscar mapa...',
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: reload, child: _buildMapList()),
          ),
        ],
      ),
    );
  }

  Widget _buildMapList() {
    if (loading && maps.isEmpty) {
      return const AppLoadingState(
        title: 'Cargando mapas',
        steps: [
          'Consultando backend',
          'Validando estados',
          'Preparando tarjetas',
        ],
      );
    }

    if (error != null && maps.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppErrorBanner(
            title: 'No se pudieron cargar los mapas',
            message:
                'La conexion con el backend fallo. Revisa tu sesion o intenta de nuevo.',
            actionLabel: 'Reintentar',
            onAction: reload,
          ),
        ],
      );
    }

    final filteredMaps = maps
        .where((map) => map.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (filteredMaps.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppEmptyState(
            icon: Icons.map_outlined,
            title: query.isEmpty ? 'Todavia no tienes mapas' : 'Sin resultados',
            message: query.isEmpty
                ? 'Importa un archivo del terreno para empezar a trabajar con capas, lotes y GPS.'
                : 'No encontramos mapas con ese nombre. Prueba con otra busqueda.',
            actionLabel: query.isEmpty ? 'Subir mapa' : null,
            onAction: query.isEmpty ? () => context.go('/upload') : null,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 176,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filteredMaps.length,
          itemBuilder: (context, index) => _MapCard(map: filteredMaps[index]),
        );
      },
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.map});

  final RemoteMap map;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/maps/${map.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 108,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGreen, AppColors.forestGreen],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: MiniMapPainter()),
                    ),
                    Center(
                      child: Icon(
                        map.isReady ? Icons.map : Icons.hourglass_top,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      map.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${map.sourceType} Â· ${map.status}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (map.processingMessage != null ||
                        map.processingProgress != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (map.processingProgress != null)
                            '${map.processingProgress!.clamp(0, 100)}%',
                          if (map.processingMessage != null)
                            map.processingMessage!,
                        ].join(' Â· '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.warningYellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        _StatusChip(map: map),
                        const Spacer(),
                        const Icon(Icons.chevron_right),
                      ],
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.map});

  final RemoteMap map;

  @override
  Widget build(BuildContext context) {
    final color = map.isReady
        ? AppColors.primaryGreen
        : map.isFailed
        ? AppColors.dangerRed
        : map.isRawReady
        ? AppColors.gpsBlue
        : map.isQuickReady
        ? AppColors.gpsBlue
        : AppColors.warningYellow;
    final label = map.processingStatusLabel;
    /*
    final oldLabel = map.isReady
        ? 'LISTO'
        : map.isFailed
        ? 'FALLÃ“'
        : map.isProcessing && map.processingProgress != null
        ? 'PROCESANDO Â· ${map.processingProgress!.clamp(0, 100)}%'
        : 'PROCESANDO';
    */

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .22)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = Colors.white.withValues(alpha: .08);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * .28)
        ..lineTo(size.width * .35, size.height * .13)
        ..lineTo(size.width * .72, size.height * .3)
        ..lineTo(size.width, size.height * .2)
        ..lineTo(size.width, size.height * .62)
        ..lineTo(size.width * .62, size.height * .76)
        ..lineTo(size.width * .2, size.height * .59)
        ..close(),
      fill,
    );
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(size.width * i / 4, 0),
        Offset(size.width * (i - 1) / 4, size.height),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

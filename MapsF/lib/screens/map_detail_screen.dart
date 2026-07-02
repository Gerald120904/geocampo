import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../models/map_detail.dart';
import '../models/map_status.dart';
import '../services/service_providers.dart';

class MapDetailScreen extends ConsumerStatefulWidget {
  const MapDetailScreen({super.key, required this.mapId});

  final String mapId;

  @override
  ConsumerState<MapDetailScreen> createState() => _MapDetailScreenState();
}

class _MapDetailScreenState extends ConsumerState<MapDetailScreen> {
  bool loading = true;
  bool downloading = false;
  double downloadProgress = 0;
  String? error;
  MapDetail? detail;
  MapStatus? status;
  Timer? timer;
  String? savedOfflineMap;

  @override
  void initState() {
    super.initState();
    load();
    startPolling();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startPolling() {
    timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final current = status?.status;
      if (current == 'queued' || current == 'processing') {
        await loadStatusOnly();
      }
    });
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final mapService = ref.read(mapServiceProvider);
      final loadedDetail = await mapService.getMapDetail(widget.mapId);
      final loadedStatus = await mapService.getMapStatus(widget.mapId);

      setState(() {
        detail = loadedDetail;
        status = loadedStatus;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> loadStatusOnly() async {
    try {
      final loadedStatus = await ref
          .read(mapServiceProvider)
          .getMapStatus(widget.mapId);
      if (!mounted) return;
      setState(() => status = loadedStatus);
      if (loadedStatus.status == 'ready') await load();
    } catch (_) {}
  }

  Future<void> process() async {
    try {
      await ref.read(mapServiceProvider).startProcessing(widget.mapId);
      await load();
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> saveOffline() async {
    final map = detail;
    if (map == null) return;

    setState(() {
      downloading = true;
      downloadProgress = 0;
      error = null;
    });

    try {
      final localMap = await ref
          .read(packageServiceProvider)
          .saveMapOffline(
            mapId: map.id,
            onProgress: (received, total) {
              if (total > 0 && mounted) {
                setState(() => downloadProgress = received / total);
              }
            },
          );

      setState(() {
        savedOfflineMap = localMap.name;
        downloading = false;
        downloadProgress = 1;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mapa guardado para usar sin internet.'),
        ),
      );
      context.push('/viewer/${localMap.id}');
    } catch (e) {
      setState(() {
        error = e.toString();
        downloading = false;
      });
    }
  }

  String statusText(String status) {
    switch (status) {
      case 'uploaded':
        return 'Archivo subido';
      case 'queued':
        return 'En cola de procesamiento';
      case 'processing':
        return 'Procesando mapa';
      case 'ready':
        return 'Mapa listo';
      case 'failed':
        return 'Falló el procesamiento';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = detail;
    final mapStatus = status;

    return Scaffold(
      appBar: AppBar(title: Text(map?.name ?? 'Mapa')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _ErrorView(message: error!, onRetry: load)
          : map == null
          ? const Center(child: Text('Mapa no encontrado'))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    map.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    map.description ?? 'Sin descripción',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estado',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            statusText(mapStatus?.status ?? map.status),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (mapStatus?.job != null) ...[
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value:
                                  mapStatus!.job!.progress.clamp(0, 100) / 100,
                            ),
                            const SizedBox(height: 8),
                            Text(mapStatus.job!.step),
                            if (mapStatus.job!.errorMessage != null)
                              Text(
                                mapStatus.job!.errorMessage!,
                                style: TextStyle(color: Colors.red.shade800),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información GIS',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('Tipo: ${map.sourceType}'),
                          Text('Capas: ${map.layers.length}'),
                          Text(
                            'Paquete disponible: ${map.packageAvailable ? "Sí" : "No"}',
                          ),
                          if (map.center != null)
                            Text(
                              'Centro: ${map.center!.lat.toStringAsFixed(6)}, ${map.center!.lng.toStringAsFixed(6)}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (map.layers.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Capas',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...map.layers.map(
                              (layer) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.layers),
                                title: Text(layer.name),
                                subtitle: Text(
                                  '${layer.layerType} · ${layer.featureCount} elementos',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  if (map.status == 'uploaded' || mapStatus?.status == 'failed')
                    FilledButton.icon(
                      onPressed: process,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Procesar mapa'),
                    ),
                  if (map.status == 'ready' ||
                      mapStatus?.status == 'ready') ...[
                    FilledButton.icon(
                      onPressed: downloading ? null : saveOffline,
                      icon: const Icon(Icons.download_for_offline_rounded),
                      label: Text(
                        downloading
                            ? 'Guardando ${(downloadProgress * 100).toStringAsFixed(0)}%'
                            : 'Guardar offline',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/viewer/${map.id}'),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Abrir visor'),
                    ),
                  ],
                  if (downloading) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: downloadProgress),
                  ],
                  if (savedOfflineMap != null) ...[
                    const SizedBox(height: 14),
                    Card(
                      color: AppColors.paleGreen,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Mapa guardado para usar sin internet:\n$savedOfflineMap',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: Colors.red.shade50,
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

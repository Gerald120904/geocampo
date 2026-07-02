import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../models/map_status.dart';
import '../services/service_providers.dart';

class MapProcessingScreen extends ConsumerStatefulWidget {
  const MapProcessingScreen({super.key, required this.mapId});

  final String mapId;

  @override
  ConsumerState<MapProcessingScreen> createState() =>
      _MapProcessingScreenState();
}

class _MapProcessingScreenState extends ConsumerState<MapProcessingScreen> {
  final stopwatch = Stopwatch();
  Timer? timer;
  MapStatus? status;
  String? error;
  bool downloading = false;
  double downloadProgress = 0;

  static const slowWarningThreshold = Duration(seconds: 90);

  @override
  void initState() {
    super.initState();
    stopwatch.start();
    poll();
  }

  @override
  void dispose() {
    timer?.cancel();
    stopwatch.stop();
    super.dispose();
  }

  Duration nextInterval() {
    final seconds = stopwatch.elapsed.inSeconds;
    if (seconds < 30) return const Duration(milliseconds: 1500);
    if (seconds < 120) return const Duration(seconds: 3);
    return const Duration(seconds: 6);
  }

  Future<void> poll() async {
    timer?.cancel();
    try {
      final loadedStatus = await ref
          .read(mapServiceProvider)
          .getMapStatus(widget.mapId);
      if (!mounted) return;
      setState(() {
        status = loadedStatus;
        error = null;
      });

      if (loadedStatus.status == 'ready') {
        if (kIsWeb) {
          context.go('/viewer/${widget.mapId}');
        } else {
          await downloadAndOpen();
        }
        return;
      }
      if (loadedStatus.status == 'duplicate_review') {
        context.go('/maps/${widget.mapId}/duplicate-review');
        return;
      }
      if (loadedStatus.status == 'failed') {
        setState(() {
          error = loadedStatus.job?.errorMessage ?? 'Fallo el procesamiento.';
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }

    if (!mounted) return;
    timer = Timer(nextInterval(), poll);
  }

  Future<void> downloadAndOpen() async {
    if (downloading) return;
    setState(() {
      downloading = true;
      downloadProgress = 0;
    });

    try {
      final localMap = await ref
          .read(packageServiceProvider)
          .saveMapOffline(
            mapId: widget.mapId,
            onProgress: (received, total) {
              if (!mounted || total <= 0) return;
              setState(() => downloadProgress = received / total);
            },
          );
      if (!mounted) return;
      context.go('/viewer/${localMap.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        downloading = false;
      });
    }
  }

  bool get isTakingLong =>
      stopwatch.elapsed > slowWarningThreshold && !downloading;

  @override
  Widget build(BuildContext context) {
    final rawProgress = status?.job?.progress ?? 0;
    final percent = downloading
        ? (downloadProgress * 100).clamp(0, 100).round()
        : rawProgress.clamp(0, 100);
    final currentStep = downloading
        ? 'Descargando paquete offline'
        : status?.job?.step ?? 'Esperando procesamiento';
    final progress = downloading
        ? downloadProgress
        : (percent == 0 ? null : percent / 100);

    return Scaffold(
      appBar: AppBar(title: const Text('Procesando mapa')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Preparando tu mapa offline',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb
                        ? 'Puedes dejar esta pantalla abierta. Cuando el mapa este listo, abriremos el visor web automaticamente.'
                        : 'Puedes dejar esta pantalla abierta. Cuando el mapa este listo, lo guardaremos para usar sin internet y abriremos el visor automaticamente.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ProcessingStatusCard(
                    progress: progress,
                    percentLabel: '$percent%',
                    title: currentStep,
                    subtitle: downloading
                        ? 'Guardando en este dispositivo'
                        : 'Procesando en el servidor',
                    icon: downloading
                        ? Icons.download_rounded
                        : Icons.map_outlined,
                    showSlowWarning: isTakingLong,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text(error!),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: poll,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProcessingStatusCard extends StatelessWidget {
  const _ProcessingStatusCard({
    required this.progress,
    required this.percentLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.showSlowWarning,
  });

  final double? progress;
  final String percentLabel;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool showSlowWarning;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.primaryGreen.withValues(alpha: .16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              percentLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primaryGreen, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox.square(
                  dimension: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: AppColors.primaryGreen.withValues(
                          alpha: .12,
                        ),
                      ),
                      Text(
                        percentLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            if (showSlowWarning) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Archivo grande. Seguimos procesando, no cierres la app.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade900,
                        ),
                      ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../models/duplicate_review.dart';
import '../services/service_providers.dart';

class DuplicateMapReviewScreen extends ConsumerStatefulWidget {
  const DuplicateMapReviewScreen({super.key, required this.mapId});

  final String mapId;

  @override
  ConsumerState<DuplicateMapReviewScreen> createState() =>
      _DuplicateMapReviewScreenState();
}

class _DuplicateMapReviewScreenState
    extends ConsumerState<DuplicateMapReviewScreen> {
  late Future<DuplicateReview> future;
  bool resolving = false;

  @override
  void initState() {
    super.initState();
    future = ref.read(mapServiceProvider).getDuplicateReview(widget.mapId);
  }

  Future<void> resolve(String action, {String? existingMapId}) async {
    setState(() => resolving = true);
    try {
      await ref
          .read(mapServiceProvider)
          .resolveDuplicate(
            mapId: widget.mapId,
            action: action,
            existingMapId: existingMapId,
          );
      if (!mounted) return;
      switch (action) {
        case 'open_existing':
          context.go('/viewer/$existingMapId');
          break;
        case 'cancel':
          context.go('/projects');
          break;
        default:
          context.go('/maps/${widget.mapId}/processing');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => resolving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar duplicado')),
      body: SafeArea(
        child: FutureBuilder<DuplicateReview>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(snapshot.error.toString()),
                ),
              );
            }

            final review = snapshot.data!;
            final candidate = review.candidates.isEmpty
                ? null
                : review.candidates.first;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'El mapa que intentas subir parece repetido.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  review.message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                if (candidate != null) _CandidateCard(candidate: candidate),
                const SizedBox(height: 18),
                _ActionButton(
                  enabled: !resolving && candidate != null,
                  icon: Icons.open_in_new,
                  label: 'Abrir existente',
                  onPressed: () =>
                      resolve('open_existing', existingMapId: candidate?.mapId),
                ),
                _ActionButton(
                  enabled: !resolving && candidate != null,
                  icon: Icons.swap_horiz,
                  label: 'Reemplazar existente',
                  onPressed: () => resolve(
                    'replace_existing',
                    existingMapId: candidate?.mapId,
                  ),
                ),
                _ActionButton(
                  enabled: !resolving,
                  icon: Icons.history,
                  label: 'Guardar como version nueva',
                  onPressed: () => resolve(
                    'save_new_version',
                    existingMapId: candidate?.mapId,
                  ),
                ),
                _ActionButton(
                  enabled: !resolving,
                  icon: Icons.warning_amber,
                  label: 'Subir de todas formas',
                  onPressed: () => resolve('upload_anyway'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: resolving ? null : () => resolve('cancel'),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar subida'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final DuplicateCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mapa existente: ${candidate.name}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text('Coincidencia: ${candidate.score.toStringAsFixed(0)}%'),
            const SizedBox(height: 4),
            Text('Razon: ${candidate.reason}'),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

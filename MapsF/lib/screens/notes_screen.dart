import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Observaciones',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const _NewPointSheet(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Puntos y notas guardados durante el trabajo de campo.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                children: const [
                  _NoteCard(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warningYellow,
                    title: 'Camino bloqueado',
                    type: 'Problema',
                    location: 'Lote 10 · Terranova',
                    status: 'Pendiente de sincronizar',
                  ),
                  SizedBox(height: 12),
                  _NoteCard(
                    icon: Icons.park_outlined,
                    color: AppColors.primaryGreen,
                    title: 'Árbol caído',
                    type: 'Observación',
                    location: 'Camino interno · Santa Rita',
                    status: 'Guardado localmente',
                  ),
                  SizedBox(height: 12),
                  _NoteCard(
                    icon: Icons.flag_outlined,
                    color: AppColors.gpsBlue,
                    title: 'Punto de control A3',
                    type: 'Control',
                    location: 'Límite norte · Río Claro',
                    status: 'Sincronizado',
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

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.type,
    required this.location,
    required this.status,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String type;
  final String location;
  final String status;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$type · $location',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _NewPointSheet extends StatelessWidget {
  const _NewPointSheet();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nuevo punto',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Camino bloqueado',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: 'Observación',
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                'Observación',
                'Árbol caído',
                'Camino bloqueado',
                'Punto de control',
                'Problema',
                'Otro',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(labelText: 'Notas'),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.paleGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gps_fixed, color: AppColors.primaryGreen),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '10.123456, -84.123456\nPrecisión: 4.5 m',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Agregar foto'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Guardar punto'),
            ),
          ],
        ),
      ),
    );
  }
}

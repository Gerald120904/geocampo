import 'package:flutter/material.dart';

import '../../models/current_location.dart';

class CurrentLocationSheet extends StatelessWidget {
  const CurrentLocationSheet({super.key, required this.location});

  final CurrentLocation location;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ubicación actual',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('${location.lat}, ${location.lng}'),
          if (location.accuracy != null)
            Text('Precisión: ${location.accuracy!.toStringAsFixed(1)} m'),
        ],
      ),
    );
  }
}

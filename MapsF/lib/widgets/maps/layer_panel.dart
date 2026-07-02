import 'package:flutter/material.dart';

import '../../models/map_layer.dart';

class LayerPanel extends StatelessWidget {
  const LayerPanel({super.key, required this.layers});

  final List<MapLayer> layers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: layers
          .map(
            (layer) => ListTile(
              leading: const Icon(Icons.layers),
              title: Text(layer.name),
              subtitle: Text('${layer.layerType} · ${layer.featureCount}'),
            ),
          )
          .toList(),
    );
  }
}

import 'package:flutter/material.dart';

class PackageDownloadCard extends StatelessWidget {
  const PackageDownloadCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

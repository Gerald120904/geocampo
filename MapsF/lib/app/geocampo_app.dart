import 'package:flutter/material.dart';

import 'app_router.dart';
import 'app_theme.dart';

class GeoCampoApp extends StatelessWidget {
  const GeoCampoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GeoCampo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}

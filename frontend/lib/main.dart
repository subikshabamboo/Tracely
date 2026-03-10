import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/router.dart';

void main() {
  runApp(
    const ProviderScope(
      child: TracelyApp(),
    ),
  );
}

class TracelyApp extends StatelessWidget {
  const TracelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tracely',
      debugShowCheckedModeBanner: false,
      theme: TracelyTheme.darkTheme,
      routerConfig: router,
    );
  }
}

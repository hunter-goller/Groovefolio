import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/routing/router.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Forces the database connection to open as soon as the app boots —
    // satisfies VinylApp-007's "app opens database on launch" criterion.
    // Unused directly here yet, but this is what makes it eager instead
    // of lazily opening on whatever screen first happens to query it.
    ref.watch(databaseProvider);

    final router = ref.watch(routerProvider);
    return MaterialApp.router(title: 'Vinyl App', routerConfig: router);
  }
}

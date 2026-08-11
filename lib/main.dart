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
    // Keep the AppDatabase provider owned by the root ProviderScope. The
    // production executor is a LazyDatabase, so this constructs the database
    // object but does not guarantee SQLite has opened or migrations completed.
    // Explicit startup initialization belongs to the later splash/bootstrap flow.
    ref.watch(databaseProvider);

    final router = ref.watch(routerProvider);
    return MaterialApp.router(title: 'Vinyl App', routerConfig: router);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/routing/router.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/theme/theme_provider.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final container = ProviderContainer();

  try {
    // Force Drift's LazyDatabase to open. The future only completes after
    // onCreate/onUpgrade and beforeOpen have finished, so the native splash
    // remains visible for the full database migration/bootstrap path.
    await container.read(databaseProvider).initialize();
  } catch (error, stackTrace) {
    container.dispose();
    FlutterNativeSplash.remove();
    Error.throwWithStackTrace(error, stackTrace);
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));

  // Keep the native splash until Flutter has actually painted the first frame.
  // Database initialization has already completed before runApp above.
  widgetsBinding.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The database was explicitly opened during bootstrap before runApp.
    // Watching it here keeps the root widget tied to the same app-lifetime
    // provider instance used during startup.
    ref.watch(databaseProvider);

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      title: 'Groovefolio',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/routing/router.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/theme/theme_provider.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final container = ProviderContainer();

  // Instantiate app-links before the database bootstrap so a cold-start OAuth
  // callback is retained while Drift opens and runs any migrations.
  container.read(discogsAppLinksProvider);

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

    // Warm the optional Android NFC availability check once at app launch.
    // Unsupported and disabled devices remain fully usable through manual
    // collection and play-logging flows.
    ref.watch(nfcAvailabilityProvider);

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    if (ref.watch(discogsDeepLinksEnabledProvider)) {
      ref.listen(discogsIncomingUriProvider, (previous, next) {
        next.whenData((uri) {
          final config = ref.read(discogsConfigProvider);
          if (!config.matchesCallback(uri)) return;

          // Route first so cold-start callbacks land on Settings immediately.
          // The controller then completes the verifier exchange and the screen
          // reacts to its state.
          router.go(AppRoutes.settings);
          ref
              .read(discogsAuthorizationControllerProvider.notifier)
              .handleCallback(uri);
        });
      });
    }

    return MaterialApp.router(
      title: 'Groovefolio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

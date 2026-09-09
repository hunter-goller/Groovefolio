import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/services/recommendation_service.dart';
import 'package:vinyl_app/services/nfc/nfc_play_undo.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/routing/router.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_intent_play_handler.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/services/notifications/nfc_play_notification_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/theme/theme_provider.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final container = ProviderContainer();

  // Instantiate app-links before the database bootstrap so a cold-start OAuth
  // or NFC callback is retained while Drift opens and runs any migrations.
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

  static final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<void> _showNfcResult(WidgetRef ref, NfcIntentPlayResult result) async {
    if (result.suppressed) {
      // Keep the first play's Undo visible while the tag remains nearby.
      return;
    }

    final play = result.play;
    if (play == null) {
      _showNfcMessage('Play logged: ${result.album.title}');
      return;
    }

    final repository = ref.read(playRepositoryProvider);
    _refreshPlayData(ref, result.album.id);
    // Haptic failure is feedback failure, not a failed database insert.
    unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
    await ref
        .read(nfcPlayNotificationServiceProvider)
        .showLoggedPlay(album: result.album, play: play);
    if (!ref.context.mounted) return;
    final undo = NfcPlayUndo(deletePlay: () => repository.deleteById(play.id));
    _showNfcMessage(
      'Play logged: ${result.album.title}',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          try {
            final removed = await undo.undo();
            if (!ref.context.mounted) return;
            _refreshPlayData(ref, result.album.id);
            if (removed) {
              await cancelNfcPlayNotification(play.id);
            }
            _showNfcMessage(
              removed ? 'Play removed.' : 'Undo is no longer available.',
            );
          } on Object {
            _showNfcMessage(
              'Couldn’t undo that play. It remains in your history.',
            );
          }
        },
      ),
    );
  }

  void _refreshPlayData(WidgetRef ref, String albumId) {
    ref.invalidate(albumsProvider);
    ref.invalidate(recentlyPlayedProvider);
    ref.invalidate(playCountProvider(albumId));
    ref.invalidate(albumDetailProvider(albumId));
    ref.invalidate(albumSearchProvider);
    ref.invalidate(statsDashboardProvider);
    ref.invalidate(discoverRecommendationsProvider);
  }

  Future<void> _openNotificationAlbum(WidgetRef ref, String albumId) async {
    try {
      final repository = ref.read(albumRepositoryProvider);
      final router = ref.read(routerProvider);
      final album = await repository.findById(albumId);
      if (!ref.context.mounted) return;
      if (album == null) {
        _showNfcMessage('That record is no longer in your collection.');
        return;
      }
      // Preserve a Collection back destination without invoking NFC logging.
      router.go(AppRoutes.collection);
      unawaited(router.push<void>(AppRoutes.albumDetailPath(album.id)));
    } on Object {
      _showNfcMessage('Couldn’t open that record. Please try again.');
    }
  }

  void _showNfcError(Object error) {
    final message = error is NfcException
        ? error.message
        : 'Groovefolio couldn’t log that NFC play.';

    _showNfcMessage(message);
  }

  void _showNfcMessage(
    String message, {
    bool afterFirstFrame = false,
    SnackBarAction? action,
  }) {
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) {
      if (!afterFirstFrame) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNfcMessage(message, afterFirstFrame: true, action: action);
        });
      }
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: action,
          duration: action == null
              ? const Duration(seconds: 4)
              : const Duration(seconds: 10),
        ),
      );
  }

  Future<void> _handleNfcUri(WidgetRef ref, Uri uri) async {
    try {
      final result = await ref.read(nfcIntentPlayHandlerProvider).handle(uri);
      if (result != null) await _showNfcResult(ref, result);
    } on Object catch (error) {
      _showNfcError(error);
    }
  }

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

    if (ref.watch(appLinksEnabledProvider)) {
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

      // AppLinks delivers the NFC URI for both cold-start and warm-app NFC
      // intents. The handler reuses the same play-logging service as foreground
      // NFC polling, so all play history follows one persistence path.
      ref.listen(discogsIncomingUriProvider, (previous, next) {
        next.whenData((uri) {
          final notificationAlbumId = albumIdFromNotificationUri(uri);
          if (notificationAlbumId != null) {
            unawaited(_openNotificationAlbum(ref, notificationAlbumId));
            return;
          }
          if (albumIdFromNfcUri(uri) == null) return;
          unawaited(_handleNfcUri(ref, uri));
        });
      });
    }

    return MaterialApp.router(
      title: 'Groovefolio',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_session.dart';
import 'package:vinyl_app/features/plays/play_data_refresh.dart';
import 'package:vinyl_app/features/startup/app_startup.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/routing/router.dart';
import 'package:vinyl_app/services/backup/backup_file_gateway.dart';
import 'package:vinyl_app/services/backup/rescue_copy_service.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_delivery_context.dart';
import 'package:vinyl_app/services/nfc/nfc_intent_play_handler.dart';
import 'package:vinyl_app/services/nfc/nfc_play_undo.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/services/notifications/nfc_play_notification_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/theme/theme_provider.dart';

/// Captures app links before opening storage. A failed database open shows
/// recovery UI and retries with fresh dependencies without deleting local data.
/// Debug and profile builds only: `--dart-define=GROOVEFOLIO_SIMULATE_STARTUP_FAILURE=true`
/// shows the startup error screen without touching the database, so the
/// rescue-copy flow can be checked on a phone. Release builds ignore it.
const _simulateStartupFailure =
    !kReleaseMode &&
    bool.fromEnvironment('GROOVEFOLIO_SIMULATE_STARTUP_FAILURE');

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  final appLinks = AppLinks();

  runApp(
    AppStartup(
      saveRescueCopy: () async {
        // No providers here: the database may be what failed to open.
        final service = RescueCopyService();
        final bytes = await service.createRescueCopy();
        return const FilePickerBackupFileGateway().save(
          service.suggestedFileName(),
          bytes,
        );
      },
      initialize: () async {
        if (_simulateStartupFailure) {
          throw StateError('Simulated startup failure for testing.');
        }
        // Keep the native app-links singleton across retries so startup callbacks
        // remain available when the normal root listeners are finally mounted.
        final container = ProviderContainer(
          overrides: [discogsAppLinksProvider.overrideWithValue(appLinks)],
        );
        try {
          await container.read(databaseProvider).initialize();
          return UncontrolledProviderScope(
            container: container,
            child: const MyApp(),
          );
        } catch (error, stackTrace) {
          container.dispose();
          Error.throwWithStackTrace(error, stackTrace);
        }
      },
    ),
  );

  // Flutter now owns loading/error recovery as well as the successful app.
  widgetsBinding.addPostFrameCallback((_) => FlutterNativeSplash.remove());
}

/// Root integration point for app-link OAuth callbacks and Android NFC
/// deliveries. NFC play persistence, feedback, and navigation stay separate
/// so a notification tap never logs the same play again.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<void> _showNfcResult(
    WidgetRef ref,
    NfcIntentPlayResult result,
    NfcDeliveryContext delivery,
  ) async {
    if (result.suppressed) {
      // Keep the first play's Undo visible while the tag remains nearby.
      return;
    }

    final play = result.play;
    if (play == null) {
      final message = 'Play logged: ${result.album.title}';
      if (delivery.isExternal) {
        await ref
            .read(nfcDeliveryContextServiceProvider)
            .showExternalMessage(message);
      } else {
        _showNfcMessage(message);
      }
      return;
    }

    final repository = ref.read(playRepositoryProvider);
    refreshPlayData(ref, result.album.id);
    ref.tutorialEvent(TutorialEvent.playLogged);

    if (delivery.isExternal) {
      final notificationShown = await ref
          .read(nfcPlayNotificationServiceProvider)
          .showLoggedPlay(album: result.album, play: play);
      if (!notificationShown) {
        await ref
            .read(nfcDeliveryContextServiceProvider)
            .showExternalMessage('Play logged: ${result.album.title}');
      }
      return;
    }

    // Haptic failure is feedback failure, not a failed database insert.
    unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
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
            refreshPlayData(ref, result.album.id);
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

  Future<void> _showNfcError(
    WidgetRef ref,
    Object error,
    NfcDeliveryContext delivery,
  ) async {
    final isDeletedAlbum =
        error is StateError &&
        error.message ==
            'The NFC tag points to an album that no longer exists.';
    final message = error is NfcException
        ? error.message
        : isDeletedAlbum
        ? delivery.isExternal
              ? 'Record no longer in collection. Add it again and relink this tag.'
              : 'This NFC tag is linked to a record that is no longer in your '
                    'collection. Add the record again and relink the tag.'
        : 'Groovefolio couldn’t log that NFC play.';

    if (delivery.isExternal) {
      await ref
          .read(nfcDeliveryContextServiceProvider)
          .showExternalMessage(message);
    } else {
      _showNfcMessage(message);
    }
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
    final deliveryService = ref.read(nfcDeliveryContextServiceProvider);
    final delivery = await deliveryService.consume();
    try {
      final result = await ref.read(nfcIntentPlayHandlerProvider).handle(uri);
      if (result != null) await _showNfcResult(ref, result, delivery);
    } on Object catch (error) {
      await _showNfcError(ref, error, delivery);
    } finally {
      await deliveryService.completeExternal(delivery);
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
        next.whenData((uri) async {
          final config = ref.read(discogsConfigProvider);
          if (!config.matchesCallback(uri)) return;

          final controller = ref.read(
            discogsAuthorizationControllerProvider.notifier,
          );
          if (router.state.uri.path != AppRoutes.settings) {
            // The router state includes pushed pages; the route information
            // provider may still describe the screen underneath Settings.
            // Keep the current screen as a Back destination, including on
            // cold starts. If Settings is already open, retain its stack;
            // replacing it with go() would strand the user after login.
            unawaited(router.push<void>(AppRoutes.settings));
          }
          await controller.handleCallback(uri);
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
          // Consume every native album-delivery classification, including a
          // malformed URI that the strict handler will safely reject. Leaving
          // one queued would misclassify the next valid, repeated tag event.
          if (uri.scheme != 'groovefolio' || uri.host != 'album') return;
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

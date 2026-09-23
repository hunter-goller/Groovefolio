import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/features/albums/screens/add_record_screen.dart';
import 'package:vinyl_app/features/albums/screens/album_detail_screen.dart';
import 'package:vinyl_app/features/albums/screens/barcode_scanner_screen.dart';
import 'package:vinyl_app/features/albums/screens/collection_screen.dart';
import 'package:vinyl_app/features/albums/screens/edit_album_screen.dart';
import 'package:vinyl_app/features/discover/screens/discover_screen.dart';
import 'package:vinyl_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:vinyl_app/features/onboarding/widgets/onboarding_gate.dart';
import 'package:vinyl_app/features/onboarding/widgets/walkthrough_frame.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/features/settings/screens/discogs_collection_import_screen.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/features/settings/screens/settings_screen.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/routing/app_routes.dart';

part 'router.g.dart';

/// Exposes the app's GoRouter instance via Riverpod.
///
/// The generated `routerProvider` is rebuilt with build_runner. A ShellRoute
/// keeps walkthrough cues mounted across screens, while OnboardingGate runs
/// only on the ordinary Collection entry route.
@riverpod
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.collection,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            WalkthroughFrame(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.collection,
            builder: (context, state) =>
                state.uri.queryParameters['onboarding'] == 'true'
                ? const CollectionScreen()
                : const OnboardingGate(child: CollectionScreen()),
          ),
          GoRoute(
            path: AppRoutes.stats,
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (context, state) => const DiscoverScreen(),
          ),
          GoRoute(
            path: AppRoutes.addAlbum,
            builder: (context, state) => const AddRecordScreen(),
          ),
          GoRoute(
            path: AppRoutes.barcodeScan,
            builder: (context, state) => const BarcodeScannerScreen(),
          ),
          GoRoute(
            path: AppRoutes.albumDetail,
            builder: (context, state) {
              final albumId = state.pathParameters['id']!;
              return AlbumDetailScreen(albumId: albumId);
            },
          ),
          GoRoute(
            path: AppRoutes.editAlbum,
            builder: (context, state) {
              final albumId = state.pathParameters['id']!;
              return EditAlbumScreen(albumId: albumId);
            },
          ),
          GoRoute(
            path: AppRoutes.logPlay,
            builder: (context, state) => const LogPlayScreen(),
          ),
          GoRoute(
            path: AppRoutes.nfcHelp,
            builder: (context, state) => const NfcHelpScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.onboarding,
            builder: (context, state) => const OnboardingScreen(replay: true),
          ),
          GoRoute(
            path: AppRoutes.discogsCollectionImport,
            builder: (context, state) => const DiscogsCollectionImportScreen(),
          ),
        ],
      ),
    ],
  );
}

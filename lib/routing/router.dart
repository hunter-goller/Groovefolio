import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/features/albums/screens/add_record_screen.dart';
import 'package:vinyl_app/features/albums/screens/album_detail_screen.dart';
import 'package:vinyl_app/features/albums/screens/barcode_scanner_screen.dart';
import 'package:vinyl_app/features/albums/screens/collection_screen.dart';
import 'package:vinyl_app/features/albums/screens/edit_album_screen.dart';
import 'package:vinyl_app/features/discover/screens/discover_screen.dart';
import 'package:vinyl_app/features/onboarding/tracks/screens/gold_record_screen.dart';
import 'package:vinyl_app/features/onboarding/tracks/screens/tracklist_screen.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/tutorial_overlay_host.dart';
import 'package:vinyl_app/features/onboarding/widgets/onboarding_gate.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/features/settings/screens/discogs_collection_import_screen.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/features/settings/screens/settings_screen.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/widgets/ui/empty_state.dart';

part 'router.g.dart';

/// Exposes the app's GoRouter instance via Riverpod.
///
/// The generated `routerProvider` is rebuilt with build_runner. A ShellRoute
/// keeps the tutorial spotlight mounted across screens, while OnboardingGate runs
/// only on the ordinary Collection entry route.
@riverpod
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.collection,
    errorBuilder: (context, state) => const RouteNotFoundScreen(),
    routes: [
      ShellRoute(
        builder: (context, state, child) => TutorialOverlayHost(child: child),
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
            path: AppRoutes.tutorial,
            builder: (context, state) => const TracklistScreen(),
          ),
          GoRoute(
            path: AppRoutes.tutorialGold,
            builder: (context, state) => const GoldRecordScreen(),
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

/// Shown for a link or path the app doesn't know, instead of go_router's
/// default error page.
class RouteNotFoundScreen extends StatelessWidget {
  const RouteNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: EmptyState(
              icon: Icons.explore_off_outlined,
              title: 'Page not found',
              subtitle:
                  'This link doesn’t go anywhere in Groovefolio. Your '
                  'collection is safe.',
              ctaLabel: 'Go to Collection',
              ctaKey: const Key('route-not-found-home'),
              onCtaTap: () => context.go(AppRoutes.collection),
            ),
          ),
        ),
      ),
    );
  }
}

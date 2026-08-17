import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/features/albums/screens/add_record_screen.dart';
import 'package:vinyl_app/features/albums/screens/album_detail_screen.dart';
import 'package:vinyl_app/features/albums/screens/collection_screen.dart';
import 'package:vinyl_app/features/albums/screens/edit_album_screen.dart';
import 'package:vinyl_app/features/discover/screens/discover_screen.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/features/settings/screens/settings_screen.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/routing/app_routes.dart';

part 'router.g.dart';

/// Exposes the app's GoRouter instance via Riverpod.
///
/// This is the codegen pattern (VinylApp-006) — the @riverpod annotation
/// generates `routerProvider` and the boilerplate in router.g.dart for you.
/// Any time you edit this file, re-run:
///   dart run build_runner build
///
/// TEMPLATE FOR FUTURE PROVIDERS YOU WRITE YOURSELF:
///   @riverpod
///   ReturnType functionName(Ref ref) { ... }
/// generates `functionNameProvider` automatically — no manual
/// `Provider<ReturnType>((ref) => ...)` boilerplate needed.
@riverpod
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.collection,
    routes: [
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) => const CollectionScreen(),
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
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

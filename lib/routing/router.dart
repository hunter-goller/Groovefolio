import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/albums/screens/add_record_screen.dart';
import 'package:vinyl_app/features/albums/screens/album_detail_screen.dart';
import 'package:vinyl_app/features/albums/screens/collection_screen.dart';
import 'package:vinyl_app/features/discover/screens/discover_screen.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/routing/app_routes.dart';

/// Exposes the app's GoRouter instance via Riverpod.
/// This is intentionally minimal — full Riverpod conventions
/// (ProviderContainer testing pattern, code gen, etc.) land separately.
final routerProvider = Provider<GoRouter>((ref) {
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
        path: AppRoutes.logPlay,
        builder: (context, state) => const LogPlayScreen(),
      ),
    ],
  );
});

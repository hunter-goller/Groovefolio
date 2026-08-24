import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/discover/screens/discover_screen.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/recommendation_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  const album = Album(
    id: 'album-blue-train',
    title: 'Blue Train',
    artistId: 'artist-coltrane',
    releaseYear: 1957,
    createdAt: '2026-01-01T00:00:00.000Z',
  );
  const jazz = Genre(
    id: 'genre-jazz',
    name: 'Jazz',
    createdAt: '2026-01-01T00:00:00.000Z',
  );

  testWidgets('populated Discover shows explanations and opens Album Detail', (
    tester,
  ) async {
    const data = DiscoverRecommendations(
      collectionSize: 4,
      tasteProfile: TasteProfile(
        totalPlays: 12,
        playedAlbums: 3,
        topGenres: [TasteGenre(genre: jazz, playCount: 8, share: 0.67)],
        favoriteDecade: 1950,
      ),
      rediscover: [
        AlbumRecommendation(
          album: album,
          artistName: 'John Coltrane',
          genres: ['Jazz'],
          reason: '4 plays • Last played 5 months ago',
          kind: RecommendationKind.rediscover,
          playCount: 4,
          score: 150,
        ),
      ],
      genrePicks: [],
      eraPicks: [],
    );

    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationServiceProvider.overrideWithValue(
            const _FakeRecommendationService(data),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your taste profile'), findsOneWidget);
    expect(find.text('Rediscover your shelf'), findsOneWidget);
    expect(find.text('Blue Train'), findsOneWidget);
    expect(find.textContaining('Last played 5 months ago'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('discover-recommendation-album-blue-train')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Album detail: album-blue-train'), findsOneWidget);
  });

  testWidgets('collection with no plays shows useful low-data state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const data = DiscoverRecommendations(
      collectionSize: 1,
      tasteProfile: null,
      rediscover: [],
      genrePicks: [],
      eraPicks: [],
    );

    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationServiceProvider.overrideWithValue(
            const _FakeRecommendationService(data),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover-low-data')), findsOneWidget);
    expect(find.text('Build your taste profile'), findsOneWidget);
    expect(find.textContaining('Log a few plays'), findsOneWidget);
    expect(find.byKey(const Key('discover-log-play')), findsOneWidget);
    expect(find.textContaining('placeholder'), findsNothing);

    await tester.tap(find.byKey(const Key('discover-log-play')));
    await tester.pumpAndSettle();

    expect(find.text('Log play'), findsOneWidget);
  });
}

GoRouter _router() {
  return GoRouter(
    initialLocation: AppRoutes.discover,
    routes: [
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) => const Scaffold(body: Text('Collection')),
      ),
      GoRoute(
        path: AppRoutes.stats,
        builder: (context, state) => const Scaffold(body: Text('Stats')),
      ),
      GoRoute(
        path: AppRoutes.discover,
        builder: (context, state) => const DiscoverScreen(),
      ),
      GoRoute(
        path: AppRoutes.addAlbum,
        builder: (context, state) => const Scaffold(body: Text('Add record')),
      ),
      GoRoute(
        path: AppRoutes.logPlay,
        builder: (context, state) => const Scaffold(body: Text('Log play')),
      ),
      GoRoute(
        path: AppRoutes.albumDetail,
        builder: (context, state) =>
            Scaffold(body: Text('Album detail: ${state.pathParameters['id']}')),
      ),
    ],
  );
}

class _FakeRecommendationService implements IRecommendationService {
  const _FakeRecommendationService(this.data);

  final DiscoverRecommendations data;

  @override
  Future<DiscoverRecommendations> getRecommendations({
    Duration rediscoverThreshold = const Duration(days: 90),
    Duration recentSuppression = const Duration(days: 30),
    int sectionLimit = 6,
  }) async {
    return data;
  }
}

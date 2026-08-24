import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/screens/collection_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  testWidgets('long press exposes Edit/Delete and delete still confirms', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _providerScope(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Blue Train'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('collection-quick-edit')), findsOneWidget);
    expect(find.byKey(const Key('collection-quick-delete')), findsOneWidget);

    await tester.tap(find.byKey(const Key('collection-quick-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete Blue Train?'), findsOneWidget);
    expect(find.byKey(const Key('delete-record-confirm')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-record-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Blue Train'), findsOneWidget);
  });

  testWidgets('long press edit navigates to the existing edit route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: AppRoutes.collection,
          builder: (context, state) => const CollectionScreen(),
        ),
        GoRoute(
          path: AppRoutes.albumDetail,
          builder: (context, state) =>
              const Scaffold(body: Text('Album detail test')),
        ),
        GoRoute(
          path: AppRoutes.editAlbum,
          builder: (context, state) => const Scaffold(body: Text('Edit test')),
        ),
        GoRoute(
          path: AppRoutes.stats,
          builder: (context, state) => const Scaffold(body: Text('Stats test')),
        ),
        GoRoute(
          path: AppRoutes.discover,
          builder: (context, state) =>
              const Scaffold(body: Text('Discover test')),
        ),
        GoRoute(
          path: AppRoutes.addAlbum,
          builder: (context, state) =>
              const Scaffold(body: Text('Add record test')),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) =>
              const Scaffold(body: Text('Settings test')),
        ),
      ],
    );

    await tester.pumpWidget(
      _providerScope(
        MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Blue Train'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection-quick-edit')));
    await tester.pumpAndSettle();

    expect(find.text('Edit test'), findsOneWidget);
  });

  testWidgets('regular tap still opens Album Detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: AppRoutes.collection,
          builder: (context, state) => const CollectionScreen(),
        ),
        GoRoute(
          path: AppRoutes.albumDetail,
          builder: (context, state) =>
              const Scaffold(body: Text('Album detail test')),
        ),
        GoRoute(
          path: AppRoutes.stats,
          builder: (context, state) => const Scaffold(body: Text('Stats test')),
        ),
        GoRoute(
          path: AppRoutes.discover,
          builder: (context, state) =>
              const Scaffold(body: Text('Discover test')),
        ),
        GoRoute(
          path: AppRoutes.addAlbum,
          builder: (context, state) =>
              const Scaffold(body: Text('Add record test')),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) =>
              const Scaffold(body: Text('Settings test')),
        ),
      ],
    );

    await tester.pumpWidget(
      _providerScope(
        MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Train'));
    await tester.pumpAndSettle();

    expect(find.text('Album detail test'), findsOneWidget);
  });
}

Widget _providerScope(Widget child) {
  return ProviderScope(
    overrides: [
      albumRepositoryProvider.overrideWithValue(_Albums()),
      artistRepositoryProvider.overrideWithValue(_Artists()),
      playRepositoryProvider.overrideWithValue(_Plays()),
      genreRepositoryProvider.overrideWithValue(_Genres()),
    ],
    child: child,
  );
}

class _Albums implements IAlbumRepository {
  static const album = Album(
    id: 'album-1',
    title: 'Blue Train',
    artistId: 'artist-1',
    releaseYear: 1957,
    label: 'Blue Note',
    createdAt: '2026-08-21T00:00:00.000Z',
  );

  @override
  Future<List<Album>> findAll() async => const [album];

  @override
  Future<Album?> findById(String id) async => id == album.id ? album : null;

  @override
  Future<List<Album>> search(String query) async => const [album];

  @override
  Future<Album> create({
    required String title,
    required String artistId,
    int? releaseYear,
    String? label,
    String? artworkPath,
    DateTime? purchaseDate,
    int? purchasePriceCents,
  }) => throw UnimplementedError();

  @override
  Future<int> delete(String id) => throw UnimplementedError();

  @override
  Future<bool> update(Album album) => throw UnimplementedError();
}

class _Artists implements IArtistRepository {
  static const artist = Artist(
    id: 'artist-1',
    name: 'John Coltrane',
    createdAt: '2026-08-21T00:00:00.000Z',
  );

  @override
  Future<List<Artist>> findAll() async => const [artist];

  @override
  Future<Artist?> findById(String id) async => id == artist.id ? artist : null;

  @override
  Future<Artist> findOrCreate(String name) => throw UnimplementedError();
}

class _Plays implements IPlayRepository {
  @override
  Future<List<Play>> findAll() async => const [];

  @override
  Future<List<Play>> findByAlbum(String albumId) async => const [];

  @override
  Future<int> getPlayCountByAlbum(String albumId) async => 0;

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async => const [];

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) => throw UnimplementedError();

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();
}

class _Genres implements IGenreRepository {
  @override
  Future<List<Genre>> findAll() async => const [];

  @override
  Future<List<Genre>> findByAlbum(String albumId) async => const [];

  @override
  Future<Genre?> findById(String id) async => null;

  @override
  Future<Genre?> findByName(String name) async => null;

  @override
  Future<Genre> findOrCreate(String name) => throw UnimplementedError();

  @override
  Future<void> setAlbumGenres(String albumId, Iterable<String> genreIds) =>
      throw UnimplementedError();

  @override
  Future<int> removeFromAlbum(String albumId, String genreId) =>
      throw UnimplementedError();

  @override
  Future<int> delete(String genreId) => throw UnimplementedError();
}

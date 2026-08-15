import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/screens/collection_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  testWidgets('shows assigned genres on Collection album rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(_FakeAlbumRepository()),
          artistRepositoryProvider.overrideWithValue(_FakeArtistRepository()),
          playRepositoryProvider.overrideWithValue(_FakePlayRepository()),
          genreRepositoryProvider.overrideWithValue(
            const _FakeGenreRepository([
              Genre(
                id: 'genre-jazz',
                name: 'Jazz',
                createdAt: '2026-08-14T00:00:00.000Z',
              ),
              Genre(
                id: 'genre-hard-bop',
                name: 'Hard Bop',
                createdAt: '2026-08-14T00:00:00.000Z',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blue Train'), findsOneWidget);
    expect(find.text('Jazz'), findsOneWidget);
    expect(find.text('Hard Bop'), findsOneWidget);
    expect(find.byKey(const Key('album-list-genres')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('genre selection keeps primary sort controls anchored', (
    tester,
  ) async {
    // Use a width where the default four controls fit, but selecting a long
    // genre can make the row wider than the viewport. This isolates the
    // regression we care about: selection must not auto-scroll the primary
    // sort controls off the left edge.
    await tester.binding.setSurfaceSize(const Size(540, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(_FakeAlbumRepository()),
          artistRepositoryProvider.overrideWithValue(_FakeArtistRepository()),
          playRepositoryProvider.overrideWithValue(_FakePlayRepository()),
          genreRepositoryProvider.overrideWithValue(
            const _FakeGenreRepository([
              Genre(
                id: 'genre-progressive-rock',
                name: 'Progressive Rock',
                createdAt: '2026-08-14T00:00:00.000Z',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('collection-genre-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Progressive Rock'));
    await tester.pumpAndSettle();

    final recentChip = find.widgetWithText(ChoiceChip, 'Recent');
    expect(recentChip, findsOneWidget);
    expect(tester.getTopLeft(recentChip).dx, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides Add record FAB while collection search is open', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(_FakeAlbumRepository()),
          artistRepositoryProvider.overrideWithValue(_FakeArtistRepository()),
          playRepositoryProvider.overrideWithValue(_FakePlayRepository()),
          genreRepositoryProvider.overrideWithValue(
            const _FakeGenreRepository([]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byTooltip('Search collection'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('collection-search-field')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAlbumRepository implements IAlbumRepository {
  static const album = Album(
    id: 'album-1',
    title: 'Blue Train',
    artistId: 'artist-1',
    releaseYear: 1957,
    label: 'Blue Note',
    createdAt: '2026-08-14T00:00:00.000Z',
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

class _FakeArtistRepository implements IArtistRepository {
  static const artist = Artist(
    id: 'artist-1',
    name: 'John Coltrane',
    createdAt: '2026-08-14T00:00:00.000Z',
  );

  @override
  Future<List<Artist>> findAll() async => const [artist];

  @override
  Future<Artist?> findById(String id) async => id == artist.id ? artist : null;

  @override
  Future<Artist> findOrCreate(String name) => throw UnimplementedError();
}

class _FakePlayRepository implements IPlayRepository {
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

class _FakeGenreRepository implements IGenreRepository {
  const _FakeGenreRepository(this.genres);

  final List<Genre> genres;

  @override
  Future<List<Genre>> findByAlbum(String albumId) async =>
      albumId == 'album-1' ? List.unmodifiable(genres) : const [];

  @override
  Future<List<Genre>> findAll() async => List.unmodifiable(genres);

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  testWidgets('manual selection logs a play and returns to Collection', (
    tester,
  ) async {
    final fixture = _Fixture.single();
    await _pumpLogPlay(tester, fixture: fixture);

    expect(find.textContaining('NFC'), findsNothing);
    expect(find.text('Blue Train'), findsOneWidget);
    await tester.tap(find.text('Blue Train'));
    await tester.pump();

    expect(find.byKey(const Key('log-play-search')), findsNothing);
    expect(find.byKey(const Key('change-log-play-album')), findsOneWidget);
    await tester.ensureVisible(find.text('Side A'));
    await tester.tap(find.text('Side A'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Save play'));
    await tester.tap(find.text('Save play'));
    await tester.pumpAndSettle();

    expect(fixture.playRepository.plays, hasLength(1));
    expect(fixture.playRepository.plays.single.albumId, 'album-1');
    expect(fixture.playRepository.plays.single.sidePlayed, SidePlayed.sideA);
    expect(find.text('Collection test'), findsOneWidget);
  });

  testWidgets('default picker limits recent records until Browse all', (
    tester,
  ) async {
    final fixture = _Fixture.many(12);
    await _pumpLogPlay(tester, fixture: fixture);

    expect(find.text('Recent records'), findsOneWidget);
    expect(find.text('Record 11'), findsOneWidget);
    expect(find.text('Record 05'), findsNothing);
    expect(find.byKey(const Key('browse-all-records')), findsOneWidget);

    await tester.tap(find.byKey(const Key('browse-all-records')));
    await tester.pumpAndSettle();

    expect(find.text('All records'), findsOneWidget);
    expect(find.text('Record 05'), findsOneWidget);
    expect(find.byKey(const Key('show-recent')), findsOneWidget);
  });

  testWidgets('search matches artist names as well as album titles', (
    tester,
  ) async {
    final fixture = _Fixture.search();
    await _pumpLogPlay(tester, fixture: fixture);

    await tester.enterText(
      find.byKey(const Key('log-play-search')),
      'Miles Davis',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Search results'), findsOneWidget);
    expect(find.text('Kind of Blue'), findsOneWidget);
    expect(find.text('Blue Train'), findsNothing);
  });

  testWidgets('preselected album is compact and can be changed', (tester) async {
    final fixture = _Fixture.single();
    final initialAlbum = CollectionAlbum(
      album: fixture.albums.single,
      artist: fixture.artists.single,
      playCount: 0,
      lastPlayedAt: null,
    );

    await _pumpLogPlay(
      tester,
      fixture: fixture,
      initialAlbum: initialAlbum,
    );

    expect(find.text('Blue Train'), findsOneWidget);
    expect(find.byKey(const Key('log-play-search')), findsNothing);
    expect(find.byKey(const Key('change-log-play-album')), findsOneWidget);

    await tester.tap(find.byKey(const Key('change-log-play-album')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('log-play-search')), findsOneWidget);
    expect(find.text('Recent records'), findsOneWidget);
  });

  testWidgets('no-result state suggests searching album title or artist', (
    tester,
  ) async {
    final fixture = _Fixture.single();
    await _pumpLogPlay(tester, fixture: fixture);

    await tester.enterText(
      find.byKey(const Key('log-play-search')),
      'not in collection',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No records match “not in collection”. Try an album title or artist.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpLogPlay(
  WidgetTester tester, {
  required _Fixture fixture,
  CollectionAlbum? initialAlbum,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.logPlay,
    routes: [
      GoRoute(
        path: AppRoutes.logPlay,
        builder: (context, state) => LogPlayScreen(initialAlbum: initialAlbum),
      ),
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Collection test'))),
      ),
      GoRoute(
        path: AppRoutes.addAlbum,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Add record test'))),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        albumRepositoryProvider.overrideWithValue(
          _FakeAlbumRepository(fixture.albums),
        ),
        artistRepositoryProvider.overrideWithValue(
          _FakeArtistRepository(fixture.artists),
        ),
        playRepositoryProvider.overrideWithValue(fixture.playRepository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Fixture {
  _Fixture({
    required this.albums,
    required this.artists,
    List<Play> plays = const [],
  }) : playRepository = _FakePlayRepository(plays);

  factory _Fixture.single() {
    return _Fixture(
      artists: const [
        Artist(
          id: 'artist-1',
          name: 'John Coltrane',
          createdAt: '2026-08-14T00:00:00.000Z',
        ),
      ],
      albums: const [
        Album(
          id: 'album-1',
          title: 'Blue Train',
          artistId: 'artist-1',
          releaseYear: 1957,
          createdAt: '2026-08-14T00:00:00.000Z',
        ),
      ],
    );
  }

  factory _Fixture.many(int count) {
    const artist = Artist(
      id: 'artist-1',
      name: 'Test Artist',
      createdAt: '2026-08-01T00:00:00.000Z',
    );
    final albums = List.generate(
      count,
      (index) => Album(
        id: 'album-$index',
        title: 'Record ${index.toString().padLeft(2, '0')}',
        artistId: artist.id,
        createdAt: DateTime.utc(2026, 8, index + 1).toIso8601String(),
      ),
    );
    return _Fixture(albums: albums, artists: const [artist]);
  }

  factory _Fixture.search() {
    return _Fixture(
      artists: const [
        Artist(
          id: 'artist-coltrane',
          name: 'John Coltrane',
          createdAt: '2026-08-01T00:00:00.000Z',
        ),
        Artist(
          id: 'artist-davis',
          name: 'Miles Davis',
          createdAt: '2026-08-01T00:00:00.000Z',
        ),
      ],
      albums: const [
        Album(
          id: 'album-coltrane',
          title: 'Blue Train',
          artistId: 'artist-coltrane',
          createdAt: '2026-08-01T00:00:00.000Z',
        ),
        Album(
          id: 'album-davis',
          title: 'Kind of Blue',
          artistId: 'artist-davis',
          createdAt: '2026-08-02T00:00:00.000Z',
        ),
      ],
    );
  }

  final List<Album> albums;
  final List<Artist> artists;
  final _FakePlayRepository playRepository;
}

class _FakeAlbumRepository implements IAlbumRepository {
  _FakeAlbumRepository(this.albums);

  final List<Album> albums;

  @override
  Future<List<Album>> findAll() async => List.unmodifiable(albums);

  @override
  Future<Album?> findById(String id) async {
    for (final album in albums) {
      if (album.id == id) return album;
    }
    return null;
  }

  @override
  Future<List<Album>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    return albums
        .where((album) => album.title.toLowerCase().contains(normalized))
        .toList();
  }

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
  _FakeArtistRepository(this.artists);

  final List<Artist> artists;

  @override
  Future<List<Artist>> findAll() async => List.unmodifiable(artists);

  @override
  Future<Artist?> findById(String id) async {
    for (final artist in artists) {
      if (artist.id == id) return artist;
    }
    return null;
  }

  @override
  Future<Artist> findOrCreate(String name) => throw UnimplementedError();
}

class _FakePlayRepository implements IPlayRepository {
  _FakePlayRepository(List<Play> plays) : plays = List.of(plays);

  final List<Play> plays;

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) async {
    final play = Play(
      id: 'play-${plays.length + 1}',
      albumId: albumId,
      playedAt: playedAt.toUtc().toIso8601String(),
      sidePlayed: sidePlayed,
      createdAt: '2026-08-14T00:00:00.000Z',
    );
    plays.add(play);
    return play;
  }

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();

  @override
  Future<List<Play>> findAll() async => List.unmodifiable(plays);

  @override
  Future<List<Play>> findByAlbum(String albumId) async {
    return plays.where((play) => play.albumId == albumId).toList();
  }

  @override
  Future<int> getPlayCountByAlbum(String albumId) async {
    return plays.where((play) => play.albumId == albumId).length;
  }

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async => const [];
}

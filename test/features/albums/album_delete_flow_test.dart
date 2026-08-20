import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/screens/album_detail_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  testWidgets('delete confirmation shows album title and current play count', (
    tester,
  ) async {
    final state = _State(playCount: 3);
    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Record actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete record'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Blue Train?'), findsOneWidget);
    expect(
      find.textContaining(
        'This will also delete all 3 plays logged for this record.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancel leaves album and associations untouched', (tester) async {
    final state = _State(playCount: 2, hasNfc: true);
    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Record actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete record'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-record-cancel')));
    await tester.pumpAndSettle();

    expect(state.albumDeleted, isFalse);
    expect(state.deletedPlayIds, isEmpty);
    expect(state.nfcDeleted, isFalse);
  });

  testWidgets('confirm deletes owned data and returns to collection', (
    tester,
  ) async {
    final state = _State(playCount: 2, hasNfc: true);
    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Record actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete record'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-record-confirm')));
    await tester.pumpAndSettle();

    expect(state.deletedPlayIds, ['play-1', 'play-2']);
    expect(state.nfcDeleted, isTrue);
    expect(state.albumDeleted, isTrue);
    expect(find.text('Collection test'), findsOneWidget);
  });
}

Widget _app(_State state) {
  final router = GoRouter(
    initialLocation: '/album/album-1',
    routes: [
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, routeState) =>
            const Scaffold(body: Text('Collection test')),
      ),
      GoRoute(
        path: AppRoutes.albumDetail,
        builder: (context, routeState) =>
            AlbumDetailScreen(albumId: routeState.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.editAlbum,
        builder: (context, routeState) =>
            const Scaffold(body: Text('Edit test')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      albumRepositoryProvider.overrideWithValue(_Albums(state)),
      artistRepositoryProvider.overrideWithValue(_Artists()),
      playRepositoryProvider.overrideWithValue(_Plays(state)),
      genreRepositoryProvider.overrideWithValue(_Genres()),
      trackRepositoryProvider.overrideWithValue(_Tracks()),
      nfcTagRepositoryProvider.overrideWithValue(_Nfc(state)),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    ),
  );
}

class _State {
  _State({required this.playCount, this.hasNfc = false});

  final int playCount;
  final bool hasNfc;
  bool albumDeleted = false;
  bool nfcDeleted = false;
  final List<String> deletedPlayIds = [];
}

class _Albums implements IAlbumRepository {
  _Albums(this.state);
  final _State state;

  static const album = Album(
    id: 'album-1',
    title: 'Blue Train',
    artistId: 'artist-1',
    releaseYear: 1957,
    label: 'Blue Note',
    createdAt: '2026-01-01T00:00:00.000Z',
  );

  @override
  Future<Album?> findById(String id) async => state.albumDeleted ? null : album;

  @override
  Future<int> delete(String id) async {
    // Schema v6 cascades album-owned Plays/NfcTags with the album delete.
    for (var i = 1; i <= state.playCount; i++) {
      state.deletedPlayIds.add('play-$i');
    }
    if (state.hasNfc) state.nfcDeleted = true;
    state.albumDeleted = true;
    return 1;
  }

  @override
  Future<List<Album>> findAll() async => state.albumDeleted ? [] : [album];

  @override
  Future<List<Album>> search(String query) async => findAll();

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
  Future<bool> update(Album album) => throw UnimplementedError();
}

class _Artists implements IArtistRepository {
  static const artist = Artist(
    id: 'artist-1',
    name: 'John Coltrane',
    createdAt: '2026-01-01T00:00:00.000Z',
  );

  @override
  Future<Artist?> findById(String id) async => artist;

  @override
  Future<List<Artist>> findAll() async => [artist];

  @override
  Future<Artist> findOrCreate(String name) => throw UnimplementedError();
}

class _Plays implements IPlayRepository {
  _Plays(this.state);
  final _State state;

  List<Play> get _plays => [
    for (var i = 1; i <= state.playCount; i++)
      if (!state.deletedPlayIds.contains('play-$i'))
        Play(
          id: 'play-$i',
          albumId: 'album-1',
          playedAt: '2026-08-${10 + i}T12:00:00.000Z',
          sidePlayed: SidePlayed.full,
          createdAt: '2026-08-${10 + i}T12:00:00.000Z',
        ),
  ];

  @override
  Future<List<Play>> findByAlbum(String albumId) async => _plays;

  @override
  Future<int> deleteById(String id) async {
    state.deletedPlayIds.add(id);
    return 1;
  }

  @override
  Future<List<Play>> findAll() async => _plays;

  @override
  Future<int> getPlayCountByAlbum(String albumId) async => _plays.length;

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async => const [];

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) => throw UnimplementedError();
}

class _Genres implements IGenreRepository {
  @override
  Future<List<Genre>> findByAlbum(String albumId) async => const [];

  @override
  Future<List<Genre>> findAll() async => const [];

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
  Future<int> removeFromAlbum(String albumId, String genreId) async => 0;

  @override
  Future<int> delete(String genreId) async => 0;
}

class _Tracks implements ITrackRepository {
  @override
  Future<List<Track>> findByAlbum(String albumId) async => const [];

  @override
  Future<List<Track>> replaceAlbumTracks(
    String albumId,
    Iterable<TrackDraft> tracks,
  ) => throw UnimplementedError();
}

class _Nfc implements INfcTagRepository {
  _Nfc(this.state);
  final _State state;

  @override
  Future<NfcTag?> findByAlbum(String albumId) async {
    if (!state.hasNfc || state.nfcDeleted) return null;
    return const NfcTag(
      id: 'nfc-1',
      albumId: 'album-1',
      nfcTagId: 'tag-1',
      writtenAt: '2026-08-16T12:00:00.000Z',
    );
  }

  @override
  Future<int> delete(String id) async {
    state.nfcDeleted = true;
    return 1;
  }

  @override
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) => throw UnimplementedError();

  @override
  Future<NfcTag?> findByTagId(String nfcTagId) async => null;
}

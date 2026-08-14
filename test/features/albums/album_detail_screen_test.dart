import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/screens/album_detail_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  testWidgets('shows album identity, summary, and recent play history', (
    tester,
  ) async {
    final playRepository = _FakePlayRepository([
      _play('play-1', '2026-08-13T20:30:00.000Z', SidePlayed.sideA),
      _play('play-2', '2026-08-12T20:30:00.000Z', SidePlayed.full),
    ]);

    await tester.pumpWidget(_testApp(playRepository: playRepository));
    await tester.pumpAndSettle();

    expect(find.text('Blue Train'), findsOneWidget);
    expect(find.text('John Coltrane'), findsOneWidget);
    expect(find.text('1957  •  Blue Note'), findsOneWidget);
    expect(find.text('TOTAL PLAYS'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Log another play'), findsOneWidget);

    await tester.drag(
      find.byKey(const PageStorageKey<String>('album-detail-list')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent plays'), findsOneWidget);
    expect(find.text('Side A'), findsOneWidget);
    expect(find.text('Full album'), findsOneWidget);
  });

  testWidgets('Log another play opens 020 with this album pre-selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        playRepository: _FakePlayRepository([
          _play('play-1', '2026-08-13T20:30:00.000Z', SidePlayed.full),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log another play'));
    await tester.pumpAndSettle();

    expect(find.text('Log a play'), findsOneWidget);
    expect(find.text('Scan an NFC tag'), findsOneWidget);
    expect(find.text('Blue Train'), findsAtLeastNWidgets(1));

    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();

    final saveButtonFinder = find.ancestor(
      of: find.text('Save play'),
      matching: find.byType(FilledButton),
    );
    expect(saveButtonFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(saveButtonFinder).onPressed, isNotNull);
  });

  testWidgets('shows a not-found state for a missing album', (tester) async {
    await tester.pumpWidget(
      _testApp(
        albumId: 'missing',
        playRepository: _FakePlayRepository(const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Record not found'), findsOneWidget);
  });
}

Widget _testApp({
  String albumId = 'album-1',
  required IPlayRepository playRepository,
}) {
  return ProviderScope(
    overrides: [
      albumRepositoryProvider.overrideWithValue(_FakeAlbumRepository()),
      artistRepositoryProvider.overrideWithValue(_FakeArtistRepository()),
      playRepositoryProvider.overrideWithValue(playRepository),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: AlbumDetailScreen(albumId: albumId),
    ),
  );
}

Play _play(String id, String playedAt, SidePlayed side) {
  return Play(
    id: id,
    albumId: 'album-1',
    playedAt: playedAt,
    sidePlayed: side,
    createdAt: playedAt,
  );
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
  Future<Album?> findById(String id) async => id == album.id ? album : null;

  @override
  Future<List<Album>> findAll() async => [album];

  @override
  Future<List<Album>> search(String query) async => [album];

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
  Future<Artist?> findById(String id) async => id == artist.id ? artist : null;

  @override
  Future<List<Artist>> findAll() async => [artist];

  @override
  Future<Artist> findOrCreate(String name) => throw UnimplementedError();
}

class _FakePlayRepository implements IPlayRepository {
  _FakePlayRepository(Iterable<Play> plays) : _plays = List.of(plays);

  final List<Play> _plays;

  @override
  Future<List<Play>> findByAlbum(String albumId) async {
    final result = _plays.where((play) => play.albumId == albumId).toList();
    result.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return result;
  }

  @override
  Future<List<Play>> findAll() async => List.unmodifiable(_plays);

  @override
  Future<int> getPlayCountByAlbum(String albumId) async {
    return _plays.where((play) => play.albumId == albumId).length;
  }

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) async {
    final play = Play(
      id: 'play-${_plays.length + 1}',
      albumId: albumId,
      playedAt: playedAt.toUtc().toIso8601String(),
      sidePlayed: sidePlayed,
      createdAt: playedAt.toUtc().toIso8601String(),
    );
    _plays.add(play);
    return play;
  }

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async => const [];
}

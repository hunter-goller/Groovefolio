import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/screens/album_detail_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_platform_adapter.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
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
    expect(find.text('1957'), findsAtLeastNWidgets(1));
    expect(find.text('Blue Note'), findsAtLeastNWidgets(1));
    expect(find.text('YOUR STATS'), findsOneWidget);
    expect(find.text('Times played'), findsOneWidget);
    expect(find.text('2'), findsAtLeastNWidgets(1));
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
    expect(find.text('Scan an NFC tag'), findsNothing);
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

  testWidgets('shows assigned genres', (tester) async {
    await tester.pumpWidget(
      _testApp(
        playRepository: _FakePlayRepository(const []),
        genreRepository: const _FakeGenreRepository([
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
    );
    await tester.pumpAndSettle();

    final heroGenres = find.byKey(const Key('album-detail-genres'));
    expect(heroGenres, findsOneWidget);
    expect(
      find.descendant(of: heroGenres, matching: find.text('Jazz')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: heroGenres, matching: find.text('Hard Bop')),
      findsOneWidget,
    );
    // The approved detail layout intentionally repeats genres in the Details
    // card, so the screen contains two display instances of each genre.
    expect(find.text('Jazz'), findsNWidgets(2));
    expect(find.text('Hard Bop'), findsNWidgets(2));
  });

  testWidgets('hides the genre row when no genres are assigned', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        playRepository: _FakePlayRepository(const []),
        genreRepository: const _FakeGenreRepository([]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('album-detail-genres')), findsNothing);
  });

  testWidgets('shows Discogs tracklist grouped by vinyl side', (tester) async {
    await tester.pumpWidget(
      _testApp(
        playRepository: _FakePlayRepository(const []),
        trackRepository: const _FakeTrackRepository([
          Track(
            id: 'track-1',
            albumId: 'album-1',
            title: 'Blue Train',
            position: 'A1',
            side: 'A',
            sequence: 0,
            durationSeconds: 642,
            createdAt: '2026-08-19T00:00:00.000Z',
          ),
          Track(
            id: 'track-2',
            albumId: 'album-1',
            title: 'Locomotion',
            position: 'B1',
            side: 'B',
            sequence: 1,
            durationSeconds: 433,
            createdAt: '2026-08-19T00:00:00.000Z',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const PageStorageKey<String>('album-detail-list')),
      const Offset(0, -650),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('album-detail-tracklist')), findsOneWidget);
    expect(find.text('Side A'), findsOneWidget);
    expect(find.text('Side B'), findsOneWidget);
    expect(find.text('Blue Train'), findsAtLeastNWidgets(1));
    expect(find.text('Locomotion'), findsOneWidget);
    expect(find.text('10:42'), findsOneWidget);
  });

  testWidgets('manual album shows clean empty tracklist state', (tester) async {
    await tester.pumpWidget(
      _testApp(
        playRepository: _FakePlayRepository(const []),
        trackRepository: const _FakeTrackRepository([]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const PageStorageKey<String>('album-detail-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No tracklist available for this record.'),
      findsOneWidget,
    );
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

  testWidgets('hides existing-record NFC actions when NFC is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(playRepository: _FakePlayRepository(const [])),
    );
    await tester.pumpAndSettle();

    await _openRecordActions(tester);

    expect(find.text('Link NFC tag'), findsNothing);
    expect(find.text('Rewrite or replace NFC tag'), findsNothing);
  });

  testWidgets('links an NFC tag to an existing record', (tester) async {
    final repository = _FakeNfcTagRepository();
    final nfc = _NfcFixture(repository: repository);

    await tester.pumpWidget(
      _testApp(
        playRepository: _FakePlayRepository(const []),
        nfcAvailability: NfcAvailabilityState.available,
        nfcTagRepository: repository,
        nfcService: nfc.service,
      ),
    );
    await tester.pumpAndSettle();

    await _openRecordActions(tester);
    expect(find.text('Link NFC tag'), findsOneWidget);
    await tester.tap(find.text('Link NFC tag'));
    await tester.pumpAndSettle();

    expect(find.text('NFC tag linked to this record.'), findsOneWidget);
    expect(nfc.platform.writtenUris, [
      Uri.parse('groovefolio://album/album-1'),
    ]);
    expect(
      (await repository.findByAlbum('album-1'))?.nfcTagId,
      '04A7392B916180',
    );
  });

  testWidgets('rewrites or replaces the NFC tag for an existing record', (
    tester,
  ) async {
    final repository = _FakeNfcTagRepository();
    await repository.create(albumId: 'album-1', nfcTagId: '01020304');
    final nfc = _NfcFixture(repository: repository);

    await tester.pumpWidget(
      _testApp(
        playRepository: _FakePlayRepository(const []),
        nfcAvailability: NfcAvailabilityState.available,
        nfcTagRepository: repository,
        nfcService: nfc.service,
      ),
    );
    await tester.pumpAndSettle();

    await _openRecordActions(tester);
    expect(find.text('Rewrite or replace NFC tag'), findsOneWidget);
    await tester.tap(find.text('Rewrite or replace NFC tag'));
    await tester.pumpAndSettle();

    expect(find.text('NFC tag updated for this record.'), findsOneWidget);
    expect(repository.replaceCalls, 1);
    expect(await repository.findByTagId('01020304'), isNull);
    expect(
      (await repository.findByAlbum('album-1'))?.nfcTagId,
      '04A7392B916180',
    );
  });
}

Future<void> _openRecordActions(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Record actions'));
  await tester.pumpAndSettle();
}

Widget _testApp({
  String albumId = 'album-1',
  required IPlayRepository playRepository,
  IGenreRepository? genreRepository,
  ITrackRepository? trackRepository,
  NfcAvailabilityState nfcAvailability = NfcAvailabilityState.unsupported,
  INfcTagRepository? nfcTagRepository,
  NfcService? nfcService,
}) {
  final resolvedNfcTagRepository = nfcTagRepository ?? _FakeNfcTagRepository();
  return ProviderScope(
    overrides: [
      albumRepositoryProvider.overrideWithValue(_FakeAlbumRepository()),
      artistRepositoryProvider.overrideWithValue(_FakeArtistRepository()),
      playRepositoryProvider.overrideWithValue(playRepository),
      genreRepositoryProvider.overrideWithValue(
        genreRepository ?? const _FakeGenreRepository([]),
      ),
      trackRepositoryProvider.overrideWithValue(
        trackRepository ?? const _FakeTrackRepository([]),
      ),
      nfcTagRepositoryProvider.overrideWithValue(resolvedNfcTagRepository),
      nfcAvailabilityProvider.overrideWithValue(AsyncData(nfcAvailability)),
      if (nfcService != null) nfcServiceProvider.overrideWithValue(nfcService),
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

class _FakeTrackRepository implements ITrackRepository {
  const _FakeTrackRepository(this.tracks);

  final List<Track> tracks;

  @override
  Future<List<Track>> findByAlbum(String albumId) async =>
      albumId == 'album-1' ? List.unmodifiable(tracks) : const [];

  @override
  Future<List<Track>> replaceAlbumTracks(
    String albumId,
    Iterable<TrackDraft> tracks,
  ) => throw UnimplementedError();
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

class _NfcFixture {
  _NfcFixture({required this.repository}) : platform = _FakeNfcPlatform() {
    service = NfcService(platform: platform, repository: repository);
  }

  final _FakeNfcPlatform platform;
  final _FakeNfcTagRepository repository;
  late final NfcService service;
}

class _FakeNfcPlatform implements INfcPlatformAdapter {
  final List<Uri> writtenUris = [];
  int finishCalls = 0;

  @override
  Future<NfcAvailabilityState> availability() async {
    return NfcAvailabilityState.available;
  }

  @override
  Future<void> finish() async {
    finishCalls += 1;
  }

  @override
  Future<NfcPlatformTag> poll({required Duration timeout}) async {
    return const NfcPlatformTag(
      identifier: '04:A7:39:2B:91:61:80',
      ndefAvailable: true,
      ndefWritable: true,
    );
  }

  @override
  Future<void> writeUri(Uri uri) async => writtenUris.add(uri);
}

class _FakeNfcTagRepository implements INfcTagRepository {
  final List<NfcTag> tags = [];
  int replaceCalls = 0;

  @override
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) async {
    final tag = NfcTag(
      id: 'nfc-${tags.length + 1}',
      albumId: albumId,
      nfcTagId: nfcTagId,
      writtenAt: (writtenAt ?? DateTime.utc(2026, 9, 4)).toIso8601String(),
    );
    tags.add(tag);
    return tag;
  }

  @override
  Future<int> delete(String id) async {
    final previousLength = tags.length;
    tags.removeWhere((tag) => tag.id == id);
    return previousLength - tags.length;
  }

  @override
  Future<NfcTag?> findByAlbum(String albumId) async {
    for (final tag in tags) {
      if (tag.albumId == albumId) return tag;
    }
    return null;
  }

  @override
  Future<NfcTag?> findByTagId(String nfcTagId) async {
    for (final tag in tags) {
      if (tag.nfcTagId == nfcTagId) return tag;
    }
    return null;
  }

  @override
  Future<NfcTag> replaceForAlbum({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) async {
    replaceCalls += 1;
    tags.removeWhere((tag) => tag.albumId == albumId);
    return create(albumId: albumId, nfcTagId: nfcTagId, writtenAt: writtenAt);
  }
}

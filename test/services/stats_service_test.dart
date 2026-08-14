import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/stats_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  const kindOfBlue = Album(
    id: 'album-kind-of-blue',
    title: 'Kind of Blue',
    artistId: 'artist-miles',
    releaseYear: 1959,
    createdAt: '2026-01-01T00:00:00.000Z',
  );
  const blueTrain = Album(
    id: 'album-blue-train',
    title: 'Blue Train',
    artistId: 'artist-coltrane',
    releaseYear: 1957,
    createdAt: '2026-01-02T00:00:00.000Z',
  );
  const abbeyRoad = Album(
    id: 'album-abbey-road',
    title: 'Abbey Road',
    artistId: 'artist-beatles',
    releaseYear: 1969,
    createdAt: '2026-01-03T00:00:00.000Z',
  );

  group('StatsService', () {
    test(
      'collection summary returns albums, plays, and plays per week',
      () async {
        final service = _service(
          albums: [kindOfBlue, blueTrain, abbeyRoad],
          plays: [
            _play('play-1', kindOfBlue.id, '2026-08-01T12:00:00.000Z'),
            _play('play-2', kindOfBlue.id, '2026-08-08T12:00:00.000Z'),
            _play('play-3', blueTrain.id, '2026-08-15T12:00:00.000Z'),
            _play('play-4', blueTrain.id, '2026-08-15T14:00:00.000Z'),
          ],
          now: () => DateTime.parse('2026-08-15T12:00:00.000Z'),
        );

        final summary = await service.getCollectionSummary();

        expect(summary.totalAlbums, 3);
        expect(summary.totalPlays, 4);
        expect(summary.averagePlaysPerWeek, closeTo(2, 0.0001));
      },
    );

    test(
      'collection summary uses one-week minimum and handles no plays',
      () async {
        final empty = _service(
          albums: [kindOfBlue],
          plays: const [],
          now: () => DateTime.parse('2026-08-15T12:00:00.000Z'),
        );
        final fresh = _service(
          albums: [kindOfBlue],
          plays: [
            _play('play-1', kindOfBlue.id, '2026-08-14T12:00:00.000Z'),
            _play('play-2', kindOfBlue.id, '2026-08-15T12:00:00.000Z'),
          ],
          now: () => DateTime.parse('2026-08-15T12:00:00.000Z'),
        );

        final emptySummary = await empty.getCollectionSummary();
        final freshSummary = await fresh.getCollectionSummary();

        expect(emptySummary.averagePlaysPerWeek, 0);
        expect(freshSummary.averagePlaysPerWeek, 2);
      },
    );

    test(
      'most played ranks by count, breaks ties by title, and limits',
      () async {
        final service = _service(
          albums: [kindOfBlue, blueTrain, abbeyRoad],
          plays: [
            _play('play-1', kindOfBlue.id, '2026-08-01T12:00:00.000Z'),
            _play('play-2', kindOfBlue.id, '2026-08-02T12:00:00.000Z'),
            _play('play-3', blueTrain.id, '2026-08-03T12:00:00.000Z'),
            _play('play-4', blueTrain.id, '2026-08-04T12:00:00.000Z'),
            _play('play-5', abbeyRoad.id, '2026-08-05T12:00:00.000Z'),
            _play('play-6', abbeyRoad.id, '2026-08-06T12:00:00.000Z'),
          ],
        );

        final ranked = await service.getMostPlayedAlbums(2);

        expect(ranked, hasLength(2));
        expect(ranked[0].album.title, 'Abbey Road');
        expect(ranked[0].playCount, 2);
        expect(ranked[1].album.title, 'Blue Train');
        expect(ranked[1].playCount, 2);
        expect(await service.getMostPlayedAlbums(0), isEmpty);
      },
    );

    test('plays by month returns all 12 buckets including zeros', () async {
      final service = _service(
        albums: [kindOfBlue],
        plays: [
          _play('play-1', kindOfBlue.id, '2026-01-15T12:00:00.000Z'),
          _play('play-2', kindOfBlue.id, '2026-01-20T12:00:00.000Z'),
          _play('play-3', kindOfBlue.id, '2026-03-10T12:00:00.000Z'),
          _play('play-4', kindOfBlue.id, '2025-03-10T12:00:00.000Z'),
        ],
      );

      final months = await service.getPlaysByMonth(2026);

      expect(months, hasLength(12));
      expect(months[0].month, 1);
      expect(months[0].playCount, 2);
      expect(months[1].playCount, 0);
      expect(months[2].playCount, 1);
      expect(months[11].month, 12);
    });

    test(
      'album stats returns totals, side counts, and first/last plays',
      () async {
        final service = _service(
          albums: [kindOfBlue],
          plays: [
            _play(
              'play-1',
              kindOfBlue.id,
              '2026-08-10T12:00:00.000Z',
              side: SidePlayed.sideB,
            ),
            _play(
              'play-2',
              kindOfBlue.id,
              '2026-08-08T12:00:00.000Z',
              side: SidePlayed.full,
            ),
            _play(
              'play-3',
              kindOfBlue.id,
              '2026-08-09T12:00:00.000Z',
              side: SidePlayed.sideA,
            ),
            _play(
              'play-4',
              kindOfBlue.id,
              '2026-08-11T12:00:00.000Z',
              side: SidePlayed.full,
            ),
          ],
        );

        final stats = await service.getAlbumStats(kindOfBlue.id);

        expect(stats, isNotNull);
        expect(stats!.totalPlays, 4);
        expect(stats.fullAlbumPlays, 2);
        expect(stats.sideAPlays, 1);
        expect(stats.sideBPlays, 1);
        expect(stats.firstPlayedAt, DateTime.parse('2026-08-08T12:00:00.000Z'));
        expect(stats.lastPlayedAt, DateTime.parse('2026-08-11T12:00:00.000Z'));
      },
    );

    test(
      'album stats handles zero plays, missing album, and blank id',
      () async {
        final service = _service(albums: [kindOfBlue], plays: const []);

        final zero = await service.getAlbumStats(kindOfBlue.id);

        expect(zero, isNotNull);
        expect(zero!.totalPlays, 0);
        expect(zero.firstPlayedAt, isNull);
        expect(zero.lastPlayedAt, isNull);
        expect(await service.getAlbumStats('missing'), isNull);
        await expectLater(service.getAlbumStats('   '), throwsArgumentError);
      },
    );

    test('provider resolves StatsService from repository overrides', () async {
      final albumRepository = _FakeAlbumRepository([kindOfBlue, blueTrain]);
      final playRepository = _FakePlayRepository([
        _play('play-1', kindOfBlue.id, '2026-08-10T12:00:00.000Z'),
      ]);
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(albumRepository),
          playRepositoryProvider.overrideWithValue(playRepository),
        ],
      );
      addTearDown(container.dispose);

      final summary = await container
          .read(statsServiceProvider)
          .getCollectionSummary();

      expect(summary.totalAlbums, 2);
      expect(summary.totalPlays, 1);
    });
  });
}

StatsService _service({
  required Iterable<Album> albums,
  required Iterable<Play> plays,
  DateTime Function()? now,
}) {
  return StatsService(
    albumRepository: _FakeAlbumRepository(albums),
    playRepository: _FakePlayRepository(plays),
    now: now ?? () => DateTime.parse('2026-08-15T12:00:00.000Z'),
  );
}

Play _play(
  String id,
  String albumId,
  String playedAt, {
  SidePlayed side = SidePlayed.full,
}) {
  return Play(
    id: id,
    albumId: albumId,
    playedAt: playedAt,
    sidePlayed: side,
    createdAt: playedAt,
  );
}

class _FakeAlbumRepository implements IAlbumRepository {
  _FakeAlbumRepository(Iterable<Album> albums)
    : _albums = {for (final album in albums) album.id: album};

  final Map<String, Album> _albums;

  @override
  Future<List<Album>> findAll() async => List.unmodifiable(_albums.values);

  @override
  Future<Album?> findById(String id) async => _albums[id];

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
  Future<List<Album>> search(String query) => throw UnimplementedError();

  @override
  Future<bool> update(Album album) => throw UnimplementedError();
}

class _FakePlayRepository implements IPlayRepository {
  _FakePlayRepository(Iterable<Play> plays) : _plays = List.of(plays);

  final List<Play> _plays;

  @override
  Future<List<Play>> findAll() async => List.unmodifiable(_plays);

  @override
  Future<List<Play>> findByAlbum(String albumId) async {
    return _plays.where((play) => play.albumId == albumId).toList();
  }

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) => throw UnimplementedError();

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();

  @override
  Future<int> getPlayCountByAlbum(String albumId) async {
    return _plays.where((play) => play.albumId == albumId).length;
  }

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) =>
      throw UnimplementedError();
}

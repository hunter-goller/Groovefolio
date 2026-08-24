import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/recommendation_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  const jazz = Genre(
    id: 'genre-jazz',
    name: 'Jazz',
    createdAt: '2026-01-01T00:00:00.000Z',
  );
  const rock = Genre(
    id: 'genre-rock',
    name: 'Rock',
    createdAt: '2026-01-01T00:00:00.000Z',
  );

  group('RecommendationService', () {
    test(
      'rediscover excludes albums played inside the recency threshold',
      () async {
        final oldAlbum = _album('old', 'Blue Train', releaseYear: 1957);
        final recentAlbum = _album('recent', 'Kind of Blue', releaseYear: 1959);
        final service = _service(
          albums: [oldAlbum, recentAlbum],
          plays: [
            _play('old-1', oldAlbum.id, '2026-03-01T12:00:00.000Z'),
            _play('old-2', oldAlbum.id, '2026-03-02T12:00:00.000Z'),
            _play('recent-1', recentAlbum.id, '2026-08-20T12:00:00.000Z'),
          ],
        );

        final result = await service.getRecommendations();

        expect(result.rediscover.map((item) => item.album.id), [oldAlbum.id]);
        expect(result.rediscover.single.reason, contains('Last played'));
        expect(result.rediscover.single.reason, contains('2 plays'));
      },
    );

    test('genre recommendations are weighted by actual play history', () async {
      final jazzAnchor = _album('jazz-anchor', 'Jazz Anchor');
      final rockAnchor = _album('rock-anchor', 'Rock Anchor');
      final jazzPick = _album('jazz-pick', 'Somethin Else');
      final rockPick = _album('rock-pick', 'Rumours');
      final service = _service(
        albums: [jazzAnchor, rockAnchor, jazzPick, rockPick],
        plays: [
          for (var index = 0; index < 5; index += 1)
            _play(
              'jazz-$index',
              jazzAnchor.id,
              '2026-08-${index + 1}T12:00:00.000Z',
            ),
          _play('rock-1', rockAnchor.id, '2026-08-06T12:00:00.000Z'),
        ],
        genresByAlbum: {
          jazzAnchor.id: [jazz],
          jazzPick.id: [jazz],
          rockAnchor.id: [rock],
          rockPick.id: [rock],
        },
      );

      final result = await service.getRecommendations();

      expect(result.tasteProfile, isNotNull);
      expect(result.tasteProfile!.topGenres.first.genre.name, 'Jazz');
      expect(result.tasteProfile!.topGenres.first.playCount, 5);
      expect(result.genrePicks.first.album.id, jazzPick.id);
      expect(result.genrePicks.first.reason, contains('Jazz'));
    });

    test(
      'genre recommendation ties are deterministic by title then id',
      () async {
        final anchor = _album('anchor', 'Anchor');
        final blueTrain = _album('blue-train', 'Blue Train');
        final aLoveSupreme = _album('a-love-supreme', 'A Love Supreme');
        final service = _service(
          albums: [anchor, blueTrain, aLoveSupreme],
          plays: [_play('play-1', anchor.id, '2026-08-20T12:00:00.000Z')],
          genresByAlbum: {
            anchor.id: [jazz],
            blueTrain.id: [jazz],
            aLoveSupreme.id: [jazz],
          },
        );

        final result = await service.getRecommendations();

        expect(result.genrePicks.map((item) => item.album.title), [
          'A Love Supreme',
          'Blue Train',
        ]);
      },
    );

    test('favorite era comes from play-weighted release decades', () async {
      final fiftiesAnchor = _album(
        'fifties-anchor',
        'Fifties Anchor',
        releaseYear: 1959,
      );
      final sixtiesAnchor = _album(
        'sixties-anchor',
        'Sixties Anchor',
        releaseYear: 1969,
      );
      final eraPick = _album(
        'era-pick',
        'Saxophone Colossus',
        releaseYear: 1956,
      );
      final service = _service(
        albums: [fiftiesAnchor, sixtiesAnchor, eraPick],
        plays: [
          _play('fifties-1', fiftiesAnchor.id, '2026-08-20T12:00:00.000Z'),
          _play('fifties-2', fiftiesAnchor.id, '2026-08-21T12:00:00.000Z'),
          _play('fifties-3', fiftiesAnchor.id, '2026-08-22T12:00:00.000Z'),
          _play('sixties-1', sixtiesAnchor.id, '2026-08-23T12:00:00.000Z'),
        ],
      );

      final result = await service.getRecommendations();

      expect(result.tasteProfile!.favoriteDecade, 1950);
      expect(result.eraPicks.single.album.id, eraPick.id);
      expect(result.eraPicks.single.reason, contains('1950s'));
    });

    test('no plays returns a low-data result without invented taste', () async {
      final service = _service(
        albums: [_album('album-1', 'Blue Train')],
        plays: const [],
        genresByAlbum: const {},
      );

      final result = await service.getRecommendations();

      expect(result.collectionSize, 1);
      expect(result.tasteProfile, isNull);
      expect(result.rediscover, isEmpty);
      expect(result.genrePicks, isEmpty);
      expect(result.eraPicks, isEmpty);
      expect(result.hasRecommendations, isFalse);
    });

    test('empty collection returns a stable empty result', () async {
      final service = _service(albums: const [], plays: const []);

      final result = await service.getRecommendations();

      expect(result.collectionSize, 0);
      expect(result.tasteProfile, isNull);
      expect(result.hasRecommendations, isFalse);
    });
  });
}

RecommendationService _service({
  required Iterable<Album> albums,
  required Iterable<Play> plays,
  Map<String, List<Genre>> genresByAlbum = const {},
}) {
  final albumList = List<Album>.of(albums);
  final artistIds = albumList.map((album) => album.artistId).toSet();
  return RecommendationService(
    albumRepository: _FakeAlbumRepository(albumList),
    artistRepository: _FakeArtistRepository([
      for (final artistId in artistIds)
        Artist(
          id: artistId,
          name: 'Artist $artistId',
          createdAt: '2026-01-01T00:00:00.000Z',
        ),
    ]),
    playRepository: _FakePlayRepository(plays),
    genreRepository: _FakeGenreRepository(genresByAlbum),
    now: () => DateTime.parse('2026-08-24T12:00:00.000Z'),
  );
}

Album _album(
  String id,
  String title, {
  int? releaseYear,
  String artistId = 'artist-1',
}) {
  return Album(
    id: id,
    title: title,
    artistId: artistId,
    releaseYear: releaseYear,
    createdAt: '2026-01-01T00:00:00.000Z',
  );
}

Play _play(String id, String albumId, String playedAt) {
  return Play(
    id: id,
    albumId: albumId,
    playedAt: playedAt,
    sidePlayed: SidePlayed.full,
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

class _FakeArtistRepository implements IArtistRepository {
  _FakeArtistRepository(Iterable<Artist> artists)
    : _artists = {for (final artist in artists) artist.id: artist};

  final Map<String, Artist> _artists;

  @override
  Future<List<Artist>> findAll() async => List.unmodifiable(_artists.values);

  @override
  Future<Artist?> findById(String id) async => _artists[id];

  @override
  Future<Artist> findOrCreate(String name) => throw UnimplementedError();
}

class _FakeGenreRepository implements IGenreRepository {
  _FakeGenreRepository(Map<String, List<Genre>> genresByAlbum)
    : _genresByAlbum = {
        for (final entry in genresByAlbum.entries)
          entry.key: List<Genre>.of(entry.value),
      };

  final Map<String, List<Genre>> _genresByAlbum;

  @override
  Future<List<Genre>> findByAlbum(String albumId) async {
    return List.unmodifiable(_genresByAlbum[albumId] ?? const <Genre>[]);
  }

  @override
  Future<int> delete(String genreId) => throw UnimplementedError();

  @override
  Future<List<Genre>> findAll() => throw UnimplementedError();

  @override
  Future<Genre?> findById(String id) => throw UnimplementedError();

  @override
  Future<Genre?> findByName(String name) => throw UnimplementedError();

  @override
  Future<Genre> findOrCreate(String name) => throw UnimplementedError();

  @override
  Future<int> removeFromAlbum(String albumId, String genreId) =>
      throw UnimplementedError();

  @override
  Future<void> setAlbumGenres(String albumId, Iterable<String> genreIds) =>
      throw UnimplementedError();
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

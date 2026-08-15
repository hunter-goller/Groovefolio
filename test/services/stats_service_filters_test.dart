import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/genre_repository.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/services/stats_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test(
    'year filter limits collection, ranking, and genre play counts',
    () async {
      final albums = _Albums([
        _album('a1', 'Blue Train', 'artist-1', '2025-01-01T00:00:00.000Z'),
      ]);
      final plays = _Plays([
        _play('p1', 'a1', '2026-02-01T00:00:00.000Z'),
        _play('p2', 'a1', '2025-02-01T00:00:00.000Z'),
      ]);
      final genres = _Genres({
        'a1': [_genre('jazz', 'Jazz')],
      });
      final service = StatsService(
        albumRepository: albums,
        playRepository: plays,
        genreRepository: genres,
        now: () => DateTime(2026, 8, 15),
      );

      final summary = await service.getCollectionSummary(year: 2026);
      final ranked = await service.getMostPlayedAlbums(5, year: 2026);
      final breakdown = await service.getGenreBreakdown(year: 2026);

      expect(summary.totalAlbums, 1);
      expect(summary.totalPlays, 1);
      expect(ranked.single.playCount, 1);
      expect(breakdown.single.playCount, 1);
    },
  );

  test('first vinyl is derived from earliest album createdAt', () async {
    final service = StatsService(
      albumRepository: _Albums([
        _album('later', 'Later', 'artist-1', '2026-05-01T00:00:00.000Z'),
        _album('first', 'First Vinyl', 'artist-1', '2026-01-01T00:00:00.000Z'),
      ]),
      playRepository: _Plays(const []),
      genreRepository: _Genres(const {}),
    );

    final first = await service.getFirstVinyl();

    expect(first?.id, 'first');
    expect(first?.title, 'First Vinyl');
  });
}

Album _album(String id, String title, String artistId, String createdAt) =>
    Album(
      id: id,
      title: title,
      artistId: artistId,
      releaseYear: null,
      label: null,
      artworkPath: null,
      purchaseDate: null,
      purchasePriceCents: null,
      createdAt: createdAt,
    );

Play _play(String id, String albumId, String playedAt) => Play(
  id: id,
  albumId: albumId,
  playedAt: playedAt,
  sidePlayed: SidePlayed.full,
  createdAt: playedAt,
);

Genre _genre(String id, String name) =>
    Genre(id: id, name: name, createdAt: '2026-01-01T00:00:00.000Z');

class _Albums implements IAlbumRepository {
  _Albums(this.values);
  final List<Album> values;

  @override
  Future<List<Album>> findAll() async => values;
  @override
  Future<Album?> findById(String id) async {
    for (final album in values) {
      if (album.id == id) return album;
    }
    return null;
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
  Future<bool> update(Album album) => throw UnimplementedError();
  @override
  Future<int> delete(String id) => throw UnimplementedError();
  @override
  Future<List<Album>> search(String query) async => values;
}

class _Plays implements IPlayRepository {
  _Plays(this.values);
  final List<Play> values;

  @override
  Future<List<Play>> findAll() async => values;
  @override
  Future<List<Play>> findByAlbum(String albumId) async =>
      values.where((play) => play.albumId == albumId).toList();
  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) => throw UnimplementedError();
  @override
  Future<int> deleteById(String id) => throw UnimplementedError();
  @override
  Future<int> getPlayCountByAlbum(String albumId) async =>
      values.where((play) => play.albumId == albumId).length;
  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async => const [];
}

class _Genres implements IGenreRepository {
  _Genres(this.byAlbum);
  final Map<String, List<Genre>> byAlbum;

  @override
  Future<List<Genre>> findByAlbum(String albumId) async =>
      byAlbum[albumId] ?? const [];
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
  Future<int> removeFromAlbum(String albumId, String genreId) =>
      throw UnimplementedError();
  @override
  Future<int> delete(String genreId) => throw UnimplementedError();
}

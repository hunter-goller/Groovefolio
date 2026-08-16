import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/stats_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test(
    'plays by year aggregates real history and orders years ascending',
    () async {
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(_Albums()),
          playRepositoryProvider.overrideWithValue(
            _Plays([
              _play('p1', '2026-08-01T12:00:00.000Z'),
              _play('p2', '2024-02-01T12:00:00.000Z'),
              _play('p3', '2025-04-01T12:00:00.000Z'),
              _play('p4', '2024-10-01T12:00:00.000Z'),
              _play('p5', '2023-06-01T12:00:00.000Z'),
              _play('p6', '2026-08-02T12:00:00.000Z'),
              _play('p7', '2026-08-03T12:00:00.000Z'),
            ]),
          ),
          genreRepositoryProvider.overrideWithValue(_Genres()),
        ],
      );
      addTearDown(container.dispose);

      final years = await container.read(statsServiceProvider).getPlaysByYear();

      expect(years.map((item) => item.year), [2023, 2024, 2025, 2026]);
      expect(years.map((item) => item.playCount), [1, 2, 1, 3]);
      expect(years.fold<int>(0, (total, item) => total + item.playCount), 7);
    },
  );

  test('plays by year returns empty for an empty listening history', () async {
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(_Albums()),
        playRepositoryProvider.overrideWithValue(_Plays(const [])),
        genreRepositoryProvider.overrideWithValue(_Genres()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(statsServiceProvider).getPlaysByYear(),
      isEmpty,
    );
  });
}

Play _play(String id, String playedAt) => Play(
  id: id,
  albumId: 'album-1',
  playedAt: playedAt,
  sidePlayed: SidePlayed.full,
  createdAt: playedAt,
);

class _Albums implements IAlbumRepository {
  @override
  Future<List<Album>> findAll() async => const [];

  @override
  Future<Album?> findById(String id) async => null;

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
  Future<List<Album>> search(String query) => throw UnimplementedError();
}

class _Plays implements IPlayRepository {
  _Plays(this.plays);
  final List<Play> plays;

  @override
  Future<List<Play>> findAll() async => List.unmodifiable(plays);

  @override
  Future<List<Play>> findByAlbum(String albumId) async => const [];

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) => throw UnimplementedError();

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();

  @override
  Future<int> getPlayCountByAlbum(String albumId) async => 0;

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) =>
      throw UnimplementedError();
}

class _Genres implements IGenreRepository {
  @override
  Future<List<Genre>> findAll() async => const [];

  @override
  Future<Genre?> findById(String id) async => null;

  @override
  Future<Genre?> findByName(String name) async => null;

  @override
  Future<Genre> findOrCreate(String name) => throw UnimplementedError();

  @override
  Future<List<Genre>> findByAlbum(String albumId) async => const [];

  @override
  Future<void> setAlbumGenres(String albumId, Iterable<String> genreIds) =>
      throw UnimplementedError();

  @override
  Future<int> removeFromAlbum(String albumId, String genreId) =>
      throw UnimplementedError();

  @override
  Future<int> delete(String genreId) => throw UnimplementedError();
}

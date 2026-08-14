import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';

void main() {
  const rock = Genre(
    id: 'genre-rock',
    name: 'Rock',
    createdAt: '2026-08-14T12:00:00.000Z',
  );
  const jazz = Genre(
    id: 'genre-jazz',
    name: 'Jazz',
    createdAt: '2026-08-14T12:00:00.000Z',
  );

  test('genresProvider delegates to the overridable repository', () async {
    final fake = _FakeGenreRepository(allGenres: const [jazz, rock]);
    final container = ProviderContainer(
      overrides: [genreRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final result = await container.read(genresProvider.future);

    expect(result, const [jazz, rock]);
    expect(fake.findAllCalls, 1);
  });

  test(
    'albumGenresProvider trims album ID and delegates to repository',
    () async {
      final fake = _FakeGenreRepository(
        albumGenres: const {
          'album-1': [rock],
        },
      );
      final container = ProviderContainer(
        overrides: [genreRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        albumGenresProvider(' album-1 ').future,
      );

      expect(result, const [rock]);
      expect(fake.requestedAlbumIds, ['album-1']);
    },
  );

  test('albumGenresProvider returns empty for a blank album ID', () async {
    final fake = _FakeGenreRepository();
    final container = ProviderContainer(
      overrides: [genreRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final result = await container.read(albumGenresProvider('   ').future);

    expect(result, isEmpty);
    expect(fake.requestedAlbumIds, isEmpty);
  });
}

class _FakeGenreRepository implements IGenreRepository {
  _FakeGenreRepository({
    this.allGenres = const [],
    this.albumGenres = const {},
  });

  final List<Genre> allGenres;
  final Map<String, List<Genre>> albumGenres;
  int findAllCalls = 0;
  final List<String> requestedAlbumIds = [];

  @override
  Future<int> delete(String genreId) => throw UnimplementedError();

  @override
  Future<List<Genre>> findAll() async {
    findAllCalls += 1;
    return allGenres;
  }

  @override
  Future<List<Genre>> findByAlbum(String albumId) async {
    requestedAlbumIds.add(albumId);
    return albumGenres[albumId] ?? const [];
  }

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

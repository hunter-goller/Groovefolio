import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/utils/id_generator.dart';

part 'genre_repository.g.dart';

/// Contract for genre persistence and album-to-genre assignments.
///
/// Callers work with domain rows and IDs only. UUID generation, timestamps,
/// Drift companions, and join-table writes stay inside the repository.
abstract interface class IGenreRepository {
  /// Returns every genre in deterministic, case-insensitive name order.
  Future<List<Genre>> findAll();

  Future<Genre?> findById(String id);

  /// Finds a genre by name using a case-insensitive match.
  Future<Genre?> findByName(String name);

  /// Returns an existing case-insensitive name match or creates a new genre.
  Future<Genre> findOrCreate(String name);

  /// Returns the genres currently assigned to [albumId], ordered by name.
  Future<List<Genre>> findByAlbum(String albumId);

  /// Atomically replaces all genre assignments for [albumId].
  ///
  /// Duplicate IDs in [genreIds] are collapsed before writing. Passing an
  /// empty iterable removes every genre assignment from the album without
  /// deleting any Genre rows.
  Future<void> setAlbumGenres(String albumId, Iterable<String> genreIds);

  /// Removes one album/genre mapping without deleting either parent row.
  Future<int> removeFromAlbum(String albumId, String genreId);

  /// Deletes a Genre row. Schema-v3 cascading removes its AlbumGenres rows.
  Future<int> delete(String genreId);
}

/// Drift-backed implementation of [IGenreRepository].
class GenreRepository implements IGenreRepository {
  GenreRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Genre>> findAll() {
    final query = _db.select(_db.genres)
      ..orderBy([(genre) => OrderingTerm.asc(genre.name.lower())]);
    return query.get();
  }

  @override
  Future<Genre?> findById(String id) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return Future.value(null);

    final query = _db.select(_db.genres)
      ..where((genre) => genre.id.equals(normalizedId));
    return query.getSingleOrNull();
  }

  @override
  Future<Genre?> findByName(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return Future.value(null);

    final query = _db.select(_db.genres)
      ..where(
        (genre) => genre.name.lower().equals(normalizedName.toLowerCase()),
      );
    return query.getSingleOrNull();
  }

  @override
  Future<Genre> findOrCreate(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Genre name cannot be empty.');
    }

    return _db.transaction(() async {
      final existingQuery = _db.select(_db.genres)
        ..where(
          (genre) => genre.name.lower().equals(normalizedName.toLowerCase()),
        );
      final existing = await existingQuery.getSingleOrNull();
      if (existing != null) return existing;

      return _db
          .into(_db.genres)
          .insertReturning(
            GenresCompanion.insert(
              id: generateId('genre'),
              name: normalizedName,
              createdAt: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    });
  }

  @override
  Future<List<Genre>> findByAlbum(String albumId) async {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) return const [];

    final query =
        _db.select(_db.genres).join([
            innerJoin(
              _db.albumGenres,
              _db.albumGenres.genreId.equalsExp(_db.genres.id),
              useColumns: false,
            ),
          ])
          ..where(_db.albumGenres.albumId.equals(normalizedAlbumId))
          ..orderBy([OrderingTerm.asc(_db.genres.name.lower())]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.genres)).toList();
  }

  @override
  Future<void> setAlbumGenres(String albumId, Iterable<String> genreIds) {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }

    final normalizedGenreIds = <String>{};
    for (final genreId in genreIds) {
      final normalizedGenreId = genreId.trim();
      if (normalizedGenreId.isEmpty) {
        throw ArgumentError.value(
          genreId,
          'genreIds',
          'Genre IDs cannot be empty.',
        );
      }
      normalizedGenreIds.add(normalizedGenreId);
    }

    return _db.transaction(() async {
      final albumQuery = _db.select(_db.albums)
        ..where((album) => album.id.equals(normalizedAlbumId));
      final album = await albumQuery.getSingleOrNull();
      if (album == null) {
        throw StateError('Album $normalizedAlbumId does not exist.');
      }

      if (normalizedGenreIds.isNotEmpty) {
        final genres = await (_db.select(
          _db.genres,
        )..where((genre) => genre.id.isIn(normalizedGenreIds))).get();
        final foundIds = genres.map((genre) => genre.id).toSet();
        final missingIds = normalizedGenreIds.difference(foundIds);
        if (missingIds.isNotEmpty) {
          throw StateError('Genre ${missingIds.first} does not exist.');
        }
      }

      await (_db.delete(
        _db.albumGenres,
      )..where((row) => row.albumId.equals(normalizedAlbumId))).go();

      for (final genreId in normalizedGenreIds) {
        await _db
            .into(_db.albumGenres)
            .insert(
              AlbumGenresCompanion.insert(
                albumId: normalizedAlbumId,
                genreId: genreId,
              ),
            );
      }
    });
  }

  @override
  Future<int> removeFromAlbum(String albumId, String genreId) {
    final normalizedAlbumId = albumId.trim();
    final normalizedGenreId = genreId.trim();
    if (normalizedAlbumId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }
    if (normalizedGenreId.isEmpty) {
      throw ArgumentError.value(
        genreId,
        'genreId',
        'Genre ID cannot be empty.',
      );
    }

    final query = _db.delete(_db.albumGenres)
      ..where(
        (row) =>
            row.albumId.equals(normalizedAlbumId) &
            row.genreId.equals(normalizedGenreId),
      );
    return query.go();
  }

  @override
  Future<int> delete(String genreId) {
    final normalizedGenreId = genreId.trim();
    if (normalizedGenreId.isEmpty) {
      throw ArgumentError.value(
        genreId,
        'genreId',
        'Genre ID cannot be empty.',
      );
    }

    final query = _db.delete(_db.genres)
      ..where((genre) => genre.id.equals(normalizedGenreId));
    return query.go();
  }
}

/// Repository dependency used by feature/service providers.
@riverpod
IGenreRepository genreRepository(Ref ref) {
  return GenreRepository(ref.watch(databaseProvider));
}

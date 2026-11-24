import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/utils/id_generator.dart';
import 'package:vinyl_app/utils/name_match.dart';

part 'artist_repository.g.dart';

/// Contract for artist persistence operations.
abstract interface class IArtistRepository {
  /// Finds an artist by name using a case-insensitive match (see
  /// [nameMatchKey]), or creates one when no matching artist exists.
  Future<Artist> findOrCreate(String name);

  Future<Artist?> findById(String id);

  Future<List<Artist>> findAll();
}

/// Drift-backed implementation of [IArtistRepository].
class ArtistRepository implements IArtistRepository {
  ArtistRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Artist> findOrCreate(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Artist name cannot be empty.');
    }

    return _db.transaction(() async {
      // Compared in Dart, not SQL: SQLite's lower() is ASCII-only. If older
      // duplicates exist, the earliest-created one is reused.
      final key = nameMatchKey(trimmedName);
      final candidates =
          await (_db.select(_db.artists)..orderBy([
                (artist) => OrderingTerm.asc(artist.createdAt),
                (artist) => OrderingTerm.asc(artist.id),
              ]))
              .get();
      for (final artist in candidates) {
        if (nameMatchKey(artist.name) == key) {
          return artist;
        }
      }

      final now = DateTime.now().toUtc();
      final id = generateId('artist');

      return _db
          .into(_db.artists)
          .insertReturning(
            ArtistsCompanion.insert(
              id: id,
              name: trimmedName,
              createdAt: now.toIso8601String(),
            ),
          );
    });
  }

  @override
  Future<Artist?> findById(String id) {
    final query = _db.select(_db.artists)
      ..where((artist) => artist.id.equals(id));
    return query.getSingleOrNull();
  }

  @override
  Future<List<Artist>> findAll() {
    return _db.select(_db.artists).get();
  }
}

/// Repository dependency used by feature/service providers.
@riverpod
IArtistRepository artistRepository(Ref ref) {
  return ArtistRepository(ref.watch(databaseProvider));
}

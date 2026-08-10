import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/utils/id_generator.dart';

part 'artist_repository.g.dart';

/// Contract for artist persistence operations.
abstract interface class IArtistRepository {
  /// Finds an artist by name using a case-insensitive match, or creates one
  /// when no matching artist exists.
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
      final existingQuery = _db.select(_db.artists)
        ..where(
          (artist) => artist.name.lower().equals(trimmedName.toLowerCase()),
        );
      final existing = await existingQuery.getSingleOrNull();

      if (existing != null) {
        return existing;
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

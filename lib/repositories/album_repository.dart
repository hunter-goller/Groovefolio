import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';

part 'album_repository.g.dart';

/// Contract for album persistence operations.
///
/// Keeping callers behind this interface makes the repository replaceable in
/// tests and prevents feature code from querying Drift directly.
abstract interface class IAlbumRepository {
  Future<List<Album>> findAll();

  Future<Album?> findById(String id);

  Future<int> create(AlbumsCompanion album);

  Future<bool> update(Album album);

  Future<int> delete(String id);

  /// Searches album titles and artist names using a case-insensitive
  /// substring match.
  Future<List<Album>> search(String query);
}

/// Drift-backed implementation of [IAlbumRepository].
class AlbumRepository implements IAlbumRepository {
  AlbumRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Album>> findAll() {
    return _db.select(_db.albums).get();
  }

  @override
  Future<Album?> findById(String id) {
    final query = _db.select(_db.albums)..where((album) => album.id.equals(id));
    return query.getSingleOrNull();
  }

  @override
  Future<int> create(AlbumsCompanion album) {
    return _db.into(_db.albums).insert(album);
  }

  @override
  Future<bool> update(Album album) {
    return _db.update(_db.albums).replace(album);
  }

  @override
  Future<int> delete(String id) {
    final query = _db.delete(_db.albums)..where((album) => album.id.equals(id));
    return query.go();
  }

  @override
  Future<List<Album>> search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return findAll();
    }

    final statement = _db.select(_db.albums).join([
      innerJoin(
        _db.artists,
        _db.artists.id.equalsExp(_db.albums.artistId),
        useColumns: false,
      ),
    ]);

    statement.where(
      _db.albums.title.lower().contains(normalizedQuery) |
          _db.artists.name.lower().contains(normalizedQuery),
    );

    final rows = await statement.get();
    return rows.map((row) => row.readTable(_db.albums)).toList();
  }
}

/// Repository dependency used by feature/service providers.
///
/// Exposing the interface keeps the provider override-friendly in tests.
@riverpod
IAlbumRepository albumRepository(Ref ref) {
  return AlbumRepository(ref.watch(databaseProvider));
}

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/utils/id_generator.dart';

part 'album_repository.g.dart';

/// Contract for album persistence operations.
///
/// Keeping callers behind this interface makes the repository replaceable in
/// tests and prevents feature code from querying Drift directly.
abstract interface class IAlbumRepository {
  Future<List<Album>> findAll();

  Future<Album?> findById(String id);

  /// Creates an album while keeping persistence-only metadata inside the
  /// repository boundary.
  Future<Album> create({
    required String title,
    required String artistId,
    int? releaseYear,
    String? label,
    String? artworkPath,
    DateTime? purchaseDate,
    int? purchasePriceCents,
  });

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
  Future<Album> create({
    required String title,
    required String artistId,
    int? releaseYear,
    String? label,
    String? artworkPath,
    DateTime? purchaseDate,
    int? purchasePriceCents,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedArtistId = artistId.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Album title cannot be empty.');
    }
    if (normalizedArtistId.isEmpty) {
      throw ArgumentError.value(
        artistId,
        'artistId',
        'Artist ID cannot be empty.',
      );
    }

    final companion = AlbumsCompanion.insert(
      id: generateId('album'),
      title: normalizedTitle,
      artistId: normalizedArtistId,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      releaseYear: Value(releaseYear),
      label: Value(_trimNullable(label)),
      artworkPath: Value(_trimNullable(artworkPath)),
      purchaseDate: Value(purchaseDate?.toUtc().toIso8601String()),
      purchasePriceCents: Value(purchasePriceCents),
    );

    return _db.into(_db.albums).insertReturning(companion);
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

  String? _trimNullable(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Repository dependency used by feature/service providers.
///
/// Exposing the interface keeps the provider override-friendly in tests.
@riverpod
IAlbumRepository albumRepository(Ref ref) {
  return AlbumRepository(ref.watch(databaseProvider));
}

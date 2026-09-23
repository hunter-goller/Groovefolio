import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';

/// Maps each local album to at most one exact Discogs release ID.
/// Release IDs are unique across the collection for import deduplication.
abstract interface class IDiscogsReleaseLinkRepository {
  /// Links an exact release to [albumId]; a duplicate release ID attached
  /// elsewhere fails under the database unique constraint.
  Future<void> link({required String albumId, required int releaseId});
  Future<int?> findReleaseIdForAlbum(String albumId);
  Future<String?> findAlbumIdForRelease(int releaseId);
  Future<Set<int>> findAllReleaseIds();
}

/// Drift implementation of the local exact-release identity mapping.
class DiscogsReleaseLinkRepository implements IDiscogsReleaseLinkRepository {
  const DiscogsReleaseLinkRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> link({required String albumId, required int releaseId}) async {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }
    if (releaseId <= 0) {
      throw ArgumentError.value(
        releaseId,
        'releaseId',
        'Release ID must be positive.',
      );
    }

    await _db
        .into(_db.albumDiscogsReleases)
        .insertOnConflictUpdate(
          AlbumDiscogsReleasesCompanion.insert(
            albumId: normalizedAlbumId,
            releaseId: releaseId,
          ),
        );
  }

  @override
  Future<int?> findReleaseIdForAlbum(String albumId) async {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) return null;
    final query = _db.select(_db.albumDiscogsReleases)
      ..where((row) => row.albumId.equals(normalizedAlbumId));
    return (await query.getSingleOrNull())?.releaseId;
  }

  @override
  Future<String?> findAlbumIdForRelease(int releaseId) async {
    final query = _db.select(_db.albumDiscogsReleases)
      ..where((row) => row.releaseId.equals(releaseId));
    return (await query.getSingleOrNull())?.albumId;
  }

  @override
  Future<Set<int>> findAllReleaseIds() async {
    final rows = await _db.select(_db.albumDiscogsReleases).get();
    return rows.map((row) => row.releaseId).toSet();
  }
}

final discogsReleaseLinkRepositoryProvider =
    Provider<IDiscogsReleaseLinkRepository>((ref) {
      return DiscogsReleaseLinkRepository(ref.watch(databaseProvider));
    });

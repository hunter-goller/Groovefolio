import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';

/// Persistence boundary for the debug-only "reset local app data" workflow.
abstract interface class ILocalDataResetRepository {
  /// Removes every local collection-owned database row in one transaction.
  ///
  /// Discogs OAuth credentials are deliberately out of scope because they are
  /// stored in secure storage rather than SQLite.
  Future<void> clearCollectionData();
}

class LocalDataResetRepository implements ILocalDataResetRepository {
  const LocalDataResetRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> clearCollectionData() {
    return _db.transaction(() async {
      // Delete dependent rows explicitly so this maintenance operation remains
      // obvious even though schema v6 also cascades most album-owned data.
      await _db.delete(_db.tracks).go();
      await _db.delete(_db.albumDiscogsReleases).go();
      await _db.delete(_db.albumGenres).go();
      await _db.delete(_db.nfcTags).go();
      await _db.delete(_db.plays).go();
      await _db.delete(_db.albums).go();
      await _db.delete(_db.genres).go();
      await _db.delete(_db.artists).go();
    });
  }
}

final localDataResetRepositoryProvider = Provider<ILocalDataResetRepository>((
  ref,
) {
  return LocalDataResetRepository(ref.watch(databaseProvider));
});

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';

part 'play_repository.g.dart';

/// Contract for play-history persistence and play-derived collection queries.
abstract interface class IPlayRepository {
  Future<int> create(PlaysCompanion play);

  /// Returns plays for [albumId], newest first.
  Future<List<Play>> findByAlbum(String albumId);

  Future<List<Play>> findAll();

  Future<int> deleteById(String id);

  Future<int> getPlayCountByAlbum(String albumId);

  /// Returns distinct albums ordered by the date of their most recent play.
  ///
  /// TODO(VinylApp-Performance): This currently loads all plays and performs
  /// distinct-album selection in Dart. This is acceptable for the expected
  /// local dataset size, but could be moved to a SQL GROUP BY / MAX query if
  /// play history grows enough for this to become a measurable bottleneck.
  Future<List<Album>> getRecentlyPlayed(int limit);
}

/// Drift-backed implementation of [IPlayRepository].
class PlayRepository implements IPlayRepository {
  PlayRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> create(PlaysCompanion play) {
    return _db.into(_db.plays).insert(play);
  }

  @override
  Future<List<Play>> findByAlbum(String albumId) {
    final query = _db.select(_db.plays)
      ..where((play) => play.albumId.equals(albumId))
      ..orderBy([(play) => OrderingTerm.desc(play.playedAt)]);
    return query.get();
  }

  @override
  Future<List<Play>> findAll() {
    return _db.select(_db.plays).get();
  }

  @override
  Future<int> deleteById(String id) {
    final query = _db.delete(_db.plays)..where((play) => play.id.equals(id));
    return query.go();
  }

  @override
  Future<int> getPlayCountByAlbum(String albumId) async {
    final count = _db.plays.id.count();
    final query = _db.selectOnly(_db.plays)
      ..addColumns([count])
      ..where(_db.plays.albumId.equals(albumId));

    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async {
    if (limit <= 0) {
      return const [];
    }

    final latestPlayedAt = _db.plays.playedAt.max();
    final query = _db.selectOnly(_db.plays)
      ..addColumns([_db.plays.albumId, latestPlayedAt])
      ..groupBy([_db.plays.albumId])
      ..orderBy([OrderingTerm.desc(latestPlayedAt)])
      ..limit(limit);
    final rows = await query.get();
    final albumIds = rows
        .map((row) => row.read(_db.plays.albumId))
        .whereType<String>()
        .toList();

    if (albumIds.isEmpty) return const [];

    final albums = await (_db.select(
      _db.albums,
    )..where((album) => album.id.isIn(albumIds))).get();
    final albumsById = {for (final album in albums) album.id: album};
    return [for (final albumId in albumIds) ?albumsById[albumId]];
  }
}

/// Repository dependency used by feature/service providers.
@riverpod
IPlayRepository playRepository(Ref ref) {
  return PlayRepository(ref.watch(databaseProvider));
}

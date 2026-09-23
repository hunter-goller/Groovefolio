import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/utils/id_generator.dart';

part 'track_repository.g.dart';

/// Persistence-agnostic input used to replace an album's tracklist.
class TrackDraft {
  const TrackDraft({
    required this.title,
    required this.sequence,
    this.position,
    this.side,
    this.durationSeconds,
  });

  final String title;
  final int sequence;
  final String? position;
  final String? side;
  final int? durationSeconds;
}

/// Complete tracklist persistence; callers supply domain drafts rather than
/// Drift companions and never update individual rows out of sequence.
abstract interface class ITrackRepository {
  /// Returns one album's tracks in deterministic release order.
  Future<List<Track>> findByAlbum(String albumId);

  /// Atomically replaces the complete tracklist for [albumId].
  ///
  /// Passing an empty iterable clears the album's tracklist. Drift companions,
  /// IDs, and timestamps remain inside the repository boundary.
  Future<List<Track>> replaceAlbumTracks(
    String albumId,
    Iterable<TrackDraft> tracks,
  );
}

/// Drift implementation that validates drafts and swaps a whole album's
/// tracklist inside one transaction.
class TrackRepository implements ITrackRepository {
  TrackRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Track>> findByAlbum(String albumId) {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) return Future.value(const <Track>[]);

    final query = _db.select(_db.tracks)
      ..where((track) => track.albumId.equals(normalizedAlbumId))
      ..orderBy([
        (track) => OrderingTerm.asc(track.sequence),
        (track) => OrderingTerm.asc(track.id),
      ]);
    return query.get();
  }

  @override
  Future<List<Track>> replaceAlbumTracks(
    String albumId,
    Iterable<TrackDraft> tracks,
  ) {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }

    final drafts = tracks.toList(growable: false);
    for (final draft in drafts) {
      if (draft.title.trim().isEmpty) {
        throw ArgumentError.value(
          draft.title,
          'tracks',
          'Track title cannot be empty.',
        );
      }
      if (draft.sequence < 0) {
        throw ArgumentError.value(
          draft.sequence,
          'tracks',
          'Track sequence cannot be negative.',
        );
      }
      if (draft.durationSeconds != null && draft.durationSeconds! < 0) {
        throw ArgumentError.value(
          draft.durationSeconds,
          'tracks',
          'Track duration cannot be negative.',
        );
      }
    }

    return _db.transaction(() async {
      final album = await (_db.select(
        _db.albums,
      )..where((row) => row.id.equals(normalizedAlbumId))).getSingleOrNull();
      if (album == null) {
        throw StateError('Album $normalizedAlbumId does not exist.');
      }

      await (_db.delete(
        _db.tracks,
      )..where((row) => row.albumId.equals(normalizedAlbumId))).go();

      final created = <Track>[];
      final now = DateTime.now().toUtc().toIso8601String();
      for (final draft in drafts) {
        created.add(
          await _db
              .into(_db.tracks)
              .insertReturning(
                TracksCompanion.insert(
                  id: generateId('track'),
                  albumId: normalizedAlbumId,
                  title: draft.title.trim(),
                  position: Value(_trimNullable(draft.position)),
                  side: Value(_normalizeSide(draft.side)),
                  sequence: draft.sequence,
                  durationSeconds: Value(draft.durationSeconds),
                  createdAt: now,
                ),
              ),
        );
      }

      created.sort((a, b) {
        final bySequence = a.sequence.compareTo(b.sequence);
        return bySequence != 0 ? bySequence : a.id.compareTo(b.id);
      });
      return List.unmodifiable(created);
    });
  }

  String? _trimNullable(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _normalizeSide(String? value) {
    final normalized = _trimNullable(value)?.toUpperCase();
    return normalized;
  }
}

@riverpod
ITrackRepository trackRepository(Ref ref) {
  return TrackRepository(ref.watch(databaseProvider));
}

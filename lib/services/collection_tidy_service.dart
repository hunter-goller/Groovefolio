import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';
import 'package:vinyl_app/repositories/genre_repository.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';

/// What one tidy pass removed.
class TidyResult {
  const TidyResult({this.artists = 0, this.genres = 0, this.artworkFiles = 0});

  final int artists;
  final int genres;
  final int artworkFiles;
}

/// Removes leftovers that no record uses any more: artists and genres left
/// behind by edits and deletes, and cover files whose record is gone.
///
/// Only unreferenced rows are deleted, so nothing a record still uses can be
/// lost. Callers run this after a successful write and treat failure as
/// harmless: the next pass cleans up whatever this one could not.
class CollectionTidyService {
  const CollectionTidyService(this._db, this._artwork);

  final AppDatabase _db;
  final ArtworkStorageService _artwork;

  /// Deletes artists with no records and genres on no record.
  Future<TidyResult> removeUnusedArtistsAndGenres() {
    return _db.transaction(() async {
      final artists = await _db.customUpdate(
        'DELETE FROM artists WHERE id NOT IN (SELECT artist_id FROM albums)',
        updates: {_db.artists},
        updateKind: UpdateKind.delete,
      );
      final genres = await _db.customUpdate(
        'DELETE FROM genres '
        'WHERE id NOT IN (SELECT genre_id FROM album_genres)',
        updates: {_db.genres},
        updateKind: UpdateKind.delete,
      );
      return TidyResult(artists: artists, genres: genres);
    });
  }

  /// Unused artists and genres, then stray cover files.
  Future<TidyResult> tidy() async {
    final rows = await removeUnusedArtistsAndGenres();
    final albums = await _db.select(_db.albums).get();
    final files = await _artwork.deleteStrayArtwork(
      albumIds: {for (final album in albums) album.id},
      referencedPaths: {for (final album in albums) ?album.artworkPath},
    );
    return TidyResult(
      artists: rows.artists,
      genres: rows.genres,
      artworkFiles: files,
    );
  }
}

/// Null unless records live in the app database: tidying runs SQL on the
/// database the repositories use, so with other repository implementations
/// (tests, previews) there is nothing for it to tidy.
final collectionTidyServiceProvider = Provider<CollectionTidyService?>((ref) {
  if (ref.watch(artistRepositoryProvider) is! ArtistRepository ||
      ref.watch(genreRepositoryProvider) is! GenreRepository) {
    return null;
  }
  return CollectionTidyService(
    ref.watch(databaseProvider),
    ref.watch(artworkStorageServiceProvider),
  );
});

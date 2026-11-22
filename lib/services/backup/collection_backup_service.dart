import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/db/migrations/schema_versions.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/types/side_played.dart';

/// Identifies Groovefolio backup files and their layout.
///
/// A backup is a zip containing [manifestName] (versioned JSON with every
/// local table) and `artwork/<albumId>.jpg` for each stored cover. Bump
/// [currentVersion] whenever the JSON layout changes, and keep reading older
/// versions so existing backups stay restorable.
abstract final class BackupFormat {
  static const name = 'groovefolio-backup';
  static const currentVersion = 1;
  static const manifestName = 'groovefolio-backup.json';
  static const artworkFolder = 'artwork';

  /// Upper bounds that keep a damaged or hostile file from exhausting memory.
  static const maxEntries = 50000;
  static const maxUncompressedBytes = 512 * 1024 * 1024;
}

/// A backup file that can't be restored, with a message safe to show users.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Restore refused because the collection already has records.
class BackupRestoreNotEmptyException implements Exception {
  const BackupRestoreNotEmptyException();
}

/// Counts shown before restoring and after it finishes.
class BackupSummary {
  const BackupSummary({
    required this.albums,
    required this.plays,
    required this.artworkFiles,
    required this.exportedAt,
  });

  final int albums;
  final int plays;
  final int artworkFiles;
  final DateTime? exportedAt;
}

/// A parsed, validated backup ready to restore.
class BackupContents {
  BackupContents._({
    required this.artists,
    required this.albums,
    required this.genres,
    required this.albumGenres,
    required this.discogsReleases,
    required this.tracks,
    required this.plays,
    required this.nfcTags,
    required this.artwork,
    required this.exportedAt,
  });

  final List<Artist> artists;
  final List<Album> albums;
  final List<Genre> genres;
  final List<AlbumGenre> albumGenres;
  final List<AlbumDiscogsRelease> discogsReleases;
  final List<Track> tracks;
  final List<Play> plays;
  final List<NfcTag> nfcTags;

  /// Cover bytes keyed by album ID.
  final Map<String, Uint8List> artwork;
  final DateTime? exportedAt;

  BackupSummary get summary => BackupSummary(
    albums: albums.length,
    plays: plays.length,
    artworkFiles: artwork.length,
    exportedAt: exportedAt,
  );
}

/// Creates and restores local collection backups. Nothing leaves the device:
/// the caller decides where the bytes are saved.
class CollectionBackupService {
  CollectionBackupService({
    required AppDatabase database,
    required ArtworkStorageService artworkStorage,
    DateTime Function()? clock,
  }) : _db = database,
       _artwork = artworkStorage,
       _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final ArtworkStorageService _artwork;
  final DateTime Function() _clock;

  /// IDs safe to use in an artwork file name (no separators or dot segments).
  static final _safeId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$');

  /// Suggested file name, for example `groovefolio-backup-2026-11-22.zip`.
  String suggestedFileName() {
    final now = _clock();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'groovefolio-backup-${now.year}-${two(now.month)}-${two(now.day)}.zip';
  }

  Future<bool> isCollectionEmpty() async {
    final count = _db.albums.id.count();
    final query = _db.selectOnly(_db.albums)..addColumns([count]);
    return (await query.map((row) => row.read(count)!).getSingle()) == 0;
  }

  /// Builds a backup of every local table plus stored covers.
  ///
  /// Rows are read in one transaction so the snapshot is consistent.
  Future<Uint8List> createBackup() async {
    final snapshot = await _db.transaction(() async {
      return (
        artists: await _db.select(_db.artists).get(),
        albums: await _db.select(_db.albums).get(),
        genres: await _db.select(_db.genres).get(),
        albumGenres: await _db.select(_db.albumGenres).get(),
        releases: await _db.select(_db.albumDiscogsReleases).get(),
        tracks: await _db.select(_db.tracks).get(),
        plays: await _db.select(_db.plays).get(),
        nfcTags: await _db.select(_db.nfcTags).get(),
      );
    });

    final archive = Archive();
    final albumJson = <Map<String, Object?>>[];
    for (final album in snapshot.albums) {
      String? artworkEntry;
      final file = _artwork.artworkFile(album.artworkPath);
      if (file != null && _safeId.hasMatch(album.id)) {
        artworkEntry = '${BackupFormat.artworkFolder}/${album.id}.jpg';
        archive.add(ArchiveFile.bytes(artworkEntry, await file.readAsBytes()));
      }
      albumJson.add(_albumToJson(album, artworkEntry));
    }

    final manifest = <String, Object?>{
      'format': BackupFormat.name,
      'formatVersion': BackupFormat.currentVersion,
      'schemaVersion': SchemaVersions.current,
      'exportedAt': _clock().toUtc().toIso8601String(),
      'data': {
        'artists': [
          for (final row in snapshot.artists)
            {'id': row.id, 'name': row.name, 'created_at': row.createdAt},
        ],
        'albums': albumJson,
        'genres': [
          for (final row in snapshot.genres)
            {'id': row.id, 'name': row.name, 'created_at': row.createdAt},
        ],
        'album_genres': [
          for (final row in snapshot.albumGenres)
            {'album_id': row.albumId, 'genre_id': row.genreId},
        ],
        'album_discogs_releases': [
          for (final row in snapshot.releases)
            {'album_id': row.albumId, 'release_id': row.releaseId},
        ],
        'tracks': [
          for (final row in snapshot.tracks)
            {
              'id': row.id,
              'album_id': row.albumId,
              'title': row.title,
              'position': row.position,
              'side': row.side,
              'sequence': row.sequence,
              'duration_seconds': row.durationSeconds,
              'created_at': row.createdAt,
            },
        ],
        'plays': [
          for (final row in snapshot.plays)
            {
              'id': row.id,
              'album_id': row.albumId,
              'played_at': row.playedAt,
              'side_played': row.sidePlayed.name,
              'created_at': row.createdAt,
            },
        ],
        'nfc_tags': [
          for (final row in snapshot.nfcTags)
            {
              'id': row.id,
              'album_id': row.albumId,
              'nfc_tag_id': row.nfcTagId,
              'written_at': row.writtenAt,
            },
        ],
      },
    };
    archive.add(
      ArchiveFile.bytes(
        BackupFormat.manifestName,
        utf8.encode(jsonEncode(manifest)),
      ),
    );
    return ZipEncoder().encodeBytes(archive);
  }

  /// Validates [bytes] as a backup without touching the database.
  BackupContents readBackup(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const BackupFormatException(
        'That file isn’t a Groovefolio backup.',
      );
    }
    final files = archive.files.where((file) => file.isFile).toList();
    final declaredSize = files.fold<int>(0, (sum, file) => sum + file.size);
    if (files.length > BackupFormat.maxEntries ||
        declaredSize > BackupFormat.maxUncompressedBytes) {
      throw const BackupFormatException('That backup is too large to restore.');
    }

    final manifestFile = files
        .where((file) => file.name == BackupFormat.manifestName)
        .firstOrNull;
    if (manifestFile == null) {
      throw const BackupFormatException(
        'That file isn’t a Groovefolio backup.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(manifestFile.content));
    } on Object {
      throw _damaged;
    }
    if (decoded is! Map<String, Object?> ||
        decoded['format'] != BackupFormat.name) {
      throw const BackupFormatException(
        'That file isn’t a Groovefolio backup.',
      );
    }
    final version = decoded['formatVersion'];
    if (version is! int || version < 1) throw _damaged;
    if (version > BackupFormat.currentVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of Groovefolio. Update the '
        'app, then try again.',
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, Object?>) throw _damaged;

    try {
      final albums = <Album>[];
      final artworkEntries = <String, String>{};
      for (final row in _rows(data, 'albums')) {
        final album = Album(
          id: _string(row, 'id'),
          title: _string(row, 'title'),
          artistId: _string(row, 'artist_id'),
          releaseYear: _intOrNull(row, 'release_year'),
          label: _stringOrNull(row, 'label'),
          artworkPath: null,
          purchaseDate: _stringOrNull(row, 'purchase_date'),
          purchasePriceCents: _intOrNull(row, 'purchase_price_cents'),
          createdAt: _string(row, 'created_at'),
        );
        albums.add(album);
        final entry = _stringOrNull(row, 'artwork');
        if (entry != null) artworkEntries[album.id] = entry;
      }

      final artwork = <String, Uint8List>{};
      for (final MapEntry(key: albumId, value: entryName)
          in artworkEntries.entries) {
        // Only the exact name this app writes, for a file-name-safe album ID.
        if (!_safeId.hasMatch(albumId) ||
            entryName != '${BackupFormat.artworkFolder}/$albumId.jpg') {
          continue;
        }
        final file = files.where((f) => f.name == entryName).firstOrNull;
        final content = file?.readBytes();
        if (content != null && content.isNotEmpty) artwork[albumId] = content;
      }

      return BackupContents._(
        artists: [
          for (final row in _rows(data, 'artists'))
            Artist(
              id: _string(row, 'id'),
              name: _string(row, 'name'),
              createdAt: _string(row, 'created_at'),
            ),
        ],
        albums: albums,
        genres: [
          for (final row in _rows(data, 'genres'))
            Genre(
              id: _string(row, 'id'),
              name: _string(row, 'name'),
              createdAt: _string(row, 'created_at'),
            ),
        ],
        albumGenres: [
          for (final row in _rows(data, 'album_genres'))
            AlbumGenre(
              albumId: _string(row, 'album_id'),
              genreId: _string(row, 'genre_id'),
            ),
        ],
        discogsReleases: [
          for (final row in _rows(data, 'album_discogs_releases'))
            AlbumDiscogsRelease(
              albumId: _string(row, 'album_id'),
              releaseId: _int(row, 'release_id'),
            ),
        ],
        tracks: [
          for (final row in _rows(data, 'tracks'))
            Track(
              id: _string(row, 'id'),
              albumId: _string(row, 'album_id'),
              title: _string(row, 'title'),
              position: _stringOrNull(row, 'position'),
              side: _stringOrNull(row, 'side'),
              sequence: _int(row, 'sequence'),
              durationSeconds: _intOrNull(row, 'duration_seconds'),
              createdAt: _string(row, 'created_at'),
            ),
        ],
        plays: [
          for (final row in _rows(data, 'plays'))
            Play(
              id: _string(row, 'id'),
              albumId: _string(row, 'album_id'),
              playedAt: _string(row, 'played_at'),
              sidePlayed: SidePlayed.values.byName(_string(row, 'side_played')),
              createdAt: _string(row, 'created_at'),
            ),
        ],
        nfcTags: [
          for (final row in _rows(data, 'nfc_tags'))
            NfcTag(
              id: _string(row, 'id'),
              albumId: _string(row, 'album_id'),
              nfcTagId: _string(row, 'nfc_tag_id'),
              writtenAt: _string(row, 'written_at'),
            ),
        ],
        artwork: artwork,
        exportedAt: DateTime.tryParse(
          decoded['exportedAt'] as String? ?? '',
        )?.toLocal(),
      );
    } on BackupFormatException {
      rethrow;
    } on Object {
      // Wrong types, unknown enum names and similar all mean a damaged file.
      throw _damaged;
    }
  }

  /// Restores [contents] into an empty collection.
  ///
  /// All rows go in one transaction: a duplicate or broken reference rolls
  /// everything back. Leftover artists and genres with no records are removed
  /// first so they can't collide with the restored ones. Covers are written
  /// after the commit; a cover that fails to save is skipped, not fatal.
  Future<BackupSummary> restore(BackupContents contents) async {
    await _db.transaction(() async {
      if (!await isCollectionEmpty()) {
        throw const BackupRestoreNotEmptyException();
      }
      await _db.delete(_db.genres).go();
      await _db.delete(_db.artists).go();
      await _db.batch((batch) {
        batch
          ..insertAll(_db.artists, contents.artists)
          ..insertAll(_db.genres, contents.genres)
          ..insertAll(_db.albums, contents.albums)
          ..insertAll(_db.albumGenres, contents.albumGenres)
          ..insertAll(_db.albumDiscogsReleases, contents.discogsReleases)
          ..insertAll(_db.tracks, contents.tracks)
          ..insertAll(_db.plays, contents.plays)
          ..insertAll(_db.nfcTags, contents.nfcTags);
      });
    });

    var restoredArtwork = 0;
    for (final MapEntry(key: albumId, value: bytes)
        in contents.artwork.entries) {
      try {
        final path = await _artwork.saveArtworkBytes(bytes, albumId);
        await (_db.update(_db.albums)..where((a) => a.id.equals(albumId)))
            .write(AlbumsCompanion(artworkPath: Value(path)));
        restoredArtwork++;
      } on FileSystemException {
        // The record is restored either way; it just shows a placeholder.
      }
    }

    return BackupSummary(
      albums: contents.albums.length,
      plays: contents.plays.length,
      artworkFiles: restoredArtwork,
      exportedAt: contents.exportedAt,
    );
  }

  static const _damaged = BackupFormatException(
    'That backup is damaged or incomplete, so nothing was restored.',
  );

  static Map<String, Object?> _albumToJson(Album album, String? artwork) => {
    'id': album.id,
    'title': album.title,
    'artist_id': album.artistId,
    'release_year': album.releaseYear,
    'label': album.label,
    'purchase_date': album.purchaseDate,
    'purchase_price_cents': album.purchasePriceCents,
    'created_at': album.createdAt,
    'artwork': artwork,
  };

  static Iterable<Map<String, Object?>> _rows(
    Map<String, Object?> data,
    String table,
  ) {
    final rows = data[table];
    if (rows is! List<Object?>) throw _damaged;
    return rows.map(
      (row) => row is Map<String, Object?> ? row : throw _damaged,
    );
  }

  static String _string(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is String) return value;
    throw _damaged;
  }

  static String? _stringOrNull(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value == null || value is String) return value as String?;
    throw _damaged;
  }

  static int _int(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is int) return value;
    throw _damaged;
  }

  static int? _intOrNull(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value == null || value is int) return value as int?;
    throw _damaged;
  }
}

final collectionBackupServiceProvider = Provider<CollectionBackupService>((
  ref,
) {
  return CollectionBackupService(
    database: ref.watch(databaseProvider),
    artworkStorage: ref.watch(artworkStorageServiceProvider),
  );
});

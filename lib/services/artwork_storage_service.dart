import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vinyl_app/services/artwork_versions.dart';

typedef DocumentsDirectoryResolver = Future<Directory> Function();

/// Owns all filesystem access for persisted album artwork.
///
/// Screens/widgets should store only the returned path in Albums.artworkPath
/// and ask this service to resolve/delete files later.
class ArtworkStorageService {
  ArtworkStorageService({
    DocumentsDirectoryResolver? documentsDirectoryResolver,
  }) : _documentsDirectoryResolver =
           documentsDirectoryResolver ?? getApplicationDocumentsDirectory;

  final DocumentsDirectoryResolver _documentsDirectoryResolver;

  Future<String> saveArtwork(File source, String albumId) async {
    if (!await source.exists()) {
      throw ArgumentError.value(
        source.path,
        'source',
        'Artwork source file does not exist.',
      );
    }
    return saveArtworkBytes(await source.readAsBytes(), albumId);
  }

  /// Writes the album-owned artwork file and returns its durable path.
  /// Callers update the Album row separately because filesystem writes cannot
  /// join a SQLite transaction.
  ///
  /// Reuses `artwork/<albumId>.jpg`, overwriting an existing file. Bytes are
  /// stored as supplied, without JPEG conversion. Edit callers must retain old
  /// bytes if they need to compensate for a later database failure.
  Future<String> saveArtworkBytes(Uint8List bytes, String albumId) async {
    final normalizedId = albumId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }
    if (bytes.isEmpty) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'Artwork bytes cannot be empty.',
      );
    }

    final documentsDirectory = await _documentsDirectoryResolver();
    final artworkDirectory = Directory(
      p.join(documentsDirectory.path, 'artwork'),
    );
    await artworkDirectory.create(recursive: true);

    final destination = File(
      p.join(artworkDirectory.path, '$normalizedId.jpg'),
    );

    await destination.writeAsBytes(bytes, flush: true);
    ArtworkVersions.bump(destination.path);
    return destination.path;
  }

  Future<void> deleteArtwork(String? artworkPath) async {
    final normalizedPath = artworkPath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) return;

    final file = File(normalizedPath);
    if (await file.exists()) {
      await file.delete();
    }
    ArtworkVersions.bump(normalizedPath);
  }

  /// Writes [bytes] back to an existing artwork path, e.g. to undo a
  /// replacement after a failed save.
  Future<void> restoreArtworkBytes(String artworkPath, List<int> bytes) async {
    await File(artworkPath).writeAsBytes(bytes, flush: true);
    ArtworkVersions.bump(artworkPath);
  }

  File? artworkFile(String? artworkPath) {
    final normalizedPath = artworkPath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) return null;

    final file = File(normalizedPath);
    return file.existsSync() ? file : null;
  }
}

extension ArtworkSweep on ArtworkStorageService {
  /// Deletes stray `artwork/<id>.jpg` files: ones whose record no longer
  /// exists in [albumIds] and that no record points to in [referencedPaths].
  ///
  /// Files newer than [minAge] are kept, so a cover saved just before its
  /// record row is written (Add and Discogs import do this) is never removed.
  /// Other files in the folder are ignored. Returns how many were deleted.
  Future<int> deleteStrayArtwork({
    required Set<String> albumIds,
    required Set<String> referencedPaths,
    Duration minAge = const Duration(hours: 1),
  }) async {
    final directory = Directory(
      p.join((await _documentsDirectoryResolver()).path, 'artwork'),
    );
    if (!await directory.exists()) return 0;

    final cutoff = DateTime.now().subtract(minAge);
    final referenced = {for (final path in referencedPaths) p.normalize(path)};
    var removed = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (p.extension(name) != '.jpg') continue;
      if (albumIds.contains(p.basenameWithoutExtension(name)) ||
          referenced.contains(p.normalize(entity.path))) {
        continue;
      }
      try {
        if ((await entity.lastModified()).isAfter(cutoff)) continue;
        await deleteArtwork(entity.path);
        removed++;
      } on FileSystemException {
        // Best effort: a file that can't be read or removed stays for next time.
      }
    }
    return removed;
  }
}

final artworkStorageServiceProvider = Provider<ArtworkStorageService>((ref) {
  return ArtworkStorageService();
});

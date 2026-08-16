import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    final normalizedId = albumId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }
    if (!await source.exists()) {
      throw ArgumentError.value(
        source.path,
        'source',
        'Artwork source file does not exist.',
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

    // Write bytes instead of File.copy() so replacing the same stable path is
    // deterministic on every supported platform.
    await destination.writeAsBytes(await source.readAsBytes(), flush: true);
    return destination.path;
  }

  Future<void> deleteArtwork(String? artworkPath) async {
    final normalizedPath = artworkPath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) return;

    final file = File(normalizedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  File? artworkFile(String? artworkPath) {
    final normalizedPath = artworkPath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) return null;

    final file = File(normalizedPath);
    return file.existsSync() ? file : null;
  }
}

final artworkStorageServiceProvider = Provider<ArtworkStorageService>((ref) {
  return ArtworkStorageService();
});

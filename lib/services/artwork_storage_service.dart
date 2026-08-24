import 'dart:io';
import 'dart:typed_data';

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
    if (!await source.exists()) {
      throw ArgumentError.value(
        source.path,
        'source',
        'Artwork source file does not exist.',
      );
    }
    return saveArtworkBytes(await source.readAsBytes(), albumId);
  }

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

  /// Removes all persisted album artwork owned by Groovefolio.
  ///
  /// This is used by the debug-only local-data reset workflow. The artwork
  /// directory is recreated lazily the next time artwork is saved.
  Future<void> clearAllArtwork() async {
    final documentsDirectory = await _documentsDirectoryResolver();
    final artworkDirectory = Directory(
      p.join(documentsDirectory.path, 'artwork'),
    );
    if (await artworkDirectory.exists()) {
      await artworkDirectory.delete(recursive: true);
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

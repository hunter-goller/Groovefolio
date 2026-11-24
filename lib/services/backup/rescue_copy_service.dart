import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';

/// Layout of a rescue copy: the raw database files and covers, saved when the
/// collection can't be opened. Unlike a backup it is not restorable in the app;
/// it keeps the data safe outside the phone until a fixed update or support.
abstract final class RescueCopyFormat {
  static const name = 'groovefolio-rescue';
  static const currentVersion = 1;
  static const manifestName = 'groovefolio-rescue.json';
  static const databaseFolder = 'database';
  static const artworkFolder = 'artwork';

  /// The database file plus any SQLite sidecar files that may hold changes.
  static const databaseSuffixes = ['', '-wal', '-shm', '-journal'];
}

/// Copies Groovefolio's local files without opening the database, so it
/// works even when opening or migrating the database is what failed.
class RescueCopyService {
  RescueCopyService({
    DocumentsDirectoryResolver? documentsDirectoryResolver,
    DateTime Function()? clock,
  }) : _documents =
           documentsDirectoryResolver ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final DocumentsDirectoryResolver _documents;
  final DateTime Function() _clock;

  String suggestedFileName() {
    final now = _clock();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'groovefolio-rescue-${now.year}-${two(now.month)}-${two(now.day)}.zip';
  }

  /// Builds the rescue zip. Throws [FileSystemException] if there is no
  /// database file to copy.
  Future<Uint8List> createRescueCopy() async {
    final documents = await _documents();
    final archive = Archive();

    final databaseFiles = <String>[];
    for (final suffix in RescueCopyFormat.databaseSuffixes) {
      final name = '${AppDatabase.fileName}$suffix';
      final file = File(p.join(documents.path, name));
      if (await file.exists()) {
        databaseFiles.add(name);
        archive.add(
          ArchiveFile.bytes(
            '${RescueCopyFormat.databaseFolder}/$name',
            await file.readAsBytes(),
          ),
        );
      }
    }
    if (!databaseFiles.contains(AppDatabase.fileName)) {
      throw FileSystemException(
        'No Groovefolio database file to copy.',
        p.join(documents.path, AppDatabase.fileName),
      );
    }

    var artworkFiles = 0;
    final artwork = Directory(
      p.join(documents.path, RescueCopyFormat.artworkFolder),
    );
    if (await artwork.exists()) {
      await for (final entity in artwork.list(followLinks: false)) {
        if (entity is! File) continue;
        archive.add(
          ArchiveFile.bytes(
            '${RescueCopyFormat.artworkFolder}/${p.basename(entity.path)}',
            await entity.readAsBytes(),
          ),
        );
        artworkFiles++;
      }
    }

    final manifest = {
      'format': RescueCopyFormat.name,
      'formatVersion': RescueCopyFormat.currentVersion,
      'createdAt': _clock().toUtc().toIso8601String(),
      'databaseFiles': databaseFiles,
      'artworkFiles': artworkFiles,
    };
    archive.add(
      ArchiveFile.bytes(
        RescueCopyFormat.manifestName,
        utf8.encode(jsonEncode(manifest)),
      ),
    );
    return ZipEncoder().encodeBytes(archive);
  }
}

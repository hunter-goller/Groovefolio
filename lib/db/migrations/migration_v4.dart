import 'package:drift/drift.dart';

/// Adds exact Discogs release linkage for VinylApp-090.
Future<void> migrateToV4(Migrator migrator) async {
  await migrator.database.customStatement('''
    CREATE TABLE album_discogs_releases (
      album_id TEXT NOT NULL PRIMARY KEY REFERENCES albums(id) ON DELETE CASCADE,
      release_id INTEGER NOT NULL UNIQUE
    )
  ''');
}

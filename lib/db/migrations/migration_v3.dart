import 'package:drift/drift.dart';

/// Creates the VinylApp-098 v3 genre schema.
///
/// v3 adds canonical genre rows and a many-to-many album/genre join table.
Future<void> migrateToV3(Migrator migrator) async {
  await migrator.database.customStatement('''
    CREATE TABLE genres (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      created_at TEXT NOT NULL
    )
  ''');

  await migrator.database.customStatement('''
    CREATE TABLE album_genres (
      album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
      genre_id TEXT NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
      PRIMARY KEY (album_id, genre_id)
    )
  ''');
}

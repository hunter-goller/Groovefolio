import 'package:drift/drift.dart';

/// Creates exactly the historical v1 schema.
///
/// VinylApp-012 froze v1 as Artists + Albums + Plays. Keep these statements
/// stable even as newer tables are added to [AppDatabase]. Fresh installs at a
/// newer schema version may call this helper and then apply later creation
/// steps explicitly.
Future<void> migrateToV1(Migrator migrator) async {
  await migrator.database.customStatement('''
    CREATE TABLE artists (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');

  await migrator.database.customStatement('''
    CREATE TABLE albums (
      id TEXT NOT NULL PRIMARY KEY,
      title TEXT NOT NULL,
      artist_id TEXT NOT NULL REFERENCES artists(id),
      release_year INTEGER NULL,
      label TEXT NULL,
      artwork_path TEXT NULL,
      purchase_date TEXT NULL,
      purchase_price_cents INTEGER NULL,
      created_at TEXT NOT NULL
    )
  ''');

  await migrator.database.customStatement('''
    CREATE TABLE plays (
      id TEXT NOT NULL PRIMARY KEY,
      album_id TEXT NOT NULL REFERENCES albums(id),
      played_at TEXT NOT NULL,
      side_played TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
}

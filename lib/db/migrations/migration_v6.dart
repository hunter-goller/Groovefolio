import 'package:drift/drift.dart';

/// VinylApp-114 reliability migration.
///
/// Rebuilds Plays and NfcTags so album-owned rows cascade when an album is
/// deleted, then adds the composite play-history index used by album history
/// and recency queries. Earlier migrations remain frozen.
Future<void> migrateToV6(Migrator migrator) async {
  final db = migrator.database;

  await db.customStatement('ALTER TABLE plays RENAME TO plays_v5');
  await db.customStatement('''
    CREATE TABLE plays (
      id TEXT NOT NULL PRIMARY KEY,
      album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
      played_at TEXT NOT NULL,
      side_played TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
  await db.customStatement('''
    INSERT INTO plays (id, album_id, played_at, side_played, created_at)
    SELECT id, album_id, played_at, side_played, created_at
    FROM plays_v5
  ''');
  await db.customStatement('DROP TABLE plays_v5');

  await db.customStatement('ALTER TABLE nfc_tags RENAME TO nfc_tags_v5');
  await db.customStatement('''
    CREATE TABLE nfc_tags (
      id TEXT NOT NULL PRIMARY KEY,
      album_id TEXT NOT NULL UNIQUE REFERENCES albums(id) ON DELETE CASCADE,
      nfc_tag_id TEXT NOT NULL UNIQUE,
      written_at TEXT NOT NULL
    )
  ''');
  await db.customStatement('''
    INSERT INTO nfc_tags (id, album_id, nfc_tag_id, written_at)
    SELECT id, album_id, nfc_tag_id, written_at
    FROM nfc_tags_v5
  ''');
  await db.customStatement('DROP TABLE nfc_tags_v5');

  await db.customStatement('''
    CREATE INDEX plays_album_played_at_idx
    ON plays (album_id, played_at)
  ''');
}

import 'package:drift/drift.dart';

/// Creates exactly the historical v2 schema addition from VinylApp-040.
///
/// Keep this migration frozen. Future schema changes belong in a later
/// migration file rather than changing the v2 definition.
Future<void> migrateToV2(Migrator migrator) async {
  await migrator.database.customStatement('''
    CREATE TABLE nfc_tags (
      id TEXT NOT NULL PRIMARY KEY,
      album_id TEXT NOT NULL UNIQUE REFERENCES albums(id),
      nfc_tag_id TEXT NOT NULL UNIQUE,
      written_at TEXT NOT NULL
    )
  ''');
}

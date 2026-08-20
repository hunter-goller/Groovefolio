import 'package:drift/drift.dart';

/// Adds persistent album tracklists for VinylApp-105.
Future<void> migrateToV5(Migrator migrator) async {
  await migrator.database.customStatement('''
    CREATE TABLE tracks (
      id TEXT NOT NULL PRIMARY KEY,
      album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      position TEXT NULL,
      side TEXT NULL,
      sequence INTEGER NOT NULL,
      duration_seconds INTEGER NULL,
      created_at TEXT NOT NULL
    )
  ''');
}

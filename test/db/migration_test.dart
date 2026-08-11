import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/migrations/schema_versions.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test('fresh database creates every v2 table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = rows.map((row) => row.read<String>('name')).toSet();

    expect(
      tableNames,
      containsAll(<String>{'artists', 'albums', 'plays', 'nfc_tags'}),
    );
    expect(await db.select(db.artists).get(), isEmpty);
    expect(await db.select(db.albums).get(), isEmpty);
    expect(await db.select(db.plays).get(), isEmpty);
    expect(await db.select(db.nfcTags).get(), isEmpty);

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), SchemaVersions.v2);
  });

  test('v1 database upgrades to v2 without losing any v1 data', () async {
    final executor = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE artists (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          );
        ''');
        rawDb.execute('''
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
          );
        ''');
        rawDb.execute('''
          CREATE TABLE plays (
            id TEXT NOT NULL PRIMARY KEY,
            album_id TEXT NOT NULL REFERENCES albums(id),
            played_at TEXT NOT NULL,
            side_played TEXT NOT NULL,
            created_at TEXT NOT NULL
          );
        ''');
        rawDb.execute(
          'INSERT INTO artists VALUES '
          "('artist-1', 'Miles Davis', '2026-08-01T00:00:00.000Z');",
        );
        rawDb.execute(
          'INSERT INTO albums '
          '(id, title, artist_id, created_at) VALUES '
          "('album-1', 'Kind of Blue', 'artist-1', "
          "'2026-08-01T00:00:00.000Z');",
        );
        rawDb.execute(
          'INSERT INTO plays '
          '(id, album_id, played_at, side_played, created_at) VALUES '
          "('play-1', 'album-1', '2026-08-01T20:00:00.000Z', 'full', "
          "'2026-08-01T20:00:00.000Z');",
        );
        rawDb.execute('PRAGMA user_version = 1;');
      },
    );

    final db = AppDatabase(executor);
    addTearDown(db.close);

    // First query opens Drift and runs the 1 -> 2 migration.
    final artists = await db.select(db.artists).get();
    final albums = await db.select(db.albums).get();
    final plays = await db.select(db.plays).get();
    final tags = await db.select(db.nfcTags).get();
    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();

    expect(artists, hasLength(1));
    expect(artists.single.name, 'Miles Davis');
    expect(albums, hasLength(1));
    expect(albums.single.title, 'Kind of Blue');
    expect(plays, hasLength(1));
    expect(plays.single.albumId, 'album-1');
    expect(plays.single.sidePlayed, SidePlayed.full);
    expect(tags, isEmpty);
    expect(versionRow.read<int>('user_version'), SchemaVersions.v2);
  });
}

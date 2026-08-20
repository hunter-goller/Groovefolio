import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/migrations/schema_versions.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test('fresh database creates every v6 table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = rows.map((row) => row.read<String>('name')).toSet();

    expect(
      tableNames,
      containsAll(<String>{
        'artists',
        'albums',
        'plays',
        'nfc_tags',
        'genres',
        'album_genres',
        'album_discogs_releases',
        'tracks',
      }),
    );
    expect(await db.select(db.artists).get(), isEmpty);
    expect(await db.select(db.albums).get(), isEmpty);
    expect(await db.select(db.plays).get(), isEmpty);
    expect(await db.select(db.nfcTags).get(), isEmpty);
    expect(await db.select(db.genres).get(), isEmpty);
    expect(await db.select(db.albumGenres).get(), isEmpty);
    expect(await db.select(db.albumDiscogsReleases).get(), isEmpty);
    expect(await db.select(db.tracks).get(), isEmpty);

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), SchemaVersions.v6);
  });

  test(
    'v1 database upgrades through v2/v3/v4/v5/v6 without losing v1 data',
    () async {
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

      final artists = await db.select(db.artists).get();
      final albums = await db.select(db.albums).get();
      final plays = await db.select(db.plays).get();
      final tags = await db.select(db.nfcTags).get();
      final genres = await db.select(db.genres).get();
      final albumGenres = await db.select(db.albumGenres).get();
      final discogsLinks = await db.select(db.albumDiscogsReleases).get();
      final tracks = await db.select(db.tracks).get();
      final versionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();

      expect(artists, hasLength(1));
      expect(artists.single.name, 'Miles Davis');
      expect(albums, hasLength(1));
      expect(albums.single.title, 'Kind of Blue');
      expect(plays, hasLength(1));
      expect(plays.single.albumId, 'album-1');
      expect(plays.single.sidePlayed, SidePlayed.full);
      expect(tags, isEmpty);
      expect(genres, isEmpty);
      expect(albumGenres, isEmpty);
      expect(discogsLinks, isEmpty);
      expect(tracks, isEmpty);
      expect(versionRow.read<int>('user_version'), SchemaVersions.v6);
    },
  );

  test(
    'v2 database upgrades through v3/v4/v5/v6 without losing v2 data',
    () async {
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
          rawDb.execute('''
          CREATE TABLE nfc_tags (
            id TEXT NOT NULL PRIMARY KEY,
            album_id TEXT NOT NULL UNIQUE REFERENCES albums(id),
            nfc_tag_id TEXT NOT NULL UNIQUE,
            written_at TEXT NOT NULL
          );
        ''');
          rawDb.execute(
            'INSERT INTO artists VALUES '
            "('artist-1', 'Pink Floyd', '2026-08-01T00:00:00.000Z');",
          );
          rawDb.execute(
            'INSERT INTO albums '
            '(id, title, artist_id, created_at) VALUES '
            "('album-1', 'Wish You Were Here', 'artist-1', "
            "'2026-08-01T00:00:00.000Z');",
          );
          rawDb.execute(
            'INSERT INTO plays '
            '(id, album_id, played_at, side_played, created_at) VALUES '
            "('play-1', 'album-1', '2026-08-02T20:00:00.000Z', 'sideA', "
            "'2026-08-02T20:00:00.000Z');",
          );
          rawDb.execute(
            'INSERT INTO nfc_tags VALUES '
            "('nfc-1', 'album-1', 'tag-1', '2026-08-03T20:00:00.000Z');",
          );
          rawDb.execute('PRAGMA user_version = 2;');
        },
      );

      final db = AppDatabase(executor);
      addTearDown(db.close);

      final artists = await db.select(db.artists).get();
      final albums = await db.select(db.albums).get();
      final plays = await db.select(db.plays).get();
      final tags = await db.select(db.nfcTags).get();
      final genres = await db.select(db.genres).get();
      final albumGenres = await db.select(db.albumGenres).get();
      final discogsLinks = await db.select(db.albumDiscogsReleases).get();
      final tracks = await db.select(db.tracks).get();
      final versionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();

      expect(artists.single.name, 'Pink Floyd');
      expect(albums.single.title, 'Wish You Were Here');
      expect(plays.single.sidePlayed, SidePlayed.sideA);
      expect(tags.single.nfcTagId, 'tag-1');
      expect(genres, isEmpty);
      expect(albumGenres, isEmpty);
      expect(discogsLinks, isEmpty);
      expect(tracks, isEmpty);
      expect(versionRow.read<int>('user_version'), SchemaVersions.v6);
    },
  );

  test('v3 database upgrades through v4/v5/v6 and preserves genre data', () async {
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
        rawDb.execute('''
          CREATE TABLE nfc_tags (
            id TEXT NOT NULL PRIMARY KEY,
            album_id TEXT NOT NULL UNIQUE REFERENCES albums(id),
            nfc_tag_id TEXT NOT NULL UNIQUE,
            written_at TEXT NOT NULL
          );
        ''');
        rawDb.execute('''
          CREATE TABLE genres (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            created_at TEXT NOT NULL
          );
        ''');
        rawDb.execute('''
          CREATE TABLE album_genres (
            album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
            genre_id TEXT NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
            PRIMARY KEY (album_id, genre_id)
          );
        ''');
        rawDb.execute(
          "INSERT INTO artists VALUES ('artist-1', 'John Coltrane', '2026-08-01T00:00:00.000Z');",
        );
        rawDb.execute(
          "INSERT INTO albums (id, title, artist_id, created_at) VALUES ('album-1', 'Blue Train', 'artist-1', '2026-08-01T00:00:00.000Z');",
        );
        rawDb.execute(
          "INSERT INTO genres VALUES ('genre-1', 'Jazz', '2026-08-01T00:00:00.000Z');",
        );
        rawDb.execute(
          "INSERT INTO album_genres VALUES ('album-1', 'genre-1');",
        );
        rawDb.execute('PRAGMA user_version = 3;');
      },
    );

    final db = AppDatabase(executor);
    addTearDown(db.close);

    expect((await db.select(db.albums).get()).single.title, 'Blue Train');
    expect((await db.select(db.genres).get()).single.name, 'Jazz');
    expect(await db.select(db.albumGenres).get(), hasLength(1));
    expect(await db.select(db.albumDiscogsReleases).get(), isEmpty);
    expect(await db.select(db.tracks).get(), isEmpty);

    await db
        .into(db.albumDiscogsReleases)
        .insert(
          AlbumDiscogsReleasesCompanion.insert(
            albumId: 'album-1',
            releaseId: 12345,
          ),
        );
    final link = (await db.select(db.albumDiscogsReleases).get()).single;
    expect(link.albumId, 'album-1');
    expect(link.releaseId, 12345);

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), SchemaVersions.v6);
  });

  test(
    'v4 database upgrades through v5/v6 and preserves Discogs release links',
    () async {
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
          rawDb.execute('''
          CREATE TABLE nfc_tags (
            id TEXT NOT NULL PRIMARY KEY,
            album_id TEXT NOT NULL UNIQUE REFERENCES albums(id),
            nfc_tag_id TEXT NOT NULL UNIQUE,
            written_at TEXT NOT NULL
          );
        ''');
          rawDb.execute('''
          CREATE TABLE genres (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            created_at TEXT NOT NULL
          );
        ''');
          rawDb.execute('''
          CREATE TABLE album_genres (
            album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
            genre_id TEXT NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
            PRIMARY KEY (album_id, genre_id)
          );
        ''');
          rawDb.execute('''
          CREATE TABLE album_discogs_releases (
            album_id TEXT NOT NULL PRIMARY KEY REFERENCES albums(id) ON DELETE CASCADE,
            release_id INTEGER NOT NULL UNIQUE
          );
        ''');
          rawDb.execute(
            "INSERT INTO artists VALUES ('artist-1', 'John Coltrane', '2026-08-01T00:00:00.000Z');",
          );
          rawDb.execute(
            "INSERT INTO albums (id, title, artist_id, created_at) VALUES ('album-1', 'Blue Train', 'artist-1', '2026-08-01T00:00:00.000Z');",
          );
          rawDb.execute(
            "INSERT INTO album_discogs_releases VALUES ('album-1', 12345);",
          );
          rawDb.execute('PRAGMA user_version = 4;');
        },
      );

      final db = AppDatabase(executor);
      addTearDown(db.close);

      expect((await db.select(db.albums).get()).single.title, 'Blue Train');
      expect(
        (await db.select(db.albumDiscogsReleases).get()).single.releaseId,
        12345,
      );
      expect(await db.select(db.tracks).get(), isEmpty);

      final versionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(versionRow.read<int>('user_version'), SchemaVersions.v6);
    },
  );

  test('v5 database upgrades to v6, preserves data, and adds cascades/index', () async {
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
        rawDb.execute('''
          CREATE TABLE nfc_tags (
            id TEXT NOT NULL PRIMARY KEY,
            album_id TEXT NOT NULL UNIQUE REFERENCES albums(id),
            nfc_tag_id TEXT NOT NULL UNIQUE,
            written_at TEXT NOT NULL
          );
        ''');
        rawDb.execute('''
          CREATE TABLE genres (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            created_at TEXT NOT NULL
          );
        ''');
        rawDb.execute('''
          CREATE TABLE album_genres (
            album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
            genre_id TEXT NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
            PRIMARY KEY (album_id, genre_id)
          );
        ''');
        rawDb.execute('''
          CREATE TABLE album_discogs_releases (
            album_id TEXT NOT NULL PRIMARY KEY REFERENCES albums(id) ON DELETE CASCADE,
            release_id INTEGER NOT NULL UNIQUE
          );
        ''');
        rawDb.execute('''
          CREATE TABLE tracks (
            id TEXT NOT NULL PRIMARY KEY,
            album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            position TEXT NULL,
            side TEXT NULL,
            sequence INTEGER NOT NULL,
            duration_seconds INTEGER NULL,
            created_at TEXT NOT NULL
          );
        ''');
        rawDb.execute(
          "INSERT INTO artists VALUES ('artist-1', 'John Coltrane', '2026-08-01T00:00:00.000Z');",
        );
        rawDb.execute(
          "INSERT INTO albums (id, title, artist_id, created_at) VALUES ('album-1', 'Blue Train', 'artist-1', '2026-08-01T00:00:00.000Z');",
        );
        rawDb.execute(
          "INSERT INTO plays VALUES ('play-1', 'album-1', '2026-08-02T20:00:00.000Z', 'full', '2026-08-02T20:00:00.000Z');",
        );
        rawDb.execute(
          "INSERT INTO nfc_tags VALUES ('nfc-1', 'album-1', 'tag-1', '2026-08-03T20:00:00.000Z');",
        );
        rawDb.execute(
          "INSERT INTO genres VALUES ('genre-1', 'Jazz', '2026-08-01T00:00:00.000Z');",
        );
        rawDb.execute(
          "INSERT INTO album_genres VALUES ('album-1', 'genre-1');",
        );
        rawDb.execute(
          "INSERT INTO album_discogs_releases VALUES ('album-1', 12345);",
        );
        rawDb.execute(
          "INSERT INTO tracks VALUES ('track-1', 'album-1', 'Blue Train', 'A1', 'A', 0, 642, '2026-08-01T00:00:00.000Z');",
        );
        rawDb.execute('PRAGMA user_version = 5;');
      },
    );

    final db = AppDatabase(executor);
    addTearDown(db.close);

    expect((await db.select(db.plays).get()).single.id, 'play-1');
    expect((await db.select(db.nfcTags).get()).single.nfcTagId, 'tag-1');
    expect((await db.select(db.tracks).get()).single.position, 'A1');

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'plays_album_played_at_idx'",
        )
        .get();
    expect(indexes, hasLength(1));

    await (db.delete(db.albums)..where((row) => row.id.equals('album-1'))).go();
    expect(await db.select(db.plays).get(), isEmpty);
    expect(await db.select(db.nfcTags).get(), isEmpty);
    expect(await db.select(db.albumGenres).get(), isEmpty);
    expect(await db.select(db.albumDiscogsReleases).get(), isEmpty);
    expect(await db.select(db.tracks).get(), isEmpty);
    expect((await db.select(db.genres).get()).single.name, 'Jazz');

    final versionRow = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), SchemaVersions.v6);
  });
}

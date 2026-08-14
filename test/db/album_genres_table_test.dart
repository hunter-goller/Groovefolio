import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedArtist() async {
    await db
        .into(db.artists)
        .insert(
          ArtistsCompanion.insert(
            id: 'artist-1',
            name: 'Pink Floyd',
            createdAt: '2026-08-14T20:00:00.000Z',
          ),
        );
  }

  Future<void> seedAlbum(String id, String title) async {
    await db
        .into(db.albums)
        .insert(
          AlbumsCompanion.insert(
            id: id,
            title: title,
            artistId: 'artist-1',
            createdAt: '2026-08-14T20:00:00.000Z',
          ),
        );
  }

  Future<void> seedGenre(String id, String name) async {
    await db
        .into(db.genres)
        .insert(
          GenresCompanion.insert(
            id: id,
            name: name,
            createdAt: '2026-08-14T20:00:00.000Z',
          ),
        );
  }

  test('an album can have multiple genres', () async {
    await seedArtist();
    await seedAlbum('album-1', 'Wish You Were Here');
    await seedGenre('genre-1', 'Progressive Rock');
    await seedGenre('genre-2', 'Art Rock');

    await db.batch((batch) {
      batch.insert(
        db.albumGenres,
        AlbumGenresCompanion.insert(albumId: 'album-1', genreId: 'genre-1'),
      );
      batch.insert(
        db.albumGenres,
        AlbumGenresCompanion.insert(albumId: 'album-1', genreId: 'genre-2'),
      );
    });

    final mappings = await (db.select(
      db.albumGenres,
    )..where((row) => row.albumId.equals('album-1'))).get();

    expect(mappings, hasLength(2));
  });

  test('a genre can belong to multiple albums', () async {
    await seedArtist();
    await seedAlbum('album-1', 'Wish You Were Here');
    await seedAlbum('album-2', 'The Dark Side of the Moon');
    await seedGenre('genre-1', 'Progressive Rock');

    await db.batch((batch) {
      batch.insert(
        db.albumGenres,
        AlbumGenresCompanion.insert(albumId: 'album-1', genreId: 'genre-1'),
      );
      batch.insert(
        db.albumGenres,
        AlbumGenresCompanion.insert(albumId: 'album-2', genreId: 'genre-1'),
      );
    });

    final mappings = await (db.select(
      db.albumGenres,
    )..where((row) => row.genreId.equals('genre-1'))).get();

    expect(mappings, hasLength(2));
  });

  test('duplicate album and genre mapping is rejected', () async {
    await seedArtist();
    await seedAlbum('album-1', 'Wish You Were Here');
    await seedGenre('genre-1', 'Progressive Rock');

    final mapping = AlbumGenresCompanion.insert(
      albumId: 'album-1',
      genreId: 'genre-1',
    );
    await db.into(db.albumGenres).insert(mapping);

    await expectLater(
      db.into(db.albumGenres).insert(mapping),
      throwsA(anything),
    );
  });

  test('album genre mapping requires an existing album', () async {
    await seedGenre('genre-1', 'Progressive Rock');

    await expectLater(
      db
          .into(db.albumGenres)
          .insert(
            AlbumGenresCompanion.insert(
              albumId: 'missing-album',
              genreId: 'genre-1',
            ),
          ),
      throwsA(anything),
    );
  });

  test('album genre mapping requires an existing genre', () async {
    await seedArtist();
    await seedAlbum('album-1', 'Wish You Were Here');

    await expectLater(
      db
          .into(db.albumGenres)
          .insert(
            AlbumGenresCompanion.insert(
              albumId: 'album-1',
              genreId: 'missing-genre',
            ),
          ),
      throwsA(anything),
    );
  });

  test('deleting an album removes its genre mappings', () async {
    await seedArtist();
    await seedAlbum('album-1', 'Wish You Were Here');
    await seedGenre('genre-1', 'Progressive Rock');
    await db
        .into(db.albumGenres)
        .insert(
          AlbumGenresCompanion.insert(albumId: 'album-1', genreId: 'genre-1'),
        );

    await (db.delete(db.albums)..where((row) => row.id.equals('album-1'))).go();

    expect(await db.select(db.albumGenres).get(), isEmpty);
    expect(await db.select(db.genres).get(), hasLength(1));
  });

  test('deleting a genre removes its album mappings', () async {
    await seedArtist();
    await seedAlbum('album-1', 'Wish You Were Here');
    await seedGenre('genre-1', 'Progressive Rock');
    await db
        .into(db.albumGenres)
        .insert(
          AlbumGenresCompanion.insert(albumId: 'album-1', genreId: 'genre-1'),
        );

    await (db.delete(db.genres)..where((row) => row.id.equals('genre-1'))).go();

    expect(await db.select(db.albumGenres).get(), isEmpty);
    expect(await db.select(db.albums).get(), hasLength(1));
  });
}

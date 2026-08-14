import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/dev/seed_collection.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';
import 'package:vinyl_app/repositories/genre_repository.dart';

void main() {
  late AppDatabase db;
  late AlbumRepository albumRepository;
  late ArtistRepository artistRepository;
  late GenreRepository genreRepository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    albumRepository = AlbumRepository(db);
    artistRepository = ArtistRepository(db);
    genreRepository = GenreRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Album> findAlbum(String artistName, String title) async {
    final artist = await artistRepository.findOrCreate(artistName);
    final albums = await albumRepository.findAll();
    return albums.singleWhere(
      (album) =>
          album.artistId == artist.id &&
          album.title.toLowerCase() == title.toLowerCase(),
    );
  }

  test('seed assigns realistic genres to seeded albums', () async {
    await seedCollectionForDev(db);

    final blueTrain = await findAlbum('John Coltrane', 'Blue Train');
    final blueTrainGenres = await genreRepository.findByAlbum(blueTrain.id);

    final randomAccessMemories = await findAlbum(
      'Daft Punk',
      'Random Access Memories',
    );
    final ramGenres = await genreRepository.findByAlbum(
      randomAccessMemories.id,
    );

    expect(blueTrainGenres.map((genre) => genre.name).toSet(), {
      'Jazz',
      'Hard Bop',
    });
    expect(ramGenres.map((genre) => genre.name).toSet(), {
      'Electronic',
      'Disco',
      'Funk',
    });
  });

  test(
    'rerunning seed backfills genres without duplicating seed data',
    () async {
      final first = await seedCollectionForDev(db);
      final second = await seedCollectionForDev(db);

      expect(first.createdAlbums, 7);
      expect(second.createdAlbums, 0);
      expect(second.reusedAlbums, 7);
      expect(second.createdPlays, 0);

      final genres = await genreRepository.findAll();
      expect(
        genres.map((genre) => genre.name.toLowerCase()).toSet().length,
        genres.length,
      );
    },
  );

  test(
    'rerunning seed preserves extra genres added to a seeded album',
    () async {
      await seedCollectionForDev(db);

      final album = await findAlbum('Miles Davis', 'Kind of Blue');
      final extraGenre = await genreRepository.findOrCreate('Cool Jazz');
      final currentGenres = await genreRepository.findByAlbum(album.id);

      await genreRepository.setAlbumGenres(album.id, [
        ...currentGenres.map((genre) => genre.id),
        extraGenre.id,
      ]);

      await seedCollectionForDev(db);

      final genresAfterReseed = await genreRepository.findByAlbum(album.id);
      expect(
        genresAfterReseed.map((genre) => genre.name).toSet(),
        containsAll({'Jazz', 'Modal Jazz', 'Cool Jazz'}),
      );
    },
  );

  test('seed backfills genres onto an already-existing seeded album', () async {
    final artist = await artistRepository.findOrCreate('Pink Floyd');
    final album = await albumRepository.create(
      title: 'Wish You Were Here',
      artistId: artist.id,
      releaseYear: 1975,
      label: 'Harvest',
    );

    expect(await genreRepository.findByAlbum(album.id), isEmpty);

    await seedCollectionForDev(db);

    final genres = await genreRepository.findByAlbum(album.id);
    expect(genres.map((genre) => genre.name).toSet(), {
      'Progressive Rock',
      'Art Rock',
    });
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/genre_repository.dart';

void main() {
  late AppDatabase db;
  late GenreRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = GenreRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedAlbum(String albumId) async {
    final artistId = 'artist-$albumId';
    await db
        .into(db.artists)
        .insert(
          ArtistsCompanion.insert(
            id: artistId,
            name: 'Artist $albumId',
            createdAt: '2026-08-14T12:00:00.000Z',
          ),
        );
    await db
        .into(db.albums)
        .insert(
          AlbumsCompanion.insert(
            id: albumId,
            title: 'Album $albumId',
            artistId: artistId,
            createdAt: '2026-08-14T12:00:00.000Z',
          ),
        );
  }

  test('findOrCreate creates a normalized genre', () async {
    final created = await repository.findOrCreate('  Alternative Rock  ');

    expect(created.id, startsWith('genre-'));
    expect(created.name, 'Alternative Rock');
    expect(DateTime.tryParse(created.createdAt), isNotNull);
    expect(await repository.findById(created.id), created);
  });

  test('findOrCreate reuses a case-insensitive match', () async {
    final first = await repository.findOrCreate('Rock');
    final second = await repository.findOrCreate('rock');

    expect(second, first);
    expect(await repository.findAll(), hasLength(1));
  });

  test('findByName trims input and matches case-insensitively', () async {
    final created = await repository.findOrCreate('Jazz');

    expect(await repository.findByName('  jAzZ '), created);
    expect(await repository.findByName('missing'), isNull);
    expect(await repository.findByName('   '), isNull);
  });

  test('findOrCreate rejects a blank genre name', () async {
    expect(() => repository.findOrCreate('   '), throwsA(isA<ArgumentError>()));
  });

  test('findAll returns deterministic case-insensitive name order', () async {
    await repository.findOrCreate('Rock');
    await repository.findOrCreate('ambient');
    await repository.findOrCreate('Jazz');

    final genres = await repository.findAll();

    expect(genres.map((genre) => genre.name), ['ambient', 'Jazz', 'Rock']);
  });

  test(
    'setAlbumGenres assigns multiple genres and findByAlbum orders them',
    () async {
      await seedAlbum('album-1');
      final rock = await repository.findOrCreate('Rock');
      final ambient = await repository.findOrCreate('Ambient');

      await repository.setAlbumGenres(' album-1 ', [rock.id, ambient.id]);

      final assigned = await repository.findByAlbum('album-1');
      expect(assigned.map((genre) => genre.id), [ambient.id, rock.id]);
    },
  );

  test('setAlbumGenres collapses duplicate genre IDs', () async {
    await seedAlbum('album-1');
    final rock = await repository.findOrCreate('Rock');

    await repository.setAlbumGenres('album-1', [
      rock.id,
      rock.id,
      ' ${rock.id} ',
    ]);

    final mappings = await db.select(db.albumGenres).get();
    expect(mappings, hasLength(1));
    expect(mappings.single.albumId, 'album-1');
    expect(mappings.single.genreId, rock.id);
  });

  test('setAlbumGenres replaces previous mappings', () async {
    await seedAlbum('album-1');
    final rock = await repository.findOrCreate('Rock');
    final jazz = await repository.findOrCreate('Jazz');
    final soul = await repository.findOrCreate('Soul');

    await repository.setAlbumGenres('album-1', [rock.id, jazz.id]);
    await repository.setAlbumGenres('album-1', [soul.id]);

    final assigned = await repository.findByAlbum('album-1');
    expect(assigned, [soul]);
  });

  test('setAlbumGenres with an empty list clears mappings only', () async {
    await seedAlbum('album-1');
    final rock = await repository.findOrCreate('Rock');
    await repository.setAlbumGenres('album-1', [rock.id]);

    await repository.setAlbumGenres('album-1', const []);

    expect(await repository.findByAlbum('album-1'), isEmpty);
    expect(await repository.findById(rock.id), rock);
  });

  test(
    'setAlbumGenres is atomic when a requested genre does not exist',
    () async {
      await seedAlbum('album-1');
      final rock = await repository.findOrCreate('Rock');
      await repository.setAlbumGenres('album-1', [rock.id]);

      expect(
        () => repository.setAlbumGenres('album-1', ['missing-genre']),
        throwsA(isA<StateError>()),
      );

      expect(await repository.findByAlbum('album-1'), [rock]);
    },
  );

  test('setAlbumGenres surfaces an unknown album cleanly', () async {
    final rock = await repository.findOrCreate('Rock');

    expect(
      () => repository.setAlbumGenres('missing-album', [rock.id]),
      throwsA(isA<StateError>()),
    );
  });

  test('removeFromAlbum removes only the mapping', () async {
    await seedAlbum('album-1');
    final rock = await repository.findOrCreate('Rock');
    await repository.setAlbumGenres('album-1', [rock.id]);

    final deleted = await repository.removeFromAlbum('album-1', rock.id);

    expect(deleted, 1);
    expect(await repository.findByAlbum('album-1'), isEmpty);
    expect(await repository.findById(rock.id), rock);
  });

  test(
    'delete removes the Genre and schema cascade removes mappings',
    () async {
      await seedAlbum('album-1');
      final rock = await repository.findOrCreate('Rock');
      await repository.setAlbumGenres('album-1', [rock.id]);

      final deleted = await repository.delete(rock.id);

      expect(deleted, 1);
      expect(await repository.findById(rock.id), isNull);
      expect(await db.select(db.albumGenres).get(), isEmpty);
    },
  );

  test('blank IDs are rejected or treated as empty lookups', () async {
    expect(await repository.findById('   '), isNull);
    expect(await repository.findByAlbum('   '), isEmpty);
    expect(
      () => repository.setAlbumGenres('   ', const []),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => repository.setAlbumGenres('album-1', ['   ']),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => repository.removeFromAlbum('   ', 'genre-1'),
      throwsA(isA<ArgumentError>()),
    );
    expect(() => repository.delete('   '), throwsA(isA<ArgumentError>()));
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  late AppDatabase db;
  late PlayRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = PlayRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> createArtist({required String id, required String name}) async {
    await db
        .into(db.artists)
        .insert(
          ArtistsCompanion.insert(
            id: id,
            name: name,
            createdAt: '2026-08-10T00:00:00.000Z',
          ),
        );
  }

  Future<void> createAlbum({
    required String id,
    required String title,
    String artistId = 'artist-1',
  }) async {
    await db
        .into(db.albums)
        .insert(
          AlbumsCompanion.insert(
            id: id,
            title: title,
            artistId: artistId,
            createdAt: '2026-08-10T00:00:00.000Z',
          ),
        );
  }

  PlaysCompanion play({
    required String id,
    required String albumId,
    required String playedAt,
    SidePlayed sidePlayed = SidePlayed.full,
  }) {
    return PlaysCompanion.insert(
      id: id,
      albumId: albumId,
      playedAt: playedAt,
      sidePlayed: sidePlayed,
      createdAt: playedAt,
    );
  }

  Future<void> seedAlbums() async {
    await createArtist(id: 'artist-1', name: 'Miles Davis');
    await createAlbum(id: 'album-1', title: 'Kind of Blue');
    await createAlbum(id: 'album-2', title: 'In a Silent Way');
    await createAlbum(id: 'album-3', title: 'Bitches Brew');
  }

  test('create persists a play with the expected fields', () async {
    await seedAlbums();

    final rowId = await repository.create(
      play(
        id: 'play-1',
        albumId: 'album-1',
        playedAt: '2026-08-08T18:30:00.000Z',
        sidePlayed: SidePlayed.sideA,
      ),
    );

    final stored = (await repository.findByAlbum('album-1')).single;

    expect(rowId, greaterThan(0));
    expect(stored.id, 'play-1');
    expect(stored.albumId, 'album-1');
    expect(stored.playedAt, '2026-08-08T18:30:00.000Z');
    expect(stored.sidePlayed, SidePlayed.sideA);
  });

  test('findByAlbum returns only that album and sorts newest first', () async {
    await seedAlbums();
    await repository.create(
      play(
        id: 'play-old',
        albumId: 'album-1',
        playedAt: '2026-08-01T12:00:00.000Z',
      ),
    );
    await repository.create(
      play(
        id: 'other-album',
        albumId: 'album-2',
        playedAt: '2026-08-09T12:00:00.000Z',
      ),
    );
    await repository.create(
      play(
        id: 'play-new',
        albumId: 'album-1',
        playedAt: '2026-08-10T12:00:00.000Z',
      ),
    );

    final results = await repository.findByAlbum('album-1');

    expect(results.map((play) => play.id).toList(), ['play-new', 'play-old']);
  });

  test('findAll returns plays across all albums', () async {
    await seedAlbums();
    await repository.create(
      play(
        id: 'play-1',
        albumId: 'album-1',
        playedAt: '2026-08-01T12:00:00.000Z',
      ),
    );
    await repository.create(
      play(
        id: 'play-2',
        albumId: 'album-2',
        playedAt: '2026-08-02T12:00:00.000Z',
      ),
    );

    final results = await repository.findAll();

    expect(results, hasLength(2));
    expect(results.map((play) => play.id).toSet(), {'play-1', 'play-2'});
  });

  test('deleteById removes exactly the targeted play', () async {
    await seedAlbums();
    await repository.create(
      play(
        id: 'play-1',
        albumId: 'album-1',
        playedAt: '2026-08-01T12:00:00.000Z',
      ),
    );
    await repository.create(
      play(
        id: 'play-2',
        albumId: 'album-1',
        playedAt: '2026-08-02T12:00:00.000Z',
      ),
    );

    final deletedRows = await repository.deleteById('play-1');
    final remaining = await repository.findAll();

    expect(deletedRows, 1);
    expect(remaining.map((play) => play.id).toList(), ['play-2']);
  });

  test('getPlayCountByAlbum returns the correct count and zero', () async {
    await seedAlbums();
    await repository.create(
      play(
        id: 'play-1',
        albumId: 'album-1',
        playedAt: '2026-08-01T12:00:00.000Z',
      ),
    );
    await repository.create(
      play(
        id: 'play-2',
        albumId: 'album-1',
        playedAt: '2026-08-02T12:00:00.000Z',
      ),
    );

    expect(await repository.getPlayCountByAlbum('album-1'), 2);
    expect(await repository.getPlayCountByAlbum('album-2'), 0);
  });

  test(
    'getRecentlyPlayed returns distinct albums in most-recent-play order',
    () async {
      await seedAlbums();

      // Interleave albums and give album-1 multiple plays. It should appear
      // once, based on its newest play.
      await repository.create(
        play(
          id: 'a1-old',
          albumId: 'album-1',
          playedAt: '2026-08-01T12:00:00.000Z',
        ),
      );
      await repository.create(
        play(
          id: 'a2',
          albumId: 'album-2',
          playedAt: '2026-08-08T12:00:00.000Z',
        ),
      );
      await repository.create(
        play(
          id: 'a3',
          albumId: 'album-3',
          playedAt: '2026-08-06T12:00:00.000Z',
        ),
      );
      await repository.create(
        play(
          id: 'a1-new',
          albumId: 'album-1',
          playedAt: '2026-08-10T12:00:00.000Z',
        ),
      );

      final results = await repository.getRecentlyPlayed(2);

      expect(results.map((album) => album.id).toList(), ['album-1', 'album-2']);
    },
  );

  test(
    'getRecentlyPlayed returns an empty list for a non-positive limit',
    () async {
      await seedAlbums();

      expect(await repository.getRecentlyPlayed(0), isEmpty);
      expect(await repository.getRecentlyPlayed(-1), isEmpty);
    },
  );

  test('sidePlayed enum round-trips for all supported values', () async {
    await seedAlbums();

    for (final side in SidePlayed.values) {
      await repository.create(
        play(
          id: 'play-${side.name}',
          albumId: 'album-1',
          playedAt: switch (side) {
            SidePlayed.full => '2026-08-01T12:00:00.000Z',
            SidePlayed.sideA => '2026-08-02T12:00:00.000Z',
            SidePlayed.sideB => '2026-08-03T12:00:00.000Z',
          },
          sidePlayed: side,
        ),
      );
    }

    final stored = await repository.findByAlbum('album-1');

    expect(
      stored.map((play) => play.sidePlayed).toSet(),
      SidePlayed.values.toSet(),
    );
  });
}

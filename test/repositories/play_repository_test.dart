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

  Future<Play> createPlay({
    required String albumId,
    required String playedAt,
    SidePlayed sidePlayed = SidePlayed.full,
  }) {
    return repository.create(
      albumId: albumId,
      playedAt: DateTime.parse(playedAt),
      sidePlayed: sidePlayed,
    );
  }

  Future<void> seedAlbums() async {
    await createArtist(id: 'artist-1', name: 'Miles Davis');
    await createAlbum(id: 'album-1', title: 'Kind of Blue');
    await createAlbum(id: 'album-2', title: 'In a Silent Way');
    await createAlbum(id: 'album-3', title: 'Bitches Brew');
  }

  test(
    'create persists expected fields and owns persistence metadata',
    () async {
      await seedAlbums();

      final created = await repository.create(
        albumId: 'album-1',
        playedAt: DateTime.parse('2026-08-08T18:30:00.000Z'),
        sidePlayed: SidePlayed.sideA,
      );
      final stored = (await repository.findByAlbum('album-1')).single;

      expect(created.id, startsWith('play-'));
      expect(created.albumId, 'album-1');
      expect(created.playedAt, '2026-08-08T18:30:00.000Z');
      expect(created.sidePlayed, SidePlayed.sideA);
      expect(created.createdAt, isNotEmpty);
      expect(stored, created);
    },
  );

  test('create rejects an album id that violates the foreign key', () async {
    await expectLater(
      repository.create(
        albumId: 'missing-album',
        playedAt: DateTime.parse('2026-08-08T18:30:00.000Z'),
        sidePlayed: SidePlayed.full,
      ),
      throwsA(anything),
    );
  });

  test('findByAlbum returns only that album and sorts newest first', () async {
    await seedAlbums();
    final oldPlay = await createPlay(
      albumId: 'album-1',
      playedAt: '2026-08-01T12:00:00.000Z',
    );
    await createPlay(albumId: 'album-2', playedAt: '2026-08-09T12:00:00.000Z');
    final newPlay = await createPlay(
      albumId: 'album-1',
      playedAt: '2026-08-10T12:00:00.000Z',
    );

    final results = await repository.findByAlbum('album-1');

    expect(results.map((play) => play.id).toList(), [newPlay.id, oldPlay.id]);
  });

  test('findAll returns plays across all albums', () async {
    await seedAlbums();
    final first = await createPlay(
      albumId: 'album-1',
      playedAt: '2026-08-01T12:00:00.000Z',
    );
    final second = await createPlay(
      albumId: 'album-2',
      playedAt: '2026-08-02T12:00:00.000Z',
    );

    final results = await repository.findAll();

    expect(results, hasLength(2));
    expect(results.map((play) => play.id).toSet(), {first.id, second.id});
  });

  test('deleteById removes exactly the targeted play', () async {
    await seedAlbums();
    final first = await createPlay(
      albumId: 'album-1',
      playedAt: '2026-08-01T12:00:00.000Z',
    );
    final second = await createPlay(
      albumId: 'album-1',
      playedAt: '2026-08-02T12:00:00.000Z',
    );

    final deletedRows = await repository.deleteById(first.id);
    final remaining = await repository.findAll();

    expect(deletedRows, 1);
    expect(remaining.map((play) => play.id).toList(), [second.id]);
  });

  test('getPlayCountByAlbum returns the correct count and zero', () async {
    await seedAlbums();
    await createPlay(albumId: 'album-1', playedAt: '2026-08-01T12:00:00.000Z');
    await createPlay(albumId: 'album-1', playedAt: '2026-08-02T12:00:00.000Z');

    expect(await repository.getPlayCountByAlbum('album-1'), 2);
    expect(await repository.getPlayCountByAlbum('album-2'), 0);
  });

  test('getRecentlyPlayed returns distinct albums in recent order', () async {
    await seedAlbums();
    await createPlay(albumId: 'album-1', playedAt: '2026-08-01T12:00:00.000Z');
    await createPlay(albumId: 'album-2', playedAt: '2026-08-08T12:00:00.000Z');
    await createPlay(albumId: 'album-3', playedAt: '2026-08-06T12:00:00.000Z');
    await createPlay(albumId: 'album-1', playedAt: '2026-08-10T12:00:00.000Z');

    final results = await repository.getRecentlyPlayed(2);

    expect(results.map((album) => album.id).toList(), ['album-1', 'album-2']);
  });

  test('getRecentlyPlayed returns empty for non-positive limit', () async {
    await seedAlbums();

    expect(await repository.getRecentlyPlayed(0), isEmpty);
    expect(await repository.getRecentlyPlayed(-1), isEmpty);
  });

  test('sidePlayed enum round-trips for all supported values', () async {
    await seedAlbums();

    for (final side in SidePlayed.values) {
      await createPlay(
        albumId: 'album-1',
        playedAt: switch (side) {
          SidePlayed.full => '2026-08-01T12:00:00.000Z',
          SidePlayed.sideA => '2026-08-02T12:00:00.000Z',
          SidePlayed.sideB => '2026-08-03T12:00:00.000Z',
        },
        sidePlayed: side,
      );
    }

    final stored = await repository.findByAlbum('album-1');

    expect(
      stored.map((play) => play.sidePlayed).toSet(),
      SidePlayed.values.toSet(),
    );
  });
}

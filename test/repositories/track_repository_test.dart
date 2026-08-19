import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/track_repository.dart';

void main() {
  late AppDatabase db;
  late TrackRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = TrackRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seedAlbum() async {
    await db.into(db.artists).insert(
          ArtistsCompanion.insert(
            id: 'artist-1',
            name: 'John Coltrane',
            createdAt: '2026-08-19T00:00:00.000Z',
          ),
        );
    await db.into(db.albums).insert(
          AlbumsCompanion.insert(
            id: 'album-1',
            title: 'Blue Train',
            artistId: 'artist-1',
            createdAt: '2026-08-19T00:00:00.000Z',
          ),
        );
  }

  test('replaceAlbumTracks stores deterministic release order', () async {
    await seedAlbum();

    final created = await repository.replaceAlbumTracks('album-1', const [
      TrackDraft(
        title: 'Moment’s Notice',
        position: 'A2',
        side: 'A',
        sequence: 1,
        durationSeconds: 558,
      ),
      TrackDraft(
        title: 'Blue Train',
        position: 'A1',
        side: 'A',
        sequence: 0,
        durationSeconds: 642,
      ),
    ]);

    expect(created.map((track) => track.position), ['A1', 'A2']);
    final stored = await repository.findByAlbum('album-1');
    expect(stored.map((track) => track.title), [
      'Blue Train',
      'Moment’s Notice',
    ]);
  });

  test('replaceAlbumTracks atomically removes stale tracks', () async {
    await seedAlbum();
    await repository.replaceAlbumTracks('album-1', const [
      TrackDraft(title: 'Old A', sequence: 0),
      TrackDraft(title: 'Old B', sequence: 1),
    ]);

    await repository.replaceAlbumTracks('album-1', const [
      TrackDraft(title: 'New A', position: 'B1', side: 'b', sequence: 0),
    ]);

    final stored = await repository.findByAlbum('album-1');
    expect(stored, hasLength(1));
    expect(stored.single.title, 'New A');
    expect(stored.single.side, 'B');
  });

  test('empty replacement clears tracklist without deleting album', () async {
    await seedAlbum();
    await repository.replaceAlbumTracks('album-1', const [
      TrackDraft(title: 'Track', sequence: 0),
    ]);

    await repository.replaceAlbumTracks('album-1', const []);

    expect(await repository.findByAlbum('album-1'), isEmpty);
    expect((await db.select(db.albums).get()).single.id, 'album-1');
  });

  test('replace validates album, title, sequence, and duration', () async {
    await seedAlbum();

    expect(
      () => repository.replaceAlbumTracks('missing', const []),
      throwsA(isA<StateError>()),
    );
    expect(
      () => repository.replaceAlbumTracks(
        'album-1',
        const [TrackDraft(title: ' ', sequence: 0)],
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => repository.replaceAlbumTracks(
        'album-1',
        const [TrackDraft(title: 'Track', sequence: -1)],
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => repository.replaceAlbumTracks(
        'album-1',
        const [TrackDraft(title: 'Track', sequence: 0, durationSeconds: -1)],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

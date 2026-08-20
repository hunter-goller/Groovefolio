import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> seedAlbum() async {
    await db
        .into(db.artists)
        .insert(
          ArtistsCompanion.insert(
            id: 'artist-1',
            name: 'John Coltrane',
            createdAt: '2026-08-19T00:00:00.000Z',
          ),
        );
    await db
        .into(db.albums)
        .insert(
          AlbumsCompanion.insert(
            id: 'album-1',
            title: 'Blue Train',
            artistId: 'artist-1',
            createdAt: '2026-08-19T00:00:00.000Z',
          ),
        );
  }

  test('stores track metadata and cascades when album is deleted', () async {
    await seedAlbum();
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            id: 'track-1',
            albumId: 'album-1',
            title: 'Blue Train',
            position: const Value('A1'),
            side: const Value('A'),
            sequence: 0,
            durationSeconds: const Value(642),
            createdAt: '2026-08-19T00:00:00.000Z',
          ),
        );

    final track = (await db.select(db.tracks).get()).single;
    expect(track.title, 'Blue Train');
    expect(track.position, 'A1');
    expect(track.side, 'A');
    expect(track.sequence, 0);
    expect(track.durationSeconds, 642);

    await (db.delete(db.albums)..where((row) => row.id.equals('album-1'))).go();
    expect(await db.select(db.tracks).get(), isEmpty);
  });
}

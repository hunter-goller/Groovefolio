import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/types/side_played.dart';

Future<void> _seedArtistAndAlbum(
  AppDatabase db, {
  required String artistId,
  required String albumId,
}) async {
  await db
      .into(db.artists)
      .insert(
        ArtistsCompanion.insert(
          id: artistId,
          name: 'John Coltrane',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
  await db
      .into(db.albums)
      .insert(
        AlbumsCompanion.insert(
          id: albumId,
          title: 'Blue Train',
          artistId: artistId,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
}

void main() {
  test('can insert and select a play, including the enum column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await _seedArtistAndAlbum(db, artistId: 'artist-1', albumId: 'album-1');

    await db
        .into(db.plays)
        .insert(
          PlaysCompanion.insert(
            id: 'play-1',
            albumId: 'album-1',
            playedAt: DateTime.now().toIso8601String(),
            sidePlayed: SidePlayed.full,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );

    final result = await db.select(db.plays).getSingle();

    expect(result.id, 'play-1');
    expect(result.albumId, 'album-1');
    // Confirms the TypeConverter round-trips correctly — a real enum
    // value comes back, not the raw 'full' string.
    expect(result.sidePlayed, SidePlayed.full);

    await db.close();
  });

  test('can query plays by albumId', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await _seedArtistAndAlbum(db, artistId: 'artist-1', albumId: 'album-1');
    await db
        .into(db.albums)
        .insert(
          AlbumsCompanion.insert(
            id: 'album-2',
            title: 'Kind of Blue',
            artistId: 'artist-1',
            createdAt: DateTime.now().toIso8601String(),
          ),
        );

    // 2 plays for album-1, 1 play for album-2.
    for (final entry in [
      ('play-1', 'album-1', SidePlayed.full),
      ('play-2', 'album-1', SidePlayed.sideA),
      ('play-3', 'album-2', SidePlayed.sideB),
    ]) {
      await db
          .into(db.plays)
          .insert(
            PlaysCompanion.insert(
              id: entry.$1,
              albumId: entry.$2,
              playedAt: DateTime.now().toIso8601String(),
              sidePlayed: entry.$3,
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
    }

    final query = db.select(db.plays)
      ..where((tbl) => tbl.albumId.equals('album-1'));
    final results = await query.get();

    expect(results.length, 2);
    expect(results.every((play) => play.albumId == 'album-1'), isTrue);

    await db.close();
  });
}

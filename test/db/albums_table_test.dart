import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';

void main() {
  test(
    'can insert and select an album with a valid artist reference',
    () async {
      final db = AppDatabase(NativeDatabase.memory());

      // The artist must exist first — albums.artistId has a real FK now,
      // not a placeholder, so this insert would fail without it.
      await db
          .into(db.artists)
          .insert(
            ArtistsCompanion.insert(
              id: 'artist-1',
              name: 'John Coltrane',
              createdAt: DateTime.now().toIso8601String(),
            ),
          );

      await db
          .into(db.albums)
          .insert(
            AlbumCompanion.insert(
              id: 'album-1',
              title: 'Blue Train',
              artistId: 'artist-1',
              createdAt: DateTime.now().toIso8601String(),
            ),
          );

      final result = await db.select(db.albums).getSingle();

      expect(result.id, 'album-1');
      expect(result.title, 'Blue Train');
      expect(result.artistId, 'artist-1');

      await db.close();
    },
  );

  test('inserting an album with a non-existent artistId fails', () async {
    // Bonus test, beyond either card's stated acceptance criteria — but
    // worth having, since it's the only thing that actually proves the FK
    // (plus the PRAGMA foreign_keys = ON in AppDatabase) is doing its job
    // rather than just existing decoratively in the schema.
    final db = AppDatabase(NativeDatabase.memory());

    expect(
      () => db
          .into(db.albums)
          .insert(
            AlbumCompanion.insert(
              id: 'album-1',
              title: 'Blue Train',
              artistId: 'does-not-exist',
              createdAt: DateTime.now().toIso8601String(),
            ),
          ),
      throwsException,
    );

    await db.close();
  });
}

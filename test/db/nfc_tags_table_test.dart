import 'package:drift/drift.dart';
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
            name: 'Miles Davis',
            createdAt: '2026-08-11T00:00:00.000Z',
          ),
        );
  }

  Future<void> seedAlbum({required String id, required String title}) async {
    await db
        .into(db.albums)
        .insert(
          AlbumsCompanion.insert(
            id: id,
            title: title,
            artistId: 'artist-1',
            createdAt: '2026-08-11T00:00:00.000Z',
          ),
        );
  }

  test('nfc tag resolves its album in a single joined query', () async {
    await seedArtist();
    await seedAlbum(id: 'album-1', title: 'Kind of Blue');
    await db
        .into(db.nfcTags)
        .insert(
          NfcTagsCompanion.insert(
            id: 'nfc-1',
            albumId: 'album-1',
            nfcTagId: '04:A7:39:2B:91:61:80',
            writtenAt: '2026-08-11T10:00:00.000Z',
          ),
        );

    final query = db.select(db.nfcTags).join([
      innerJoin(db.albums, db.albums.id.equalsExp(db.nfcTags.albumId)),
    ])..where(db.nfcTags.nfcTagId.equals('04:A7:39:2B:91:61:80'));

    final row = await query.getSingle();
    final album = row.readTable(db.albums);

    expect(album.id, 'album-1');
    expect(album.title, 'Kind of Blue');
  });

  test('nfcTagId is unique across albums', () async {
    await seedArtist();
    await seedAlbum(id: 'album-1', title: 'Kind of Blue');
    await seedAlbum(id: 'album-2', title: 'In a Silent Way');

    await db
        .into(db.nfcTags)
        .insert(
          NfcTagsCompanion.insert(
            id: 'nfc-1',
            albumId: 'album-1',
            nfcTagId: 'same-tag',
            writtenAt: '2026-08-11T10:00:00.000Z',
          ),
        );

    await expectLater(
      db
          .into(db.nfcTags)
          .insert(
            NfcTagsCompanion.insert(
              id: 'nfc-2',
              albumId: 'album-2',
              nfcTagId: 'same-tag',
              writtenAt: '2026-08-11T10:01:00.000Z',
            ),
          ),
      throwsA(anything),
    );
  });

  test('an album can have at most one nfc tag', () async {
    await seedArtist();
    await seedAlbum(id: 'album-1', title: 'Kind of Blue');

    await db
        .into(db.nfcTags)
        .insert(
          NfcTagsCompanion.insert(
            id: 'nfc-1',
            albumId: 'album-1',
            nfcTagId: 'tag-1',
            writtenAt: '2026-08-11T10:00:00.000Z',
          ),
        );

    await expectLater(
      db
          .into(db.nfcTags)
          .insert(
            NfcTagsCompanion.insert(
              id: 'nfc-2',
              albumId: 'album-1',
              nfcTagId: 'tag-2',
              writtenAt: '2026-08-11T10:01:00.000Z',
            ),
          ),
      throwsA(anything),
    );
  });

  test('nfc tag requires an existing album', () async {
    await expectLater(
      db
          .into(db.nfcTags)
          .insert(
            NfcTagsCompanion.insert(
              id: 'nfc-1',
              albumId: 'does-not-exist',
              nfcTagId: 'tag-1',
              writtenAt: '2026-08-11T10:00:00.000Z',
            ),
          ),
      throwsA(anything),
    );
  });
}

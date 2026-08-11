import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/nfc_tag_repository.dart';

void main() {
  late AppDatabase db;
  late NfcTagRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = NfcTagRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedAlbum(String albumId) async {
    await db
        .into(db.artists)
        .insert(
          ArtistsCompanion.insert(
            id: 'artist-$albumId',
            name: 'Artist $albumId',
            createdAt: '2026-08-11T12:00:00.000Z',
          ),
        );

    await db
        .into(db.albums)
        .insert(
          AlbumsCompanion.insert(
            id: albumId,
            title: 'Album $albumId',
            artistId: 'artist-$albumId',
            createdAt: '2026-08-11T12:00:00.000Z',
          ),
        );
  }

  test('create persists an NFC tag and owns persistence metadata', () async {
    await seedAlbum('album-1');

    final writtenAt = DateTime.utc(2026, 8, 11, 16, 15);
    final created = await repository.create(
      albumId: ' album-1 ',
      nfcTagId: ' tag-001 ',
      writtenAt: writtenAt,
    );

    final stored = await repository.findByTagId('tag-001');

    expect(created.id, startsWith('nfc-tag-'));
    expect(created.albumId, 'album-1');
    expect(created.nfcTagId, 'tag-001');
    expect(created.writtenAt, writtenAt.toIso8601String());
    expect(stored, created);
  });

  test('findByTagId returns the matching tag', () async {
    await seedAlbum('album-1');
    final created = await repository.create(
      albumId: 'album-1',
      nfcTagId: 'tag-001',
    );

    final result = await repository.findByTagId('tag-001');

    expect(result, created);
  });

  test('findByTagId returns null when the tag is not registered', () async {
    final result = await repository.findByTagId('missing-tag');

    expect(result, isNull);
  });

  test('findByAlbum returns the matching tag', () async {
    await seedAlbum('album-1');
    final created = await repository.create(
      albumId: 'album-1',
      nfcTagId: 'tag-001',
    );

    final result = await repository.findByAlbum('album-1');

    expect(result, created);
  });

  test('findByAlbum returns null when the album has no tag', () async {
    await seedAlbum('album-1');

    final result = await repository.findByAlbum('album-1');

    expect(result, isNull);
  });

  test('delete removes the matching NFC tag association', () async {
    await seedAlbum('album-1');
    final created = await repository.create(
      albumId: 'album-1',
      nfcTagId: 'tag-001',
    );

    final deletedRows = await repository.delete(created.id);
    final result = await repository.findByTagId('tag-001');

    expect(deletedRows, 1);
    expect(result, isNull);
  });

  test('create rejects empty album and NFC tag IDs', () async {
    expect(
      () => repository.create(albumId: '   ', nfcTagId: 'tag-001'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => repository.create(albumId: 'album-1', nfcTagId: '   '),
      throwsA(isA<ArgumentError>()),
    );
  });
}

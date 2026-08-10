import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';

void main() {
  late AppDatabase db;
  late AlbumRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = AlbumRepository(db);
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
            createdAt: '2026-08-09T12:00:00.000Z',
          ),
        );
  }

  AlbumsCompanion album({
    required String id,
    required String title,
    required String artistId,
  }) {
    return AlbumsCompanion.insert(
      id: id,
      title: title,
      artistId: artistId,
      createdAt: '2026-08-09T12:00:00.000Z',
    );
  }

  test('create inserts an album', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');

    final rowId = await repository.create(
      album(id: 'album-1', title: 'Blue Train', artistId: 'artist-1'),
    );

    final created = await repository.findById('album-1');

    expect(rowId, greaterThan(0));
    expect(created, isNotNull);
    expect(created!.title, 'Blue Train');
    expect(created.artistId, 'artist-1');
  });

  test('findAll returns every album', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');
    await repository.create(
      album(id: 'album-1', title: 'Blue Train', artistId: 'artist-1'),
    );
    await repository.create(
      album(id: 'album-2', title: 'Giant Steps', artistId: 'artist-1'),
    );

    final results = await repository.findAll();

    expect(results, hasLength(2));
    expect(results.map((album) => album.id).toSet(), {'album-1', 'album-2'});
  });

  test('findById returns the matching album and null when missing', () async {
    await createArtist(id: 'artist-1', name: 'Miles Davis');
    await repository.create(
      album(id: 'album-1', title: 'Kind of Blue', artistId: 'artist-1'),
    );

    final found = await repository.findById('album-1');
    final missing = await repository.findById('missing');

    expect(found?.title, 'Kind of Blue');
    expect(missing, isNull);
  });

  test('update replaces the stored album', () async {
    await createArtist(id: 'artist-1', name: 'Miles Davis');
    await repository.create(
      album(id: 'album-1', title: 'Kind of Blue', artistId: 'artist-1'),
    );

    final existing = await repository.findById('album-1');
    final updated = existing!.copyWith(title: 'Kind of Blue - Updated');

    final didUpdate = await repository.update(updated);
    final result = await repository.findById('album-1');

    expect(didUpdate, isTrue);
    expect(result?.title, 'Kind of Blue - Updated');
  });

  test('delete removes the matching album', () async {
    await createArtist(id: 'artist-1', name: 'Daft Punk');
    await repository.create(
      album(id: 'album-1', title: 'Discovery', artistId: 'artist-1'),
    );

    final deletedRows = await repository.delete('album-1');
    final result = await repository.findById('album-1');

    expect(deletedRows, 1);
    expect(result, isNull);
  });

  test('search matches album title case-insensitively', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');
    await createArtist(id: 'artist-2', name: 'Daft Punk');
    await repository.create(
      album(id: 'album-1', title: 'Blue Train', artistId: 'artist-1'),
    );
    await repository.create(
      album(id: 'album-2', title: 'Discovery', artistId: 'artist-2'),
    );

    final results = await repository.search('tRaIn');

    expect(results.map((album) => album.id), ['album-1']);
  });

  test('search matches artist name case-insensitively', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');
    await createArtist(id: 'artist-2', name: 'Miles Davis');
    await repository.create(
      album(id: 'album-1', title: 'Blue Train', artistId: 'artist-1'),
    );
    await repository.create(
      album(id: 'album-2', title: 'Kind of Blue', artistId: 'artist-2'),
    );

    final results = await repository.search('cOlTrAnE');

    expect(results.map((album) => album.id), ['album-1']);
  });

  test('search returns all albums for an empty query', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');
    await repository.create(
      album(id: 'album-1', title: 'Blue Train', artistId: 'artist-1'),
    );
    await repository.create(
      album(id: 'album-2', title: 'Giant Steps', artistId: 'artist-1'),
    );

    final results = await repository.search('   ');

    expect(results, hasLength(2));
  });
}

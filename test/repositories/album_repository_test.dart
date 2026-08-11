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

  Future<Album> createAlbum({required String title, required String artistId}) {
    return repository.create(title: title, artistId: artistId);
  }

  test('create inserts an album and owns persistence metadata', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');

    final created = await repository.create(
      title: '  Blue Train  ',
      artistId: 'artist-1',
      releaseYear: 1957,
    );

    final stored = await repository.findById(created.id);

    expect(created.id, startsWith('album-'));
    expect(created.title, 'Blue Train');
    expect(created.artistId, 'artist-1');
    expect(created.releaseYear, 1957);
    expect(created.createdAt, isNotEmpty);
    expect(stored, created);
  });

  test('findAll returns every album', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');
    final first = await createAlbum(title: 'Blue Train', artistId: 'artist-1');
    final second = await createAlbum(
      title: 'Giant Steps',
      artistId: 'artist-1',
    );

    final results = await repository.findAll();

    expect(results, hasLength(2));
    expect(results.map((album) => album.id).toSet(), {first.id, second.id});
  });

  test('findById returns the matching album and null when missing', () async {
    await createArtist(id: 'artist-1', name: 'Miles Davis');
    final created = await createAlbum(
      title: 'Kind of Blue',
      artistId: 'artist-1',
    );

    final found = await repository.findById(created.id);
    final missing = await repository.findById('missing');

    expect(found?.title, 'Kind of Blue');
    expect(missing, isNull);
  });

  test('update replaces the stored album', () async {
    await createArtist(id: 'artist-1', name: 'Miles Davis');
    final created = await createAlbum(
      title: 'Kind of Blue',
      artistId: 'artist-1',
    );
    final updated = created.copyWith(title: 'Kind of Blue - Updated');

    final didUpdate = await repository.update(updated);
    final result = await repository.findById(created.id);

    expect(didUpdate, isTrue);
    expect(result?.title, 'Kind of Blue - Updated');
  });

  test('delete removes the matching album', () async {
    await createArtist(id: 'artist-1', name: 'Daft Punk');
    final created = await createAlbum(title: 'Discovery', artistId: 'artist-1');

    final deletedRows = await repository.delete(created.id);
    final result = await repository.findById(created.id);

    expect(deletedRows, 1);
    expect(result, isNull);
  });

  test('search matches album title case-insensitively', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');
    await createArtist(id: 'artist-2', name: 'Daft Punk');
    final blueTrain = await createAlbum(
      title: 'Blue Train',
      artistId: 'artist-1',
    );
    await createAlbum(title: 'Discovery', artistId: 'artist-2');

    final results = await repository.search('tRaIn');

    expect(results.map((album) => album.id), [blueTrain.id]);
  });

  test('search matches artist name case-insensitively', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');
    await createArtist(id: 'artist-2', name: 'Miles Davis');
    final blueTrain = await createAlbum(
      title: 'Blue Train',
      artistId: 'artist-1',
    );
    await createAlbum(title: 'Kind of Blue', artistId: 'artist-2');

    final results = await repository.search('cOlTrAnE');

    expect(results.map((album) => album.id), [blueTrain.id]);
  });

  test('search returns all albums for an empty query', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');
    await createAlbum(title: 'Blue Train', artistId: 'artist-1');
    await createAlbum(title: 'Giant Steps', artistId: 'artist-1');

    final results = await repository.search('   ');

    expect(results, hasLength(2));
  });

  test('search returns an empty list when nothing matches', () async {
    await createArtist(id: 'artist-1', name: 'John Coltrane');
    await createAlbum(title: 'Blue Train', artistId: 'artist-1');

    final results = await repository.search('no-such-record');

    expect(results, isEmpty);
  });
}

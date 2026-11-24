import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';
import 'package:vinyl_app/repositories/genre_repository.dart';
import 'package:vinyl_app/repositories/nfc_tag_repository.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/repositories/track_repository.dart';
import 'package:vinyl_app/services/album_deletion_service.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/services/collection_tidy_service.dart';
import 'package:vinyl_app/services/record_write_service.dart';
import 'package:vinyl_app/utils/name_match.dart';

void main() {
  late AppDatabase db;
  late Directory documents;
  late ArtworkStorageService artwork;
  late CollectionTidyService tidy;
  late RecordWriteService writes;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    documents = await Directory.systemTemp.createTemp('groovefolio-tidy-');
    artwork = ArtworkStorageService(
      documentsDirectoryResolver: () async => documents,
    );
    tidy = CollectionTidyService(db, artwork);
    writes = RecordWriteService(
      transactionRunner: DriftDatabaseTransactionRunner(db),
      albumRepository: AlbumRepository(db),
      artistRepository: ArtistRepository(db),
      genreRepository: GenreRepository(db),
      trackRepository: TrackRepository(db),
      releaseLinkRepository: DiscogsReleaseLinkRepository(db),
      tidyService: tidy,
    );
  });

  tearDown(() async {
    await db.close();
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  Future<Album> record(String title, String artist, List<String> genres) =>
      writes.createRecord(title: title, artistName: artist, genreNames: genres);

  Future<Set<String>> artistNames() async => {
    for (final artist in await db.select(db.artists).get()) artist.name,
  };
  Future<Set<String>> genreNames() async => {
    for (final genre in await db.select(db.genres).get()) genre.name,
  };

  group('name matching', () {
    test('ignores case beyond A to Z, and extra spaces', () {
      expect(nameMatchKey('BJÖRK'), nameMatchKey('Björk'));
      expect(nameMatchKey('  Sigur   Rós '), nameMatchKey('sigur rós'));
      expect(nameMatchKey('ÆTHER'), nameMatchKey('æther'));
      // Accents still matter.
      expect(nameMatchKey('Bjork'), isNot(nameMatchKey('Björk')));
    });

    test('accented artist names in another case reuse the artist', () async {
      final first = await record('Homogenic', 'Björk', const []);
      final second = await record('Vespertine', 'BJÖRK', const []);
      expect(second.artistId, first.artistId);
      expect(await artistNames(), {'Björk'});
    });

    test('accented genre names in another case reuse the genre', () async {
      await record('A', 'X', const ['Música Popular']);
      await record('B', 'Y', const ['MÚSICA POPULAR']);
      expect(await genreNames(), {'Música Popular'});
    });

    test('existing duplicates resolve to the earliest artist', () async {
      await db
          .into(db.artists)
          .insert(
            ArtistsCompanion.insert(
              id: 'old',
              name: 'BJÖRK',
              createdAt: '2025-01-01T00:00:00.000Z',
            ),
          );
      await db
          .into(db.artists)
          .insert(
            ArtistsCompanion.insert(
              id: 'new',
              name: 'Björk',
              createdAt: '2026-01-01T00:00:00.000Z',
            ),
          );
      final artist = await ArtistRepository(db).findOrCreate('björk');
      expect(artist.id, 'old');
    });
  });

  group('unused artists and genres', () {
    test('editing away an artist and genre removes them', () async {
      final album = await record('Blue Train', 'Coltrane', const ['Jazz']);
      await record('Kind of Blue', 'Miles Davis', const ['Jazz']);

      await writes.updateRecord(
        existing: album,
        title: 'Blue Train',
        artistName: 'John Coltrane',
        genreNames: const ['Hard Bop'],
      );

      expect(await artistNames(), {'John Coltrane', 'Miles Davis'});
      expect(await genreNames(), {'Hard Bop', 'Jazz'});
    });

    test('deleting the last record by an artist removes the artist', () async {
      final blueTrain = await record('Blue Train', 'Coltrane', const ['Jazz']);
      final giant = await record('Giant Steps', 'Coltrane', const ['Bop']);
      await record('Rumours', 'Fleetwood Mac', const ['Rock']);
      final deletion = AlbumDeletionService(
        albumRepository: AlbumRepository(db),
        playRepository: PlayRepository(db),
        nfcTagRepository: NfcTagRepository(db),
        artworkStorageService: artwork,
        tidyService: tidy,
      );

      await deletion.deleteAlbum(giant.id);
      expect(await artistNames(), {'Coltrane', 'Fleetwood Mac'});
      expect(await genreNames(), {'Jazz', 'Rock'});

      await deletion.deleteAlbum(blueTrain.id);
      expect(await artistNames(), {'Fleetwood Mac'});
      expect(await genreNames(), {'Rock'});
    });

    test('nothing a record still uses is removed', () async {
      await record('Rumours', 'Fleetwood Mac', const ['Rock', 'Pop']);
      final result = await tidy.removeUnusedArtistsAndGenres();
      expect(result.artists, 0);
      expect(result.genres, 0);
    });
  });

  group('stray cover files', () {
    Future<File> file(
      String name, {
      Duration age = const Duration(days: 2),
    }) async {
      final directory = Directory(p.join(documents.path, 'artwork'));
      await directory.create(recursive: true);
      final file = File(p.join(directory.path, name));
      await file.writeAsBytes(Uint8List.fromList([1, 2, 3]));
      await file.setLastModified(DateTime.now().subtract(age));
      return file;
    }

    test('removes only old covers of records that no longer exist', () async {
      final kept = await record('Kept', 'Artist', const []);
      final keptFile = await file('${kept.id}.jpg');
      final stray = await file('album-gone.jpg');
      final fresh = await file('album-just-saved.jpg', age: Duration.zero);
      final other = await file('notes.txt');

      final result = await tidy.tidy();

      expect(result.artworkFiles, 1);
      expect(await stray.exists(), isFalse);
      expect(await keptFile.exists(), isTrue);
      expect(
        await fresh.exists(),
        isTrue,
        reason: 'may belong to a save in progress',
      );
      expect(await other.exists(), isTrue);
    });

    test('keeps a cover any record points to, whatever its name', () async {
      final referenced = await file('renamed.jpg');
      final album = await record('Pointed', 'Artist', const []);
      await (db.update(db.albums)..where((a) => a.id.equals(album.id))).write(
        AlbumsCompanion(artworkPath: Value(referenced.path)),
      );

      await tidy.tidy();
      expect(await referenced.exists(), isTrue);
    });

    test('no artwork folder is fine', () async {
      expect((await tidy.tidy()).artworkFiles, 0);
    });
  });

  group('provider', () {
    test('tidies only when records live in the app database', () {
      final real = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(real.dispose);
      expect(real.read(collectionTidyServiceProvider), isNotNull);

      final fake = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          artistRepositoryProvider.overrideWithValue(_FakeArtists()),
        ],
      );
      addTearDown(fake.dispose);
      expect(fake.read(collectionTidyServiceProvider), isNull);
    });
  });
}

class _FakeArtists implements IArtistRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

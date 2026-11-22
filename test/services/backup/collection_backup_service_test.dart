import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/services/backup/collection_backup_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('groovefolio_backup_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<(AppDatabase, ArtworkStorageService, CollectionBackupService)> open(
    String name,
  ) async {
    final docs = await Directory('${root.path}/$name').create();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final artwork = ArtworkStorageService(
      documentsDirectoryResolver: () async => docs,
    );
    return (
      db,
      artwork,
      CollectionBackupService(
        database: db,
        artworkStorage: artwork,
        clock: () => DateTime.utc(2026, 11, 22, 9, 30),
      ),
    );
  }

  final cover = Uint8List.fromList(List.generate(256, (i) => i));

  Future<void> seed(AppDatabase db, ArtworkStorageService artwork) async {
    final coverPath = await artwork.saveArtworkBytes(cover, 'album-1');
    await db.batch((b) {
      b
        ..insert(
          db.artists,
          const Artist(id: 'artist-1', name: 'Björk', createdAt: '2026-01-01'),
        )
        ..insert(
          db.genres,
          const Genre(
            id: 'genre-1',
            name: 'Electronic',
            createdAt: '2026-01-01',
          ),
        )
        ..insertAll(db.albums, [
          Album(
            id: 'album-1',
            title: 'Homogenic',
            artistId: 'artist-1',
            releaseYear: 1997,
            label: 'One Little Indian',
            artworkPath: coverPath,
            purchaseDate: '2026-02-03',
            purchasePriceCents: 3299,
            createdAt: '2026-01-02',
          ),
          const Album(
            id: 'album-2',
            title: 'Post',
            artistId: 'artist-1',
            createdAt: '2026-01-03',
          ),
        ])
        ..insert(
          db.albumGenres,
          const AlbumGenre(albumId: 'album-1', genreId: 'genre-1'),
        )
        ..insert(
          db.albumDiscogsReleases,
          const AlbumDiscogsRelease(albumId: 'album-1', releaseId: 12345),
        )
        ..insert(
          db.tracks,
          const Track(
            id: 'track-1',
            albumId: 'album-1',
            title: 'Jóga',
            position: 'A2',
            side: 'A',
            sequence: 1,
            durationSeconds: 305,
            createdAt: '2026-01-02',
          ),
        )
        ..insertAll(db.plays, [
          const Play(
            id: 'play-1',
            albumId: 'album-1',
            playedAt: '2026-03-01T20:00:00',
            sidePlayed: SidePlayed.sideA,
            createdAt: '2026-03-01T20:00:00',
          ),
          const Play(
            id: 'play-2',
            albumId: 'album-2',
            playedAt: '2026-03-02T20:00:00',
            sidePlayed: SidePlayed.full,
            createdAt: '2026-03-02T20:00:00',
          ),
        ])
        ..insert(
          db.nfcTags,
          const NfcTag(
            id: 'nfc-1',
            albumId: 'album-1',
            nfcTagId: '04A1B2C3',
            writtenAt: '2026-03-01',
          ),
        );
    });
  }

  Uint8List zipWith(Map<String, Object?> manifest) {
    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          BackupFormat.manifestName,
          utf8.encode(jsonEncode(manifest)),
        ),
      );
    return ZipEncoder().encodeBytes(archive);
  }

  Map<String, Object?> manifest({
    Object? format = BackupFormat.name,
    Object? version = BackupFormat.currentVersion,
    Map<String, Object?>? data,
  }) => {
    'format': format,
    'formatVersion': version,
    'schemaVersion': 6,
    'exportedAt': '2026-11-22T09:30:00Z',
    'data':
        data ??
        {
          'artists': <Object?>[],
          'albums': <Object?>[],
          'genres': <Object?>[],
          'album_genres': <Object?>[],
          'album_discogs_releases': <Object?>[],
          'tracks': <Object?>[],
          'plays': <Object?>[],
          'nfc_tags': <Object?>[],
        },
  };

  test('round trip restores every table and cover on another device', () async {
    final (source, sourceArtwork, sourceService) = await open('source');
    await seed(source, sourceArtwork);
    final bytes = await sourceService.createBackup();

    final (target, _, targetService) = await open('target');
    final contents = targetService.readBackup(bytes);
    expect(contents.summary.albums, 2);
    expect(contents.summary.plays, 2);
    expect(contents.summary.artworkFiles, 1);
    expect(contents.exportedAt, DateTime.utc(2026, 11, 22, 9, 30).toLocal());

    final result = await targetService.restore(contents);
    expect(result.albums, 2);
    expect(result.artworkFiles, 1);

    Future<List<Object?>> rows(AppDatabase db) async => [
      await db.select(db.artists).get(),
      await db.select(db.genres).get(),
      await db.select(db.albumGenres).get(),
      await db.select(db.albumDiscogsReleases).get(),
      await db.select(db.tracks).get(),
      await db.select(db.plays).get(),
      await db.select(db.nfcTags).get(),
    ];
    expect(await rows(target), await rows(source));

    final sourceAlbums = await source.select(source.albums).get();
    final targetAlbums = await target.select(target.albums).get();
    expect(
      targetAlbums.map((a) => a.copyWith(artworkPath: const Value(null))),
      sourceAlbums.map((a) => a.copyWith(artworkPath: const Value(null))),
    );
    final restored = targetAlbums.singleWhere((a) => a.id == 'album-1');
    expect(restored.artworkPath, startsWith('${root.path}/target/artwork/'));
    expect(await File(restored.artworkPath!).readAsBytes(), cover);
    expect(
      targetAlbums.singleWhere((a) => a.id == 'album-2').artworkPath,
      isNull,
    );
  });

  test('suggested file name uses the local date', () async {
    final (_, _, service) = await open('name');
    expect(service.suggestedFileName(), 'groovefolio-backup-2026-11-22.zip');
  });

  test('restore refuses a collection that already has records', () async {
    final (source, sourceArtwork, sourceService) = await open('source');
    await seed(source, sourceArtwork);
    final bytes = await sourceService.createBackup();

    final (target, targetArtwork, targetService) = await open('target');
    await target
        .into(target.artists)
        .insert(
          const Artist(id: 'artist-x', name: 'Other', createdAt: '2026-01-01'),
        );
    await target
        .into(target.albums)
        .insert(
          const Album(
            id: 'album-x',
            title: 'Mine',
            artistId: 'artist-x',
            createdAt: '2026-01-01',
          ),
        );
    expect(await targetService.isCollectionEmpty(), isFalse);

    await expectLater(
      targetService.restore(targetService.readBackup(bytes)),
      throwsA(isA<BackupRestoreNotEmptyException>()),
    );
    final albums = await target.select(target.albums).get();
    expect(albums.map((a) => a.id), ['album-x']);
    expect(
      targetArtwork.artworkFile('${root.path}/target/artwork/album-1.jpg'),
      isNull,
    );
  });

  test(
    'leftover artists and genres with no records do not block restore',
    () async {
      final (source, sourceArtwork, sourceService) = await open('source');
      await seed(source, sourceArtwork);
      final bytes = await sourceService.createBackup();

      final (target, _, targetService) = await open('target');
      await target
          .into(target.genres)
          .insert(
            const Genre(
              id: 'genre-old',
              name: 'ELECTRONIC',
              createdAt: '2025-01-01',
            ),
          );
      await target
          .into(target.artists)
          .insert(
            const Artist(
              id: 'artist-old',
              name: 'Old',
              createdAt: '2025-01-01',
            ),
          );
      expect(await targetService.isCollectionEmpty(), isTrue);

      await targetService.restore(targetService.readBackup(bytes));
      final genres = await target.select(target.genres).get();
      expect(genres.map((g) => g.id), ['genre-1']);
      final artists = await target.select(target.artists).get();
      expect(artists.map((a) => a.id), ['artist-1']);
    },
  );

  test('a broken reference rolls the whole restore back', () async {
    final (target, _, service) = await open('target');
    final data = manifest()['data']! as Map<String, Object?>;
    data['plays'] = [
      {
        'id': 'play-1',
        'album_id': 'missing-album',
        'played_at': '2026-03-01',
        'side_played': 'full',
        'created_at': '2026-03-01',
      },
    ];
    data['artists'] = [
      {'id': 'artist-1', 'name': 'A', 'created_at': '2026-01-01'},
    ];
    final contents = service.readBackup(zipWith(manifest(data: data)));

    await expectLater(service.restore(contents), throwsA(anything));
    expect(await target.select(target.artists).get(), isEmpty);
    expect(await target.select(target.plays).get(), isEmpty);
  });

  group('readBackup rejects', () {
    late CollectionBackupService service;

    setUp(() async {
      (_, _, service) = await open('reader');
    });

    Matcher message(String text) => throwsA(
      isA<BackupFormatException>().having(
        (e) => e.message,
        'message',
        contains(text),
      ),
    );

    test('a file that is not a zip', () {
      expect(
        () => service.readBackup(Uint8List.fromList(utf8.encode('hello'))),
        message('isn’t a Groovefolio backup'),
      );
    });

    test('a zip without the backup manifest', () {
      final zip = ZipEncoder().encodeBytes(
        Archive()..add(ArchiveFile.string('notes.txt', 'hi')),
      );
      expect(() => service.readBackup(zip), message('isn’t a Groovefolio'));
    });

    test('a manifest from another app', () {
      expect(
        () => service.readBackup(zipWith(manifest(format: 'something-else'))),
        message('isn’t a Groovefolio'),
      );
    });

    test('a backup from a newer app version', () {
      expect(
        () => service.readBackup(zipWith(manifest(version: 2))),
        message('newer version of Groovefolio'),
      );
    });

    test('rows with the wrong types or unknown values', () {
      final data = manifest()['data']! as Map<String, Object?>;
      data['plays'] = [
        {
          'id': 'play-1',
          'album_id': 'album-1',
          'played_at': '2026-03-01',
          'side_played': 'sideZ',
          'created_at': '2026-03-01',
        },
      ];
      expect(
        () => service.readBackup(zipWith(manifest(data: data))),
        message('damaged or incomplete'),
      );
      data['plays'] = <Object?>[];
      data['albums'] = [
        {'id': 'album-1', 'title': 7},
      ];
      expect(
        () => service.readBackup(zipWith(manifest(data: data))),
        message('damaged or incomplete'),
      );
    });

    test('a missing table', () {
      final data = manifest()['data']! as Map<String, Object?>
        ..remove('tracks');
      expect(
        () => service.readBackup(zipWith(manifest(data: data))),
        message('damaged or incomplete'),
      );
    });
  });

  test('cover entries outside the expected file name are ignored', () async {
    final (_, _, service) = await open('reader');
    final data = manifest()['data']! as Map<String, Object?>;
    data['albums'] = [
      {
        'id': '..',
        'title': 'Escape',
        'artist_id': 'artist-1',
        'created_at': '2026-01-01',
        'artwork': 'artwork/...jpg',
      },
      {
        'id': 'album-2',
        'title': 'Wrong name',
        'artist_id': 'artist-1',
        'created_at': '2026-01-01',
        'artwork': '../../outside.jpg',
      },
    ];
    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          BackupFormat.manifestName,
          utf8.encode(jsonEncode(manifest(data: data))),
        ),
      )
      ..add(ArchiveFile.bytes('artwork/...jpg', [1, 2, 3]))
      ..add(ArchiveFile.bytes('../../outside.jpg', [1, 2, 3]));
    final contents = service.readBackup(ZipEncoder().encodeBytes(archive));
    expect(contents.albums, hasLength(2));
    expect(contents.artwork, isEmpty);
  });
}

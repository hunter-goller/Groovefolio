import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/repositories/artist_repository.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';
import 'package:vinyl_app/repositories/genre_repository.dart';
import 'package:vinyl_app/repositories/track_repository.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/services/discogs/discogs_catalog_service.dart';
import 'package:vinyl_app/services/discogs/discogs_collection_import_service.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/record_write_service.dart';

void main() {
  test('prepares paginated import and classifies duplicates/review', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final artists = ArtistRepository(db);
    final albums = AlbumRepository(db);
    final genres = GenreRepository(db);
    final tracks = TrackRepository(db);
    final links = DiscogsReleaseLinkRepository(db);
    final artwork = ArtworkStorageService(
      documentsDirectoryResolver: () async => Directory.systemTemp,
    );

    final exactArtist = await artists.findOrCreate('Existing Artist');
    final exactAlbum = await albums.create(
      title: 'Already Linked',
      artistId: exactArtist.id,
    );
    await links.link(albumId: exactAlbum.id, releaseId: 10);

    final reviewArtist = await artists.findOrCreate('Artist B');
    await albums.create(title: 'Same Album', artistId: reviewArtist.id);

    final catalog = _FakeCatalogService(
      pages: {
        1: DiscogsCollectionPage(
          items: [
            _item(10, 1, 'Already Linked', 'Existing Artist'),
            _item(20, 2, 'Same Album', 'Artist B'),
            _item(30, 3, 'Brand New', 'Artist C'),
            _item(40, 4, 'Compact Disc', 'Artist D', formats: const ['CD']),
          ],
          page: 1,
          pages: 2,
          totalItems: 5,
        ),
        2: DiscogsCollectionPage(
          items: [_item(30, 5, 'Brand New', 'Artist C')],
          page: 2,
          pages: 2,
          totalItems: 5,
        ),
      },
    );

    final service = DefaultDiscogsCollectionImportService(
      catalog,
      albums,
      artists,
      links,
      artwork,
      _recordWriter(db, albums, artists, genres, tracks, links),
    );

    final preview = await service.prepare('hunter');

    expect(catalog.requestedPages, [1, 2]);
    expect(preview.totalFetched, 5);
    expect(preview.nonVinylIgnored, 1);
    expect(preview.vinylFound, 4);
    expect(preview.newCount, 1);
    expect(preview.exactDuplicateCount, 2);
    expect(preview.needsReviewCount, 1);

    final review = preview.candidates.singleWhere(
      (candidate) => candidate.item.releaseId == 20,
    );
    expect(review.status, DiscogsCollectionCandidateStatus.needsReview);
    expect(review.selectedByDefault, isFalse);

    final newRecord = preview.candidates.firstWhere(
      (candidate) =>
          candidate.item.releaseId == 30 &&
          candidate.status == DiscogsCollectionCandidateStatus.newRecord,
    );
    expect(newRecord.selectedByDefault, isTrue);
  });

  test(
    'imports mapped release and continues after another release fails',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final tempDirectory = await Directory.systemTemp.createTemp(
        'groovefolio-import-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final artists = ArtistRepository(db);
      final albums = AlbumRepository(db);
      final genres = GenreRepository(db);
      final tracks = TrackRepository(db);
      final links = DiscogsReleaseLinkRepository(db);
      final artwork = ArtworkStorageService(
        documentsDirectoryResolver: () async => tempDirectory,
      );
      final catalog = _FakeCatalogService(
        details: {
          100: const DiscogsReleaseDetails(
            releaseId: 100,
            title: 'Blue Train',
            artist: 'John Coltrane',
            year: 1957,
            label: 'Blue Note',
            genres: ['Jazz'],
            styles: ['Hard Bop'],
            artworkUrl: 'https://example.test/blue-train.jpg',
            tracks: [
              DiscogsTrack(
                title: 'Blue Train',
                position: 'A1',
                side: 'A',
                sequence: 0,
                durationSeconds: 642,
              ),
              DiscogsTrack(
                title: 'Moment’s Notice',
                position: 'A2',
                side: 'A',
                sequence: 1,
                durationSeconds: 558,
              ),
            ],
          ),
        },
        releaseFailures: {
          101: const DiscogsApiFailure('Release lookup failed.'),
        },
      );

      final service = DefaultDiscogsCollectionImportService(
        catalog,
        albums,
        artists,
        links,
        artwork,
        _recordWriter(db, albums, artists, genres, tracks, links),
      );

      final progress = <DiscogsImportProgress>[];
      final result = await service.importCandidates([
        DiscogsCollectionCandidate(
          item: _item(100, 1, 'Blue Train', 'John Coltrane'),
          status: DiscogsCollectionCandidateStatus.newRecord,
        ),
        DiscogsCollectionCandidate(
          item: _item(101, 2, 'Broken Release', 'Artist'),
          status: DiscogsCollectionCandidateStatus.newRecord,
        ),
      ], onProgress: progress.add);

      expect(result.requested, 2);
      expect(result.imported, 1);
      expect(result.skipped, 0);
      expect(result.failed, 1);
      expect(result.failures.single.releaseId, 101);
      expect(progress.last.completed, 2);

      final storedAlbums = await albums.findAll();
      expect(storedAlbums, hasLength(1));
      final album = storedAlbums.single;
      expect(album.title, 'Blue Train');
      expect(album.releaseYear, 1957);
      expect(album.label, 'Blue Note');
      expect(album.artworkPath, isNotNull);
      expect(File(album.artworkPath!).existsSync(), isTrue);

      final artist = await artists.findById(album.artistId);
      expect(artist?.name, 'John Coltrane');
      expect(await links.findReleaseIdForAlbum(album.id), 100);
      expect(
        (await genres.findByAlbum(album.id)).map((genre) => genre.name).toSet(),
        {'Jazz', 'Hard Bop'},
      );
      final storedTracks = await tracks.findByAlbum(album.id);
      expect(storedTracks.map((track) => track.position), ['A1', 'A2']);
      expect(storedTracks.first.durationSeconds, 642);
    },
  );

  test('a rate limit that persists after retries stops the batch', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final albums = AlbumRepository(db);
    final artists = ArtistRepository(db);
    final genres = GenreRepository(db);
    final tracks = TrackRepository(db);
    final links = DiscogsReleaseLinkRepository(db);
    final artwork = ArtworkStorageService(
      documentsDirectoryResolver: () async => Directory.systemTemp,
    );
    final catalog = _FakeCatalogService(
      releaseFailures: {
        100: const DiscogsRateLimitFailure(
          'Rate limited.',
          retryAfter: Duration(seconds: 2),
        ),
      },
    );
    final waits = <Duration>[];
    final service = DefaultDiscogsCollectionImportService(
      catalog,
      albums,
      artists,
      links,
      artwork,
      _recordWriter(db, albums, artists, genres, tracks, links),
      delay: (d) async => waits.add(d),
    );

    await expectLater(
      service.importCandidates([
        DiscogsCollectionCandidate(
          item: _item(100, 1, 'First', 'Artist'),
          status: DiscogsCollectionCandidateStatus.newRecord,
        ),
        DiscogsCollectionCandidate(
          item: _item(101, 2, 'Second', 'Artist'),
          status: DiscogsCollectionCandidateStatus.newRecord,
        ),
      ]),
      throwsA(isA<DiscogsRateLimitFailure>()),
    );

    // One try plus three retries, each after the wait Discogs asked for.
    expect(catalog.requestedReleases, [100, 100, 100, 100]);
    expect(waits, List.filled(3, const Duration(seconds: 2)));
    expect(await albums.findAll(), isEmpty);
  });

  group('rate limits and cancelling', () {
    late AppDatabase db;
    late AlbumRepository albums;
    late DiscogsReleaseLinkRepository links;
    late RecordWriteService writer;
    late ArtistRepository artists;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      albums = AlbumRepository(db);
      artists = ArtistRepository(db);
      links = DiscogsReleaseLinkRepository(db);
      writer = _recordWriter(
        db,
        albums,
        artists,
        GenreRepository(db),
        TrackRepository(db),
        links,
      );
    });
    tearDown(() => db.close());

    DefaultDiscogsCollectionImportService service(
      _FakeCatalogService catalog, {
      ImportDelay? delay,
    }) => DefaultDiscogsCollectionImportService(
      catalog,
      albums,
      artists,
      links,
      ArtworkStorageService(
        documentsDirectoryResolver: () async => Directory.systemTemp,
      ),
      writer,
      delay: delay ?? (_) async {},
    );

    List<DiscogsCollectionCandidate> candidates(List<int> ids) => [
      for (final id in ids)
        DiscogsCollectionCandidate(
          item: _item(id, id, 'Record $id', 'Artist'),
          status: DiscogsCollectionCandidateStatus.newRecord,
        ),
    ];

    test(
      'waits as Discogs asks, then carries on with the same record',
      () async {
        final catalog = _FakeCatalogService(rateLimitedTimes: {101: 2});
        final waits = <Duration>[];
        final progress = <DiscogsImportProgress>[];
        final result = await service(catalog, delay: (d) async => waits.add(d))
            .importCandidates(
              candidates([100, 101, 102]),
              onProgress: progress.add,
            );

        expect(result.imported, 3);
        expect(result.cancelled, isFalse);
        expect(catalog.requestedReleases, [100, 101, 101, 101, 102]);
        expect(waits, List.filled(2, const Duration(seconds: 5)));
        expect(
          progress
              .where((p) => p.waitingFor != null)
              .map((p) => p.currentTitle),
          ['Record 101', 'Record 101'],
        );
        expect(await albums.findAll(), hasLength(3));
      },
    );

    test('never waits longer than a minute at a time', () async {
      final catalog = _FakeCatalogService(
        rateLimitedTimes: {100: 1},
        retryAfter: const Duration(minutes: 10),
      );
      final waits = <Duration>[];
      await service(
        catalog,
        delay: (d) async => waits.add(d),
      ).importCandidates(candidates([100]));
      expect(waits, [const Duration(seconds: 60)]);
    });

    test(
      'cancelling stops between records and keeps what was imported',
      () async {
        final cancellation = DiscogsImportCancellation();
        final result = await service(_FakeCatalogService()).importCandidates(
          candidates([100, 101, 102]),
          onProgress: (p) {
            if (p.completed == 1) cancellation.cancel();
          },
          cancellation: cancellation,
        );
        expect(result.cancelled, isTrue);
        expect(result.imported, 1);
        expect(await albums.findAll(), hasLength(1));
      },
    );

    test('cancelling during a rate-limit wait stops straight away', () async {
      final cancellation = DiscogsImportCancellation();
      final never = Completer<void>();
      final catalog = _FakeCatalogService(rateLimitedTimes: {101: 3});
      final result =
          await service(
            catalog,
            delay: (_) {
              cancellation.cancel();
              return never.future;
            },
          ).importCandidates(
            candidates([100, 101, 102]),
            cancellation: cancellation,
          );
      expect(result.cancelled, isTrue);
      expect(result.imported, 1);
      expect(catalog.requestedReleases, [100, 101]);
    });
  });
}

RecordWriteService _recordWriter(
  AppDatabase db,
  IAlbumRepository albums,
  IArtistRepository artists,
  IGenreRepository genres,
  ITrackRepository tracks,
  IDiscogsReleaseLinkRepository links,
) {
  return RecordWriteService(
    transactionRunner: DriftDatabaseTransactionRunner(db),
    albumRepository: albums,
    artistRepository: artists,
    genreRepository: genres,
    trackRepository: tracks,
    releaseLinkRepository: links,
  );
}

DiscogsCollectionItem _item(
  int releaseId,
  int instanceId,
  String title,
  String artist, {
  List<String> formats = const ['Vinyl', 'LP'],
}) {
  return DiscogsCollectionItem(
    releaseId: releaseId,
    instanceId: instanceId,
    title: title,
    artist: artist,
    formats: formats,
    coverImageUrl: 'https://example.test/$releaseId.jpg',
  );
}

class _FakeCatalogService implements DiscogsCatalogService {
  _FakeCatalogService({
    this.pages = const {},
    this.details = const {},
    this.releaseFailures = const {},
    Map<int, int> rateLimitedTimes = const {},
    this.retryAfter = const Duration(seconds: 5),
  }) : _rateLimitsLeft = Map.of(rateLimitedTimes);

  final Map<int, DiscogsCollectionPage> pages;
  final Map<int, DiscogsReleaseDetails> details;
  final Map<int, DiscogsFailure> releaseFailures;

  /// Rate-limit this many requests for a release, then succeed.
  final Map<int, int> _rateLimitsLeft;
  final Duration retryAfter;
  final List<int> requestedPages = [];
  final List<int> requestedReleases = [];

  @override
  Future<DiscogsCollectionPage> collectionPage({
    required String username,
    required int page,
    int perPage = 100,
  }) async {
    requestedPages.add(page);
    return pages[page] ??
        const DiscogsCollectionPage(
          items: [],
          page: 1,
          pages: 1,
          totalItems: 0,
        );
  }

  @override
  Future<Uint8List> downloadArtwork(String url) async {
    return Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  Future<DiscogsReleaseDetails> release(int releaseId) async {
    requestedReleases.add(releaseId);
    final failure = releaseFailures[releaseId];
    if (failure != null) throw failure;
    final left = _rateLimitsLeft[releaseId] ?? 0;
    if (left > 0) {
      _rateLimitsLeft[releaseId] = left - 1;
      throw DiscogsRateLimitFailure('Rate limited.', retryAfter: retryAfter);
    }
    return details[releaseId] ??
        DiscogsReleaseDetails(
          releaseId: releaseId,
          title: 'Release $releaseId',
          artist: 'Artist',
        );
  }

  @override
  Future<List<DiscogsReleaseSearchResult>> searchReleases({
    required String artist,
    required String title,
  }) async {
    return const [];
  }

  @override
  Future<List<DiscogsReleaseSearchResult>> searchReleasesByBarcode(
    String barcode,
  ) async {
    return const [];
  }
}

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
          items: [
            _item(30, 5, 'Brand New', 'Artist C'),
          ],
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
      genres,
      tracks,
      links,
      artwork,
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

  test('imports mapped release and continues after another release fails', () async {
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
      genres,
      tracks,
      links,
      artwork,
    );

    final progress = <DiscogsImportProgress>[];
    final result = await service.importCandidates(
      [
        DiscogsCollectionCandidate(
          item: _item(100, 1, 'Blue Train', 'John Coltrane'),
          status: DiscogsCollectionCandidateStatus.newRecord,
        ),
        DiscogsCollectionCandidate(
          item: _item(101, 2, 'Broken Release', 'Artist'),
          status: DiscogsCollectionCandidateStatus.newRecord,
        ),
      ],
      onProgress: progress.add,
    );

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
  });
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
  });

  final Map<int, DiscogsCollectionPage> pages;
  final Map<int, DiscogsReleaseDetails> details;
  final Map<int, DiscogsFailure> releaseFailures;
  final List<int> requestedPages = [];

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
    final failure = releaseFailures[releaseId];
    if (failure != null) throw failure;
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
}

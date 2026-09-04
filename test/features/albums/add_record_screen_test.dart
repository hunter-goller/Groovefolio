import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/screens/add_record_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/discogs/discogs_catalog_service.dart';
import 'package:vinyl_app/services/discogs/discogs_credential_store.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_platform_adapter.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/services/record_write_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  testWidgets('requires title and artist', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add to collection'));
    await tester.tap(find.text('Add to collection'));
    await tester.pump();

    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Artist is required'), findsOneWidget);
  });

  testWidgets('creates artist and album then returns to Collection', (
    tester,
  ) async {
    final artistRepository = _FakeArtistRepository();
    final albumRepository = _FakeAlbumRepository();

    await tester.pumpWidget(
      _testApp(
        artistRepository: artistRepository,
        albumRepository: albumRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('add-record-title')),
        matching: find.byType(TextFormField),
      ),
      'Blue Train',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('add-record-artist')),
        matching: find.byType(TextFormField),
      ),
      'John Coltrane',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('add-record-year')),
        matching: find.byType(TextFormField),
      ),
      '1957',
    );

    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Add to collection'));
    await tester.tap(find.text('Add to collection'));
    await tester.pumpAndSettle();

    expect(artistRepository.names, ['John Coltrane']);
    expect(albumRepository.created, hasLength(1));
    expect(albumRepository.created.single.title, 'Blue Train');
    expect(albumRepository.created.single.releaseYear, 1957);
    expect(find.text('Collection test'), findsOneWidget);
  });

  testWidgets('persists selected genres for the created album', (tester) async {
    final artistRepository = _FakeArtistRepository();
    final albumRepository = _FakeAlbumRepository();
    final genreRepository = _FakeGenreRepository(
      initialGenres: [
        const Genre(
          id: 'genre-jazz',
          name: 'Jazz',
          createdAt: '2026-08-14T00:00:00.000Z',
        ),
      ],
    );

    await tester.pumpWidget(
      _testApp(
        artistRepository: artistRepository,
        albumRepository: albumRepository,
        genreRepository: genreRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('add-record-title')),
        matching: find.byType(TextFormField),
      ),
      'Blue Train',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('add-record-artist')),
        matching: find.byType(TextFormField),
      ),
      'John Coltrane',
    );

    await tester.ensureVisible(find.byKey(const Key('genre-add-chip')));
    await tester.tap(find.byKey(const Key('genre-add-chip')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('genre-picker-field')),
      '  Hard Bop  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('genre-create-chip')));
    await tester.pumpAndSettle();

    expect(find.text('Hard Bop'), findsOneWidget);

    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Add to collection'));
    await tester.tap(find.text('Add to collection'));
    await tester.pumpAndSettle();

    expect(genreRepository.findOrCreateNames, ['Hard Bop']);
    expect(genreRepository.albumAssignments, {
      'album-1': ['genre-2'],
    });
    expect(find.text('Collection test'), findsOneWidget);
  });

  testWidgets(
    'Discogs selection autofills editable metadata and preserves release id',
    (tester) async {
      final artistRepository = _FakeArtistRepository();
      final albumRepository = _FakeAlbumRepository();
      final genreRepository = _FakeGenreRepository();
      final catalog = _FakeDiscogsCatalogService(
        results: const [
          DiscogsReleaseSearchResult(
            releaseId: 123,
            title: 'A Love Supreme',
            artist: 'John Coltrane',
            year: 1965,
            label: 'Impulse!',
            country: 'US',
            formats: ['LP'],
          ),
        ],
        details: const DiscogsReleaseDetails(
          releaseId: 123,
          title: 'A Love Supreme',
          artist: 'John Coltrane',
          year: 1965,
          label: 'Impulse!',
          genres: ['Jazz'],
          styles: ['Modal'],
          tracks: [
            DiscogsTrack(
              title: 'Part I – Acknowledgement',
              position: 'A1',
              side: 'A',
              sequence: 0,
              durationSeconds: 467,
            ),
          ],
        ),
      );
      final links = _FakeDiscogsReleaseLinkRepository();
      final tracks = _FakeTrackRepository();

      await tester.pumpWidget(
        _testApp(
          artistRepository: artistRepository,
          albumRepository: albumRepository,
          genreRepository: genreRepository,
          catalogService: catalog,
          credentialStore: _ConnectedCredentialStore(),
          releaseLinkRepository: links,
          trackRepository: tracks,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search Discogs to autofill'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('discogs-search-artist')),
        'John Coltrane',
      );
      await tester.enterText(
        find.byKey(const Key('discogs-search-title')),
        'A Love Supreme',
      );
      await tester.tap(find.byKey(const Key('discogs-search-submit')));
      await tester.pumpAndSettle();

      final resultCard = find.byKey(const Key('discogs-result-123'));
      expect(
        find.descendant(of: resultCard, matching: find.text('A Love Supreme')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: resultCard, matching: find.textContaining('1965')),
        findsOneWidget,
      );
      await tester.tap(resultCard);
      await tester.pumpAndSettle();

      final titleField = find.descendant(
        of: find.byKey(const Key('add-record-title')),
        matching: find.byType(EditableText),
      );
      final artistField = find.descendant(
        of: find.byKey(const Key('add-record-artist')),
        matching: find.byType(EditableText),
      );

      expect(
        tester.widget<EditableText>(titleField).controller.text,
        'A Love Supreme',
      );
      expect(
        tester.widget<EditableText>(artistField).controller.text,
        'John Coltrane',
      );
      expect(find.text('Jazz'), findsOneWidget);
      expect(find.text('Modal'), findsOneWidget);

      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Add to collection'));
      await tester.tap(find.text('Add to collection'));
      await tester.pumpAndSettle();

      expect(albumRepository.created.single.title, 'A Love Supreme');
      expect(albumRepository.created.single.releaseYear, 1965);
      expect(albumRepository.created.single.label, 'Impulse!');
      expect(links.links, {'album-1': 123});
      expect(genreRepository.findOrCreateNames, ['Jazz', 'Modal']);
      expect(tracks.replacements['album-1'], hasLength(1));
      expect(tracks.replacements['album-1']!.single.position, 'A1');
    },
  );

  testWidgets(
    'barcode scan looks up Discogs and autofills the selected release',
    (tester) async {
      final artistRepository = _FakeArtistRepository();
      final albumRepository = _FakeAlbumRepository();
      final catalog = _FakeDiscogsCatalogService(
        barcodeResults: const [
          DiscogsReleaseSearchResult(
            releaseId: 456,
            title: 'Blue Train',
            artist: 'John Coltrane',
            year: 1957,
            label: 'Blue Note',
            country: 'US',
            formats: ['Vinyl', 'LP', 'Album'],
          ),
        ],
        details: const DiscogsReleaseDetails(
          releaseId: 456,
          title: 'Blue Train',
          artist: 'John Coltrane',
          year: 1957,
          label: 'Blue Note',
          genres: ['Jazz'],
          tracks: [
            DiscogsTrack(
              title: 'Blue Train',
              position: 'A1',
              side: 'A',
              sequence: 0,
              durationSeconds: 642,
            ),
          ],
        ),
      );
      final links = _FakeDiscogsReleaseLinkRepository();
      final tracks = _FakeTrackRepository();

      await tester.pumpWidget(
        _testApp(
          artistRepository: artistRepository,
          albumRepository: albumRepository,
          catalogService: catalog,
          credentialStore: _ConnectedCredentialStore(),
          releaseLinkRepository: links,
          trackRepository: tracks,
          scannedBarcode: '074643377512',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('scan-barcode-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fake-barcode-result')));
      await tester.pumpAndSettle();

      expect(catalog.barcodeLookups, ['074643377512']);
      expect(find.text('Barcode results'), findsOneWidget);
      expect(find.text('Barcode 074643377512'), findsOneWidget);

      await tester.tap(find.byKey(const Key('barcode-result-456')));
      await tester.pumpAndSettle();

      final titleField = find.descendant(
        of: find.byKey(const Key('add-record-title')),
        matching: find.byType(EditableText),
      );
      final artistField = find.descendant(
        of: find.byKey(const Key('add-record-artist')),
        matching: find.byType(EditableText),
      );

      expect(
        tester.widget<EditableText>(titleField).controller.text,
        'Blue Train',
      );
      expect(
        tester.widget<EditableText>(artistField).controller.text,
        'John Coltrane',
      );
      expect(find.text('Jazz'), findsOneWidget);

      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Add to collection'));
      await tester.tap(find.text('Add to collection'));
      await tester.pumpAndSettle();

      expect(links.links, {'album-1': 456});
      expect(tracks.replacements['album-1'], hasLength(1));
    },
  );

  testWidgets('barcode lookup shows a graceful not-found state', (
    tester,
  ) async {
    final catalog = _FakeDiscogsCatalogService();

    await tester.pumpWidget(
      _testApp(
        catalogService: catalog,
        credentialStore: _ConnectedCredentialStore(),
        releaseLinkRepository: _FakeDiscogsReleaseLinkRepository(),
        scannedBarcode: '000000000000',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scan-barcode-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake-barcode-result')));
    await tester.pumpAndSettle();

    expect(catalog.barcodeLookups, ['000000000000']);
    expect(
      find.text('No vinyl release found for this barcode.'),
      findsOneWidget,
    );
    expect(find.text('Back to Add Record'), findsOneWidget);
  });

  testWidgets('Discogs search shows empty and retryable failure states', (
    tester,
  ) async {
    final catalog = _FakeDiscogsCatalogService(
      failure: const DiscogsRateLimitFailure('Try again shortly.'),
    );

    await tester.pumpWidget(
      _testApp(
        catalogService: catalog,
        credentialStore: _ConnectedCredentialStore(),
        releaseLinkRepository: _FakeDiscogsReleaseLinkRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search Discogs to autofill'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('discogs-search-title')),
      'Blue Train',
    );
    await tester.tap(find.byKey(const Key('discogs-search-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Try again shortly.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    catalog.failure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No matching Discogs releases found.'), findsOneWidget);
  });

  testWidgets('shows the NFC write toggle only when NFC is available', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-record-write-nfc')), findsNothing);

    await tester.pumpWidget(
      _testApp(nfcAvailability: NfcAvailabilityState.available),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-record-write-nfc')), findsOneWidget);
  });

  testWidgets('writes and links an NFC tag after saving the record', (
    tester,
  ) async {
    final albums = _FakeAlbumRepository();
    final nfc = _NfcFixture();

    await tester.pumpWidget(
      _testApp(
        albumRepository: albums,
        nfcAvailability: NfcAvailabilityState.available,
        nfcService: nfc.service,
      ),
    );
    await tester.pumpAndSettle();
    await _enterRequiredRecord(tester);
    await tester.ensureVisible(find.byKey(const Key('add-record-write-nfc')));
    await tester.tap(find.byKey(const Key('add-record-write-nfc')));
    await tester.pump();

    await _submitRecord(tester);
    await tester.pumpAndSettle();

    expect(find.text('Collection test'), findsOneWidget);
    expect(find.text('Record added and NFC tag linked.'), findsOneWidget);
    expect(albums.created, hasLength(1));
    expect(nfc.platform.writtenUris, [
      Uri.parse('groovefolio://album/album-1'),
    ]);
    expect(nfc.repository.createdTags.single.albumId, 'album-1');
  });

  testWidgets('retries NFC without creating a duplicate record', (
    tester,
  ) async {
    final albums = _FakeAlbumRepository();
    final nfc = _NfcFixture(
      tags: const [
        NfcPlatformTag(
          identifier: '04:A7:39:2B:91:61:80',
          ndefAvailable: true,
          ndefWritable: false,
        ),
        NfcPlatformTag(
          identifier: '04:A7:39:2B:91:61:80',
          ndefAvailable: true,
          ndefWritable: true,
        ),
      ],
    );

    await tester.pumpWidget(
      _testApp(
        albumRepository: albums,
        nfcAvailability: NfcAvailabilityState.available,
        nfcService: nfc.service,
      ),
    );
    await tester.pumpAndSettle();
    await _enterRequiredRecord(tester);
    await tester.ensureVisible(find.byKey(const Key('add-record-write-nfc')));
    await tester.tap(find.byKey(const Key('add-record-write-nfc')));
    await tester.pump();

    await _submitRecord(tester);
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t write tag'), findsOneWidget);
    expect(
      find.text('That NFC tag is read-only or not writable.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nfc-write-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nfc-write-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Collection test'), findsOneWidget);
    expect(albums.created, hasLength(1));
    expect(nfc.platform.pollCalls, 2);
    expect(nfc.repository.createdTags, hasLength(1));
  });

  testWidgets('skipping an active NFC write keeps the saved record', (
    tester,
  ) async {
    final albums = _FakeAlbumRepository();
    final nfc = _NfcFixture(holdPoll: true, tags: const []);

    await tester.pumpWidget(
      _testApp(
        albumRepository: albums,
        nfcAvailability: NfcAvailabilityState.available,
        nfcService: nfc.service,
      ),
    );
    await tester.pumpAndSettle();
    await _enterRequiredRecord(tester);
    await tester.ensureVisible(find.byKey(const Key('add-record-write-nfc')));
    await tester.tap(find.byKey(const Key('add-record-write-nfc')));
    await tester.pump();

    await _submitRecord(tester);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('nfc-write-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nfc-write-skip')));
    await tester.pumpAndSettle();

    expect(find.text('Collection test'), findsOneWidget);
    expect(
      find.text('Record added. You can link an NFC tag later.'),
      findsOneWidget,
    );
    expect(albums.created, hasLength(1));
    expect(nfc.repository.createdTags, isEmpty);
    expect(nfc.platform.finishCalls, 1);
  });

  testWidgets('available NFC remains opt-in', (tester) async {
    final albums = _FakeAlbumRepository();
    final nfc = _NfcFixture();

    await tester.pumpWidget(
      _testApp(
        albumRepository: albums,
        nfcAvailability: NfcAvailabilityState.available,
        nfcService: nfc.service,
      ),
    );
    await tester.pumpAndSettle();
    await _enterRequiredRecord(tester);

    await _submitRecord(tester);
    await tester.pumpAndSettle();

    expect(find.text('Collection test'), findsOneWidget);
    expect(albums.created, hasLength(1));
    expect(nfc.platform.pollCalls, 0);
    expect(nfc.repository.createdTags, isEmpty);
  });
}

Future<void> _enterRequiredRecord(WidgetTester tester) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('add-record-title')),
      matching: find.byType(TextFormField),
    ),
    'Blue Train',
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('add-record-artist')),
      matching: find.byType(TextFormField),
    ),
    'John Coltrane',
  );
  tester.testTextInput.hide();
}

Future<void> _submitRecord(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Save'));
}

Widget _testApp({
  IArtistRepository? artistRepository,
  IAlbumRepository? albumRepository,
  IGenreRepository? genreRepository,
  ITrackRepository? trackRepository,
  DiscogsCatalogService? catalogService,
  DiscogsCredentialStore? credentialStore,
  IDiscogsReleaseLinkRepository? releaseLinkRepository,
  NfcAvailabilityState nfcAvailability = NfcAvailabilityState.unsupported,
  NfcService? nfcService,
  String? scannedBarcode,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.addAlbum,
    routes: [
      GoRoute(
        path: AppRoutes.addAlbum,
        builder: (context, state) => const AddRecordScreen(),
      ),
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Collection test'))),
      ),
      GoRoute(
        path: AppRoutes.barcodeScan,
        builder: (context, state) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('fake-barcode-result'),
              onPressed: () => context.pop(scannedBarcode),
              child: const Text('Return barcode'),
            ),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      artistRepositoryProvider.overrideWithValue(
        artistRepository ?? _FakeArtistRepository(),
      ),
      albumRepositoryProvider.overrideWithValue(
        albumRepository ?? _FakeAlbumRepository(),
      ),
      genreRepositoryProvider.overrideWithValue(
        genreRepository ?? _FakeGenreRepository(),
      ),
      trackRepositoryProvider.overrideWithValue(
        trackRepository ?? _FakeTrackRepository(),
      ),
      discogsCatalogServiceProvider.overrideWithValue(
        catalogService ?? _FakeDiscogsCatalogService(),
      ),
      discogsCredentialStoreProvider.overrideWithValue(
        credentialStore ?? _DisconnectedCredentialStore(),
      ),
      discogsReleaseLinkRepositoryProvider.overrideWithValue(
        releaseLinkRepository ?? _FakeDiscogsReleaseLinkRepository(),
      ),
      databaseTransactionRunnerProvider.overrideWithValue(
        _ImmediateTransactionRunner(),
      ),
      nfcAvailabilityProvider.overrideWithValue(AsyncData(nfcAvailability)),
      if (nfcService != null) nfcServiceProvider.overrideWithValue(nfcService),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    ),
  );
}

class _FakeArtistRepository implements IArtistRepository {
  final List<String> names = [];

  @override
  Future<Artist> findOrCreate(String name) async {
    final normalized = name.trim();
    names.add(normalized);
    return Artist(
      id: 'artist-${names.length}',
      name: normalized,
      createdAt: '2026-08-14T00:00:00.000Z',
    );
  }

  @override
  Future<List<Artist>> findAll() async => const [];

  @override
  Future<Artist?> findById(String id) async => null;
}

class _FakeAlbumRepository implements IAlbumRepository {
  final List<Album> created = [];

  @override
  Future<Album> create({
    required String title,
    required String artistId,
    int? releaseYear,
    String? label,
    String? artworkPath,
    DateTime? purchaseDate,
    int? purchasePriceCents,
  }) async {
    final album = Album(
      id: 'album-${created.length + 1}',
      title: title.trim(),
      artistId: artistId.trim(),
      releaseYear: releaseYear,
      label: label,
      artworkPath: artworkPath,
      purchaseDate: purchaseDate?.toUtc().toIso8601String(),
      purchasePriceCents: purchasePriceCents,
      createdAt: '2026-08-14T00:00:00.000Z',
    );
    created.add(album);
    return album;
  }

  @override
  Future<int> delete(String id) async => 0;

  @override
  Future<List<Album>> findAll() async => List.unmodifiable(created);

  @override
  Future<Album?> findById(String id) async {
    for (final album in created) {
      if (album.id == id) return album;
    }
    return null;
  }

  @override
  Future<List<Album>> search(String query) async => findAll();

  @override
  Future<bool> update(Album album) async => false;
}

class _FakeGenreRepository implements IGenreRepository {
  _FakeGenreRepository({List<Genre> initialGenres = const []})
    : genres = List<Genre>.of(initialGenres);

  final List<Genre> genres;
  final List<String> findOrCreateNames = [];
  final Map<String, List<String>> albumAssignments = {};

  @override
  Future<int> delete(String genreId) async {
    final before = genres.length;
    genres.removeWhere((genre) => genre.id == genreId);
    return before - genres.length;
  }

  @override
  Future<List<Genre>> findAll() async => List.unmodifiable(genres);

  @override
  Future<List<Genre>> findByAlbum(String albumId) async {
    final ids = albumAssignments[albumId] ?? const <String>[];
    return genres.where((genre) => ids.contains(genre.id)).toList();
  }

  @override
  Future<Genre?> findById(String id) async {
    for (final genre in genres) {
      if (genre.id == id) return genre;
    }
    return null;
  }

  @override
  Future<Genre?> findByName(String name) async {
    final normalized = name.trim().toLowerCase();
    for (final genre in genres) {
      if (genre.name.toLowerCase() == normalized) return genre;
    }
    return null;
  }

  @override
  Future<Genre> findOrCreate(String name) async {
    final normalized = name.trim();
    findOrCreateNames.add(normalized);
    final existing = await findByName(normalized);
    if (existing != null) return existing;

    final genre = Genre(
      id: 'genre-${genres.length + 1}',
      name: normalized,
      createdAt: '2026-08-14T00:00:00.000Z',
    );
    genres.add(genre);
    return genre;
  }

  @override
  Future<int> removeFromAlbum(String albumId, String genreId) async {
    final ids = albumAssignments[albumId];
    if (ids == null || !ids.remove(genreId)) return 0;
    return 1;
  }

  @override
  Future<void> setAlbumGenres(String albumId, Iterable<String> genreIds) async {
    albumAssignments[albumId] = List<String>.of(genreIds);
  }
}

class _FakeTrackRepository implements ITrackRepository {
  final Map<String, List<TrackDraft>> replacements = {};

  @override
  Future<List<Track>> findByAlbum(String albumId) async => const [];

  @override
  Future<List<Track>> replaceAlbumTracks(
    String albumId,
    Iterable<TrackDraft> tracks,
  ) async {
    replacements[albumId] = List<TrackDraft>.of(tracks);
    return const [];
  }
}

class _FakeDiscogsCatalogService implements DiscogsCatalogService {
  _FakeDiscogsCatalogService({
    this.results = const [],
    this.barcodeResults = const [],
    this.details,
    this.failure,
  });

  List<DiscogsReleaseSearchResult> results;
  List<DiscogsReleaseSearchResult> barcodeResults;
  DiscogsReleaseDetails? details;
  DiscogsFailure? failure;
  final List<String> barcodeLookups = [];

  @override
  Future<List<DiscogsReleaseSearchResult>> searchReleases({
    required String artist,
    required String title,
  }) async {
    final current = failure;
    if (current != null) throw current;
    return results;
  }

  @override
  Future<List<DiscogsReleaseSearchResult>> searchReleasesByBarcode(
    String barcode,
  ) async {
    barcodeLookups.add(barcode);
    final current = failure;
    if (current != null) throw current;
    return barcodeResults;
  }

  @override
  Future<DiscogsCollectionPage> collectionPage({
    required String username,
    required int page,
    int perPage = 100,
  }) async {
    return const DiscogsCollectionPage(
      items: [],
      page: 1,
      pages: 1,
      totalItems: 0,
    );
  }

  @override
  Future<DiscogsReleaseDetails> release(int releaseId) async {
    final current = failure;
    if (current != null) throw current;
    return details ??
        DiscogsReleaseDetails(
          releaseId: releaseId,
          title: 'Release $releaseId',
          artist: 'Artist',
        );
  }

  @override
  Future<Uint8List> downloadArtwork(String url) async {
    final current = failure;
    if (current != null) throw current;
    return Uint8List.fromList([1, 2, 3]);
  }
}

class _ConnectedCredentialStore extends _DisconnectedCredentialStore {
  @override
  Future<DiscogsOAuthCredentials?> readCredentials() async {
    return const DiscogsOAuthCredentials(token: 'token', tokenSecret: 'secret');
  }
}

class _DisconnectedCredentialStore implements DiscogsCredentialStore {
  @override
  Future<void> clearCredentials() async {}

  @override
  Future<void> clearPendingRequestToken() async {}

  @override
  Future<DiscogsOAuthCredentials?> readCredentials() async => null;

  @override
  Future<DiscogsRequestToken?> readPendingRequestToken() async => null;

  @override
  Future<void> writeCredentials(DiscogsOAuthCredentials credentials) async {}

  @override
  Future<void> writePendingRequestToken(DiscogsRequestToken token) async {}
}

class _FakeDiscogsReleaseLinkRepository
    implements IDiscogsReleaseLinkRepository {
  final Map<String, int> links = {};

  @override
  Future<String?> findAlbumIdForRelease(int releaseId) async {
    for (final entry in links.entries) {
      if (entry.value == releaseId) return entry.key;
    }
    return null;
  }

  @override
  Future<int?> findReleaseIdForAlbum(String albumId) async => links[albumId];

  @override
  Future<Set<int>> findAllReleaseIds() async => links.values.toSet();

  @override
  Future<void> link({required String albumId, required int releaseId}) async {
    links[albumId] = releaseId;
  }
}

class _ImmediateTransactionRunner implements DatabaseTransactionRunner {
  @override
  Future<T> run<T>(Future<T> Function() operation) => operation();
}

class _NfcFixture {
  _NfcFixture({
    List<NfcPlatformTag> tags = const [
      NfcPlatformTag(
        identifier: '04:A7:39:2B:91:61:80',
        ndefAvailable: true,
        ndefWritable: true,
      ),
    ],
    bool holdPoll = false,
  }) : platform = _QueuedNfcPlatform(tags: tags, holdPoll: holdPoll),
       repository = _FakeNfcTagRepository() {
    service = NfcService(platform: platform, repository: repository);
  }

  final _QueuedNfcPlatform platform;
  final _FakeNfcTagRepository repository;
  late final NfcService service;
}

class _QueuedNfcPlatform implements INfcPlatformAdapter {
  _QueuedNfcPlatform({
    required List<NfcPlatformTag> tags,
    required this.holdPoll,
  }) : _tags = List<NfcPlatformTag>.of(tags);

  final List<NfcPlatformTag> _tags;
  final bool holdPoll;
  final List<Uri> writtenUris = [];
  int pollCalls = 0;
  int finishCalls = 0;
  Completer<NfcPlatformTag>? _pendingPoll;

  @override
  Future<NfcAvailabilityState> availability() async {
    return NfcAvailabilityState.available;
  }

  @override
  Future<NfcPlatformTag> poll({required Duration timeout}) {
    pollCalls += 1;
    if (_tags.isNotEmpty) return Future.value(_tags.removeAt(0));
    if (!holdPoll) throw StateError('No fake NFC tag is queued.');
    _pendingPoll = Completer<NfcPlatformTag>();
    return _pendingPoll!.future;
  }

  @override
  Future<void> writeUri(Uri uri) async => writtenUris.add(uri);

  @override
  Future<void> finish() async {
    finishCalls += 1;
    final pendingPoll = _pendingPoll;
    if (pendingPoll != null && !pendingPoll.isCompleted) {
      pendingPoll.completeError(
        PlatformException(code: 'cancelled', message: 'cancelled'),
      );
    }
  }
}

class _FakeNfcTagRepository implements INfcTagRepository {
  final List<NfcTag> createdTags = [];

  @override
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) async {
    final tag = NfcTag(
      id: 'nfc-${createdTags.length + 1}',
      albumId: albumId,
      nfcTagId: nfcTagId,
      writtenAt: (writtenAt ?? DateTime.utc(2026, 9, 2)).toIso8601String(),
    );
    createdTags.add(tag);
    return tag;
  }

  @override
  Future<int> delete(String id) async {
    final previousLength = createdTags.length;
    createdTags.removeWhere((tag) => tag.id == id);
    return previousLength - createdTags.length;
  }

  @override
  Future<NfcTag?> findByAlbum(String albumId) async {
    for (final tag in createdTags) {
      if (tag.albumId == albumId) return tag;
    }
    return null;
  }

  @override
  Future<NfcTag?> findByTagId(String nfcTagId) async {
    for (final tag in createdTags) {
      if (tag.nfcTagId == nfcTagId) return tag;
    }
    return null;
  }
}

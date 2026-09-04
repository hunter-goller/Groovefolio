import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/screens/edit_album_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/record_write_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';
import 'package:vinyl_app/widgets/shared/artwork_picker.dart';

void main() {
  testWidgets('prefills album artist and assigned genres', (tester) async {
    final genres = _FakeGenreRepository();
    genres.albumAssignments['album-1'] = ['genre-jazz', 'genre-hard-bop'];

    await tester.pumpWidget(_testApp(genreRepository: genres));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'edit-record-title'), 'Blue Train');
    expect(_fieldText(tester, 'edit-record-artist'), 'John Coltrane');
    expect(_fieldText(tester, 'edit-record-year'), '1957');
    expect(_fieldText(tester, 'edit-record-label'), 'Blue Note');
    expect(find.text('Jazz'), findsOneWidget);
    expect(find.text('Hard Bop'), findsOneWidget);
    expect(find.byType(ArtworkPicker), findsOneWidget);
    expect(find.byKey(const Key('edit-record-artwork')), findsOneWidget);
  });

  testWidgets('editing only title preserves other album fields and genres', (
    tester,
  ) async {
    final albums = _FakeAlbumRepository();
    final genres = _FakeGenreRepository();
    genres.albumAssignments['album-1'] = ['genre-jazz', 'genre-hard-bop'];

    await tester.pumpWidget(
      _testApp(albumRepository: albums, genreRepository: genres),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('edit-record-title')),
        matching: find.byType(TextFormField),
      ),
      'Blue Train Deluxe',
    );

    await tester.ensureVisible(find.byKey(const Key('edit-record-save')));
    await tester.tap(find.byKey(const Key('edit-record-save')));
    await tester.pumpAndSettle();

    final updated = albums.updated.single;
    expect(updated.title, 'Blue Train Deluxe');
    expect(updated.artistId, 'artist-1');
    expect(updated.releaseYear, 1957);
    expect(updated.label, 'Blue Note');
    expect(updated.artworkPath, '/tmp/cover.jpg');
    expect(updated.purchaseDate, '2025-12-01T00:00:00.000Z');
    expect(updated.purchasePriceCents, 2499);
    expect(updated.createdAt, '2026-01-01T00:00:00.000Z');
    expect(genres.albumAssignments['album-1'], [
      'genre-jazz',
      'genre-hard-bop',
    ]);
    expect(find.text('Detail test'), findsOneWidget);
  });

  testWidgets('requires title and artist in edit mode', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('edit-record-title')),
        matching: find.byType(TextFormField),
      ),
      '',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('edit-record-artist')),
        matching: find.byType(TextFormField),
      ),
      '',
    );

    await tester.ensureVisible(find.byKey(const Key('edit-record-save')));
    await tester.tap(find.byKey(const Key('edit-record-save')));
    await tester.pump();

    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Artist is required'), findsOneWidget);
  });

  testWidgets('shows rewrite NFC option only when a tag is linked', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(hasNfc: true));
    await tester.pumpAndSettle();
    expect(find.text('Rewrite NFC tag'), findsOneWidget);

    await tester.pumpWidget(_testApp(hasNfc: false));
    await tester.pumpAndSettle();
    expect(find.text('Rewrite NFC tag'), findsNothing);
  });
}

String _fieldText(WidgetTester tester, String key) {
  final field = tester.widget<TextFormField>(
    find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextFormField),
    ),
  );
  return field.controller!.text;
}

Widget _testApp({
  IAlbumRepository? albumRepository,
  IArtistRepository? artistRepository,
  IGenreRepository? genreRepository,
  bool hasNfc = false,
}) {
  final router = GoRouter(
    initialLocation: '/album/album-1/edit',
    routes: [
      GoRoute(
        path: AppRoutes.editAlbum,
        builder: (context, state) =>
            EditAlbumScreen(albumId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.albumDetail,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Detail test'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      albumRepositoryProvider.overrideWithValue(
        albumRepository ?? _FakeAlbumRepository(),
      ),
      artistRepositoryProvider.overrideWithValue(
        artistRepository ?? _FakeArtistRepository(),
      ),
      genreRepositoryProvider.overrideWithValue(
        genreRepository ?? _FakeGenreRepository(),
      ),
      playRepositoryProvider.overrideWithValue(_FakePlayRepository()),
      nfcTagRepositoryProvider.overrideWithValue(
        _FakeNfcRepository(hasNfc: hasNfc),
      ),
      trackRepositoryProvider.overrideWithValue(_FakeTrackRepository()),
      discogsReleaseLinkRepositoryProvider.overrideWithValue(
        _FakeReleaseLinkRepository(),
      ),
      databaseTransactionRunnerProvider.overrideWithValue(
        _ImmediateTransactionRunner(),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    ),
  );
}

class _FakeAlbumRepository implements IAlbumRepository {
  final List<Album> updated = [];

  static const album = Album(
    id: 'album-1',
    title: 'Blue Train',
    artistId: 'artist-1',
    releaseYear: 1957,
    label: 'Blue Note',
    artworkPath: '/tmp/cover.jpg',
    purchaseDate: '2025-12-01T00:00:00.000Z',
    purchasePriceCents: 2499,
    createdAt: '2026-01-01T00:00:00.000Z',
  );

  @override
  Future<Album?> findById(String id) async => id == album.id ? album : null;

  @override
  Future<List<Album>> findAll() async => [album];

  @override
  Future<List<Album>> search(String query) async => [album];

  @override
  Future<bool> update(Album album) async {
    updated.add(album);
    return true;
  }

  @override
  Future<Album> create({
    required String title,
    required String artistId,
    int? releaseYear,
    String? label,
    String? artworkPath,
    DateTime? purchaseDate,
    int? purchasePriceCents,
  }) => throw UnimplementedError();

  @override
  Future<int> delete(String id) => throw UnimplementedError();
}

class _FakeArtistRepository implements IArtistRepository {
  static const artist = Artist(
    id: 'artist-1',
    name: 'John Coltrane',
    createdAt: '2025-01-01T00:00:00.000Z',
  );

  @override
  Future<Artist?> findById(String id) async => id == artist.id ? artist : null;

  @override
  Future<List<Artist>> findAll() async => [artist];

  @override
  Future<Artist> findOrCreate(String name) async {
    if (name.trim().toLowerCase() == artist.name.toLowerCase()) return artist;
    return Artist(
      id: 'artist-2',
      name: name.trim(),
      createdAt: '2026-08-15T00:00:00.000Z',
    );
  }
}

class _FakeGenreRepository implements IGenreRepository {
  _FakeGenreRepository();

  final genres = <Genre>[
    const Genre(
      id: 'genre-jazz',
      name: 'Jazz',
      createdAt: '2025-01-01T00:00:00.000Z',
    ),
    const Genre(
      id: 'genre-hard-bop',
      name: 'Hard Bop',
      createdAt: '2025-01-01T00:00:00.000Z',
    ),
  ];
  final Map<String, List<String>> albumAssignments = {};

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
    for (final genre in genres) {
      if (genre.name.toLowerCase() == name.trim().toLowerCase()) return genre;
    }
    return null;
  }

  @override
  Future<Genre> findOrCreate(String name) async {
    final existing = await findByName(name);
    if (existing != null) return existing;
    final genre = Genre(
      id: 'genre-${genres.length + 1}',
      name: name.trim(),
      createdAt: '2026-08-15T00:00:00.000Z',
    );
    genres.add(genre);
    return genre;
  }

  @override
  Future<void> setAlbumGenres(String albumId, Iterable<String> genreIds) async {
    albumAssignments[albumId] = List.of(genreIds);
  }

  @override
  Future<int> removeFromAlbum(String albumId, String genreId) async => 0;

  @override
  Future<int> delete(String genreId) async => 0;
}

class _FakePlayRepository implements IPlayRepository {
  @override
  Future<List<Play>> findAll() async => const [];

  @override
  Future<List<Play>> findByAlbum(String albumId) async => const [];

  @override
  Future<int> getPlayCountByAlbum(String albumId) async => 0;

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async => const [];

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) => throw UnimplementedError();

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();
}

class _FakeNfcRepository implements INfcTagRepository {
  const _FakeNfcRepository({required this.hasNfc});

  final bool hasNfc;

  @override
  Future<NfcTag?> findByAlbum(String albumId) async => hasNfc
      ? const NfcTag(
          id: 'nfc-1',
          albumId: 'album-1',
          nfcTagId: 'tag-1',
          writtenAt: '2026-08-15T00:00:00.000Z',
        )
      : null;

  @override
  Future<NfcTag?> findByTagId(String nfcTagId) async => null;

  @override
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) => throw UnimplementedError();

  @override
  Future<NfcTag> replaceForAlbum({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) => throw UnimplementedError();

  @override
  Future<int> delete(String id) => throw UnimplementedError();
}

class _FakeTrackRepository implements ITrackRepository {
  @override
  Future<List<Track>> findByAlbum(String albumId) async => const [];

  @override
  Future<List<Track>> replaceAlbumTracks(
    String albumId,
    Iterable<TrackDraft> tracks,
  ) async => const [];
}

class _FakeReleaseLinkRepository implements IDiscogsReleaseLinkRepository {
  @override
  Future<Set<int>> findAllReleaseIds() async => const {};

  @override
  Future<String?> findAlbumIdForRelease(int releaseId) async => null;

  @override
  Future<int?> findReleaseIdForAlbum(String albumId) async => null;

  @override
  Future<void> link({required String albumId, required int releaseId}) async {}
}

class _ImmediateTransactionRunner implements DatabaseTransactionRunner {
  @override
  Future<T> run<T>(Future<T> Function() operation) => operation();
}

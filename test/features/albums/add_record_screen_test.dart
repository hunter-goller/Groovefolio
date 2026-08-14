import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/albums/screens/add_record_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
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
}

Widget _testApp({
  IArtistRepository? artistRepository,
  IAlbumRepository? albumRepository,
  IGenreRepository? genreRepository,
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

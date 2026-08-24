import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  testWidgets('manual selection logs a play and returns to Collection', (
    tester,
  ) async {
    const artist = Artist(
      id: 'artist-1',
      name: 'John Coltrane',
      createdAt: '2026-08-14T00:00:00.000Z',
    );
    const album = Album(
      id: 'album-1',
      title: 'Blue Train',
      artistId: 'artist-1',
      releaseYear: 1957,
      createdAt: '2026-08-14T00:00:00.000Z',
    );

    final playRepository = _FakePlayRepository();
    final router = GoRouter(
      initialLocation: AppRoutes.logPlay,
      routes: [
        GoRoute(
          path: AppRoutes.logPlay,
          builder: (context, state) => const LogPlayScreen(),
        ),
        GoRoute(
          path: AppRoutes.collection,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Collection test'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(
            _FakeAlbumRepository(album),
          ),
          artistRepositoryProvider.overrideWithValue(
            _FakeArtistRepository(artist),
          ),
          playRepositoryProvider.overrideWithValue(playRepository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('NFC'), findsNothing);
    expect(find.text('Blue Train'), findsOneWidget);
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Blue Train'));
    await tester.tap(find.text('Blue Train'));
    await tester.pump();
    await tester.ensureVisible(find.text('Side A'));
    await tester.tap(find.text('Side A'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Save play'));
    await tester.tap(find.text('Save play'));
    await tester.pumpAndSettle();

    expect(playRepository.plays, hasLength(1));
    expect(playRepository.plays.single.albumId, album.id);
    expect(playRepository.plays.single.sidePlayed, SidePlayed.sideA);
    expect(find.text('Collection test'), findsOneWidget);
  });
}

class _FakeAlbumRepository implements IAlbumRepository {
  _FakeAlbumRepository(this.album);

  final Album album;

  @override
  Future<List<Album>> findAll() async => [album];

  @override
  Future<Album?> findById(String id) async => id == album.id ? album : null;

  @override
  Future<List<Album>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    return album.title.toLowerCase().contains(normalized) ? [album] : [];
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

  @override
  Future<bool> update(Album album) => throw UnimplementedError();
}

class _FakeArtistRepository implements IArtistRepository {
  _FakeArtistRepository(this.artist);

  final Artist artist;

  @override
  Future<List<Artist>> findAll() async => [artist];

  @override
  Future<Artist?> findById(String id) async => id == artist.id ? artist : null;

  @override
  Future<Artist> findOrCreate(String name) => throw UnimplementedError();
}

class _FakePlayRepository implements IPlayRepository {
  final List<Play> plays = [];

  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) async {
    final play = Play(
      id: 'play-${plays.length + 1}',
      albumId: albumId,
      playedAt: playedAt.toUtc().toIso8601String(),
      sidePlayed: sidePlayed,
      createdAt: '2026-08-14T00:00:00.000Z',
    );
    plays.add(play);
    return play;
  }

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();

  @override
  Future<List<Play>> findAll() async => List.unmodifiable(plays);

  @override
  Future<List<Play>> findByAlbum(String albumId) async {
    return plays.where((play) => play.albumId == albumId).toList();
  }

  @override
  Future<int> getPlayCountByAlbum(String albumId) async {
    return plays.where((play) => play.albumId == albumId).length;
  }

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) async => const [];
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/settings/screens/fake_nfc_tap_screen.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_play_logging_service.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/services/play_logging_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  testWidgets('fake tap logs through the NFC and normal play services', (
    tester,
  ) async {
    final albumRepository = _FakeAlbumRepository();
    final artistRepository = _FakeArtistRepository();
    final playRepository = _FakePlayRepository();
    final playLoggingService = PlayLoggingService(
      albumRepository: albumRepository,
      playRepository: playRepository,
    );
    final nfcPlayLoggingService = NfcPlayLoggingService(
      nfcService: const _UnusedNfcScanner(),
      playLogger: PlayLoggingNfcAdapter(playLoggingService),
      now: () => DateTime.utc(2026, 9, 7, 12),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(albumRepository),
          artistRepositoryProvider.overrideWithValue(artistRepository),
          playRepositoryProvider.overrideWithValue(playRepository),
          nfcPlayLoggingServiceProvider.overrideWithValue(
            nfcPlayLoggingService,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FakeNfcTapScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final albumTile = find.byKey(const Key('fake-nfc-album-album-1'));
    expect(albumTile, findsOneWidget);

    await tester.tap(albumTile);
    await tester.pumpAndSettle();

    expect(playRepository.plays, hasLength(1));
    expect(playRepository.plays.single.albumId, 'album-1');
    expect(playRepository.plays.single.sidePlayed, SidePlayed.full);
    expect(find.text('Play logged: Blue Train'), findsOneWidget);

    await tester.tap(albumTile);
    await tester.pumpAndSettle();

    expect(playRepository.plays, hasLength(1));
    expect(find.text('Blue Train is already logged.'), findsOneWidget);
  });
}

class _FakeAlbumRepository implements IAlbumRepository {
  static const album = Album(
    id: 'album-1',
    title: 'Blue Train',
    artistId: 'artist-1',
    releaseYear: 1957,
    createdAt: '2026-09-07T00:00:00.000Z',
  );

  @override
  Future<List<Album>> findAll() async => const [album];

  @override
  Future<Album?> findById(String id) async => id == album.id ? album : null;

  @override
  Future<List<Album>> search(String query) async => const [album];

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
  static const artist = Artist(
    id: 'artist-1',
    name: 'John Coltrane',
    createdAt: '2026-09-07T00:00:00.000Z',
  );

  @override
  Future<List<Artist>> findAll() async => const [artist];

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
      createdAt: playedAt.toUtc().toIso8601String(),
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

class _UnusedNfcScanner implements INfcAlbumScanner {
  const _UnusedNfcScanner();

  @override
  Stream<String> startScan({Duration timeout = const Duration(seconds: 20)}) {
    throw UnimplementedError();
  }
}

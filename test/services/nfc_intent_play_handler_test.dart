import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/services/nfc/nfc_intent_play_handler.dart';
import 'package:vinyl_app/services/nfc/nfc_play_logging_service.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test('valid album intent resolves locally and logs a full play', () async {
    final fixture = _Fixture();

    final result = await fixture.handler.handle(
      Uri.parse('groovefolio://album/album-1'),
    );

    expect(result?.album, _FakeAlbumRepository.album);
    expect(result?.play?.id, 'play-1');
    expect(result?.suppressed, isFalse);
    expect(fixture.albumRepository.findCalls, 1);
    expect(fixture.playLogger.calls, 1);
    expect(fixture.playLogger.lastSide, SidePlayed.full);
  });

  test('unsafe album intent is ignored before repository access', () async {
    final fixture = _Fixture();

    final result = await fixture.handler.handle(
      Uri.parse('groovefolio://album/album-1?source=other-app'),
    );

    expect(result, isNull);
    expect(fixture.albumRepository.findCalls, 0);
    expect(fixture.playLogger.calls, 0);
  });

  test('deleted album intent fails without inserting a play', () async {
    final fixture = _Fixture(albumExists: false);

    await expectLater(
      fixture.handler.handle(Uri.parse('groovefolio://album/album-1')),
      throwsStateError,
    );

    expect(fixture.albumRepository.findCalls, 1);
    expect(fixture.playLogger.calls, 0);
  });

  test(
    'foreground NFC operation suppresses automatic intent logging',
    () async {
      final fixture = _Fixture(suppressAutomaticIntent: true);

      final result = await fixture.handler.handle(
        Uri.parse('groovefolio://album/album-1'),
      );

      expect(result, isNull);
      expect(fixture.albumRepository.findCalls, 0);
      expect(fixture.playLogger.calls, 0);
    },
  );
}

class _Fixture {
  _Fixture({bool albumExists = true, bool suppressAutomaticIntent = false})
    : albumRepository = _FakeAlbumRepository(albumExists: albumExists),
      playLogger = _FakePlayLogger() {
    handler = NfcIntentPlayHandler(
      NfcPlayLoggingService(
        nfcService: const _UnusedNfcScanner(),
        playLogger: playLogger,
        now: () => DateTime.utc(2026, 9, 8, 12),
        elapsed: () => Duration.zero,
      ),
      albumRepository,
      () => suppressAutomaticIntent,
    );
  }

  final _FakeAlbumRepository albumRepository;
  final _FakePlayLogger playLogger;
  late final NfcIntentPlayHandler handler;
}

class _FakeAlbumRepository implements IAlbumRepository {
  _FakeAlbumRepository({required this.albumExists});

  static const album = Album(
    id: 'album-1',
    title: 'Blue Train',
    artistId: 'artist-1',
    releaseYear: 1957,
    createdAt: '2026-09-08T00:00:00.000Z',
  );

  final bool albumExists;
  int findCalls = 0;

  @override
  Future<Album?> findById(String id) async {
    findCalls += 1;
    return albumExists && id == album.id ? album : null;
  }

  @override
  Future<List<Album>> findAll() => throw UnimplementedError();

  @override
  Future<List<Album>> search(String query) => throw UnimplementedError();

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

class _FakePlayLogger implements INfcPlayLogger {
  int calls = 0;
  SidePlayed? lastSide;

  @override
  Future<Play> logPlay(
    String albumId,
    DateTime playedAt,
    SidePlayed side,
  ) async {
    calls += 1;
    lastSide = side;
    return Play(
      id: 'play-$calls',
      albumId: albumId,
      playedAt: playedAt.toUtc().toIso8601String(),
      sidePlayed: side,
      createdAt: playedAt.toUtc().toIso8601String(),
    );
  }
}

class _UnusedNfcScanner implements INfcAlbumScanner {
  const _UnusedNfcScanner();

  @override
  Stream<String> startScan({Duration timeout = const Duration(seconds: 20)}) {
    throw UnimplementedError();
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_intent_play_handler.dart';
import 'package:vinyl_app/services/nfc/nfc_play_logging_service.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test(
    'same tag is delivered again after cooldown without restarting',
    () async {
      final uris = StreamController<Uri>();
      final container = ProviderContainer(
        overrides: [
          incomingAppLinkStreamProvider.overrideWithValue(uris.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await uris.close();
      });
      final fixture = _Fixture();
      final pending = <Future<NfcIntentPlayResult?>>[];
      container.listen(discogsIncomingUriProvider, (previous, next) {
        next.whenData((uri) => pending.add(fixture.handler.handle(uri)));
      });
      await container.pump();
      final uri = Uri.parse('groovefolio://album/album-1');
      for (final seconds in [0, 1, 6]) {
        fixture.elapsed = Duration(seconds: seconds);
        uris.add(uri);
        await Future<void>.delayed(Duration.zero);
        await container.pump();
        await Future.wait(pending);
      }
      expect(pending, hasLength(3));
      final results = await Future.wait(pending);
      expect(results.map((result) => result?.suppressed), [false, true, false]);
      expect(fixture.playLogger.calls, 2);
    },
  );
  test(
    'opening a write interaction during album resolution prevents insertion',
    () async {
      final resolution = Completer<Album?>();
      final repository = _FakeAlbumRepository(
        albumExists: true,
        resolution: resolution,
      );
      final playLogger = _FakePlayLogger();
      var protected = false;
      final handler = NfcIntentPlayHandler(
        NfcPlayLoggingService(
          nfcService: const _UnusedNfcScanner(),
          playLogger: playLogger,
        ),
        repository,
        () => protected,
      );
      final pending = handler.handle(Uri.parse('groovefolio://album/album-1'));
      expect(repository.findCalls, 1);
      protected = true;
      resolution.complete(_FakeAlbumRepository.album);
      expect(await pending, isNull);
      expect(playLogger.calls, 0);
    },
  );
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
        elapsed: () => elapsed,
      ),
      albumRepository,
      () => suppressAutomaticIntent,
    );
  }

  final _FakeAlbumRepository albumRepository;
  final _FakePlayLogger playLogger;
  late final NfcIntentPlayHandler handler;
  Duration elapsed = Duration.zero;
}

class _FakeAlbumRepository implements IAlbumRepository {
  _FakeAlbumRepository({required this.albumExists, this.resolution});

  static const album = Album(
    id: 'album-1',
    title: 'Blue Train',
    artistId: 'artist-1',
    releaseYear: 1957,
    createdAt: '2026-09-08T00:00:00.000Z',
  );

  final bool albumExists;
  final Completer<Album?>? resolution;
  int findCalls = 0;

  @override
  Future<Album?> findById(String id) async {
    findCalls += 1;
    if (resolution != null) return resolution!.future;
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

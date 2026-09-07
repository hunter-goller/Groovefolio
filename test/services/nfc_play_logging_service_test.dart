import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/services/nfc/nfc_play_logging_service.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test('logs a resolved NFC scan as one full-side play', () async {
    final nfc = _FakeNfcScanner('album-1');
    final logger = _FakePlayLogger();
    final service = NfcPlayLoggingService(
      nfcService: nfc,
      playLogger: logger,
      now: () => DateTime.utc(2026, 9, 6, 16, 0),
    );

    final result = await service.logNextScan();

    expect(result.suppressed, isFalse);
    expect(result.albumId, 'album-1');
    expect(result.play?.albumId, 'album-1');
    expect(logger.calls, 1);
    expect(logger.lastSide, SidePlayed.full);
  });

  test('suppresses a duplicate NFC scan inside the cooldown window', () async {
    final nfc = _FakeNfcScanner('album-1');
    final logger = _FakePlayLogger();
    var now = DateTime.utc(2026, 9, 6, 16, 0);
    final service = NfcPlayLoggingService(
      nfcService: nfc,
      playLogger: logger,
      now: () => now,
      duplicateWindow: const Duration(seconds: 5),
    );

    await service.logNextScan();
    now = now.add(const Duration(seconds: 2));
    final result = await service.logNextScan();

    expect(result.suppressed, isTrue);
    expect(result.albumId, 'album-1');
    expect(logger.calls, 1);
  });

  test('allows a later NFC scan after the cooldown window', () async {
    final nfc = _FakeNfcScanner('album-1');
    final logger = _FakePlayLogger();
    var now = DateTime.utc(2026, 9, 6, 16, 0);
    final service = NfcPlayLoggingService(
      nfcService: nfc,
      playLogger: logger,
      now: () => now,
    );

    await service.logNextScan();
    now = now.add(const Duration(seconds: 6));
    final result = await service.logNextScan();

    expect(result.suppressed, isFalse);
    expect(logger.calls, 2);
  });

  test('different albums are not treated as duplicates', () async {
    final nfc = _SequenceNfcScanner(['album-1', 'album-2']);
    final logger = _FakePlayLogger();
    final service = NfcPlayLoggingService(
      nfcService: nfc,
      playLogger: logger,
      now: () => DateTime.utc(2026, 9, 6, 16, 0),
    );

    final first = await service.logNextScan();
    final second = await service.logNextScan();

    expect(first.suppressed, isFalse);
    expect(second.suppressed, isFalse);
    expect(logger.calls, 2);
  });

  test(
    'suppresses an overlapping callback while the first write is pending',
    () async {
      final nfc = _FakeNfcScanner('album-1');
      final logger = _CompletingPlayLogger();
      final service = NfcPlayLoggingService(
        nfcService: nfc,
        playLogger: logger,
        now: () => DateTime.utc(2026, 9, 6, 16),
      );

      final first = service.logResolvedAlbum('album-1');
      final duplicate = await service.logResolvedAlbum('album-1');

      expect(duplicate.suppressed, isTrue);
      expect(logger.calls, 1);

      logger.complete();
      expect((await first).suppressed, isFalse);
    },
  );

  test('a failed write does not block an immediate retry', () async {
    final nfc = _FakeNfcScanner('album-1');
    final logger = _FailingOncePlayLogger();
    final service = NfcPlayLoggingService(
      nfcService: nfc,
      playLogger: logger,
      now: () => DateTime.utc(2026, 9, 6, 16),
    );

    await expectLater(service.logResolvedAlbum('album-1'), throwsStateError);
    final retry = await service.logResolvedAlbum('album-1');

    expect(retry.suppressed, isFalse);
    expect(logger.calls, 2);
  });
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

class _FakeNfcScanner implements INfcAlbumScanner {
  _FakeNfcScanner(this.albumId);

  final String albumId;

  @override
  Stream<String> startScan({
    Duration timeout = const Duration(seconds: 20),
  }) async* {
    yield albumId;
  }
}

class _SequenceNfcScanner implements INfcAlbumScanner {
  _SequenceNfcScanner(this.albumIds);

  final List<String> albumIds;
  int index = 0;

  @override
  Stream<String> startScan({
    Duration timeout = const Duration(seconds: 20),
  }) async* {
    yield albumIds[index++];
  }
}

class _CompletingPlayLogger implements INfcPlayLogger {
  final _completer = Completer<Play>();
  int calls = 0;

  @override
  Future<Play> logPlay(String albumId, DateTime playedAt, SidePlayed side) {
    calls += 1;
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      Play(
        id: 'play-1',
        albumId: 'album-1',
        playedAt: DateTime.utc(2026, 9, 6, 16).toIso8601String(),
        sidePlayed: SidePlayed.full,
        createdAt: DateTime.utc(2026, 9, 6, 16).toIso8601String(),
      ),
    );
  }
}

class _FailingOncePlayLogger implements INfcPlayLogger {
  int calls = 0;

  @override
  Future<Play> logPlay(
    String albumId,
    DateTime playedAt,
    SidePlayed side,
  ) async {
    calls += 1;
    if (calls == 1) throw StateError('write failed');
    return Play(
      id: 'play-$calls',
      albumId: albumId,
      playedAt: playedAt.toUtc().toIso8601String(),
      sidePlayed: side,
      createdAt: playedAt.toUtc().toIso8601String(),
    );
  }
}

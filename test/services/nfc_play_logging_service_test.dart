import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/services/nfc/nfc_play_logging_service.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  test('logs a resolved NFC scan as one full-side play', () async {
    final nfc = _FakeNfcService('album-1');
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
    final nfc = _FakeNfcService('album-1');
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
    final nfc = _FakeNfcService('album-1');
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
    final nfc = _SequenceNfcService(['album-1', 'album-2']);
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

class _FakeNfcService extends NfcService {
  _FakeNfcService(this.albumId)
    : super(
        platform: throw UnimplementedError(),
        repository: throw UnimplementedError(),
      );

  final String albumId;

  @override
  Stream<String> startScan({Duration timeout = const Duration(seconds: 20)}) async* {
    yield albumId;
  }
}

class _SequenceNfcService extends NfcService {
  _SequenceNfcService(this.albumIds)
    : super(
        platform: throw UnimplementedError(),
        repository: throw UnimplementedError(),
      );

  final List<String> albumIds;
  int index = 0;

  @override
  Stream<String> startScan({Duration timeout = const Duration(seconds: 20)}) async* {
    yield albumIds[index++];
  }
}

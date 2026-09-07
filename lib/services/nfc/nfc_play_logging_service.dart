import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/services/play_logging_service.dart';
import 'package:vinyl_app/types/side_played.dart';

/// The result of handling one NFC scan.
class NfcPlayLogResult {
  const NfcPlayLogResult.logged(this.play)
    : suppressed = false,
      albumId = play.albumId;

  const NfcPlayLogResult.suppressed(this.albumId)
    : play = null,
      suppressed = true;

  final Play? play;
  final String albumId;
  final bool suppressed;
}

/// Small boundary around play logging so the NFC workflow can be tested
/// without constructing a database-backed PlayLoggingService.
abstract interface class INfcPlayLogger {
  Future<Play> logPlay(String albumId, DateTime playedAt, SidePlayed side);
}

class PlayLoggingNfcAdapter implements INfcPlayLogger {
  const PlayLoggingNfcAdapter(this._service);

  final PlayLoggingService _service;

  @override
  Future<Play> logPlay(String albumId, DateTime playedAt, SidePlayed side) =>
      _service.logPlay(albumId, playedAt, side);
}

/// Converts one resolved NFC album scan into exactly one play-log operation.
///
/// NFC scanning itself stays in [NfcService]. This class deliberately reuses
/// the normal play-logging service so NFC plays behave exactly like manually
/// logged plays and immediately participate in stats/recommendations.
///
/// A short per-album cooldown protects against duplicate callbacks caused by
/// a tag being held against the phone. The cooldown is intentionally in-memory;
/// it is a duplicate-event guard, not a persistent play-history rule.
class NfcPlayLoggingService {
  NfcPlayLoggingService({
    required INfcAlbumScanner nfcService,
    required INfcPlayLogger playLogger,
    DateTime Function()? now,
    this.duplicateWindow = const Duration(seconds: 5),
  }) : _nfcService = nfcService,
       _playLogger = playLogger,
       _now = now ?? DateTime.now;

  final INfcAlbumScanner _nfcService;
  final INfcPlayLogger _playLogger;
  final DateTime Function() _now;
  final Duration duplicateWindow;

  final Map<String, DateTime> _lastLoggedAt = {};

  /// Waits for one NFC scan, resolves it to an album, and logs one full-side
  /// play. A duplicate scan within [duplicateWindow] is acknowledged without
  /// creating another play row.
  Future<NfcPlayLogResult> logNextScan({
    DateTime? playedAt,
    SidePlayed side = SidePlayed.full,
  }) async {
    final albumId = await _nfcService.startScan().single;
    return logResolvedAlbum(albumId, playedAt: playedAt, side: side);
  }

  /// Logs a play for an album already resolved from an NFC URI/intent.
  ///
  /// This is used for Android NDEF intents, where the NFC payload contains the
  /// Groovefolio album URI and Android delivers it directly to the app instead
  /// of requiring a foreground NFC polling session.
  Future<NfcPlayLogResult> logResolvedAlbum(
    String albumId, {
    DateTime? playedAt,
    SidePlayed side = SidePlayed.full,
  }) async {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) {
      throw StateError('NFC scan resolved to an empty album ID.');
    }

    final timestamp = playedAt ?? _now();
    final previous = _lastLoggedAt[normalizedAlbumId];
    if (previous != null &&
        timestamp.difference(previous).abs() < duplicateWindow) {
      return NfcPlayLogResult.suppressed(normalizedAlbumId);
    }

    // Reserve the cooldown before awaiting persistence so overlapping Android
    // callbacks for the same tag cannot both create a play.
    _lastLoggedAt[normalizedAlbumId] = timestamp;
    try {
      final play = await _playLogger.logPlay(
        normalizedAlbumId,
        timestamp,
        side,
      );
      return NfcPlayLogResult.logged(play);
    } on Object {
      // A failed write must not prevent an immediate retry. Only remove this
      // attempt if a newer callback has not replaced its timestamp.
      if (_lastLoggedAt[normalizedAlbumId] == timestamp) {
        _lastLoggedAt.remove(normalizedAlbumId);
      }
      rethrow;
    }
  }

  /// Clears the in-memory duplicate guard. Useful after an explicit user
  /// action or when a new app session wants a clean scan window.
  void resetDuplicateGuard() => _lastLoggedAt.clear();
}

final nfcPlayLoggingServiceProvider = Provider<NfcPlayLoggingService>((ref) {
  return NfcPlayLoggingService(
    nfcService: ref.watch(nfcServiceProvider),
    playLogger: PlayLoggingNfcAdapter(ref.watch(playLoggingServiceProvider)),
  );
});

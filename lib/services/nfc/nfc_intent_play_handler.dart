import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_play_logging_service.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';

class NfcIntentPlayResult {
  const NfcIntentPlayResult.logged({required this.album, required this.play})
    : suppressed = false;

  const NfcIntentPlayResult.suppressed({required this.album})
    : play = null,
      suppressed = true;

  final Album album;
  final Play? play;
  final bool suppressed;
}

/// Handles Groovefolio NFC URI intents delivered by Android, including when
/// the app was launched from a terminated state.
///
/// The Android manifest routes `groovefolio://album/{id}` NFC NDEF records to
/// the app. This handler turns that URI into the same play-log workflow used
/// by foreground NFC scanning.
class NfcIntentPlayHandler {
  NfcIntentPlayHandler(
    this._playLogging,
    this._albumRepository,
    this._shouldSuppressAutomaticIntent,
  );

  final NfcPlayLoggingService _playLogging;
  final IAlbumRepository _albumRepository;
  final bool Function() _shouldSuppressAutomaticIntent;

  Future<NfcIntentPlayResult?> handle(Uri uri) async {
    if (_shouldSuppressAutomaticIntent()) return null;

    final albumId = albumIdFromNfcUri(uri);
    if (albumId == null) return null;

    final album = await _albumRepository.findById(albumId);
    // A linking dialog may have opened while album resolution was awaiting.
    if (_shouldSuppressAutomaticIntent()) return null;
    if (album == null) {
      throw StateError('The NFC tag points to an album that no longer exists.');
    }

    final result = await _playLogging.logResolvedAlbum(
      albumId,
      playedAt: DateTime.now(),
    );

    if (result.suppressed) {
      return NfcIntentPlayResult.suppressed(album: album);
    }
    return NfcIntentPlayResult.logged(album: album, play: result.play!);
  }
}

final nfcIntentPlayHandlerProvider = Provider<NfcIntentPlayHandler>((ref) {
  final nfcService = ref.watch(nfcServiceProvider);
  return NfcIntentPlayHandler(
    ref.watch(nfcPlayLoggingServiceProvider),
    ref.watch(albumRepositoryProvider),
    () => nfcService.shouldSuppressAutomaticIntent,
  );
});

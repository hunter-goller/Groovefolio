import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/services/nfc/nfc_play_logging_service.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';

class NfcIntentPlayResult {
  const NfcIntentPlayResult.logged({required this.album})
    : suppressed = false;

  const NfcIntentPlayResult.suppressed({required this.album})
    : suppressed = true;

  final Album album;
  final bool suppressed;
}

/// Handles Groovefolio NFC URI intents delivered by Android, including when
/// the app was launched from a terminated state.
///
/// The Android manifest already routes `groovefolio://album/{id}` NFC NDEF
/// records to the app. This handler turns that URI into the same play-log
/// workflow used by foreground NFC scanning.
class NfcIntentPlayHandler {
  NfcIntentPlayHandler({
    required NfcPlayLoggingService playLogging,
    required IAlbumRepository albumRepository,
  }) : _playLogging = playLogging,
       _albumRepository = albumRepository;

  final NfcPlayLoggingService _playLogging;
  final IAlbumRepository _albumRepository;

  Future<NfcIntentPlayResult?> handle(Uri uri) async {
    final albumId = albumIdFromNfcUri(uri);
    if (albumId == null) return null;

    final album = await _albumRepository.findById(albumId);
    if (album == null) {
      throw StateError('The NFC tag points to an album that no longer exists.');
    }

    // The URI itself has already resolved the physical tag to an album. The
    // play logger accepts the resolved album ID through the normal workflow.
    final result = await _playLogging.logResolvedAlbum(
      albumId,
      playedAt: DateTime.now(),
    );

    if (result.suppressed) {
      return NfcIntentPlayResult.suppressed(album: album);
    }
    return NfcIntentPlayResult.logged(album: album);
  }
}

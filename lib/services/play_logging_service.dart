import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/types/side_played.dart';

part 'play_logging_service.g.dart';

/// Coordinates the business workflow for logging a vinyl play.
///
/// The service validates that the target album exists, then delegates play
/// persistence to [IPlayRepository]. Last-played state is derived from the
/// Plays table, so logging a play does not mutate the Album row.
class PlayLoggingService {
  PlayLoggingService({
    required this._albumRepository,
    required this._playRepository,
  });

  final IAlbumRepository _albumRepository;
  final IPlayRepository _playRepository;

  /// Logs exactly one play for [albumId].
  ///
  /// NFC flows should resolve a tag to an album first and then call this same
  /// method, keeping the play-logging workflow independent of input source.
  Future<Play> logPlay(
    String albumId,
    DateTime playedAt,
    SidePlayed side,
  ) async {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }

    final album = await _albumRepository.findById(normalizedAlbumId);
    if (album == null) {
      throw StateError(
        'Cannot log a play for missing album $normalizedAlbumId.',
      );
    }

    return _playRepository.create(
      albumId: normalizedAlbumId,
      playedAt: playedAt,
      sidePlayed: side,
    );
  }
}

/// Service dependency used by feature providers and UI workflows.
@riverpod
PlayLoggingService playLoggingService(Ref ref) {
  return PlayLoggingService(
    albumRepository: ref.watch(albumRepositoryProvider),
    playRepository: ref.watch(playRepositoryProvider),
  );
}

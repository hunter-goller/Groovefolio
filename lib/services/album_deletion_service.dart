import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';

class AlbumDeletionResult {
  const AlbumDeletionResult({
    required this.deletedPlayCount,
    required this.deletedNfcAssociation,
  });

  final int deletedPlayCount;
  final bool deletedNfcAssociation;
}

/// Canonical album deletion workflow.
///
/// Schema v6 makes Plays, NfcTags, AlbumGenres, Discogs release links, and
/// Tracks cascade from Albums. The database delete is therefore one atomic
/// statement. Artwork is cleaned up only after the DB commit; if filesystem
/// cleanup fails, an orphaned image is safer than deleting artwork for an
/// album that survived a failed database operation.
class AlbumDeletionService {
  const AlbumDeletionService({
    required this._albumRepository,
    required this._playRepository,
    required this._nfcTagRepository,
    required this._artworkStorageService,
  });

  final IAlbumRepository _albumRepository;
  final IPlayRepository _playRepository;
  final INfcTagRepository _nfcTagRepository;
  final ArtworkStorageService _artworkStorageService;

  Future<AlbumDeletionResult> deleteAlbum(String albumId) async {
    final normalizedId = albumId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }

    final album = await _albumRepository.findById(normalizedId);
    if (album == null) {
      throw StateError('Record no longer exists.');
    }

    final playsFuture = _playRepository.findByAlbum(normalizedId);
    final nfcFuture = _nfcTagRepository.findByAlbum(normalizedId);
    final plays = await playsFuture;
    final nfcTag = await nfcFuture;

    final deletedAlbum = await _albumRepository.delete(normalizedId);
    if (deletedAlbum != 1) {
      throw StateError('Could not delete record.');
    }

    try {
      await _artworkStorageService.deleteArtwork(album.artworkPath);
    } catch (_) {
      // The database deletion already committed. Leave orphan cleanup for a
      // later maintenance pass rather than reporting the record as undeleted.
    }

    return AlbumDeletionResult(
      deletedPlayCount: plays.length,
      deletedNfcAssociation: nfcTag != null,
    );
  }
}

final albumDeletionServiceProvider = Provider<AlbumDeletionService>((ref) {
  return AlbumDeletionService(
    albumRepository: ref.watch(albumRepositoryProvider),
    playRepository: ref.watch(playRepositoryProvider),
    nfcTagRepository: ref.watch(nfcTagRepositoryProvider),
    artworkStorageService: ref.watch(artworkStorageServiceProvider),
  );
});

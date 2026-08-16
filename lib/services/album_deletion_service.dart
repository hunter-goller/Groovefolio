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

/// Coordinates deletion of album-owned records that do not currently use
/// database-level cascade deletion.
///
/// AlbumGenres already cascades from Albums in schema v3. Plays and NfcTags do
/// not, so they are explicitly removed before the Album row.
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

    final plays = await _playRepository.findByAlbum(normalizedId);
    var deletedPlayCount = 0;
    for (final play in plays) {
      final deleted = await _playRepository.deleteById(play.id);
      if (deleted != 1) {
        throw StateError('Could not delete play ${play.id}.');
      }
      deletedPlayCount += deleted;
    }

    final nfcTag = await _nfcTagRepository.findByAlbum(normalizedId);
    var deletedNfcAssociation = false;
    if (nfcTag != null) {
      final deleted = await _nfcTagRepository.delete(nfcTag.id);
      if (deleted != 1) {
        throw StateError('Could not delete linked NFC tag.');
      }
      deletedNfcAssociation = true;
    }

    await _artworkStorageService.deleteArtwork(album.artworkPath);

    final deletedAlbum = await _albumRepository.delete(normalizedId);
    if (deletedAlbum != 1) {
      throw StateError('Could not delete record.');
    }

    return AlbumDeletionResult(
      deletedPlayCount: deletedPlayCount,
      deletedNfcAssociation: deletedNfcAssociation,
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

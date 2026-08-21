import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/repositories/local_data_reset_repository.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';

/// Debug maintenance workflow for returning Groovefolio to an empty local
/// collection without disconnecting the developer's Discogs account.
class LocalDataResetService {
  const LocalDataResetService({
    required ILocalDataResetRepository resetRepository,
    required ArtworkStorageService artworkStorageService,
  }) : this._(resetRepository, artworkStorageService);

  const LocalDataResetService._(
    this._resetRepository,
    this._artworkStorageService,
  );

  final ILocalDataResetRepository _resetRepository;
  final ArtworkStorageService _artworkStorageService;

  Future<void> reset() async {
    // Database state is authoritative. Commit that reset first; if filesystem
    // cleanup ever fails, orphaned artwork is safer than live rows pointing to
    // files that were already deleted.
    await _resetRepository.clearCollectionData();
    await _artworkStorageService.clearAllArtwork();
  }
}

final localDataResetServiceProvider = Provider<LocalDataResetService>((ref) {
  return LocalDataResetService(
    resetRepository: ref.watch(localDataResetRepositoryProvider),
    artworkStorageService: ref.watch(artworkStorageServiceProvider),
  );
});

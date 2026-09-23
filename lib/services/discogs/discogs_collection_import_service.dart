import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/services/discogs/discogs_catalog_service.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/record_write_service.dart';

/// Review state of a Discogs item relative to the local collection.
enum DiscogsCollectionCandidateStatus { newRecord, exactDuplicate, needsReview }

/// A vinyl item plus duplicate classification for the import review screen.
class DiscogsCollectionCandidate {
  const DiscogsCollectionCandidate({
    required this.item,
    required this.status,
    this.localMatchTitle,
  });

  final DiscogsCollectionItem item;
  final DiscogsCollectionCandidateStatus status;
  final String? localMatchTitle;

  bool get canImport =>
      status != DiscogsCollectionCandidateStatus.exactDuplicate;
  bool get selectedByDefault =>
      status == DiscogsCollectionCandidateStatus.newRecord;
}

class DiscogsCollectionPreview {
  const DiscogsCollectionPreview({
    required this.candidates,
    required this.totalFetched,
    required this.nonVinylIgnored,
  });

  final List<DiscogsCollectionCandidate> candidates;
  final int totalFetched;
  final int nonVinylIgnored;

  int get vinylFound => candidates.length;
  int get newCount => candidates
      .where(
        (candidate) =>
            candidate.status == DiscogsCollectionCandidateStatus.newRecord,
      )
      .length;
  int get exactDuplicateCount => candidates
      .where(
        (candidate) =>
            candidate.status == DiscogsCollectionCandidateStatus.exactDuplicate,
      )
      .length;
  int get needsReviewCount => candidates
      .where(
        (candidate) =>
            candidate.status == DiscogsCollectionCandidateStatus.needsReview,
      )
      .length;
}

class DiscogsImportProgress {
  const DiscogsImportProgress({
    required this.completed,
    required this.total,
    this.currentTitle,
  });

  final int completed;
  final int total;
  final String? currentTitle;
}

class DiscogsImportFailure {
  const DiscogsImportFailure({
    required this.releaseId,
    required this.title,
    required this.message,
  });

  final int releaseId;
  final String title;
  final String message;
}

class DiscogsImportWarning {
  const DiscogsImportWarning({
    required this.releaseId,
    required this.title,
    required this.message,
  });

  final int releaseId;
  final String title;
  final String message;
}

class DiscogsCollectionImportResult {
  const DiscogsCollectionImportResult({
    required this.requested,
    required this.imported,
    required this.skipped,
    required this.failures,
    required this.warnings,
  });

  final int requested;
  final int imported;
  final int skipped;
  final List<DiscogsImportFailure> failures;
  final List<DiscogsImportWarning> warnings;

  int get failed => failures.length;
}

/// Previews the complete collection before any write, then imports only the
/// caller-selected candidates into the phone's local database.
abstract interface class DiscogsCollectionImportService {
  /// Fetches every collection page and classifies exact and possible local
  /// duplicates. Similar title/artist matches require explicit review.
  Future<DiscogsCollectionPreview> prepare(String username);

  /// Imports eligible selected candidates one by one. Per-release failures
  /// are reported; authentication, throttling, or network failure stops the
  /// batch so a systemic outage is not mistaken for individual bad records.
  Future<DiscogsCollectionImportResult> importCandidates(
    Iterable<DiscogsCollectionCandidate> candidates, {
    void Function(DiscogsImportProgress progress)? onProgress,
  });
}

class DefaultDiscogsCollectionImportService
    implements DiscogsCollectionImportService {
  const DefaultDiscogsCollectionImportService(
    this._catalogService,
    this._albumRepository,
    this._artistRepository,
    this._releaseLinkRepository,
    this._artworkStorageService,
    this._recordWriteService,
  );

  final DiscogsCatalogService _catalogService;
  final IAlbumRepository _albumRepository;
  final IArtistRepository _artistRepository;
  final IDiscogsReleaseLinkRepository _releaseLinkRepository;
  final ArtworkStorageService _artworkStorageService;
  final RecordWriteService _recordWriteService;

  @override
  Future<DiscogsCollectionPreview> prepare(String username) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw ArgumentError.value(
        username,
        'username',
        'Discogs username cannot be empty.',
      );
    }

    final fetched = <DiscogsCollectionItem>[];
    var pageNumber = 1;
    var totalFetched = 0;
    while (true) {
      final page = await _catalogService.collectionPage(
        username: normalizedUsername,
        page: pageNumber,
        perPage: 100,
      );
      fetched.addAll(page.items);
      totalFetched = page.totalItems;

      if (!page.hasNextPage) break;
      pageNumber += 1;
    }

    final vinylItems = fetched.where((item) => item.isVinyl).toList();
    final nonVinylIgnored = fetched.length - vinylItems.length;
    final linkedReleaseIds = await _releaseLinkRepository.findAllReleaseIds();
    final localAlbums = await _albumRepository.findAll();
    final localArtists = await _artistRepository.findAll();
    final artistsById = {
      for (final artist in localArtists) artist.id: artist.name,
    };

    final localKeys = <String, String>{};
    for (final album in localAlbums) {
      final artistName = artistsById[album.artistId];
      if (artistName == null) continue;
      localKeys[_albumKey(album.title, artistName)] =
          '${artistName.trim()} — ${album.title.trim()}';
    }

    // Two physical Discogs collection instances can share a release ID,
    // while the local release link is unique. Offer only the first instance.
    final seenReleaseIds = <int>{};
    final candidates = <DiscogsCollectionCandidate>[];
    for (final item in vinylItems) {
      final duplicateRelease =
          linkedReleaseIds.contains(item.releaseId) ||
          !seenReleaseIds.add(item.releaseId);
      if (duplicateRelease) {
        candidates.add(
          DiscogsCollectionCandidate(
            item: item,
            status: DiscogsCollectionCandidateStatus.exactDuplicate,
          ),
        );
        continue;
      }

      final localMatch = localKeys[_albumKey(item.title, item.artist)];
      if (localMatch != null) {
        candidates.add(
          DiscogsCollectionCandidate(
            item: item,
            status: DiscogsCollectionCandidateStatus.needsReview,
            localMatchTitle: localMatch,
          ),
        );
      } else {
        candidates.add(
          DiscogsCollectionCandidate(
            item: item,
            status: DiscogsCollectionCandidateStatus.newRecord,
          ),
        );
      }
    }

    return DiscogsCollectionPreview(
      candidates: List.unmodifiable(candidates),
      totalFetched: totalFetched == 0 ? fetched.length : totalFetched,
      nonVinylIgnored: nonVinylIgnored,
    );
  }

  @override
  Future<DiscogsCollectionImportResult> importCandidates(
    Iterable<DiscogsCollectionCandidate> candidates, {
    void Function(DiscogsImportProgress progress)? onProgress,
  }) async {
    final selected = candidates
        .where((candidate) => candidate.canImport)
        .toList(growable: false);
    final failures = <DiscogsImportFailure>[];
    final warnings = <DiscogsImportWarning>[];
    var imported = 0;
    var skipped = 0;

    onProgress?.call(
      DiscogsImportProgress(completed: 0, total: selected.length),
    );

    for (var index = 0; index < selected.length; index++) {
      final candidate = selected[index];
      onProgress?.call(
        DiscogsImportProgress(
          completed: index,
          total: selected.length,
          currentTitle: candidate.item.title,
        ),
      );

      // Stop on systemic failures; only a particular release's content or
      // write failure should be isolated and counted in the final summary.
      try {
        final alreadyLinked = await _releaseLinkRepository
            .findAlbumIdForRelease(candidate.item.releaseId);
        if (alreadyLinked != null) {
          skipped += 1;
        } else {
          final warning = await _importOne(candidate);
          if (warning != null) warnings.add(warning);
          imported += 1;
        }
      } on DiscogsAuthenticationFailure {
        rethrow;
      } on DiscogsRateLimitFailure {
        rethrow;
      } on DiscogsNetworkFailure {
        rethrow;
      } catch (error) {
        failures.add(
          DiscogsImportFailure(
            releaseId: candidate.item.releaseId,
            title: candidate.item.title,
            message: _failureMessage(error),
          ),
        );
      }

      onProgress?.call(
        DiscogsImportProgress(
          completed: index + 1,
          total: selected.length,
          currentTitle: candidate.item.title,
        ),
      );
    }

    return DiscogsCollectionImportResult(
      requested: selected.length,
      imported: imported,
      skipped: skipped,
      failures: List.unmodifiable(failures),
      warnings: List.unmodifiable(warnings),
    );
  }

  Future<DiscogsImportWarning?> _importOne(
    DiscogsCollectionCandidate candidate,
  ) async {
    final details = await _catalogService.release(candidate.item.releaseId);
    Uint8List? artworkBytes;
    DiscogsImportWarning? warning;
    final artworkUrl = details.artworkUrl ?? candidate.item.coverImageUrl;
    if (artworkUrl != null) {
      try {
        artworkBytes = await _catalogService.downloadArtwork(artworkUrl);
      } catch (error) {
        warning = DiscogsImportWarning(
          releaseId: candidate.item.releaseId,
          title: details.title,
          message: 'Imported without artwork: ${_failureMessage(error)}',
        );
      }
    }

    final createdAlbum = await _recordWriteService.createRecord(
      title: details.title,
      artistName: details.artist,
      releaseYear: details.year,
      label: details.label,
      discogsReleaseId: details.releaseId,
      genreNames: details.genreNames,
      tracks: details.tracks.map(
        (track) => TrackDraft(
          title: track.title,
          sequence: track.sequence,
          position: track.position,
          side: track.side,
          durationSeconds: track.durationSeconds,
        ),
      ),
    );

    if (artworkBytes != null && artworkBytes.isNotEmpty) {
      String? storedArtworkPath;
      try {
        storedArtworkPath = await _artworkStorageService.saveArtworkBytes(
          artworkBytes,
          createdAlbum.id,
        );
        final withArtwork = Album(
          id: createdAlbum.id,
          title: createdAlbum.title,
          artistId: createdAlbum.artistId,
          releaseYear: createdAlbum.releaseYear,
          label: createdAlbum.label,
          artworkPath: storedArtworkPath,
          purchaseDate: createdAlbum.purchaseDate,
          purchasePriceCents: createdAlbum.purchasePriceCents,
          createdAt: createdAlbum.createdAt,
        );
        final updated = await _albumRepository.update(withArtwork);
        if (!updated) {
          throw StateError(
            'Imported artwork could not be linked to the album.',
          );
        }
      } catch (error) {
        if (storedArtworkPath != null) {
          try {
            await _artworkStorageService.deleteArtwork(storedArtworkPath);
          } catch (_) {
            // Orphan cleanup is best-effort; the database record is already a
            // valid atomic import and must not be rolled back for artwork.
          }
        }
        warning = DiscogsImportWarning(
          releaseId: candidate.item.releaseId,
          title: details.title,
          message: 'Imported without artwork: ${_failureMessage(error)}',
        );
      }
    }

    return warning;
  }

  String _albumKey(String title, String artist) {
    return '${_normalize(artist)}\u0000${_normalize(title)}';
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _failureMessage(Object error) {
    if (error is DiscogsFailure) return error.message;
    if (error is ArgumentError) return error.message?.toString() ?? '$error';
    if (error is StateError) return error.message.toString();
    return 'Unexpected import error.';
  }
}

final discogsCollectionImportServiceProvider =
    Provider<DiscogsCollectionImportService>((ref) {
      return DefaultDiscogsCollectionImportService(
        ref.watch(discogsCatalogServiceProvider),
        ref.watch(albumRepositoryProvider),
        ref.watch(artistRepositoryProvider),
        ref.watch(discogsReleaseLinkRepositoryProvider),
        ref.watch(artworkStorageServiceProvider),
        ref.watch(recordWriteServiceProvider),
      );
    });

// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/repositories/discogs_release_link_repository.dart';

/// Persistence-agnostic transaction boundary used by workflow services.
///
/// The service layer can coordinate multiple repositories atomically without
/// importing Drift APIs or constructing persistence companions.
abstract interface class DatabaseTransactionRunner {
  Future<T> run<T>(Future<T> Function() operation);
}

class DriftDatabaseTransactionRunner implements DatabaseTransactionRunner {
  const DriftDatabaseTransactionRunner(this._db);

  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() operation) {
    return _db.transaction(operation);
  }
}

/// Coordinates record writes that span multiple repositories.
///
/// Add/Edit/Discogs import all use this service so artist, album, Discogs link,
/// tracklist, and genre mappings commit as one database transaction. Artwork is
/// intentionally handled after the DB commit because filesystem writes cannot
/// participate in a SQLite transaction.
class RecordWriteService {
  const RecordWriteService({
    required DatabaseTransactionRunner transactionRunner,
    required IAlbumRepository albumRepository,
    required IArtistRepository artistRepository,
    required IGenreRepository genreRepository,
    required ITrackRepository trackRepository,
    required IDiscogsReleaseLinkRepository releaseLinkRepository,
  }) : _transactionRunner = transactionRunner,
       _albumRepository = albumRepository,
       _artistRepository = artistRepository,
       _genreRepository = genreRepository,
       _trackRepository = trackRepository,
       _releaseLinkRepository = releaseLinkRepository;

  final DatabaseTransactionRunner _transactionRunner;
  final IAlbumRepository _albumRepository;
  final IArtistRepository _artistRepository;
  final IGenreRepository _genreRepository;
  final ITrackRepository _trackRepository;
  final IDiscogsReleaseLinkRepository _releaseLinkRepository;

  Future<Album> createRecord({
    required String title,
    required String artistName,
    int? releaseYear,
    String? label,
    int? discogsReleaseId,
    Iterable<String> genreNames = const [],
    Iterable<TrackDraft> tracks = const [],
  }) {
    final normalizedGenres = genreNames.toList(growable: false);
    final trackDrafts = tracks.toList(growable: false);

    return _transactionRunner.run(() async {
      final releaseId = discogsReleaseId;
      if (releaseId != null) {
        final existingAlbumId = await _releaseLinkRepository
            .findAlbumIdForRelease(releaseId);
        if (existingAlbumId != null) {
          throw StateError(
            'That exact Discogs release is already linked to another record in your collection.',
          );
        }
      }

      final artist = await _artistRepository.findOrCreate(artistName);
      final album = await _albumRepository.create(
        title: title,
        artistId: artist.id,
        releaseYear: releaseYear,
        label: label,
      );

      if (releaseId != null) {
        await _releaseLinkRepository.link(
          albumId: album.id,
          releaseId: releaseId,
        );
      }

      if (trackDrafts.isNotEmpty) {
        await _trackRepository.replaceAlbumTracks(album.id, trackDrafts);
      }

      if (normalizedGenres.isNotEmpty) {
        final genreIds = <String>[];
        for (final name in normalizedGenres) {
          genreIds.add((await _genreRepository.findOrCreate(name)).id);
        }
        await _genreRepository.setAlbumGenres(album.id, genreIds);
      }

      return album;
    });
  }

  Future<Album> updateRecord({
    required Album existing,
    required String title,
    required String artistName,
    required Iterable<String> genreNames,
    int? releaseYear,
    String? label,
    String? artworkPath,
  }) {
    final normalizedGenres = genreNames.toList(growable: false);

    return _transactionRunner.run(() async {
      final artist = await _artistRepository.findOrCreate(artistName);
      final updatedAlbum = Album(
        id: existing.id,
        title: title.trim(),
        artistId: artist.id,
        releaseYear: releaseYear,
        label: _trimNullable(label),
        artworkPath: _trimNullable(artworkPath),
        purchaseDate: existing.purchaseDate,
        purchasePriceCents: existing.purchasePriceCents,
        createdAt: existing.createdAt,
      );

      final updated = await _albumRepository.update(updatedAlbum);
      if (!updated) {
        throw StateError('Record could not be updated.');
      }

      final genreIds = <String>[];
      for (final name in normalizedGenres) {
        genreIds.add((await _genreRepository.findOrCreate(name)).id);
      }
      await _genreRepository.setAlbumGenres(existing.id, genreIds);

      return updatedAlbum;
    });
  }

  String? _trimNullable(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

final databaseTransactionRunnerProvider = Provider<DatabaseTransactionRunner>((
  ref,
) {
  return DriftDatabaseTransactionRunner(ref.watch(databaseProvider));
});

final recordWriteServiceProvider = Provider<RecordWriteService>((ref) {
  return RecordWriteService(
    transactionRunner: ref.watch(databaseTransactionRunnerProvider),
    albumRepository: ref.watch(albumRepositoryProvider),
    artistRepository: ref.watch(artistRepositoryProvider),
    genreRepository: ref.watch(genreRepositoryProvider),
    trackRepository: ref.watch(trackRepositoryProvider),
    releaseLinkRepository: ref.watch(discogsReleaseLinkRepositoryProvider),
  );
});

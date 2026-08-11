import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/utils/id_generator.dart';

part 'nfc_tag_repository.g.dart';

/// Contract for NFC-tag persistence operations.
///
/// VinylApp-040 enforces a one-to-one relationship between albums and NFC
/// tags. Missing lookups return null rather than throwing.
abstract interface class INfcTagRepository {
  /// Creates an NFC-tag association for [albumId].
  ///
  /// The repository owns generated IDs and the persisted write timestamp so
  /// callers do not need to construct Drift companions.
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  });

  /// Finds the association for a physical NFC tag, or null when unregistered.
  Future<NfcTag?> findByTagId(String nfcTagId);

  /// Finds the single NFC tag associated with an album, or null when absent.
  Future<NfcTag?> findByAlbum(String albumId);

  /// Deletes an NFC-tag association by its repository entity ID.
  Future<int> delete(String id);
}

/// Drift-backed implementation of [INfcTagRepository].
class NfcTagRepository implements INfcTagRepository {
  NfcTagRepository(this._db);

  final AppDatabase _db;

  @override
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) {
    final normalizedAlbumId = albumId.trim();
    final normalizedTagId = nfcTagId.trim();

    if (normalizedAlbumId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }
    if (normalizedTagId.isEmpty) {
      throw ArgumentError.value(
        nfcTagId,
        'nfcTagId',
        'NFC tag ID cannot be empty.',
      );
    }

    final companion = NfcTagsCompanion.insert(
      id: generateId('nfc-tag'),
      albumId: normalizedAlbumId,
      nfcTagId: normalizedTagId,
      writtenAt: (writtenAt ?? DateTime.now()).toUtc().toIso8601String(),
    );

    return _db.into(_db.nfcTags).insertReturning(companion);
  }

  @override
  Future<NfcTag?> findByTagId(String nfcTagId) {
    final normalizedTagId = nfcTagId.trim();
    if (normalizedTagId.isEmpty) return Future.value(null);

    final query = _db.select(_db.nfcTags)
      ..where((tag) => tag.nfcTagId.equals(normalizedTagId));
    return query.getSingleOrNull();
  }

  @override
  Future<NfcTag?> findByAlbum(String albumId) {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) return Future.value(null);

    final query = _db.select(_db.nfcTags)
      ..where((tag) => tag.albumId.equals(normalizedAlbumId));
    return query.getSingleOrNull();
  }

  @override
  Future<int> delete(String id) {
    final query = _db.delete(_db.nfcTags)..where((tag) => tag.id.equals(id));
    return query.go();
  }
}

/// Repository dependency used by feature/service providers.
///
/// VinylApp-016 will standardize override coverage across all repository
/// providers; VinylApp-041 introduces this provider alongside the repository.
@riverpod
INfcTagRepository nfcTagRepository(Ref ref) {
  return NfcTagRepository(ref.watch(databaseProvider));
}

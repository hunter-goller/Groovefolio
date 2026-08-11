import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  group('repository providers', () {
    test('albumRepositoryProvider can be overridden', () {
      final fake = _FakeAlbumRepository();
      final container = ProviderContainer(
        overrides: [albumRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(albumRepositoryProvider), same(fake));
    });

    test('artistRepositoryProvider can be overridden', () {
      final fake = _FakeArtistRepository();
      final container = ProviderContainer(
        overrides: [artistRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(artistRepositoryProvider), same(fake));
    });

    test('playRepositoryProvider can be overridden', () {
      final fake = _FakePlayRepository();
      final container = ProviderContainer(
        overrides: [playRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(playRepositoryProvider), same(fake));
    });

    test('nfcTagRepositoryProvider can be overridden', () {
      final fake = _FakeNfcTagRepository();
      final container = ProviderContainer(
        overrides: [nfcTagRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(nfcTagRepositoryProvider), same(fake));
    });
  });
}

class _FakeAlbumRepository implements IAlbumRepository {
  @override
  Future<Album> create({
    required String title,
    required String artistId,
    int? releaseYear,
    String? label,
    String? artworkPath,
    DateTime? purchaseDate,
    int? purchasePriceCents,
  }) => throw UnimplementedError();

  @override
  Future<int> delete(String id) => throw UnimplementedError();

  @override
  Future<List<Album>> findAll() => throw UnimplementedError();

  @override
  Future<Album?> findById(String id) => throw UnimplementedError();

  @override
  Future<List<Album>> search(String query) => throw UnimplementedError();

  @override
  Future<bool> update(Album album) => throw UnimplementedError();
}

class _FakeArtistRepository implements IArtistRepository {
  @override
  Future<List<Artist>> findAll() => throw UnimplementedError();

  @override
  Future<Artist?> findById(String id) => throw UnimplementedError();

  @override
  Future<Artist> findOrCreate(String name) => throw UnimplementedError();
}

class _FakePlayRepository implements IPlayRepository {
  @override
  Future<Play> create({
    required String albumId,
    required DateTime playedAt,
    required SidePlayed sidePlayed,
  }) => throw UnimplementedError();

  @override
  Future<int> deleteById(String id) => throw UnimplementedError();

  @override
  Future<List<Play>> findAll() => throw UnimplementedError();

  @override
  Future<List<Play>> findByAlbum(String albumId) => throw UnimplementedError();

  @override
  Future<int> getPlayCountByAlbum(String albumId) => throw UnimplementedError();

  @override
  Future<List<Album>> getRecentlyPlayed(int limit) =>
      throw UnimplementedError();
}

class _FakeNfcTagRepository implements INfcTagRepository {
  @override
  Future<NfcTag> create({
    required String albumId,
    required String nfcTagId,
    DateTime? writtenAt,
  }) => throw UnimplementedError();

  @override
  Future<int> delete(String id) => throw UnimplementedError();

  @override
  Future<NfcTag?> findByAlbum(String albumId) => throw UnimplementedError();

  @override
  Future<NfcTag?> findByTagId(String nfcTagId) => throw UnimplementedError();
}

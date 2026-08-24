import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/services/onboarding_service.dart';

void main() {
  test('new empty install requires onboarding', () async {
    final store = _MemoryOnboardingStore();
    final service = OnboardingService(
      store: store,
      albumRepository: const _Albums([]),
    );

    expect(await service.shouldShowOnboarding(), isTrue);
    expect(store.completed, isFalse);
  });

  test('completed onboarding is not shown again', () async {
    final service = OnboardingService(
      store: _MemoryOnboardingStore(completed: true),
      albumRepository: const _Albums([]),
    );

    expect(await service.shouldShowOnboarding(), isFalse);
  });

  test(
    'existing collection skips and permanently completes onboarding',
    () async {
      final store = _MemoryOnboardingStore();
      final service = OnboardingService(
        store: store,
        albumRepository: const _Albums([
          Album(
            id: 'album-1',
            title: 'Blue Train',
            artistId: 'artist-1',
            createdAt: '2026-08-24T00:00:00.000Z',
          ),
        ]),
      );

      expect(await service.shouldShowOnboarding(), isFalse);
      expect(store.completed, isTrue);
    },
  );
}

class _MemoryOnboardingStore implements OnboardingStore {
  _MemoryOnboardingStore({this.completed = false});

  bool completed;

  @override
  Future<bool> hasCompletedOnboarding() async => completed;

  @override
  Future<void> markOnboardingComplete() async {
    completed = true;
  }
}

class _Albums implements IAlbumRepository {
  const _Albums(this.albums);

  final List<Album> albums;

  @override
  Future<List<Album>> findAll() async => albums;

  @override
  Future<Album?> findById(String id) async => null;

  @override
  Future<List<Album>> search(String query) async => albums;

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
  Future<bool> update(Album album) => throw UnimplementedError();
}

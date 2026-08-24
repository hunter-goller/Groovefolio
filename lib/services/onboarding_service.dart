import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vinyl_app/providers/repository_providers.dart';

abstract interface class OnboardingStore {
  Future<bool> hasCompletedOnboarding();

  Future<void> markOnboardingComplete();
}

class SecureOnboardingStore implements OnboardingStore {
  const SecureOnboardingStore(this._storage);

  static const _completionKey = 'groovefolio.onboarding.completed.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasCompletedOnboarding() async {
    return await _storage.read(key: _completionKey) == 'true';
  }

  @override
  Future<void> markOnboardingComplete() {
    return _storage.write(key: _completionKey, value: 'true');
  }
}

class OnboardingService {
  const OnboardingService({
    required this._store,
    required this._albumRepository,
  });

  final OnboardingStore _store;
  final IAlbumRepository _albumRepository;

  Future<bool> shouldShowOnboarding() async {
    if (await _store.hasCompletedOnboarding()) return false;

    // A populated collection means this is an upgraded install. Do not force
    // an existing Groovefolio user through a newly added first-run flow.
    if ((await _albumRepository.findAll()).isNotEmpty) {
      await _store.markOnboardingComplete();
      return false;
    }

    return true;
  }

  Future<void> completeOnboarding() => _store.markOnboardingComplete();
}

final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  return const SecureOnboardingStore(FlutterSecureStorage());
});

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(
    store: ref.watch(onboardingStoreProvider),
    albumRepository: ref.watch(albumRepositoryProvider),
  );
});

final onboardingRequiredProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingServiceProvider).shouldShowOnboarding();
});

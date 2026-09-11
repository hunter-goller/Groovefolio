import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vinyl_app/providers/repository_providers.dart';

abstract interface class OnboardingStore {
  Future<bool> hasCompletedOnboarding();

  Future<void> markOnboardingComplete();

  Future<int?> readProgress();

  Future<void> saveProgress(int step);
}

class SecureOnboardingStore implements OnboardingStore {
  const SecureOnboardingStore(this._storage);

  static const _completionKey = 'groovefolio.onboarding.completed.v1';

  static const _progressKey = 'groovefolio.onboarding.progress.v2';

  final FlutterSecureStorage _storage;

  @override
  Future<int?> readProgress() async {
    final raw = await _storage.read(key: _progressKey);
    if (raw == null) return null;
    final step = int.tryParse(raw);
    return step != null && step >= 0 && step < 8 ? step : 0;
  }

  @override
  Future<void> saveProgress(int step) =>
      _storage.write(key: _progressKey, value: step.toString());

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

    if (await _store.readProgress() != null) return true;

    // A populated collection means this is an upgraded install. Do not force
    // an existing Groovefolio user through a newly added first-run flow.
    if ((await _albumRepository.findAll()).isNotEmpty) {
      await _store.markOnboardingComplete();
      return false;
    }

    return true;
  }

  Future<int> resumeStep() async => await _store.readProgress() ?? 0;

  Future<bool> hasPendingWalkthrough() async =>
      !await _store.hasCompletedOnboarding() &&
      await _store.readProgress() != null;

  Future<void> saveStep(int step) {
    if (step < 0 || step >= 8) throw RangeError.range(step, 0, 7);
    return _store.saveProgress(step);
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

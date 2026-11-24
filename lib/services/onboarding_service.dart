import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The old walkthrough's saved state. Only read now, once, to carry over
/// whether someone has already seen getting started (see
/// `migrateFromWalkthrough`). The tutorial saves its own progress.
abstract interface class OnboardingStore {
  Future<bool> hasCompletedOnboarding();

  Future<void> markOnboardingComplete();

  Future<int?> readProgress();

  Future<void> saveProgress(int step);
}

/// Versioned progress keys allow the walkthrough to change without
/// interpreting an older sequence of steps as the current one.
class SecureOnboardingStore implements OnboardingStore {
  const SecureOnboardingStore(this._storage);

  static const _completionKey = 'groovefolio.onboarding.completed.v1';

  static const _progressKey = 'groovefolio.onboarding.progress.v3';

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

final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  return const SecureOnboardingStore(FlutterSecureStorage());
});

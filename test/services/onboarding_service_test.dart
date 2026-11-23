import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/onboarding_service.dart';

/// The old walkthrough store is only read now, to migrate "intro seen".
void main() {
  test('reads what the old walkthrough saved', () async {
    FlutterSecureStorage.setMockInitialValues({
      'groovefolio.onboarding.completed.v1': 'true',
      'groovefolio.onboarding.progress.v3': '4',
    });
    const store = SecureOnboardingStore(FlutterSecureStorage());
    expect(await store.hasCompletedOnboarding(), isTrue);
    expect(await store.readProgress(), 4);
  });

  test('a fresh install has nothing saved', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureOnboardingStore(FlutterSecureStorage());
    expect(await store.hasCompletedOnboarding(), isFalse);
    expect(await store.readProgress(), isNull);
  });
}

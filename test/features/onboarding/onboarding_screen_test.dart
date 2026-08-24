import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  testWidgets('first-run tutorial advances and Skip persists completion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _MemoryOnboardingStore();

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('Your record shelf, remembered'), findsOneWidget);
    expect(find.textContaining('NFC'), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Add records your way'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(store.completed, isTrue);
    expect(find.text('Collection test'), findsOneWidget);
  });

  testWidgets('last page finishes with Get started', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _MemoryOnboardingStore();

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    for (var page = 1; page < 6; page++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Stats and picks improve as you listen'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-skip')), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding-get-started')));
    await tester.pumpAndSettle();

    expect(store.completed, isTrue);
    expect(find.text('Collection test'), findsOneWidget);
  });

  testWidgets('content remains usable with larger text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _app(_MemoryOnboardingStore()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('onboarding-next')), findsOneWidget);
  });
}

Widget _app(_MemoryOnboardingStore store) {
  final service = OnboardingService(
    store: store,
    albumRepository: const _Albums(),
  );
  final router = GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Collection test'))),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [onboardingServiceProvider.overrideWithValue(service)],
    child: MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    ),
  );
}

class _MemoryOnboardingStore implements OnboardingStore {
  bool completed = false;

  @override
  Future<bool> hasCompletedOnboarding() async => completed;

  @override
  Future<void> markOnboardingComplete() async {
    completed = true;
  }
}

class _Albums implements IAlbumRepository {
  const _Albums();

  @override
  Future<List<Album>> findAll() async => const [];

  @override
  Future<Album?> findById(String id) async => null;

  @override
  Future<List<Album>> search(String query) async => const [];

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

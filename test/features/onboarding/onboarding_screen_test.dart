import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  testWidgets(
    'replay returns to Settings and leaves first-run progress alone',
    (tester) async {
      final store = _MemoryOnboardingStore()..progress = 3;
      await tester.pumpWidget(_app(store, replay: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(find.text('Settings test'), findsOneWidget);
      expect(store.progress, 3);
      expect(store.completed, isFalse);
    },
  );

  testWidgets('reduced motion changes page without an animation error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_MemoryOnboardingStore(), reducedMotion: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Bring your Discogs collection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported devices have no NFC setup action', (tester) async {
    await tester.pumpWidget(_app(_MemoryOnboardingStore()..progress = 5));
    await tester.pumpAndSettle();
    expect(find.text('Choose a record to link'), findsNothing);
    expect(find.byKey(const Key('onboarding-next')), findsOneWidget);
  });

  testWidgets('supported devices can open NFC setup later', (tester) async {
    await tester.pumpWidget(
      _app(_MemoryOnboardingStore()..progress = 5, nfc: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose a record to link'), findsOneWidget);
    expect(find.text('Set up later'), findsOneWidget);
  });

  testWidgets('resumes a saved step and returns from a real action', (
    tester,
  ) async {
    final store = _MemoryOnboardingStore()..progress = 2;
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    expect(find.text('Add records your way'), findsOneWidget);
    await tester.ensureVisible(find.text('Add a record'));
    await tester.tap(find.text('Add a record'));
    await tester.pumpAndSettle();
    expect(find.text('Real add route'), findsOneWidget);
    await tester.tap(find.text('Return to tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Add records your way'), findsOneWidget);
    expect(store.progress, 2);
    expect(store.completed, isFalse);
  });

  testWidgets('failed completion stays recoverable without a raw error', (
    tester,
  ) async {
    final store = _MemoryOnboardingStore()..failCompletion = true;
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(store.completed, isFalse);
    expect(
      find.text('Couldn’t save your progress. Please try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    store.failCompletion = false;
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(store.completed, isTrue);
  });

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
    expect(find.text('Bring your Discogs collection'), findsOneWidget);
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

    for (var page = 1; page < 8; page++) {
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

    await tester.pumpWidget(_app(_MemoryOnboardingStore(), textScale: 1.8));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('onboarding-next')), findsOneWidget);
  });
}

Widget _app(
  _MemoryOnboardingStore store, {
  bool replay = false,
  bool reducedMotion = false,
  bool nfc = false,
  double textScale = 1,
}) {
  final service = OnboardingService(
    store: store,
    albumRepository: const _Albums(),
  );
  final router = GoRouter(
    initialLocation: replay ? AppRoutes.settings : AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('Settings test'),
              TextButton(
                onPressed: () => context.push(AppRoutes.onboarding),
                child: const Text('Replay'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.addAlbum,
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('Real add route'),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Return to tutorial'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Collection test'))),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(replay: replay),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      onboardingServiceProvider.overrideWithValue(service),
      discogsAccountProvider.overrideWith((ref) async => null),
      nfcHelpVisibleProvider.overrideWithValue(nfc),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reducedMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
}

class _MemoryOnboardingStore implements OnboardingStore {
  int? progress;

  @override
  Future<int?> readProgress() async => progress;

  @override
  Future<void> saveProgress(int step) async {
    progress = step;
  }

  bool completed = false;
  bool failCompletion = false;

  @override
  Future<bool> hasCompletedOnboarding() async => completed;

  @override
  Future<void> markOnboardingComplete() async {
    if (failCompletion) throw StateError('sensitive storage error');
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:vinyl_app/features/onboarding/widgets/walkthrough_frame.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/features/settings/screens/settings_screen.dart';
import 'package:vinyl_app/repositories/album_repository.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'welcome opens real Settings and Not now branches to Collection',
    (tester) async {
      final store = _MemoryOnboardingStore();
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      await tester.tap(find.byKey(const Key('guide-start')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byKey(const Key('connect-discogs-button')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('guide-skip-step')));
      await tester.tap(find.byKey(const Key('guide-skip-step')));
      await tester.pumpAndSettle();
      expect(find.text('Collection test'), findsOneWidget);
      expect(store.progress, 1);
      expect(store.completed, isFalse);
    },
  );

  testWidgets(
    'play form visibility changes guidance without advancing the step',
    (tester) async {
      final store = _MemoryOnboardingStore()..progress = 3;
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guide-start')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WalkthroughFrame)),
      );
      final form = container.read(walkthroughPlayFormProvider.notifier);
      form.setOpen(true);
      await tester.pumpAndSettle();
      expect(find.textContaining('then tap Save play'), findsOneWidget);
      expect(store.progress, 3);
      form.setOpen(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose a record below'), findsOneWidget);
      expect(store.progress, 3);
    },
  );

  testWidgets('connected Settings offers import or manual entry', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_MemoryOnboardingStore(), connected: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-start')));
    await tester.pumpAndSettle();
    expect(find.text('Add manually'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
    final import = find.byKey(const Key('discogs-import-collection-button'));
    await tester.ensureVisible(import);
    await tester.tap(import);
    await tester.pumpAndSettle();
    expect(find.text('Import route'), findsOneWidget);
    expect(find.textContaining('After reviewing the result'), findsOneWidget);
  });

  testWidgets('replay exit returns to Settings without changing progress', (
    tester,
  ) async {
    final store = _MemoryOnboardingStore()..progress = 3;
    await tester.pumpWidget(_app(store, replay: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-skip-step')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-exit')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(store.progress, 3);
    expect(store.completed, isFalse);
    expect(find.byKey(const Key('guide-exit')), findsNothing);
  });

  testWidgets('small display and large text keep guide and screen usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(_MemoryOnboardingStore(), textScale: 1.8));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('guide-start')));
    await tester.tap(find.byKey(const Key('guide-start')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('guide-skip-step')));
    await tester.tap(find.byKey(const Key('guide-skip-step')));
    await tester.pumpAndSettle();
    expect(find.text('Collection test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'saved actions advance and a failed progress write can retry without repeating the action',
    () async {
      final store = _MemoryOnboardingStore();
      final container = _container(store);
      addTearDown(container.dispose);
      final guide = container.read(walkthroughProvider.notifier);
      await guide.start();
      await guide.skipStep();
      store.failProgress = true;
      await guide.recordSaved('record');
      expect(container.read(walkthroughProvider).step, 1);
      expect(container.read(walkthroughProvider).error, isTrue);
      store.failProgress = false;
      await guide.retry();
      expect(container.read(walkthroughProvider).step, 2);
      expect(container.read(walkthroughProvider).albumId, 'record');
      await guide.recordOpened('record');
      expect(container.read(walkthroughProvider).route, '/album/record');
      await guide.playSaved('record');
      expect(store.progress, 4);
      await guide.nfcLinked();
      guide.swipeRevealed();
      expect(container.read(walkthroughProvider).practiced, isTrue);
      await guide.move(6);
      await guide.move(7);
      await guide.finish();
      expect(store.completed, isTrue);
      await guide.playSaved('record');
      expect(container.read(walkthroughProvider).active, isFalse);
    },
  );

  test(
    'resuming a record-specific step asks for a record instead of keeping a stale ID',
    () async {
      final store = _MemoryOnboardingStore()..progress = 4;
      final container = _container(store);
      addTearDown(container.dispose);
      final guide = container.read(walkthroughProvider.notifier);
      await guide.start();
      expect(container.read(walkthroughProvider).route, AppRoutes.collection);
      await guide.recordOpened('existing');
      expect(container.read(walkthroughProvider).step, 4);
      expect(container.read(walkthroughProvider).route, '/album/existing');
    },
  );

  test(
    'replay never writes first-run progress and finish failures remain recoverable',
    () async {
      final store = _MemoryOnboardingStore()..progress = 2;
      final container = _container(store);
      addTearDown(container.dispose);
      final guide = container.read(walkthroughProvider.notifier);
      await guide.start(replay: true);
      await guide.move(7);
      await guide.finish();
      expect(store.progress, 2);
      expect(store.completed, isFalse);
      await guide.start();
      store.failCompletion = true;
      expect(await guide.finish(), isFalse);
      expect(container.read(walkthroughProvider).active, isTrue);
      store.failCompletion = false;
      await guide.retry();
      expect(store.completed, isTrue);
      expect(container.read(walkthroughProvider).active, isFalse);
    },
  );
}

ProviderContainer _container(_MemoryOnboardingStore store) => ProviderContainer(
  overrides: [
    onboardingServiceProvider.overrideWithValue(
      OnboardingService(store: store, albumRepository: const _Albums()),
    ),
  ],
);

Widget _app(
  _MemoryOnboardingStore store, {
  bool replay = false,
  bool connected = false,
  double textScale = 1,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            WalkthroughFrame(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.onboarding,
            builder: (context, state) => OnboardingScreen(replay: replay),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.collection,
            builder: (context, state) =>
                const Scaffold(body: Text('Collection test')),
          ),
          GoRoute(
            path: AppRoutes.discogsCollectionImport,
            builder: (context, state) =>
                const Scaffold(body: Text('Import route')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      onboardingServiceProvider.overrideWithValue(
        OnboardingService(store: store, albumRepository: const _Albums()),
      ),
      discogsConfigProvider.overrideWithValue(
        const DiscogsConfig(consumerKey: 'test', consumerSecret: 'test'),
      ),
      discogsAccountProvider.overrideWithValue(
        AsyncData(
          connected
              ? const DiscogsAccount(
                  id: 1,
                  username: 'listener',
                  resourceUrl: 'https://api.discogs.com/users/listener',
                )
              : null,
        ),
      ),
      nfcHelpVisibleProvider.overrideWithValue(false),
      developerToolsEnabledProvider.overrideWithValue(false),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
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
    if (failProgress) throw StateError('storage unavailable');
    progress = step;
  }

  bool failProgress = false;
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

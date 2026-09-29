import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/main.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/routing/router.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_platform_adapter.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/services/onboarding_service.dart';

final _callback = Uri.parse('groovefolio://discogs-auth');

void main() {
  for (final failed in [false, true]) {
    testWidgets(
      'warm callback preserves Settings Back navigation, failed=$failed',
      (tester) async {
        final fixture = await _pumpApp(tester, failed: failed);
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        final settingsElement = tester.element(
          find.widgetWithText(AppBar, 'Settings'),
        );

        // Browser auto-return and the fallback link can deliver the same URI.
        for (var delivery = 0; delivery < 2; delivery++) {
          fixture.uris.add(_callback);
          await tester.pumpAndSettle();
        }
        expect(fixture.authorization.checks, 2);
        expect(
          tester.element(find.widgetWithText(AppBar, 'Settings')),
          same(settingsElement),
        );
        expect(find.byTooltip('Back'), findsOneWidget);

        if (failed) {
          expect(find.text('Test authorization failed.'), findsOneWidget);
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('Back'));
        }
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'My collection'), findsOneWidget);
        expect(fixture.container.read(routerProvider).canPop(), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('queued startup callback keeps Collection as Back destination', (
    tester,
  ) async {
    final fixture = await _pumpApp(tester, initialCallback: true);
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(fixture.authorization.checks, 1);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'My collection'), findsOneWidget);
    expect(fixture.container.read(routerProvider).canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('callback from another screen returns there after one Back', (
    tester,
  ) async {
    final fixture = await _pumpApp(tester);
    final router = fixture.container.read(routerProvider);
    router.go(AppRoutes.stats);
    await tester.pumpAndSettle();

    fixture.uris.add(_callback);
    await tester.pumpAndSettle();
    fixture.uris.add(_callback);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.stats);
    expect(find.widgetWithText(AppBar, 'Settings'), findsNothing);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  const _Fixture(this.uris, this.container, this.authorization);

  final StreamController<Uri> uris;
  final ProviderContainer container;
  final _Authorization authorization;
}

Future<_Fixture> _pumpApp(
  WidgetTester tester, {
  bool failed = false,
  bool initialCallback = false,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final uris = StreamController<Uri>();
  final authorization = _Authorization(failed);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      incomingAppLinkStreamProvider.overrideWithValue(uris.stream),
      onboardingStoreProvider.overrideWithValue(_CompletedOnboarding()),
      nfcAvailabilityProvider.overrideWith(
        (ref) async => NfcAvailabilityState.unsupported,
      ),
      discogsAccountProvider.overrideWithValue(
        const AsyncData<DiscogsAccount?>(null),
      ),
      discogsAuthorizationControllerProvider.overrideWith(() => authorization),
    ],
  );
  final router = container.read(routerProvider);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    await uris.close();
    await db.close();
  });
  if (initialCallback) uris.add(_callback);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pumpAndSettle();
  return _Fixture(uris, container, authorization);
}

class _Authorization extends DiscogsAuthorizationController {
  _Authorization(this.failed);

  final bool failed;
  int checks = 0;

  @override
  DiscogsAuthorizationState build() =>
      const DiscogsAuthorizationState.awaitingCallback();

  @override
  Future<void> checkAuthorization() async {
    checks++;
    state = failed
        ? const DiscogsAuthorizationState.failed(
            DiscogsAuthenticationFailure('Test authorization failed.'),
          )
        : const DiscogsAuthorizationState.idle();
  }
}

class _CompletedOnboarding implements OnboardingStore {
  @override
  Future<bool> hasCompletedOnboarding() async => true;

  @override
  Future<void> markOnboardingComplete() async {}

  @override
  Future<int?> readProgress() async => null;

  @override
  Future<void> saveProgress(int step) async {}
}

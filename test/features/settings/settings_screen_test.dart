import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/settings/screens/settings_screen.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  testWidgets(
    'browser return checks only a pending connection and removes observer',
    (tester) async {
      final controller = _ResumeAuthorizationController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discogsAccountProvider.overrideWithValue(
              const AsyncData<DiscogsAccount?>(null),
            ),
            discogsAuthorizationControllerProvider.overrideWith(
              () => controller,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.checks, 1);
      // Completed/idle connections do not poll on every foreground event.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.checks, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(controller.checks, 1);
    },
  );

  testWidgets('shows connected Discogs username', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discogsConfigProvider.overrideWithValue(const DiscogsConfig()),
          discogsAccountProvider.overrideWithValue(
            const AsyncData<DiscogsAccount?>(
              DiscogsAccount(
                id: 7,
                username: 'hunter',
                resourceUrl: 'https://api.discogs.com/users/hunter',
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('developer-test-nfc-tap')), findsNothing);
    expect(find.text('Connected as hunter'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Data provided by Discogs.'), findsOneWidget);
    expect(
      find.byKey(const Key('discogs-import-collection-button')),
      findsOneWidget,
    );
  });

  testWidgets('shows connect action when disconnected', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discogsConfigProvider.overrideWithValue(const DiscogsConfig()),
          discogsAccountProvider.overrideWithValue(
            const AsyncData<DiscogsAccount?>(null),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );

    await tester.pump();

    expect(find.byKey(const Key('connect-discogs-button')), findsOneWidget);
    expect(find.text('Connect Discogs'), findsOneWidget);
  });

  testWidgets('Discogs identity retry starts a visible connection check', (
    tester,
  ) async {
    final controller = _ActionAuthorizationController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discogsConfigProvider.overrideWithValue(const DiscogsConfig()),
          discogsAccountProvider.overrideWithValue(
            const AsyncError<DiscogsAccount?>(
              DiscogsNetworkFailure('Offline'),
              StackTrace.empty,
            ),
          ),
          discogsAuthorizationControllerProvider.overrideWith(() => controller),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('discogs-identity-retry')));
    await tester.pump();

    expect(controller.checks, 1);
    expect(find.text('Checking Discogs connection…'), findsOneWidget);
  });

  testWidgets('Discogs identity disconnect starts a visible disconnect', (
    tester,
  ) async {
    final controller = _ActionAuthorizationController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discogsConfigProvider.overrideWithValue(const DiscogsConfig()),
          discogsAccountProvider.overrideWithValue(
            const AsyncError<DiscogsAccount?>(
              DiscogsNetworkFailure('Offline'),
              StackTrace.empty,
            ),
          ),
          discogsAuthorizationControllerProvider.overrideWith(() => controller),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('discogs-identity-disconnect')));
    await tester.pump();

    expect(controller.disconnects, 1);
    expect(find.text('Disconnecting Discogs…'), findsOneWidget);
  });

  testWidgets('does not expose developer reset controls', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discogsConfigProvider.overrideWithValue(const DiscogsConfig()),
          discogsAccountProvider.overrideWithValue(
            const AsyncData<DiscogsAccount?>(null),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('developer-settings-heading')), findsNothing);
    expect(find.byKey(const Key('developer-test-nfc-tap')), findsNothing);
    expect(find.byKey(const Key('developer-reset-local-data')), findsNothing);
    expect(find.text('Developer'), findsNothing);
    expect(find.text('Reset local app data'), findsNothing);
  });
}

class _ResumeAuthorizationController extends DiscogsAuthorizationController {
  int checks = 0;

  @override
  DiscogsAuthorizationState build() =>
      const DiscogsAuthorizationState.awaitingCallback();

  @override
  Future<void> checkAuthorization() async {
    checks++;
    state = const DiscogsAuthorizationState.idle();
  }
}

class _ActionAuthorizationController extends DiscogsAuthorizationController {
  int checks = 0;
  int disconnects = 0;

  @override
  DiscogsAuthorizationState build() => const DiscogsAuthorizationState.idle();

  @override
  Future<void> checkAuthorization() async {
    checks++;
    state = const DiscogsAuthorizationState.completing();
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    state = const DiscogsAuthorizationState.disconnecting();
  }
}

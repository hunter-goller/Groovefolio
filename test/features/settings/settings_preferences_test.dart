import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/settings/widgets/settings_preferences.dart';
import 'package:vinyl_app/services/app_info_service.dart';
import 'package:vinyl_app/theme/theme_preference_store.dart';
import 'package:vinyl_app/theme/theme_provider.dart';

class MemoryThemeStore implements ThemePreferenceStore {
  String? value;
  Completer<String?>? pendingRead;
  bool failWrite = false;
  @override
  Future<String?> read() => pendingRead?.future ?? Future.value(value);
  @override
  Future<void> write(String next) async {
    if (failWrite) {
      throw StateError('storage unavailable');
    }
    value = next;
  }
}

void main() {
  testWidgets('privacy and support open the release destinations', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themePreferenceStoreProvider.overrideWithValue(MemoryThemeStore()),
          appBuildInfoProvider.overrideWith(
            (ref) async => const AppBuildInfo('1.0.0', '1'),
          ),
          settingsLinkLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SettingsPreferences()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.https('groovefolio.app', '/privacy/')]);
    await tester.ensureVisible(find.text('Support'));
    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email support'));
    await tester.pumpAndSettle();
    expect(
      opened.last,
      Uri(scheme: 'mailto', path: 'support.groovefolio@gmail.com'),
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'theme persists across containers and late reads cannot undo selection',
    () async {
      final store = MemoryThemeStore()..pendingRead = Completer<String?>();
      final first = ProviderContainer(
        overrides: [themePreferenceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(first.dispose);
      expect(first.read(themeModeControllerProvider), ThemeMode.system);
      await first.read(themeModeControllerProvider.notifier).useDark();
      store.pendingRead!.complete('light');
      await Future<void>.delayed(Duration.zero);
      expect(first.read(themeModeControllerProvider), ThemeMode.dark);
      store.pendingRead = null;
      final second = ProviderContainer(
        overrides: [themePreferenceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(second.dispose);
      second.read(themeModeControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(second.read(themeModeControllerProvider), ThemeMode.dark);
    },
  );

  test(
    'failed persistence reports failure and subsequent writes recover',
    () async {
      final store = MemoryThemeStore()..failWrite = true;
      final container = ProviderContainer(
        overrides: [themePreferenceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(themeModeControllerProvider.notifier);
      expect(await notifier.useDark(), isFalse);
      expect(container.read(themeModeControllerProvider), ThemeMode.dark);
      store.failWrite = false;
      final writes = [notifier.useLight(), notifier.useSystem()];
      expect(await Future.wait(writes), [true, true]);
      expect(store.value, 'system');
    },
  );

  testWidgets(
    'large text shows actual version, defers export and handles link failure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themePreferenceStoreProvider.overrideWithValue(MemoryThemeStore()),
            appBuildInfoProvider.overrideWith(
              (ref) async => const AppBuildInfo('2.3.4', '56'),
            ),
            supportEmailProvider.overrideWithValue(null),
            privacyPolicyUrlProvider.overrideWithValue(null),
            settingsLinkLauncherProvider.overrideWithValue(
              (uri) async => false,
            ),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(child: SettingsPreferences()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Version 2.3.4 (build 56)'), findsOneWidget);
      expect(find.text('Export collection'), findsNothing);
      final privacy = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Privacy policy'),
      );
      expect(privacy.enabled, isFalse);
      await tester.ensureVisible(find.text('Groovefolio website'));
      await tester.tap(find.text('Groovefolio website'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t open the link. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

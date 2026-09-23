import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/services/nfc/nfc_platform_adapter.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  test('store links only accept approved HTTPS destinations', () {
    expect(
      isAllowedNfcStoreUrl(Uri.parse('https://groovefolio.app/nfc-tags')),
      isTrue,
    );
    expect(
      isAllowedNfcStoreUrl(
        Uri.parse('https://www.amazon.com/dp/B012345678?tag=example-20'),
      ),
      isTrue,
    );
    for (final url in [
      'http://groovefolio.app/nfc-tags',
      'https://groovefolio.app.evil.test/nfc-tags',
      'https://user@groovefolio.app/nfc-tags',
      'https://groovefolio.app:8443/nfc-tags',
      'https://groovefolio.app/nfc-tags?redirect=https://evil.test',
      'https://www.amazon.com/redirect?url=https://evil.test',
      'https://www.amazon.com/dp/B012345678?tag=a&tag=b',
    ]) {
      expect(isAllowedNfcStoreUrl(Uri.parse(url)), isFalse, reason: url);
    }
  });

  for (final state in NfcAvailabilityState.values) {
    testWidgets('help visibility for $state and disabled rollout', (
      tester,
    ) async {
      for (final enabled in [true, false]) {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              nfcHelpEnabledProvider.overrideWithValue(enabled),
              nfcAvailabilityProvider.overrideWith((ref) async => state),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: NfcHelpButton()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final visible = enabled && state != NfcAvailabilityState.unsupported;
        expect(
          find.text('NFC help & tags'),
          visible ? findsOneWidget : findsNothing,
        );
        if (visible) {
          await tester.tap(find.text('NFC help & tags'));
          await tester.pumpAndSettle();
          expect(
            find.text('Tap a record. Remember the listen.'),
            findsOneWidget,
          );
          if (state == NfcAvailabilityState.disabled) {
            expect(find.textContaining('NFC is switched off.'), findsOneWidget);
          }
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.text('Tap a record. Remember the listen.'), findsNothing);
        }
      }
    });
  }

  testWidgets('offline help has no purchase CTA and supports large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nfcAvailabilityProvider.overrideWith(
            (ref) async => NfcAvailabilityState.available,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const NfcHelpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('never directly to the vinyl record'),
      300,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('never directly to the vinyl record'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Tag store'), 400);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Verified product links are coming soon'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nfc-tag-store-link')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final throwsError in [true, false]) {
    testWidgets(
      'store disclosure and safe launch failure throws=$throwsError',
      (tester) async {
        final uri = Uri.parse(
          'https://www.amazon.com/dp/B012345678?tag=example-20',
        );
        final launched = <Uri>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nfcAvailabilityProvider.overrideWith(
                (ref) async => NfcAvailabilityState.available,
              ),
              nfcTagStoreUrlProvider.overrideWithValue(uri),
              nfcHelpLinkLauncherProvider.overrideWithValue((value) async {
                launched.add(value);
                if (throwsError) throw StateError('private platform details');
                return false;
              }),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const NfcHelpScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('nfc-tag-store-link')),
          300,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('nfc-tag-store-link')));
        await tester.pumpAndSettle();
        expect(
          find.text('As an Amazon Associate I earn from qualifying purchases.'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('nfc-tag-store-link')));
        await tester.pumpAndSettle();
        expect(launched, [uri]);
        expect(
          find.text('Couldn’t open the tag store. Please try again later.'),
          findsOneWidget,
        );
        expect(find.textContaining('private platform details'), findsNothing);
      },
    );
  }
}

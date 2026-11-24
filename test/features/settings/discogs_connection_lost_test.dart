import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/settings/widgets/discogs_connection_card.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, {required bool lost}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (lost) container.read(discogsConnectionLostProvider.notifier).report();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiscogsConnectionCard(
              configured: true,
              accountAsync: const AsyncData(null),
              authorization: const DiscogsAuthorizationState.idle(),
              onConnect: () async {},
              onCancel: () async {},
              onCheck: () async {},
              onDisconnect: () async {},
              onImport: () {},
              onRetryIdentity: () {},
              onClearFailure: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('explains a connection that ended while unused', (tester) async {
    await _pump(tester, lost: true);
    expect(find.byKey(const Key('discogs-connection-lost')), findsOneWidget);
    expect(find.textContaining('Your records are safe'), findsOneWidget);
    expect(find.byKey(const Key('connect-discogs-button')), findsOneWidget);
  });

  testWidgets('says nothing extra for someone who never connected', (
    tester,
  ) async {
    await _pump(tester, lost: false);
    expect(find.byKey(const Key('discogs-connection-lost')), findsNothing);
    expect(find.byKey(const Key('connect-discogs-button')), findsOneWidget);
  });
}

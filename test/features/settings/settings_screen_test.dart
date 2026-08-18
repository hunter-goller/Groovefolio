import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/settings/screens/settings_screen.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/theme/app_theme.dart';

void main() {
  testWidgets('shows connected Discogs username', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discogsConfigProvider.overrideWithValue(
            const DiscogsConfig(consumerKey: 'key', consumerSecret: 'secret'),
          ),
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
          discogsConfigProvider.overrideWithValue(
            const DiscogsConfig(consumerKey: 'key', consumerSecret: 'secret'),
          ),
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
}

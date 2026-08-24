import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/features/settings/screens/settings_screen.dart';
import 'package:vinyl_app/repositories/local_data_reset_repository.dart';
import 'package:vinyl_app/services/artwork_storage_service.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/local_data_reset_service.dart';
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

  testWidgets('developer tools can be hidden for release/profile UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discogsConfigProvider.overrideWithValue(
            const DiscogsConfig(consumerKey: 'key', consumerSecret: 'secret'),
          ),
          discogsAccountProvider.overrideWithValue(
            const AsyncData<DiscogsAccount?>(null),
          ),
          developerToolsEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('developer-settings-heading')), findsNothing);
    expect(find.byKey(const Key('developer-reset-local-data')), findsNothing);
  });

  testWidgets(
    'developer reset confirms, clears local data, and keeps Discogs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final resetRepository = _FakeLocalDataResetRepository();
      final artworkStorageService = _FakeArtworkStorageService();
      final resetService = LocalDataResetService(
        resetRepository: resetRepository,
        artworkStorageService: artworkStorageService,
      );

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
            localDataResetServiceProvider.overrideWithValue(resetService),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('developer-settings-heading')),
        findsOneWidget,
      );
      final resetTile = find.byKey(const Key('developer-reset-local-data'));
      await tester.ensureVisible(resetTile);
      await tester.pumpAndSettle();
      await tester.tap(resetTile);
      await tester.pumpAndSettle();

      expect(find.text('Reset local app data?'), findsOneWidget);
      expect(
        find.textContaining('Discogs account connection is kept'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('developer-reset-confirm')));
      await tester.pumpAndSettle();

      expect(resetRepository.clearCalls, 1);
      expect(artworkStorageService.clearCalls, 1);
      expect(find.text('Connected as hunter'), findsOneWidget);
      expect(
        find.text('Local app data reset. Discogs connection kept.'),
        findsOneWidget,
      );
    },
  );
}

class _FakeLocalDataResetRepository implements ILocalDataResetRepository {
  int clearCalls = 0;

  @override
  Future<void> clearCollectionData() async {
    clearCalls += 1;
  }
}

class _FakeArtworkStorageService extends ArtworkStorageService {
  int clearCalls = 0;

  @override
  Future<void> clearAllArtwork() async {
    clearCalls += 1;
  }
}

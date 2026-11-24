import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/features/settings/widgets/discogs_connection_card.dart';
import 'package:vinyl_app/features/settings/widgets/settings_preferences.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Hosts optional Discogs connection, walkthrough replay, app preferences, and
/// help links.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(discogsAuthorizationControllerProvider).isAwaitingCallback) {
      // One check per browser return, with no background polling. The
      // controller also coalesces a simultaneous deep-link verification.
      unawaited(
        ref
            .read(discogsAuthorizationControllerProvider.notifier)
            .checkAuthorization(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final config = ref.watch(discogsConfigProvider);
    final authorization = ref.watch(discogsAuthorizationControllerProvider);
    final pauseAccountLookup =
        authorization.status == DiscogsAuthorizationStatus.completing ||
        authorization.status == DiscogsAuthorizationStatus.disconnecting ||
        authorization.status == DiscogsAuthorizationStatus.failed;
    final accountAsync = pauseAccountLookup
        ? const AsyncLoading<DiscogsAccount?>()
        : ref.watch(discogsAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.all(tokens.space16),
          children: [
            Text(
              'Integrations',
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: tokens.space12),
            DiscogsConnectionCard(
              configured: config.isConfigured,
              accountAsync: accountAsync,
              authorization: authorization,
              onConnect: () => ref
                  .read(discogsAuthorizationControllerProvider.notifier)
                  .connect(),
              onCheck: () => ref
                  .read(discogsAuthorizationControllerProvider.notifier)
                  .checkAuthorization(),
              onCancel: () => ref
                  .read(discogsAuthorizationControllerProvider.notifier)
                  .cancelAuthorization(),
              onDisconnect: () => ref
                  .read(discogsAuthorizationControllerProvider.notifier)
                  .disconnect(),
              onImport: () => context.push(AppRoutes.discogsCollectionImport),
              onRetryIdentity: () => ref
                  .read(discogsAuthorizationControllerProvider.notifier)
                  .checkAuthorization(),
              onClearFailure: () => ref
                  .read(discogsAuthorizationControllerProvider.notifier)
                  .clearFailure(),
            ),
            SizedBox(height: tokens.space24),
            Text(
              'Help',
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: tokens.space12),
            Card(
              child: ListTile(
                key: const Key('settings-getting-started'),
                contentPadding: EdgeInsets.all(tokens.space16),
                leading: const Icon(Icons.album_rounded),
                title: const Text('Getting started'),
                subtitle: Text(switch (ref.watch(tutorialViewProvider).value) {
                  final view? when view.isGold =>
                    'Gold record · ${view.badges.length} badges',
                  final view? =>
                    '${view.requiredDone} of ${view.required.length} tracks · '
                        '${view.badges.length} badges',
                  null => 'Learn the app, one track at a time.',
                }),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.tutorial),
              ),
            ),
            if (ref.watch(nfcHelpVisibleProvider))
              Card(
                child: ListTile(
                  key: const Key('settings-nfc-help'),
                  leading: const Icon(Icons.nfc_rounded),
                  title: const Text('NFC help & tags'),
                  subtitle: const Text(
                    'Link tags, log listens, and troubleshoot taps.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.nfcHelp),
                ),
              ),
            const SettingsPreferences(),
          ],
        ),
      ),
    );
  }
}

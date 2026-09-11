import 'package:vinyl_app/features/settings/widgets/discogs_connection_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/features/settings/widgets/settings_preferences.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/providers/track_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/local_data_reset_service.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

final developerToolsEnabledProvider = Provider<bool>((ref) => kDebugMode);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isResettingLocalData = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final config = ref.watch(discogsConfigProvider);
    final accountAsync = ref.watch(discogsAccountProvider);
    final authorization = ref.watch(discogsAuthorizationControllerProvider);
    final showDeveloperTools = ref.watch(developerToolsEnabledProvider);

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
              onCancel: () => ref
                  .read(discogsAuthorizationControllerProvider.notifier)
                  .cancelAuthorization(),
              onDisconnect: () => ref
                  .read(discogsAuthorizationControllerProvider.notifier)
                  .disconnect(),
              onImport: () => context.push(AppRoutes.discogsCollectionImport),
              onRetryIdentity: () => ref.invalidate(discogsAccountProvider),
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
                key: const Key('replay-onboarding'),
                contentPadding: EdgeInsets.all(tokens.space16),
                leading: const Icon(Icons.school_outlined),
                title: const Text('Replay getting started'),
                subtitle: const Text(
                  'Review how to build your shelf, log plays, and use Groovefolio.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.onboarding),
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
            if (showDeveloperTools) ...[
              SizedBox(height: tokens.space24),
              Text(
                'Developer',
                key: const Key('developer-settings-heading'),
                style: context.theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: tokens.space12),
              _DeveloperToolsCard(
                isResetting: _isResettingLocalData,
                onReset: _confirmResetLocalData,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset local app data?'),
        content: const Text(
          'This clears your local collection, play history, genres, NFC '
          'associations, Discogs release links, tracklists, and album artwork. '
          'Your Discogs account connection is kept so you can import again. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            key: const Key('developer-reset-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('developer-reset-confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset data'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isResettingLocalData = true);
    try {
      await ref.read(localDataResetServiceProvider).reset();

      ref.read(collectionFiltersProvider.notifier).reset();
      ref.invalidate(albumsProvider);
      ref.invalidate(albumSearchProvider);
      ref.invalidate(albumProvider);
      ref.invalidate(albumDetailProvider);
      ref.invalidate(playCountProvider);
      ref.invalidate(recentlyPlayedProvider);
      ref.invalidate(genresProvider);
      ref.invalidate(albumGenresProvider);
      ref.invalidate(albumTracksProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local app data reset. Discogs connection kept.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t reset local data: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResettingLocalData = false);
      }
    }
  }
}

class _DeveloperToolsCard extends StatelessWidget {
  const _DeveloperToolsCard({required this.isResetting, required this.onReset});

  final bool isResetting;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Card(
      child: Column(
        children: [
          ListTile(
            key: const Key('developer-reset-local-data'),
            enabled: !isResetting,
            contentPadding: EdgeInsets.all(tokens.space16),
            leading: isResetting
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.delete_sweep_outlined,
                    color: context.theme.colorScheme.error,
                  ),
            title: const Text('Reset local app data'),
            subtitle: const Text(
              'Clears collection data and artwork, but keeps your Discogs login.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: isResetting ? null : () => onReset(),
          ),
        ],
      ),
    );
  }
}

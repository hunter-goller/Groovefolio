import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final config = ref.watch(discogsConfigProvider);
    final accountAsync = ref.watch(discogsAccountProvider);
    final authorization = ref.watch(discogsAuthorizationControllerProvider);

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
            _DiscogsConnectionCard(
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
          ],
        ),
      ),
    );
  }
}

class _DiscogsConnectionCard extends StatelessWidget {
  const _DiscogsConnectionCard({
    required this.configured,
    required this.accountAsync,
    required this.authorization,
    required this.onConnect,
    required this.onCancel,
    required this.onDisconnect,
    required this.onImport,
    required this.onRetryIdentity,
    required this.onClearFailure,
  });

  final bool configured;
  final AsyncValue<DiscogsAccount?> accountAsync;
  final DiscogsAuthorizationState authorization;
  final Future<void> Function() onConnect;
  final Future<void> Function() onCancel;
  final Future<void> Function() onDisconnect;
  final VoidCallback onImport;
  final VoidCallback onRetryIdentity;
  final VoidCallback onClearFailure;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.album_outlined,
                  color: context.theme.colorScheme.primary,
                ),
                SizedBox(width: tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discogs',
                        style: context.theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: tokens.space4),
                      Text(
                        'Connect your account for Discogs-powered metadata and imports.',
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.space16),
            if (!configured)
              const _MessagePanel(
                icon: Icons.key_off_outlined,
                message:
                    'Discogs developer credentials are not configured for this build.',
              )
            else
              accountAsync.when(
                loading: () => const _LoadingRow(label: 'Checking connection…'),
                error: (error, stackTrace) => _IdentityError(
                  onRetry: onRetryIdentity,
                  onDisconnect: onDisconnect,
                ),
                data: (account) => _ConnectionBody(
                  account: account,
                  authorization: authorization,
                  onConnect: onConnect,
                  onCancel: onCancel,
                  onDisconnect: onDisconnect,
                  onImport: onImport,
                  onClearFailure: onClearFailure,
                ),
              ),
            SizedBox(height: tokens.space16),
            Divider(color: context.theme.dividerColor),
            SizedBox(height: tokens.space12),
            Text(
              'This application uses Discogs’ API but is not affiliated with, sponsored or endorsed by Discogs. '
              '“Discogs” is a trademark of Zink Media, LLC.',
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBody extends StatelessWidget {
  const _ConnectionBody({
    required this.account,
    required this.authorization,
    required this.onConnect,
    required this.onCancel,
    required this.onDisconnect,
    required this.onImport,
    required this.onClearFailure,
  });

  final DiscogsAccount? account;
  final DiscogsAuthorizationState authorization;
  final Future<void> Function() onConnect;
  final Future<void> Function() onCancel;
  final Future<void> Function() onDisconnect;
  final VoidCallback onImport;
  final VoidCallback onClearFailure;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (authorization.status == DiscogsAuthorizationStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MessagePanel(
            icon: Icons.error_outline_rounded,
            message:
                authorization.failure?.message ??
                'Discogs authorization could not be completed.',
          ),
          SizedBox(height: tokens.space12),
          Row(
            children: [
              TextButton(
                onPressed: onClearFailure,
                child: const Text('Dismiss'),
              ),
              const Spacer(),
              if (account == null)
                FilledButton.icon(
                  onPressed: () => onConnect(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => onDisconnect(),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Disconnect'),
                ),
            ],
          ),
        ],
      );
    }

    if (authorization.status == DiscogsAuthorizationStatus.completing) {
      return const _LoadingRow(label: 'Finishing Discogs connection…');
    }

    if (authorization.status == DiscogsAuthorizationStatus.disconnecting) {
      return const _LoadingRow(label: 'Disconnecting Discogs…');
    }

    if (authorization.isAwaitingCallback) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MessagePanel(
            icon: Icons.open_in_browser_rounded,
            message:
                'Finish authorization in your browser. Groovefolio will return here automatically.',
          ),
          SizedBox(height: tokens.space12),
          OutlinedButton(
            onPressed: () => onCancel(),
            child: const Text('Cancel connection'),
          ),
        ],
      );
    }

    if (account != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: context.theme.colorScheme.primary,
              ),
              SizedBox(width: tokens.space8),
              Expanded(
                child: Text(
                  'Connected as ${account!.username}',
                  key: const Key('discogs-connected-username'),
                  style: context.theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space8),
          _DiscogsDataLink(account: account!),
          SizedBox(height: tokens.space12),
          FilledButton.icon(
            key: const Key('discogs-import-collection-button'),
            onPressed: onImport,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Import Discogs collection'),
          ),
          SizedBox(height: tokens.space8),
          OutlinedButton.icon(
            onPressed: () => onDisconnect(),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Disconnect'),
          ),
        ],
      );
    }

    return FilledButton.icon(
      key: const Key('connect-discogs-button'),
      onPressed: () => onConnect(),
      icon: const Icon(Icons.link_rounded),
      label: const Text('Connect Discogs'),
    );
  }
}

class _DiscogsDataLink extends StatelessWidget {
  const _DiscogsDataLink({required this.account});

  final DiscogsAccount account;

  @override
  Widget build(BuildContext context) {
    final uri = Uri(
      scheme: 'https',
      host: 'www.discogs.com',
      pathSegments: ['user', account.username],
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: const Text('Data provided by Discogs.'),
      ),
    );
  }
}

class _IdentityError extends StatelessWidget {
  const _IdentityError({required this.onRetry, required this.onDisconnect});

  final VoidCallback onRetry;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MessagePanel(
          icon: Icons.cloud_off_rounded,
          message: 'Could not verify the saved Discogs connection.',
        ),
        SizedBox(height: tokens.space12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => onDisconnect(),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Disconnect'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: tokens.space12),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(tokens.space12),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tokens.textMuted),
          SizedBox(width: tokens.space8),
          Expanded(
            child: Text(
              message,
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vinyl_app/services/app_info_service.dart';
import 'package:vinyl_app/theme/theme_provider.dart';

final settingsLinkLauncherProvider = Provider<Future<bool> Function(Uri)>((
  ref,
) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

// Configure only after these destinations are published and reviewed.
final supportEmailProvider = Provider<String?>((ref) {
  const email = String.fromEnvironment('GROOVEFOLIO_SUPPORT_EMAIL');
  return RegExp(
        r'^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
      ).hasMatch(email)
      ? email
      : null;
});
final privacyPolicyUrlProvider = Provider<Uri?>((ref) => null);

class SettingsPreferences extends ConsumerWidget {
  const SettingsPreferences({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    try {
      if (await ref.read(settingsLinkLauncherProvider)(uri)) {
        return;
      }
    } on Object {
      // Keep platform errors out of user-facing text.
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Couldn’t open the link. Please try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    final info = ref.watch(appBuildInfoProvider);
    final policy = ref.watch(privacyPolicyUrlProvider);
    final email = ref.watch(supportEmailProvider);
    final validPolicy =
        policy != null &&
        policy.scheme == 'https' &&
        policy.host == 'groovefolio.app' &&
        policy.userInfo.isEmpty &&
        !policy.hasPort;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Theme'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ThemeMode.values
                      .map(
                        (value) => ChoiceChip(
                          label: Text(switch (value) {
                            ThemeMode.system => 'System',
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                          }),
                          selected: mode == value,
                          onSelected: (_) async {
                            final saved = await ref
                                .read(themeModeControllerProvider.notifier)
                                .setMode(value);
                            if (!saved && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Theme changed for now, but couldn’t be saved. Try again.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
                const Text('System follows your phone’s appearance setting.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Data', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.phone_android_outlined),
                title: Text('Stored on this device'),
                subtitle: Text(
                  'Your collection and play history stay here. Manage individual records from Collection. Uninstalling or clearing app data removes local records and history.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('About', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.album_outlined),
                title: const Text('Groovefolio'),
                subtitle: Text(
                  info.isLoading
                      ? 'Loading version…'
                      : info.value?.label ?? 'Version information unavailable',
                ),
                trailing: IconButton(
                  tooltip: 'Copy app information',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: info.value == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: 'Groovefolio ${info.value!.label}',
                            ),
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('App information copied.'),
                            ),
                          );
                        },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('Support'),
                subtitle: Text(
                  email ?? 'Contact details coming before release',
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Groovefolio support'),
                    scrollable: true,
                    content: Text(
                      'Include your app version, phone model, and what happened. Avoid sending passwords or your private collection.\n\n${info.value?.label ?? 'Version unavailable'}\n\n${email ?? 'A support contact will be added before public release.'}',
                    ),
                    actions: [
                      if (email != null)
                        TextButton(
                          onPressed: () => _open(
                            context,
                            ref,
                            Uri(scheme: 'mailto', path: email),
                          ),
                          child: const Text('Email support'),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: const Text('Groovefolio website'),
                subtitle: const Text('groovefolio.app'),
                onTap: () =>
                    _open(context, ref, Uri.https('groovefolio.app', '/')),
              ),
              ListTile(
                enabled: validPolicy,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                subtitle: validPolicy
                    ? null
                    : const Text('Available before public release'),
                onTap: validPolicy ? () => _open(context, ref, policy) : null,
              ),
              ListTile(
                title: const Text('Third-party notices'),
                subtitle: const Text(
                  'Licenses for components used by Groovefolio',
                ),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Groovefolio',
                  applicationVersion: info.value?.label,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Built with Flutter'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vinyl_app/services/nfc/nfc_platform_adapter.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';

/// Ships with the enabled NFC workflow; can be disabled for a staged rollout.
final nfcHelpEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment(
    'GROOVEFOLIO_NFC_HELP_ENABLED',
    defaultValue: true,
  ),
);

final nfcHelpVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(nfcHelpEnabledProvider)) return false;
  final state = ref.watch(nfcAvailabilityProvider).value;
  return state == NfcAvailabilityState.available ||
      state == NfcAvailabilityState.disabled;
});

/// Set only after the product is physically verified and the destination is
/// published. Monetized destinations additionally require Associates approval (VinylApp-130).
/// Prefer a maintained groovefolio.app page so retailer links can change there.
final nfcTagStoreUrlProvider = Provider<Uri?>((ref) => null);

bool isAllowedNfcStoreUrl(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    return false;
  }
  if (uri.host == 'groovefolio.app') {
    return uri.path == '/nfc-tags' && !uri.hasQuery;
  }
  return uri.host == 'www.amazon.com' &&
      RegExp(r'^/dp/[A-Z0-9]{10}$').hasMatch(uri.path) &&
      uri.queryParametersAll.keys.every((key) => key == 'tag') &&
      uri.queryParametersAll.values.every((values) => values.length == 1);
}

final nfcHelpLinkLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

Future<void> openNfcHelp(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const NfcHelpScreen()));

class NfcHelpButton extends ConsumerWidget {
  const NfcHelpButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(nfcHelpVisibleProvider)) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () => openNfcHelp(context),
      icon: const Icon(Icons.help_outline_rounded),
      label: const Text('NFC help & tags'),
    );
  }
}

class NfcHelpScreen extends ConsumerStatefulWidget {
  const NfcHelpScreen({super.key});

  @override
  ConsumerState<NfcHelpScreen> createState() => _NfcHelpScreenState();
}

class _NfcHelpScreenState extends ConsumerState<NfcHelpScreen>
    with WidgetsBindingObserver {
  bool _openingLink = false;

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
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(nfcAvailabilityProvider);
    }
  }

  Future<void> _openStore(Uri uri) async {
    if (_openingLink || !isAllowedNfcStoreUrl(uri)) return;
    setState(() => _openingLink = true);
    try {
      final opened = await ref.read(nfcHelpLinkLauncherProvider)(uri);
      if (!opened) throw StateError('Link unavailable');
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn’t open the tag store. Please try again later.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingLink = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(nfcHelpVisibleProvider);
    final availability = ref.watch(nfcAvailabilityProvider);
    final store = ref.watch(nfcTagStoreUrlProvider);
    final validStore = store != null && isAllowedNfcStoreUrl(store);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('NFC help & tags')),
      body: SafeArea(
        top: false,
        child: !visible
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'NFC help is unavailable on this device. You can still add records and log plays manually.',
                        textAlign: TextAlign.center,
                      ),
                      if (availability.hasError || availability.isLoading)
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(nfcAvailabilityProvider),
                          child: const Text('Check again'),
                        ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: colors.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.nfc_rounded,
                            size: 40,
                            color: colors.onPrimaryContainer,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap a record. Remember the listen.',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: colors.onPrimaryContainer),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Link a tag to a record, then tap your unlocked Android phone against it to log a full-album play. Your collection and listening history stay on this device.',
                            style: TextStyle(color: colors.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (availability.value == NfcAvailabilityState.disabled)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'NFC is switched off. Open Android Settings and search for NFC, turn it on, then return here. Manual play logging always works.',
                        ),
                      ),
                    ),
                  const _HelpSection(
                    title: '1. Choose and place a tag',
                    initiallyExpanded: true,
                    text:
                        'Use a writable NDEF-compatible NFC tag with room for a short album link. NTAG215 stickers (504 bytes of user memory) have been tested with Groovefolio on a Galaxy S22 Ultra. That does not verify every seller’s tags.\n\nChoose a sticker size that fits your sleeve and is easy to find by touch. Try it on paper first. Attach it to the sleeve or outer protector, never directly to the vinyl record. Avoid metal surfaces and keep other tags away while scanning.\n\nCompatible tags you already own are welcome. No purchase is required.',
                  ),
                  const _HelpSection(
                    title: '2. Link or replace a tag',
                    text:
                        'Save your record, then follow the Write NFC tag prompt. For a record already in your collection, open Album Details and use its NFC tag action. Hold the phone steady until the app confirms success.\n\nUse Rewrite or replace for the same record’s current tag or a fresh tag. A tag linked to another record is rejected: it must not silently transfer or log a play during writing. Use a fresh unlinked tag for the other record.\n\nIf writing fails, move the tag away, keep the error open, then choose Try again. Skip for now leaves your record saved.',
                  ),
                  const _HelpSection(
                    title: '3. Tap to log a listen',
                    text:
                        'Tap the linked tag with your unlocked phone to log one full-album play. When Groovefolio is closed or in the background, it stays out of the foreground and shows a system notification. Tap that notification to open the record without logging another play. When Groovefolio is already open, you get an in-app confirmation with Undo for ten seconds and no system notification. Tag writing and its error dialogs do not log plays.\n\nKeep the tag still, then move it away. Repeat callbacks within five seconds are ignored for that record. Different records can each log a play.\n\nTo log manually, open Log a play, select a record, choose the side and time, then press Save play. Manual Save shows only an in-app confirmation. NFC taps always log a full-album play.',
                  ),
                  const _HelpSection(
                    title: 'If a tap does not work',
                    text:
                        'Check that NFC is on and your phone is unlocked. Move the back of the phone slowly over the tag to find its antenna; placement varies by phone. Try removing a thick or metallic case. Keep only one tag near the phone.\n\nAn empty tag needs to be linked in Groovefolio first. A locked/read-only tag cannot be rewritten. If the tag points to a deleted record or data from before reinstall/reset, add the record again and relink the tag from Album Details. Reinstalling over the existing app preserves your data; uninstalling or resetting removes it.\n\nIf notifications are off, the play can still be logged. An outside-app tap shows a brief bottom-screen message instead. Errors also use a brief message outside the app and detailed guidance inside it. Check the play count before tapping again. Collection and play logging work offline; shopping links need a connection.',
                  ),
                  const _HelpSection(
                    title: 'Common questions',
                    text:
                        'Does NFC detect listening? No. Each accepted tap logs one full-album play; Groovefolio does not detect whether the record is playing.\n\nWhere is Undo? When the app is open, the confirmation offers Undo for ten seconds. Outside-app notifications do not offer Undo.\n\nWhy does my phone beep again? Android may detect the tag during the five-second cooldown even though Groovefolio adds no extra play. Remove the tag and wait at least five seconds before tapping again.\n\nWhere do I enable notifications? In Android Settings, open Apps, Groovefolio, then Notifications and allow notifications. Names may vary by phone.\n\nWhat if I change phones or lose my collection? Tags refer to records in this installation. If those records are missing, add them again and relink the tags.',
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tag store',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/help/tested-ntag215.jpg',
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              semanticLabel:
                                  'Product listing photo of round adhesive NFC tags',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tested tags: Timeskey NFC NTAG215, 10-pack',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tested with Groovefolio on a Galaxy S22 Ultra. '
                            'Product listing: B0GFMTFQT1. Listing photo supplied by the seller; '
                            'appearance and pack options may vary. Compatible tags you already own also work.',
                          ),
                          const SizedBox(height: 12),
                          if (!validStore)
                            const Text(
                              'Verified product links are coming soon. You can use compatible tags you already own.',
                            ),
                          if (validStore) ...[
                            const Text(
                              'As an Amazon Associate I earn from qualifying purchases.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const Key('nfc-tag-store-link'),
                              onPressed: _openingLink
                                  ? null
                                  : () => _openStore(store),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(
                                store.host == 'www.amazon.com'
                                    ? 'Buy on Amazon (affiliate link)'
                                    : 'View tested tags (affiliate links)',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.title,
    required this.text,
    this.initiallyExpanded = false,
  });
  final String title;
  final String text;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(title),
      initiallyExpanded: initiallyExpanded,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [Text(text)],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';

/// Reserves space for guidance instead of covering forms, navigation or toasts.
/// The nested navigator stays mounted while the guide starts and finishes.
class WalkthroughFrame extends ConsumerWidget {
  const WalkthroughFrame({super.key, required this.child, required this.path});
  final Widget child;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(walkthroughProvider);
    ref.listen(walkthroughProvider, (previous, next) {
      if (!next.active || next.busy || next.error || previous == null) return;
      if (previous.active &&
          (previous.busy ||
              next.step != previous.step ||
              next.albumId != previous.albumId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted &&
              identical(ref.read(walkthroughProvider), next)) {
            context.go(next.route);
          }
        });
      }
    });
    return Column(
      children: [
        if (guide.active && path != AppRoutes.onboarding)
          _GuidePanel(path: path),
        Expanded(child: child),
      ],
    );
  }
}

class _GuidePanel extends ConsumerWidget {
  const _GuidePanel({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(walkthroughProvider);
    final controller = ref.read(walkthroughProvider.notifier);
    final connected =
        guide.step == 0 && ref.watch(discogsAccountProvider).value != null;
    final nfcVisible = guide.step == 4 && ref.watch(nfcHelpVisibleProvider);
    final onCollection = path == AppRoutes.collection;
    final onStats = path == AppRoutes.stats;
    final title = switch (guide.step) {
      0 =>
        connected ? 'Discogs connected' : 'Connect Discogs, or start offline',
      1 => 'Add a record to your shelf',
      2 => 'Open a record',
      3 => 'Log your listen',
      4 => 'Optional: link an NFC tag',
      5 =>
        guide.practiced
            ? 'Those are your record actions'
            : 'Try swiping a record left',
      6 =>
        onStats ? 'Your listening, in Stats' : 'See what your listen changed',
      _ => 'Find your next listen',
    };
    final message = switch (guide.step) {
      0 =>
        path == AppRoutes.discogsCollectionImport
            ? 'Choose the records you want and tap Import. After reviewing the result, tap View collection.'
            : connected
            ? 'Tap Import Discogs collection in Settings, or choose Add manually below.'
            : 'In Settings below, tap Connect Discogs. Your browser will open; approve access and return here. Not now takes you to manual entry.',
      1 =>
        path == AppRoutes.addAlbum
            ? 'Enter a title and artist, or use Discogs search or Scan barcode. Tap Save when ready; this adds a real record.'
            : 'Tap the outlined Add record control below. Already have a record? Choose Use existing record.',
      2 =>
        'Tap a record below to open Album Details. If your shelf is empty, add one first or skip this step.',
      3 =>
        onCollection
            ? 'Choose a record below to continue with logging a listen.'
            : 'Tap the outlined Log play button. Choose a full album or side and save. This records a real listen.',
      4 =>
        !nfcVisible
            ? 'NFC is optional. If this phone supports it, enable NFC in Android settings; otherwise choose Not now.'
            : onCollection
            ? 'Choose a record below, then use its Record actions menu to link a tag.'
            : 'Open the outlined Record actions menu and choose Link NFC tag. Hold a writable tag to your phone. You can skip this.',
      5 =>
        path.endsWith('/edit')
            ? 'This is the real edit form. Change any details you want and save, or go Back to keep them unchanged.'
            : guide.practiced
            ? 'Tap Edit to open the real edit form. Delete is a safe practice tap in this step; it will not remove a record. Choose Continue when ready.'
            : 'Swipe left on an outlined record to reveal Edit and Delete. You can try editing; Delete is a safe practice tap during this step.',
      6 =>
        onStats
            ? 'This is your real play history. Explore the trends, then tap the outlined Discover tab.'
            : 'Tap the outlined Stats tab at the bottom. If you skipped logging, you’ll see its empty state.',
      _ =>
        'Discover uses your collection and listening history to suggest records. With little history, suggestions may be limited. Your walkthrough is complete.',
    };
    final intended = switch (guide.step) {
      0 =>
        path == AppRoutes.settings || path == AppRoutes.discogsCollectionImport,
      1 =>
        onCollection ||
            path == AppRoutes.addAlbum ||
            path == AppRoutes.barcodeScan,
      2 || 5 =>
        onCollection ||
            (guide.step == 2 && path == AppRoutes.addAlbum) ||
            (guide.step == 5 && path.endsWith('/edit')),
      3 =>
        onCollection || path.startsWith('/album/') || path == AppRoutes.logPlay,
      4 =>
        onCollection || path.startsWith('/album/') || path == AppRoutes.nfcHelp,
      6 => onCollection || onStats,
      _ => path == AppRoutes.discover,
    };
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.32,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Walkthrough ${guide.step + 1}/8 · $title',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      key: const Key('guide-exit'),
                      tooltip: 'Exit guide',
                      onPressed: guide.busy
                          ? null
                          : () async {
                              final replay = guide.replay;
                              if (await controller.finish() &&
                                  context.mounted) {
                                context.go(
                                  replay
                                      ? AppRoutes.settings
                                      : AppRoutes.collection,
                                );
                              }
                            },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  intended
                      ? message
                      : 'You’re exploring another screen. Return to the guide when you’re ready.',
                ),
                if (guide.error)
                  const Text(
                    'Your app action is kept, but guide progress could not be saved. Retry to continue.',
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (guide.error)
                      TextButton(
                        key: const Key('guide-retry'),
                        onPressed: controller.retry,
                        child: const Text('Retry saving progress'),
                      )
                    else if (!intended)
                      TextButton(
                        onPressed: () => context.go(guide.route),
                        child: const Text('Return to guide'),
                      )
                    else if (guide.step == 5 && guide.practiced && onCollection)
                      FilledButton(
                        onPressed: guide.busy ? null : () => controller.move(6),
                        child: const Text('Continue'),
                      )
                    else if (guide.step == 7)
                      FilledButton(
                        key: const Key('guide-finish'),
                        onPressed: guide.busy
                            ? null
                            : () async {
                                final replay = guide.replay;
                                if (await controller.finish() &&
                                    context.mounted &&
                                    replay) {
                                  context.go(AppRoutes.settings);
                                }
                              },
                        child: const Text('Finish walkthrough'),
                      ),
                    if (guide.step < 7 && !guide.error)
                      TextButton(
                        key: const Key('guide-skip-step'),
                        onPressed: guide.busy ? null : controller.skipStep,
                        child: Text(
                          guide.step == 0
                              ? connected
                                    ? 'Add manually'
                                    : 'Not now'
                              : guide.step == 4
                              ? 'Not now'
                              : 'Skip step',
                        ),
                      ),
                    if (guide.step == 1 && onCollection && !guide.error)
                      TextButton(
                        onPressed: guide.busy ? null : () => controller.move(2),
                        child: const Text('Use existing record'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

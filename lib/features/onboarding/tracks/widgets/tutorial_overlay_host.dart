import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/spotlight_overlay.dart';
import 'package:vinyl_app/features/onboarding/tracks/track_launcher.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_session.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/tutorial_visuals.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Wraps every screen: the spotlight while a track is playing, and the
/// "Track complete" celebration when one finishes.
class TutorialOverlayHost extends ConsumerWidget {
  const TutorialOverlayHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celebrating = ref.watch(tutorialSessionProvider).celebrating;
    return Stack(
      children: [
        child,
        const Positioned.fill(child: SpotlightOverlay()),
        if (celebrating != null)
          Positioned.fill(child: _TrackComplete(track: celebrating)),
      ],
    );
  }
}

class _TrackComplete extends ConsumerWidget {
  const _TrackComplete({required this.track});
  final TutorialTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(tutorialViewProvider).value;
    final session = ref.read(tutorialSessionProvider.notifier);
    final colors = context.theme.colorScheme;
    final tokens = context.tokens;
    final text = context.theme.textTheme;
    final showGold = view != null && view.isGold && !view.goldCelebrated;
    final next = view?.next;
    final total = view?.required.length ?? 1;
    final done = view?.requiredDone ?? 0;

    void close() => session.dismissCelebration();

    return Stack(
      children: [
        Positioned.fill(
          child: ModalBarrier(color: Colors.black.withValues(alpha: 0.55)),
        ),
        const Positioned.fill(child: Confetti()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(28),
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'TRACK ${track.number} COMPLETE',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    BadgeMedal(track: track, size: 112, glow: true),
                    const SizedBox(height: 16),
                    Text(
                      'Badge unlocked',
                      style: text.labelLarge?.copyWith(color: tokens.textMuted),
                    ),
                    Text(
                      track.badge,
                      key: const Key('track-complete-badge'),
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!track.optional) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          RecordProgress(done: done, total: total, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$done of $total tracks played',
                              style: text.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        key: const Key('track-complete-next'),
                        onPressed: () {
                          close();
                          if (showGold) {
                            context.push(AppRoutes.tutorialGold);
                          } else if (next != null) {
                            startTrack(context, ref, next);
                          } else {
                            context.go(AppRoutes.tutorial);
                          }
                        },
                        icon: Icon(
                          showGold
                              ? Icons.emoji_events_rounded
                              : Icons.skip_next_rounded,
                        ),
                        label: Text(
                          showGold
                              ? 'See your gold record'
                              : next != null
                              ? 'Next: ${next.title}'
                              : 'See your tracks',
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('track-complete-shelf'),
                      onPressed: () {
                        close();
                        context.go(AppRoutes.collection);
                      },
                      child: const Text('Back to my shelf'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

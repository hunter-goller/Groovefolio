import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/track_launcher.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/tutorial_visuals.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/widgets/ui/app_error_state.dart';

/// Getting started: progress, badges, and every track playable in any order.
class TracklistScreen extends ConsumerWidget {
  const TracklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(tutorialViewProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Getting started')),
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AppErrorState(
          title: 'Couldn’t load your tracks',
          message: 'Try again in a moment.',
          error: error,
          stackTrace: stackTrace,
          operation: 'load tutorial tracks',
          onRetry: () => ref.invalidate(tutorialProgressProvider),
        ),
        data: (view) => _Tracklist(view: view),
      ),
    );
  }
}

class _Tracklist extends ConsumerWidget {
  const _Tracklist({required this.view});
  final TutorialView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = context.theme.textTheme;
    final total = view.required.length;
    Widget side(String label, Iterable<TutorialTrack> tracks) {
      final list = tracks.where(view.tracks.contains).toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(
              label,
              style: text.labelLarge?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: tokens.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final track in list) _TrackRow(track: track, view: view),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(
          children: [
            RecordProgress(
              done: view.requiredDone,
              total: total,
              size: 112,
              gold: view.isGold,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.isGold
                        ? 'Gold record!'
                        : '${view.requiredDone} of $total tracks',
                    key: const Key('tracklist-progress'),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    view.isGold
                        ? 'You know your way around Groovefolio. Replay any track.'
                        : 'Each track you finish lights up a groove. Play them in any order.',
                    style: text.bodyMedium?.copyWith(color: tokens.textMuted),
                  ),
                  if (view.isGold)
                    TextButton(
                      onPressed: () => context.push(AppRoutes.tutorialGold),
                      child: const Text('See your gold record'),
                    ),
                ],
              ),
            ),
          ],
        ),
        side(
          'SIDE A · THE BASICS',
          TutorialTrack.values.where((t) => t.side == TutorialSide.a),
        ),
        side(
          'SIDE B · PRO MOVES',
          TutorialTrack.values.where((t) => t.side == TutorialSide.b),
        ),
        side(
          'BONUS TRACK',
          TutorialTrack.values.where((t) => t.side == TutorialSide.bonus),
        ),
        const SizedBox(height: 22),
        Text(
          'YOUR BADGES · ${view.badges.length}',
          style: text.labelLarge?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: tokens.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final track in view.tracks)
              SizedBox(
                width: 76,
                child: Column(
                  children: [
                    BadgeMedal(
                      track: track,
                      earned: view.badges.contains(track),
                    ),
                    const SizedBox(height: 4),
                    ExcludeSemantics(
                      child: Text(
                        track.badge,
                        textAlign: TextAlign.center,
                        style: text.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrackRow extends ConsumerWidget {
  const _TrackRow({required this.track, required this.view});
  final TutorialTrack track;
  final TutorialView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.theme.colorScheme;
    final tokens = context.tokens;
    final status = view.statusOf(track);
    final isNext = view.next == track;
    final done = status == TutorialTrackStatus.completed;
    final locked = status == TutorialTrackStatus.locked;
    final subtitle = switch (status) {
      TutorialTrackStatus.completed => 'Badge: ${track.badge}',
      TutorialTrackStatus.locked => 'Add a record first',
      TutorialTrackStatus.available =>
        track.optional ? '${trackBlurb(track)} · optional' : trackBlurb(track),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: isNext
            ? BorderSide(color: colors.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        key: Key('track-${track.name}'),
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? colors.primary : tokens.surfaceElevated,
          ),
          child: Icon(
            done
                ? Icons.check_rounded
                : locked
                ? Icons.lock_outline_rounded
                : track.icon,
            color: done
                ? colors.onPrimary
                : locked
                ? tokens.textMuted
                : colors.primary,
          ),
        ),
        title: Text(
          '${track.number}. ${track.title}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: locked
            ? null
            : isNext
            ? FilledButton(
                key: Key('track-play-${track.name}'),
                onPressed: () => startTrack(context, ref, track),
                child: const Text('Play'),
              )
            : IconButton(
                key: Key('track-play-${track.name}'),
                tooltip: done ? 'Replay ${track.title}' : 'Play ${track.title}',
                onPressed: () => startTrack(context, ref, track),
                icon: Icon(
                  done ? Icons.replay_rounded : Icons.play_arrow_rounded,
                ),
              ),
      ),
    );
  }
}

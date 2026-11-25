import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/tutorial_visuals.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// The tutorial badges, earned ones lit, on a screen people actually visit.
/// Tapping opens Getting started, where every track can be played.
class BadgeShelfCard extends ConsumerWidget {
  const BadgeShelfCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(tutorialViewProvider).value;
    if (view == null || view.tracks.isEmpty) return const SizedBox.shrink();
    final tokens = context.tokens;
    final text = context.theme.textTheme;
    final earned = view.tracks.where(view.badges.contains).length;
    final total = view.tracks.length;

    return Material(
      key: const Key('stats-badges'),
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
        side: BorderSide(color: tokens.textMuted.withValues(alpha: 0.13)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.tutorial),
        child: Padding(
          padding: EdgeInsets.all(tokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your badges',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$earned of $total',
                    style: text.labelMedium?.copyWith(color: tokens.textMuted),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tokens.textMuted),
                ],
              ),
              SizedBox(height: tokens.space12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final track in view.tracks)
                    BadgeMedal(
                      track: track,
                      size: 40,
                      earned: view.badges.contains(track),
                    ),
                ],
              ),
              SizedBox(height: tokens.space12),
              Text(
                view.isGold
                    ? 'Gold record earned. Replay any track from Getting started.'
                    : earned == 0
                    ? 'Learn Groovefolio in a few short tracks and earn badges.'
                    : 'Play the rest in Getting started.',
                style: text.bodySmall?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

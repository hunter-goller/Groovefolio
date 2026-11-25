import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/tutorial_visuals.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// The finale once every required track is done.
class GoldRecordScreen extends ConsumerStatefulWidget {
  const GoldRecordScreen({super.key});

  @override
  ConsumerState<GoldRecordScreen> createState() => _GoldRecordScreenState();
}

class _GoldRecordScreenState extends ConsumerState<GoldRecordScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(tutorialProgressProvider.notifier).markGoldCelebrated();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(tutorialViewProvider).value;
    final tokens = context.tokens;
    final text = context.theme.textTheme;
    final required = view?.required.length ?? 5;
    // Optional tracks (Discogs, NFC) earn badges too, so there can be more
    // badges than required tracks.
    final bonus = (view?.badges.length ?? 0) - required;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: Confetti()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: goldLight.withValues(alpha: 0.55),
                                blurRadius: 60,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: RecordProgress(
                            done: required,
                            total: required,
                            size: 200,
                            spin: true,
                            gold: true,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Semantics(
                          header: true,
                          child: Text(
                            'Gold record!',
                            style: text.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bonus > 0
                              ? 'You played all $required main tracks and '
                                    '${bonus == 1 ? 'a bonus one' : '$bonus bonus ones'}. '
                                    'You know your way around Groovefolio.'
                              : 'You played all $required tracks. You know your '
                                    'way around Groovefolio.',
                          key: const Key('gold-record-summary'),
                          textAlign: TextAlign.center,
                          style: text.bodyLarge?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final track
                                in view?.badges ?? const <TutorialTrack>[])
                              SizedBox(
                                width: 92,
                                child: Column(
                                  children: [
                                    BadgeMedal(track: track),
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
                        const Spacer(),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            key: const Key('gold-go-to-shelf'),
                            onPressed: () => context.go(AppRoutes.collection),
                            child: const Text(
                              'Go to my shelf',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.tutorial),
                          child: const Text('Replay any track'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/track_launcher.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/onboarding/tracks/widgets/tutorial_visuals.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// First screen on a fresh install: one vinyl, one sentence, one button.
class TutorialWelcomeScreen extends ConsumerWidget {
  const TutorialWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(tutorialViewProvider).value;
    final progress = ref.read(tutorialProgressProvider.notifier);
    final tokens = context.tokens;
    final text = context.theme.textTheme;
    final tracks = view?.tracks ?? TutorialTrack.values;
    final count = view?.required.length ?? 5;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 24,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('tutorial-welcome-skip'),
                        onPressed: () async {
                          final router = GoRouter.of(context);
                          await progress.markIntroSeen();
                          router.go(AppRoutes.collection);
                        },
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: RecordProgress(
                        done: 0,
                        total: count,
                        size: 210,
                        spin: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to\nGroovefolio',
                      textAlign: TextAlign.center,
                      style: text.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Play through $count quick tracks to learn the app, '
                      'using your real records. About 3 minutes.',
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(color: tokens.textMuted),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final track in tracks)
                          Chip(
                            avatar: Icon(
                              track.icon,
                              size: 18,
                              color: context.theme.colorScheme.primary,
                            ),
                            label: Text(track.badge),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        key: const Key('tutorial-welcome-start'),
                        onPressed: () => startTrack(
                          context,
                          ref,
                          view?.next ?? TutorialTrack.addRecord,
                          beforeStart: progress.markIntroSeen,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: const Text(
                          'Drop the needle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No account needed. Your shelf stays on this phone.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';

/// One short introduction; every subsequent step happens inside the real app.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key, this.replay = false});
  final bool replay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(walkthroughProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Getting started')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.album_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your record shelf, remembered',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Let’s set up Groovefolio together. We’ll point out '
                    'the controls as you connect Discogs, add a record and log a listen.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You’ll use your real collection. Skip any step or '
                    'exit whenever you like. No Groovefolio account is needed.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your collection stays on this device. There is no '
                    'automatic backup; uninstalling removes local data.',
                  ),
                  const SizedBox(height: 24),
                  if (guide.error)
                    const Text(
                      'Couldn’t save your progress. Please try again.',
                    ),
                  FilledButton(
                    key: const Key('guide-start'),
                    onPressed: guide.busy
                        ? null
                        : () async {
                            final controller = ref.read(
                              walkthroughProvider.notifier,
                            );
                            if (await controller.start(replay: replay) &&
                                context.mounted) {
                              context.go(ref.read(walkthroughProvider).route);
                            }
                          },
                    child: Text(
                      replay
                          ? 'Start walkthrough'
                          : 'Start or resume walkthrough',
                    ),
                  ),
                  TextButton(
                    key: const Key('onboarding-skip'),
                    onPressed: guide.busy
                        ? null
                        : () async {
                            // Replay may be dismissed without changing first-run flags.
                            if (replay) {
                              context.go(AppRoutes.settings);
                            } else if (await ref
                                    .read(walkthroughProvider.notifier)
                                    .finish() &&
                                context.mounted) {
                              context.go(AppRoutes.collection);
                            }
                          },
                    child: const Text('Explore on my own'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

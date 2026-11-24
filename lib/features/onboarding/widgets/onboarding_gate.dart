import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/tracks/screens/tutorial_welcome_screen.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

/// Welcomes a fresh install once (intro not seen and no records). A shelf
/// that already has records goes straight in; Getting started is in
/// Settings. If progress can't be read, the collection opens: onboarding is
/// never a reason to lock someone out of their records.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(tutorialViewProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) {
            logAppError('read tutorial progress', error, stackTrace);
            return child;
          },
          data: (view) => !view.introSeen && !view.hasRecord
              ? const TutorialWelcomeScreen()
              : child,
        );
  }
}

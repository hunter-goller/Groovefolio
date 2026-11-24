import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress_store.dart';

/// Tutorial progress for someone who has already seen the welcome, so
/// app-level tests open straight on the collection. Writes are kept in
/// memory.
class IntroSeenTutorialStore implements TutorialProgressStore {
  TutorialProgressData saved = const TutorialProgressData(introSeen: true);

  @override
  Future<TutorialProgressData?> read() async => saved;

  @override
  Future<void> write(TutorialProgressData data) async => saved = data;
}

Override skipTutorialWelcome() =>
    tutorialProgressStoreProvider.overrideWithValue(IntroSeenTutorialStore());

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

/// Turns on the game-style tutorial. Off by default until the spotlight
/// guide (part 3) lands; until then the old walkthrough stays in charge.
/// Try it with `--dart-define=GROOVEFOLIO_NEW_TUTORIAL=true`.
final newTutorialEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('GROOVEFOLIO_NEW_TUTORIAL'),
);

/// The track being played right now, and a finished one waiting to be
/// celebrated. Not persisted: closing the app simply ends the session.
class TutorialSessionState {
  const TutorialSessionState({this.active, this.celebrating});

  final TutorialTrack? active;
  final TutorialTrack? celebrating;
}

final tutorialSessionProvider =
    NotifierProvider<TutorialSession, TutorialSessionState>(
      TutorialSession.new,
    );

class TutorialSession extends Notifier<TutorialSessionState> {
  bool _statsSeen = false;

  @override
  TutorialSessionState build() => const TutorialSessionState();

  void play(TutorialTrack track) => state = TutorialSessionState(active: track);

  void quit() => state = const TutorialSessionState();

  void dismissCelebration() =>
      state = TutorialSessionState(active: state.active);

  /// Records a finished track. Only the track being played is celebrated;
  /// doing something outside the tutorial earns the badge quietly.
  Future<void> trackDone(TutorialTrack track) async {
    await ref.read(tutorialProgressProvider.notifier).complete(track);
    if (state.active == track) {
      state = TutorialSessionState(celebrating: track);
    }
  }

  /// Re-reads the shelf so locks and data-proven tracks stay current.
  Future<void> shelfChanged() =>
      ref.read(tutorialProgressProvider.notifier).refreshEvidence();

  void statsViewed() => _statsSeen = true;

  /// "Check your stats" finishes on Discover, after looking at Stats.
  Future<void> discoverViewed() async {
    if (_statsSeen) await trackDone(TutorialTrack.stats);
  }
}

/// What the app reports to the tutorial. Every call is fire-and-forget and
/// does nothing while the new tutorial is switched off, so existing screens
/// behave exactly as before.
enum TutorialEvent {
  recordAdded,
  playLogged,
  nfcLinked,
  swiped,
  statsViewed,
  discoverViewed,
  discogsImported,
}

extension TutorialEvents on WidgetRef {
  void tutorialEvent(TutorialEvent event, {int imported = 0}) {
    if (!read(newTutorialEnabledProvider)) return;
    final session = read(tutorialSessionProvider.notifier);
    Future<void> run() async {
      switch (event) {
        case TutorialEvent.recordAdded:
          await session.shelfChanged();
          await session.trackDone(TutorialTrack.addRecord);
        case TutorialEvent.playLogged:
          await session.shelfChanged();
          await session.trackDone(TutorialTrack.logSpin);
        case TutorialEvent.nfcLinked:
          await session.shelfChanged();
          await session.trackDone(TutorialTrack.nfc);
        case TutorialEvent.swiped:
          await session.trackDone(TutorialTrack.swipe);
        case TutorialEvent.statsViewed:
          session.statsViewed();
        case TutorialEvent.discoverViewed:
          await session.discoverViewed();
        case TutorialEvent.discogsImported:
          await session.shelfChanged();
          await session.trackDone(TutorialTrack.discogsImport);
          if (imported > 0) await session.trackDone(TutorialTrack.addRecord);
      }
    }

    unawaited(
      run().catchError((Object error, StackTrace stackTrace) {
        logAppError('record tutorial progress', error, stackTrace);
      }),
    );
  }
}

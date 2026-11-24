import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/spotlight_target.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/track_scripts.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

/// The track being played, its current step, and a finished track waiting
/// to be celebrated. Not persisted: closing the app simply ends the session.
class TutorialSessionState {
  const TutorialSessionState({
    this.active,
    this.step = 0,
    this.path = ShelfPath.byHand,
    this.home,
    this.celebrating,
  });

  final TutorialTrack? active;
  final int step;
  final ShelfPath path;

  /// Where the track started; "Show me" returns here.
  final String? home;
  final TutorialTrack? celebrating;

  List<TrackStep> get script =>
      active == null ? const [] : trackScript(active!, path: path);

  /// Null when the track has no script or every step has been passed.
  TrackStep? get currentStep {
    final steps = script;
    return step < steps.length ? steps[step] : null;
  }
}

final tutorialSessionProvider =
    NotifierProvider<TutorialSession, TutorialSessionState>(
      TutorialSession.new,
    );

class TutorialSession extends Notifier<TutorialSessionState> {
  bool _statsSeen = false;

  @override
  TutorialSessionState build() => const TutorialSessionState();

  void play(
    TutorialTrack track, {
    ShelfPath path = ShelfPath.byHand,
    String? home,
  }) => state = TutorialSessionState(active: track, path: path, home: home);

  /// Back to the first step, for "Show me".
  void restart() => state = TutorialSessionState(
    active: state.active,
    path: state.path,
    home: state.home,
  );

  /// Ends the track without a badge. It can be replayed from Getting started.
  void quit() => state = const TutorialSessionState();

  void dismissCelebration() => state = TutorialSessionState(
    active: state.active,
    step: state.step,
    path: state.path,
    home: state.home,
  );

  void _goTo(int step) => state = TutorialSessionState(
    active: state.active,
    step: step,
    path: state.path,
    home: state.home,
  );

  /// An event-driven step happened (for example the row was swiped).
  void stepEvent(SpotlightId target) {
    final current = state.currentStep;
    if (current == null || current.advance != StepAdvance.event) return;
    if (current.targets.contains(target)) advance();
  }

  /// True while the swipe track is being played, so Delete is practice.
  bool get practisingDelete => state.active == TutorialTrack.swipe;

  /// Moves to the next step ("Got it", or an event-driven step).
  void advance() {
    if (state.active == null) return;
    if (state.step < state.script.length) _goTo(state.step + 1);
  }

  /// Follows the user if they got ahead: e.g. a later step's control is on
  /// screen while the current one isn't. Never moves backwards.
  void jumpTo(int step) {
    if (state.active == null || step <= state.step) return;
    if (step < state.script.length) _goTo(step);
  }

  /// A tagged control was tapped. Moves on if it's the current step's.
  void targetTapped(SpotlightId id) {
    final current = state.currentStep;
    if (current == null || current.advance != StepAdvance.tap) return;
    if (current.targets.contains(id)) advance();
  }

  /// Discogs isn't reachable or wanted: fill the shelf by hand instead.
  void switchToByHand() {
    if (state.active != TutorialTrack.addRecord) return;
    state = const TutorialSessionState(active: TutorialTrack.addRecord);
  }

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

/// What the app reports to the tutorial. Every call is fire-and-forget, and
/// failures are logged, never shown: the tutorial must not break a screen.
enum TutorialEvent {
  recordAdded,
  playLogged,
  nfcLinked,
  swiped,
  statsViewed,
  discoverViewed,
  discogsImported,
  practiceDelete,
  backupSaved,
}

extension TutorialEvents on WidgetRef {
  void tutorialEvent(TutorialEvent event, {int imported = 0}) {
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
          // While practising, the swipe only moves on to "try Delete";
          // otherwise, swiping for real earns the badge quietly.
          if (session.practisingDelete) {
            session.stepEvent(SpotlightId.firstRecordRow);
          } else {
            await session.trackDone(TutorialTrack.swipe);
          }
        case TutorialEvent.practiceDelete:
          await session.trackDone(TutorialTrack.swipe);
        case TutorialEvent.backupSaved:
          await session.trackDone(TutorialTrack.backup);
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

import 'package:vinyl_app/features/onboarding/tracks/spotlight/spotlight_target.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';

enum SpotlightGesture { tap, swipe, field, none }

/// How a step moves on to the next one.
enum StepAdvance {
  /// The user taps the spotlighted control.
  tap,

  /// The user presses "Got it" in the bubble (look-only steps).
  gotIt,

  /// Something else happens, reported by the app (for example a swipe).
  event,

  /// The last step: the track's completion event finishes it.
  completion,
}

/// One instruction in a track: which control to spotlight and what to say.
class TrackStep {
  const TrackStep({
    required this.targets,
    required this.title,
    required this.body,
    this.gesture = SpotlightGesture.tap,
    this.advance = StepAdvance.tap,
    this.dim = true,
    this.skippable = false,
    this.padding = 8,
  });

  /// The first of these that is on screen is spotlighted (for example the
  /// Add record button, or the empty-shelf button when there are none).
  final List<SpotlightId> targets;
  final String title;
  final String body;
  final SpotlightGesture gesture;
  final StepAdvance advance;

  /// False for steps inside menus or sheets, which dim the screen themselves.
  final bool dim;

  /// If a later step's control is already on screen, move on without this
  /// one (for example the user opened Add record some other way).
  final bool skippable;

  /// Space around the control that's lit and tappable, for controls whose
  /// tappable area is bigger than what's tagged (a tab's label).
  final double padding;
}

/// How Track 1 fills the shelf.
enum ShelfPath { byHand, discogs }

/// The steps for [track]. Short on purpose: one idea per step.
List<TrackStep> trackScript(
  TutorialTrack track, {
  ShelfPath path = ShelfPath.byHand,
}) => switch (track) {
  TutorialTrack.addRecord when path == ShelfPath.discogs => const [
    TrackStep(
      targets: [SpotlightId.discogsConnect],
      skippable: true,
      title: 'Connect Discogs',
      body:
          'Tap Connect Discogs and approve in your browser. Then come back '
          'here.',
    ),
    TrackStep(
      targets: [SpotlightId.discogsImport],
      title: 'Import your collection',
      body: 'Connected! Tap Import Discogs collection.',
    ),
    TrackStep(
      targets: [SpotlightId.discogsImportSelected],
      title: 'Pick what to bring in',
      body: 'Untick anything you don’t own any more, then tap Import.',
      advance: StepAdvance.completion,
    ),
  ],
  TutorialTrack.addRecord => const [
    TrackStep(
      targets: [SpotlightId.addRecordFab, SpotlightId.addRecordEmpty],
      skippable: true,
      title: 'Add your first record',
      body: 'Tap Add record.',
    ),
    TrackStep(
      targets: [SpotlightId.addTitle],
      title: 'Type the album title',
      body: 'For example, Kind of Blue.',
      gesture: SpotlightGesture.field,
    ),
    TrackStep(
      targets: [SpotlightId.addArtist],
      title: 'Add the artist',
      body: 'Who made it? A cover photo is optional.',
      gesture: SpotlightGesture.field,
    ),
    TrackStep(
      targets: [SpotlightId.addSave],
      title: 'Tap Save',
      body: 'It goes straight onto your shelf.',
      advance: StepAdvance.completion,
    ),
  ],
  TutorialTrack.logSpin => const [
    TrackStep(
      targets: [SpotlightId.logPickRecord],
      title: 'Pick a record',
      body: 'Choose one you’ve listened to.',
    ),
    TrackStep(
      targets: [SpotlightId.logSide],
      title: 'Which side?',
      body: 'Full album, Side A or Side B.',
    ),
    TrackStep(
      targets: [SpotlightId.logSave],
      title: 'Save play',
      body: 'Your listening history starts here.',
      advance: StepAdvance.completion,
    ),
  ],
  TutorialTrack.stats => const [
    TrackStep(
      targets: [SpotlightId.statsSummary],
      title: 'Your listening, at a glance',
      body:
          'Records played, total plays and plays per week. They update every '
          'time you log a spin.',
      gesture: SpotlightGesture.none,
      advance: StepAdvance.gotIt,
    ),
    TrackStep(
      targets: [SpotlightId.navDiscover],
      padding: 26,
      title: 'Now tap Discover',
      body: 'It suggests what to play next, from your own shelf.',
      advance: StepAdvance.completion,
    ),
  ],
  // Side B scripts arrive in part 3b; until then these play unguided.
  TutorialTrack.nfc ||
  TutorialTrack.swipe ||
  TutorialTrack.backup ||
  TutorialTrack.discogsImport => const [],
};

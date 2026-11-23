import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress_store.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/features/settings/screens/nfc_help_screen.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

/// What the local data already proves the user has done.
class TutorialEvidence {
  const TutorialEvidence({
    required this.records,
    required this.plays,
    required this.nfcTags,
  });

  static const none = TutorialEvidence(records: 0, plays: 0, nfcTags: 0);

  final int records;
  final int plays;
  final int nfcTags;

  /// Tracks that count as done because the user already did the real thing.
  /// Stats, swipe and backup leave no trace in the data, so they are only
  /// completed by playing them.
  Set<TutorialTrack> get completedTracks => {
    if (records > 0) TutorialTrack.addRecord,
    if (plays > 0) TutorialTrack.logSpin,
    if (nfcTags > 0) TutorialTrack.nfc,
  };
}

Future<TutorialEvidence> readTutorialEvidence(AppDatabase db) async {
  Future<int> count(TableInfo<Table, Object?> table, Expression<int> c) =>
      (db.selectOnly(
        table,
      )..addColumns([c])).map((row) => row.read(c) ?? 0).getSingle();
  return TutorialEvidence(
    records: await count(db.albums, db.albums.id.count()),
    plays: await count(db.plays, db.plays.id.count()),
    nfcTags: await count(db.nfcTags, db.nfcTags.id.count()),
  );
}

/// Reads [TutorialEvidence] from the collection. Overridable in tests.
final tutorialEvidenceReaderProvider =
    Provider<Future<TutorialEvidence> Function()>(
      (ref) =>
          () => readTutorialEvidence(ref.read(databaseProvider)),
    );

/// Saved progress merged with evidence from the collection.
class TutorialProgressState {
  const TutorialProgressState({required this.data, required this.evidence});

  final TutorialProgressData data;
  final TutorialEvidence evidence;
}

/// Loads, merges and saves tutorial progress.
///
/// Progress is best-effort: if secure storage can't be read or written, the
/// app carries on (the tutorial just won't remember), because it must never
/// block access to the collection.
class TutorialProgressController extends AsyncNotifier<TutorialProgressState> {
  Future<void> _writes = Future.value();

  @override
  Future<TutorialProgressState> build() async {
    final store = ref.watch(tutorialProgressStoreProvider);
    var data = await _readOrMigrate(store);
    final evidence = await _readEvidence();

    final earned = data.completed.union(evidence.completedTracks);
    if (earned.length != data.completed.length) {
      data = data.copyWith(completed: earned);
      _save(data);
    }
    return TutorialProgressState(data: data, evidence: evidence);
  }

  Future<TutorialProgressData> _readOrMigrate(
    TutorialProgressStore store,
  ) async {
    try {
      final saved = await store.read();
      if (saved != null) return saved;
      final migrated = await migrateFromWalkthrough(
        ref.read(onboardingStoreProvider),
      );
      _save(migrated);
      return migrated;
    } catch (error, stackTrace) {
      logAppError('read tutorial progress', error, stackTrace);
      // Don't greet someone with the intro just because storage failed.
      return const TutorialProgressData(introSeen: true);
    }
  }

  Future<TutorialEvidence> _readEvidence() async {
    try {
      return await ref.read(tutorialEvidenceReaderProvider)();
    } catch (error, stackTrace) {
      logAppError('read tutorial evidence', error, stackTrace);
      return TutorialEvidence.none;
    }
  }

  /// Writes in order; a failed write is logged and the in-memory state kept.
  void _save(TutorialProgressData data) {
    final store = ref.read(tutorialProgressStoreProvider);
    _writes = _writes.then((_) async {
      try {
        await store.write(data);
      } catch (error, stackTrace) {
        logAppError('save tutorial progress', error, stackTrace);
      }
    });
  }

  /// Completes when every queued write has finished (used by tests).
  Future<void> get settled => _writes;

  Future<void> _update(
    TutorialProgressData Function(TutorialProgressData) change,
  ) async {
    final current = await future;
    final next = change(current.data);
    if (next == current.data) return;
    state = AsyncData(
      TutorialProgressState(data: next, evidence: current.evidence),
    );
    _save(next);
  }

  /// Marks a track as played. Its badge stays even if the data that earned
  /// it is later deleted.
  Future<void> complete(TutorialTrack track) =>
      _update((data) => data.copyWith(completed: {...data.completed, track}));

  Future<void> markIntroSeen() =>
      _update((data) => data.copyWith(introSeen: true));

  Future<void> markGoldCelebrated() =>
      _update((data) => data.copyWith(goldCelebrated: true));

  /// Re-reads the collection, e.g. after an import, to unlock tracks and
  /// light up any the user has now done for real.
  Future<void> refreshEvidence() async {
    final current = await future;
    final evidence = await _readEvidence();
    final earned = current.data.completed.union(evidence.completedTracks);
    final data = current.data.copyWith(completed: earned);
    state = AsyncData(TutorialProgressState(data: data, evidence: evidence));
    if (data != current.data) _save(data);
  }
}

final tutorialProgressProvider =
    AsyncNotifierProvider<TutorialProgressController, TutorialProgressState>(
      TutorialProgressController.new,
    );

/// Whether the backup track can be played. Off until the backup feature
/// ships, so nobody is sent to a Settings row that doesn't exist yet.
final backupTrackAvailableProvider = Provider<bool>((ref) => false);

/// Tracks this phone can play. NFC needs NFC hardware.
final tutorialAvailableTracksProvider = Provider<Set<TutorialTrack>>((ref) {
  final nfc = ref.watch(nfcHelpVisibleProvider);
  final backup = ref.watch(backupTrackAvailableProvider);
  return {
    for (final track in TutorialTrack.values)
      if ((track != TutorialTrack.nfc || nfc) &&
          (track != TutorialTrack.backup || backup))
        track,
  };
});

enum TutorialTrackStatus { locked, available, completed }

/// Everything the tutorial screens need, for the tracks this phone supports.
class TutorialView {
  const TutorialView({required this.state, required this.available});

  final TutorialProgressState state;
  final Set<TutorialTrack> available;

  TutorialProgressData get _data => state.data;
  bool get hasRecord => state.evidence.records > 0;
  bool get introSeen => _data.introSeen;
  bool get goldCelebrated => _data.goldCelebrated;

  /// Visible tracks in play order.
  List<TutorialTrack> get tracks => [
    for (final track in TutorialTrack.values)
      if (available.contains(track)) track,
  ];

  TutorialTrackStatus statusOf(TutorialTrack track) {
    if (_data.completed.contains(track)) return TutorialTrackStatus.completed;
    if (track.needsRecord && !hasRecord) return TutorialTrackStatus.locked;
    return TutorialTrackStatus.available;
  }

  /// Badges earned, in track order. Kept even for tracks hidden on this phone.
  List<TutorialTrack> get badges => [
    for (final track in TutorialTrack.values)
      if (_data.completed.contains(track)) track,
  ];

  /// Tracks that count towards the gold record on this phone.
  List<TutorialTrack> get required => [
    for (final track in tracks)
      if (!track.optional) track,
  ];

  int get requiredDone =>
      required.where((track) => _data.completed.contains(track)).length;

  bool get isGold => required.isNotEmpty && requiredDone == required.length;

  /// The track to suggest next: the first playable required one, then the
  /// first playable optional one. Null when there's nothing left to play.
  TutorialTrack? get next {
    bool playable(TutorialTrack track) =>
        statusOf(track) == TutorialTrackStatus.available;
    for (final track in required) {
      if (playable(track)) return track;
    }
    for (final track in tracks) {
      if (track.optional && playable(track)) return track;
    }
    return null;
  }
}

final tutorialViewProvider = Provider<AsyncValue<TutorialView>>((ref) {
  final available = ref.watch(tutorialAvailableTracksProvider);
  return ref
      .watch(tutorialProgressProvider)
      .whenData((state) => TutorialView(state: state, available: available));
});

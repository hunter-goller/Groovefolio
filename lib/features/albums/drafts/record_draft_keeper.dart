import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vinyl_app/features/albums/drafts/record_draft.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

/// Returns a photo the picker chose while Android had closed the app, if any.
/// On Android the photo picker can outlive the app; the image then arrives on
/// the next launch instead of to the screen that asked for it.
final lostPickedImageProvider = Provider<Future<File?> Function()>(
  (ref) => () async {
    if (!Platform.isAndroid) return null;
    try {
      final response = await ImagePicker().retrieveLostData();
      final file = response.file;
      return file == null ? null : File(file.path);
    } catch (error, stackTrace) {
      logAppError('recover picked artwork', error, stackTrace);
      return null;
    }
  },
);

/// Keeps a form's contents in a [RecordDraft] while it's open (APP-28).
///
/// - Saves after every change, and straight away when the app goes to the
///   background, which is when Android may close it.
/// - Deletes the draft when the form closes normally or the record is saved.
///   So a draft only outlives the screen when the app was closed under it.
/// - When the form opens and a draft is waiting, fills it back in and offers
///   to discard it.
///
/// Call [initDrafts] in `initState`, [markDraftReady] once the form shows its
/// starting values, [finishDraft] after a successful save, and
/// [disposeDrafts] in `dispose`.
mixin RecordDraftKeeper<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  RecordDraftKind get draftKind;

  /// The text fields; any change to them is saved.
  Listenable get draftFields;

  /// The form's contents now.
  RecordDraft captureDraft();

  /// Puts [draft] into the form. Called inside `setState`.
  void applyDraft(RecordDraft draft);

  /// A cover the picker returned after Android closed the app.
  void applyRecoveredArtwork(File file) {}

  late final RecordDraftStore _draftStore;
  late final Future<File?> Function() _lostImage;
  AppLifecycleListener? _draftLifecycle;
  RecordDraft? _baseline;
  bool _draftReady = false;
  bool _draftFinished = false;
  bool _draftWriteQueued = false;

  /// Saves and deletes run one after another, in order, so a slow save can
  /// never land after the delete that should have replaced it.
  Future<void> _draftQueue = Future.value();
  void _queue(Future<void> Function() step) {
    _draftQueue = _draftQueue.then((_) async {
      try {
        await step();
      } catch (error, stackTrace) {
        logAppError('keep record draft', error, stackTrace);
      }
    });
  }

  void initDrafts() {
    _draftStore = ref.read(recordDraftStoreProvider);
    _lostImage = ref.read(lostPickedImageProvider);
    draftFields.addListener(_draftChanged);
    _draftLifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) {
          _draftChanged();
        }
      },
    );
  }

  /// The form now shows its starting values ([baseline]: empty for Add, the
  /// saved record for Edit). Restores a waiting draft, then starts saving.
  void markDraftReady([RecordDraft baseline = const RecordDraft()]) {
    if (_draftReady) return;
    _draftReady = true;
    _baseline = baseline;
    _restoreDraft(baseline);
  }

  Future<void> _restoreDraft(RecordDraft baseline) async {
    final draft = await _draftStore.read(draftKind);
    if (!mounted || _draftFinished) return;
    if (draft == null ||
        draft.albumId != baseline.albumId ||
        draft.sameContentAs(baseline) ||
        !captureDraft().sameContentAs(baseline)) {
      // Nothing to restore, another record's draft, or the person has
      // already started typing: keep what's on screen.
      return;
    }
    setState(() => applyDraft(_withExistingFiles(draft)));
    final recovered = await _lostImage();
    if (!mounted) return;
    if (recovered != null && recovered.existsSync()) {
      setState(() => applyRecoveredArtwork(recovered));
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: const Key('record-draft-restored'),
        content: Text(
          draftKind == RecordDraftKind.add
              ? 'We kept what you were adding.'
              : 'We kept your unsaved changes.',
        ),
        action: SnackBarAction(
          label: 'Discard',
          onPressed: () {
            if (!mounted) return;
            setState(() => applyDraft(baseline));
            _queue(() => _draftStore.delete(draftKind));
          },
        ),
      ),
    );
  }

  /// Leaves out covers whose files have gone (the system cleared its cache).
  RecordDraft _withExistingFiles(RecordDraft draft) {
    bool exists(String? path) => path != null && File(path).existsSync();
    return RecordDraft(
      albumId: draft.albumId,
      title: draft.title,
      artist: draft.artist,
      year: draft.year,
      label: draft.label,
      genres: draft.genres,
      artworkPath: exists(draft.artworkPath) ? draft.artworkPath : null,
      discogsArtworkPath: exists(draft.discogsArtworkPath)
          ? draft.discogsArtworkPath
          : null,
      discogsReleaseId: draft.discogsReleaseId,
      discogsTracks: draft.discogsTracks,
      nfc: draft.nfc,
      savedAt: draft.savedAt,
    );
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _draftChanged();
  }

  void _draftChanged() {
    if (!_draftReady || _draftFinished || !mounted || _draftWriteQueued) {
      return;
    }
    _draftWriteQueued = true;
    _queue(() async {
      _draftWriteQueued = false;
      // Read the form when the save runs, so quick changes share one save.
      if (_draftFinished || !mounted) return;
      final draft = captureDraft();
      if (draft.sameContentAs(_baseline ?? const RecordDraft())) {
        await _draftStore.delete(draftKind);
      } else {
        await _draftStore.write(draftKind, draft);
      }
    });
  }

  /// The record was saved: forget the draft and stop keeping one.
  void finishDraft() {
    if (_draftFinished) return;
    _draftFinished = true;
    _queue(() => _draftStore.delete(draftKind));
  }

  void disposeDrafts() {
    draftFields.removeListener(_draftChanged);
    _draftLifecycle?.dispose();
    // Closing the form normally (Back, Save, or going elsewhere) drops the
    // draft. Android closing the app doesn't dispose the screen, so a draft
    // survives exactly when it's needed.
    if (_draftReady && !_draftFinished) {
      _draftFinished = true;
      _queue(() => _draftStore.delete(draftKind));
    }
  }
}

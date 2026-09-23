import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/onboarding_service.dart';

/// Only guide progress is persisted. Collection/play writes remain owned by
/// their existing screens and services; replay never changes first-run flags.
class WalkthroughState {
  const WalkthroughState({
    this.active = false,
    this.step = 0,
    this.replay = false,
    this.albumId,
    this.busy = false,
    this.error = false,
    this.practiced = false,
  });

  final bool active;
  final int step;
  final bool replay;
  final String? albumId;
  final bool busy;
  final bool error;
  final bool practiced;

  String get route => switch (step) {
    0 => AppRoutes.settings,
    3 || 4 when albumId != null => AppRoutes.albumDetailPath(albumId!),
    7 => AppRoutes.discover,
    _ => AppRoutes.collection,
  };
}

final walkthroughProvider =
    NotifierProvider<WalkthroughController, WalkthroughState>(
      WalkthroughController.new,
    );

/// Advances the walkthrough in response to actual app actions.
/// Only first-run progress is persisted; Settings replay stays transient.
class WalkthroughController extends Notifier<WalkthroughState> {
  WalkthroughState? _pending;
  bool _pendingFinish = false;

  @override
  WalkthroughState build() => const WalkthroughState();

  /// Starts from saved progress, or step zero for a Settings replay.
  Future<bool> start({bool replay = false}) async {
    if (state.busy) return false;
    _pending = null;
    _pendingFinish = false;
    state = WalkthroughState(busy: true, replay: replay);
    try {
      final service = ref.read(onboardingServiceProvider);
      final step = replay ? 0 : await service.resumeStep();
      if (!replay) await service.saveStep(step);
      state = WalkthroughState(active: true, step: step, replay: replay);
      return true;
    } catch (_) {
      state = WalkthroughState(error: true, replay: replay);
      return false;
    }
  }

  Future<void> move(int step, {String? albumId}) async {
    if (!state.active || state.busy || state.error) return;
    if (step < 0 || step > 7) return;
    await _persist(
      WalkthroughState(
        active: true,
        step: step,
        replay: state.replay,
        albumId: albumId ?? state.albumId,
      ),
    );
  }

  // Keep the previous step on screen while storage is pending. On failure
  // retain it with an error and allow retry of the requested transition.
  Future<void> _persist(WalkthroughState next) async {
    final before = state;
    _pending = next;
    state = WalkthroughState(
      active: before.active,
      step: before.step,
      replay: before.replay,
      albumId: before.albumId,
      busy: true,
      practiced: before.practiced,
    );
    try {
      if (!next.replay) {
        await ref.read(onboardingServiceProvider).saveStep(next.step);
      }
      state = next;
      _pending = null;
    } catch (_) {
      state = WalkthroughState(
        active: before.active,
        step: before.step,
        replay: before.replay,
        albumId: before.albumId,
        error: true,
        practiced: before.practiced,
      );
    }
  }

  Future<void> recordSaved(String id) async {
    if (state.active && state.step <= 2) await move(2, albumId: id);
  }

  Future<void> recordOpened(String id) async {
    if (!state.active) return;
    if (state.step == 2 || state.step == 3 || state.step == 4) {
      await move(state.step == 2 ? 3 : state.step, albumId: id);
    }
  }

  Future<void> playSaved(String id) async {
    if (state.active && state.step == 3) await move(4, albumId: id);
  }

  Future<void> nfcLinked() async {
    if (state.active && state.step == 4) await move(5);
  }

  void swipeRevealed() {
    if (!state.active || state.step != 5 || state.busy || state.error) return;
    state = WalkthroughState(
      active: true,
      step: 5,
      replay: state.replay,
      albumId: state.albumId,
      practiced: true,
    );
  }

  Future<void> skipStep() => move(state.step == 2 ? 5 : state.step + 1);

  /// Marks first-run complete, or closes replay without changing its flag.
  Future<bool> finish() async {
    if (state.busy) return false;
    final before = state;
    _pendingFinish = true;
    state = WalkthroughState(
      active: before.active,
      step: before.step,
      replay: before.replay,
      albumId: before.albumId,
      busy: true,
      practiced: before.practiced,
    );
    try {
      if (!before.replay) {
        await ref.read(onboardingServiceProvider).completeOnboarding();
        ref.invalidate(onboardingRequiredProvider);
      }
      _pending = null;
      _pendingFinish = false;
      state = const WalkthroughState();
      return true;
    } catch (_) {
      state = WalkthroughState(
        active: before.active,
        step: before.step,
        replay: before.replay,
        albumId: before.albumId,
        error: true,
        practiced: before.practiced,
      );
      return false;
    }
  }

  Future<void> retry() async {
    if (_pendingFinish) {
      await finish();
    } else if (_pending != null) {
      await _persist(_pending!);
    }
  }
}

/// Transient modal visibility, separate from saved walkthrough progress.
final walkthroughPlayFormProvider = NotifierProvider<WalkthroughPlayForm, bool>(
  WalkthroughPlayForm.new,
);

class WalkthroughPlayForm extends Notifier<bool> {
  @override
  bool build() => false;

  void setOpen(bool open) => state = open;
}

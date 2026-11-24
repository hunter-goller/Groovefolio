import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_session.dart';

/// Real controls the tutorial can point at. Each is tagged once in the app
/// with [SpotlightTarget].
enum SpotlightId {
  addRecordFab,
  addRecordEmpty,
  addTitle,
  addArtist,
  addSave,
  discogsConnect,
  discogsImport,
  discogsImportSelected,
  logPickRecord,
  logSide,
  logSave,
  statsSummary,
  navDiscover,
  settingsGear,
  recordMenu,
  linkNfcItem,
  firstRecordRow,
  swipeDelete,
  backupTile,
}

/// Where each tagged control is on screen right now, in global coordinates.
class SpotlightRegistry extends ChangeNotifier {
  final Map<SpotlightId, Rect> _rects = {};
  final Map<SpotlightId, RenderObject> _objects = {};
  bool _disposed = false;

  /// Scrolls the control into view if it's inside a scrollable.
  void reveal(SpotlightId id) {
    final object = _objects[id];
    if (object == null || !object.attached) return;
    object.showOnScreen(duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Rect? rectOf(SpotlightId id) => _rects[id];

  bool isMounted(SpotlightId id) => _rects.containsKey(id);

  void _set(SpotlightId id, Rect rect, RenderObject object) {
    if (_disposed) return;
    _objects[id] = object;
    if (_rects[id] == rect) return;
    _rects[id] = rect;
    notifyListeners();
  }

  void _remove(SpotlightId id, Rect? ifStill) {
    if (_disposed || (ifStill != null && _rects[id] != ifStill)) return;
    _objects.remove(id);
    if (_rects.remove(id) != null) notifyListeners();
  }
}

/// Listen with a ListenableBuilder; the instance lives as long as the app.
final spotlightRegistryProvider = Provider<SpotlightRegistry>((ref) {
  final registry = SpotlightRegistry();
  ref.onDispose(registry.dispose);
  return registry;
});

/// Tags [child] so the tutorial can spotlight it. Doesn't change layout,
/// semantics or gestures: taps still reach the control as normal.
class SpotlightTarget extends ConsumerWidget {
  const SpotlightTarget({
    super.key,
    required this.id,
    required this.child,
    this.enabled = true,
  });

  final SpotlightId id;
  final Widget child;

  /// False for every instance but one when a widget repeats (list rows).
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only the screen on top counts: a covered screen keeps its widgets
    // alive, and a spotlight on them would point at nothing visible.
    // The widget structure never changes with this, so the child (for
    // example a menu button with its menu open) is never rebuilt.
    final active = enabled && (ModalRoute.of(context)?.isCurrent ?? true);
    final registry = ref.watch(spotlightRegistryProvider);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: active
          ? (_) => ref.read(tutorialSessionProvider.notifier).targetTapped(id)
          : null,
      child: _RectReporter(
        id: id,
        registry: registry,
        active: active,
        child: child,
      ),
    );
  }
}

class _RectReporter extends SingleChildRenderObjectWidget {
  const _RectReporter({
    required this.id,
    required this.registry,
    required this.active,
    required super.child,
  });

  final SpotlightId id;
  final SpotlightRegistry registry;
  final bool active;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRectReporter(id, registry, active);

  @override
  void updateRenderObject(BuildContext context, _RenderRectReporter render) {
    render
      ..id = id
      ..registry = registry
      ..active = active;
  }
}

/// Reports its rect after every paint, so scrolling and animations are
/// followed without polling, and removes it when it leaves the screen.
class _RenderRectReporter extends RenderProxyBox {
  _RenderRectReporter(this.id, this.registry, this._active);

  SpotlightId id;
  SpotlightRegistry registry;
  bool _active;

  set active(bool value) {
    if (value == _active) return;
    _active = value;
    if (!value) _forget();
    markNeedsPaint();
  }

  Rect? _reported;
  bool _scheduled = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_active || _scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!attached || !hasSize || !_active) return;
      final rect = localToGlobal(Offset.zero) & size;
      _reported = rect;
      registry._set(id, rect, this);
    });
  }

  void _forget() {
    final last = _reported;
    if (last == null) return;
    final reg = registry;
    final target = id;
    _reported = null;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => reg._remove(target, last),
    );
  }

  @override
  void detach() {
    _forget();
    super.detach();
  }
}

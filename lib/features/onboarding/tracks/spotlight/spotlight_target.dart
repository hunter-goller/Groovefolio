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

  /// On screen but under something else, such as a dialog. The tutorial
  /// waits quietly instead of pointing at it or asking to go back.
  bool isCovered(SpotlightId id) => _covered.contains(id);
  final Set<SpotlightId> _covered = {};

  void _set(SpotlightId id, Rect rect, RenderObject object) {
    if (_disposed) return;
    _objects[id] = object;
    _startFollowing();
    final cover = object is _RenderRectReporter ? object.cover() : _Cover.none;
    if (cover != _Cover.none) {
      final underPopup = cover == _Cover.popup;
      final changed = underPopup ? _covered.add(id) : _covered.remove(id);
      if (changed | (_rects.remove(id) != null)) notifyListeners();
      return;
    }
    final uncovered = _covered.remove(id);
    if (_rects[id] == rect && !uncovered) return;
    _rects[id] = rect;
    notifyListeners();
  }

  bool _following = false;

  /// Re-measures every known control after each frame. A control reports
  /// itself when it paints, but page transitions and other layer-only
  /// animations can move it without painting it again; without this the
  /// spotlight stays where the control was partway through the slide.
  void _startFollowing() {
    if (_following) return;
    _following = true;
    SchedulerBinding.instance.addPersistentFrameCallback((_) => _remeasure());
  }

  void _remeasure() {
    if (_disposed || _objects.isEmpty) return;
    var changed = false;
    final gone = <SpotlightId>[];
    for (final MapEntry(key: id, value: object) in _objects.entries) {
      final box = object;
      if (!box.attached) {
        gone.add(id);
        continue;
      }
      if (box is! RenderBox || !box.hasSize) continue;
      final cover = box is _RenderRectReporter ? box.cover() : _Cover.none;
      if (cover != _Cover.none) {
        // Under a dialog (wait quietly) or a whole screen (off track).
        final underPopup = cover == _Cover.popup;
        if ((underPopup ? _covered.add(id) : _covered.remove(id)) |
            (_rects.remove(id) != null)) {
          changed = true;
        }
        continue;
      }
      if (_covered.remove(id)) changed = true;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (_rects[id] != rect) {
        _rects[id] = rect;
        changed = true;
      }
    }
    for (final id in gone) {
      _objects.remove(id);
      if ((_rects.remove(id) != null) | _covered.remove(id)) changed = true;
    }
    if (changed) {
      // Listeners rebuild widgets, which can't happen mid-frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  void _remove(SpotlightId id, RenderObject object) {
    // Another instance may have taken over this id since (a new screen).
    if (_disposed || _objects[id] != object) return;
    _objects.remove(id);
    final wasCovered = _covered.remove(id);
    if ((_rects.remove(id) != null) | wasCovered) notifyListeners();
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
      _RenderRectReporter(id, registry, active)
        ..cover = () => _coverOf(context);

  @override
  void updateRenderObject(BuildContext context, _RenderRectReporter render) {
    render
      ..id = id
      ..registry = registry
      ..active = active
      ..cover = () => _coverOf(context);
  }
}

/// What, if anything, is on top of [context]. A route counts only if every
/// route holding an outer navigator is on top too: a dialog over the tab
/// shell covers the shell's pages even though each is still on top of the
/// shell's own navigator.
enum _Cover {
  none,

  /// A dialog, menu or sheet: the control is still on screen underneath.
  popup,

  /// Another whole screen: the control isn't on screen any more.
  page,
}

_Cover _coverOf(BuildContext context) {
  if (!context.mounted) return _Cover.page;
  var current = context;
  // Each pass moves strictly up the tree, to the navigator holding the
  // route just checked, so this always ends.
  while (true) {
    final route = ModalRoute.of(current);
    if (route == null) return _Cover.none;
    if (!route.isCurrent) {
      // A screen pushed on top animates this one away; a dialog, menu or
      // sheet leaves it in place.
      final away = route.secondaryAnimation?.value ?? 0;
      return away > 0 ? _Cover.page : _Cover.popup;
    }
    final navigator = current.findAncestorStateOfType<NavigatorState>();
    if (navigator == null) return _Cover.none;
    final outer = navigator.context.findAncestorStateOfType<NavigatorState>();
    if (outer == null) return _Cover.none;
    current = navigator.context;
  }
}

/// Reports its rect after every paint, so scrolling and animations are
/// followed without polling, and removes it when it leaves the screen.
class _RenderRectReporter extends RenderProxyBox {
  _RenderRectReporter(this.id, this.registry, this._active);

  /// Checked every frame while the tutorial is showing; see [_coverOf].
  _Cover Function() cover = () => _Cover.none;

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
      (_) => reg._remove(target, this),
    );
  }

  @override
  void detach() {
    _forget();
    super.detach();
  }
}

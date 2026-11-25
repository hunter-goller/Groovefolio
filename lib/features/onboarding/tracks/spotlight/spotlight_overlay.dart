import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/spotlight_target.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/track_scripts.dart';
import 'package:vinyl_app/features/onboarding/tracks/track_launcher.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_progress.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_session.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Dims the app except the control the current step is about, explains it
/// in a bubble, and lets only that control (and the bubble) be tapped.
///
/// If the control isn't on screen (the user wandered off, or a screen is
/// still opening), it shows a small bubble with no dimming so the user is
/// never stuck, plus a way back.
class SpotlightOverlay extends ConsumerStatefulWidget {
  const SpotlightOverlay({super.key});

  @override
  ConsumerState<SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends ConsumerState<SpotlightOverlay> {
  (TutorialTrack?, int)? _revealed;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(tutorialSessionProvider);
    final track = session.active;
    if (track == null || session.celebrating != null) {
      return const SizedBox.shrink();
    }
    final registry = ref.watch(spotlightRegistryProvider);
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final step = session.currentStep;
        if (step != null && step.hidden) return const SizedBox.shrink();
        // A dialog the app opened covers the control: stay out of its way
        // until it closes, rather than drawing over it.
        if (step != null &&
            !step.targets.any(registry.isMounted) &&
            step.targets.any(registry.isCovered)) {
          return const SizedBox.shrink();
        }
        final targetId = step?.targets.where(registry.isMounted).firstOrNull;
        if (step != null && step.skippable && targetId == null) {
          _followAhead(session, registry);
        }
        final global = targetId == null ? null : registry.rectOf(targetId);
        if (targetId != null) _reveal(track, session.step, registry, targetId);

        final bubble = _CoachBubble(session: session, track: track, step: step);
        if (global == null || step == null) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 84),
                child: bubble,
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            // Converted at layout time, when this overlay's position is known.
            final box = context.findRenderObject()! as RenderBox;
            final hole = Rect.fromPoints(
              box.globalToLocal(global.topLeft),
              box.globalToLocal(global.bottomRight),
            );
            final padded = hole.inflate(step.padding);
            final above = padded.center.dy > constraints.maxHeight / 2;
            return Stack(
              children: [
                if (step.dim)
                  Positioned.fill(child: _SpotlightBarrier(hole: padded))
                else
                  // Inside a menu: outline the item only; the menu already
                  // takes the user's attention and handles its own taps.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          painter: _DimPainter(
                            padded,
                            Theme.of(context).colorScheme.primary,
                            dim: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (step.gesture != SpotlightGesture.none &&
                    step.gesture != SpotlightGesture.field)
                  _Hand(
                    hole: padded,
                    swipe: step.gesture == SpotlightGesture.swipe,
                    beside: !step.dim,
                  ),
                // Steps inside menus keep the bubble at the bottom, clear of
                // the menu's other items.
                if (!step.dim)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 84),
                        child: bubble,
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 12,
                    right: 12,
                    top: above ? null : padded.bottom + 14,
                    bottom: above
                        ? constraints.maxHeight - padded.top + 14
                        : null,
                    child: bubble,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// If a later step's control is already on screen, move there.
  void _followAhead(TutorialSessionState session, SpotlightRegistry registry) {
    final steps = session.script;
    for (var i = session.step + 1; i < steps.length; i++) {
      if (steps[i].targets.any(registry.isMounted)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(tutorialSessionProvider.notifier).jumpTo(i);
        });
        return;
      }
    }
  }

  /// Scrolls the control into view once per step.
  void _reveal(
    TutorialTrack track,
    int step,
    SpotlightRegistry registry,
    SpotlightId id,
  ) {
    if (_revealed == (track, step)) return;
    _revealed = (track, step);
    WidgetsBinding.instance.addPostFrameCallback((_) => registry.reveal(id));
  }
}

/// Absorbs taps outside [hole]; taps inside reach the real control.
class _SpotlightBarrier extends SingleChildRenderObjectWidget {
  _SpotlightBarrier({required this.hole})
    : super(
        child: ExcludeSemantics(child: _DimPaint(hole: hole)),
      );

  final Rect hole;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarrier(hole);

  @override
  void updateRenderObject(BuildContext context, _RenderBarrier render) {
    render.hole = hole;
  }
}

class _RenderBarrier extends RenderProxyBox {
  _RenderBarrier(this.hole);
  Rect hole;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position) || hole.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

class _DimPaint extends StatelessWidget {
  const _DimPaint({required this.hole});
  final Rect hole;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DimPainter(hole, Theme.of(context).colorScheme.primary),
    size: Size.infinite,
  );
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.hole, this.accent, {this.dim = true});
  final Rect hole;
  final Color accent;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, const Radius.circular(18));
    if (dim) {
      canvas.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRRect(rrect),
        Paint()..color = const Color(0xFF0E0B09).withValues(alpha: 0.72),
      );
    }
    canvas.drawRRect(
      rrect.inflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = accent.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _DimPainter old) =>
      old.hole != hole || old.accent != accent || old.dim != dim;
}

/// A short demonstration: a few taps or swipes, then it rests. Static when
/// the phone asks for reduced motion. It never fakes a gesture.
class _Hand extends StatefulWidget {
  const _Hand({required this.hole, required this.swipe, this.beside = false});
  final Rect hole;
  final bool swipe;

  /// Points from the side (menu items, so the next item stays readable).
  final bool beside;

  @override
  State<_Hand> createState() => _HandState();
}

class _HandState extends State<_Hand> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  int _cycles = 0;

  @override
  void initState() {
    super.initState();
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.completed && ++_cycles < 3) {
        _motion.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else if (_cycles == 0 && !_motion.isAnimating) {
      _motion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const size = 52.0;
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final t = _motion.isAnimating ? _motion.value : 0.5;
        final travel = math.min(140.0, widget.hole.width * 0.5);
        final dx = widget.swipe
            ? widget.hole.right -
                  size -
                  12 -
                  travel * Curves.easeInOut.transform(t)
            : widget.hole.right - size + 6;
        // Near the bottom edge (tabs), point from above so the label shows.
        final nearBottom =
            widget.hole.bottom > MediaQuery.sizeOf(context).height - 96;
        final bob = 4 * math.sin(math.pi * t);
        final dy = widget.swipe || widget.beside
            ? widget.hole.center.dy - size / 2
            : nearBottom
            ? widget.hole.top - size + 6 - bob
            : widget.hole.bottom - size / 2 - bob;
        return Positioned(
          left: dx.clamp(4.0, double.infinity),
          top: dy,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  widget.swipe
                      ? Icons.swipe_left_rounded
                      : Icons.touch_app_rounded,
                  size: 32,
                  color: colors.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoachBubble extends ConsumerWidget {
  const _CoachBubble({
    required this.session,
    required this.track,
    required this.step,
  });

  final TutorialSessionState session;
  final TutorialTrack track;
  final TrackStep? step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = context.theme.colorScheme;
    final text = context.theme.textTheme;
    final controller = ref.read(tutorialSessionProvider.notifier);
    final steps = session.script;
    final current = step;
    final title = current?.title ?? track.title;
    final body = current?.body ?? trackHint(track);
    final offTrack =
        current != null &&
        !current.targets.any(ref.read(spotlightRegistryProvider).isMounted);

    Future<void> skip() async {
      controller.quit();
      final next = ref.read(tutorialViewProvider).value?.nextAfter(track);
      if (next != null && context.mounted) {
        await startTrack(context, ref, next);
      }
    }

    return Semantics(
      container: true,
      sortKey: const OrdinalSortKey(0),
      child: Material(
        color: tokens.surface,
        elevation: 8,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 6, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'TRACK ${track.number}',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (steps.length > 1)
                    ExcludeSemantics(
                      child: Row(
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < session.step
                                    ? colors.primary
                                    : i == session.step
                                    ? colors.primary.withValues(alpha: 0.45)
                                    : tokens.textMuted.withValues(alpha: 0.25),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    key: const Key('spotlight-pause'),
                    tooltip: 'Pause tutorial',
                    onPressed: controller.quit,
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                  ),
                ],
              ),
              Semantics(
                liveRegion: true,
                header: true,
                child: Text(
                  title,
                  key: const Key('spotlight-title'),
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  body,
                  key: const Key('spotlight-body'),
                  style: text.bodyLarge?.copyWith(color: tokens.textMuted),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (track == TutorialTrack.addRecord &&
                      session.path == ShelfPath.discogs)
                    TextButton(
                      key: const Key('spotlight-by-hand'),
                      onPressed: () {
                        controller.switchToByHand();
                        context.go(trackStartLocation(TutorialTrack.addRecord));
                      },
                      child: const Text('Add by hand instead'),
                    ),
                  if (offTrack)
                    TextButton(
                      key: const Key('spotlight-show-me'),
                      onPressed: () {
                        controller.restart();
                        context.go(
                          session.home ??
                              trackStartLocation(track, path: session.path),
                        );
                      },
                      child: Text(current.quiet ? 'Start again' : 'Show me'),
                    ),
                  TextButton(
                    key: const Key('spotlight-skip'),
                    onPressed: skip,
                    child: const Text('Skip this track'),
                  ),
                  if (current?.advance == StepAdvance.gotIt && !offTrack)
                    FilledButton(
                      key: const Key('spotlight-got-it'),
                      onPressed: controller.advance,
                      child: const Text('Got it'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

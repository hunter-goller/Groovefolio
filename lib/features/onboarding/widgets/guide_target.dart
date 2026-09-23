import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/widgets/guide_cue.dart';
import 'package:vinyl_app/services/walkthrough_controller.dart';

export 'package:vinyl_app/features/onboarding/widgets/guide_cue.dart'
    show GuideCue;

/// Highlights the real control without intercepting taps or swipe gestures.
class GuideTarget extends ConsumerStatefulWidget {
  const GuideTarget({
    super.key,
    required this.steps,
    required this.child,
    this.reveal = false,
    this.outlineGap = false,
    this.cue = GuideCue.tap,
  });
  final List<int> steps;
  final Widget child;
  final bool reveal;
  final bool outlineGap;
  final GuideCue cue;

  @override
  ConsumerState<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends ConsumerState<GuideTarget> {
  bool _revealed = false;
  int? _interactedStep;

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(walkthroughProvider);
    final highlighted = guide.active && widget.steps.contains(guide.step);
    if (highlighted && widget.reveal && !_revealed) {
      _revealed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: Duration.zero,
          );
        }
      });
    }
    if (!highlighted) {
      _revealed = false;
      _interactedStep = null;
    }
    final showCue =
        highlighted &&
        !guide.busy &&
        !guide.error &&
        widget.cue != GuideCue.none &&
        _interactedStep != guide.step;
    return Listener(
      onPointerDown: highlighted
          ? (_) => setState(() => _interactedStep = guide.step)
          : null,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: highlighted
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.all(highlighted && widget.outlineGap ? 6 : 0),
              child: widget.child,
            ),
          ),
          if (showCue)
            Positioned.fill(
              child: GuideCueOverlay(
                key: ValueKey((guide.step, widget.cue)),
                cue: widget.cue,
              ),
            ),
        ],
      ),
    );
  }
}

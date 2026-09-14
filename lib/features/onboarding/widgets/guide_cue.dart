import 'dart:math' as math;

import 'package:flutter/material.dart';

enum GuideCue { none, tap, swipe, field }

/// A short, decorative demonstration. It never synthesizes a tap or swipe.
/// Two gentle cycles settle back to the normal control; reduced motion uses
/// a static symbol. Keeping this finite also avoids a permanent app ticker.
class GuideCueOverlay extends StatefulWidget {
  const GuideCueOverlay({super.key, required this.cue});
  final GuideCue cue;

  @override
  State<GuideCueOverlay> createState() => _GuideCueOverlayState();
}

class _GuideCueOverlayState extends State<GuideCueOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced || !TickerMode.of(context)) {
      _controller.stop();
    } else if (widget.cue != GuideCue.field && !_controller.isCompleted) {
      if (!_started) {
        _started = true;
        _controller.forward(from: 0);
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staticCue =
        MediaQuery.disableAnimationsOf(context) || widget.cue == GuideCue.field;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (!staticCue && _controller.isCompleted) {
              return const SizedBox.shrink();
            }
            final phase = staticCue ? 0.5 : (_controller.value * 2) % 1;
            final fade = staticCue
                ? 1.0
                : (math.min(phase / 0.15, (1 - phase) / 0.15)).clamp(0.0, 1.0);
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = math.min(
                  34.0,
                  math.min(constraints.maxWidth, constraints.maxHeight),
                );
                final travel = math.min(
                  100.0,
                  math.max(0.0, constraints.maxWidth - size - 8),
                );
                final swipe = widget.cue == GuideCue.swipe;
                final x = swipe
                    ? (constraints.maxWidth - size) / 2 + travel * (0.5 - phase)
                    : math.max(0.0, constraints.maxWidth - size - 3);
                final y = math.max(
                  0.0,
                  (constraints.maxHeight - size) / 2 +
                      (staticCue || swipe
                          ? 0.0
                          : -4 * math.sin(math.pi * phase)),
                );
                final colors = Theme.of(context).colorScheme;
                return Opacity(
                  opacity: fade,
                  child: Stack(
                    children: [
                      if (swipe && travel >= 18)
                        Positioned(
                          left: (constraints.maxWidth - travel) / 2,
                          top: (constraints.maxHeight - 20) / 2,
                          width: travel,
                          height: 20,
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                                color: colors.primary,
                              ),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Positioned(
                        left: x,
                        top: y,
                        width: size,
                        height: size,
                        child: Transform.scale(
                          scale: staticCue || swipe
                              ? 1
                              : 0.9 + 0.1 * math.sin(math.pi * phase),
                          child: DecoratedBox(
                            key: const Key('guide-cue-symbol'),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surface,
                              border: Border.all(
                                color: colors.primary,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 3),
                              ],
                            ),
                            child: Icon(
                              widget.cue == GuideCue.field
                                  ? Icons.edit_outlined
                                  : Icons.touch_app_rounded,
                              size: size * 0.65,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                      if (!staticCue && widget.cue == GuideCue.tap)
                        Positioned(
                          left: x,
                          top: y,
                          width: size,
                          height: size,
                          child: Opacity(
                            opacity: 1 - phase,
                            child: Transform.scale(
                              scale: 0.55 + phase * 0.45,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';

const goldLight = Color(0xFFF6C35B);
const goldDark = Color(0xFFD9822B);

/// A vinyl whose grooves light up as tracks are completed. Spins slowly when
/// [spin] is set, unless the phone asks for reduced motion.
class RecordProgress extends StatefulWidget {
  const RecordProgress({
    super.key,
    required this.done,
    required this.total,
    this.size = 200,
    this.spin = false,
    this.gold = false,
  });

  final int done;
  final int total;
  final double size;
  final bool spin;
  final bool gold;

  @override
  State<RecordProgress> createState() => _RecordProgressState();
}

class _RecordProgressState extends State<RecordProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RecordProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate =
        widget.spin &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !_turn.isAnimating) {
      _turn.repeat();
    } else if (!animate && _turn.isAnimating) {
      _turn.stop();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.gold
        ? goldLight
        : Theme.of(context).colorScheme.primary;
    return Semantics(
      label: widget.gold
          ? 'Gold record'
          : '${widget.done} of ${widget.total} tracks complete',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _turn,
          builder: (context, _) => CustomPaint(
            painter: _RecordPainter(
              done: widget.done,
              total: math.max(widget.total, 1),
              accent: accent,
              angle: _turn.value * 2 * math.pi,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordPainter extends CustomPainter {
  _RecordPainter({
    required this.done,
    required this.total,
    required this.accent,
    required this.angle,
  });

  final int done;
  final int total;
  final Color accent;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c.translate(0, r * 0.04),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF17130F));
    final inner = r * 0.40;
    final band = (r * 0.94 - inner) / total;
    for (var i = 0; i < total; i++) {
      final outer = r * 0.94 - i * band;
      final lit = i < done;
      for (var g = 0; g < 4; g++) {
        canvas.drawCircle(
          c,
          outer - g * band / 4 - 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = lit
                ? accent.withValues(alpha: 0.85 - g * 0.12)
                : Colors.white.withValues(alpha: g.isEven ? 0.10 : 0.07),
        );
      }
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawCircle(
      Offset.zero,
      r * 0.95,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.12, 0.25, 0.5, 0.62, 0.75],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.restore();
    canvas.drawCircle(c, inner * 0.92, Paint()..color = accent);
    canvas.drawCircle(
      c,
      inner * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.drawCircle(c, r * 0.035, Paint()..color = const Color(0xFF17130F));
  }

  @override
  bool shouldRepaint(covariant _RecordPainter old) =>
      old.done != done ||
      old.total != total ||
      old.accent != accent ||
      old.angle != angle;
}

/// A round gold medal with the track's icon. Greyed out until earned.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({
    super.key,
    required this.track,
    this.size = 52,
    this.earned = true,
    this.glow = false,
  });

  final TutorialTrack track;
  final double size;
  final bool earned;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.12);
    return Semantics(
      label: earned
          ? '${track.badge} badge'
          : '${track.badge} badge, not earned yet',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: earned ? null : muted,
          gradient: earned
              ? const LinearGradient(
                  colors: [goldLight, goldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          boxShadow: glow && earned
              ? [
                  BoxShadow(
                    color: goldLight.withValues(alpha: 0.6),
                    blurRadius: size / 4,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ExcludeSemantics(
          child: Icon(
            earned ? track.icon : Icons.lock_outline_rounded,
            size: size * 0.5,
            color: earned
                ? Colors.white
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Still confetti around the edges, kept clear of the middle so text stays
/// readable. It fades in as a [ConfettiBurst] lands, or shows at once with
/// reduced motion. Put it behind the content.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = _playOnce(this, context);

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _settle; // Starts on the first build.
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ConfettiPainter(
              Theme.of(context).colorScheme.primary,
              settle: _settle,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// Confetti fired from both bottom corners, up over the content, then
/// fluttering down and away. Plays once; nothing with reduced motion.
/// Put it in front of the content: it never takes taps.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  static const duration = Duration(milliseconds: 3600);

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = _playOnce(this, context);

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _burst; // Starts on the first build.
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ConfettiBurstPainter(
              progress: _burst,
              accent: Theme.of(context).colorScheme.primary,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// A controller that runs [ConfettiBurst.duration] once, or is already
/// finished when the phone asks for reduced motion.
AnimationController _playOnce(TickerProvider vsync, BuildContext context) {
  final controller = AnimationController(
    vsync: vsync,
    duration: ConfettiBurst.duration,
  );
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
    controller.value = 1;
  } else {
    controller.forward();
  }
  return controller;
}

List<Color> _confettiColors(Color accent) => [
  accent,
  goldLight,
  const Color(0xFF5FB49C),
  const Color(0xFFE8E2D9),
  const Color(0xFF8E7CC3),
];

/// The moving burst. Half the pieces leave each bottom corner, angled up
/// and inwards, slowed by air, pulled down by gravity, tumbling as they go.
class _ConfettiBurstPainter extends CustomPainter {
  _ConfettiBurstPainter({required this.progress, required this.accent})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color accent;

  static const _pieces = 130;

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value;
    if (value <= 0 || value >= 1) return;
    final t = value * ConfettiBurst.duration.inMilliseconds / 1000;
    final gravity = size.height * 0.85;
    final colors = _confettiColors(accent);
    final rnd = math.Random(11);
    final paint = Paint();

    for (var i = 0; i < _pieces; i++) {
      // Every piece draws the same randoms on every frame, in the same order.
      final fromLeft = i.isEven;
      // Up fast enough to near the top; across by up to most of the width.
      final rise = size.height * (1.5 + rnd.nextDouble() * 1.0);
      final across = size.width * (0.25 + rnd.nextDouble() * 1.05);
      final delay = rnd.nextDouble() * 0.35;
      // Light pieces catch more air, so they float down more slowly.
      final drag = 1.35 + rnd.nextDouble() * 0.8;
      final spin = (rnd.nextDouble() - 0.5) * 12;
      final flip = 5 + rnd.nextDouble() * 7;
      final sway = 8 + rnd.nextDouble() * 16;
      final phase = rnd.nextDouble() * math.pi * 2;
      final round = rnd.nextDouble() < 0.25;
      final life = 2.9 + rnd.nextDouble() * 0.65;

      final age = t - delay;
      if (age <= 0 || age >= life) continue;
      final vx = fromLeft ? across : -across;
      final vy = -rise;
      // Exact motion with linear drag: fast at first, then a gentle fall.
      final slowed = (1 - math.exp(-drag * age)) / drag;
      final x =
          (fromLeft ? -8.0 : size.width + 8) +
          vx * slowed +
          math.sin(age * 3.5 + phase) * sway * math.min(age, 1);
      final y = size.height + 8 + vy * slowed + gravity / drag * (age - slowed);
      final fade = ((life - age) / 0.45).clamp(0.0, 1.0);

      paint.color = colors[i % colors.length].withValues(alpha: 0.95 * fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(phase + spin * age);
      // Squashing one axis makes a flat piece look like it's turning over.
      canvas.scale(1, math.cos(age * flip + phase).abs() * 0.85 + 0.15);
      if (round) {
        canvas.drawCircle(Offset.zero, 3.5, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-6, -3, 12, 6),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter old) =>
      old.progress != progress || old.accent != accent;
}

/// The still frame around the edges. Fades in over the second half of the
/// burst, so the pieces seem to land there.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.accent, {required this.settle})
    : super(repaint: settle);
  final Color accent;
  final Animation<double> settle;

  @override
  void paint(Canvas canvas, Size size) {
    final shown = Curves.easeOut.transform(
      ((settle.value - 0.35) / 0.65).clamp(0.0, 1.0),
    );
    if (shown == 0) return;
    final rnd = math.Random(7);
    final colors = _confettiColors(accent);
    for (var i = 0; i < 110; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.6;
      final angle = rnd.nextDouble() * math.pi;
      if (x > size.width * 0.18 &&
          x < size.width * 0.82 &&
          y > size.height * 0.14) {
        continue;
      }
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, -2.5, 10, 5),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = colors[i % colors.length].withValues(alpha: 0.9 * shown),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.accent != accent || old.settle != settle;
}

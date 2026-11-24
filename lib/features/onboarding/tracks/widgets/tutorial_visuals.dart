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

/// Static confetti, kept clear of the middle so text stays readable.
/// Decorative only; it never moves, so reduced motion is respected.
class Confetti extends StatelessWidget {
  const Confetti({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _ConfettiPainter(Theme.of(context).colorScheme.primary),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final colors = [
      accent,
      goldLight,
      const Color(0xFF5FB49C),
      const Color(0xFFE8E2D9),
      const Color(0xFF8E7CC3),
    ];
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
        Paint()..color = colors[i % colors.length].withValues(alpha: 0.9),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.accent != accent;
}

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Paints a ring: a track and, over it, an arc with round ends.
///
/// The arc painter `Spinner` and `ProgressRing` share. Hand-painted rather
/// than a wrapped `CircularProgressIndicator` because nothing under `lib/`
/// may import `material.dart`.
///
/// Angles are in radians, clockwise from three o'clock, as `Canvas.drawArc`
/// takes them. The ring is inscribed in the smaller side of the box and
/// centred in it.
class RingPainter extends CustomPainter {
  /// Creates a painter of one ring. [arc] is asked at paint time, so a
  /// painter given a [repaint] listenable can follow an animation without
  /// being rebuilt.
  RingPainter({
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.arc,
    this.trackStart = 0,
    this.trackSweep = math.pi * 2,
    this.opacity,
    super.repaint,
  });

  /// The colour of the arc.
  final Color color;

  /// The colour of the track. Fully transparent paints none.
  final Color trackColor;

  /// The thickness of track and arc.
  final double strokeWidth;

  /// Where the track starts.
  final double trackStart;

  /// How far round the track goes; a full turn for a closed ring.
  final double trackSweep;

  /// The arc to paint now: where it starts and how far it goes.
  final ({double start, double sweep}) Function() arc;

  /// How opaque the arc is now, from 0 to 1, asked at paint time like
  /// [arc]: a spin under reduced motion breathes instead of turning. Null
  /// is fully opaque. The track keeps its own colour.
  final double Function()? opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (side - strokeWidth) / 2,
    );
    if (rect.width <= 0) return;

    if (trackColor.a > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor;
      if (trackSweep >= math.pi * 2) {
        canvas.drawCircle(rect.center, rect.width / 2, paint);
      } else {
        canvas.drawArc(
          rect,
          trackStart,
          trackSweep,
          false,
          paint..strokeCap = StrokeCap.round,
        );
      }
    }

    final (:start, :sweep) = arc();
    // A zero sweep with a round cap is a dot; nothing has happened yet, so
    // nothing is drawn.
    if (sweep <= 0) return;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..color = opacity == null
            ? color
            : color.withValues(alpha: color.a * opacity!().clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackStart != trackStart ||
      oldDelegate.trackSweep != trackSweep ||
      oldDelegate.arc != arc ||
      oldDelegate.opacity != opacity;
}

/// The default line of a ring — a `Spinner`, a `ProgressRing` — [size]
/// points across: a tenth of it
/// on a large ring, the same 3 points on a smaller one — a line that thins
/// with the ring reads as fainter than the text beside it — and a sixth of
/// it on a very small one, where 3 points would fill the ring.
double ringStrokeFor(double size) => math.max(size / 10, math.min(size / 6, 3));

/// One grow-and-shrink of the indeterminate arc ([indeterminateArc]): the
/// head runs ahead for the first half, the tail catches up in the second.
const indeterminateArcCycle = Duration(milliseconds: 1333);

/// How long the indeterminate arc takes to come back to where it started,
/// whole: [indeterminateArcCycle] times the 2222 ms of one slow turn, as
/// Material's `CircularProgressIndicator` repeats. A clock looping over
/// this never jumps.
const indeterminateArcLoop = Duration(milliseconds: 1333 * 2222);

/// The arc of an indeterminate ring [elapsed] into its animation: Material's
/// `CircularProgressIndicator`, painted here.
///
/// Within each [indeterminateArcCycle] the head grows the arc to
/// [maxSweep] over the first half and the tail shrinks it again over the
/// second, both on `Curves.fastOutSlowIn`; each cycle also starts a quarter
/// turn further on, and the whole turns once every 2222 ms. The arc never
/// shrinks below [minSweep], so a round-capped arc stays a short stroke
/// rather than a dot.
///
/// [start] is where the arc begins at rest: the top by default.
({double start, double sweep}) indeterminateArc(
  Duration elapsed, {
  double start = -math.pi / 2,
  double maxSweep = math.pi * 1.5,
  double minSweep = .12,
}) {
  final ms = elapsed.inMicroseconds / Duration.microsecondsPerMillisecond;
  final cycle = indeterminateArcCycle.inMilliseconds;
  final path = (ms / cycle) % 1;
  final rotation = (ms / 2222) % 1;
  final head = Curves.fastOutSlowIn.transform((path * 2).clamp(0.0, 1.0));
  final tail = Curves.fastOutSlowIn.transform(
    (path * 2 - 1).clamp(0.0, 1.0),
  );
  final sweep = math.max((head - tail) * maxSweep, minSweep);
  return (
    // The tail's travel and a quarter turn per cycle add up to a whole turn,
    // so the arc is continuous from one cycle to the next.
    start:
        start +
        tail * maxSweep +
        path * (math.pi * 2 - maxSweep) +
        rotation * math.pi * 2 -
        // Centre the minimum on the moving arc rather than its tail.
        (sweep - (head - tail) * maxSweep) / 2,
    sweep: sweep,
  );
}

/// How long one breath of a spinner held still takes.
const spinnerBreathPeriod = Duration(milliseconds: 1600);

/// The opacity of a spinner that holds still under reduced motion,
/// [elapsed] into its animation: it breathes between a third and full
/// strength, so it still says "working" without anything moving.
double spinnerBreath(Duration elapsed) {
  final phase = elapsed.inMicroseconds / spinnerBreathPeriod.inMicroseconds % 1;
  return .35 + .65 * (.5 + .5 * math.cos(phase * math.pi * 2));
}

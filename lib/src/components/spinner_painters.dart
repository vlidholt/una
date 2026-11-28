import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// One frame of a spinner: how far into its animation it is, at the
/// variant's own pace, and how opaque it is (below 1 only while a spinner
/// held still by reduced motion breathes).
typedef SpinnerFrame = ({Duration time, double opacity});

/// The painter of a `Spinner` variant other than the ring: one colour, a
/// square box, everything drawn from [frame] at paint time so the painter
/// follows its clock without being rebuilt.
///
/// The drawing is centred and scaled to the smaller side of the box. A
/// translucent colour is painted opaque inside one layer that carries the
/// alpha, so shapes that overlap (a dot over its trail, a drop over its
/// neck) are not blended twice.
abstract class SpinnerPainter extends CustomPainter {
  /// Creates a spinner painter.
  SpinnerPainter({required this.color, required this.frame, super.repaint});

  /// The colour everything is drawn in.
  final Color color;

  /// The frame to paint now.
  final SpinnerFrame Function() frame;

  /// One cycle of this variant: what a `Spinner`'s `duration` replaces.
  Duration get cycle;

  /// The moment a spinner held still by reduced motion shows.
  Duration get restingTime;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2;
    if (radius <= 0) return;
    final (:time, :opacity) = frame();
    final alpha = color.a * opacity.clamp(0.0, 1.0);
    if (alpha <= 0) return;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);
    final layered = alpha < 1;
    if (layered) {
      canvas.saveLayer(
        Rect.fromCircle(center: Offset.zero, radius: radius + 1),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
    }
    paintFrame(
      canvas,
      radius,
      time.inMicroseconds / Duration.microsecondsPerSecond,
      layered ? color.withValues(alpha: 1) : color,
    );
    if (layered) canvas.restore();
    canvas.restore();
  }

  /// Paints the spinner [seconds] into its animation, centred on the
  /// origin in a circle of [radius].
  @protected
  void paintFrame(Canvas canvas, double radius, double seconds, Color color);

  @override
  bool shouldRepaint(SpinnerPainter oldDelegate) =>
      oldDelegate.runtimeType != runtimeType ||
      oldDelegate.color != color ||
      oldDelegate.frame != frame;
}

/// A ring of dots with a wave of light running round it.
///
/// Eight dots sit on a ring that drifts slowly the other way. Once per
/// [cycle] a swell runs round clockwise: a dot rises sharply as it nears,
/// is largest as it passes — stretched a little along the ring, as if by
/// its speed — and settles back over the next few, so two or three are
/// lit at once, each in a soft glow of its own colour. One colour
/// throughout: the glow is the dot's colour, blurred and faint.
class HaloSpinnerPainter extends SpinnerPainter {
  /// Creates the halo painter.
  HaloSpinnerPainter({
    required super.color,
    required super.frame,
    super.repaint,
  });

  @override
  Duration get cycle => const Duration(milliseconds: 1100);

  @override
  Duration get restingTime => const Duration(milliseconds: 180);

  static const _dots = 8;

  /// How much of the lap behind the swell a dot takes to settle, and how
  /// sharply it rises ahead of it.
  static const _settle = 4.2;
  static const _rise = 22.0;

  /// How fast the ring drifts against the swell, in laps per second.
  static const _drift = .08;

  @override
  void paintFrame(Canvas canvas, double radius, double seconds, Color color) {
    final lap = seconds / (cycle.inMicroseconds / 1e6);
    final swell = (lap - lap.floorToDouble()) * math.pi * 2;
    final drift = -seconds * _drift * math.pi * 2;
    final orbit = radius * .6;
    final small = radius * .062;
    final large = radius * .17;
    final glow = Paint();
    final dot = Paint()..color = color;
    for (var i = 0; i < _dots; i++) {
      final place = i / _dots * math.pi * 2;
      // How far the swell has gone past this dot, as a share of a lap.
      final behind = ((swell - place) % (math.pi * 2)) / (math.pi * 2);
      final lit = math.max(
        math.exp(-behind * _settle),
        math.exp(-(1 - behind) * _rise),
      );
      final angle = place + drift - math.pi / 2;
      final centre = Offset.fromDirection(angle, orbit);
      final r = small + (large - small) * lit;
      if (lit > .12) {
        glow
          ..color = color.withValues(alpha: color.a * .38 * lit)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.1);
        canvas.drawCircle(centre, r * 1.9, glow);
      }
      // Stretched along the ring by up to a third as it passes.
      final stretch = 1 + .32 * lit;
      dot.color = color.withValues(alpha: color.a * (.5 + .5 * lit));
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(angle + math.pi / 2)
        ..drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: 2 * r * stretch,
            height: 2 * r / math.sqrt(stretch),
          ),
          dot,
        )
        ..restore();
    }
  }
}

/// Three comets chasing each other round a circle.
///
/// Each dot runs a lap per [cycle], slow at the top and fast at the bottom,
/// so the three bunch up and then fling apart; a tail as long as the
/// distance the dot covered in the last moment streams behind it, so the
/// faster it goes the longer it is. The point where they bunch drifts
/// slowly round, so no two laps look alike.
class OrbitSpinnerPainter extends SpinnerPainter {
  /// Creates the orbit painter.
  OrbitSpinnerPainter({
    required super.color,
    required super.frame,
    super.repaint,
  });

  @override
  Duration get cycle => const Duration(milliseconds: 1500);

  @override
  Duration get restingTime => const Duration(milliseconds: 1050);

  static const _dots = 3;
  static const _lag = .1;
  static const _scales = [1.0, .8, .62];

  /// How long ago, in seconds, the tip of a tail was where it is.
  static const _tail = .16;

  /// Where dot [index] is at [seconds]: an angle, clockwise from the top.
  double _angle(double seconds, int index) {
    final lap = seconds / cycle.inMicroseconds * 1e6 - index * _lag;
    final f = lap - lap.floorToDouble();
    // Speed 1 − k·cos(2πf): nearly stopped at the top, twice as fast at the
    // bottom, and smooth across the lap.
    const k = .86;
    final eased = f - k * math.sin(f * math.pi * 2) / (math.pi * 2);
    return (lap.floorToDouble() + eased) * math.pi * 2 +
        seconds * math.pi * 2 * .12 -
        math.pi / 2;
  }

  @override
  void paintFrame(Canvas canvas, double radius, double seconds, Color color) {
    final dot = radius * .22;
    final orbit = radius - dot - radius * .04;
    final paint = Paint()..color = color;
    // The last dot first, so the leader is drawn over the others' tails.
    for (var i = _dots - 1; i >= 0; i--) {
      final head = _angle(seconds, i);
      final tail = _angle(seconds - _tail, i);
      final r = dot * _scales[i];
      final sweep = head - tail;
      if (sweep > .02) {
        _comet(canvas, orbit, r, tail, math.min(sweep, math.pi * 1.6), color);
      }
      canvas.drawCircle(Offset.fromDirection(head, orbit), r, paint);
    }
  }

  /// A tail along the orbit from [from] to [from] + [sweep], [width] wide
  /// at the head and nothing at the tip, fading out towards the tip.
  void _comet(
    Canvas canvas,
    double orbit,
    double width,
    double from,
    double sweep,
    Color color,
  ) {
    const steps = 14;
    final outer = <Offset>[];
    final inner = <Offset>[];
    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      final w = width * math.pow(t, .7);
      final a = t * sweep;
      outer.add(Offset.fromDirection(a, orbit + w));
      inner.add(Offset.fromDirection(a, orbit - w));
    }
    final path = Path()..addPolygon([...outer, ...inner.reversed], true);
    canvas
      ..save()
      ..rotate(from)
      ..drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.sweep(
            Offset.zero,
            [color.withValues(alpha: 0), color.withValues(alpha: color.a * .6)],
            const [0, 1],
            TileMode.clamp,
            0,
            sweep,
          ),
      )
      ..restore();
  }
}

/// A shape that keeps changing its mind: a four-leaf clover becomes a
/// soft sun, a rounded triangle, a pill, a flower, a pentagon and back,
/// each change a twist with a little overshoot, while the whole turns
/// slowly.
///
/// A shape is a radius for every direction, so going from one to the next
/// is a blend of the two radii — every in-between is a smooth blob.
class MorphSpinnerPainter extends SpinnerPainter {
  /// Creates the morph painter.
  MorphSpinnerPainter({
    required super.color,
    required super.frame,
    super.repaint,
  });

  /// One change of shape: a short hold, then the twist into the next.
  @override
  Duration get cycle => const Duration(milliseconds: 750);

  @override
  Duration get restingTime => Duration.zero;

  /// The shapes in order, as lobe count and depth; zero lobes is the pill.
  static const _shapes = [
    (lobes: 4, depth: .16),
    (lobes: 8, depth: .07),
    (lobes: 3, depth: .13),
    (lobes: 0, depth: .45),
    (lobes: 6, depth: .1),
    (lobes: 5, depth: .1),
  ];

  /// How much of a cycle the shape holds before it changes.
  static const _hold = .3;

  static double _radius(({int lobes, double depth}) shape, double angle) {
    if (shape.lobes == 0) {
      // An ellipse, its long side across; depth is how much shorter the
      // other side is.
      final c = math.cos(angle);
      final s = math.sin(angle) / (1 - shape.depth);
      return 1 / math.sqrt(c * c + s * s);
    }
    // Lobes pointing up at rest, scaled so the tips touch the edge.
    return (1 + shape.depth * math.cos(shape.lobes * (angle + math.pi / 2))) /
        (1 + shape.depth);
  }

  @override
  void paintFrame(Canvas canvas, double radius, double seconds, Color color) {
    final cycles = seconds * 1e6 / cycle.inMicroseconds;
    final index = cycles.floor();
    final f = cycles - index;
    final from = _shapes[index % _shapes.length];
    final to = _shapes[(index + 1) % _shapes.length];
    final change = ((f - _hold) / (1 - _hold)).clamp(0.0, 1.0);
    final blend = Curves.easeInOutCubic.transform(change);
    // Each change twists a fifth of a turn with an overshoot, on top of a
    // slow, steady turn.
    final twist =
        (index + Curves.easeOutBack.transform(change)) * math.pi * .4 +
        seconds * math.pi * 2 * .08;
    // The shape draws in a little while it changes, like a breath.
    final scale = radius * (1 - .1 * math.sin(change * math.pi));

    final points = (radius * 6).clamp(48, 160).round();
    final outline = <Offset>[];
    for (var p = 0; p < points; p++) {
      final angle = p / points * math.pi * 2;
      final r = _radius(from, angle) * (1 - blend) + _radius(to, angle) * blend;
      outline.add(Offset.fromDirection(angle + twist, r * scale));
    }
    canvas.drawPath(
      Path()..addPolygon(outline, true),
      Paint()..color = color,
    );
  }
}

/// A drop of something gooey that splits into three and pulls itself back
/// together.
///
/// Three droplets swell out of a central drop on stretching necks that
/// thin and snap, hang apart for a moment, then are pulled back in faster
/// and faster until they merge with a little swell of the centre, while
/// the whole swirls a third of a turn.
class GooSpinnerPainter extends SpinnerPainter {
  /// Creates the goo painter.
  GooSpinnerPainter({
    required super.color,
    required super.frame,
    super.repaint,
  });

  /// One split and merge.
  @override
  Duration get cycle => const Duration(milliseconds: 1700);

  @override
  Duration get restingTime => const Duration(milliseconds: 520);

  static const _drops = 3;

  /// How far out a droplet is, 0 to 1, [f] into a cycle.
  static double _reach(double f) {
    if (f < .1) return 0;
    if (f < .48) return Curves.easeInOutCubic.transform((f - .1) / .38);
    if (f < .6) return 1;
    // Pulled back, faster and faster.
    return 1 - Curves.easeInCubic.transform((f - .6) / .4);
  }

  @override
  void paintFrame(Canvas canvas, double radius, double seconds, Color color) {
    final cycles = seconds * 1e6 / cycle.inMicroseconds;
    final paint = Paint()..color = color;
    final drop = radius * .25;
    final far = radius - drop - radius * .03;

    // The centre holds what the droplets took from it: it is largest while
    // they are all in, and swells a little more as they land.
    final f0 = cycles - cycles.floorToDouble();
    final landing = f0 < .1 ? math.sin(f0 / .1 * math.pi) : 0.0;
    final core = radius * (.34 + .14 * (1 - _reach(f0)) + .05 * landing);
    canvas.drawCircle(Offset.zero, core, paint);

    for (var i = 0; i < _drops; i++) {
      // Each droplet a little behind the last, so they do not move in
      // lockstep.
      final c = cycles - i * .035;
      final f = c - c.floorToDouble();
      final reach = _reach(f);
      // A third of a turn per cycle brings every droplet to where the next
      // one started, so the swirl is seamless.
      final angle =
          (c.floorToDouble() + Curves.easeInOutCubic.transform(f)) *
              math.pi *
              2 /
              _drops +
          i * math.pi * 2 / _drops +
          seconds * math.pi * 2 * .1 -
          math.pi / 2;
      final centre = Offset.fromDirection(angle, far * reach);
      final r = drop * (.82 + .18 * reach);
      // The neck thins as the droplet pulls away and is gone at full
      // reach.
      final spread = .5 * (1 - _smoothstep(core * .6, far * .98, far * reach));
      final neck = metaballNeck(Offset.zero, core, centre, r, spread);
      if (neck != null) canvas.drawPath(neck, paint);
      canvas.drawCircle(centre, r, paint);
    }
  }

  static double _smoothstep(double from, double to, double x) {
    final t = ((x - from) / (to - from)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

/// The neck that joins two circles of goo: the circle at [c1] of radius
/// [r1] and the one at [c2] of radius [r2], [spread] (0 to 1, .5 is a
/// natural neck) of the way round each, with handles [handleSize] long.
///
/// Null when there is no neck to draw: the circles too far apart, one
/// inside the other, or no spread. The path only bridges the gap; drawn
/// with both circles it reads as one blob. After Hiroyuki Sato's metaball
/// construction.
Path? metaballNeck(
  Offset c1,
  double r1,
  Offset c2,
  double r2,
  double spread, {
  double handleSize = 2.4,
}) {
  final d = (c2 - c1).distance;
  if (r1 <= 0 || r2 <= 0 || spread <= 0 || d <= (r1 - r2).abs()) return null;
  var u1 = 0.0;
  var u2 = 0.0;
  if (d < r1 + r2) {
    // The circles overlap: start the neck where they cross.
    u1 = math.acos(((r1 * r1 + d * d - r2 * r2) / (2 * r1 * d)).clamp(-1, 1));
    u2 = math.acos(((r2 * r2 + d * d - r1 * r1) / (2 * r2 * d)).clamp(-1, 1));
  }
  final between = math.atan2(c2.dy - c1.dy, c2.dx - c1.dx);
  final maxSpread = math.acos(((r1 - r2) / d).clamp(-1, 1));
  final a1 = between + u1 + (maxSpread - u1) * spread;
  final a2 = between - u1 - (maxSpread - u1) * spread;
  final a3 = between + math.pi - u2 - (math.pi - u2 - maxSpread) * spread;
  final a4 = between - math.pi + u2 + (math.pi - u2 - maxSpread) * spread;
  final p1 = c1 + Offset.fromDirection(a1, r1);
  final p2 = c1 + Offset.fromDirection(a2, r1);
  final p3 = c2 + Offset.fromDirection(a3, r2);
  final p4 = c2 + Offset.fromDirection(a4, r2);
  final total = r1 + r2;
  final reach =
      math.min(spread * handleSize, (p1 - p3).distance / total) *
      math.min(1, d * 2 / total);
  final h1 = p1 + Offset.fromDirection(a1 - math.pi / 2, r1 * reach);
  final h2 = p2 + Offset.fromDirection(a2 + math.pi / 2, r1 * reach);
  final h3 = p3 + Offset.fromDirection(a3 + math.pi / 2, r2 * reach);
  final h4 = p4 + Offset.fromDirection(a4 - math.pi / 2, r2 * reach);
  return Path()
    ..moveTo(p1.dx, p1.dy)
    ..cubicTo(h1.dx, h1.dy, h3.dx, h3.dy, p3.dx, p3.dy)
    ..lineTo(p4.dx, p4.dy)
    ..cubicTo(h4.dx, h4.dy, h2.dx, h2.dy, p2.dx, p2.dy)
    ..close();
}

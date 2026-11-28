import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:una/src/components/ring_painter.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/debug_check.dart';
import 'package:una/src/utils/progress_semantics.dart';
import 'package:una/src/utils/spring.dart';

/// A ring that fills as something progresses: an upload, a quota, a goal —
/// the circular counterpart of `ProgressBar`.
///
/// ```dart
/// ProgressRing(
///   value: uploaded / total,
///   semanticLabel: 'Uploading',
///   child: Text('${(uploaded / total * 100).round()}%'),
/// )
/// ```
///
/// [value] runs from 0 to 1 and eases to each new value on the theme's
/// smooth spring. A null [value] spins instead: progress of unknown length,
/// at any size and with a [child] in the middle. The arc turns while it
/// grows and shrinks, head and tail on offset curves, as Material's
/// indeterminate indicator does; under reduced motion it holds still and
/// breathes. (`Spinner` stays the small inline indicator for a button or a
/// line of text, and its default look is this ring.)
///
/// With a [sweepAngle] of less than a full turn the ring is a gauge: an
/// open arc, its gap at the bottom.
///
/// ```dart
/// ProgressRing(
///   value: .72,
///   sweepAngle: math.pi * 1.5,
///   size: 96,
///   child: const Text('72'),
/// )
/// ```
///
/// The arc takes the progress bar's colour, the track its track colour and
/// a new value its spring, so the two read as one family.
class ProgressRing extends StatefulWidget {
  /// Creates a progress ring.
  const ProgressRing({
    required this.value,
    this.size,
    this.strokeWidth,
    this.color,
    this.trackColor,
    this.child,
    this.sweepAngle = math.pi * 2,
    this.semanticLabel,
    this.semanticValue,
    super.key,
  }) : assert(
         sweepAngle > 0 && sweepAngle <= math.pi * 2,
         'sweepAngle is between 0 and a full turn',
       );

  /// The progress, from 0 to 1; values outside are clamped. Null spins.
  final double? value;

  /// The ring's diameter. Defaults to 40.
  final double? size;

  /// The thickness of the ring. Defaults to a tenth of [size] on a large
  /// ring, at most 6; below 30 points the line keeps its weight — 3 points
  /// — and only a very small ring thins with it, as a `Spinner` does.
  final double? strokeWidth;

  /// The colour of the arc. Defaults to the progress bar theme's.
  final Color? color;

  /// The colour of the track behind the arc. Defaults to the progress bar
  /// theme's `trackColor`; pass a transparent colour for none.
  final Color? trackColor;

  /// A widget centred in the ring: a percentage, an icon.
  final Widget? child;

  /// How far round the ring goes, in radians. A full turn by default; less
  /// makes a gauge, open at the bottom.
  final double sweepAngle;

  /// What the progress is of, for assistive technology.
  final String? semanticLabel;

  /// The progress as assistive technology reads it. Defaults to [value] as
  /// a percentage.
  final String? semanticValue;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with TickerProviderStateMixin {
  // One clock over the arc's whole loop (see `indeterminateArcLoop`): the
  // painter reads the time off it, so nothing is rebuilt while it turns.
  late final _spin = AnimationController(
    vsync: this,
    duration: indeterminateArcLoop,
  );

  /// How much faster than its own pace the arc runs: the spinner theme's
  /// `duration` is one grow-and-shrink.
  double _speed = 1;

  /// Whether the spin holds still and breathes (reduced motion), or does
  /// not move at all (`Motion.none`).
  _Stillness _still = _Stillness.moving;
  late final _value = SpringController(
    vsync: this,
    value: _clamped(widget.value),
  );
  late final _repaint = Listenable.merge([_spin, _value.animation]);

  static double _clamped(double? value) => (value ?? 0).clamp(0.0, 1.0);

  bool get _spinning => widget.value == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cycle = Theme.of(context).spinnerTheme.duration;
    _speed = cycle == null || cycle <= Duration.zero
        ? 1
        : indeterminateArcCycle.inMicroseconds / cycle.inMicroseconds;
    final motion = Motion.of(context);
    _still = !motion.reduced
        ? _Stillness.moving
        : motion.fast == Duration.zero
        ? _Stillness.still
        : _Stillness.breathing;
    _syncSpin();
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final value = widget.value;
      if (value == null) {
        _syncSpin();
      } else if (oldWidget.value == null) {
        // Out of the spin there is no arc to grow from.
        _syncSpin();
        _value.jumpTo(_clamped(value));
      } else {
        // The bar's spring, so the two read as one family.
        _value.animateTo(
          _clamped(value),
          spring:
              Theme.of(context).progressBarTheme.spring ??
              Motion.of(context).smooth,
        );
      }
    }
  }

  void _syncSpin() {
    if (_spinning && _still != _Stillness.still) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _value.dispose();
    super.dispose();
  }

  /// Where the track starts: the top for a closed ring, and for a gauge the
  /// point that leaves its gap centred at the bottom.
  double get _trackStart => widget.sweepAngle >= math.pi * 2
      ? -math.pi / 2
      : -math.pi / 2 - widget.sweepAngle / 2;

  /// How far into its loop the spin is, at the arc's own pace.
  Duration get _elapsed => indeterminateArcLoop * _spin.value;

  ({double start, double sweep}) _arc() {
    if (_spinning) {
      // Material's arc, its longest kept inside a gauge's sweep. Held
      // still, it is a long arc, three quarters of the way grown.
      final maxSweep = math.min(math.pi * 1.5, widget.sweepAngle);
      return indeterminateArc(
        _still == _Stillness.moving
            ? _elapsed * _speed
            : indeterminateArcCycle * .3,
        start: _trackStart,
        maxSweep: maxSweep,
        minSweep: math.min(.12, maxSweep),
      );
    }
    return (
      start: _trackStart,
      sweep: widget.sweepAngle * _value.value.clamp(0.0, 1.0),
    );
  }

  double _breath() => spinnerBreath(_elapsed);

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasTheme(context));
    final theme = Theme.of(context);
    final bar = theme.progressBarTheme;
    final size = widget.size ?? 40.0;
    // The spinner's rule — a line that keeps its weight on a small ring —
    // up to 6 on a large one.
    final strokeWidth = widget.strokeWidth ?? math.min(ringStrokeFor(size), 6);
    final value = widget.value;

    return progressSemantics(
      determinate: value != null,
      label: widget.semanticLabel,
      value:
          widget.semanticValue ??
          (value == null ? null : '${(_clamped(value) * 100).round()}%'),
      // A spinner with a name is news; a percentage is read on demand.
      liveRegion: value == null && widget.semanticLabel != null,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Painted, not built: the arc follows the spring and the spin
            // in a layer of its own.
            RepaintBoundary(
              child: CustomPaint(
                painter: RingPainter(
                  color: widget.color ?? bar.color ?? theme.colorScheme.tint,
                  trackColor:
                      widget.trackColor ??
                      bar.trackColor ??
                      theme.colorScheme.muted,
                  strokeWidth: strokeWidth,
                  trackStart: _trackStart,
                  trackSweep: widget.sweepAngle,
                  arc: _arc,
                  opacity: _spinning && _still == _Stillness.breathing
                      ? _breath
                      : null,
                  repaint: _repaint,
                ),
              ),
            ),
            if (widget.child != null)
              Padding(
                padding: EdgeInsets.all(strokeWidth * 2),
                child: Center(
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                    child: IconTheme.merge(
                      data: IconThemeData(size: size * .4),
                      child: widget.child!,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Stillness { moving, breathing, still }

import 'package:flutter/widgets.dart';
import 'package:una/src/components/ring_painter.dart';
import 'package:una/src/components/spinner_painters.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/debug_check.dart';
import 'package:una/src/utils/progress_semantics.dart';

/// The looks of a [Spinner].
enum SpinnerVariant {
  /// An arc that turns while it grows and shrinks, over a faint track: the
  /// indeterminate `ProgressRing`, small. The default.
  ring,

  /// Three comets chasing each other round a circle, bunching up and
  /// flinging apart, each with a tail as long as it is fast.
  orbit,

  /// A shape that keeps changing its mind — clover, sun, triangle, pill,
  /// flower, pentagon — twisting into each with a little overshoot.
  morph,

  /// A drop of goo that splits into three droplets on stretching necks and
  /// pulls itself back together.
  goo,

  /// A ring of dots with a wave of light running round it: each dot swells
  /// and glows as it passes, then settles. At home on a dark pill or a
  /// photograph, in the colour of the text beside it.
  halo,
}

/// {@template Spinner}
/// An indeterminate loading indicator.
///
/// The small inline indicator you put inside a button or next to a label
/// while an action is in flight; `ProgressRing` with a null value is the
/// larger one, and `ProgressBar` the linear one.
///
/// ```dart
/// Button(
///   onPressed: submitting ? null : submit,
///   leading: submitting ? const Spinner(size: 16) : null,
///   child: const Text('Save'),
/// )
/// ```
///
/// It comes in four variants ([SpinnerVariant]): the ring (the default, the
/// indeterminate progress ring), orbit, morph and goo. Pass `variant:`, use
/// the named constructors, which are shortcuts for it, or set
/// `SpinnerTheme.variant` to change every spinner below — a button's
/// `loading` spinner included.
///
/// A spinner takes the ambient icon colour, so it spins in a button's own
/// content colour. Under reduced motion it holds still and breathes; with
/// `Motion.none` it holds still.
/// {@endtemplate}
class Spinner extends StatefulWidget {
  /// {@macro Spinner}
  const Spinner({
    super.key,
    this.variant,
    this.size,
    this.color,
    this.trackColor,
    this.strokeWidth,
    this.duration,
    this.semanticLabel,
  });

  /// Three comets chasing each other round a circle ([SpinnerVariant.orbit]).
  const Spinner.orbit({
    super.key,
    this.size,
    this.color,
    this.duration,
    this.semanticLabel,
  }) : variant = SpinnerVariant.orbit,
       trackColor = null,
       strokeWidth = null;

  /// A shape that keeps changing ([SpinnerVariant.morph]).
  const Spinner.morph({
    super.key,
    this.size,
    this.color,
    this.duration,
    this.semanticLabel,
  }) : variant = SpinnerVariant.morph,
       trackColor = null,
       strokeWidth = null;

  /// A drop of goo that splits and merges ([SpinnerVariant.goo]).
  const Spinner.goo({
    super.key,
    this.size,
    this.color,
    this.duration,
    this.semanticLabel,
  }) : variant = SpinnerVariant.goo,
       trackColor = null,
       strokeWidth = null;

  /// A ring of dots with a wave of light running round it
  /// ([SpinnerVariant.halo]).
  const Spinner.halo({
    super.key,
    this.size,
    this.color,
    this.duration,
    this.semanticLabel,
  }) : variant = SpinnerVariant.halo,
       trackColor = null,
       strokeWidth = null;

  /// {@template Spinner.variant}
  /// The look of the spinner. Defaults to [SpinnerVariant.ring].
  /// {@endtemplate}
  final SpinnerVariant? variant;

  /// {@template Spinner.size}
  /// The diameter of the spinner, defaults to 16.
  /// {@endtemplate}
  final double? size;

  /// {@template Spinner.color}
  /// The colour of the spinner. Defaults to the ambient icon colour.
  /// {@endtemplate}
  final Color? color;

  /// {@template Spinner.trackColor}
  /// The colour of the ring behind the ring variant's arc. Defaults to the
  /// spinner's colour at a fifth of its strength.
  ///
  /// Pass a fully transparent colour for an arc with no visible track.
  /// {@endtemplate}
  final Color? trackColor;

  /// {@template Spinner.strokeWidth}
  /// The thickness of the ring variant's arc. Defaults to a tenth of the
  /// size from 30 points up; below that the line keeps its weight — 3
  /// points — as the ring shrinks, and only a very small ring (under about
  /// 18 points) thins with it, to a sixth of its size.
  /// {@endtemplate}
  final double? strokeWidth;

  /// {@template Spinner.duration}
  /// The length of one cycle: a grow and shrink of the ring, a lap of the
  /// orbit, a change of shape, a split and merge of the goo, a lap of the
  /// halo's wave. Defaults to the variant's own (1333, 1500, 750, 1700 and
  /// 1100 ms); the rest of the
  /// animation keeps pace with it.
  /// {@endtemplate}
  final Duration? duration;

  /// The accessible name announced while the spinner is visible.
  final String? semanticLabel;

  @override
  State<Spinner> createState() => _SpinnerState();
}

enum _Stillness { moving, breathing, still }

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  // One clock over a long loop; each painter reads the time off it and
  // draws its own frame, so nothing is rebuilt while it spins. The loop is
  // the ring's whole one, so the default never jumps.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: indeterminateArcLoop,
  );

  _Stillness _still = _Stillness.moving;

  /// The variant's own cycle and the one asked for, as a ratio.
  double _speed = 1;

  SpinnerPainter? _painter;
  SpinnerVariant? _painterVariant;
  Color? _painterColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Spinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  SpinnerVariant get _variant =>
      widget.variant ??
      Theme.of(context).spinnerTheme.variant ??
      SpinnerVariant.ring;

  void _sync() {
    final motion = Motion.of(context);
    _still = !motion.reduced
        ? _Stillness.moving
        : motion.fast == Duration.zero
        ? _Stillness.still
        : _Stillness.breathing;
    if (_still == _Stillness.still) {
      _clock
        ..stop()
        ..value = 0;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Duration get _elapsed => indeterminateArcLoop * _clock.value;

  Duration _naturalCycle(SpinnerVariant variant) => switch (variant) {
    SpinnerVariant.ring => indeterminateArcCycle,
    _ => _painter!.cycle,
  };

  Duration _restingTime(SpinnerVariant variant) => switch (variant) {
    SpinnerVariant.ring => indeterminateArcCycle * .3,
    _ => _painter!.restingTime,
  };

  /// The time a painter draws: the clock at the variant's pace, or the
  /// resting moment while the spinner holds still.
  Duration _time(SpinnerVariant variant) =>
      _still == _Stillness.moving ? _elapsed * _speed : _restingTime(variant);

  double _opacity() =>
      _still == _Stillness.breathing ? spinnerBreath(_elapsed) : 1;

  ({double start, double sweep}) _arc() =>
      indeterminateArc(_time(SpinnerVariant.ring));

  SpinnerFrame _frame() => (time: _time(_painterVariant!), opacity: _opacity());

  /// The painter of a variant other than the ring, kept while its variant
  /// and colour are, so a rebuild does not repaint it for nothing.
  SpinnerPainter _painterFor(SpinnerVariant variant, Color color) {
    if (_painter == null ||
        _painterVariant != variant ||
        _painterColor != color) {
      _painterVariant = variant;
      _painterColor = color;
      _painter = switch (variant) {
        SpinnerVariant.orbit => OrbitSpinnerPainter(
          color: color,
          frame: _frame,
          repaint: _clock,
        ),
        SpinnerVariant.morph => MorphSpinnerPainter(
          color: color,
          frame: _frame,
          repaint: _clock,
        ),
        SpinnerVariant.goo => GooSpinnerPainter(
          color: color,
          frame: _frame,
          repaint: _clock,
        ),
        SpinnerVariant.halo => HaloSpinnerPainter(
          color: color,
          frame: _frame,
          repaint: _clock,
        ),
        SpinnerVariant.ring => throw StateError(
          'The ring is painted by a RingPainter',
        ),
      };
    }
    return _painter!;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasTheme(context));
    final theme = Theme.of(context);
    final spinnerTheme = theme.spinnerTheme;
    final variant = _variant;

    final effectiveSize = widget.size ?? spinnerTheme.size ?? 16.0;
    // shadcn's spinner is an icon in `text-current`: inside a button it spins
    // in the button's own content colour. The ambient IconTheme carries that,
    // so it sits between the explicit overrides and the primary fallback.
    final effectiveColor =
        widget.color ??
        spinnerTheme.color ??
        IconTheme.of(context).color ??
        theme.colorScheme.primary;

    final CustomPainter painter;
    if (variant == SpinnerVariant.ring) {
      _painter = null;
      _painterVariant = null;
      painter = RingPainter(
        color: effectiveColor,
        trackColor:
            widget.trackColor ??
            spinnerTheme.trackColor ??
            effectiveColor.withValues(alpha: effectiveColor.a * .2),
        strokeWidth:
            widget.strokeWidth ??
            spinnerTheme.strokeWidth ??
            ringStrokeFor(effectiveSize),
        arc: _arc,
        opacity: _still == _Stillness.breathing ? _opacity : null,
        repaint: _clock,
      );
    } else {
      painter = _painterFor(variant, effectiveColor);
    }
    final cycle = widget.duration ?? spinnerTheme.duration;
    _speed = cycle == null || cycle <= Duration.zero
        ? 1
        : _naturalCycle(variant).inMicroseconds / cycle.inMicroseconds;

    // The spin is painted, not built: the painter follows the clock in a
    // layer of its own and nothing is rebuilt while it turns.
    Widget spinner = SizedBox.square(
      dimension: effectiveSize,
      child: RepaintBoundary(child: CustomPaint(painter: painter)),
    );

    if (widget.semanticLabel != null) {
      spinner = progressSemantics(
        determinate: false,
        label: widget.semanticLabel,
        value: null,
        liveRegion: true,
        child: spinner,
      );
    }
    return spinner;
  }
}

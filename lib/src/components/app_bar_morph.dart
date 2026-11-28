import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode, lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/components/app_bar_layout.dart';
import 'package:una/src/components/back_button.dart';
import 'package:una/src/components/button.dart';
import 'package:una/src/components/icon_button.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/backdrop.dart';

// The chrome of a Liquid Glass bar stays where it is while the page under
// it is pushed or popped, and turns into the next page's: iOS 26's
// navigation bar, whose back button and actions belong to the navigation
// stack rather than to a screen, while the title moves with its page.
// Internal.
//
// Each page keeps its own bar, so nothing has to be declared above the
// navigator. The toolbar is drawn in two layers over one layout: the
// title (and a leading logo) in the page, and the capsules of glass in a
// `Hero` tagged with the navigator. Between two pages that both have one,
// the flight draws one set of capsules in place and the pages, titles
// and all, slide under it.
//
// The choreography is the one `liquid_glass_widgets` measured from iOS 26
// for its pinned bar (`GlassNavPinnedMetrics`), played on the clock of
// the page being entered — a pop plays it towards the page below, not as
// the push rewound. A capsule both pages have reshapes on a spring that
// lands with the page, swelling like gel on the way; a button both have
// holds still, one that changes blurs away as its successor sharpens in.
// A capsule only one page has materializes or dissolves. Under a back
// swipe the chrome holds still until the swipe is let go, then
// cross-fades over what is left of the way.

/// What the glass of a toolbar is made of, for the flight to the next
/// page's: its parts as the page gave them, before they were put on
/// capsules.
@immutable
class BarMorphData {
  /// Records a toolbar's glass.
  const BarMorphData({
    required this.height,
    required this.leading,
    required this.actions,
    required this.buttonVariant,
    required this.centerTitle,
    this.padding,
    this.maxWidth,
    this.gap,
    this.actionsGap,
  });

  /// The toolbar's height.
  final double height;

  /// The button at the start, on a capsule of its own; null for none (a
  /// logo stays with the page).
  final Widget? leading;

  /// The buttons at the end, on one capsule.
  final List<Widget> actions;

  /// The look the bar gives its buttons.
  final ButtonVariant buttonVariant;

  /// Whether the title is centred.
  final bool centerTitle;

  /// The toolbar's padding, as the bar was given it.
  final EdgeInsetsGeometry? padding;

  /// The widest the toolbar's content grows, as the bar was given it.
  final double? maxWidth;

  /// The gap around the title, as the bar was given it.
  final double? gap;

  /// The gap between the actions, as the bar was given it.
  final double? actionsGap;
}

/// The tag of the bars of one navigator: two of its pages each have one,
/// so a push or pop between them flies one into the other.
@immutable
class _BarTag {
  const _BarTag(this.navigator);

  final NavigatorState navigator;

  @override
  bool operator ==(Object other) =>
      other is _BarTag && identical(other.navigator, navigator);

  @override
  int get hashCode => identityHashCode(navigator);
}

/// The row of a bar on Liquid Glass, whose capsules stay in place between
/// two pages of its navigator and turn into the other page's: see the
/// comment at the top of this file. Takes [AppBarToolbar]'s parts, with
/// [leading] and [actions] already on their capsules and [rawLeading] and
/// [rawActions] as they were before.
class BarMorph extends StatefulWidget {
  /// Creates the row of a bar on Liquid Glass.
  const BarMorph({
    required this.height,
    required this.leading,
    required this.rawLeading,
    required this.title,
    required this.actions,
    required this.rawActions,
    required this.buttonVariant,
    required this.centerTitle,
    this.padding,
    this.maxWidth,
    this.gap,
    this.actionsGap,
    super.key,
  });

  /// The row's height.
  final double height;

  /// The widget at the start, on its capsule if it is a button.
  final Widget? leading;

  /// [leading] before it was put on a capsule.
  final Widget? rawLeading;

  /// The title.
  final Widget? title;

  /// The widgets at the end, on their capsule.
  final List<Widget> actions;

  /// [actions] before they were put on a capsule.
  final List<Widget> rawActions;

  /// See [AppBarToolbar.buttonVariant].
  final ButtonVariant buttonVariant;

  /// See [AppBarToolbar.centerTitle].
  final bool centerTitle;

  /// See [AppBarToolbar.padding].
  final EdgeInsetsGeometry? padding;

  /// See [AppBarToolbar.maxWidth].
  final double? maxWidth;

  /// See [AppBarToolbar.gap].
  final double? gap;

  /// See [AppBarToolbar.actionsGap].
  final double? actionsGap;

  @override
  State<BarMorph> createState() => _BarMorphState();

  static Widget _flight(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = ((fromHeroContext.widget as Hero).child as _BarPayload).data;
    final to = ((toHeroContext.widget as Hero).child as _BarPayload).data;
    final push = direction == HeroFlightDirection.push;
    // The page on top runs the clock both ways: 0 to 1 coming in, 1 to 0
    // going.
    final top = ModalRoute.of(push ? toHeroContext : fromHeroContext)!;
    return _BarFlight(
      from: from,
      to: to,
      top: top,
      push: push,
      navigator: Navigator.of(fromHeroContext),
    );
  }
}

class _BarMorphState extends State<BarMorph> {
  // The toolbar keeps its state while a flight shows it as the hero's
  // placeholder, under another parent.
  final _toolbarKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final navigator = Navigator.maybeOf(context);
    final route = ModalRoute.of(context);
    final flies = w.leading is LiquidGlassBarGroup;
    Widget toolbar({Widget? leading, List<Widget>? actions}) => AppBarToolbar(
      height: w.height,
      leading: leading,
      title: w.title,
      actions: actions ?? const [],
      buttonVariant: w.buttonVariant,
      centerTitle: w.centerTitle,
      padding: w.padding,
      maxWidth: w.maxWidth,
      gap: w.gap,
      actionsGap: w.actionsGap,
    );
    // Only a page's bar: one in a dialog or a sheet stays with it.
    if (navigator == null || route is! PageRoute || route.fullscreenDialog) {
      return toolbar(leading: w.leading, actions: w.actions);
    }
    return Hero(
      tag: _BarTag(navigator),
      transitionOnUserGestures: true,
      flightShuttleBuilder: BarMorph._flight,
      // While the glass flies, the page keeps its toolbar with the glass
      // hidden, so the title goes with the page.
      placeholderBuilder: (context, size, child) => _InFlight(child: child),
      child: _BarPayload(
        key: _toolbarKey,
        data: BarMorphData(
          height: w.height,
          leading: flies ? w.rawLeading : null,
          actions: w.rawActions,
          buttonVariant: w.buttonVariant,
          centerTitle: w.centerTitle,
          padding: w.padding,
          maxWidth: w.maxWidth,
          gap: w.gap,
          actionsGap: w.actionsGap,
        ),
        child: toolbar(
          leading: flies ? _Glass(w.leading!) : w.leading,
          actions: [for (final a in w.actions) _Glass(a)],
        ),
      ),
    );
  }
}

/// Marks a toolbar whose glass is flying.
class _InFlight extends InheritedWidget {
  const _InFlight({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InFlight>() != null;

  @override
  bool updateShouldNotify(_InFlight oldWidget) => false;
}

/// A capsule of the toolbar, hidden while a flight draws it — its place
/// kept, and its state.
class _Glass extends StatelessWidget {
  const _Glass(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Visibility(
    visible: !_InFlight.of(context),
    maintainState: true,
    maintainAnimation: true,
    maintainSize: true,
    child: child,
  );
}

/// The toolbar, carrying what its glass is made of to its flight.
class _BarPayload extends StatelessWidget {
  const _BarPayload({required this.data, required this.child, super.key});

  final BarMorphData data;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The timing of the flight, as `liquid_glass_widgets` measured it from
/// iOS 26 (`GlassNavPinnedMetrics`), over the flight's progress `q`: 0 on
/// the page being left, 1 on the page being entered.
abstract final class _Choreography {
  /// Where the capsules start to reshape.
  static const morphStart = .03;

  /// The reshaping's own progress at [q].
  static double morph(double q) =>
      ((q - morphStart) / (1 - morphStart)).clamp(0.0, 1.0);

  /// The window of the reshaping in which a changed button cross-fades.
  static const crossFadeStart = .25;
  static const crossFadeEnd = .6;

  static double crossFade(double morph) =>
      ((morph - crossFadeStart) / (crossFadeEnd - crossFadeStart)).clamp(
        0.0,
        1.0,
      );

  /// How much a reshaping capsule swells, and over how much of the way.
  static const swellAmount = .22;
  static const swellWindow = .6;

  static double swell(double morph) =>
      swellAmount * math.sin(math.pi * (morph / swellWindow).clamp(0.0, 1.0));

  /// How much of the spring's overshoot squeezes the capsule as it lands.
  static const squeeze = .35;

  /// The blur a leaving button smears away under.
  static double outgoingSigma(double morph) => 6 * (morph * 3).clamp(0.0, 1.0);

  /// The blur an arriving button sharpens from.
  static double incomingSigma(double morph) =>
      3.5 * (1 - ((morph - .48) / (.9 - .48)).clamp(0.0, 1.0));

  /// How far a capsule only one page has is there at [q]: one only the
  /// page entered has materializes over the second half, one only the
  /// page left has dissolves over the first.
  static double presence(double q, {required bool entering}) => entering
      ? ((q - .45) / .55).clamp(0.0, 1.0)
      : 1 - (q / .55).clamp(0.0, 1.0);

  /// A capsule materializing: its glass first, its buttons sharpening
  /// last.
  static const entranceGlass = Interval(0, .92);
  static const entranceContent = Interval(.35, 1);

  /// A capsule dissolving: its buttons gone first, an empty shell after.
  static const exitContent = Interval(.45, 1);

  /// The blur of a materializing capsule's buttons at their softest.
  static const materializeSigma = 8.0;

  /// The size a capsule swells to while it is not there.
  static const materializeScale = 1.1;
}

/// The capsules of glass drawn in place, from [from]'s at the start of the
/// flight to [to]'s at its end.
class _BarFlight extends StatefulWidget {
  const _BarFlight({
    required this.from,
    required this.to,
    required this.top,
    required this.push,
    required this.navigator,
  });

  final BarMorphData from;
  final BarMorphData to;

  /// The page on top, whose animation is the flight's clock.
  final ModalRoute<Object?> top;

  /// Whether [top] is coming in; otherwise it is going.
  final bool push;

  final NavigatorState navigator;

  @override
  State<_BarFlight> createState() => _BarFlightState();
}

class _BarFlightState extends State<_BarFlight> {
  late Listenable _clock;

  // Where the top page was when a back swipe was let go and committed.
  double? _released;

  @override
  void initState() {
    super.initState();
    _clock = Listenable.merge([
      widget.top.animation,
      widget.navigator.userGestureInProgressNotifier,
    ]);
  }

  /// The flight's progress, and whether it is a plain cross-fade.
  (double, bool) _progress() {
    final a = widget.top.animation!.value;
    if (widget.push) return (a, false);
    if (widget.navigator.userGestureInProgress) {
      // Held under the finger: the swipe may yet be let go back.
      if (widget.top.isActive) return (0, false);
      // Let go towards the page below: a cross-fade over the rest of the
      // way, as iOS 26 does after a swipe.
      final released = _released ??= a;
      return (released <= 0 ? 1 : (1 - a / released).clamp(0.0, 1.0), true);
    }
    return (1 - a, _released != null);
  }

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final spring = motion.bouncy.curve;
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final (q, fade) = _progress();
        final plain = fade || motion.reduced;
        final from = widget.from;
        final to = widget.to;
        final shape = plain ? q : spring.transform(_Choreography.morph(q));
        return AppBarToolbar(
          height: lerpDouble(from.height, to.height, shape.clamp(0.0, 1.0))!,
          leading: _cluster(
            context,
            [?from.leading],
            [?to.leading],
            q: q,
            shape: shape,
            plain: plain,
            gap: 0,
            atStart: true,
          ),
          actions: [
            ?_cluster(
              context,
              from.actions,
              to.actions,
              q: q,
              shape: shape,
              plain: plain,
              gap: to.actionsGap ?? Theme.of(context).layoutTheme.gapSm ?? 8,
              atStart: false,
            ),
          ],
          buttonVariant: to.buttonVariant,
          centerTitle: to.centerTitle,
          padding: to.padding,
          maxWidth: to.maxWidth,
          gap: to.gap,
          actionsGap: to.actionsGap,
        );
      },
    );
  }

  /// One capsule turning from [from]'s buttons into [to]'s at progress
  /// [q], its shape at [shape] (on the spring, so past 1 on the way to
  /// landing).
  Widget? _cluster(
    BuildContext context,
    List<Widget> from,
    List<Widget> to, {
    required double q,
    required double shape,
    required bool plain,
    required double gap,
    required bool atStart,
  }) {
    if (from.isEmpty && to.isEmpty) return null;
    final alignment =
        (atStart
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd)
            .resolve(Directionality.of(context));

    // There on one side only: it materializes or dissolves.
    if (from.isEmpty || to.isEmpty) {
      final entering = from.isEmpty;
      final buttons = entering ? to : from;
      final double glass;
      final double content;
      if (plain) {
        glass = entering ? q : 1 - q;
        content = glass;
      } else {
        final phase = _Choreography.presence(q, entering: entering);
        glass = entering ? _Choreography.entranceGlass.transform(phase) : phase;
        content = entering
            ? _Choreography.entranceContent.transform(phase)
            : _Choreography.exitContent.transform(phase);
      }
      if (glass <= 0) return const SizedBox.shrink();
      final sigma = plain
          ? 0.0
          : _Choreography.materializeSigma * (1 - content);
      final scale = plain
          ? 1.0
          : _Choreography.materializeScale +
                (1 - _Choreography.materializeScale) * glass;
      final capsule = LiquidGlassBarGroup(
        children: [
          _Cluster(
            shape: 1,
            scale: 1,
            gap: gap,
            atStart: atStart,
            children: [
              for (final b in buttons)
                _ClusterItem(
                  isFrom: false,
                  opacity: content,
                  sigma: sigma,
                  child: b,
                ),
            ],
          ),
        ],
      );
      // The fade goes through the glass's own host: an opacity layer
      // around glass would switch it off.
      return BackdropFadeHost(
        opacity: AlwaysStoppedAnimation(glass),
        child: scale == 1
            ? capsule
            : Transform.scale(
                scale: scale,
                alignment: alignment,
                child: capsule,
              ),
      );
    }

    // On both sides: matched button by button from the capsule's anchored
    // end, as UIKit matches bar items by position.
    final morph = _Choreography.morph(q);
    final crossFade = plain ? q : _Choreography.crossFade(morph);
    final outSigma = plain ? 0.0 : _Choreography.outgoingSigma(morph);
    final inSigma = plain ? 0.0 : _Choreography.incomingSigma(morph);
    int slotOf(int index, int length) => atStart ? index : length - 1 - index;
    final kept = <int>{};
    for (var slot = 0; slot < math.min(from.length, to.length); slot++) {
      final a = from[slotOf(slot, from.length)];
      final b = to[slotOf(slot, to.length)];
      if (_sameButton(a, b)) kept.add(slot);
    }
    final changes = from.length != to.length || kept.length != to.length;
    final overshoot = (shape - 1).clamp(0.0, 1.0);
    final scale = plain || !changes
        ? 1.0
        : 1 + _Choreography.swell(morph) - _Choreography.squeeze * overshoot;
    return LiquidGlassBarGroup(
      children: [
        _Cluster(
          shape: plain ? q : shape.clamp(0.0, 1.0),
          scale: scale,
          gap: gap,
          atStart: atStart,
          children: [
            for (var i = 0; i < from.length; i++)
              _ClusterItem(
                isFrom: true,
                // A button both have is drawn once, by the page entered.
                opacity: kept.contains(slotOf(i, from.length))
                    ? 0
                    : 1 - crossFade,
                sigma: outSigma,
                child: from[i],
              ),
            for (var i = 0; i < to.length; i++)
              _ClusterItem(
                isFrom: false,
                opacity: kept.contains(slotOf(i, to.length)) ? 1 : crossFade,
                sigma: kept.contains(slotOf(i, to.length)) ? 0 : inSigma,
                child: to[i],
              ),
          ],
        ),
      ],
    );
  }
}

/// Whether two bar buttons draw the same thing, so the button can hold
/// still while its capsule changes around it: the same widget, or two
/// icon buttons with the same glyph.
bool _sameButton(Widget a, Widget b) {
  if (identical(a, b)) return true;
  if (a.runtimeType != b.runtimeType || a.key != b.key) return false;
  return switch ((a, b)) {
    (BackButton(), BackButton()) || (CloseButton(), CloseButton()) => true,
    (final IconButton x, final IconButton y) =>
      x.variant == y.variant &&
          x.semanticLabel == y.semanticLabel &&
          _sameIcon(x.icon, y.icon),
    _ => false,
  };
}

bool _sameIcon(Widget a, Widget b) {
  if (identical(a, b)) return true;
  return a is Icon &&
      b is Icon &&
      a.runtimeType == b.runtimeType &&
      a.icon == b.icon &&
      a.size == b.size &&
      a.color == b.color &&
      a.key == b.key;
}

/// A button in a [_Cluster]: which page it is from, and how it is drawn.
class _ClusterItem extends ParentDataWidget<_ClusterData> {
  const _ClusterItem({
    required this.isFrom,
    required this.opacity,
    required this.sigma,
    required super.child,
  });

  final bool isFrom;
  final double opacity;
  final double sigma;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _ClusterData;
    if (data.isFrom == isFrom &&
        data.opacity == opacity &&
        data.sigma == sigma) {
      return;
    }
    final layout = data.isFrom != isFrom;
    data
      ..isFrom = isFrom
      ..opacity = opacity
      ..sigma = sigma;
    final parent = renderObject.parent;
    if (parent is RenderObject) {
      layout ? parent.markNeedsLayout() : parent.markNeedsPaint();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _Cluster;
}

/// The buttons of two pages in one capsule: each page's laid out in a row
/// [gap] apart, matched from the anchored end, every button moving from
/// its place in the first row to its place in the second, and the whole
/// as wide as the one row eased into the other by [shape], swollen by
/// [scale].
class _Cluster extends MultiChildRenderObjectWidget {
  const _Cluster({
    required this.shape,
    required this.scale,
    required this.gap,
    required this.atStart,
    required super.children,
  });

  final double shape;
  final double scale;
  final double gap;
  final bool atStart;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCluster(
    shape: shape,
    scale: scale,
    gap: gap,
    atStart: atStart,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderCluster)
      ..shape = shape
      ..scale = scale
      ..gap = gap
      ..atStart = atStart
      ..textDirection = Directionality.of(context);
  }
}

class _ClusterData extends ContainerBoxParentData<RenderBox> {
  bool isFrom = false;
  double opacity = 1;
  double sigma = 0;
  final opacityLayer = LayerHandle<OpacityLayer>();
  final blurLayer = LayerHandle<ImageFilterLayer>();
}

class _RenderCluster extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ClusterData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ClusterData> {
  _RenderCluster({
    required double shape,
    required double scale,
    required double gap,
    required bool atStart,
    required TextDirection textDirection,
  }) : _shape = shape,
       _scale = scale,
       _gap = gap,
       _atStart = atStart,
       _textDirection = textDirection;

  double get shape => _shape;
  double _shape;
  set shape(double value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsLayout();
  }

  double get scale => _scale;
  double _scale;
  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    markNeedsLayout();
  }

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  bool get atStart => _atStart;
  bool _atStart;
  set atStart(bool value) {
    if (value == _atStart) return;
    _atStart = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  // The box before the swell, which paint scales up to [size].
  Size _unswollen = Size.zero;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ClusterData) child.parentData = _ClusterData();
  }

  _ClusterData _data(RenderBox child) => child.parentData! as _ClusterData;

  @override
  void performLayout() {
    final from = <RenderBox>[];
    final to = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      child.layout(constraints.loosen(), parentUsesSize: true);
      (_data(child).isFrom ? from : to).add(child);
      child = childAfter(child);
    }

    // Each button's distance from the anchored end of its own row, and
    // the row's size.
    (List<double>, Size) row(List<RenderBox> boxes) {
      final ordered = _atStart ? boxes : boxes.reversed.toList();
      final distances = <double>[];
      var x = 0.0;
      var height = 0.0;
      for (final box in ordered) {
        distances.add(x);
        x += box.size.width + _gap;
        height = math.max(height, box.size.height);
      }
      final width = boxes.isEmpty ? 0.0 : x - _gap;
      return (
        _atStart ? distances : distances.reversed.toList(),
        Size(width, height),
      );
    }

    final (fromAt, fromSize) = row(from);
    final (toAt, toSize) = row(to);
    final t = _shape;
    final Size box;
    if (from.isEmpty) {
      box = toSize;
    } else if (to.isEmpty) {
      box = fromSize;
    } else {
      box = Size.lerp(fromSize, toSize, t)!;
    }
    _unswollen = box;
    size = constraints.constrain(box * _scale);

    // Matched from the anchored end: slot k of each row.
    int slotOf(int index, int length) => _atStart ? index : length - 1 - index;
    final fromBySlot = {
      for (var i = 0; i < from.length; i++) slotOf(i, from.length): i,
    };
    final toBySlot = {
      for (var i = 0; i < to.length; i++) slotOf(i, to.length): i,
    };
    final anchorLeft = _atStart == (_textDirection == TextDirection.ltr);
    void place(RenderBox child, double distance) {
      final x = anchorLeft ? distance : box.width - distance - child.size.width;
      _data(child).offset = Offset(x, (box.height - child.size.height) / 2);
    }

    for (var i = 0; i < from.length; i++) {
      final partner = toBySlot[slotOf(i, from.length)];
      place(
        from[i],
        partner == null ? fromAt[i] : lerpDouble(fromAt[i], toAt[partner], t)!,
      );
    }
    for (var i = 0; i < to.length; i++) {
      final partner = fromBySlot[slotOf(i, to.length)];
      place(
        to[i],
        partner == null ? toAt[i] : lerpDouble(fromAt[partner], toAt[i], t)!,
      );
    }
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    void paintChildren(PaintingContext context, Offset offset) {
      var child = firstChild;
      while (child != null) {
        final data = _data(child);
        final alpha = (data.opacity.clamp(0.0, 1.0) * 255).round();
        if (alpha <= 0) {
          data.opacityLayer.layer = null;
          data.blurLayer.layer = null;
        } else {
          final box = child;
          void paintChild(PaintingContext context, Offset offset) {
            if (data.sigma <= .01) {
              data.blurLayer.layer = null;
              context.paintChild(box, offset);
              return;
            }
            final layer = data.blurLayer.layer ??= ImageFilterLayer();
            layer.imageFilter = ImageFilter.blur(
              sigmaX: data.sigma,
              sigmaY: data.sigma,
              tileMode: TileMode.decal,
            );
            context.pushLayer(
              layer,
              (context, offset) => context.paintChild(box, offset),
              offset,
            );
          }

          data.opacityLayer.layer = context.pushOpacity(
            offset + data.offset,
            alpha,
            paintChild,
            oldLayer: data.opacityLayer.layer,
          );
        }
        child = childAfter(child);
      }
    }

    if (_scale == 1) {
      _transformLayer.layer = null;
      paintChildren(context, offset);
      return;
    }
    // The swell: the buttons grow with their capsule, about its centre.
    final transform = Matrix4.translationValues(offset.dx, offset.dy, 0)
      ..multiply(_swell());
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      Offset.zero,
      transform,
      paintChildren,
      oldLayer: _transformLayer.layer,
    );
  }

  final _transformLayer = LayerHandle<TransformLayer>();

  /// The swell, about the centre of the box, from the box laid out before
  /// it to [size].
  Matrix4 _swell() {
    final centre = size.center(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(_scale, _scale, 1, 1)
      ..translateByDouble(-_unswollen.width / 2, -_unswollen.height / 2, 0, 1);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_scale != 1) transform.multiply(_swell());
    super.applyPaintTransform(child, transform);
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    var child = firstChild;
    while (child != null) {
      _data(child)
        ..opacityLayer.layer = null
        ..blurLayer.layer = null;
      child = childAfter(child);
    }
    super.dispose();
  }

  // A flight takes no input.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;
}

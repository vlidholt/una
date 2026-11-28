import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/components/app_bar_layout.dart';
import 'package:una/src/components/button.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/utils/backdrop.dart';

// A Liquid Glass bar that stays where it is while the page under it is
// pushed or popped, and turns into the next page's bar: iOS 26's
// navigation bar, whose items belong to the navigation stack rather than
// to a screen. Internal.
//
// Each page keeps its own bar, so nothing has to be declared above the
// navigator: a bar's toolbar is a `Hero` tagged with its navigator, and
// between two pages that both have one the flight draws a single toolbar
// in place — the pages slide under it. Its capsules are one surface each,
// whose width eases from the buttons of one page to those of the next
// while the buttons cross-fade; a capsule only one page has materializes
// or dissolves; the titles cross-fade with a short slide in the direction
// of travel. A swipe back carries the flight with the finger.
//
// Only the toolbar flies. A bar's scroll edge, and a row under the toolbar
// (tabs), belong to the page and move with it, as on iOS 26. A filled bar
// is not a hero: it moves with its page, as Material's does.

/// What a toolbar on Liquid Glass is made of, for the flight to the next
/// page's: its parts as the page gave them, before they were put on
/// capsules.
@immutable
class BarMorphData {
  /// Records a toolbar's parts.
  const BarMorphData({
    required this.height,
    required this.leading,
    required this.title,
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

  /// The button at the start, or a logo; null for none.
  final Widget? leading;

  /// The title.
  final Widget? title;

  /// The buttons at the end.
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

/// Makes [child], a toolbar on Liquid Glass, stay in place between two
/// pages of its navigator and turn into the other page's: see the comment
/// at the top of this file.
class BarMorph extends StatelessWidget {
  /// Lets [child] fly between pages, drawn from [data].
  const BarMorph({required this.data, required this.child, super.key});

  /// What the toolbar is made of.
  final BarMorphData data;

  /// The toolbar.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    final route = ModalRoute.of(context);
    // Only a page's bar: one in a dialog or a sheet stays with it.
    if (navigator == null || route is! PageRoute || route.fullscreenDialog) {
      return child;
    }
    return Hero(
      tag: _BarTag(navigator),
      transitionOnUserGestures: true,
      flightShuttleBuilder: _flight,
      child: _BarPayload(data: data, child: child),
    );
  }

  static Widget _flight(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = ((fromHeroContext.widget as Hero).child as _BarPayload).data;
    final to = ((toHeroContext.widget as Hero).child as _BarPayload).data;
    return _BarFlight(
      from: from,
      to: to,
      animation: animation,
      forward: direction == HeroFlightDirection.push,
    );
  }
}

/// The toolbar, carrying what it is made of to its flight.
class _BarPayload extends StatelessWidget {
  const _BarPayload({required this.data, required this.child});

  final BarMorphData data;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// One toolbar drawn in place, from [from]'s parts at 0 to [to]'s at 1.
class _BarFlight extends StatefulWidget {
  const _BarFlight({
    required this.from,
    required this.to,
    required this.animation,
    required this.forward,
  });

  final BarMorphData from;
  final BarMorphData to;
  final Animation<double> animation;
  final bool forward;

  @override
  State<_BarFlight> createState() => _BarFlightState();
}

class _BarFlightState extends State<_BarFlight> {
  // The flight's progress on the page's own curve, so the bar keeps pace
  // with the page sliding under it.
  late Animation<double> _t;
  Curve? _curve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_BarFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.animation, widget.animation)) _curve = null;
    _sync();
  }

  void _sync() {
    final motion = Motion.of(context);
    final curve = motion.reduced ? motion.standard : motion.smooth.curve;
    if (curve == _curve) return;
    _curve = curve;
    _t = widget.animation.drive(CurveTween(curve: curve));
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.from;
    final to = widget.to;
    // Within its box: the flight is laid out at the hero's size.
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final t = _t.value.clamp(0.0, 1.0);
        return AppBarToolbar(
          height: lerpDouble(from.height, to.height, t)!,
          leading: _capsule(
            [?from.leading],
            [?to.leading],
            t,
            gap: 0,
            alignment: AlignmentDirectional.centerStart,
          ),
          title: _TitleMorph(
            from: from.title,
            to: to.title,
            t: t,
            // Forward, the old title leaves towards the start and the new
            // one comes from the end; back, the other way.
            travel: widget.forward ? 1 : -1,
            centered: to.centerTitle,
          ),
          actions: [
            ?_capsule(
              from.actions,
              to.actions,
              t,
              gap: to.actionsGap ?? from.actionsGap ?? 8,
              alignment: AlignmentDirectional.centerEnd,
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

  /// One capsule of glass whose content turns from [from] into [to]: its
  /// width eases between theirs while they cross-fade. A capsule only one
  /// side has materializes or dissolves.
  Widget? _capsule(
    List<Widget> from,
    List<Widget> to,
    double t, {
    required double gap,
    required AlignmentGeometry alignment,
  }) {
    if (from.isEmpty && to.isEmpty) return null;
    Widget row(List<Widget> children) => children.isEmpty
        ? const SizedBox.shrink()
        : Row(mainAxisSize: MainAxisSize.min, spacing: gap, children: children);
    Widget capsule = LiquidGlassBarGroup(
      children: [
        _CrossSize(
          t: t,
          alignment: alignment,
          from: row(from),
          to: row(to),
        ),
      ],
    );
    // There on one side only: it grows out of nothing, or shrinks into it,
    // as iOS 26 materializes a button. The fade goes through the glass's
    // own host: an opacity layer around glass would switch it off.
    final presence = from.isEmpty
        ? t
        : to.isEmpty
        ? 1 - t
        : 1.0;
    if (presence < 1) {
      capsule = BackdropFadeHost(
        opacity: AlwaysStoppedAnimation(presence),
        child: Transform.scale(
          scale: .6 + .4 * presence,
          alignment: alignment.resolve(Directionality.of(context)),
          child: capsule,
        ),
      );
    }
    return capsule;
  }
}

/// Two titles in one place: [from] fading out and moving a short way
/// towards the start (with [travel] 1), [to] fading in from the end.
class _TitleMorph extends StatelessWidget {
  const _TitleMorph({
    required this.from,
    required this.to,
    required this.t,
    required this.travel,
    required this.centered,
  });

  final Widget? from;
  final Widget? to;
  final double t;
  final double travel;
  final bool centered;

  /// How far a title moves as it fades.
  static const _shift = 24.0;

  @override
  Widget build(BuildContext context) {
    final ltr = Directionality.of(context) == TextDirection.ltr;
    final sign = (ltr ? 1 : -1) * travel;
    // Gone by the middle, in after it: the two are never both legible.
    final out = (1 - t * 2).clamp(0.0, 1.0);
    final into = (t * 2 - 1).clamp(0.0, 1.0);
    Widget place(Widget child, double opacity, double dx) => Opacity(
      opacity: opacity,
      child: Transform.translate(offset: Offset(dx, 0), child: child),
    );
    return Stack(
      alignment: centered ? Alignment.center : AlignmentDirectional.centerStart,
      children: [
        if (from case final from? when out > 0)
          place(from, out, -_shift * sign * t),
        if (to case final to? when into > 0)
          place(to, into, _shift * sign * (1 - t)),
      ],
    );
  }
}

/// Two children in one box as big as the one eased into the other by
/// `t`, the first fading out and the second in, each placed by
/// `alignment`.
class _CrossSize extends MultiChildRenderObjectWidget {
  _CrossSize({
    required this.t,
    required this.alignment,
    required Widget from,
    required Widget to,
  }) : super(children: [from, to]);

  final double t;
  final AlignmentGeometry alignment;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCrossSize(
    t: t,
    alignment: alignment.resolve(Directionality.of(context)),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderCrossSize)
      ..t = t
      ..alignment = alignment.resolve(Directionality.of(context));
  }
}

class _CrossSizeData extends ContainerBoxParentData<RenderBox> {}

class _RenderCrossSize extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CrossSizeData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CrossSizeData> {
  _RenderCrossSize({required double t, required Alignment alignment})
    : _t = t,
      _alignment = alignment;

  double get t => _t;
  double _t;
  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsLayout();
  }

  Alignment get alignment => _alignment;
  Alignment _alignment;
  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  final _fromLayer = LayerHandle<OpacityLayer>();
  final _toLayer = LayerHandle<OpacityLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CrossSizeData) {
      child.parentData = _CrossSizeData();
    }
  }

  @override
  void performLayout() {
    final from = firstChild!;
    final to = childAfter(from)!;
    final loose = constraints.loosen();
    from.layout(loose, parentUsesSize: true);
    to.layout(loose, parentUsesSize: true);
    size = constraints.constrain(Size.lerp(from.size, to.size, _t)!);
    for (final child in [from, to]) {
      (child.parentData! as _CrossSizeData).offset = _alignment.alongOffset(
        (size - child.size) as Offset,
      );
    }
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final from = firstChild!;
    final to = childAfter(from)!;
    void paintWith(
      RenderBox child,
      double opacity,
      LayerHandle<OpacityLayer> h,
    ) {
      final alpha = (opacity * 255).round();
      final at = offset + (child.parentData! as _CrossSizeData).offset;
      if (alpha <= 0) {
        h.layer = null;
        return;
      }
      h.layer = context.pushOpacity(
        at,
        alpha,
        (context, offset) => context.paintChild(child, offset),
        oldLayer: h.layer,
      );
    }

    paintWith(from, 1 - _t, _fromLayer);
    paintWith(to, _t, _toLayer);
  }

  @override
  void dispose() {
    _fromLayer.layer = null;
    _toLayer.layer = null;
    super.dispose();
  }

  // A flight takes no input.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;
}

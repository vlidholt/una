import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/components/back_button.dart';
import 'package:una/src/components/bar_button_scope.dart';
import 'package:una/src/components/button.dart';
import 'package:una/src/components/icon_button.dart';
import 'package:una/src/components/indicator_badge.dart';
import 'package:una/src/components/scaffold.dart';
import 'package:una/src/components/tooltip.dart';
import 'package:una/src/i18n/localizations_delegate.dart';
import 'package:una/src/icons/phosphor_icon.dart';
import 'package:una/src/icons/phosphor_icons_regular.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/liquid_glass/liquid_glass_theme.dart';
import 'package:una/src/theme/components/layout.dart';
import 'package:una/src/theme/form_factor.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/backdrop.dart';

// The parts `AppBar` and `SliverAppBar` are both made of: the toolbar row,
// the bar's surface, and the leading button a bar shows by itself. Internal.

/// How a bar at the top of the page is drawn.
enum AppBarMaterial {
  /// una's own bar: the style's bar colour, over its glass filter where
  /// the colour is translucent, with a hairline under it.
  frosted,

  /// Liquid Glass: no fill and no hairline, the page under the bar blurred
  /// and faded into the page colour (`LiquidGlassScrollEdge`), the buttons
  /// on glass capsules.
  liquid,

  /// A bar that would be Liquid Glass where the renderer has no shader
  /// filters (every browser), by default: the bar colour at full opacity,
  /// with its hairline, no blur and no capsules, shown at rest too. The
  /// scroll edge needs a graduated blur, which only shader filters draw in
  /// one pass; una's own shader draws it there too, at the cost of a
  /// snapshot of the page every frame, when the theme asks for it (see
  /// `LiquidGlassTheme.webScrollEdge`).
  solid,
}

/// How a bar at the top of the page is drawn in [context], its component
/// theme (or the bar itself) saying [mode].
///
/// Liquid Glass only at the phone and tablet form factors: a desktop's top
/// bar is una's own, as a Mac window's toolbar sits on its own material
/// rather than floating free over the content, unless the bar asks for
/// glass with [LiquidGlassMode.always].
///
/// Where the renderer has no shader filters — every browser — a bar that
/// would be Liquid Glass is solid, unless it asks for the glass outright
/// ([LiquidGlassMode.always]) or the theme's
/// `LiquidGlassTheme.webScrollEdge` is on: then its scroll edge is una's
/// own shader over a snapshot of the page.
AppBarMaterial appBarMaterial(BuildContext context, LiquidGlassMode? mode) {
  if (Theme.of(context).formFactor == FormFactor.desktop &&
      mode != LiquidGlassMode.always) {
    return AppBarMaterial.frosted;
  }
  if (!LiquidGlass.isActive(context, mode)) return AppBarMaterial.frosted;
  if (LiquidGlass.hasShaderFilters) return AppBarMaterial.liquid;
  return mode == LiquidGlassMode.always ||
          Theme.of(context).liquidGlass.webScrollEdge
      ? AppBarMaterial.liquid
      : AppBarMaterial.solid;
}

/// Whether a bar at the top of the page draws with Liquid Glass in
/// [context] (see [appBarMaterial]).
bool appBarUsesLiquidGlass(BuildContext context, LiquidGlassMode? mode) =>
    appBarMaterial(context, mode) == AppBarMaterial.liquid;

/// The space above a primary bar's toolbar in [context]: the status bar,
/// or — where there is none (a browser, a desktop window, a phone frame in
/// a page) — a small margin at the phone and tablet form factors, and for
/// a bar of floating glass at any: a phone's bar is laid out to sit under
/// a status bar, and without one its title and buttons met the top of the
/// window.
double appBarTopInset(BuildContext context, {required bool liquid}) {
  final top = MediaQuery.paddingOf(context).top;
  if (top > 0) return top;
  // A filled bar's toolbar has room around its buttons of its own (see
  // [appBarStyleHeight]); capsules of glass float, and need the margin.
  if (!liquid) return 0;
  return Theme.of(context).layoutTheme.gap(GapSize.sm);
}

/// The constraints a `Scaffold` lays its app bar out with: the screen's
/// width, and how far the scaffold's banner reaches below the bar
/// ([below]). A bar of Liquid Glass reaches its scroll edge down under the
/// banner as well, so the page scrolled under the two is blurred as one.
///
/// Constraints rather than an inherited value: the banner is laid out
/// first, and a new [below] lays the bar out again in the same frame.
@immutable
class ScaffoldBarConstraints extends BoxConstraints {
  /// [constraints] with the banner's height under the bar.
  ScaffoldBarConstraints.from(BoxConstraints constraints, {required this.below})
    : super(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      );

  /// How far below the bar the scaffold's banner reaches.
  final double below;

  /// How far below the bar a bar laid out with [constraints] has
  /// something of the scaffold's under it: 0 outside a scaffold.
  static double belowOf(BoxConstraints constraints) =>
      constraints is ScaffoldBarConstraints ? constraints.below : 0;

  @override
  bool operator ==(Object other) =>
      other is ScaffoldBarConstraints && other.below == below && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, below);
}

/// The style height of a bar's toolbar: [height] when the caller gives
/// one, otherwise the theme's — and for a filled bar at least an icon
/// button with the small gap above and below it.
///
/// A phone's toolbar is 44, the height of iOS's bar, which draws its
/// buttons as bare glyphs; una's buttons show a disc on hover and press,
/// and in a 44-point bar that disc met the bar's edges. Material's bar is
/// 64 around a 40-point state layer. A bar of Liquid Glass keeps iOS's
/// height: its capsules float over the page and the bar has no edge.
double appBarStyleHeight(
  BuildContext context,
  double? height, {
  required bool liquid,
}) {
  if (height != null) return height;
  final theme = Theme.of(context);
  final styled = theme.appBarTheme.height ?? 64;
  if (liquid) return styled;
  return math.max(
    styled,
    theme.style.iconButtonSize + 2 * theme.layoutTheme.gap(GapSize.sm),
  );
}

/// Whether [leading] is a button, which iOS 26 puts on a capsule of glass:
/// a logo or a title at the start of the bar stands on the page bare.
bool _isBarButton(Widget leading) => switch (leading) {
  IconButton() || Button() || BackButton() || CloseButton() => true,
  // A button kept on a layer of its own, as a bar that repaints while it
  // scrolls keeps its buttons, or with a badge or a tooltip.
  RepaintBoundary(:final child?) ||
  IndicatorBadge(:final child?) ||
  Tooltip(:final child) ||
  KeyedSubtree(:final child) => _isBarButton(child),
  _ => false,
};

/// The variant a bar gives the buttons in it that name none (see
/// `BarButtonScope`): ghost on the bar's own surface and on a capsule of
/// Liquid Glass, which is the surface there; an outline — a disc with a
/// hairline — over a picture the bar is drawn on, where a bare glyph would
/// be lost.
ButtonVariant appBarButtonVariant({
  required AppBarMaterial material,
  bool overPicture = false,
}) => overPicture && material != AppBarMaterial.liquid
    ? ButtonVariant.outline
    : ButtonVariant.ghost;

/// Whether [widget], at an end of a bar whose buttons take [barVariant], is
/// an icon button with no surface of its own: its glyph, not its box, then
/// stands on the bar's margin, as a bar's title does. Seen through the
/// wrappers a bar's buttons come in.
bool _isBareIconButton(Widget widget, ButtonVariant barVariant) =>
    switch (widget) {
      IconButton(:final variant) => (variant ?? barVariant) == .ghost,
      BackButton() || CloseButton() => barVariant == .ghost,
      RepaintBoundary(:final child?) ||
      IndicatorBadge(:final child?) ||
      Tooltip(:final child) ||
      KeyedSubtree(:final child) => _isBareIconButton(child, barVariant),
      _ => false,
    };

/// A bar's [leading] and [actions] as iOS 26 puts them on Liquid Glass:
/// the leading button on a capsule of its own and all the actions on one
/// shared capsule, [actionsGap] apart. A leading widget that is not a
/// button (a logo) has no capsule; [leadingIsButton] says it is one
/// anyway, for a button the bar put there itself.
(Widget?, List<Widget>) liquidGlassBarSlots(
  BuildContext context, {
  required Widget? leading,
  required List<Widget> actions,
  double? actionsGap,
  bool leadingIsButton = false,
}) {
  final theme = Theme.of(context);
  return (
    leading == null || !(leadingIsButton || _isBarButton(leading))
        ? leading
        : LiquidGlassBarGroup(children: [leading]),
    actions.isEmpty
        ? actions
        : [
            LiquidGlassBarGroup(
              gap: actionsGap ?? theme.layoutTheme.gapSm ?? 8,
              children: actions,
            ),
          ],
  );
}

/// The button a bar shows at its start when it was given none: a close
/// button on a full-screen dialog, a back button on a page that can be
/// popped, a menu button under a scaffold with a drawer (its own, or one
/// around the navigator it is in) — or nothing.
Widget? impliedLeading(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route is PageRoute && route.fullscreenDialog) return const CloseButton();
  if (route?.impliesAppBarDismissal ?? false) return const BackButton();
  final scaffold = Scaffold.withDrawerOf(context);
  if (scaffold != null) {
    return IconButton.ghost(
      icon: const PhosphorIcon(PhosphorIconsRegular.list),
      semanticLabel: UnaLocalizations.of(context).navigation.openMenu,
      onPressed: scaffold.openDrawer,
    );
  }
  return null;
}

/// [actions], or — when there are none and a scaffold around the bar has
/// an end drawer (see [impliedLeading]) — the button that opens it.
List<Widget> impliedActions(BuildContext context, List<Widget> actions) {
  if (actions.isNotEmpty) return actions;
  final scaffold = Scaffold.withDrawerOf(context, end: true);
  if (scaffold == null) return actions;
  return [
    IconButton.ghost(
      icon: const PhosphorIcon(PhosphorIconsRegular.list),
      semanticLabel: UnaLocalizations.of(context).navigation.openMenu,
      onPressed: scaffold.openEndDrawer,
    ),
  ];
}

/// The least a pulled-out button at an end keeps from the edge of the bar.
const _minEdgeMargin = 4.0;

/// The row of a bar: [leading], [title], [middle] and [actions], in the
/// bar's text and icon styles, inside the bar's margins.
class AppBarToolbar extends StatelessWidget {
  /// Creates the row of a bar.
  const AppBarToolbar({
    required this.height,
    this.leading,
    this.title,
    this.middle,
    this.actions = const [],
    this.centerTitle = false,
    this.buttonVariant = ButtonVariant.ghost,
    this.padding,
    this.maxWidth,
    this.gap,
    this.actionsGap,
    super.key,
  });

  /// The row's height.
  final double height;

  /// The widget at the start.
  final Widget? leading;

  /// The widget after [leading], or in the middle with [centerTitle].
  final Widget? title;

  /// A widget centred in the bar.
  final Widget? middle;

  /// The widgets at the end.
  final List<Widget> actions;

  /// Whether [title] is centred in the bar. A [middle] has the centre
  /// first.
  final bool centerTitle;

  /// The variant of the buttons in the row that name none (see
  /// [appBarButtonVariant]).
  ///
  /// An icon button at either end that has no surface of its own — ghost —
  /// stands with its *glyph*, not its box, on the row's margin, as the
  /// title does: the box is moved out towards the edge by its own inner
  /// inset, as far as the margin allows. A button with a surface (an
  /// outline disc, a capsule of glass) stands with its edge on it.
  final ButtonVariant buttonVariant;

  /// Padding around the row. Defaults to the theme's.
  final EdgeInsetsGeometry? padding;

  /// The widest the row grows. Defaults to the theme's.
  final double? maxWidth;

  /// The gap between the row's parts. Defaults to the theme's.
  final double? gap;

  /// The gap between two [actions]. Defaults to the theme's small gap.
  final double? actionsGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = theme.appBarTheme;
    final effectiveGap = gap ?? bar.gap ?? 24;
    final foreground = bar.foregroundColor ?? theme.colorScheme.foreground;
    // A page's bar is headed by its title. In a navigation bar — one with
    // a [middle] — the title's place holds a search field or a product
    // name, and the bar is chrome, not a heading.
    final heading = title == null || middle != null
        ? title
        // A node of its own: merged into the bar's, it would make a
        // heading of everything else that is read there.
        : Semantics(header: true, container: true, child: title);

    final actionsRow = actions.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: actionsGap ?? theme.layoutTheme.gapSm ?? 8,
            children: actions,
          );

    final Widget content;
    if (middle != null) {
      content = Row(
        spacing: effectiveGap,
        children: [
          Expanded(
            child: Row(
              spacing: effectiveGap - 4,
              children: [
                ?leading,
                if (heading != null) Flexible(child: heading),
              ],
            ),
          ),
          middle!,
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: actionsRow,
            ),
          ),
        ],
      );
    } else if (centerTitle) {
      // Centred in the bar, not in what the buttons leave over, and pushed
      // aside rather than under them when it is too long for that.
      content = NavigationToolbar(
        leading: leading,
        middle: heading,
        trailing: actionsRow,
        middleSpacing: effectiveGap / 2,
      );
    } else {
      content = Row(
        spacing: effectiveGap / 2,
        children: [
          ?leading,
          Expanded(child: heading ?? const SizedBox.shrink()),
          ?actionsRow,
        ],
      );
    }

    final direction = Directionality.of(context);
    var effectivePadding =
        (padding ?? bar.padding ?? const EdgeInsets.symmetric(horizontal: 24))
            .resolve(direction);
    final inset =
        (theme.style.iconButtonSize - theme.style.iconButtonIconSize) / 2;
    double pulled(double margin) {
      // Never right up against the edge.
      final room = margin - _minEdgeMargin;
      return margin - inset.clamp(0.0, room < 0 ? 0.0 : room);
    }

    final ltr = direction == TextDirection.ltr;
    final alignStart =
        leading != null && _isBareIconButton(leading!, buttonVariant);
    final alignEnd =
        actions.isNotEmpty && _isBareIconButton(actions.last, buttonVariant);
    if (alignStart || alignEnd) {
      final left = ltr ? alignStart : alignEnd;
      final right = ltr ? alignEnd : alignStart;
      effectivePadding = effectivePadding.copyWith(
        left: left ? pulled(effectivePadding.left) : null,
        right: right ? pulled(effectivePadding.right) : null,
      );
    }

    return SizedBox(
      height: height,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? bar.maxWidth ?? double.infinity,
          ),
          child: Padding(
            padding: effectivePadding,
            child: DefaultTextStyle.merge(
              style: (bar.titleStyle ?? theme.textTheme.large).copyWith(
                color: foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: BarButtonScope(variant: buttonVariant, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The height of a bar's toolbar at the text scale of [context], for a
/// style height of [height].
///
/// A style height is the height at the platform's own text size: it is a
/// floor, not a size, once the user has scaled the text. The toolbar keeps
/// its height for as long as a line of its title fits, which with the
/// shipped styles is up to a little over twice the text size, and is as
/// tall as that line from there on. At a scale of 1 or less it is exactly
/// [height].
double appBarToolbarHeight(BuildContext context, double height) {
  final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
  if (scaler == TextScaler.noScaling) return height;
  final theme = Theme.of(context);
  final style = theme.appBarTheme.titleStyle ?? theme.textTheme.large;
  final fontSize = style.fontSize ?? 14;
  final line = scaler.scale(fontSize) * (style.height ?? 1.2);
  return math.max(height, line.ceilToDouble());
}

/// The surface of a bar: its fill over the blurred page, and the hairline
/// under it.
///
/// With a [visibility], the whole surface — fill, hairline and blur — is
/// shown by that much, from 0 (a bare bar: only the content) to 1. It
/// follows the animation at paint time: nothing is rebuilt while it runs.
class AppBarSurface extends StatelessWidget {
  /// Creates the surface of a bar around [child].
  const AppBarSurface({
    required this.child,
    required this.color,
    this.borderColor,
    this.blur = 0,
    this.saturation = 1,
    this.padding = EdgeInsets.zero,
    this.visibility,
    this.liquid = false,
    this.edgeBelow = 0,
    super.key,
  });

  /// Whether the bar is Liquid Glass: no fill and no hairline, only the
  /// page under it blurred and faded into the page colour, more the
  /// nearer the screen's edge and reaching a little below the bar (see
  /// `LiquidGlassScrollEdge`), so the bar has no edge of its own.
  final bool liquid;

  /// How far past the bar's own box its scroll edge reaches on Liquid
  /// Glass, before the edge's own fade: a scaffold's banner under the bar.
  final double edgeBelow;

  /// The bar's content.
  final Widget child;

  /// The fill.
  final Color color;

  /// The colour of the hairline under the bar; null for none. The hairline
  /// is added below the content, not laid over it.
  final Color? borderColor;

  /// The sigma of the blur of what is behind the bar.
  final double blur;

  /// How much what is behind the bar is saturated.
  final double saturation;

  /// Padding between the surface's edge and the content: the status bar.
  final EdgeInsets padding;

  /// How much of the surface shows, from 0 to 1. Null is all of it, always.
  final Animation<double>? visibility;

  @override
  Widget build(BuildContext context) {
    final border = borderColor;
    final visibility = this.visibility;
    if (liquid) {
      final theme = Theme.of(context);
      return Stack(
        // The scroll edge reaches below the bar.
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: -edgeBelow,
            child: LiquidGlassScrollEdge(
              color: theme.colorScheme.background,
              visibility: visibility,
            ),
          ),
          Padding(
            // The hairline's point, as the frosted bar reserves it, so the
            // bar is as tall either way.
            padding: padding + EdgeInsets.only(bottom: border == null ? 0 : 1),
            child: child,
          ),
        ],
      );
    }
    if (visibility == null) {
      return Backdrop(
        blur: blur,
        saturation: saturation,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            border: border == null
                ? null
                : Border(bottom: BorderSide(color: border)),
          ),
          child: child,
        ),
      );
    }
    Widget surface = _FadingFill(
      visibility: visibility,
      color: color,
      borderColor: border,
      child: Padding(
        // The hairline's point, as a `Container` would reserve it.
        padding: padding + EdgeInsets.only(bottom: border == null ? 0 : 1),
        child: child,
      ),
    );
    final filter = Backdrop.filterFor(blur: blur, saturation: saturation);
    if (filter != null) {
      surface = ClipRect(
        child: FadingBackdrop(
          visibility: visibility,
          filter: filter,
          child: surface,
        ),
      );
    }
    return surface;
  }
}

/// A fill and a hairline under it, shown by [visibility].
class _FadingFill extends SingleChildRenderObjectWidget {
  const _FadingFill({
    required this.visibility,
    required this.color,
    required this.borderColor,
    required super.child,
  });

  final Animation<double> visibility;
  final Color color;
  final Color? borderColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFadingFill(visibility, color, borderColor);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFadingFill renderObject,
  ) {
    renderObject
      ..visibility = visibility
      ..color = color
      ..borderColor = borderColor;
  }
}

class _RenderFadingFill extends RenderProxyBox {
  _RenderFadingFill(this._visibility, this._color, this._borderColor);

  Animation<double> get visibility => _visibility;
  Animation<double> _visibility;
  set visibility(Animation<double> value) {
    if (identical(value, _visibility)) return;
    if (attached) _visibility.removeListener(markNeedsPaint);
    _visibility = value;
    if (attached) _visibility.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  Color? get borderColor => _borderColor;
  Color? _borderColor;
  set borderColor(Color? value) {
    if (value == _borderColor) return;
    _borderColor = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _visibility.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _visibility.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shown = _visibility.value.clamp(0.0, 1.0);
    if (shown > 0) {
      final rect = offset & size;
      context.canvas.drawRect(
        rect,
        Paint()..color = _color.withValues(alpha: _color.a * shown),
      );
      if (_borderColor case final border?) {
        context.canvas.drawRect(
          Rect.fromLTRB(rect.left, rect.bottom - 1, rect.right, rect.bottom),
          Paint()..color = border.withValues(alpha: border.a * shown),
        );
      }
    }
    super.paint(context, offset);
  }
}

/// A backdrop filter whose result is shown by [visibility].
///
/// Not an opacity around a filter: under an opacity layer a backdrop filter
/// samples that layer, which is empty. The filter's own output is faded.
class FadingBackdrop extends SingleChildRenderObjectWidget {
  /// Creates a backdrop filter shown by [visibility].
  const FadingBackdrop({
    required this.visibility,
    required this.filter,
    required super.child,
    super.key,
  });

  /// How much of the filter's result shows, from 0 to 1.
  final Animation<double> visibility;

  /// The filter at full strength.
  final ImageFilter filter;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFadingBackdrop(visibility, filter);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBackdropFilter renderObject,
  ) {
    (renderObject as _RenderFadingBackdrop)
      ..visibility = visibility
      ..base = filter;
  }
}

// A `RenderBackdropFilter`, so that whatever counts the backdrop filters on
// screen counts this one.
class _RenderFadingBackdrop extends RenderBackdropFilter {
  _RenderFadingBackdrop(this._visibility, this._base)
    : super(
        filter: Backdrop.faded(_base, _visibility.value) ?? _base,
        enabled: _visibility.value > 0,
      );

  Animation<double> get visibility => _visibility;
  Animation<double> _visibility;
  set visibility(Animation<double> value) {
    if (identical(value, _visibility)) return;
    if (attached) _visibility.removeListener(_follow);
    _visibility = value;
    if (attached) _visibility.addListener(_follow);
    _follow();
  }

  ImageFilter get base => _base;
  ImageFilter _base;
  set base(ImageFilter value) {
    if (identical(value, _base)) return;
    _base = value;
    _follow();
  }

  void _follow() {
    final shown = _visibility.value.clamp(0.0, 1.0);
    enabled = shown > 0;
    if (shown > 0) filter = Backdrop.faded(_base, shown)!;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _visibility.addListener(_follow);
    _follow();
  }

  @override
  void detach() {
    _visibility.removeListener(_follow);
    super.detach();
  }
}

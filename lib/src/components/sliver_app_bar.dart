import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/components/app_bar_layout.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/liquid_glass/liquid_glass_theme.dart';
import 'package:una/src/theme/components/app_bar.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/backdrop.dart';
import 'package:una/src/utils/scroll_edge_shader.dart';
import 'package:una/src/utils/spring.dart';
import 'package:una/src/utils/system_overlay_style.dart';

/// An app bar that lives in a scroll view: it can scroll away with the
/// page, come back when the reader turns round, or carry a large title
/// that collapses into the toolbar.
///
/// Use it as the first sliver of the `CustomScrollView` that is a
/// `Scaffold`'s body, and give the scaffold no `appBar`:
///
/// ```dart
/// Scaffold(
///   body: CustomScrollView(
///     slivers: [
///       SliverAppBar.large(title: const Text('Library')),
///       SliverList.builder(itemBuilder: _album),
///     ],
///   ),
/// )
/// ```
///
/// **The plain bar** looks like an `AppBar`. [pinned], the default, keeps it
/// at the top; unpinned it scrolls away with the page, and with [floating]
/// it comes back as soon as the page is scrolled the other way, settling
/// fully in or out when the scrolling stops.
///
/// **[SliverAppBar.large]** sets the title large under the toolbar, at the
/// page margin, as it is on a top-level screen on iOS and Android. As the
/// page scrolls, the large title slides under the toolbar, the same title
/// fades in small, and the bar takes its surface. A `background` — a
/// photograph, a gradient — fills the expanded area, moves at half the
/// page's speed and fades. With bouncing physics the expanded area grows
/// when the page is pulled down, and the title with it a little.
///
/// The bar follows the scroll at paint time: scrolling builds nothing and
/// lays out nothing in it. It is measured, so [bottom] can be any widget.
/// A primary bar covers the status bar itself and styles its icons.
///
/// Vertical, top-to-bottom scroll views only.
class SliverAppBar extends StatefulWidget {
  /// Creates an app bar for a scroll view.
  const SliverAppBar({
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.centerTitle,
    this.middle,
    this.actions = const [],
    this.automaticallyImplyActions = true,
    this.bottom,
    this.pinned = true,
    this.floating = false,
    this.height,
    this.padding,
    this.backgroundColor,
    this.showBorder = true,
    this.surfaceBehavior,
    this.systemOverlayStyle,
    this.maxWidth,
    this.gap,
    this.actionsGap,
    this.primary = true,
    this.liquidGlass,
    super.key,
  }) : _large = false,
       subtitle = null,
       background = null,
       expandedHeight = null,
       stretch = false;

  /// Creates an app bar with a large title that collapses into the toolbar.
  const SliverAppBar.large({
    required Widget this.title,
    this.subtitle,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.actions = const [],
    this.automaticallyImplyActions = true,
    this.bottom,
    this.background,
    this.expandedHeight,
    this.stretch = true,
    this.pinned = true,
    this.height,
    this.padding,
    this.backgroundColor,
    this.showBorder = true,
    this.systemOverlayStyle,
    this.maxWidth,
    this.gap,
    this.actionsGap,
    this.primary = true,
    this.liquidGlass,
    super.key,
  }) : _large = true,
       middle = null,
       floating = false,
       surfaceBehavior = null;

  final bool _large;

  /// The widget at the start of the toolbar. See `AppBar.leading`.
  final Widget? leading;

  /// Whether a bar without a [leading] shows the button its place calls
  /// for: close, back, or the scaffold's menu.
  final bool automaticallyImplyLeading;

  /// The title. In a large bar it is shown twice — large under the toolbar
  /// and small in it — so it should be a plain widget such as a `Text`.
  final Widget? title;

  /// A line under the large title, in the muted style.
  final Widget? subtitle;

  /// Whether the small title is centred in the toolbar. Defaults to the
  /// theme's.
  final bool? centerTitle;

  /// A widget centred in the toolbar. See `AppBar.middle`.
  final Widget? middle;

  /// The widgets at the end of the toolbar.
  final List<Widget> actions;

  /// Whether a bar without [actions] over a scaffold with an end drawer
  /// shows the button that opens it. See `AppBar.automaticallyImplyActions`.
  final bool automaticallyImplyActions;

  /// A row at the bottom of the bar that stays when the bar collapses: a
  /// search field, a `TabBar`, filter chips. Any height.
  final Widget? bottom;

  /// What fills the expanded area of a large bar, behind the title: an
  /// image, a gradient. The titles stand on the page colour, which rises
  /// into the picture just above them, so they read on any picture in
  /// either brightness.
  ///
  /// It goes with the page as the bar collapses, fading out as it goes,
  /// and the collapsed bar is the bar it always is: its surface, or on
  /// Liquid Glass the page blurred under it. A picture kept behind a
  /// collapsed toolbar is never right: veiled it is a grey slab, and left
  /// clear the toolbar has nothing to stand on.
  final Widget? background;

  /// The height of the area under the toolbar of a large bar while it is
  /// fully expanded. Defaults to the theme's, and then to the height of the
  /// title and subtitle with the layout gap above and below.
  final double? expandedHeight;

  /// Whether pulling the page down past its top grows the expanded area of
  /// a large bar. Only scroll physics that overscroll — bouncing ones — do.
  final bool stretch;

  /// Whether the toolbar (and [bottom]) stays at the top of the scroll view
  /// when the page is scrolled.
  final bool pinned;

  /// Whether an unpinned bar comes back as soon as the page is scrolled
  /// towards its start, wherever the page is.
  final bool floating;

  /// The toolbar's height. Defaults to the theme's.
  final double? height;

  /// Padding around the toolbar's content and the large title. Defaults to
  /// the theme's page margin.
  final EdgeInsetsGeometry? padding;

  /// The bar's fill. Defaults to the theme's.
  final Color? backgroundColor;

  /// Whether a hairline is drawn under the bar while it has its surface.
  final bool showBorder;

  /// When the plain bar shows its surface. Defaults to the theme's. A
  /// large bar always takes its surface as it collapses.
  final AppBarSurfaceBehavior? surfaceBehavior;

  /// The style of the system's status bar over this bar. See
  /// `AppBar.systemOverlayStyle`.
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// The widest the bar's content box grows, its horizontal [padding]
  /// included, before it is centred. Defaults to the theme's: the page's
  /// width plus its margins, so the bar lines up with a `PageContainer`.
  /// A screen whose columns are wider sets the bar to match them.
  final double? maxWidth;

  /// The gap between the toolbar's parts.
  final double? gap;

  /// The gap between two [actions].
  final double? actionsGap;

  /// Whether the bar is at the top of the screen and should extend under
  /// the status bar.
  final bool primary;

  /// Whether the bar is Liquid Glass. See `AppBar.liquidGlass`.
  final LiquidGlassMode? liquidGlass;

  @override
  State<SliverAppBar> createState() => _SliverAppBarState();
}

class _SliverAppBarState extends State<SliverAppBar>
    with TickerProviderStateMixin {
  final _scroll = _BarScroll();

  // A bar with no expanded area takes its surface when the page has
  // scrolled at all: in one fade, as an `AppBar` does, rather than at
  // once. A bar that collapses fades its surface with the collapse.
  late final _scrolledUnder = AnimationController(vsync: this);
  bool? _wasScrolled;

  // The settle of a floating bar that the reader left half shown.
  late final _snap = SpringController(vsync: this, tolerance: .05);
  ScrollPosition? _position;

  late final Animation<double> _surface = _ScrollAnimation(
    Listenable.merge([_scroll, _scrolledUnder]),
    () => _scroll.expandedExtent <= 0 ? _scrolledUnder.value : _scroll.surface,
  );
  late final Animation<double> _cover = _ScrollAnimation(
    _scroll,
    () => _scroll.cover,
  );
  late final Animation<double> _smallTitle = _ScrollAnimation(
    _scroll,
    () => _scroll.smallTitle,
  );

  @override
  void initState() {
    super.initState();
    _snap.animation.addListener(_onSnapTick);
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled = _scroll.scrolled;
    if (scrolled == _wasScrolled) return;
    final first = _wasScrolled == null;
    _wasScrolled = scrolled;
    // As it is laid out the first time: nothing to fade from.
    if (first) {
      _scrolledUnder.value = scrolled ? 1 : 0;
      return;
    }
    final motion = Motion.of(context);
    _scrolledUnder.animateTo(
      scrolled ? 1 : 0,
      duration: motion.fast,
      curve: motion.standard,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _position)) return;
    _position?.isScrollingNotifier.removeListener(_onScrollingChanged);
    _position = position;
    position?.isScrollingNotifier.addListener(_onScrollingChanged);
  }

  bool get _floats => widget.floating && !widget.pinned;

  void _onScrollingChanged() {
    final position = _position;
    if (position == null) return;
    if (widget._large && widget.pinned) {
      _settleLarge(position);
      return;
    }
    if (!_floats) return;
    if (position.isScrollingNotifier.value) {
      // The reader has it again.
      _snap.stop();
      return;
    }
    final hidden = _scroll.hidden;
    final full = _scroll.fullExtent;
    if (hidden <= 0 || hidden >= full) return;
    // Half shown: all the way in if most of it is, or if the page is too
    // near its top for the bar to be out; otherwise out.
    final show = hidden < full / 2 || position.pixels < full;
    final motion = Motion.of(context);
    _snap
      ..jumpTo(hidden)
      ..animateTo(show ? 0 : full, spring: motion.snappy);
  }

  /// A large bar does not rest half collapsed, with its subtitle peeking
  /// out between the toolbar and the page, as iOS's does not: when the page
  /// stops it goes the rest of the way, collapsed if most of it is and the
  /// page is long enough to let it, expanded otherwise.
  void _settleLarge(ScrollPosition position) {
    if (position.isScrollingNotifier.value) return;
    final collapse = _scroll.collapse;
    final expanded = _scroll.expandedExtent;
    if (expanded <= 0 || collapse <= 0 || collapse >= expanded) return;
    final rest = expanded - collapse;
    final canCollapse = position.maxScrollExtent >= position.pixels + rest;
    final target = collapse > expanded / 2 && canCollapse
        ? position.pixels + rest
        : position.pixels - collapse;
    final motion = Motion.of(context);
    if (motion.normal == Duration.zero) {
      position.jumpTo(target);
    } else {
      position.animateTo(
        target,
        duration: motion.normal,
        curve: motion.standard,
      );
    }
  }

  void _onSnapTick() {
    if (!_snap.isAnimating && _snap.value == _scroll.hidden) return;
    _scroll.requestHidden(_snap.value);
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_onScrollingChanged);
    _snap.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrolledUnder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = theme.appBarTheme;
    final scheme = theme.colorScheme;
    final motion = Motion.of(context);
    final large = widget._large;
    final direction = Directionality.of(context);
    final material = appBarMaterial(
      context,
      widget.liquidGlass ?? bar.liquidGlass,
    );
    final liquid = material == AppBarMaterial.liquid;
    // Liquid Glass without shader filters: the bar colour, opaque.
    final solid = material == AppBarMaterial.solid;
    final barFill =
        widget.backgroundColor ?? bar.backgroundColor ?? scheme.card;
    final fill = solid ? barFill.withValues(alpha: 1) : barFill;
    final topInset = widget.primary
        ? appBarTopInset(context, liquid: liquid)
        : 0.0;
    // On Liquid Glass the scroll edge shows once content is under the bar,
    // as on iOS: at the top it would only blur the page's own first lines.
    // A solid bar is there at rest too, unless it is large.
    // A small bar on glass with a row under its toolbar keeps its edge at
    // rest, as an `AppBar` does: the row would have nothing to stand on.
    final behavior = liquid && !large && widget.bottom != null
        ? AppBarSurfaceBehavior.always
        : large || liquid
        ? AppBarSurfaceBehavior.whenScrolled
        : solid
        ? AppBarSurfaceBehavior.always
        : widget.surfaceBehavior ??
              bar.surfaceBehavior ??
              AppBarSurfaceBehavior.always;
    final always = behavior == AppBarSurfaceBehavior.always;
    final title = widget.title;

    final implied = widget.leading == null && widget.automaticallyImplyLeading
        ? impliedLeading(context)
        : null;
    var leading = widget.leading ?? implied;
    var actions = widget.automaticallyImplyActions
        ? impliedActions(context, widget.actions)
        : widget.actions;
    if (liquid) {
      (leading, actions) = liquidGlassBarSlots(
        context,
        leading: leading,
        actions: actions,
        actionsGap: widget.actionsGap,
        leadingIsButton: implied != null,
      );
    }
    // A solid bar over a picture keeps its fill at rest, with the picture
    // below it, rather than floating its buttons on the picture: in a
    // browser there is no status bar for them to hang under.
    final filledOverPicture = solid && large && widget.background != null;
    Widget toolbar = Padding(
      padding: EdgeInsets.only(top: topInset),
      child: AppBarToolbar(
        // A floor, as in an `AppBar`: a line of scaled text that needs more
        // room gets it.
        height: appBarToolbarHeight(
          context,
          appBarStyleHeight(context, widget.height, liquid: liquid),
        ),
        leading: leading,
        // Over a picture a bare glyph would be lost: the buttons are
        // discs, there and once the bar has collapsed over the picture.
        buttonVariant: appBarButtonVariant(
          material: material,
          overPicture: widget.background != null && !filledOverPicture,
        ),
        // In a large bar the small title is there for assistive technology
        // all along, and for the eye once the large one has gone under.
        title: large && title != null
            ? FadeTransition(
                opacity: _smallTitle,
                alwaysIncludeSemantics: true,
                child: title,
              )
            : title,
        middle: widget.middle,
        actions: actions,
        centerTitle: widget.centerTitle ?? bar.centerTitle ?? false,
        padding: widget.padding,
        maxWidth: widget.maxWidth,
        gap: widget.gap,
        actionsGap: widget.actionsGap,
      ),
    );

    if (filledOverPicture) toolbar = ColoredBox(color: fill, child: toolbar);

    Widget? expanded;
    Widget? background;
    var titleInset = 0.0;
    if (large) {
      final margin =
          (widget.padding ??
                  bar.padding ??
                  const EdgeInsets.symmetric(horizontal: 24))
              .resolve(direction);
      final gap = theme.layoutTheme.gapMd ?? 12;
      titleInset = direction == TextDirection.ltr ? margin.left : margin.right;
      final height = widget.expandedHeight ?? bar.expandedHeight;
      // Marked, so the bar knows where the titles are: the bar's surface
      // and its small title come in as the large one goes under the
      // toolbar.
      final titles = _TitleMark(
        part: _TitlePart.block,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The title is read once, from the toolbar, where it always is.
            _TitleMark(
              part: _TitlePart.line,
              child: ExcludeSemantics(
                child: DefaultTextStyle.merge(
                  style: bar.largeTitleStyle ?? theme.textTheme.h3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: title!,
                ),
              ),
            ),
            if (widget.subtitle case final subtitle?)
              Padding(
                padding: EdgeInsets.only(top: theme.layoutTheme.gapXs ?? 4),
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.muted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: subtitle,
                ),
              ),
          ],
        ),
      );
      final page = scheme.background;
      Widget block = Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth ?? bar.maxWidth ?? double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(margin.left, gap, margin.right, gap),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              heightFactor: 1,
              child: titles,
            ),
          ),
        ),
      );
      if (widget.background != null) {
        // The titles stand on the page colour, which rises into the
        // picture above them: measured from the titles, not from the bar,
        // so a long name or a second line of headline is never set on the
        // picture itself, in either brightness.
        block = _TitleScrim(color: page, fade: gap * 4, child: block);
      }
      // As tall as it is asked to be, with the titles at its bottom start
      // corner, inside the page's margins.
      expanded = ConstrainedBox(
        constraints: BoxConstraints(minHeight: height ?? 0),
        child: Align(alignment: Alignment.bottomCenter, child: block),
      );
      if (widget.background case final picture?) {
        background = filledOverPicture
            ? picture
            : Stack(
                fit: StackFit.expand,
                children: [
                  picture,
                  // The page colour comes down behind the toolbar's buttons, so
                  // they read on any picture; the titles bring their own.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          page.withValues(alpha: .6),
                          page.withValues(alpha: 0),
                        ],
                        stops: const [0, .3],
                      ),
                    ),
                  ),
                ],
              );
      }
    }

    final filter = solid
        ? null
        : Backdrop.filterFor(
            blur: bar.blur ?? 0,
            saturation: bar.saturation ?? 1,
          );
    // On Liquid Glass the bar has no fill and no hairline: the page
    // scrolled under it is blurred and faded into the page colour.
    final hairline = widget.showBorder && !liquid;
    Widget body = _SliverBarFill(
      scroll: _scroll,
      visibility: always ? null : _surface,
      color: liquid ? const Color(0x00000000) : fill,
      borderColor: hairline ? bar.borderColor ?? scheme.border : null,
      child: _SliverBarBody(
        scroll: _scroll,
        hairline: widget.showBorder ? 1 : 0,
        reduceMotion: motion.reduced,
        titleInset: titleInset,
        backgroundBelowToolbar: filledOverPicture,
        // On Liquid Glass the scroll edge covers the titles instead.
        cover: liquid ? null : fill,
        children: [
          // On Liquid Glass: the page under the collapsed bar, blurred and
          // faded into the page colour, reaching [_edgeOverhang] below it.
          // As tall as the collapsed bar, not the whole box: stretched
          // over that, only its top showed once the bar had collapsed,
          // cut off on a line where the blur was still strong.
          if (liquid)
            _BarPart(
              slot: _BarSlot.edge,
              child: LiquidGlassScrollEdge(
                color: scheme.background,
                // Over a large title, as it goes under the toolbar.
                visibility: always ? null : (large ? _cover : _surface),
              ),
            ),
          if (background != null)
            _BarPart(slot: _BarSlot.background, child: background),
          if (expanded != null)
            _BarPart(slot: _BarSlot.expanded, child: expanded),
          _BarPart(slot: _BarSlot.toolbar, child: toolbar),
          if (widget.bottom case final bottom?)
            _BarPart(slot: _BarSlot.bottom, child: bottom),
        ],
      ),
    );
    if (!liquid && filter != null) {
      body = always
          ? BackdropFilter(filter: filter, child: body)
          : FadingBackdrop(visibility: _surface, filter: filter, child: body);
    }
    // The bar's box is always its full, expanded size; what shows of it is
    // cut at paint time.
    body = ClipRect(
      clipper: _BarClipper(_scroll, overhang: liquid ? _edgeOverhang : 0),
      child: body,
    );

    if (widget.primary) {
      body = AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            widget.systemOverlayStyle ??
            systemOverlayStyleFor(
              // Bare at first, a large bar stands on the page.
              large
                  ? theme.brightness
                  : surfaceBrightness(fill, scheme.background),
            ),
        child: body,
      );
    }

    return _SliverBar(
      scroll: _scroll,
      pinned: widget.pinned,
      floating: _floats,
      stretch: widget.stretch && !motion.reduced,
      // A layer of its own: the viewport paints its slivers again on every
      // scroll frame, and without one the bar went with them, collapsed and
      // still or not. Its pieces repaint themselves when the bar moves.
      child: RepaintBoundary(
        // A scroll edge drawn by una's shader takes its picture of the page
        // this bar is in: the bar itself, its buttons and title, stay out.
        child: ScrollEdgeExclusion(
          active: liquid && !LiquidGlass.hasShaderFilters,
          child: Semantics(container: true, child: body),
        ),
      ),
    );
  }
}

/// Where a bar is in its travel, written by its sliver at layout and read
/// by the bar's pieces at paint.
class _BarScroll extends ChangeNotifier {
  /// How much of the expanded area has gone under the toolbar.
  double collapse = 0;

  /// How far the page is pulled down past its top.
  double stretch = 0;

  /// How far the whole bar has moved up off the top (unpinned bars).
  double away = 0;

  /// How much of a floating bar is out of sight.
  double hidden = 0;

  /// Whether the page has scrolled at all.
  bool scrolled = false;

  /// The heights the bar measured: its expanded area, everything that
  /// stays when that is gone, and both together.
  double expandedExtent = 0;
  double pinnedExtent = 0;

  /// Whether the heights changed since the pieces were last told: what
  /// they paint depends on them as much as on the scroll.
  bool _measured = false;

  /// Where a large bar's title line starts and how tall it is, and where
  /// its titles (title and subtitle) end, in the expanded area; zero
  /// without them.
  double titleTop = 0;
  double titleLine = 0;
  double titlesBottom = 0;

  /// How much of the bar's top its body covers with the bar's surface
  /// itself, over the titles going under it: the fill leaves that much
  /// out, or it would be laid on twice.
  double coverTop = 0;

  /// Records what the bar's layout measured.
  void measure({
    required double expanded,
    required double pinned,
    double titleTop = 0,
    double titleLine = 0,
    double titlesBottom = 0,
    double coverTop = 0,
  }) {
    if (expanded == expandedExtent &&
        pinned == pinnedExtent &&
        titleTop == this.titleTop &&
        titleLine == this.titleLine &&
        titlesBottom == this.titlesBottom &&
        coverTop == this.coverTop) {
      return;
    }
    expandedExtent = expanded;
    pinnedExtent = pinned;
    this.titleTop = titleTop;
    this.titleLine = titleLine;
    this.titlesBottom = titlesBottom;
    this.coverTop = coverTop;
    _measured = true;
  }

  /// From 0 to 1 as [collapse] goes from [from] to [to], which is never
  /// past the end of the collapse.
  double _ramp(double from, double to) {
    final end = math.min(to, expandedExtent);
    final start = math.min(from, end);
    if (end <= start) return collapse >= end ? 1 : 0;
    return ((collapse - start) / (end - start)).clamp(0.0, 1.0);
  }

  bool get _titled => titleLine > 0;

  double get fullExtent => expandedExtent + pinnedExtent;

  /// The height of the bar that shows.
  double get visibleExtent => fullExtent - collapse + stretch;

  /// A floating bar's settle asks for this much to be hidden.
  double? requestedHidden;

  /// The distance over which the surface and the small title come in, at
  /// the end of the collapse.
  static const _fade = 28.0;

  /// How much of the bar's surface shows: once the page is under it.
  double get surface {
    if (expandedExtent <= 0) return scrolled ? 1 : 0;
    return ((collapse - (expandedExtent - _fade)) / _fade).clamp(0.0, 1.0);
  }

  /// How much of the bar's surface shows over the toolbar of a large bar.
  /// It comes in as the large title goes under the toolbar, so the title
  /// goes under the bar rather than being cut off at the toolbar's edge.
  double get cover {
    if (expandedExtent > 0 && _titled) {
      return _ramp(titleTop, titleTop + titleLine);
    }
    return surface;
  }

  /// How much of the small title shows: it comes in once the large one is
  /// half under the bar.
  double get smallTitle {
    if (expandedExtent <= 0) return 1;
    if (_titled) {
      return _ramp(titleTop + titleLine * .5, titleTop + titleLine * 1.5);
    }
    return surface;
  }

  /// How much of the large titles shows: they thin out as they go under
  /// the toolbar, and are gone once the last line is under it.
  double get titles {
    if (_titled) return 1 - _ramp(titleTop, titlesBottom);
    return (1 - (progress - .35) / .5).clamp(0.0, 1.0);
  }

  /// How far collapsed the expanded area is, from 0 to 1.
  double get progress =>
      expandedExtent <= 0 ? 1 : (collapse / expandedExtent).clamp(0.0, 1.0);

  void update({
    required double collapse,
    required double stretch,
    required double away,
    required double hidden,
    required bool scrolled,
  }) {
    if (!_measured &&
        collapse == this.collapse &&
        stretch == this.stretch &&
        away == this.away &&
        hidden == this.hidden &&
        scrolled == this.scrolled) {
      return;
    }
    _measured = false;
    this.collapse = collapse;
    this.stretch = stretch;
    this.away = away;
    this.hidden = hidden;
    this.scrolled = scrolled;
    notifyListeners();
  }

  VoidCallback? onRequest;

  void requestHidden(double value) {
    requestedHidden = value;
    onRequest?.call();
  }
}

/// One number of a [_BarScroll], as an animation to hand to a transition.
class _ScrollAnimation extends Animation<double> {
  _ScrollAnimation(this._scroll, this._read);

  final Listenable _scroll;
  final double Function() _read;

  @override
  double get value => _read();

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void addListener(VoidCallback listener) => _scroll.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _scroll.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}
}

/// Cuts the bar to the part of it that shows.
class _BarClipper extends CustomClipper<Rect> {
  _BarClipper(this.scroll, {this.overhang = 0}) : super(reclip: scroll);

  final _BarScroll scroll;

  /// How far below the bar its scroll edge reaches.
  final double overhang;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    0,
    size.width,
    math.max(scroll.visibleExtent, 0) + overhang,
  );

  @override
  Rect getApproximateClipRect(Size size) => Offset.zero & size;

  @override
  bool shouldReclip(_BarClipper oldClipper) =>
      !identical(oldClipper.scroll, scroll) || oldClipper.overhang != overhang;
}

/// The sliver: one box, always laid out at the bar's full height.
class _SliverBar extends SingleChildRenderObjectWidget {
  const _SliverBar({
    required this.scroll,
    required this.pinned,
    required this.floating,
    required this.stretch,
    required super.child,
  });

  final _BarScroll scroll;
  final bool pinned;
  final bool floating;
  final bool stretch;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSliverBar(
    scroll: scroll,
    pinned: pinned,
    floating: floating,
    stretch: stretch,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderSliverBar renderObject) {
    renderObject
      ..pinned = pinned
      ..floating = floating
      ..stretch = stretch;
  }
}

class _RenderSliverBar extends RenderSliverSingleBoxAdapter {
  _RenderSliverBar({
    required this.scroll,
    required bool pinned,
    required bool floating,
    required bool stretch,
  }) : _pinned = pinned,
       _floating = floating,
       _stretch = stretch;

  final _BarScroll scroll;

  bool get pinned => _pinned;
  bool _pinned;
  set pinned(bool value) {
    if (value == _pinned) return;
    _pinned = value;
    markNeedsLayout();
  }

  bool get floating => _floating;
  bool _floating;
  set floating(bool value) {
    if (value == _floating) return;
    _floating = value;
    _lastScrollOffset = null;
    markNeedsLayout();
  }

  bool get stretch => _stretch;
  bool _stretch;
  set stretch(bool value) {
    if (value == _stretch) return;
    _stretch = value;
    markNeedsLayout();
  }

  // A floating bar: how much of it is out of sight, and the scroll offset
  // that was measured against.
  double _hidden = 0;
  double? _lastScrollOffset;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    scroll.onRequest = markNeedsLayout;
  }

  @override
  void detach() {
    scroll.onRequest = null;
    super.detach();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    assert(
      constraints.axisDirection == AxisDirection.down,
      'A SliverAppBar goes at the top of a vertical scroll view that is not '
      'reversed.',
    );
    child.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final full = child.size.height;
    final expanded = math.min(scroll.expandedExtent, full);
    final offset = constraints.scrollOffset;

    // How far the bar has moved from fully shown.
    final double shift;
    if (pinned) {
      shift = math.min(offset, expanded);
    } else if (floating) {
      final last = _lastScrollOffset;
      final requested = scroll.requestedHidden;
      scroll.requestedHidden = null;
      if (requested != null) {
        _hidden = requested;
      } else if (last != null) {
        // It goes out as the page goes on and comes back as soon as the
        // page turns round.
        _hidden += offset - last;
      } else {
        _hidden = offset;
      }
      // Never more hidden than the page has scrolled: at the top of the
      // page the bar is in its place.
      _hidden = _hidden.clamp(0.0, math.min(full, offset));
      _lastScrollOffset = offset;
      shift = _hidden;
    } else {
      shift = math.min(offset, full);
    }
    final collapse = math.min(shift, expanded);
    final away = shift - collapse;
    final pulled = stretch && constraints.overlap < 0 && expanded > 0
        ? -constraints.overlap
        : 0.0;

    final visible = full - shift + pulled;
    geometry = SliverGeometry(
      scrollExtent: full,
      paintOrigin: pulled > 0 ? constraints.overlap : 0,
      paintExtent: visible.clamp(0.0, constraints.remainingPaintExtent),
      layoutExtent: (full - offset).clamp(
        0.0,
        constraints.remainingPaintExtent,
      ),
      maxPaintExtent: full + pulled,
      maxScrollObstructionExtent: pinned ? full - expanded : 0,
      hasVisualOverflow: true,
    );
    (child.parentData! as SliverPhysicalParentData).paintOffset = Offset(
      0,
      -away,
    );
    _away = away;
    scroll.update(
      collapse: collapse,
      stretch: pulled,
      away: away,
      hidden: floating ? _hidden : 0,
      scrolled: offset > 0,
    );
  }

  double _away = 0;

  @override
  double childMainAxisPosition(RenderBox child) => -_away;
}

/// The bar's fill and hairline, drawn over the part of the bar that shows.
class _SliverBarFill extends SingleChildRenderObjectWidget {
  const _SliverBarFill({
    required this.scroll,
    required this.visibility,
    required this.color,
    required this.borderColor,
    required super.child,
  });

  final _BarScroll scroll;
  final Animation<double>? visibility;
  final Color color;
  final Color? borderColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSliverBarFill(scroll, visibility, color, borderColor);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSliverBarFill renderObject,
  ) {
    renderObject
      ..visibility = visibility
      ..color = color
      ..borderColor = borderColor;
  }
}

class _RenderSliverBarFill extends RenderProxyBox {
  _RenderSliverBarFill(
    this.scroll,
    this._visibility,
    this._color,
    this._borderColor,
  );

  final _BarScroll scroll;

  Animation<double>? get visibility => _visibility;
  Animation<double>? _visibility;
  set visibility(Animation<double>? value) {
    if (identical(value, _visibility)) return;
    _visibility = value;
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
    scroll.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    scroll.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shown = (_visibility?.value ?? 1).clamp(0.0, 1.0);
    final height = math.max<double>(scroll.visibleExtent, 0);
    final rect = Rect.fromLTWH(offset.dx, offset.dy, size.width, height);
    if (shown > 0) {
      // The top the body covers itself, over the titles under it.
      final top = math.min(scroll.coverTop, height);
      context.canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.top + top, rect.right, rect.bottom),
        Paint()..color = _color.withValues(alpha: _color.a * shown),
      );
    }
    super.paint(context, offset);
    if (shown > 0) {
      if (_borderColor case final border?) {
        context.canvas.drawRect(
          Rect.fromLTRB(rect.left, rect.bottom - 1, rect.right, rect.bottom),
          Paint()..color = border.withValues(alpha: border.a * shown),
        );
      }
    }
  }
}

/// Marks a large bar's titles as standing on the page colour [color],
/// which rises [fade] above them into the picture.
///
/// It paints nothing itself: the bar paints the scrim with the picture —
/// in the picture's clip and opacity, but where the titles are — so it is
/// not cut off at the toolbar with the titles, and as the titles go under
/// the toolbar the page covers the picture behind it instead of ending on
/// a line.
class _TitleScrim extends SingleChildRenderObjectWidget {
  const _TitleScrim({
    required this.color,
    required this.fade,
    required super.child,
  });

  final Color color;
  final double fade;

  @override
  _RenderTitleScrim createRenderObject(BuildContext context) =>
      _RenderTitleScrim(color, fade);

  @override
  void updateRenderObject(BuildContext context, _RenderTitleScrim scrim) {
    scrim
      ..color = color
      ..fade = fade;
  }
}

class _RenderTitleScrim extends RenderProxyBox {
  _RenderTitleScrim(this._color, this._fade);

  // The bar paints from these, in the same paint pass: no repaint
  // boundary lies between the two.
  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  double get fade => _fade;
  double _fade;
  set fade(double value) {
    if (value == _fade) return;
    _fade = value;
    markNeedsPaint();
  }

  /// Paints the scrim on [canvas], in the coordinates of [ancestor].
  void paintScrim(Canvas canvas, RenderObject ancestor, {double opacity = 1}) {
    final box = MatrixUtils.transformRect(
      getTransformTo(ancestor),
      Offset.zero & size,
    );
    final color = _color.withValues(alpha: _color.a * opacity);
    canvas.drawRect(box, Paint()..color = color);
    if (_fade <= 0) return;
    final rise = Rect.fromLTRB(box.left, box.top - _fade, box.right, box.top);
    Color at(double t) => color.withValues(alpha: color.a * t);
    canvas.drawRect(
      rise,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Eased, so the picture has no edge where it ends.
          colors: [at(0), at(.25), at(.7), at(1)],
          stops: const [0, .35, .7, 1],
        ).createShader(rise),
    );
  }
}

/// The [_RenderTitleScrim] in [part], a few single-child boxes down.
_RenderTitleScrim? _scrimIn(RenderObject part) {
  _RenderTitleScrim? found;
  void visit(RenderObject child) {
    if (found != null) return;
    if (child is _RenderTitleScrim) {
      found = child;
    } else {
      child.visitChildren(visit);
    }
  }

  part.visitChildren(visit);
  return found;
}

/// Which part of a large bar's titles a [_TitleMark] marks.
enum _TitlePart { line, block }

/// Marks where a large bar's title line ([_TitlePart.line]) or its titles
/// ([_TitlePart.block]) are, for the bar to measure. It paints nothing.
class _TitleMark extends SingleChildRenderObjectWidget {
  const _TitleMark({required this.part, required super.child});

  final _TitlePart part;

  @override
  _RenderTitleMark createRenderObject(BuildContext context) =>
      _RenderTitleMark(part);

  @override
  void updateRenderObject(BuildContext context, _RenderTitleMark mark) {
    mark.part = part;
  }
}

class _RenderTitleMark extends RenderProxyBox {
  _RenderTitleMark(this.part);

  _TitlePart part;

  /// Its size, kept for the bar, which may not read a descendant's.
  Size laidOutSize = Size.zero;

  @override
  void performLayout() {
    super.performLayout();
    laidOutSize = size;
  }
}

/// The [_RenderTitleMark] of [part] in [root], a few boxes down.
_RenderTitleMark? _markIn(RenderObject root, _TitlePart part) {
  _RenderTitleMark? found;
  void visit(RenderObject child) {
    if (found != null) return;
    if (child is _RenderTitleMark && child.part == part) {
      found = child;
    } else {
      child.visitChildren(visit);
    }
  }

  root.visitChildren(visit);
  return found;
}

/// How far a bar's scroll edge reaches below it on Liquid Glass.
const _edgeOverhang = 24.0;

enum _BarSlot { edge, background, expanded, toolbar, bottom }

class _BarPartData extends ContainerBoxParentData<RenderBox> {
  _BarSlot? slot;
}

class _BarPart extends ParentDataWidget<_BarPartData> {
  const _BarPart({required this.slot, required super.child});

  final _BarSlot slot;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _BarPartData;
    if (data.slot == slot) return;
    data.slot = slot;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _SliverBarBody;
}

/// The bar's parts, laid out once at their expanded places and painted
/// wherever the scroll has them.
class _SliverBarBody extends MultiChildRenderObjectWidget {
  const _SliverBarBody({
    required this.scroll,
    required this.hairline,
    required this.reduceMotion,
    required this.titleInset,
    required this.backgroundBelowToolbar,
    required this.cover,
    required super.children,
  });

  final _BarScroll scroll;
  final double hairline;
  final bool reduceMotion;
  final double titleInset;
  final bool backgroundBelowToolbar;
  final Color? cover;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSliverBarBody(
    scroll: scroll,
    hairline: hairline,
    reduceMotion: reduceMotion,
    textDirection: Directionality.of(context),
    titleInset: titleInset,
    backgroundBelowToolbar: backgroundBelowToolbar,
    cover: cover,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSliverBarBody renderObject,
  ) {
    renderObject
      ..hairline = hairline
      ..reduceMotion = reduceMotion
      ..textDirection = Directionality.of(context)
      ..titleInset = titleInset
      ..backgroundBelowToolbar = backgroundBelowToolbar
      ..cover = cover;
  }
}

class _RenderSliverBarBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BarPartData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BarPartData> {
  _RenderSliverBarBody({
    required this.scroll,
    required double hairline,
    required bool reduceMotion,
    required TextDirection textDirection,
    required double titleInset,
    required bool backgroundBelowToolbar,
    required Color? cover,
  }) : _cover = cover,
       _hairline = hairline,
       _reduceMotion = reduceMotion,
       _textDirection = textDirection,
       _titleInset = titleInset,
       _backgroundBelowToolbar = backgroundBelowToolbar;

  /// The bar's surface, laid over the toolbar's part of the titles as they
  /// go under it; null where something else covers them (the scroll edge
  /// on Liquid Glass).
  Color? get cover => _cover;
  Color? _cover;
  set cover(Color? value) {
    if (value == _cover) return;
    _cover = value;
    markNeedsLayout();
  }

  /// Whether the picture starts below the toolbar, which has a fill of
  /// its own, instead of reaching up behind it.
  bool get backgroundBelowToolbar => _backgroundBelowToolbar;
  bool _backgroundBelowToolbar;
  set backgroundBelowToolbar(bool value) {
    if (value == _backgroundBelowToolbar) return;
    _backgroundBelowToolbar = value;
    markNeedsLayout();
  }

  /// The top of the picture's box: under the toolbar or behind it.
  double get _backgroundTop => _backgroundBelowToolbar ? _toolbarHeight : 0;

  final _BarScroll scroll;

  double get hairline => _hairline;
  double _hairline;
  set hairline(double value) {
    if (value == _hairline) return;
    _hairline = value;
    markNeedsLayout();
  }

  bool get reduceMotion => _reduceMotion;
  bool _reduceMotion;
  set reduceMotion(bool value) {
    if (value == _reduceMotion) return;
    _reduceMotion = value;
    markNeedsPaint();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
  }

  /// How far the large title's start is from the bar's start edge.
  double get titleInset => _titleInset;
  double _titleInset;
  set titleInset(double value) {
    if (value == _titleInset) return;
    _titleInset = value;
    markNeedsPaint();
  }

  /// How fast the background moves, as a share of the page's speed.
  static const _parallax = .5;

  /// How much the large title grows when the page is pulled down, at most,
  /// and the pull that takes it there.
  static const _titleGrowth = .1;
  static const _titleGrowthPull = 240.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BarPartData) child.parentData = _BarPartData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    scroll.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    scroll.removeListener(markNeedsPaint);
    super.detach();
  }

  RenderBox? _part(_BarSlot slot) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _BarPartData;
      if (data.slot == slot) return child;
      child = data.nextSibling;
    }
    return null;
  }

  double _toolbarHeight = 0;
  double _expandedHeight = 0;

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final loose = BoxConstraints(minWidth: width, maxWidth: width);
    double layout(_BarSlot slot) {
      final part = _part(slot);
      if (part == null) return 0;
      part.layout(loose, parentUsesSize: true);
      return part.size.height;
    }

    final toolbar = _toolbarHeight = layout(_BarSlot.toolbar);
    final expanded = _expandedHeight = layout(_BarSlot.expanded);
    final bottom = layout(_BarSlot.bottom);
    // The picture is behind the toolbar as well as the title, unless the
    // toolbar is filled.
    _part(_BarSlot.background)?.layout(
      BoxConstraints.tightFor(
        width: width,
        height: toolbar + expanded - _backgroundTop,
      ),
    );
    (_part(_BarSlot.toolbar)?.parentData as _BarPartData?)?.offset =
        Offset.zero;
    (_part(_BarSlot.expanded)?.parentData as _BarPartData?)?.offset = Offset(
      0,
      toolbar,
    );
    (_part(_BarSlot.bottom)?.parentData as _BarPartData?)?.offset = Offset(
      0,
      toolbar + expanded,
    );
    (_part(_BarSlot.background)?.parentData as _BarPartData?)?.offset =
        Offset.zero;
    // The scroll edge is as tall as the collapsed bar: it shows only once
    // content is under it, which is once the bar has collapsed.
    _part(_BarSlot.edge)?.layout(
      BoxConstraints.tightFor(width: width, height: toolbar + bottom),
    );
    (_part(_BarSlot.edge)?.parentData as _BarPartData?)?.offset = Offset.zero;
    // Where the titles are in the expanded area, unscaled.
    var titleTop = 0.0;
    var titleLine = 0.0;
    var titlesBottom = 0.0;
    if (_part(_BarSlot.expanded) case final part?) {
      final line = _markIn(part, _TitlePart.line);
      final block = _markIn(part, _TitlePart.block);
      if (line != null && block != null) {
        final lineRect = MatrixUtils.transformRect(
          line.getTransformTo(part),
          Offset.zero & line.laidOutSize,
        );
        final blockRect = MatrixUtils.transformRect(
          block.getTransformTo(part),
          Offset.zero & block.laidOutSize,
        );
        titleTop = lineRect.top;
        titleLine = lineRect.height;
        titlesBottom = blockRect.bottom;
      }
    }
    scroll.measure(
      expanded: expanded,
      pinned: toolbar + bottom + hairline,
      titleTop: titleTop,
      titleLine: titleLine,
      titlesBottom: titlesBottom,
      coverTop: expanded > 0 && _cover != null ? toolbar : 0,
    );
    size = constraints.constrain(
      Size(width, toolbar + expanded + bottom + hairline),
    );
  }

  /// How far the parts under the toolbar are from their expanded places.
  double get _lift => scroll.stretch - scroll.collapse;

  double get _titleScale => reduceMotion
      ? 1
      : 1 + _titleGrowth * (scroll.stretch / _titleGrowthPull).clamp(0.0, 1.0);

  /// Where the expanded area is painted: lifted with the scroll and, pulled
  /// down, grown from the start of its last line — the corner the title
  /// hangs from.
  Matrix4 _expandedTransform(RenderBox expanded) {
    final transform = Matrix4.translationValues(0, _toolbarHeight + _lift, 0);
    final scale = _titleScale;
    if (scale == 1) return transform;
    final anchor = Offset(
      textDirection == TextDirection.ltr ? titleInset : size.width - titleInset,
      expanded.size.height,
    );
    return transform
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);
  }

  /// Where the picture is painted: lagging behind the page as it scrolls,
  /// and grown from the top to cover when the page is pulled down.
  Matrix4 _backgroundTransform() {
    final top = _backgroundTop;
    if (reduceMotion) return Matrix4.translationValues(0, top, 0);
    if (scroll.stretch <= 0) {
      return Matrix4.translationValues(
        0,
        top - scroll.collapse * _parallax,
        0,
      );
    }
    final full = _toolbarHeight + _expandedHeight - top;
    final scale = full <= 0 ? 1.0 : (full + scroll.stretch) / full;
    return Matrix4.identity()
      ..translateByDouble(size.width / 2, top, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-size.width / 2, 0, 0, 1);
  }

  void _paintMoved(
    PaintingContext context,
    Offset offset,
    RenderBox part,
    Matrix4 transform,
  ) {
    // A plain move needs no layer.
    final move = MatrixUtils.getAsTranslation(transform);
    if (move != null) {
      context.paintChild(part, offset + move);
    } else {
      context.pushTransform(
        needsCompositing,
        offset,
        transform,
        (context, offset) => context.paintChild(part, offset),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final toolbar = _part(_BarSlot.toolbar);
    final expanded = _part(_BarSlot.expanded);
    final bottom = _part(_BarSlot.bottom);
    final background = _part(_BarSlot.background);
    final progress = scroll.progress;
    // What is left of the expanded area, under the toolbar.
    final window = Rect.fromLTWH(
      0,
      _toolbarHeight,
      size.width,
      math.max(_expandedHeight + _lift, 0),
    );

    final goUnder = expanded != null;
    final edge = _part(_BarSlot.edge);
    // Under a bar with no large title the edge is behind everything; over
    // titles that go under the bar it is painted after them, and blurs and
    // fades them into the page as they do.
    if (edge != null && !goUnder) context.paintChild(edge, offset);

    // The large titles thin out as they go under the toolbar.
    final titleFade = scroll.titles;
    if (background != null && progress < 1) {
      final top = _backgroundTop;
      final shown = Rect.fromLTRB(
        0,
        top,
        size.width,
        math.max(window.bottom, top),
      );
      final alpha = ((1 - progress) * 255).round().clamp(0, 255);
      final scrim = expanded == null ? null : _scrimIn(expanded);
      void paintPicture(PaintingContext context, Offset offset) {
        context.pushClipRect(needsCompositing, offset, shown, (
          context,
          offset,
        ) {
          _paintMoved(context, offset, background, _backgroundTransform());
          // The page colour behind the titles, where they are, going with
          // them.
          if (scrim != null && titleFade > 0) {
            context.canvas
              ..save()
              ..translate(offset.dx, offset.dy)
              ..transform(_expandedTransform(expanded!).storage);
            scrim.paintScrim(context.canvas, expanded, opacity: titleFade);
            context.canvas.restore();
          }
        });
      }

      if (alpha >= 255) {
        paintPicture(context, offset);
      } else if (alpha > 0) {
        context.pushOpacity(offset, alpha, paintPicture);
      }
    }

    if (expanded != null && window.height > 0) {
      final alpha = (titleFade * 255).round();
      // Going under the bar, the titles are cut at its top, not at the
      // toolbar's lower edge: the toolbar's part of them is covered below.
      final clip = Rect.fromLTRB(0, 0, size.width, window.bottom);
      void paintTitle(PaintingContext context, Offset offset) =>
          context.pushClipRect(
            needsCompositing,
            offset,
            clip,
            (context, offset) => _paintMoved(
              context,
              offset,
              expanded,
              _expandedTransform(expanded),
            ),
          );

      if (alpha >= 255) {
        paintTitle(context, offset);
      } else if (alpha > 0) {
        context.pushOpacity(offset, alpha, paintTitle);
      }
    }

    if (goUnder) {
      if (edge != null) {
        context.paintChild(edge, offset);
      } else if (_cover case final cover?) {
        // The bar's surface over the toolbar's part of the titles, coming
        // in as they go under it. The fill leaves this part out.
        final shown = scroll.cover;
        if (shown > 0 && _toolbarHeight > 0) {
          context.canvas.drawRect(
            Rect.fromLTWH(
              offset.dx,
              offset.dy,
              size.width,
              math.min(_toolbarHeight, math.max(scroll.visibleExtent, 0)),
            ),
            Paint()..color = cover.withValues(alpha: cover.a * shown),
          );
        }
      }
    }

    if (bottom != null) {
      context.paintChild(
        bottom,
        offset + Offset(0, _toolbarHeight + _expandedHeight + _lift),
      );
    }
    if (toolbar != null) context.paintChild(toolbar, offset);
  }

  // The title and the picture are faded through layers of their own.
  @override
  bool get alwaysNeedsCompositing =>
      _part(_BarSlot.expanded) != null || _part(_BarSlot.background) != null;

  Matrix4 _transformOf(RenderBox child) {
    final data = child.parentData! as _BarPartData;
    return switch (data.slot) {
      _BarSlot.toolbar || _BarSlot.edge || null => Matrix4.identity(),
      _BarSlot.background => _backgroundTransform(),
      _BarSlot.expanded => _expandedTransform(child),
      _BarSlot.bottom => Matrix4.translationValues(
        0,
        _toolbarHeight + _expandedHeight + _lift,
        0,
      ),
    };
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transformOf(child));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    bool hit(_BarSlot slot) {
      final part = _part(slot);
      if (part == null) return false;
      return result.addWithPaintTransform(
        transform: _transformOf(part),
        position: position,
        hitTest: (result, transformed) =>
            part.hitTest(result, position: transformed),
      );
    }

    if (hit(_BarSlot.toolbar) || hit(_BarSlot.bottom)) return true;
    // What has gone under the toolbar cannot be touched.
    if (position.dy >= _toolbarHeight && hit(_BarSlot.expanded)) return true;
    return hit(_BarSlot.background);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // In reading order, whatever order they are painted in.
    for (final slot in const [
      _BarSlot.toolbar,
      _BarSlot.expanded,
      _BarSlot.bottom,
      _BarSlot.background,
    ]) {
      final part = _part(slot);
      if (part != null) visitor(part);
    }
  }
}

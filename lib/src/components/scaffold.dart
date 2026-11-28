import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/components/app_bar.dart';
import 'package:una/src/components/app_bar_layout.dart';
import 'package:una/src/components/navigation_bar.dart';
import 'package:una/src/components/scaffold_drawer.dart';
import 'package:una/src/i18n/localizations_delegate.dart';
import 'package:una/src/theme/data.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/backdrop.dart';
import 'package:una/src/utils/expand_reveal.dart';
import 'package:una/src/utils/overlay_insets.dart';
import 'package:una/src/utils/scroll_edge_shader.dart';
import 'package:una/src/utils/spring.dart';
import 'package:una/src/utils/system_overlay_style.dart';

/// Where a [Scaffold] puts its floating action button along the bottom of
/// the screen.
enum FloatingActionButtonLocation {
  /// At the start of the line: the left in a left-to-right language.
  start,

  /// In the middle.
  center,

  /// At the end of the line: the right in a left-to-right language.
  end,
}

/// The frame of a screen: a page with bars over its top and bottom, and the
/// things that float over or slide in beside it.
///
/// ```dart
/// Scaffold(
///   appBar: const AppBar(title: Text('Messages')),
///   body: ListView(children: conversations),
///   footer: const Composer(),
///   floatingActionButton: FloatingActionButton(
///     icon: const PhosphorIcon(PhosphorIconsRegular.pencilSimple),
///     label: const Text('New message'),
///     onPressed: _compose,
///   ),
///   drawer: const AccountMenu(),
/// )
/// ```
///
/// **The bars lie over the page.** [appBar], [banner], [bottomNavigationBar],
/// [footer] and [bottomSheet] are laid over [body], not above and below it,
/// so a translucent bar shows the page scrolling beneath it. To keep content
/// clear of them, [body] is given a [MediaQuery] whose padding includes
/// their heights — a `ListView`, a `SafeArea` or a `PageContainer` then
/// insets itself, the same way it would for the status bar. Every slot is
/// measured in the frame it is laid out, so a bar of any height works.
///
/// **The keyboard.** With [resizeToAvoidBottomInset], the default, [body]
/// ends where the software keyboard begins — a focused field is scrolled
/// into view as usual — and sees no `viewInsets` of its own. [footer],
/// [bottomSheet] and [floatingActionButton] ride up with the keyboard;
/// [bottomNavigationBar] stays where it is and is covered.
///
/// **Safe areas.** A slot at an edge of the screen is told about that
/// edge's safe area through its own [MediaQuery] padding and is expected to
/// extend under it, as [AppBar] and [BottomNavigationBar] do: wrap a
/// [footer] that is not a bar in a `SafeArea`. A slot that has another one
/// between it and the edge sees no padding there.
///
/// **Drawers.** [drawer] and [endDrawer] open as modal panels from the
/// start and end edges, over a scrim: with [ScaffoldState.openDrawer], with
/// the menu button an [AppBar] shows by itself, or — on a touch screen,
/// when the page cannot be popped — by dragging in from the edge. The
/// system back gesture, Escape, a tap on the scrim and a drag on the panel
/// close them. They need a [Navigator] above the scaffold.
///
/// **The status bar.** The scaffold makes the system's status and
/// navigation bars transparent and gives their icons the brightness that
/// reads on the page; an [AppBar] does the same for itself.
/// [systemOverlayStyle] overrides it.
///
/// Reach the scaffold from below with [Scaffold.of].
class Scaffold extends StatefulWidget {
  /// Creates a scaffold.
  const Scaffold({
    required this.body,
    this.appBar,
    this.banner,
    this.bottomNavigationBar,
    this.footer,
    this.bottomSheet,
    this.floatingActionButton,
    this.floatingActionButtonLocation = FloatingActionButtonLocation.end,
    this.drawer,
    this.endDrawer,
    this.onDrawerChanged,
    this.onEndDrawerChanged,
    this.drawerEdgeDragEnabled = true,
    this.resizeToAvoidBottomInset = true,
    this.systemOverlayStyle,
    this.backgroundColor,
    this.appBarHeight,
    this.bottomNavigationBarHeight,
    super.key,
  });

  /// The page.
  final Widget body;

  /// The bar laid over the top of [body], usually an [AppBar].
  final Widget? appBar;

  /// A message across the page, under [appBar]: usually an `Alert`. It
  /// takes the page's width; give it its own margins.
  ///
  /// When it comes or goes the page makes room for it on the theme's
  /// surface spring.
  final Widget? banner;

  /// The bar laid over the bottom of [body], usually a
  /// [BottomNavigationBar]. It stays at the bottom of the screen: the
  /// software keyboard covers it.
  final Widget? bottomNavigationBar;

  /// A bar that rides above [bottomNavigationBar] and above the software
  /// keyboard: a message composer, a row of actions, a `Toolbar`.
  ///
  /// It lies over the end of the page, like the bars, and is part of the
  /// bottom inset the page is told about. A `TextField` in the page that
  /// takes the focus is scrolled clear of it: its default `scrollPadding`
  /// includes that inset.
  final Widget? footer;

  /// A panel that stays over the bottom of the page without blocking it,
  /// above [footer]: a mini player, a summary that can be pulled up.
  final Widget? bottomSheet;

  /// A button floating over the page's bottom corner, usually a
  /// `FloatingActionButton`.
  ///
  /// It keeps one page margin from the side and from whatever is below it —
  /// the bottom bar, the footer, the sheet, the keyboard, the safe area —
  /// and moves on the theme's surface spring when those change. A button
  /// that appears, disappears or is replaced by one with another key pops
  /// in and out.
  final Widget? floatingActionButton;

  /// Where [floatingActionButton] sits along the bottom.
  final FloatingActionButtonLocation floatingActionButtonLocation;

  /// A panel that slides in from the start edge: a `Sidebar`, a column of
  /// `ListTile`s. See the class documentation.
  final Widget? drawer;

  /// A panel that slides in from the end edge.
  final Widget? endDrawer;

  /// Called with true when [drawer] opens and with false when it closes.
  final ValueChanged<bool>? onDrawerChanged;

  /// Called with true when [endDrawer] opens and with false when it closes.
  final ValueChanged<bool>? onEndDrawerChanged;

  /// Whether a finger dragging in from the start or end edge opens the
  /// drawer there.
  ///
  /// The drag is only offered while the page cannot be popped: on a page
  /// with something to go back to, that edge belongs to the back gesture.
  final bool drawerEdgeDragEnabled;

  /// Whether [body] ends at the software keyboard and the things at the
  /// bottom ride above it. Turn it off for a page that should stay as it
  /// is under the keyboard.
  final bool resizeToAvoidBottomInset;

  /// The style of the system's status and navigation bars over this
  /// screen. Defaults to transparent bars whose icons read on the page.
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// The page's colour. Defaults to the theme's background.
  final Color? backgroundColor;

  /// How far [body] is inset for [appBar], in place of its measured height.
  final double? appBarHeight;

  /// How far [body] is inset for [bottomNavigationBar], in place of its
  /// measured height.
  final double? bottomNavigationBarHeight;

  /// The state of the nearest [Scaffold] above [context], to open and close
  /// its drawers.
  ///
  /// [context] is rebuilt when the scaffold gains or loses a drawer, or
  /// opens or closes one. A context *above* the scaffold — the one of the
  /// `build` that returns it — does not find it: use a `Builder`, or a
  /// `GlobalKey<ScaffoldState>`.
  static ScaffoldState of(BuildContext context) {
    final state = maybeOf(context);
    assert(
      state != null,
      'Scaffold.of() was called with a context that has no Scaffold above '
      'it. A context from the build method that creates the Scaffold is '
      'above it: wrap the caller in a Builder.',
    );
    return state!;
  }

  /// The state of the nearest [Scaffold] above [context], or null.
  static ScaffoldState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ScaffoldScope>()?.state;

  @override
  State<Scaffold> createState() => ScaffoldState();
}

/// The state of a [Scaffold]: whether it has drawers, whether they are
/// open, and the calls that open and close them.
///
/// ```dart
/// IconButton.ghost(
///   icon: const PhosphorIcon(PhosphorIconsRegular.list),
///   onPressed: () => Scaffold.of(context).openDrawer(),
/// )
/// ```
class ScaffoldState extends State<Scaffold> with TickerProviderStateMixin {
  // The body, for a bar's scroll edge drawn by una's shader.
  final _edgeSource = ScrollEdgeSourceHandle();

  // Each drawer's content, handed to its route. The route is in the
  // navigator's overlay, not under this widget, so it cannot simply be
  // rebuilt from here.
  final _drawerContent = ValueNotifier<Widget?>(null);
  final _endDrawerContent = ValueNotifier<Widget?>(null);
  ScaffoldDrawerRoute? _drawerRoute;
  ScaffoldDrawerRoute? _endDrawerRoute;

  // What is left of the floating action button's travel after its place
  // changed, in logical pixels.
  late final _fabDx = SpringController(vsync: this, tolerance: .05);
  late final _fabDy = SpringController(vsync: this, tolerance: .05);
  late final _fabTravel = _FabTravel(
    Listenable.merge([_fabDx.animation, _fabDy.animation]),
  )..remaining = () => Offset(_fabDx.value, _fabDy.value);

  // What the scaffold last told the overlay registry, and the registry.
  OverlayInsets? _overlayInsets;
  final _geometry = _Geometry();

  /// Whether the scaffold has a [Scaffold.drawer].
  bool get hasDrawer => widget.drawer != null;

  /// Whether the scaffold has a [Scaffold.endDrawer].
  bool get hasEndDrawer => widget.endDrawer != null;

  /// Whether the [Scaffold.drawer] is open or opening.
  bool get isDrawerOpen => _drawerRoute != null;

  /// Whether the [Scaffold.endDrawer] is open or opening.
  bool get isEndDrawerOpen => _endDrawerRoute != null;

  /// Opens the [Scaffold.drawer]. Does nothing without one, or while it is
  /// open.
  void openDrawer() => _open(atEnd: false);

  /// Opens the [Scaffold.endDrawer]. Does nothing without one, or while it
  /// is open.
  void openEndDrawer() => _open(atEnd: true);

  /// Closes the [Scaffold.drawer] if it is open.
  void closeDrawer() => _drawerRoute?.close();

  /// Closes the [Scaffold.endDrawer] if it is open.
  void closeEndDrawer() => _endDrawerRoute?.close();

  /// A drawer's [content] under this scaffold's scope. The drawer is a
  /// route, built in the navigator's overlay and not under the scaffold,
  /// so without it `Scaffold.of` would find nothing there — and a menu
  /// item could not close the drawer it is in.
  Widget? _scoped(Widget? content, {required bool atEnd}) {
    if (content == null) return null;
    return _ScaffoldScope(
      state: this,
      hasDrawer: hasDrawer,
      hasEndDrawer: hasEndDrawer,
      // Shown, its own drawer is open; the scaffold's state says when it
      // is closing.
      isDrawerOpen: !atEnd,
      isEndDrawerOpen: atEnd,
      child: content,
    );
  }

  /// The scaffold's theme if a drawer has to carry it: under the
  /// navigator's own theme the drawer follows that one live — a switch to
  /// dark while it is open included.
  ThemeData? _drawerTheme(NavigatorState navigator) {
    final theme = Theme.of(context);
    final ambient = Theme.maybeOf(navigator.context, listen: false);
    return identical(theme, ambient) ? null : theme;
  }

  void _open({required bool atEnd, double from = 0, double velocity = 0}) {
    final content = atEnd ? widget.endDrawer : widget.drawer;
    if (content == null) return;
    if ((atEnd ? _endDrawerRoute : _drawerRoute) != null) return;
    final navigator = Navigator.maybeOf(context);
    assert(
      navigator != null,
      'A Scaffold needs a Navigator above it to open a drawer. UnaApp '
      'provides one.',
    );
    if (navigator == null) return;

    (atEnd ? _endDrawerContent : _drawerContent).value = _scoped(
      content,
      atEnd: atEnd,
    );
    final strings = UnaLocalizations.of(context);
    final route = ScaffoldDrawerRoute(
      content: atEnd ? _endDrawerContent : _drawerContent,
      atEnd: atEnd,
      motion: Motion.of(context),
      theme: _drawerTheme(navigator),
      semanticLabel: strings.navigation.menu,
      barrierLabel: strings.dialog.dismiss,
      initialProgress: from,
      initialVelocity: velocity,
    );
    setState(() {
      if (atEnd) {
        _endDrawerRoute = route;
      } else {
        _drawerRoute = route;
      }
    });
    (atEnd ? widget.onEndDrawerChanged : widget.onDrawerChanged)?.call(true);
    navigator.push(route).whenComplete(() {
      // Every way the route can go: the scrim, system back, Escape, a
      // drag, `closeDrawer`, the clean-up in `dispose`.
      if (!mounted) return;
      setState(() {
        if (atEnd) {
          _endDrawerRoute = null;
        } else {
          _drawerRoute = null;
        }
      });
      (atEnd ? widget.onEndDrawerChanged : widget.onDrawerChanged)?.call(
        false,
      );
    });
  }

  // The drawer a finger is pulling out of an edge, before it is a route.
  _DrawerPull? _pull;

  /// A finger that came in from an edge moved [delta] logical pixels,
  /// positive towards the end of the line.
  void _edgePull(bool atEnd, double delta) {
    final opening = atEnd ? -delta : delta;
    var pull = _pull;
    if (pull == null) {
      // Nothing shows until the finger has moved inwards: a touch that only
      // rests on the edge is not a pull.
      if (opening <= 0) return;
      if ((atEnd ? _endDrawerRoute : _drawerRoute) != null) return;
      final content = atEnd ? widget.endDrawer : widget.drawer;
      final navigator = Navigator.maybeOf(context);
      final overlay = navigator?.overlay;
      if (content == null || navigator == null || overlay == null) return;
      if (!drawerSlides(Motion.of(context))) {
        // Nothing to follow the finger with.
        _open(atEnd: atEnd);
        return;
      }
      final notifier = atEnd ? _endDrawerContent : _drawerContent;
      notifier.value = _scoped(content, atEnd: atEnd);
      final controller = AnimationController(vsync: this);
      final theme = _drawerTheme(navigator);
      final created = pull = _pull = _DrawerPull(atEnd, controller)
        ..width = drawerWidthFor(MediaQuery.sizeOf(context).width);
      created.entry = OverlayEntry(
        builder: (context) => DrawerDragPreview(
          progress: controller,
          content: notifier,
          atEnd: atEnd,
          onWidth: (width) => created.width = width,
          theme: theme,
        ),
      );
      overlay.insert(created.entry);
    }
    if (pull.atEnd != atEnd || pull.closing) return;
    pull.controller.value = (pull.controller.value + opening / pull.width)
        .clamp(0.0, 1.0);
  }

  /// The finger let go at [velocity] logical pixels per second, positive
  /// towards the end of the line.
  void _edgeRelease(bool atEnd, double velocity) {
    final pull = _pull;
    if (pull == null || pull.atEnd != atEnd || pull.closing) return;
    final opening = atEnd ? -velocity : velocity;
    final progress = pull.controller.value;
    if (drawerSettlesOpen(progress, opening)) {
      // The route takes over where the finger left the panel, at the speed
      // it had. The preview goes in the same frame the route arrives in.
      _pull = null;
      pull.entry.remove();
      SchedulerBinding.instance.addPostFrameCallback((_) => pull.dispose());
      _open(atEnd: atEnd, from: progress, velocity: opening / pull.width);
      return;
    }
    pull.closing = true;
    final motion = Motion.of(context);
    final (duration, curve) = drawerExit(
      progress,
      opening < 0 ? -opening / pull.width : 0,
      motion.normal,
      motion,
    );
    pull.controller
        .animateBack(0, duration: duration, curve: curve)
        .whenCompleteOrCancel(() {
          if (!identical(_pull, pull)) return;
          _pull = null;
          pull.entry.remove();
          pull.dispose();
        });
  }

  Widget _edgeDragArea({required bool atEnd, required double sign}) {
    return DrawerEdgeDragArea(
      onUpdate: (delta) => _edgePull(atEnd, delta * sign),
      onEnd: (velocity) => _edgeRelease(atEnd, velocity * sign),
      onCancel: () => _edgeRelease(atEnd, 0),
    );
  }

  @override
  void didUpdateWidget(Scaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.drawer, oldWidget.drawer) ||
        !identical(widget.endDrawer, oldWidget.endDrawer)) {
      // An open drawer shows what the scaffold has now. Its route is built
      // elsewhere in the tree, so it is told once this build is over.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _drawerContent.value = _scoped(widget.drawer, atEnd: false);
        _endDrawerContent.value = _scoped(widget.endDrawer, atEnd: true);
        if (widget.drawer == null) _drawerRoute?.close();
        if (widget.endDrawer == null) _endDrawerRoute?.close();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final insets = OverlayInsets.maybeOf(context);
    if (!identical(insets, _overlayInsets)) {
      final previous = _overlayInsets;
      _overlayInsets = insets;
      _geometry.reported = null;
      if (previous != null) {
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => previous.remove(this),
        );
      }
    }
  }

  @override
  void dispose() {
    // A drawer left open would be a route nobody owns: take it down once
    // the navigator can be changed again.
    final routes = [?_drawerRoute, ?_endDrawerRoute];
    final insets = _overlayInsets;
    if (routes.isNotEmpty || insets != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final route in routes) {
          if (route.isActive) route.navigator?.removeRoute(route);
        }
        insets?.remove(this);
      });
    }
    if (_pull case final pull?) {
      _pull = null;
      pull.controller.dispose();
      pull.entry.remove();
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => pull.entry.dispose(),
      );
    }
    _drawerContent.dispose();
    _endDrawerContent.dispose();
    _fabDx.dispose();
    _fabDy.dispose();
    super.dispose();
  }

  /// Hands the jump the button's place just made to its springs, which
  /// then run it down to nothing.
  void _startFabTravel() {
    if (!mounted) return;
    final pending = _fabTravel.pending;
    _fabTravel.pending = Offset.zero;
    final spring = Motion.of(context).smooth;
    _fabDx
      ..shiftBy(pending.dx, spring: spring)
      ..animateTo(0, spring: spring);
    _fabDy
      ..shiftBy(pending.dy, spring: spring)
      ..animateTo(0, spring: spring);
  }

  /// Tells the overlay registry what this scaffold covers, once the frame
  /// that changed it is over.
  void _reportGeometry() {
    if (!mounted) return;
    final insets = _overlayInsets;
    if (insets == null) return;
    final box = context.findRenderObject();
    EdgeInsets? covered;
    // A scaffold in a covered route covers nothing anybody can see.
    if (_geometry.onStage && box is RenderBox && box.hasSize) {
      // What it covers is counted from the screen's edges, so only a
      // scaffold that reaches an edge has anything to say about it.
      final origin = box.localToGlobal(Offset.zero);
      final atTop = origin.dy.abs() < 1;
      final atBottom =
          (origin.dy + box.size.height - _geometry.viewHeight).abs() < 1;
      covered = EdgeInsets.only(
        top: atTop ? _geometry.top : 0,
        bottom: atBottom ? _geometry.bottom : 0,
      );
    }
    if (covered == _geometry.reported) return;
    _geometry.reported = covered;
    if (covered == null || covered == EdgeInsets.zero) {
      insets.remove(this);
    } else {
      insets.report(this, covered);
    }
  }

  void _onGeometry(double top, double bottom) {
    if (_overlayInsets == null) return;
    if (top == _geometry.top && bottom == _geometry.bottom) return;
    _geometry
      ..top = top
      ..bottom = bottom;
    _scheduleReport();
  }

  bool _reportScheduled = false;

  void _scheduleReport() {
    if (_reportScheduled) return;
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      _reportGeometry();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final direction = Directionality.of(context);
    final motion = Motion.of(context);
    final background = widget.backgroundColor ?? theme.colorScheme.background;

    _geometry.viewHeight = media.size.height;
    // Off stage under a covered route, and in a hidden child of an
    // IndexedStack, which keeps its tickers running.
    final onStage =
        TickerMode.valuesOf(context).enabled && Visibility.of(context);
    if (onStage != _geometry.onStage) {
      _geometry.onStage = onStage;
      if (_overlayInsets != null) _scheduleReport();
    }

    final hasAppBar = widget.appBar != null;
    final hasBar = widget.bottomNavigationBar != null;
    final hasFooter = widget.footer != null;
    final hasSheet = widget.bottomSheet != null;
    final keyboard = widget.resizeToAvoidBottomInset
        ? media.viewInsets.bottom
        : 0.0;
    // The home indicator's inset gives way to the keyboard's.
    final safeBottom = math.max<double>(media.padding.bottom - keyboard, 0);
    // A slot that rides above the keyboard has no keyboard under it.
    final lifted = media.copyWith(
      viewInsets: media.viewInsets.copyWith(
        bottom: media.viewInsets.bottom - keyboard,
      ),
    );
    MediaQueryData bottomSlot({required bool atEdge}) => lifted.copyWith(
      padding: media.padding.copyWith(top: 0, bottom: atEdge ? safeBottom : 0),
    );

    final pagePadding = (theme.layoutTheme.pagePadding ?? EdgeInsets.zero)
        .resolve(direction);
    final margin = math.max(pagePadding.left, pagePadding.right);

    // An edge is the drawer's to drag from only while nothing else wants
    // it: on a page that can be popped it is the way back.
    final edgeDrag =
        widget.drawerEdgeDragEnabled &&
        (hasDrawer || hasEndDrawer) &&
        !(ModalRoute.canPopOf(context) ?? false);
    final sign = direction == TextDirection.ltr ? 1.0 : -1.0;

    Widget slot(_Slot id, double order, Widget child, [MediaQueryData? data]) {
      return LayoutId(
        id: id,
        // Read in the order of the screen, top to bottom, although the bars
        // are painted last.
        child: FocusTraversalOrder(
          order: NumericFocusOrder(order),
          child: FocusTraversalGroup(
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              sortKey: OrdinalSortKey(order),
              child: data == null
                  ? child
                  : MediaQuery(data: data, child: child),
            ),
          ),
        ),
      );
    }

    final body = widget.body;
    final layout = CustomMultiChildLayout(
      delegate: _ScaffoldLayout(
        textDirection: direction,
        safeArea: media.padding,
        keyboard: keyboard,
        fabLocation: widget.floatingActionButtonLocation,
        fabMargin: margin,
        fabTravel: _fabTravel,
        animateFab: !motion.smooth.isInstant,
        onFabTravel: _startFabTravel,
        appBarInset: widget.appBarHeight,
        bottomBarInset: widget.bottomNavigationBarHeight,
        onGeometry: _onGeometry,
      ),
      // In paint order: the page, then what lies over its bottom, then what
      // lies over its top.
      children: [
        slot(
          _Slot.body,
          2,
          // The page learns its insets from the layout that measured the
          // bars: in the same frame, with nothing estimated.
          // The page a bar's scroll edge is a picture of, where it is
          // drawn by una's shader (see `LiquidGlassTheme.webScrollEdge`).
          ScrollEdgeSource(
            handle: _edgeSource,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final insets = constraints as _BodyConstraints;
                return MediaQuery(
                  data: lifted.copyWith(
                    padding: media.padding.copyWith(
                      top: insets.top,
                      bottom: insets.bottom,
                    ),
                  ),
                  child: body,
                );
              },
            ),
          ),
        ),
        // The strips stay while a drawer is open: taking one away mid-drag
        // would cancel the drag that is opening it.
        if (edgeDrag && hasDrawer)
          LayoutId(
            id: _Slot.startEdge,
            child: _edgeDragArea(atEnd: false, sign: sign),
          ),
        if (edgeDrag && hasEndDrawer)
          LayoutId(
            id: _Slot.endEdge,
            child: _edgeDragArea(atEnd: true, sign: sign),
          ),
        if (hasSheet)
          slot(
            _Slot.bottomSheet,
            4,
            widget.bottomSheet!,
            bottomSlot(atEdge: !hasBar && !hasFooter),
          ),
        if (hasFooter)
          slot(_Slot.footer, 5, widget.footer!, bottomSlot(atEdge: !hasBar)),
        if (hasBar)
          slot(
            _Slot.bottomBar,
            6,
            widget.bottomNavigationBar!,
            media.copyWith(padding: media.padding.copyWith(top: 0)),
          ),
        slot(
          _Slot.fab,
          3,
          _FabSwitcher(child: widget.floatingActionButton),
          bottomSlot(atEdge: false),
        ),
        if (hasAppBar) slot(_Slot.appBar, 0, widget.appBar!),
        slot(
          _Slot.banner,
          1,
          _BannerSlot(child: widget.banner),
          // Under the app bar, or under the status bar: either way the
          // layout has taken care of the top.
          media.copyWith(padding: media.padding.copyWith(top: 0, bottom: 0)),
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          widget.systemOverlayStyle ??
          systemOverlayStyleFor(
            widget.backgroundColor == null
                ? theme.brightness
                : surfaceBrightness(background, theme.colorScheme.background),
          ),
      child: _ScaffoldScope(
        state: this,
        hasDrawer: hasDrawer,
        hasEndDrawer: hasEndDrawer,
        isDrawerOpen: isDrawerOpen,
        isEndDrawerOpen: isEndDrawerOpen,
        child: ColoredBox(
          color: background,
          // So that a bar can tell whether the page has scrolled under it.
          child: ScrollNotificationObserver(
            child: ScrollEdgeSourceScope(
              handle: _edgeSource,
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: layout,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells the widgets under a [Scaffold] about its drawers.
class _ScaffoldScope extends InheritedWidget {
  const _ScaffoldScope({
    required this.state,
    required this.hasDrawer,
    required this.hasEndDrawer,
    required this.isDrawerOpen,
    required this.isEndDrawerOpen,
    required super.child,
  });

  final ScaffoldState state;
  final bool hasDrawer;
  final bool hasEndDrawer;
  final bool isDrawerOpen;
  final bool isEndDrawerOpen;

  @override
  bool updateShouldNotify(_ScaffoldScope oldWidget) =>
      hasDrawer != oldWidget.hasDrawer ||
      hasEndDrawer != oldWidget.hasEndDrawer ||
      isDrawerOpen != oldWidget.isDrawerOpen ||
      isEndDrawerOpen != oldWidget.isEndDrawerOpen;
}

enum _Slot {
  body,
  bottomSheet,
  footer,
  bottomBar,
  fab,
  appBar,
  banner,
  startEdge,
  endEdge,
}

/// The width of the strip along an edge that a drawer is dragged out of.
const _edgeDragWidth = 20.0;

/// A drawer on its way out of an edge under a finger.
class _DrawerPull {
  _DrawerPull(this.atEnd, this.controller);

  final bool atEnd;

  /// How far out it is, from 0 to 1.
  final AnimationController controller;

  /// Where it is shown until it is let go.
  late final OverlayEntry entry;

  /// The panel's width, for turning the finger's travel into progress.
  double width = 0;

  /// Whether it was let go and is on its way back.
  bool closing = false;

  void dispose() {
    controller.dispose();
    entry.dispose();
  }
}

/// What the scaffold covers at the top and the bottom, and what it has told
/// the overlay registry about it.
class _Geometry {
  double top = 0;
  double bottom = 0;
  bool onStage = true;
  double viewHeight = 0;
  EdgeInsets? reported;
}

/// The floating action button's place between layouts.
class _FabTravel {
  _FabTravel(this.animation);

  /// Ticks while the button is travelling.
  final Listenable animation;

  /// What the springs still have to run down, read at layout.
  Offset Function() remaining = () => Offset.zero;

  /// Where the button rested at the last layout, and what that layout was
  /// given: the scaffold's size and the keyboard's height.
  Offset? target;
  Offset? anchor;
  Size? size;
  double? keyboard;

  /// A jump made by the current layout that the springs have not been
  /// given yet.
  Offset pending = Offset.zero;
  bool scheduled = false;
}

/// The constraints a scaffold lays its page out with: tight, as large as
/// the page gets, and carrying how far the bars reach in over it.
class _BodyConstraints extends BoxConstraints {
  const _BodyConstraints({
    required double width,
    required double height,
    required this.top,
    required this.bottom,
  }) : super(
         minWidth: width,
         maxWidth: width,
         minHeight: height,
         maxHeight: height,
       );

  final double top;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is _BodyConstraints &&
      other.top == top &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(super.hashCode, top, bottom);
}

class _ScaffoldLayout extends MultiChildLayoutDelegate {
  _ScaffoldLayout({
    required this.textDirection,
    required this.safeArea,
    required this.keyboard,
    required this.fabLocation,
    required this.fabMargin,
    required this.fabTravel,
    required this.animateFab,
    required this.onFabTravel,
    required this.appBarInset,
    required this.bottomBarInset,
    required this.onGeometry,
  }) : super(relayout: fabTravel.animation);

  final TextDirection textDirection;
  final EdgeInsets safeArea;
  final double keyboard;
  final FloatingActionButtonLocation fabLocation;
  final double fabMargin;
  final _FabTravel fabTravel;
  final bool animateFab;
  final VoidCallback onFabTravel;
  final double? appBarInset;
  final double? bottomBarInset;
  final void Function(double top, double bottom) onGeometry;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout(Size size) {
    final bar = BoxConstraints(
      minWidth: size.width,
      maxWidth: size.width,
      maxHeight: size.height,
    );

    // The top: the app bar, then the banner under it. The banner is laid
    // out first: a bar of Liquid Glass reaches its scroll edge down under
    // it, and is told how far in its constraints.
    final banner = layoutChild(_Slot.banner, bar).height;
    var top = safeArea.top;
    var topInset = top;
    if (hasChild(_Slot.appBar)) {
      final height = layoutChild(
        _Slot.appBar,
        ScaffoldBarConstraints.from(bar, below: banner),
      ).height;
      positionChild(_Slot.appBar, Offset.zero);
      top = height;
      topInset = appBarInset ?? height;
    }
    positionChild(_Slot.banner, Offset(0, top));
    top += banner;
    topInset += banner;

    // The bottom: the bottom bar on the edge, where the keyboard covers
    // it; the footer above whichever of the two is taller; the sheet above
    // the footer.
    var barHeight = 0.0;
    var floor = keyboard;
    var bottomInset = 0.0;
    final hasBar = hasChild(_Slot.bottomBar);
    if (hasBar) {
      barHeight = layoutChild(_Slot.bottomBar, bar).height;
      positionChild(_Slot.bottomBar, Offset(0, size.height - barHeight));
      floor = math.max(keyboard, barHeight);
      bottomInset = math.max((bottomBarInset ?? barHeight) - keyboard, 0);
    }
    var stacked = 0.0;
    for (final id in const [_Slot.footer, _Slot.bottomSheet]) {
      if (!hasChild(id)) continue;
      final height = layoutChild(id, bar).height;
      stacked += height;
      positionChild(id, Offset(0, size.height - floor - stacked));
    }
    // With nothing of the scaffold's on the bottom edge, the safe area is
    // the page's to keep clear of.
    final bare = !hasBar && stacked == 0;
    final safeBottom = math.max<double>(safeArea.bottom - keyboard, 0);
    bottomInset += stacked + (bare ? safeBottom : 0);

    layoutChild(
      _Slot.body,
      _BodyConstraints(
        width: size.width,
        height: math.max(size.height - keyboard, 0),
        top: topInset,
        bottom: bottomInset,
      ),
    );
    positionChild(_Slot.body, Offset.zero);

    // The edges a drawer is dragged out of, including the part of the
    // screen a notch keeps the page out of.
    for (final (id, atEnd) in const [
      (_Slot.startEdge, false),
      (_Slot.endEdge, true),
    ]) {
      if (!hasChild(id)) continue;
      final onRight = atEnd == (textDirection == TextDirection.ltr);
      final width = _edgeDragWidth + (onRight ? safeArea.right : safeArea.left);
      layoutChild(
        id,
        BoxConstraints.tightFor(width: width, height: size.height),
      );
      positionChild(id, Offset(onRight ? size.width - width : 0, 0));
    }

    // The floating action button: a margin above everything at the bottom.
    final fab = layoutChild(_Slot.fab, BoxConstraints.loose(size));
    final clear = floor + stacked + (bare ? safeBottom : 0);
    final left = safeArea.left + fabMargin;
    final right = size.width - safeArea.right - fabMargin - fab.width;
    final x = switch ((fabLocation, textDirection)) {
      (FloatingActionButtonLocation.center, _) => (size.width - fab.width) / 2,
      (FloatingActionButtonLocation.start, TextDirection.ltr) => left,
      (FloatingActionButtonLocation.start, TextDirection.rtl) => right,
      (FloatingActionButtonLocation.end, TextDirection.ltr) => right,
      (FloatingActionButtonLocation.end, TextDirection.rtl) => left,
    };
    final bottom = size.height - clear - fabMargin;
    final target = Offset(x, bottom - fab.height);
    // The corner the button hangs from: what does not move when the button
    // itself changes size.
    final anchor = Offset(
      fabLocation == FloatingActionButtonLocation.center
          ? size.width / 2
          : x == left
          ? left
          : right + fab.width,
      bottom,
    );
    final travel = fabTravel;
    final previous = travel.target;
    // Its place changed because something at the bottom did — a footer
    // appeared, the bar went away, it was sent to the other corner. That is
    // travelled. A window that is being resized and a keyboard on its way
    // up are followed rigidly: they are moving already. So is a button
    // that is growing or shrinking from its corner.
    if (animateFab &&
        !fab.isEmpty &&
        previous != null &&
        travel.anchor != anchor &&
        travel.size == size &&
        travel.keyboard == keyboard) {
      travel.pending += previous - target;
      if (!travel.scheduled) {
        travel.scheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          travel.scheduled = false;
          onFabTravel();
        });
      }
    }
    travel
      ..target = fab.isEmpty ? null : target
      ..anchor = anchor
      ..size = size
      ..keyboard = keyboard;
    positionChild(_Slot.fab, target + travel.pending + travel.remaining());

    onGeometry(
      top,
      clear + (fab.isEmpty ? 0 : fab.height + fabMargin),
    );
  }

  @override
  bool shouldRelayout(_ScaffoldLayout oldDelegate) =>
      textDirection != oldDelegate.textDirection ||
      safeArea != oldDelegate.safeArea ||
      keyboard != oldDelegate.keyboard ||
      fabLocation != oldDelegate.fabLocation ||
      fabMargin != oldDelegate.fabMargin ||
      animateFab != oldDelegate.animateFab ||
      appBarInset != oldDelegate.appBarInset ||
      bottomBarInset != oldDelegate.bottomBarInset;
}

/// The banner's place under the app bar: it opens and closes on the
/// surface spring, and goes on showing the banner it had while it closes.
class _BannerSlot extends StatefulWidget {
  const _BannerSlot({required this.child});

  final Widget? child;

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  late Widget? _shown = widget.child;

  @override
  void didUpdateWidget(_BannerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) _shown = widget.child;
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.child != null;
    return SpringBuilder(
      value: open ? 1 : 0,
      spring: Motion.of(context).smooth,
      onEnd: () {
        if (!open && mounted && widget.child == null) {
          setState(() => _shown = null);
        }
      },
      builder: (context, factor, child) {
        if (child == null) return const SizedBox(width: double.infinity);
        return ExpandReveal(
          factor: factor,
          travel: Motion.of(context).overlayTravel,
          child: SizedBox(width: double.infinity, child: child),
        );
      },
      child: _shown,
    );
  }
}

/// Pops the floating action button in and out, and swaps one for another by
/// popping the old one out first.
class _FabSwitcher extends StatefulWidget {
  const _FabSwitcher({required this.child});

  final Widget? child;

  @override
  State<_FabSwitcher> createState() => _FabSwitcherState();
}

class _FabSwitcherState extends State<_FabSwitcher>
    with SingleTickerProviderStateMixin {
  late Widget? _shown = widget.child;

  // 0 gone, 1 there. Made at once: made on first use, the first button a
  // scaffold is given would be made already there, and not pop in.
  late final SpringController _presence;

  // Through a host that a glass button takes the fade over from: an
  // opacity layer around a backdrop filter takes its blur away on some
  // renderers.
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _presence = SpringController(
      vsync: this,
      value: widget.child == null ? 0 : 1,
    );
    _opacity = _presence.animation.drive(const _FabOpacity());
  }

  @override
  void didUpdateWidget(_FabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.child;
    final shown = _shown;
    if (next != null && (shown == null || Widget.canUpdate(shown, next))) {
      // The same button, rebuilt — or the first one.
      final entering = shown == null || _presence.target == 0;
      _shown = next;
      if (entering) _presence.animateTo(1, spring: Motion.of(context).bouncy);
      return;
    }
    if (shown == null || _presence.target == 0) return;
    // Gone, or replaced: the old one leaves first.
    _presence.animateTo(0, spring: Motion.of(context).snappy).whenComplete(() {
      if (!mounted || _presence.target != 0) return;
      setState(() => _shown = widget.child);
      if (widget.child != null) {
        _presence.animateTo(1, spring: Motion.of(context).bouncy);
      }
    });
  }

  @override
  void dispose() {
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final leaving =
        widget.child == null || !Widget.canUpdate(shown, widget.child!);
    return IgnorePointer(
      ignoring: leaving,
      // One tree for the whole pop: a full opacity and an identity
      // transform cost no layer.
      child: BackdropFadeHost(
        opacity: _opacity,
        child: AnimatedBuilder(
          animation: _presence.animation,
          builder: (context, child) => Transform.scale(
            scale: .6 + .4 * _presence.value,
            child: child,
          ),
          child: shown,
        ),
      ),
    );
  }
}

/// The floating action button's opacity for its presence: there by half
/// way.
class _FabOpacity extends Animatable<double> {
  const _FabOpacity();

  @override
  double transform(double t) => (t * 2).clamp(0.0, 1.0);
}

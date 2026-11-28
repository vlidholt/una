import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/theme/data.dart';
import 'package:una/src/theme/form_factor.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/back_edge_claims.dart';
import 'package:una/src/utils/entrance.dart';
import 'package:una/src/utils/route_on_top.dart';

/// The page route `UnaApp` uses by default.
///
/// On iOS and macOS, on a phone or a tablet, it is the platform's push, as
/// Material's route draws it there: the page slides the whole width in
/// from the end side — the right, in a left-to-right layout — casting a
/// soft shadow on the page under it, which moves a third of the way out
/// of its way. Elsewhere on a phone the new page fades in while it moves a
/// short way into place, and the page under it gives way a little. A
/// [fullscreenDialog] rises from below. On a desktop, where a page is not a
/// sheet of paper, it only rises a few pixels. The timing is the theme's
/// `Motion`: with reduced motion the page only fades, and with
/// `Motion.none` it is simply there.
///
/// ## Going back with a gesture
///
/// On iOS and macOS the page can be dragged away from its start edge — the
/// left, in a left-to-right layout; on a Mac with the mouse as well. It
/// follows the finger; let go past the middle, or flick it, and it leaves,
/// otherwise it springs back. On Android the
/// system's predictive back gesture is previewed: the page shrinks a little
/// with rounded corners while the finger is down, and leaves when the
/// gesture is committed. Neither is offered to a [fullscreenDialog], to the
/// first page of a navigator, or to a page that vetoes its pop with a
/// `PopScope`. See [backGesture].
///
/// To declare pages rather than push routes — `Navigator.pages`, or a
/// router package — use [UnaPage], which makes one of these.
class UnaPageRoute<T> extends PageRoute<T> {
  /// Creates a page route that builds its page with [builder].
  UnaPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog,
    this.backGesture,
  });

  /// Builds the page.
  final WidgetBuilder builder;

  @override
  final bool maintainState;

  /// Whether the page can be taken back with a gesture.
  ///
  /// Null follows the platform: the swipe from the start edge on iOS and
  /// macOS, and
  /// the preview of the predictive back gesture wherever the system reports
  /// one (Android). True also offers the edge swipe on every other
  /// platform; false switches both off, and the system's back then pops
  /// the page without a preview.
  ///
  /// A [fullscreenDialog] never has one, whatever this says.
  final bool? backGesture;

  /// The page itself. [UnaPage] reads its child here, so a page that
  /// is updated in place shows its new content.
  @protected
  Widget buildContent(BuildContext context) => builder(context);

  /// Whether a drag from the start edge takes this page back.
  bool get _swipes =>
      !fullscreenDialog && (backGesture ?? _isApple(defaultTargetPlatform));

  static bool _isApple(TargetPlatform platform) =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  /// Whether the push is the platform's whole-width slide: iOS and macOS,
  /// on a phone or a tablet, with motion, and not a dialog.
  bool _slidesIn(ThemeData theme, Motion motion) =>
      !fullscreenDialog &&
      !motion.reduced &&
      theme.formFactor != FormFactor.desktop &&
      _isApple(defaultTargetPlatform);

  /// Whether a predictive back gesture is previewed on this page.
  bool get _previews => !fullscreenDialog && (backGesture ?? true);

  /// The motion tokens where the route was pushed, without making the
  /// navigator depend on them. Null before the route has a navigator.
  Motion? get _motion {
    final context = navigator?.context;
    if (context == null) return null;
    final motion = Theme.maybeOf(context, listen: false)?.motion;
    if (motion == null) return null;
    final reduce =
        context
            .getInheritedWidgetOfExactType<MediaQuery>()
            ?.data
            .disableAnimations ??
        false;
    return reduce ? motion.reduce() : motion;
  }

  @override
  Duration get transitionDuration {
    final motion = _motion;
    if (motion == null) return const Duration(milliseconds: 200);
    if (motion.reduced) return motion.fast;
    final theme = Theme.maybeOf(navigator!.context, listen: false);
    // A whole page travelling the whole width is a surface: the smooth
    // spring, not the snappy one.
    return theme != null && _slidesIn(theme, motion)
        ? motion.smooth.settleDuration
        : motion.snappy.settleDuration;
  }

  // It leaves faster than it arrives.
  @override
  Duration get reverseTransitionDuration {
    final motion = _motion;
    if (motion == null) return const Duration(milliseconds: 200);
    return motion.reduced ? motion.fast : motion.normal;
  }

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  /// Whether the route over this one rises from below rather than coming
  /// in from the side: this page then stays where it is.
  bool _coveredByDialog = false;

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    _coveredByDialog = nextRoute is PageRoute && nextRoute.fullscreenDialog;
    super.didChangeNext(nextRoute);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: buildContent(context),
    );
  }

  /// The animations the transition is drawn from. They depend only on the
  /// route's own animations and the motion curves, so they are made when
  /// those change — not in [buildTransitions], which the framework calls on
  /// every tick of either animation, for this page and the one it covers.
  _PageAnimations? _animations;

  // ---------------------------------------------------------------------
  // Going back with a gesture.
  //
  // A gesture drives the route's own controller, as the framework's routes
  // do, and the transition is drawn differently while one is under way
  // (`_phase`). What the phases draw from is made when a phase begins, for
  // the same reason `_animations` is kept: `buildTransitions` runs on every
  // tick.
  // ---------------------------------------------------------------------

  _BackPhase _phase = _BackPhase.none;

  /// The navigator a gesture was started on: the route may have left it by
  /// the time the gesture has settled.
  NavigatorState? _gestureNavigator;

  /// The edge a predictive back gesture came from.
  SwipeEdge _edge = SwipeEdge.left;

  /// How far a predictive back gesture has pulled the page, from 0 to 1.
  Animation<double>? _pull;

  /// Where a page that fades away after a swipe is held, and its fade.
  Animation<double>? _heldProgress;
  Animation<double>? _heldFade;

  void _enter(_BackPhase phase) {
    _phase = phase;
    if (isActive) changedInternalState();
  }

  /// Ends the phase once the controller has come to rest.
  void _whenSettled(VoidCallback done) {
    final controller = this.controller;
    if (controller == null || !controller.isAnimating) {
      done();
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      controller.removeStatusListener(listener);
      done();
    };
    controller.addStatusListener(listener);
  }

  void _swipeStart() {
    final navigator = this.navigator;
    if (navigator == null || controller == null) return;
    if (_phase != _BackPhase.none) return;
    _gestureNavigator = navigator;
    navigator.didStartUserGesture();
    _enter(_BackPhase.swipe);
  }

  /// Moves the page by [fraction] of its width towards leaving.
  void _swipeBy(double fraction) {
    if (_phase != _BackPhase.swipe) return;
    final controller = this.controller!;
    controller.value = (controller.value - fraction).clamp(0.0, 1.0);
  }

  /// Lets go of the page, moving at [velocity] widths a second towards
  /// leaving.
  void _swipeEnd(double velocity) {
    if (_phase != _BackPhase.swipe) return;
    final navigator = _gestureNavigator!;
    final controller = this.controller!;
    final value = controller.value;
    // A flick decides; without one, whichever side of the middle it is on.
    final leave = isCurrent && (velocity > 1 || (velocity >= -1 && value < .5));
    final motion = _motion ?? Motion.none;
    // Critically damped: an overshoot past either end is clamped and would
    // only hold the route back from finishing.
    final spring = motion.snappy.copyWith(bounce: 0);
    final fades = motion.reduced && motion.fast > Duration.zero;
    if (leave) {
      navigator.pop();
      // Already gone if it was let go at the very end.
      if (controller.isAnimating) {
        if (!spring.isInstant) {
          controller.animateBackWith(
            spring.simulation(start: value, end: 0, velocity: -velocity),
          );
        } else if (fades && value > 0) {
          // With reduced motion the page fades where it was let go.
          _heldProgress = AlwaysStoppedAnimation<double>(value);
          _heldFade = controller.drive(_FadeInBy(value));
          _phase = _BackPhase.swipeFade;
          controller.animateBack(0, duration: motion.fast);
        } else {
          controller.value = 0;
        }
      }
    } else if (!spring.isInstant) {
      controller.animateWith(
        spring.simulation(start: value, end: 1, velocity: -velocity),
      );
    } else if (fades) {
      controller.animateTo(1, duration: motion.fast, curve: motion.standard);
    } else {
      controller.value = 1;
    }
    _whenSettled(() {
      _gestureNavigator = null;
      _heldProgress = null;
      _heldFade = null;
      if (navigator.mounted) navigator.didStopUserGesture();
      _enter(_BackPhase.none);
    });
  }

  /// The gesture's widget went away under the finger.
  void _swipeAbandoned() {
    if (_phase != _BackPhase.swipe) return;
    final navigator = _gestureNavigator;
    _gestureNavigator = null;
    _phase = _BackPhase.none;
    if (isActive) controller?.value = 1;
    if (navigator != null && navigator.mounted) {
      navigator.didStopUserGesture();
    }
  }

  /// The pull of a predictive back gesture. The route's own controller is
  /// left alone until the gesture is committed, so that the ordinary exit
  /// then plays from its start and the page under this one does not move
  /// while the finger is still deciding.
  AnimationController? _pullController;

  bool _predictiveStart(PredictiveBackEvent event) {
    if (event.isButtonEvent || !_previews) return false;
    if (_phase != _BackPhase.none || !isCurrent || !popGestureEnabled) {
      return false;
    }
    final navigator = this.navigator!;
    _gestureNavigator = navigator;
    _edge = event.swipeEdge;
    _pull = (_pullController ??= AnimationController(vsync: navigator))
      ..value = event.progress;
    // Let the page under this one be painted, as it is during a
    // transition.
    if (overlayEntries.isNotEmpty) overlayEntries.first.opaque = false;
    navigator.didStartUserGesture();
    _enter(_BackPhase.predictive);
    return true;
  }

  void _predictiveUpdate(PredictiveBackEvent event) {
    if (_phase != _BackPhase.predictive) return;
    _pullController!.value = event.progress;
  }

  void _predictiveEnd({required bool commit}) {
    if (_phase != _BackPhase.predictive) return;
    final navigator = _gestureNavigator!;
    final pull = _pullController!;
    void done() {
      _gestureNavigator = null;
      if (navigator.mounted) navigator.didStopUserGesture();
      if (!isActive) return;
      pull.value = 0;
      _pull = null;
      if (overlayEntries.isNotEmpty && (controller?.isCompleted ?? false)) {
        overlayEntries.first.opaque = opaque;
      }
      _enter(_BackPhase.none);
    }

    if (commit && isCurrent) {
      // The page keeps the shape the gesture left it in while the
      // ordinary exit plays.
      _phase = _BackPhase.committed;
      navigator.pop();
      _whenSettled(done);
      return;
    }
    final motion = _motion ?? Motion.none;
    final spring = motion.snappy.copyWith(bounce: 0);
    if (!spring.isInstant) {
      pull.animateBackWith(spring.simulation(start: pull.value, end: 0));
    } else if (motion.fast > Duration.zero) {
      pull.animateBack(0, duration: motion.fast, curve: motion.standard);
    }
    if (!pull.isAnimating) {
      done();
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      pull.removeStatusListener(listener);
      done();
    };
    pull.addStatusListener(listener);
  }

  @override
  void dispose() {
    _pullController?.dispose();
    _pullController = null;
    super.dispose();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final motion = Motion.of(context);
    final theme = Theme.of(context);
    final mobile = theme.formFactor == FormFactor.mobile;
    final side = Directionality.maybeOf(context) == TextDirection.rtl
        ? -1.0
        : 1.0;
    final slides = _slidesIn(theme, motion);
    // In on the spring, and back out in a straight line from wherever it
    // is, so a pop in the middle of a push does not jump.
    final enter = motion.reduced
        ? motion.standard
        : slides
        ? motion.smooth.curve
        : motion.snappy.curve;
    var animations = _animations;
    if (animations == null ||
        !animations.isFor(
          animation,
          secondaryAnimation,
          enter: enter,
          giveWay: motion.standard,
        )) {
      animations = _animations = _PageAnimations(
        animation,
        secondaryAnimation,
        enter: enter,
        giveWay: motion.standard,
      );
    }
    // Where the page comes from: a fifth of the width from the end side on
    // a phone, from below for a dialog, and a short rise on a desktop.
    var slide = 0.0;
    var rise = 0.0;
    if (motion.reduced) {
      // Only the fade.
    } else if (fullscreenDialog) {
      rise = mobile ? 48 : motion.overlayTravel * 2;
    } else if (slides) {
      slide = side;
    } else if (mobile) {
      slide = .2 * side;
    } else {
      rise = motion.overlayTravel * 2;
    }
    // The page under this one gives way as the next is pushed over it.
    final giveWay = motion.reduced || _coveredByDialog
        ? 0.0
        : slides
        ? -side / 3
        : !mobile
        ? 0.0
        : -.06 * side;

    // Everything below is the same widget from one tick to the next, holding
    // the same animations: updating it is a handful of comparisons, and the
    // movement itself is paint.
    // The platform's slide is not faded: the page is a sheet moving over
    // the one under it, with its shadow while it moves.
    var fade = slides ? kAlwaysCompleteAnimation : animations.fade;
    Animation<double> progress = animations.progress;
    Animation<double>? pull;
    var edgeShadow = slides && !animation.isCompleted
        ? _edgeShadow(theme.brightness)
        : null;
    switch (_phase) {
      case _BackPhase.none:
        break;
      case _BackPhase.swipe:
        // Under the finger: the whole width, in step with the drag, and
        // fully there.
        fade = kAlwaysCompleteAnimation;
        progress = animation;
        slide = side;
        rise = 0;
        edgeShadow = _edgeShadow(theme.brightness);
      case _BackPhase.swipeFade:
        fade = _heldFade ?? fade;
        progress = _heldProgress ?? progress;
        slide = side;
        rise = 0;
      case _BackPhase.predictive:
        fade = kAlwaysCompleteAnimation;
        progress = kAlwaysCompleteAnimation;
        pull = _pull;
        edgeShadow = _edgeShadow(theme.brightness);
      case _BackPhase.committed:
        pull = _pull;
        edgeShadow = _edgeShadow(theme.brightness);
    }

    return _BackGestureDetector(
      route: this,
      swipe: _swipes,
      child: FadeTransition(
        opacity: fade,
        child: _PageShift(
          progress: progress,
          covered: animations.covered,
          slide: slide,
          rise: rise,
          giveWay: giveWay,
          pull: pull,
          // With the finger, away from the edge it came from.
          pullShift: _edge == SwipeEdge.left ? _pullShift : -_pullShift,
          pullRadius: theme.radii.xl3.topLeft.x,
          pullRim: theme.colorScheme.border,
          edgeShadow: edgeShadow,
          child: child,
        ),
      ),
    );
  }

  /// How far a predictive back gesture moves the page sideways at its end,
  /// and how much smaller it draws it.
  static const _pullShift = 8.0;
  static const _pullScale = .1;

  /// The shadow a page casts on the one under it while it is dragged away.
  static Color _edgeShadow(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0x66000000)
      : const Color(0x1F000000);
}

/// What a back gesture is doing to a [UnaPageRoute].
enum _BackPhase {
  /// Nothing: the ordinary transition.
  none,

  /// The page is under the finger, or settling after it was let go.
  swipe,

  /// Let go with reduced motion: the page fades where it was left.
  swipeFade,

  /// A predictive back gesture is pulling the page, or was cancelled and
  /// the page is returning.
  predictive,

  /// A predictive back gesture was committed and the page is leaving.
  committed,
}

/// A page for `Navigator.pages` and router packages that is shown through a
/// [UnaPageRoute]: the same transition and the same back gestures.
///
/// ```dart
/// Navigator(
///   pages: [
///     const UnaPage<void>(key: ValueKey('inbox'), child: Inbox()),
///     if (open != null)
///       UnaPage<void>(key: ValueKey(open), child: Thread(open)),
///   ],
///   onDidRemovePage: (page) => setState(() => open = null),
/// )
/// ```
///
/// With `go_router`, return one from a route's `pageBuilder`:
///
/// ```dart
/// GoRoute(
///   path: '/thread/:id',
///   pageBuilder: (context, state) => UnaPage<void>(
///     key: state.pageKey,
///     child: Thread(state.pathParameters['id']!),
///   ),
/// )
/// ```
class UnaPage<T> extends Page<T> {
  /// Creates a page that shows [child].
  const UnaPage({
    required this.child,
    this.fullscreenDialog = false,
    this.maintainState = true,
    this.backGesture,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.canPop,
    super.onPopInvoked,
  });

  /// The page's content.
  final Widget child;

  /// Whether the page is a full-screen dialog: it rises from below, cannot
  /// be taken back with a gesture, and an `AppBar` shows a close button
  /// rather than a back button.
  final bool fullscreenDialog;

  /// Whether the page is kept in memory while another covers it.
  final bool maintainState;

  /// Whether the page can be taken back with a gesture; see
  /// [UnaPageRoute.backGesture].
  final bool? backGesture;

  @override
  Route<T> createRoute(BuildContext context) => _PageBasedRoute<T>(this);
}

/// The route of a [UnaPage]. It reads everything from its page, which
/// the navigator replaces in place when the page list is rebuilt.
class _PageBasedRoute<T> extends UnaPageRoute<T> {
  _PageBasedRoute(UnaPage<T> page) : super(builder: _unused, settings: page);

  static Widget _unused(BuildContext context) =>
      throw StateError('A page-based route builds its page from the page.');

  UnaPage<T> get _page => settings as UnaPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  bool? get backGesture => _page.backGesture;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}

/// The animations of one [UnaPageRoute]'s transition.
class _PageAnimations {
  _PageAnimations(
    this._animation,
    this._secondaryAnimation, {
    required Curve enter,
    required Curve giveWay,
  }) : _enter = enter,
       _giveWay = giveWay,
       progress = EntranceProgress(_animation, curve: enter),
       covered = _secondaryAnimation.drive(CurveTween(curve: giveWay));

  final Animation<double> _animation;
  final Animation<double> _secondaryAnimation;
  final Curve _enter;
  final Curve _giveWay;

  /// How far the page is into place: 0 where it comes from, 1 at rest.
  final EntranceProgress progress;

  /// How far the route above has come over this page.
  final Animation<double> covered;

  /// The page is readable well before it has settled.
  late final Animation<double> fade = progress.drive(const _FadeInBy(.6));

  /// Whether these were made for the given animations and curves.
  bool isFor(
    Animation<double> animation,
    Animation<double> secondaryAnimation, {
    required Curve enter,
    required Curve giveWay,
  }) =>
      identical(animation, _animation) &&
      identical(secondaryAnimation, _secondaryAnimation) &&
      enter == _enter &&
      giveWay == _giveWay;
}

/// A fade that is finished by [end] of the way: the page is readable well
/// before it has settled.
class _FadeInBy extends Animatable<double> {
  const _FadeInBy(this.end);

  final double end;

  @override
  double transform(double t) => end <= 0 ? 1 : (t / end).clamp(0.0, 1.0);
}

/// Listens for the gestures that take a [UnaPageRoute] back: a drag
/// from the start edge, and the system's predictive back.
///
/// It is the outermost widget of the transition, so the strip that catches
/// the drag stays at the edge of the screen while the page moves.
class _BackGestureDetector extends StatefulWidget {
  const _BackGestureDetector({
    required this.route,
    required this.swipe,
    required this.child,
  });

  final UnaPageRoute<dynamic> route;

  /// Whether a drag from the start edge is listened for.
  final bool swipe;

  final Widget child;

  @override
  State<_BackGestureDetector> createState() => _BackGestureDetectorState();
}

class _BackGestureDetectorState extends State<_BackGestureDetector>
    with WidgetsBindingObserver {
  /// How wide the strip along the start edge is that starts a swipe.
  static const _edgeWidth = 20.0;

  HorizontalDragGestureRecognizer? _recognizer;

  /// The scaffold around this page's navigator, whose drawer would
  /// otherwise take the start edge: a shell's route never pops, so it
  /// cannot tell from its own route that the edge is the way back here.
  BackEdgeClaims? _edgeClaims;

  bool _claimsEdge() =>
      mounted &&
      widget.swipe &&
      widget.route.isCurrent &&
      widget.route.popGestureEnabled &&
      _onTop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final claims = BackEdgeScope.maybeOf(context);
    if (identical(claims, _edgeClaims)) return;
    _edgeClaims?.remove(_claimsEdge);
    _edgeClaims = claims?..add(_claimsEdge);
  }

  @override
  void dispose() {
    _edgeClaims?.remove(_claimsEdge);
    WidgetsBinding.instance.removeObserver(this);
    _recognizer?.dispose();
    // The navigator may not be told while the tree is being torn down.
    final route = widget.route;
    if (route._phase == _BackPhase.swipe) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => route._swipeAbandoned(),
      );
    }
    super.dispose();
  }

  // The system's predictive back gesture. Every page listens; the one on
  // top that can go back answers. Every observer that answers is told the
  // rest of the gesture, so a page that is current only in its own
  // navigator must not: under a dialog on the root navigator, or in a tab
  // an `IndexedStack` is not showing.

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (!_onTop) return false;
    return widget.route._predictiveStart(backEvent);
  }

  // The transitions are built around the page, outside the route's
  // subtree, so the route is looked for from the page.
  bool get _onTop =>
      mounted &&
      isShownOnTop(
        context,
        routeContext: widget.route.subtreeContext ?? context,
      );

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) =>
      widget.route._predictiveUpdate(backEvent);

  @override
  void handleCommitBackGesture() => widget.route._predictiveEnd(commit: true);

  @override
  void handleCancelBackGesture() => widget.route._predictiveEnd(commit: false);

  // The swipe from the start edge.

  double get _towardsLeaving =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  double get _width => math.max(context.size?.width ?? 1, 1);

  void _handlePointerDown(PointerDownEvent event) {
    final route = widget.route;
    if (!route.isCurrent || !route.popGestureEnabled) return;
    final recognizer = _recognizer ??=
        HorizontalDragGestureRecognizer(
            debugOwner: this,
            // A finger or a pen; on a Mac the mouse too, as Material's
            // route there takes it. Elsewhere a mouse drags to select, and
            // a trackpad swipe is the system's.
            supportedDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
              if (defaultTargetPlatform == TargetPlatform.macOS)
                PointerDeviceKind.mouse,
            },
          )
          ..onStart = ((_) => widget.route._swipeStart())
          ..onUpdate = _handleUpdate
          ..onEnd = _handleEnd
          ..onCancel = (() => widget.route._swipeEnd(0));
    recognizer.addPointer(event);
  }

  void _handleUpdate(DragUpdateDetails details) {
    widget.route._swipeBy(
      _towardsLeaving * (details.primaryDelta ?? 0) / _width,
    );
  }

  void _handleEnd(DragEndDetails details) {
    widget.route._swipeEnd(
      _towardsLeaving * details.velocity.pixelsPerSecond.dx / _width,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.swipe) {
      return Stack(fit: StackFit.passthrough, children: [widget.child]);
    }
    final padding = MediaQuery.paddingOf(context);
    final inset = Directionality.of(context) == TextDirection.rtl
        ? padding.right
        : padding.left;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          // Past a notch, in landscape.
          width: math.max(inset, _edgeWidth),
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

/// Moves a page along its route's transition, in paint.
///
/// While [progress] runs from 0 to 1 the page comes in from [slide] of its
/// own width to the side and [rise] logical pixels below; while [covered]
/// runs from 0 to 1 it moves [giveWay] of its width aside for the page
/// pushed over it. While [pull] runs from 0 to 1 — a predictive back
/// gesture — it is drawn a little smaller, with rounded corners, [pullShift]
/// to the side. With an [edgeShadow] it casts one on what is under it while
/// it is away from its place.
///
/// A render object rather than an `AnimatedBuilder` around a `Transform`
/// inside a `LayoutBuilder`: the distance is a share of the page's width,
/// which is known at paint, so a tick costs no build and no layout.
class _PageShift extends SingleChildRenderObjectWidget {
  const _PageShift({
    required this.progress,
    required this.covered,
    required this.slide,
    required this.rise,
    required this.giveWay,
    required this.pull,
    required this.pullShift,
    required this.pullRadius,
    required this.pullRim,
    required this.edgeShadow,
    super.child,
  });

  final Animation<double> progress;
  final Animation<double> covered;
  final double slide;
  final double rise;
  final double giveWay;
  final Animation<double>? pull;
  final double pullShift;
  final double pullRadius;
  final Color pullRim;
  final Color? edgeShadow;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPageShift(
    progress: progress,
    covered: covered,
    slide: slide,
    rise: rise,
    giveWay: giveWay,
    pull: pull,
    pullShift: pullShift,
    pullRadius: pullRadius,
    pullRim: pullRim,
    edgeShadow: edgeShadow,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPageShift renderObject,
  ) {
    renderObject
      ..progress = progress
      ..covered = covered
      ..slide = slide
      ..rise = rise
      ..giveWay = giveWay
      ..pull = pull
      ..pullShift = pullShift
      ..pullRadius = pullRadius
      ..pullRim = pullRim
      ..edgeShadow = edgeShadow;
  }
}

class _RenderPageShift extends RenderProxyBox {
  _RenderPageShift({
    required Animation<double> progress,
    required Animation<double> covered,
    required double slide,
    required double rise,
    required double giveWay,
    required Animation<double>? pull,
    required double pullShift,
    required double pullRadius,
    required Color pullRim,
    required Color? edgeShadow,
  }) : _progress = progress,
       _covered = covered,
       _slide = slide,
       _rise = rise,
       _giveWay = giveWay,
       _pull = pull,
       _pullShift = pullShift,
       _pullRadius = pullRadius,
       _pullRim = pullRim,
       _edgeShadow = edgeShadow;

  /// How wide the shadow of a dragged page is.
  static const _shadowWidth = 24.0;

  Animation<double> get progress => _progress;
  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (identical(value, _progress)) return;
    if (attached) {
      _progress.removeListener(_moved);
      value.addListener(_moved);
    }
    _progress = value;
    _moved();
  }

  Animation<double> get covered => _covered;
  Animation<double> _covered;
  set covered(Animation<double> value) {
    if (identical(value, _covered)) return;
    if (attached) {
      _covered.removeListener(_moved);
      value.addListener(_moved);
    }
    _covered = value;
    _moved();
  }

  Animation<double>? get pull => _pull;
  Animation<double>? _pull;
  set pull(Animation<double>? value) {
    if (identical(value, _pull)) return;
    if (attached) {
      _pull?.removeListener(_moved);
      value?.addListener(_moved);
    }
    _pull = value;
    _moved();
  }

  double get slide => _slide;
  double _slide;
  set slide(double value) {
    if (value == _slide) return;
    _slide = value;
    _moved();
  }

  double get rise => _rise;
  double _rise;
  set rise(double value) {
    if (value == _rise) return;
    _rise = value;
    _moved();
  }

  double get giveWay => _giveWay;
  double _giveWay;
  set giveWay(double value) {
    if (value == _giveWay) return;
    _giveWay = value;
    _moved();
  }

  double get pullShift => _pullShift;
  double _pullShift;
  set pullShift(double value) {
    if (value == _pullShift) return;
    _pullShift = value;
    _moved();
  }

  double get pullRadius => _pullRadius;
  double _pullRadius;
  set pullRadius(double value) {
    if (value == _pullRadius) return;
    _pullRadius = value;
    _moved();
  }

  Color get pullRim => _pullRim;
  Color _pullRim;
  set pullRim(Color value) {
    if (value == _pullRim) return;
    _pullRim = value;
    if (_pulled > 0) markNeedsPaint();
  }

  Color? get edgeShadow => _edgeShadow;
  Color? _edgeShadow;
  set edgeShadow(Color? value) {
    if (value == _edgeShadow) return;
    _edgeShadow = value;
    markNeedsPaint();
  }

  /// Where the page is painted, relative to where it is laid out.
  Offset get _shift {
    final away = 1 - _progress.value;
    return Offset(
      (_slide * away + _giveWay * _covered.value) * size.width,
      _rise * away,
    );
  }

  /// How far a predictive back gesture has pulled the page.
  double get _pulled => (_pull?.value ?? 0).clamp(0.0, 1.0);

  /// The whole of what paint does to the page: the shift and, pulled, the
  /// shrinking about its centre.
  Matrix4 get _transform {
    final shift = _shift;
    final pulled = _pulled;
    final matrix = Matrix4.translationValues(shift.dx, shift.dy, 0);
    if (pulled <= 0) return matrix;
    final scale = 1 - UnaPageRoute._pullScale * pulled;
    final centre = size.center(Offset.zero);
    return matrix
      ..translateByDouble(
        centre.dx + _pullShift * pulled,
        centre.dy,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
  }

  /// What was last painted, to tell a tick that moves the page from one
  /// that does not: a page on a desktop does not give way, yet the
  /// animation of the route over it still runs.
  Offset? _painted;
  double _paintedPull = 0;

  void _moved() {
    if (hasSize && _shift == _painted && _pulled == _paintedPull) return;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(_moved);
    _covered.addListener(_moved);
    _pull?.addListener(_moved);
  }

  @override
  void detach() {
    _progress.removeListener(_moved);
    _covered.removeListener(_moved);
    _pull?.removeListener(_moved);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shift = _painted = _shift;
    final pulled = _paintedPull = _pulled;
    if (pulled <= 0) {
      layer = null;
      _paintEdgeShadow(context.canvas, offset + shift);
      super.paint(context, offset + shift);
      return;
    }
    final radius = Radius.circular(_pullRadius * pulled);
    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(bounds, radius);
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) {
        // Lifted off the page under it: a soft shadow around the sheet,
        // and a rim that still tells the two apart where both are dark.
        final shadow = _edgeShadow;
        if (shadow != null) {
          context.canvas.drawRRect(
            shape.shift(offset + const Offset(0, 8)),
            Paint()
              ..color = shadow.withValues(alpha: shadow.a * pulled)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
          );
        }
        context.pushClipRRect(
          needsCompositing,
          offset,
          bounds,
          shape,
          super.paint,
        );
        context.canvas.drawRRect(
          shape.shift(offset).deflate(.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = _pullRim.withValues(alpha: _pullRim.a * pulled),
        );
      },
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  /// A soft shadow along the edge the page is dragged away from, falling
  /// on the page under it.
  void _paintEdgeShadow(Canvas canvas, Offset origin) {
    final color = _edgeShadow;
    final away = 1 - _progress.value;
    if (color == null || _slide == 0 || away <= 0) return;
    // It is gone by the time the page is back in place.
    final strength = (away * 12).clamp(0.0, 1.0);
    final near = color.withValues(alpha: color.a * strength);
    final far = color.withValues(alpha: 0);
    // The page moves towards the side `slide` points to and uncovers the
    // other one.
    final edge = _slide > 0 ? origin.dx : origin.dx + size.width;
    final outer = _slide > 0 ? edge - _shadowWidth : edge + _shadowWidth;
    final rect = Rect.fromLTRB(
      math.min(edge, outer),
      origin.dy,
      math.max(edge, outer),
      origin.dy + size.height,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(edge, 0),
          Offset(outer, 0),
          [near, far],
        ),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_pulled <= 0) {
      return result.addWithPaintOffset(
        offset: _shift,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );
    }
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}

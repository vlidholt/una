import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';

/// Going back with a gesture: the swipe from the start edge that iOS has,
/// Android's predictive back, and [UnaPage], which gives both to a
/// declared page.
const _frame = Duration(milliseconds: 16);
const _size = Size(390, 844);

final _navigator = GlobalKey<NavigatorState>();

const _page = Key('page');
const _home = Key('home');

Widget _app({
  bool reduceMotion = false,
  Motion? motion,
  TextDirection textDirection = TextDirection.ltr,
  FormFactor formFactor = FormFactor.mobile,
}) {
  return UnaApp(
    navigatorKey: _navigator,
    theme: ThemeData(motion: motion),
    formFactor: formFactor,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Directionality(textDirection: textDirection, child: child!),
    ),
    home: const SizedBox.expand(key: _home),
  );
}

Future<void> _push(
  WidgetTester tester, {
  bool fullscreenDialog = false,
  bool? backGesture,
  Widget child = const SizedBox.expand(key: _page),
}) async {
  _navigator.currentState!.push(
    UnaPageRoute<void>(
      fullscreenDialog: fullscreenDialog,
      backGesture: backGesture,
      builder: (context) => child,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Where the route above [finder] paints its top left corner, how wide it
/// paints it, and how opaque.
({Offset offset, double width, double opacity}) _painted(
  WidgetTester tester,
  Finder finder,
) {
  var opacity = 1.0;
  final box = tester.renderObject<RenderBox>(finder);
  RenderObject? node = box;
  while (node != null) {
    if (node is RenderAnimatedOpacity) opacity *= node.opacity.value;
    node = node.parent;
  }
  final transform = box.getTransformTo(null);
  final topLeft = MatrixUtils.transformPoint(transform, Offset.zero);
  final topRight = MatrixUtils.transformPoint(
    transform,
    Offset(box.size.width, 0),
  );
  return (
    offset: topLeft,
    width: topRight.dx - topLeft.dx,
    opacity: opacity,
  );
}

void _expectMonotone(List<double> values, {required String reason}) {
  final rising = values.last >= values.first;
  for (var i = 1; i < values.length; i++) {
    final step = values[i] - values[i - 1];
    expect(
      rising ? step >= -1e-6 : step <= 1e-6,
      isTrue,
      reason: '$reason turned back at frame $i: $values',
    );
  }
}

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _size;
  addTearDown(tester.view.reset);
}

/// Sends the engine's predictive back messages, as Android does.
Future<void> _backGesture(
  WidgetTester tester,
  String method, [
  double progress = 0,
  int swipeEdge = 0,
]) async {
  final arguments = switch (method) {
    'startBackGesture' || 'updateBackGestureProgress' => <String, Object?>{
      'touchOffset': <double>[5, 300],
      'progress': progress,
      'swipeEdge': swipeEdge,
    },
    _ => null,
  };
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(method, arguments),
    ),
    (_) {},
  );
  await tester.pump();
}

void main() {
  group('the swipe from the start edge', () {
    testWidgets('follows the finger, pops past the middle and settles '
        'without turning back', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      await tester.pumpWidget(_app());
      await _push(tester);
      expect(_navigator.currentState!.userGestureInProgress, isFalse);

      final gesture = await tester.startGesture(const Offset(4, 400));
      // Past the slop; from here on the page is under the finger.
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(_navigator.currentState!.userGestureInProgress, isTrue);
      final start = _painted(tester, find.byKey(_page)).offset.dx;
      var moved = 0.0;
      final under = <double>[];
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump(_frame);
        moved += 20;
        final now = _painted(tester, find.byKey(_page));
        // The whole distance, with no fade and no easing.
        expect(now.offset.dx, moreOrLessEquals(start + moved, epsilon: .01));
        expect(now.offset.dy, 0);
        expect(now.opacity, 1);
        under.add(_painted(tester, find.byKey(_home)).offset.dx);
      }
      // The page under it comes back from where it gave way to.
      expect(under.first, lessThan(0));
      _expectMonotone(under, reason: 'the page under');
      expect(under.last, greaterThan(under.first));

      // Past the middle of 390.
      expect(_painted(tester, find.byKey(_page)).offset.dx, greaterThan(195));
      await gesture.up();
      final leaving = <double>[];
      var frames = 0;
      while (find.byKey(_page).evaluate().isNotEmpty && frames < 120) {
        leaving.add(_painted(tester, find.byKey(_page)).offset.dx);
        await tester.pump(_frame);
        frames++;
      }
      expect(find.byKey(_page), findsNothing);
      _expectMonotone(leaving, reason: 'leaving');
      expect(leaving.last, greaterThan(350));
      await tester.pumpAndSettle();
      expect(_navigator.currentState!.userGestureInProgress, isFalse);
      expect(_painted(tester, find.byKey(_home)).offset, Offset.zero);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('springs back when let go before the middle', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      await tester.pumpWidget(_app());
      await _push(tester);
      final gesture = await tester.startGesture(const Offset(4, 400));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      // Held still, then let go: no fling.
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      final returning = <double>[];
      for (var i = 0; i < 60; i++) {
        returning.add(_painted(tester, find.byKey(_page)).offset.dx);
        await tester.pump(_frame);
      }
      _expectMonotone(returning, reason: 'returning');
      expect(returning.first, greaterThan(90));
      expect(returning.last, 0);
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsOneWidget);
      expect(_navigator.currentState!.userGestureInProgress, isFalse);
      // And it is the ordinary transition again: on iOS the platform's
      // push, a slide with no fade.
      _navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final leaving = _painted(tester, find.byKey(_page));
      expect(leaving.opacity, 1);
      expect(leaving.offset.dx, greaterThan(0));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a flick pops from anywhere, and a flick the other way '
        'keeps the page', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      await tester.pumpWidget(_app());
      await _push(tester);
      // 60 points in 60 ms: about 2.5 widths a second.
      await tester.flingFrom(
        const Offset(4, 400),
        const Offset(80, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsNothing);

      await _push(tester);
      final gesture = await tester.startGesture(const Offset(4, 400));
      await gesture.moveBy(const Offset(30, 0));
      // Well past the middle, then thrown back.
      await gesture.moveBy(
        const Offset(300, 0),
        timeStamp: const Duration(milliseconds: 100),
      );
      for (var i = 1; i <= 6; i++) {
        await gesture.moveBy(
          const Offset(-15, 0),
          timeStamp: Duration(milliseconds: 100 + i * 10),
        );
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 160));
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsOneWidget);
      expect(_painted(tester, find.byKey(_page)).offset, Offset.zero);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('starts at the right edge in a right-to-left layout', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      await tester.pumpWidget(_app(textDirection: TextDirection.rtl));
      await _push(tester);
      // The left edge is not the start edge here.
      await tester.dragFrom(const Offset(4, 400), const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(386, 400));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      expect(
        _painted(tester, find.byKey(_page)).offset.dx,
        moreOrLessEquals(-200, epsilon: .01),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('is offered only where a page can go back', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 300));

      Future<void> swipe({Offset from = const Offset(4, 400)}) async {
        await tester.dragFrom(from, const Offset(250, 0));
        await tester.pumpAndSettle();
      }

      // The first page of a navigator has nowhere to go.
      await swipe();
      expect(find.byKey(_home), findsOneWidget);

      // A drag that starts inside the page is the page's.
      await _push(tester);
      await swipe(from: const Offset(60, 400));
      expect(find.byKey(_page), findsOneWidget);
      // A mouse drags to select.
      final mouse = await tester.startGesture(
        const Offset(4, 400),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(250, 0));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsOneWidget);
      await swipe();
      expect(find.byKey(_page), findsNothing);

      // A dialog is closed, not swiped away.
      await _push(tester, fullscreenDialog: true);
      await swipe();
      expect(find.byKey(_page), findsOneWidget);
      _navigator.currentState!.pop();
      await tester.pumpAndSettle();

      // A page that vetoes its pop is not dragged about.
      await _push(
        tester,
        child: const PopScope<void>(
          canPop: false,
          child: SizedBox.expand(key: _page),
        ),
      );
      await swipe();
      expect(find.byKey(_page), findsOneWidget);
      expect(_painted(tester, find.byKey(_page)).offset, Offset.zero);
      _navigator.currentState!.pop();
      await tester.pumpAndSettle();

      // Switched off for one route.
      await _push(tester, backGesture: false);
      await swipe();
      expect(find.byKey(_page), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('follows the platform: off away from iOS and macOS unless '
        'asked for', (tester) async {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        _phone(tester);
        await tester.pumpWidget(_app());
        await tester.pump(const Duration(milliseconds: 300));
        await _push(tester);
        await tester.dragFrom(const Offset(4, 400), const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(find.byKey(_page), findsOneWidget, reason: '$platform');
        _navigator.currentState!.pop();
        await tester.pumpAndSettle();

        await _push(tester, backGesture: true);
        await tester.dragFrom(const Offset(4, 400), const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(find.byKey(_page), findsNothing, reason: '$platform');
        await tester.pumpWidget(const SizedBox.shrink());
      }
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets("on iOS a push is the platform's: the page slides the whole "
        'width, unfaded, and the one under it moves a third out of its way', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        _phone(tester);
        await tester.pumpWidget(_app());
        await tester.pump(const Duration(milliseconds: 300));
        _navigator.currentState!.push(
          UnaPageRoute<void>(
            builder: (_) => const SizedBox.expand(key: _page),
          ),
        );
        await tester.pump();
        await tester.pump(_frame);
        await tester.pump(_frame);
        final arriving = _painted(tester, find.byKey(_page));
        expect(arriving.opacity, 1);
        expect(arriving.offset.dx, greaterThan(195));
        // Most of the way in, the page under it is well on its way out.
        for (var i = 0; i < 8; i++) {
          await tester.pump(_frame);
        }
        final home = _painted(tester, find.byKey(_home, skipOffstage: false));
        expect(home.offset.dx, lessThan(-40));
        expect(home.offset.dx, greaterThanOrEqualTo(-390 / 3 - 1));
        await tester.pumpAndSettle();
        expect(_painted(tester, find.byKey(_page)).offset.dx, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('on macOS the edge swipe is on, for the mouse too, as '
        "Material's route there has it", (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        _phone(tester);
        await tester.pumpWidget(_app());
        await tester.pump(const Duration(milliseconds: 300));
        await _push(tester);
        final mouse = await tester.startGesture(
          const Offset(4, 400),
          kind: PointerDeviceKind.mouse,
        );
        for (var i = 0; i < 10; i++) {
          await mouse.moveBy(const Offset(30, 0));
          await tester.pump(_frame);
        }
        await mouse.up();
        await tester.pumpAndSettle();
        expect(find.byKey(_page), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('with reduced motion it still follows the finger, then '
        'fades where it was let go', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      await tester.pumpWidget(_app(reduceMotion: true));
      await tester.pump(const Duration(milliseconds: 300));
      await _push(tester);
      final gesture = await tester.startGesture(const Offset(4, 400));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(240, 0));
      await tester.pump();
      final held = _painted(tester, find.byKey(_page));
      expect(held.offset.dx, moreOrLessEquals(240, epsilon: .01));
      expect(held.opacity, 1);
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      final opacity = <double>[];
      var frames = 0;
      while (find.byKey(_page).evaluate().isNotEmpty && frames < 60) {
        final now = _painted(tester, find.byKey(_page));
        // It does not travel any further.
        expect(now.offset.dx, moreOrLessEquals(240, epsilon: .01));
        opacity.add(now.opacity);
        await tester.pump(_frame);
        frames++;
      }
      expect(find.byKey(_page), findsNothing);
      _expectMonotone(opacity, reason: 'fading');
      expect(opacity.where((o) => o > 0 && o < 1), isNotEmpty);
      await tester.pumpAndSettle();
      expect(_navigator.currentState!.userGestureInProgress, isFalse);

      // Let go early, it goes back.
      await _push(tester);
      await tester.dragFrom(const Offset(4, 400), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsOneWidget);
      expect(_painted(tester, find.byKey(_page)).offset, Offset.zero);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('with no motion it is there or gone at once', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      await tester.pumpWidget(_app(motion: Motion.none));
      await tester.pump(const Duration(milliseconds: 300));
      await _push(tester);
      final gesture = await tester.startGesture(const Offset(4, 400));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      expect(_painted(tester, find.byKey(_page)).offset, Offset.zero);
      expect(_navigator.currentState!.userGestureInProgress, isFalse);

      final again = await tester.startGesture(const Offset(4, 400));
      await again.moveBy(const Offset(30, 0));
      await again.moveBy(const Offset(240, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await again.up();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_page), findsNothing);
      expect(_navigator.currentState!.userGestureInProgress, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a horizontal scrollable inside the page still scrolls '
        'from anywhere but the edge', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      await tester.pumpWidget(_app());
      final scroll = ScrollController(initialScrollOffset: 200);
      addTearDown(scroll.dispose);
      await _push(
        tester,
        child: ListView(
          key: _page,
          controller: scroll,
          scrollDirection: Axis.horizontal,
          children: const [SizedBox(width: 2000)],
        ),
      );
      await tester.dragFrom(const Offset(200, 400), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(scroll.offset, lessThan(200));
      expect(find.byKey(_page), findsOneWidget);
      expect(_painted(tester, find.byKey(_page)).offset, Offset.zero);
      // From the edge the page goes back, and the list stays where it is.
      final before = scroll.offset;
      final gesture = await tester.startGesture(const Offset(4, 400));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      expect(scroll.offset, before);
      expect(_painted(tester, find.byKey(_page)).offset.dx, greaterThan(90));
      await gesture.up();
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a drag is drawn without setting the transition up again', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      await tester.pumpWidget(_app());
      await _push(tester);
      RenderAnimatedOpacity fade() => tester.renderObject(
        find
            .ancestor(
              of: find.byKey(_page),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      final gesture = await tester.startGesture(const Offset(4, 400));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      final during = fade().opacity;
      final shift = tester.renderObject(
        find.ancestor(
          of: find.byKey(_page),
          matching: find.byWidgetPredicate(
            (w) => '${w.runtimeType}' == '_PageShift',
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(_frame);
        // The same animation and the same render object from one frame of
        // the drag to the next; only its paint moves.
        expect(fade().opacity, same(during));
        expect(shift.debugNeedsLayout, isFalse);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('predictive back', () {
    testWidgets('draws the page smaller with rounded corners while the '
        'gesture is held, and commits to the ordinary exit', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await _push(tester);
      await _backGesture(tester, 'startBackGesture');
      expect(_navigator.currentState!.userGestureInProgress, isTrue);
      final width = <double>[];
      for (var i = 1; i <= 10; i++) {
        await _backGesture(tester, 'updateBackGestureProgress', i / 10);
        final now = _painted(tester, find.byKey(_page));
        expect(now.opacity, 1);
        width.add(now.width);
      }
      _expectMonotone(width, reason: 'the pull');
      // A tenth smaller at the end of the pull, moved with the finger.
      expect(width.last, moreOrLessEquals(390 * .9, epsilon: .01));
      final pulled = _painted(tester, find.byKey(_page));
      expect(pulled.offset.dx, moreOrLessEquals(390 * .05 + 8, epsilon: .01));
      expect(pulled.offset.dy, moreOrLessEquals(844 * .05, epsilon: .01));
      // The corners are rounded by a clip.
      expect(
        tester.layers.whereType<ClipRRectLayer>().single.clipRRect!.tlRadiusX,
        greaterThan(8),
      );

      // The page under it waits where it is.
      final under = _painted(tester, find.byKey(_home)).offset;
      expect(under.dx, lessThan(0));

      await _backGesture(tester, 'commitBackGesture');
      expect(_painted(tester, find.byKey(_home)).offset, under);
      final opacity = <double>[];
      var frames = 0;
      while (find.byKey(_page).evaluate().isNotEmpty && frames < 60) {
        final now = _painted(tester, find.byKey(_page));
        // It keeps its size while it goes.
        expect(now.width, moreOrLessEquals(390 * .9, epsilon: .01));
        opacity.add(now.opacity);
        await tester.pump(_frame);
        frames++;
      }
      expect(find.byKey(_page), findsNothing);
      _expectMonotone(opacity, reason: 'leaving');
      expect(opacity.where((o) => o > 0 && o < 1), isNotEmpty);
      await tester.pumpAndSettle();
      expect(_navigator.currentState!.userGestureInProgress, isFalse);
      expect(_painted(tester, find.byKey(_home)).offset, Offset.zero);
    });

    testWidgets('cancelled, the page goes back to its place', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await _push(tester);
      // From the right edge the page moves to the left.
      await _backGesture(tester, 'startBackGesture', 0, 1);
      await _backGesture(tester, 'updateBackGestureProgress', .6, 1);
      final pulled = _painted(tester, find.byKey(_page));
      expect(pulled.width, moreOrLessEquals(390 * .94, epsilon: .01));
      expect(
        pulled.offset.dx,
        moreOrLessEquals(390 * .03 - 8 * .6, epsilon: .01),
      );
      await _backGesture(tester, 'cancelBackGesture');
      final width = <double>[];
      for (var i = 0; i < 30; i++) {
        width.add(_painted(tester, find.byKey(_page)).width);
        await tester.pump(_frame);
      }
      _expectMonotone(width, reason: 'returning');
      expect(width.last, 390);
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsOneWidget);
      expect(_painted(tester, find.byKey(_page)).offset, Offset.zero);
      expect(_navigator.currentState!.userGestureInProgress, isFalse);
      expect(tester.layers.whereType<ClipRRectLayer>(), isEmpty);
    });

    testWidgets('is left to the system for a dialog, a first page and a '
        'route that opts out', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 300));
      await _backGesture(tester, 'startBackGesture');
      expect(_navigator.currentState!.userGestureInProgress, isFalse);
      await _backGesture(tester, 'cancelBackGesture');

      await _push(tester, fullscreenDialog: true);
      await _backGesture(tester, 'startBackGesture');
      await _backGesture(tester, 'updateBackGestureProgress', .5);
      expect(_navigator.currentState!.userGestureInProgress, isFalse);
      expect(_painted(tester, find.byKey(_page)).width, 390);
      // Committed, the system's back pops it the ordinary way.
      await _backGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsNothing);

      await _push(tester, backGesture: false);
      await _backGesture(tester, 'startBackGesture');
      await _backGesture(tester, 'updateBackGestureProgress', .5);
      expect(_painted(tester, find.byKey(_page)).width, 390);
      await _backGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsOneWidget);
    });

    testWidgets('closes a dialog on the root navigator, not the page under '
        'it in a nested one', (tester) async {
      _phone(tester);
      final nested = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        UnaApp(
          navigatorKey: _navigator,
          home: Navigator(
            key: nested,
            onGenerateRoute: (_) => UnaPageRoute<void>(
              builder: (_) => const SizedBox.expand(key: _home),
            ),
          ),
        ),
      );
      nested.currentState!.push(
        UnaPageRoute<void>(
          builder: (_) => const SizedBox.expand(key: _page),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: nested.currentContext!,
          builder: (_) => const SizedBox.square(
            dimension: 100,
            key: Key('dialog'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _backGesture(tester, 'startBackGesture');
      await _backGesture(tester, 'updateBackGestureProgress', .5);
      expect(nested.currentState!.userGestureInProgress, isFalse);
      expect(_painted(tester, find.byKey(_page)).width, 390);
      await _backGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dialog')), findsNothing);
      expect(find.byKey(_page), findsOneWidget);
    });

    testWidgets('is not answered by a page in a tab that is not shown', (
      tester,
    ) async {
      _phone(tester);
      final tabs = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];
      await tester.pumpWidget(
        UnaApp(
          home: IndexedStack(
            index: 1,
            children: [
              for (final tab in tabs)
                Navigator(
                  key: tab,
                  onGenerateRoute: (_) => UnaPageRoute<void>(
                    builder: (_) => const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      );
      for (final (i, tab) in tabs.indexed) {
        tab.currentState!.push(
          UnaPageRoute<void>(
            builder: (_) => SizedBox.expand(key: Key('page $i')),
          ),
        );
      }
      await tester.pumpAndSettle();

      await _backGesture(tester, 'startBackGesture');
      await _backGesture(tester, 'updateBackGestureProgress', .5);
      expect(tabs[0].currentState!.userGestureInProgress, isFalse);
      expect(tabs[1].currentState!.userGestureInProgress, isTrue);
      await _backGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('page 0'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const Key('page 1')), findsNothing);
    });
  });

  group('UnaPage', () {
    testWidgets('shows a declared page through the same route, follows the '
        'page list and reports a swipe back', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _phone(tester);
      var open = false;
      var label = 'one';
      late StateSetter rebuild;
      await tester.pumpWidget(
        UnaApp.custom(
          appBuilder: (context) => Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: _size),
              child: Theme(
                data: ThemeData().withFormFactor(FormFactor.mobile),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return Navigator(
                      pages: [
                        const UnaPage<void>(
                          key: ValueKey('home'),
                          child: SizedBox.expand(key: _home),
                        ),
                        if (open)
                          UnaPage<void>(
                            key: const ValueKey('detail'),
                            name: 'detail',
                            child: SizedBox.expand(
                              key: _page,
                              child: Text(label),
                            ),
                          ),
                      ],
                      onDidRemovePage: (page) => rebuild(() => open = false),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(_home), findsOneWidget);

      rebuild(() => open = true);
      await tester.pump();
      await tester.pump(_frame);
      await tester.pump(_frame);
      // Arriving from the end side, as a pushed route does: on iOS the
      // platform's slide, not faded.
      final arriving = _painted(tester, find.byKey(_page));
      expect(arriving.offset.dx, greaterThan(0));
      expect(arriving.opacity, 1);
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.byKey(_page)))!;
      expect(route, isA<UnaPageRoute<void>>());
      expect(route.settings.name, 'detail');

      // The page is replaced in place: same route, new content.
      rebuild(() => label = 'two');
      await tester.pump();
      expect(find.text('two'), findsOneWidget);
      expect(ModalRoute.of(tester.element(find.byKey(_page))), same(route));

      await tester.dragFrom(const Offset(4, 400), const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(open, isFalse);
      expect(find.byKey(_page), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('carries fullscreenDialog, maintainState and backGesture to '
        'its route', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      const page = UnaPage<int>(
        fullscreenDialog: true,
        maintainState: false,
        backGesture: false,
        child: SizedBox(),
      );
      final route = page.createRoute(context) as UnaPageRoute<int>;
      expect(route.fullscreenDialog, isTrue);
      expect(route.maintainState, isFalse);
      expect(route.backGesture, isFalse);
      expect(route.settings, same(page));
      const plain = UnaPage<int>(child: SizedBox());
      final other = plain.createRoute(context) as UnaPageRoute<int>;
      expect(other.fullscreenDialog, isFalse);
      expect(other.maintainState, isTrue);
      expect(other.backGesture, isNull);
    });
  });

  testWidgets('a scrollable stretches at its ends on Android instead of '
      'glowing', (tester) async {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        UnaApp(
          home: ListView(children: const [SizedBox(height: 2000)]),
        ),
      );
      final stretches =
          platform == TargetPlatform.android ||
          platform == TargetPlatform.fuchsia;
      expect(
        find.byType(StretchingOverscrollIndicator),
        stretches ? findsOneWidget : findsNothing,
        reason: '$platform',
      );
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    debugDefaultTargetPlatformOverride = null;
  });
}

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';

/// The one toast system: a `Toaster` that stacks `Toast`s.
void main() {
  late BuildContext host;

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1000, 700),
    ThemeData? theme,
    TextDirection textDirection = TextDirection.ltr,
    double textScale = 1,
    EdgeInsets viewInsets = EdgeInsets.zero,
    bool reduceMotion = false,
    AlignmentGeometry? alignment,
    Widget? home,
  }) async {
    // The app's own toaster is the one a page finds, so where the stack
    // sits is set through the theme.
    final effectiveTheme = alignment == null
        ? theme
        : (theme ?? ThemeData()).copyWith(
            toasterTheme: ToasterTheme(alignment: alignment),
          );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UnaApp(
        theme: effectiveTheme,
        darkTheme: effectiveTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: viewInsets,
            disableAnimations: reduceMotion,
          ),
          child: Directionality(
            textDirection: textDirection,
            child: child!,
          ),
        ),
        home:
            home ??
            Builder(
              builder: (context) {
                host = context;
                return const SizedBox.expand();
              },
            ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Rect rectOf(WidgetTester tester, String title) => tester.getRect(
    find.ancestor(of: find.text(title), matching: find.byType(Toast)),
  );

  const stays = Duration.zero;

  group('showing', () {
    testWidgets('show returns what identifies the toast', (tester) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      final own = toaster.show(const Toast(title: Text('One')));
      final given = toaster.show(const Toast(id: 'two', title: Text('Two')));
      expect(own, isNotNull);
      expect(given, 'two');
      await settle(tester);
      expect(toaster.toasts.map((toast) => toast.id), [null, 'two']);
      unawaited(toaster.dismissAll());
      await settle(tester);
      expect(toaster.toasts, isEmpty);
      expect(find.byType(Toast), findsNothing);
    });

    testWidgets('shown during a build, a toast is found by its id at once', (
      tester,
    ) async {
      final shown = <String, Object>{};
      final updated = <String, bool>{};
      Widget shows(String name, {bool thenUpdate = false}) => _ShowsInBuild(
        onBuild: (toaster) {
          shown[name] = toaster.show(
            const Toast(id: 'offline', title: Text('Offline')),
          );
          if (thenUpdate) {
            updated[name] = toaster.update(
              'offline',
              const Toast(id: 'offline', title: Text('Back online')),
            );
          }
        },
      );
      await pumpApp(
        tester,
        home: Column(children: [shows('a'), shows('b', thenUpdate: true)]),
      );
      await settle(tester);
      // Two widgets showed one id in one build: one toast, updated.
      expect(find.text('Offline'), findsNothing);
      expect(find.text('Back online'), findsOneWidget);
      expect(shown, {'a': 'offline', 'b': 'offline'});
      expect(updated, {'b': true});
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
    });

    testWidgets('a toast dismissed in the build that showed it never shows', (
      tester,
    ) async {
      var done = false;
      await pumpApp(
        tester,
        home: _ShowsInBuild(
          onBuild: (toaster) {
            final id = toaster.show(const Toast(title: Text('Gone')));
            unawaited(toaster.dismiss(id).then((_) => done = true));
          },
        ),
      );
      await settle(tester);
      expect(find.text('Gone'), findsNothing);
      expect(done, isTrue);
    });

    testWidgets('a toast with the id of one on screen replaces it in place', (
      tester,
    ) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      toaster.show(const Toast(id: 'x', title: Text('Before')));
      await settle(tester);
      final where = rectOf(tester, 'Before');
      toaster.show(const Toast(id: 'x', title: Text('After')));
      await tester.pump();
      expect(find.text('Before'), findsNothing);
      expect(find.byType(Toast), findsOneWidget);
      expect(rectOf(tester, 'After'), where);
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
    });

    testWidgets('update turns a loading toast into its result, and says '
        'no for a toast that is not there', (tester) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      final id = toaster.show(
        const Toast(variant: ToastVariant.loading, title: Text('Uploading')),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(Spinner), findsOneWidget);
      // A loading toast stays.
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Uploading'), findsOneWidget);

      expect(
        toaster.update(
          id,
          const Toast(variant: ToastVariant.success, title: Text('Uploaded')),
        ),
        isTrue,
      );
      await tester.pump();
      expect(find.byType(Spinner), findsNothing);
      expect(find.text('Uploaded'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkCircle), findsOneWidget);
      // And now it has a result's time to live.
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(find.text('Uploaded'), findsNothing);

      expect(toaster.update(id, const Toast(title: Text('Late'))), isFalse);
      await tester.pump();
      expect(find.text('Late'), findsNothing);
    });

    testWidgets('each variant leads with its icon, in its colour; a leading '
        'widget replaces it', (tester) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      final theme = Theme.of(host);
      for (final (variant, icon, colour) in [
        (
          ToastVariant.success,
          PhosphorIconsFill.checkCircle,
          theme.toastTheme.successColor,
        ),
        (
          ToastVariant.warning,
          PhosphorIconsFill.warning,
          theme.toastTheme.warningColor,
        ),
        (
          ToastVariant.destructive,
          PhosphorIconsFill.xCircle,
          theme.toastTheme.destructiveColor,
        ),
      ]) {
        final id = toaster.show(
          Toast(variant: variant, title: const Text('T'), duration: stays),
        );
        await settle(tester);
        final found = find.byIcon(icon);
        expect(found, findsOneWidget, reason: '$variant');
        expect(IconTheme.of(tester.element(found)).color, colour);
        expect(
          IconTheme.of(tester.element(found)).size,
          theme.toastTheme.iconSize,
        );
        unawaited(toaster.dismiss(id));
        await settle(tester);
      }
      toaster.show(
        const Toast(
          variant: ToastVariant.success,
          leading: PhosphorIcon(PhosphorIconsRegular.heart),
          title: Text('T'),
          duration: stays,
        ),
      );
      await settle(tester);
      expect(find.byIcon(PhosphorIconsFill.checkCircle), findsNothing);
      expect(find.byIcon(PhosphorIconsRegular.heart), findsOneWidget);
      // A plain toast has none.
      unawaited(toaster.dismissAll());
      await settle(tester);
      toaster.show(const Toast(title: Text('Plain'), duration: stays));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(Toast),
          matching: find.bySubtype<Icon>(),
        ),
        findsNothing,
      );
    });

    testWidgets('Duration.zero keeps a toast; onDismissed is called once, '
        'however it leaves', (tester) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      var dismissed = 0;
      final id = toaster.show(
        Toast(
          title: const Text('Sticky'),
          duration: stays,
          onDismissed: () => dismissed++,
        ),
      );
      await tester.pump(const Duration(minutes: 5));
      expect(find.text('Sticky'), findsOneWidget);
      expect(dismissed, 0);
      unawaited(toaster.dismiss(id));
      unawaited(toaster.dismiss(id));
      await settle(tester);
      expect(dismissed, 1);

      toaster.show(
        Toast(
          title: const Text('Timed'),
          duration: const Duration(seconds: 1),
          onDismissed: () => dismissed++,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(dismissed, 2);
    });

    testWidgets('a page can show a toast while it is being built', (
      tester,
    ) async {
      await pumpApp(
        tester,
        home: Builder(
          builder: (context) {
            Toaster.of(
              context,
            ).show(const Toast(id: 'hello', title: Text('Welcome')));
            return const SizedBox.expand();
          },
        ),
      );
      expect(tester.takeException(), isNull);
      await settle(tester);
      expect(find.text('Welcome'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
    });

    testWidgets('Toaster.of explains itself when there is no toaster', (
      tester,
    ) async {
      late BuildContext bare;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            bare = context;
            return const SizedBox();
          },
        ),
      );
      expect(Toaster.maybeOf(bare), isNull);
      expect(
        () => Toaster.of(bare),
        throwsA(
          isA<FlutterError>().having(
            (error) => error.message,
            'message',
            contains('UnaAppBuilder'),
          ),
        ),
      );
    });
  });

  group('where it sits', () {
    testWidgets('a desktop: the bottom end corner, at the theme width', (
      tester,
    ) async {
      await pumpApp(tester);
      final theme = Theme.of(host);
      expect(theme.formFactor, FormFactor.desktop);
      Toaster.of(host).show(const Toast(title: Text('Hi'), duration: stays));
      await settle(tester);
      final rect = rectOf(tester, 'Hi');
      final padding = theme.toasterTheme.padding!
          .resolve(TextDirection.ltr)
          .right;
      expect(rect.width, theme.toasterTheme.width);
      expect(rect.right, moreOrLessEquals(1000 - padding));
      expect(rect.bottom, moreOrLessEquals(700 - padding));
    });

    testWidgets('right to left it is the other corner', (tester) async {
      await pumpApp(tester, textDirection: TextDirection.rtl);
      final theme = Theme.of(host);
      Toaster.of(host).show(const Toast(title: Text('Hi'), duration: stays));
      await settle(tester);
      final padding = theme.toasterTheme.padding!
          .resolve(TextDirection.rtl)
          .left;
      expect(rectOf(tester, 'Hi').left, moreOrLessEquals(padding));
    });

    testWidgets('a phone: across the bottom, the page less its margins, '
        'above the safe area and the keyboard', (tester) async {
      await pumpApp(
        tester,
        size: const Size(390, 800),
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      final theme = Theme.of(host);
      expect(theme.formFactor, FormFactor.mobile);
      Toaster.of(host).show(const Toast(title: Text('Hi'), duration: stays));
      await settle(tester);
      final rect = rectOf(tester, 'Hi');
      final padding = theme.toasterTheme.padding!.resolve(TextDirection.ltr);
      expect(rect.left, moreOrLessEquals(padding.left));
      expect(rect.right, moreOrLessEquals(390 - padding.right));
      expect(rect.bottom, moreOrLessEquals(800 - 300 - padding.bottom));
    });

    testWidgets('insets keep it clear of what a screen has put in the way, '
        'and it moves there without a jump', (tester) async {
      await pumpApp(tester, size: const Size(390, 800));
      final toaster = Toaster.of(host);
      toaster.show(const Toast(title: Text('Hi'), duration: stays));
      await settle(tester);
      final before = rectOf(tester, 'Hi').bottom;

      toaster.insets = const EdgeInsets.only(bottom: 88);
      expect(toaster.insets.bottom, 88);
      await tester.pump();
      var last = rectOf(tester, 'Hi').bottom;
      // Nothing has moved in the frame it was set in…
      expect(last, moreOrLessEquals(before, epsilon: 1));
      var moved = false;
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final now = rectOf(tester, 'Hi').bottom;
        // …and it only ever goes up, a little at a time.
        expect(now, lessThanOrEqualTo(last + .01));
        expect(last - now, lessThan(30));
        if (now < last) moved = true;
        last = now;
      }
      expect(moved, isTrue);
      expect(last, moreOrLessEquals(before - 88, epsilon: .1));

      toaster.insets = EdgeInsets.zero;
      await settle(tester);
      expect(rectOf(tester, 'Hi').bottom, moreOrLessEquals(before));
    });

    testWidgets('an alignment in the upper half stacks down from the top', (
      tester,
    ) async {
      await pumpApp(tester, alignment: Alignment.topCenter);
      final toaster = Toaster.of(host);
      toaster.show(const Toast(title: Text('One'), duration: stays));
      await settle(tester);
      toaster.show(const Toast(title: Text('Two'), duration: stays));
      await settle(tester);
      final one = rectOf(tester, 'One');
      final two = rectOf(tester, 'Two');
      expect(two.top, lessThan(100));
      expect(two.center.dx, moreOrLessEquals(500));
      // The older one shows under the newer one's bottom edge.
      expect(one.bottom, greaterThan(two.bottom));
    });

    testWidgets('twice the text size: nothing overflows and the toast grows', (
      tester,
    ) async {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpApp(tester, size: const Size(390, 800), textScale: scale);
        Toaster.of(host).show(
          Toast(
            variant: ToastVariant.success,
            title: const Text('Saved'),
            description: const Text('Your changes are safe'),
            duration: stays,
            action: Button.outline(
              size: ButtonSize.sm,
              onPressed: () {},
              child: const Text('Undo'),
            ),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'at $scale');
      }
    });
  });

  group('the stack', () {
    Future<ToasterState> three(WidgetTester tester) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      for (final title in ['One', 'Two', 'Three']) {
        toaster.show(Toast(title: Text(title), duration: stays));
        await settle(tester);
      }
      return toaster;
    }

    testWidgets('the newest is in front; the others show an edge above it, '
        'each a little smaller', (tester) async {
      await three(tester);
      final theme = Theme.of(host);
      final one = rectOf(tester, 'One');
      final two = rectOf(tester, 'Two');
      final three_ = rectOf(tester, 'Three');
      final offset = theme.toasterTheme.stackOffset!;
      expect(two.top, moreOrLessEquals(three_.top - offset, epsilon: .1));
      expect(one.top, moreOrLessEquals(three_.top - offset * 2, epsilon: .1));
      expect(two.width, moreOrLessEquals(three_.width * .95, epsilon: .1));
      expect(one.width, moreOrLessEquals(three_.width * .9, epsilon: .1));
      expect(two.center.dx, moreOrLessEquals(three_.center.dx));
    });

    testWidgets('pointing at it opens it, and it closes when the pointer '
        'leaves', (tester) async {
      await three(tester);
      final theme = Theme.of(host);
      final closed = rectOf(tester, 'One');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(rectOf(tester, 'Three').center);
      await settle(tester);

      final one = rectOf(tester, 'One');
      final two = rectOf(tester, 'Two');
      final three_ = rectOf(tester, 'Three');
      final gap = theme.toasterTheme.gap!;
      expect(two.bottom, moreOrLessEquals(three_.top - gap, epsilon: .1));
      expect(one.bottom, moreOrLessEquals(two.top - gap, epsilon: .1));
      expect(one.width, moreOrLessEquals(three_.width, epsilon: .1));

      // Crossing the gap between two toasts does not close it.
      await mouse.moveTo(Offset(three_.center.dx, three_.top - gap / 2));
      await settle(tester);
      expect(rectOf(tester, 'One').top, moreOrLessEquals(one.top));

      await mouse.moveTo(Offset.zero);
      await settle(tester);
      expect(rectOf(tester, 'One').top, moreOrLessEquals(closed.top));
    });

    testWidgets('opening and closing never jumps or turns back', (
      tester,
    ) async {
      await three(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(rectOf(tester, 'Three').center);
      await tester.pump();
      var last = rectOf(tester, 'One').top;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final now = rectOf(tester, 'One').top;
        expect(now, lessThanOrEqualTo(last + .01), reason: 'frame $i');
        expect(last - now, lessThan(40), reason: 'frame $i');
        last = now;
      }
    });

    testWidgets('a toast past the last one shown waits unseen, takes no '
        'taps, and comes back when there is room', (tester) async {
      final toaster = await three(tester);
      final four = toaster.show(
        const Toast(title: Text('Four'), duration: stays),
      );
      await settle(tester);
      final stack = tester.renderObject(
        find.byWidgetPredicate(
          (widget) => '${widget.runtimeType}' == '_ToastStack',
        ),
      );
      RenderObject slotOf(String title) {
        var node = tester.renderObject(find.text(title));
        while (node.parent != stack) {
          node = node.parent!;
        }
        return node;
      }

      expect(stack.paintsChild(slotOf('One')), isFalse);
      expect(stack.paintsChild(slotOf('Two')), isTrue);
      expect(stack.paintsChild(slotOf('Four')), isTrue);

      unawaited(toaster.dismiss(four));
      await settle(tester);
      expect(stack.paintsChild(slotOf('One')), isTrue);
    });

    testWidgets('a waiting toast does not use its time up', (tester) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      toaster.show(
        const Toast(title: Text('Old'), duration: Duration(seconds: 3)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final newer = [
        for (final title in ['A', 'B', 'C'])
          toaster.show(Toast(title: Text(title), duration: stays)),
      ];
      await settle(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Old', skipOffstage: false), findsOneWidget);
      unawaited(toaster.dismiss(newer.last));
      await settle(tester);
      // Back on screen, with its three seconds again.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Old'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('Old'), findsNothing);
    });

    testWidgets('time stands still while the pointer is on the stack', (
      tester,
    ) async {
      await pumpApp(tester);
      Toaster.of(host).show(
        const Toast(title: Text('Hi'), duration: Duration(seconds: 2)),
      );
      await settle(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(rectOf(tester, 'Hi').center);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Hi'), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Hi'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('Hi'), findsNothing);
    });

    testWidgets('the gap and the number shown can be set on the toaster '
        'and in the theme', (tester) async {
      await pumpApp(
        tester,
        theme: ThemeData(
          toasterTheme: const ToasterTheme(maxVisible: 1, width: 300),
        ),
      );
      final toaster = Toaster.of(host);
      toaster.show(const Toast(title: Text('One'), duration: stays));
      await settle(tester);
      toaster.show(const Toast(title: Text('Two'), duration: stays));
      await settle(tester);
      expect(rectOf(tester, 'Two').width, 300);
      final stack = tester.renderObject(
        find.byWidgetPredicate(
          (widget) => '${widget.runtimeType}' == '_ToastStack',
        ),
      );
      var node = tester.renderObject(find.text('One', skipOffstage: false));
      while (node.parent != stack) {
        node = node.parent!;
      }
      expect(stack.paintsChild(node), isFalse);
    });
  });

  group('motion', () {
    testWidgets('a toast rises into place and settles, without turning back '
        'past where it rests', (tester) async {
      await pumpApp(tester);
      Toaster.of(host).show(const Toast(title: Text('Hi'), duration: stays));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final first = rectOf(tester, 'Hi');
      final tops = <double>[];
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        tops.add(rectOf(tester, 'Hi').top);
      }
      final rest = tops.last;
      // It came from below.
      expect(first.top, greaterThan(rest + 4));
      // A lively spring may pass its rest by a hair; no more.
      for (final top in tops) {
        expect(top, greaterThan(rest - 3));
      }
      // And it rests: nothing is scheduled.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('dismissed half way in, it leaves from where it is', (
      tester,
    ) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      final id = toaster.show(const Toast(title: Text('Hi'), duration: stays));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      final at = rectOf(tester, 'Hi').top;
      unawaited(toaster.dismiss(id));
      await tester.pump();
      expect(rectOf(tester, 'Hi').top, moreOrLessEquals(at, epsilon: 2));
      await settle(tester);
      expect(find.text('Hi'), findsNothing);
    });

    testWidgets('with reduced motion it fades where it rests', (tester) async {
      await pumpApp(tester, reduceMotion: true);
      final toaster = Toaster.of(host);
      final id = toaster.show(const Toast(title: Text('Hi'), duration: stays));
      await tester.pump();
      final first = rectOf(tester, 'Hi');
      await settle(tester);
      expect(rectOf(tester, 'Hi'), first);
      unawaited(toaster.dismiss(id));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(rectOf(tester, 'Hi'), first);
      await settle(tester);
      expect(find.text('Hi'), findsNothing);
    });

    testWidgets('nothing is built or scheduled when there is no toast', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => '${widget.runtimeType}' == '_ToastStack',
        ),
        findsNothing,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the page keeps its state when the first toast arrives', (
      tester,
    ) async {
      var builds = 0;
      await pumpApp(
        tester,
        home: _Counter(
          onBuild: () => builds++,
          onContext: (context) => host = context,
        ),
      );
      final state = tester.state(find.byType(_Counter));
      final before = builds;
      Toaster.of(host).show(const Toast(title: Text('Hi'), duration: stays));
      await settle(tester);
      expect(tester.state(find.byType(_Counter)), same(state));
      expect(builds, before);
    });
  });

  group('swiping', () {
    Future<ToasterState> one(
      WidgetTester tester, {
      bool dismissible = true,
      AlignmentGeometry? alignment,
    }) async {
      await pumpApp(tester, size: const Size(390, 800), alignment: alignment);
      final toaster = Toaster.of(host);
      toaster.show(
        Toast(
          title: const Text('Hi'),
          duration: stays,
          dismissible: dismissible,
        ),
      );
      await settle(tester);
      return toaster;
    }

    testWidgets('down past the threshold dismisses', (tester) async {
      await one(tester);
      final start = rectOf(tester, 'Hi').center;
      final gesture = await tester.startGesture(start);
      // The first move is the slop the recognizer takes to tell a swipe
      // from a tap.
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      // It follows the finger.
      expect(rectOf(tester, 'Hi').center.dy, greaterThan(start.dy + 50));
      await gesture.up();
      await settle(tester);
      expect(find.text('Hi'), findsNothing);
    });

    testWidgets('a short drag springs back', (tester) async {
      await one(tester);
      final rest = rectOf(tester, 'Hi');
      final gesture = await tester.startGesture(rest.center);
      await gesture.moveBy(const Offset(0, 22));
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
      expect(rectOf(tester, 'Hi').top, greaterThan(rest.top));
      await gesture.up();
      await settle(tester);
      expect(rectOf(tester, 'Hi').top, moreOrLessEquals(rest.top, epsilon: .5));
    });

    testWidgets('a flick dismisses from any distance', (tester) async {
      await one(tester);
      // Too short to dismiss by distance once the slop is taken off.
      await tester.fling(find.text('Hi'), const Offset(0, 70), 1500);
      await settle(tester);
      expect(find.text('Hi'), findsNothing);
    });

    testWidgets('sideways dismisses, either way', (tester) async {
      for (final dx in [-120.0, 120.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await one(tester);
        final start = rectOf(tester, 'Hi').center;
        final gesture = await tester.startGesture(start);
        await gesture.moveBy(Offset(dx / 4, 0));
        await gesture.moveBy(Offset(dx * 3 / 4, 0));
        await tester.pump();
        final moved = rectOf(tester, 'Hi').center;
        expect((moved.dx - start.dx).sign, dx.sign);
        // Locked to the axis it started on.
        expect(moved.dy, moreOrLessEquals(start.dy));
        await gesture.up();
        await settle(tester);
        expect(find.text('Hi'), findsNothing);
      }
    });

    testWidgets('away from its edge it only gives a little', (tester) async {
      await one(tester);
      final rest = rectOf(tester, 'Hi');
      final gesture = await tester.startGesture(rest.center);
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -200));
      await tester.pump();
      expect(rest.top - rectOf(tester, 'Hi').top, inExclusiveRange(1, 24.5));
      await gesture.up();
      await settle(tester);
      expect(find.text('Hi'), findsOneWidget);
      expect(rectOf(tester, 'Hi').top, moreOrLessEquals(rest.top, epsilon: .5));
    });

    testWidgets('a toast at the top is swiped up', (tester) async {
      await one(tester, alignment: Alignment.topCenter);
      final gesture = await tester.startGesture(rectOf(tester, 'Hi').center);
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -60));
      await gesture.up();
      await settle(tester);
      expect(find.text('Hi'), findsNothing);
    });

    testWidgets('a toast that is not dismissible cannot be swiped away', (
      tester,
    ) async {
      await one(tester, dismissible: false);
      final rest = rectOf(tester, 'Hi');
      final gesture = await tester.startGesture(rest.center);
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(rectOf(tester, 'Hi').top - rest.top, lessThan(24.5));
      await gesture.up();
      await settle(tester);
      expect(find.text('Hi'), findsOneWidget);
    });

    testWidgets('a tap on its action still gets through, and time stands '
        'still while a finger is on the toast', (tester) async {
      await pumpApp(tester, size: const Size(390, 800));
      var undone = 0;
      Toaster.of(host).show(
        Toast(
          title: const Text('Hi'),
          duration: const Duration(seconds: 2),
          action: Button.outline(
            size: ButtonSize.sm,
            onPressed: () => undone++,
            child: const Text('Undo'),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(undone, 1);

      final gesture = await tester.startGesture(
        rectOf(tester, 'Hi').centerLeft + const Offset(20, 0),
      );
      await gesture.moveBy(const Offset(0, 22));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Hi'), findsOneWidget);
      await gesture.moveBy(const Offset(0, -22));
      await gesture.up();
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(find.text('Hi'), findsNothing);
    });
  });

  group('mouse and keyboard', () {
    testWidgets('a toast has no close button; a mouse swipes it away as a '
        'finger does', (tester) async {
      await pumpApp(tester);
      Toaster.of(host).show(const Toast(title: Text('Hi'), duration: stays));
      await settle(tester);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Pressable && widget.semanticLabel == 'Dismiss',
        ),
        findsNothing,
      );
      final start = rectOf(tester, 'Hi').center;
      final mouse = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 10; i++) {
        await mouse.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await mouse.up();
      await settle(tester);
      expect(find.text('Hi'), findsNothing);
    });

    testWidgets('F6 focuses a toast with no control itself, with a ring, '
        'and Escape dismisses it', (tester) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      toaster.show(const Toast(title: Text('Hi'), duration: stays));
      await settle(tester);
      expect(toaster.focusToasts(), isTrue);
      await settle(tester);
      expect(
        tester
            .widgetList<FocusRing>(
              find.ancestor(
                of: find.byType(Toast),
                matching: find.byType(FocusRing),
              ),
            )
            .any((ring) => ring.visible),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Hi'), findsNothing);
    });

    testWidgets('F6 moves the focus to the front toast and back; while it '
        'is there the stack is open and time stands still; Escape dismisses '
        'that toast and gives the focus back', (tester) async {
      final field = FocusNode();
      addTearDown(field.dispose);
      await pumpApp(
        tester,
        home: Builder(
          builder: (context) {
            host = context;
            return Center(
              child: Focus(
                focusNode: field,
                autofocus: true,
                child: const SizedBox.square(dimension: 40),
              ),
            );
          },
        ),
      );
      await tester.pump();
      expect(field.hasPrimaryFocus, isTrue);

      // With no toast the key is nobody's.
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.f6), isFalse);

      final toaster = Toaster.of(host);
      toaster.show(const Toast(title: Text('Older'), duration: stays));
      await settle(tester);
      var undone = 0;
      toaster.show(
        Toast(
          title: const Text('Hi'),
          duration: const Duration(seconds: 2),
          action: Button.outline(
            size: ButtonSize.sm,
            onPressed: () => undone++,
            child: const Text('Undo'),
          ),
        ),
      );
      await settle(tester);
      final closed = rectOf(tester, 'Older').top;

      // Tab stays in the page: the toasts are not part of it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(field.hasFocus, isTrue);

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.f6), isTrue);
      await settle(tester);
      expect(field.hasFocus, isFalse);
      bool focusIn(Finder finder) {
        final focus = FocusManager.instance.primaryFocus!.context!;
        return find
            .descendant(of: finder, matching: find.byWidget(focus.widget))
            .evaluate()
            .isNotEmpty;
      }

      expect(focusIn(find.widgetWithText(Button, 'Undo')), isTrue);
      // The stack is open and the clock has stopped.
      expect(rectOf(tester, 'Older').top, lessThan(closed - 20));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Hi'), findsOneWidget);
      // Enter presses the action.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(undone, 1);

      // Tab walks the toasts' controls and stays among them.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(field.hasFocus, isFalse);
      }

      // F6 again goes back to the page.
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.f6), isTrue);
      await settle(tester);
      expect(field.hasPrimaryFocus, isTrue);
      expect(rectOf(tester, 'Older').top, moreOrLessEquals(closed));

      await tester.sendKeyEvent(LogicalKeyboardKey.f6);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      // One toast per press: the one with the focus.
      expect(toaster.toasts.length, 1);
      expect(find.text('Hi'), findsNothing);
      expect(field.hasPrimaryFocus, isTrue);
    });

    testWidgets('a toast that leaves by itself gives the focus back', (
      tester,
    ) async {
      final field = FocusNode();
      addTearDown(field.dispose);
      await pumpApp(
        tester,
        home: Builder(
          builder: (context) {
            host = context;
            return Focus(
              focusNode: field,
              autofocus: true,
              child: const SizedBox.expand(),
            );
          },
        ),
      );
      await tester.pump();
      final toaster = Toaster.of(host);
      final id = toaster.show(const Toast(title: Text('Hi'), duration: stays));
      await settle(tester);
      expect(toaster.focusToasts(), isTrue);
      await settle(tester);
      expect(field.hasFocus, isFalse);
      unawaited(toaster.dismiss(id));
      await settle(tester);
      expect(field.hasPrimaryFocus, isTrue);
    });

    testWidgets('Escape leaves a toast that is not dismissible alone, and '
        'a toast with no control takes no focus', (tester) async {
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      toaster.show(
        const Toast(title: Text('Plain'), duration: stays, dismissible: false),
      );
      await settle(tester);
      expect(toaster.focusToasts(), isFalse);
      toaster.show(
        Toast(
          title: const Text('Hi'),
          duration: stays,
          dismissible: false,
          action: Button.outline(onPressed: () {}, child: const Text('Retry')),
        ),
      );
      await settle(tester);
      expect(toaster.focusToasts(), isTrue);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Hi'), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets('a toast is a live region that can be dismissed', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      toaster.show(
        const Toast(
          title: Text('Saved'),
          description: Text('All good'),
          duration: stays,
        ),
      );
      await settle(tester);
      SemanticsNode liveRegion() {
        SemanticsNode? live = tester.getSemantics(find.text('Saved'));
        while (live != null &&
            !live.getSemanticsData().flagsCollection.isLiveRegion) {
          live = live.parent;
        }
        expect(live, isNotNull, reason: 'no live region around the toast');
        return live!;
      }

      expect(
        liveRegion().getSemanticsData().hasAction(SemanticsAction.dismiss),
        isTrue,
      );
      // There is no close button: the toast's own action is how a screen
      // reader dismisses it.
      expect(find.bySemanticsLabel('Dismiss'), findsNothing);
      // The action a screen reader offers does what it says.
      final live = liveRegion();
      live.owner!.performAction(live.id, SemanticsAction.dismiss);
      await settle(tester);
      expect(find.text('Saved'), findsNothing);
      handle.dispose();
    });

    testWidgets('a toast waiting behind the stack is not read', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      final toaster = Toaster.of(host);
      for (final title in ['One', 'Two', 'Three', 'Four']) {
        toaster.show(Toast(title: Text(title), duration: stays));
        await settle(tester);
      }
      expect(find.bySemanticsLabel('One'), findsNothing);
      expect(find.bySemanticsLabel('Four'), findsOneWidget);
      handle.dispose();
    });
  });

  group('on its own', () {
    testWidgets('a Toast outside a Toaster is a picture of one', (
      tester,
    ) async {
      await tester.pumpWidget(
        UnaApp(
          home: Center(
            child: Toast(
              variant: ToastVariant.warning,
              title: const Text('Title'),
              description: const Text('Description'),
              action: Button.outline(
                size: ButtonSize.sm,
                onPressed: () {},
                child: const Text('Undo'),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final theme = Theme.of(tester.element(find.byType(Toast)));
      expect(
        tester.getSize(find.byType(Toast)).width,
        theme.toasterTheme.width,
      );
      await expectLater(
        find.byType(Toast),
        matchesGoldenFile('goldens/toast.png'),
      );
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({required this.onBuild, required this.onContext});

  final VoidCallback onBuild;
  final ValueChanged<BuildContext> onContext;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    widget.onContext(context);
    return const SizedBox.expand();
  }
}

/// Calls [onBuild] with the app's toaster the first time it is built.
class _ShowsInBuild extends StatefulWidget {
  const _ShowsInBuild({required this.onBuild});

  final void Function(ToasterState toaster) onBuild;

  @override
  State<_ShowsInBuild> createState() => _ShowsInBuildState();
}

class _ShowsInBuildState extends State<_ShowsInBuild> {
  @override
  void initState() {
    super.initState();
    widget.onBuild(Toaster.of(context));
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

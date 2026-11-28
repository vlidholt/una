import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/components/ring_painter.dart';
import 'package:una/src/components/spinner_painters.dart';
import 'package:una/una.dart';

import '../../una_harness.dart';

CustomPainter _painterOf(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(Spinner),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter!;

/// What [painter] draws in a box [side] across, as text: every call and
/// its arguments, paths by their bounds.
String _drawing(CustomPainter painter, double side) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, Size.square(side));
  String describe(Object? argument) => switch (argument) {
    final Path path =>
      'Path(${path.getBounds()}, '
          '${path.computeMetrics().first.getTangentForOffset(0)?.position})',
    final Paint paint => 'Paint(${paint.color}, ${paint.strokeWidth})',
    final double d => d.toStringAsFixed(3),
    _ => '$argument',
  };
  return [
    for (final call in canvas.invocations)
      [
        call.invocation.memberName,
        call.invocation.positionalArguments.map(describe).join(', '),
      ].join(' '),
  ].join('\n');
}

Widget _app(Widget child, {bool reduceMotion = false, Motion? motion}) =>
    UnaApp(
      theme: ThemeData(motion: motion),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: Center(child: child),
        ),
      ),
    );

void main() {
  group('Spinner', () {
    testWidgets('renders every variant at the requested size', (tester) async {
      for (final variant in SpinnerVariant.values) {
        await tester.pumpWidget(_app(Spinner(variant: variant, size: 24)));
        expect(tester.getSize(find.byType(Spinner)), const Size(24, 24));
        // A spinner never settles: pump fixed frames, never pumpAndSettle.
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('is the indeterminate ring by default, its stroke following '
        'its size and its colour the icon colour', (tester) async {
      await tester.pumpWidget(
        _app(
          const IconTheme(
            data: IconThemeData(color: Color(0xff336699)),
            child: Spinner(),
          ),
        ),
      );
      var ring = _painterOf(tester) as RingPainter;
      // A small ring keeps its line's weight: a sixth of 16, not a tenth.
      expect(ring.strokeWidth, moreOrLessEquals(16 / 6));
      expect(ring.color, const Color(0xff336699));
      expect(ring.trackColor.a, moreOrLessEquals(.2, epsilon: .01));

      await tester.pumpWidget(_app(const Spinner(size: 48)));
      ring = _painterOf(tester) as RingPainter;
      expect(ring.strokeWidth, moreOrLessEquals(4.8));
    });

    test('the line keeps its weight as the ring shrinks, until it is very '
        'small', () {
      expect(ringStrokeFor(56), moreOrLessEquals(5.6));
      expect(ringStrokeFor(30), moreOrLessEquals(3));
      expect(ringStrokeFor(24), 3);
      expect(ringStrokeFor(18), 3);
      expect(ringStrokeFor(12), moreOrLessEquals(2));
    });

    testWidgets('the named constructors and the theme choose the variant', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const Spinner.orbit()));
      expect(_painterOf(tester), isA<OrbitSpinnerPainter>());
      await tester.pumpWidget(_app(const Spinner.morph()));
      expect(_painterOf(tester), isA<MorphSpinnerPainter>());
      await tester.pumpWidget(_app(const Spinner.goo()));
      expect(_painterOf(tester), isA<GooSpinnerPainter>());
      await tester.pumpWidget(_app(const Spinner.halo()));
      expect(_painterOf(tester), isA<HaloSpinnerPainter>());

      // A theme's variant reaches a spinner that names none — a button's
      // loading spinner among them.
      await tester.pumpWidget(
        UnaApp(
          theme: ThemeData(
            spinnerTheme: const SpinnerTheme(variant: SpinnerVariant.goo),
          ),
          home: Center(
            child: Button(
              loading: true,
              onPressed: () {},
              child: const Text('Save'),
            ),
          ),
        ),
      );
      // The button swaps its spinner in a frame after it is first built.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painterOf(tester), isA<GooSpinnerPainter>());
    });

    for (final variant in SpinnerVariant.values) {
      testWidgets('${variant.name}: moves in paint and is never rebuilt', (
        tester,
      ) async {
        await tester.pumpWidget(_app(Spinner(variant: variant, size: 32)));
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(Spinner),
            matching: find.byType(CustomPaint),
          ),
        );
        final drawings = <String>{};
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 130));
          drawings.add(_drawing(_painterOf(tester), 32));
        }
        // Every frame is a new picture, from one painter on one widget.
        expect(drawings, hasLength(6));
        expect(
          tester.widget<CustomPaint>(
            find.descendant(
              of: find.byType(Spinner),
              matching: find.byType(CustomPaint),
            ),
          ),
          same(paint),
        );
        expect(tester.hasRunningAnimations, isTrue);
      });
    }

    testWidgets('every variant stays inside its box', (tester) async {
      var time = Duration.zero;
      for (final painter in [
        OrbitSpinnerPainter(
          color: const Color(0xff000000),
          frame: () => (time: time, opacity: 1),
        ),
        MorphSpinnerPainter(
          color: const Color(0xff000000),
          frame: () => (time: time, opacity: 1),
        ),
        GooSpinnerPainter(
          color: const Color(0xff000000),
          frame: () => (time: time, opacity: 1),
        ),
        HaloSpinnerPainter(
          color: const Color(0xff000000),
          frame: () => (time: time, opacity: 1),
        ),
      ]) {
        for (final side in [16.0, 24.0, 96.0]) {
          for (var ms = 0; ms < 4000; ms += 37) {
            time = Duration(milliseconds: ms);
            final canvas = TestRecordingCanvas();
            painter.paint(canvas, Size.square(side));
            for (final call in canvas.invocations) {
              final args = call.invocation.positionalArguments;
              final bounds = switch (call.invocation.memberName) {
                #drawCircle => Rect.fromCircle(
                  center: args[0] as Offset,
                  radius: args[1] as double,
                ),
                #drawPath => (args[0] as Path).getBounds(),
                _ => null,
              };
              if (bounds == null) continue;
              // Drawn about the centre: the box is ± half its side.
              final half = side / 2 + .01;
              expect(
                bounds.left >= -half &&
                    bounds.top >= -half &&
                    bounds.right <= half &&
                    bounds.bottom <= half,
                isTrue,
                reason: '${painter.runtimeType} at $side, $ms ms: $bounds',
              );
            }
          }
        }
      }
    });

    testWidgets('under reduced motion it holds still and breathes', (
      tester,
    ) async {
      for (final variant in SpinnerVariant.values) {
        await tester.pumpWidget(
          _app(Spinner(variant: variant), reduceMotion: true),
        );
        final opacities = <double>{};
        Object? pose;
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 300));
          final painter = _painterOf(tester);
          if (painter is RingPainter) {
            final arc = painter.arc();
            pose ??= arc;
            expect(arc, pose, reason: 'the ring does not move');
            opacities.add(painter.opacity!());
          } else {
            final (:time, :opacity) = (painter as SpinnerPainter).frame();
            pose ??= time;
            expect(time, pose, reason: '${variant.name} does not move');
            opacities.add(opacity);
          }
        }
        expect(opacities.length, greaterThan(1), reason: variant.name);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('with Motion.none it holds still and schedules nothing', (
      tester,
    ) async {
      for (final variant in SpinnerVariant.values) {
        await tester.pumpWidget(
          _app(Spinner(variant: variant), motion: Motion.none),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.hasRunningAnimations, isFalse, reason: variant.name);
      }
    });

    testWidgets('duration sets the pace of one cycle', (tester) async {
      Future<Duration> timeAfter(Duration? duration) async {
        await tester.pumpWidget(
          _app(Spinner.morph(duration: duration)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final time = (_painterOf(tester) as SpinnerPainter).frame().time;
        await tester.pumpWidget(const SizedBox());
        return time;
      }

      final own = await timeAfter(null);
      final twiceAsFast = await timeAfter(const Duration(milliseconds: 375));
      expect(
        twiceAsFast.inMicroseconds / own.inMicroseconds,
        moreOrLessEquals(2, epsilon: .01),
      );
    });

    testWidgets('a label is announced as a loading spinner', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const Spinner.orbit(semanticLabel: 'Saving')),
      );
      expect(find.bySemanticsLabel('Saving'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('builds in every layout', (tester) async {
      await expectBuildsInEveryLayout(
        tester,
        (_) => const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Spinner(),
              Spinner.orbit(),
              Spinner.morph(),
              Spinner.goo(),
              Spinner.halo(),
            ],
          ),
        ),
      );
    });
  });

  group('indeterminateArc', () {
    test('grows to three quarters of a turn and back, and keeps turning', () {
      final sweeps = <double>[];
      final starts = <double>[];
      for (var ms = 0; ms <= 1333; ms += 10) {
        final arc = indeterminateArc(Duration(milliseconds: ms));
        sweeps.add(arc.sweep);
        starts.add(arc.start);
      }
      expect(
        sweeps.reduce(math.max),
        moreOrLessEquals(math.pi * 1.5, epsilon: .01),
      );
      expect(sweeps.reduce(math.min), moreOrLessEquals(.12));
      // Longest halfway through, when the head has finished and the tail
      // not started.
      expect(sweeps[67], greaterThan(math.pi * 1.45));
    });

    test('is continuous from one cycle to the next', () {
      for (var cycle = 1; cycle < 5; cycle++) {
        final end = indeterminateArc(
          indeterminateArcCycle * cycle - const Duration(microseconds: 1),
        );
        final next = indeterminateArc(indeterminateArcCycle * cycle);
        final gap = (next.start - end.start) % (math.pi * 2);
        expect(math.min(gap, math.pi * 2 - gap), lessThan(.001));
        expect(next.sweep, moreOrLessEquals(end.sweep, epsilon: .001));
      }
    });
  });
}

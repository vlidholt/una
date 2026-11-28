import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/components/ring_painter.dart';
import 'package:una/una.dart';

import '../../frame_sampler.dart';
import '../../una_harness.dart';

void main() {
  RingPainter painterOf(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(ProgressRing),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as RingPainter;

  Widget ring({
    double? value = .5,
    double sweepAngle = math.pi * 2,
    double? size,
    Widget? child,
    String? semanticLabel,
    String? semanticValue,
    Color? color,
    Color? trackColor,
  }) => Center(
    child: ProgressRing(
      value: value,
      sweepAngle: sweepAngle,
      size: size,
      semanticLabel: semanticLabel,
      semanticValue: semanticValue,
      color: color,
      trackColor: trackColor,
      child: child,
    ),
  );

  group('ProgressRing', () {
    testWidgets('takes its colours from the progress bar and its size from '
        'the widget', (tester) async {
      await pumpUna(tester, ring());
      final theme = themeOf(tester, find.byType(ProgressRing));
      final painter = painterOf(tester);
      expect(painter.color, theme.progressBarTheme.color);
      expect(painter.trackColor, theme.progressBarTheme.trackColor);
      expect(tester.getSize(find.byType(ProgressRing)), const Size(40, 40));
      expect(painter.strokeWidth, 4);

      await pumpUna(
        tester,
        ring(
          size: 96,
          color: const Color(0xff112233),
          trackColor: const Color(0x00000000),
        ),
      );
      expect(tester.getSize(find.byType(ProgressRing)), const Size(96, 96));
      expect(painterOf(tester).strokeWidth, 6);
      expect(painterOf(tester).color, const Color(0xff112233));
    });

    testWidgets('the arc starts at the top and covers the value', (
      tester,
    ) async {
      await pumpUna(tester, ring(value: .25));
      final arc = painterOf(tester).arc();
      expect(arc.start, moreOrLessEquals(-math.pi / 2));
      expect(arc.sweep, moreOrLessEquals(math.pi / 2));
    });

    testWidgets('a new value rides the spring of the progress bar theme', (
      tester,
    ) async {
      Widget themed(double value) => Builder(
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(
            progressBarTheme: const ProgressBarTheme(
              spring: MotionSpring.instant,
            ),
          ),
          child: ring(value: value),
        ),
      );
      await pumpUna(tester, themed(.25));
      await pumpUna(tester, themed(.75));
      await tester.pump();
      expect(painterOf(tester).arc().sweep, moreOrLessEquals(math.pi * 1.5));
    });

    testWidgets('values outside 0 to 1 are clamped', (tester) async {
      await pumpUna(tester, ring(value: 3));
      expect(painterOf(tester).arc().sweep, moreOrLessEquals(math.pi * 2));
      await pumpUna(tester, ring(value: -1));
      await tester.pumpAndSettle();
      expect(painterOf(tester).arc().sweep, 0);
    });

    testWidgets('a change of value eases there: monotone, and it settles', (
      tester,
    ) async {
      await pumpUna(tester, ring(value: .2));
      await pumpUna(tester, ring(value: .8));
      // pumpUna has already let it run; start again from rest.
      await pumpUna(tester, ring(value: .2));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        UnaApp(
          formFactor: FormFactor.desktop,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: ring(value: .8),
          ),
        ),
      );
      final sweeps = <double>[];
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        sweeps.add(painterOf(tester).arc().sweep);
      }
      expect(sweeps.first, greaterThan(math.pi * 2 * .2 - 1e-6));
      expect(sweeps.first, lessThan(math.pi * 2 * .8));
      for (var i = 1; i < sweeps.length; i++) {
        expect(sweeps[i], greaterThanOrEqualTo(sweeps[i - 1] - 1e-9));
      }
      expect(sweeps.last, moreOrLessEquals(math.pi * 2 * .8, epsilon: 1e-3));
      await tester.pumpAndSettle();
    });

    testWidgets('under Motion.none and reduced motion the value jumps', (
      tester,
    ) async {
      await pumpUna(
        tester,
        ring(value: .2),
        theme: ThemeData(motion: Motion.none),
      );
      await tester.pumpWidget(
        UnaApp(
          theme: ThemeData(motion: Motion.none),
          formFactor: FormFactor.desktop,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: ring(value: .9),
          ),
        ),
      );
      await tester.pump();
      expect(
        painterOf(tester).arc().sweep,
        moreOrLessEquals(math.pi * 2 * .9),
      );

      await pumpUna(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) => GestureDetector(
              onTap: () => setState(() => _value = .7),
              behavior: HitTestBehavior.opaque,
              child: ring(value: _value),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ProgressRing));
      await tester.pump();
      expect(
        painterOf(tester).arc().sweep,
        moreOrLessEquals(math.pi * 2 * .7),
      );
    });

    testWidgets('a null value spins, and nothing is built while it does', (
      tester,
    ) async {
      var builds = 0;
      await pumpUna(
        tester,
        Center(
          child: ProgressRing(
            value: null,
            child: Builder(
              builder: (context) {
                builds++;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final before = builds;
      final first = painterOf(tester).arc();
      await tester.pump(const Duration(milliseconds: 100));
      final second = painterOf(tester).arc();
      expect(second.start, isNot(first.start));
      expect(builds, before);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('a null value grows and shrinks while it turns, as '
        "Material's does", (tester) async {
      await pumpUna(tester, ring(value: null));
      final sweeps = <double>[];
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        sweeps.add(painterOf(tester).arc().sweep);
      }
      expect(sweeps.reduce(math.max), greaterThan(math.pi * 1.3));
      expect(sweeps.reduce(math.min), lessThan(math.pi * .3));
    });

    testWidgets('a gauge spins within its own sweep', (tester) async {
      const sweep = math.pi;
      await pumpUna(tester, ring(value: null, sweepAngle: sweep));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(painterOf(tester).arc().sweep, lessThanOrEqualTo(sweep + 1e-9));
      }
    });

    testWidgets('a null value under reduced motion holds still and breathes', (
      tester,
    ) async {
      await pumpUna(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ring(value: null),
          ),
        ),
      );
      final arc = painterOf(tester).arc();
      final opacities = <double>{};
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
        expect(painterOf(tester).arc(), arc);
        opacities.add(painterOf(tester).opacity!());
      }
      expect(opacities.length, greaterThan(1));
    });

    testWidgets('a determinate ring schedules nothing at rest', (tester) async {
      await pumpUna(tester, ring());
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      // Going back from a spin stops the spin.
      await pumpUna(tester, ring(value: null));
      expect(tester.hasRunningAnimations, isTrue);
      await pumpUna(tester, ring(value: .4));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        painterOf(tester).arc().sweep,
        moreOrLessEquals(math.pi * 2 * .4),
      );
    });

    testWidgets('a gauge is an open arc with its gap at the bottom', (
      tester,
    ) async {
      const sweep = math.pi * 1.5;
      await pumpUna(tester, ring(value: 1, sweepAngle: sweep, size: 100));
      final painter = painterOf(tester);
      expect(painter.trackSweep, sweep);
      expect(painter.trackStart, moreOrLessEquals(-math.pi / 2 - sweep / 2));
      expect(painter.arc().sweep, moreOrLessEquals(sweep));

      final sampler = FrameSampler();
      await pumpUna(
        tester,
        sampler.wrap(
          ring(
            value: 1,
            sweepAngle: sweep,
            size: 100,
            color: const Color(0xffff0000),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(ProgressRing));
      // On the ring at the top; nothing on it at the bottom.
      final top = await sampler.pixel(
        tester,
        rect.topCenter + const Offset(0, 3),
      );
      final bottom = await sampler.pixel(
        tester,
        rect.bottomCenter - const Offset(0, 3),
      );
      expect(rgbOf(top), [255, 0, 0]);
      expect(rgbOf(bottom), isNot([255, 0, 0]));
    });

    testWidgets('the child is centred inside the ring', (tester) async {
      await pumpUna(
        tester,
        ring(size: 80, child: const Text('50%')),
      );
      expect(
        tester.getCenter(find.text('50%')),
        tester.getCenter(find.byType(ProgressRing)),
      );
    });

    testWidgets('announces a percentage, or the value it is given', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpUna(tester, ring(value: .42, semanticLabel: 'Uploading'));
      expect(
        tester.getSemantics(find.byType(ProgressRing)),
        matchesSemantics(label: 'Uploading', value: '42%'),
      );
      await pumpUna(
        tester,
        ring(semanticLabel: 'Storage', semanticValue: '12 of 50 GB'),
      );
      expect(
        tester.getSemantics(find.byType(ProgressRing)),
        matchesSemantics(label: 'Storage', value: '12 of 50 GB'),
      );
      await pumpUna(tester, ring(value: null, semanticLabel: 'Loading'));
      expect(
        tester.getSemantics(find.byType(ProgressRing)),
        matchesSemantics(label: 'Loading', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('builds in every layout, style and brightness', (tester) async {
      for (final style in [StyleTokens.fluid, StyleTokens.crisp]) {
        await expectBuildsInEveryLayout(
          tester,
          (_) => ring(child: const Text('5')),
          theme: ThemeData(style: style),
        );
      }
    });
  });

  group('Spinner on the shared painter', () {
    testWidgets('spins in paint: its arc moves and nothing is rebuilt', (
      tester,
    ) async {
      await pumpUna(tester, const Center(child: Spinner()));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(Spinner),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as RingPainter;
      final first = painter.arc();
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter.arc().start, isNot(first.start));
      expect(painter.arc().sweep, isNot(first.sweep));
      // A 16-point ring keeps a heavier line than a tenth of its size.
      expect(painter.strokeWidth, moreOrLessEquals(16 / 6));
    });
  });
}

double _value = .1;

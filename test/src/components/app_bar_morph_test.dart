import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/components/app_bar_layout.dart' show AppBarToolbar;
import 'package:una/una.dart';

import '../../una_harness.dart';

/// A Liquid Glass bar stays in place while its page is pushed or popped,
/// and turns into the next page's: one toolbar flies, the pages slide
/// under it.
void main() {
  final navigator = GlobalKey<NavigatorState>();
  const frame = Duration(milliseconds: 16);

  Widget page(String title, {List<Widget> actions = const []}) => Scaffold(
    appBar: AppBar(
      liquidGlass: LiquidGlassMode.always,
      title: Text(title),
      actions: actions,
    ),
    body: SizedBox.expand(key: ValueKey(title)),
  );

  Widget icon(String label) => IconButton(
    icon: const PhosphorIcon(PhosphorIconsRegular.heart),
    semanticLabel: label,
    onPressed: () {},
  );

  Future<void> pumpStack(WidgetTester tester, {bool liquid = true}) => pumpUna(
    tester,
    // A navigator of its own needs its own hero controller, as an
    // app's or a router's branch has.
    HeroControllerScope(
      controller: HeroController(),
      child: Navigator(
        key: navigator,
        onGenerateInitialRoutes: (_, _) => [
          UnaPageRoute<void>(
            builder: (_) => liquid
                ? page('Trips', actions: [icon('Search')])
                : const Scaffold(
                    appBar: AppBar(
                      liquidGlass: LiquidGlassMode.never,
                      title: Text('Trips'),
                    ),
                    body: SizedBox.expand(key: ValueKey('Trips')),
                  ),
          ),
        ],
      ),
    ),
    formFactor: FormFactor.mobile,
  );

  Finder flight() =>
      find.byWidgetPredicate((w) => '${w.runtimeType}' == '_BarFlight');

  // On iOS with shader filters, reset inside the test: Flutter checks its
  // debug variables before a tear-down runs.
  void onIos(String description, WidgetTesterCallback body) =>
      testWidgets(description, (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        LiquidGlass.debugHasShaderFilters = true;
        try {
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          LiquidGlass.debugHasShaderFilters = null;
        }
      });

  // A button in the flight, by its label, and how opaque it is drawn.
  double? shown(WidgetTester tester, String label) {
    final items = find.descendant(
      of: flight(),
      matching: find.byWidgetPredicate(
        (w) =>
            '${w.runtimeType}' == '_ClusterItem' &&
            switch ((w as dynamic).child) {
              IconButton(:final semanticLabel) => semanticLabel == label,
              _ => false,
            },
      ),
    );
    if (items.evaluate().isEmpty) return null;
    return (tester.widget(items.first) as dynamic).opacity as double;
  }

  // Pumps [frames] frames, recording [labels]' opacity in the flight.
  Future<Map<String, List<double>>> sample(
    WidgetTester tester,
    List<String> labels, {
    int frames = 40,
  }) async {
    final seen = {for (final l in labels) l: <double>[]};
    for (var i = 0; i < frames && flight().evaluate().isNotEmpty; i++) {
      for (final l in labels) {
        if (shown(tester, l) case final o?) seen[l]!.add(o);
      }
      await tester.pump(frame);
    }
    return seen;
  }

  void expectMonotone(List<double> values, {required bool rising}) {
    for (var i = 1; i < values.length; i++) {
      rising
          ? expect(values[i], greaterThanOrEqualTo(values[i - 1] - 1e-9))
          : expect(values[i], lessThanOrEqualTo(values[i - 1] + 1e-9));
    }
  }

  Future<void> pushLofoten(WidgetTester tester) async {
    navigator.currentState!.push(
      UnaPageRoute<void>(
        builder: (_) => page('Lofoten', actions: [icon('Save'), icon('Share')]),
      ),
    );
    await tester.pump();
    await tester.pump(frame);
  }

  onIos('a push flies the glass in place, the titles going with their pages, '
      'the back button materializing', (tester) async {
    await pumpStack(tester);
    final rest = tester.getRect(find.byType(AppBarToolbar));
    final restTitle = tester.getTopLeft(find.text('Trips'));
    await pushLofoten(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(frame);
    }
    expect(flight(), findsOneWidget);
    // In place: where the bar is at rest, while the page slides.
    final flying = tester.getRect(
      find.descendant(of: flight(), matching: find.byType(AppBarToolbar)),
    );
    expect(flying.topLeft, rest.topLeft);
    // The titles are not in the flight: each moves with its page.
    expect(
      find.descendant(of: flight(), matching: find.byType(Text)),
      findsNothing,
    );
    expect(tester.getTopLeft(find.text('Trips')).dx, lessThan(restTitle.dx));
    expect(
      tester.getTopLeft(find.text('Lofoten')).dx,
      greaterThan(restTitle.dx),
    );
    // Early on, the back button is not there yet: it materializes over
    // the second half.
    expect(
      find.descendant(of: flight(), matching: find.byType(BackButton)),
      findsNothing,
    );
    final seen = await sample(tester, ['Search', 'Save']);
    expectMonotone(seen['Search']!, rising: false);
    expectMonotone(seen['Save']!, rising: true);
    await tester.pumpAndSettle();
    expect(flight(), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  onIos('a pop plays towards the page below, from the buttons of the page '
      'leaving', (tester) async {
    await pumpStack(tester);
    await pushLofoten(tester);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(frame);
    expect(flight(), findsOneWidget);
    // The first frames show the page leaving, never the one below.
    expect(shown(tester, 'Save'), 1);
    expect(shown(tester, 'Search') ?? 0, 0);
    final seen = await sample(tester, ['Search', 'Save', 'Share']);
    expectMonotone(seen['Save']!, rising: false);
    expectMonotone(seen['Share']!, rising: false);
    expectMonotone(seen['Search']!, rising: true);
    await tester.pumpAndSettle();
    expect(flight(), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Trips'), findsOneWidget);
  });

  onIos('a button both pages have holds still', (tester) async {
    await pumpStack(tester);
    navigator.currentState!.push(
      UnaPageRoute<void>(
        builder: (_) =>
            page('Lofoten', actions: [icon('Save'), icon('Search')]),
      ),
    );
    await tester.pump();
    await tester.pump(frame);
    final at = <double>[];
    for (var i = 0; i < 30 && flight().evaluate().isNotEmpty; i++) {
      final kept = find.descendant(
        of: flight(),
        matching: find.bySemanticsLabel('Search'),
      );
      if (kept.evaluate().isNotEmpty) at.add(tester.getRect(kept.last).right);
      await tester.pump(frame);
    }
    expect(at, isNotEmpty);
    // Its end of the capsule holds still while
    // the capsule grows away from it.
    expect(at.reduce(math.max) - at.reduce(math.min), lessThan(.5));
    await tester.pumpAndSettle();
  });

  onIos('a swipe back holds the chrome under the finger, then cross-fades', (
    tester,
  ) async {
    await pumpStack(tester);
    await pushLofoten(tester);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(4, 400));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await tester.pump(frame);
    expect(flight(), findsOneWidget);
    // Past half way, still the page under the finger.
    expect(shown(tester, 'Save'), 1);
    expect(shown(tester, 'Search') ?? 0, 0);
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump(frame);
    await gesture.up();
    await tester.pump();
    final seen = await sample(tester, ['Search', 'Save']);
    expectMonotone(seen['Save']!, rising: false);
    expectMonotone(seen['Search']!, rising: true);
    await tester.pumpAndSettle();
    expect(flight(), findsNothing);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  onIos('a cancelled swipe leaves the chrome as it was', (tester) async {
    await pumpStack(tester);
    await pushLofoten(tester);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(4, 400));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await tester.pump(frame);
    await gesture.moveBy(const Offset(-60, 0));
    await gesture.up();
    await tester.pump();
    final seen = await sample(tester, ['Search', 'Save']);
    expect(seen['Save']!.every((o) => o == 1), isTrue);
    expect(seen['Search']!.every((o) => o == 0), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Lofoten'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  onIos('the toolbar keeps its state through a flight', (tester) async {
    _Probe.states.clear();
    await pumpUna(
      tester,
      HeroControllerScope(
        controller: HeroController(),
        child: Navigator(
          key: navigator,
          onGenerateInitialRoutes: (_, _) => [
            UnaPageRoute<void>(
              builder: (_) => const Scaffold(
                appBar: AppBar(
                  liquidGlass: LiquidGlassMode.always,
                  title: _Probe(),
                ),
                body: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
      formFactor: FormFactor.mobile,
    );
    await pushLofoten(tester);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_Probe.states, hasLength(1));
  });

  onIos('a filled bar is not a hero: it moves with its page', (
    tester,
  ) async {
    await pumpStack(tester, liquid: false);
    navigator.currentState!.push(
      UnaPageRoute<void>(
        builder: (_) => const Scaffold(
          appBar: AppBar(
            liquidGlass: LiquidGlassMode.never,
            title: Text('Lofoten'),
          ),
          body: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(frame);
    await tester.pump(frame);
    expect(flight(), findsNothing);
    expect(find.byType(Hero), findsNothing);
    await tester.pumpAndSettle();
  });
}

/// A title that counts how often its state is made.
class _Probe extends StatefulWidget {
  const _Probe();

  static final states = <State<_Probe>>[];

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.states.add(this);
  }

  @override
  Widget build(BuildContext context) => const Text('Probe');
}

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

  onIos('a push flies one toolbar in place over the sliding pages, '
      'the back button materializing', (tester) async {
    await pumpStack(tester);
    final rest = tester.getRect(find.byType(AppBarToolbar));
    navigator.currentState!.push(
      UnaPageRoute<void>(
        builder: (_) => page('Lofoten', actions: [icon('Save'), icon('Share')]),
      ),
    );
    await tester.pump();
    await tester.pump(frame);
    for (var i = 0; i < 6; i++) {
      await tester.pump(frame);
    }
    expect(flight(), findsOneWidget);
    // In place: where the bar is at rest, while the page slides.
    final flying = tester.getRect(
      find.descendant(of: flight(), matching: find.byType(AppBarToolbar)),
    );
    expect(flying.top, rest.top);
    expect(flying.left, rest.left);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('Lofoten'))).dx,
      greaterThan(0),
    );
    // Both titles are in the flight, and the back button is coming.
    expect(
      find.descendant(of: flight(), matching: find.byType(BackButton)),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(flight(), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  onIos('a swipe back carries the flight with the finger', (
    tester,
  ) async {
    await pumpStack(tester);
    navigator.currentState!.push(
      UnaPageRoute<void>(builder: (_) => page('Lofoten')),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(4, 400));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await tester.pump(frame);
    expect(flight(), findsOneWidget);
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(flight(), findsNothing);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
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

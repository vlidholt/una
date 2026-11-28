import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/utils/scroll_edge_shader.dart';
import 'package:una/una.dart';

import '../../una_harness.dart';

void main() {
  // Where there are no shader filters, as in every browser and in tests.
  setUp(() => LiquidGlass.debugHasShaderFilters = false);
  tearDown(() => LiquidGlass.debugHasShaderFilters = null);

  Widget screen({LiquidGlassMode? mode, Widget? body, Widget? banner}) =>
      Scaffold(
        banner: banner,
        appBar: AppBar(
          liquidGlass: mode,
          title: const Text('Inbox'),
          actions: [
            IconButton.ghost(
              icon: const PhosphorIcon(PhosphorIconsRegular.bell),
              semanticLabel: 'Alerts',
              onPressed: () {},
            ),
          ],
        ),
        body:
            body ??
            ListView(
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 48, child: Text('Row $i')),
              ],
            ),
      );

  group('a Liquid Glass bar without shader filters', () {
    testWidgets('reaches its edge down under the banner, as one edge', (
      tester,
    ) async {
      await pumpUna(
        tester,
        screen(
          mode: LiquidGlassMode.always,
          banner: const SizedBox(key: Key('banner'), height: 72),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final bar = tester.getRect(find.byType(AppBar));
      final banner = tester.getRect(find.byKey(const Key('banner')));
      expect(banner.top, bar.bottom);
      final edge = tester.getRect(find.byType(LiquidGlassScrollEdge));
      expect(edge.top, bar.top);
      expect(edge.bottom, banner.bottom);
    });

    testWidgets('its edge rises with the scroll rather than popping in', (
      tester,
    ) async {
      await pumpUna(tester, screen(mode: LiquidGlassMode.always));
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable),
      );
      double strength() => tester
          .widget<ShaderScrollEdge>(find.byType(ShaderScrollEdge))
          .strength;
      scrollable.position.jumpTo(8);
      await tester.pump();
      await tester.pump();
      final early = strength();
      expect(early, greaterThan(0));
      expect(early, lessThan(.5));
      scrollable.position.jumpTo(16);
      await tester.pump();
      expect(strength(), greaterThan(early));
      scrollable.position.jumpTo(200);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(strength(), 1);
    });

    testWidgets('is solid unless it asks for the glass', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpUna(tester, screen(), formFactor: FormFactor.mobile);
        expect(find.byType(LiquidGlassBarGroup), findsNothing);
        expect(find.byType(ShaderScrollEdge), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('asked with LiquidGlassMode.always, it has capsules and '
        "una's scroll edge once the page is under it", (tester) async {
      await pumpUna(
        tester,
        screen(mode: LiquidGlassMode.always),
      );
      expect(find.byType(LiquidGlassBarGroup), findsOneWidget);
      // At the top, nothing is under the bar to blur.
      expect(find.byType(ShaderScrollEdge), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(ShaderScrollEdge), findsOneWidget);
    });

    testWidgets('the theme can turn the edge on for every bar', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpUna(
          tester,
          screen(),
          formFactor: FormFactor.mobile,
          theme: ThemeData(
            liquidGlass: const LiquidGlassTheme(webScrollEdge: true),
          ),
        );
        expect(find.byType(LiquidGlassBarGroup), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('a scaffold marks its body as the page the edge is taken from', (
    tester,
  ) async {
    await pumpUna(tester, screen());
    expect(find.byType(ScrollEdgeSource), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ScrollEdgeSource),
        matching: find.byType(ListView),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ScrollEdgeSource),
        matching: find.byType(AppBar),
      ),
      findsNothing,
    );
  });
}

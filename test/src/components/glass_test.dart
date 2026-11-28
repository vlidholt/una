import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/una.dart';

import '../../decoration_finders.dart';
import '../../una_harness.dart';

void main() {
  /// The surface's own box: the tint, the hairline and the radius.
  BoxDecoration surfaceOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(Glass),
        matching: find.byType(Container),
      ),
    );
    return container.decoration! as BoxDecoration;
  }

  group('GlassTheme', () {
    test("is fed by the style's glass tokens and the scheme", () {
      final light = ThemeData();
      final dark = ThemeData(brightness: Brightness.dark);

      expect(light.glassTheme.blur, StyleTokens.fluid.glassBlur);
      expect(light.glassTheme.blur, 24);
      expect(light.glassTheme.saturation, 1.6);
      expect(light.glassTheme.color, light.colorScheme.card);
      expect(light.glassTheme.opacity, .7);
      // The dark tint is a touch lighter-handed.
      expect(dark.glassTheme.opacity, .66);
      expect(light.glassTheme.strongOpacity, .9);
      expect(dark.glassTheme.strongOpacity, .9);
      expect(light.glassTheme.borderColor, light.colorScheme.border);
      expect(light.glassTheme.borderWidth, 1);
      expect(light.glassTheme.borderRadius, light.cardTheme.borderRadius);
    });

    test('lerps', () {
      final a = ThemeData().glassTheme;
      final b = ThemeData(brightness: Brightness.dark).glassTheme;
      final mid = GlassTheme.lerp(a, b, .5)!;
      expect(mid.opacity, closeTo(.68, 1e-9));
      expect(mid.color, Color.lerp(a.color, b.color, .5));
      expect(GlassTheme.lerp(a, b, 0), a);
      expect(GlassTheme.lerp(a, b, 1), b);
    });
  });

  group('Glass', () {
    testWidgets('renders in both form factors and text directions', (
      tester,
    ) async {
      await expectBuildsInEveryLayout(
        tester,
        (layout) => const Center(
          child: Glass(
            padding: EdgeInsets.all(12),
            child: Text('Floating'),
          ),
        ),
        check: (layout) async {
          expect(find.text('Floating'), findsOneWidget);
        },
      );
    });

    testWidgets("tints with the theme's card colour at the regular opacity", (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pumpUna(
          tester,
          const Center(child: Glass(child: Text('Hi'))),
          theme: ThemeData(brightness: brightness),
        );
        final theme = themeOf(tester, find.byType(Glass));
        final expected = brightness == Brightness.dark ? .66 : .7;

        expect(
          surfaceOf(tester).color,
          theme.colorScheme.card.withValues(alpha: expected),
          reason: '$brightness',
        );
      }
    });

    testWidgets('the strong level is heavier but still not opaque', (
      tester,
    ) async {
      await pumpUna(
        tester,
        const Center(
          child: Glass(level: GlassLevel.strong, child: Text('Hi')),
        ),
      );
      final theme = themeOf(tester, find.byType(Glass));
      final tint = surfaceOf(tester).color!;

      expect(tint, theme.colorScheme.card.withValues(alpha: .9));
      expect(tint.a, lessThan(1));
    });

    testWidgets("the bar level is the bottom bar's glass: its tint frosted, "
        "and on Liquid Glass the theme's glass with nothing of its own", (
      tester,
    ) async {
      await pumpUna(
        tester,
        const Center(
          child: Glass(level: GlassLevel.bar, child: Text('Hi')),
        ),
      );
      final theme = themeOf(tester, find.byType(Glass));
      expect(
        surfaceOf(tester).color,
        theme.bottomNavigationBarTheme.backgroundColor,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpUna(
          tester,
          const Center(
            child: Glass(level: GlassLevel.bar, child: Text('Hi')),
          ),
          formFactor: FormFactor.mobile,
        );
        final surface = tester.widget<LiquidGlassSurface>(
          find.byType(LiquidGlassSurface),
        );
        expect(surface.tint, isNull);
        expect(surface.blur, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets("a translucent card colour keeps its own alpha: the level's "
        'opacity multiplies it', (tester) async {
      const card = Color(0x80ffffff);
      for (final (level, opacity) in [
        (GlassLevel.regular, .7),
        (GlassLevel.strong, .9),
      ]) {
        await pumpUna(
          tester,
          Center(
            child: Glass(level: level, child: const Text('Hi')),
          ),
          theme: ThemeData(
            colorScheme: const OceanColorScheme.light().copyWith(card: card),
          ),
        );
        final theme = themeOf(tester, find.byType(Glass));
        expect(theme.colorScheme.card, card);
        expect(theme.glassTheme.color, card);

        final tint = surfaceOf(tester).color!;
        // Half of the level's opacity, not the level's opacity outright.
        expect(tint.a, closeTo(card.a * opacity, 1e-6), reason: level.name);
        expect(tint.a, lessThan(card.a), reason: level.name);
        expect(tint.withValues(alpha: 1), card.withValues(alpha: 1));
      }
    });

    testWidgets("a translucent GlassTheme colour is multiplied by the theme's "
        'opacities too', (tester) async {
      const colour = Color(0x40102030);
      for (final (level, opacity) in [
        (GlassLevel.regular, .5),
        (GlassLevel.strong, .8),
      ]) {
        await pumpUna(
          tester,
          Center(
            child: Glass(level: level, child: const Text('Hi')),
          ),
          theme: ThemeData(
            glassTheme: const GlassTheme(
              color: colour,
              opacity: .5,
              strongOpacity: .8,
            ),
          ),
        );
        final tint = surfaceOf(tester).color!;
        expect(tint.a, closeTo(colour.a * opacity, 1e-6), reason: level.name);
        expect(tint.withValues(alpha: 1), colour.withValues(alpha: 1));
      }
    });

    testWidgets('an opaque card colour gives exactly the level opacity', (
      tester,
    ) async {
      await pumpUna(tester, const Center(child: Glass(child: Text('Hi'))));
      final theme = themeOf(tester, find.byType(Glass));
      expect(theme.colorScheme.card.a, 1);
      expect(
        surfaceOf(tester).color!.a,
        closeTo(theme.glassTheme.opacity!, 1e-6),
      );
    });

    testWidgets('an explicit colour is used at its own alpha', (tester) async {
      const scrim = Color(0x52090909);
      await pumpUna(
        tester,
        const Center(
          child: Glass(
            color: scrim,
            // Ignored once a colour is given.
            level: GlassLevel.strong,
            child: Text('Hi'),
          ),
        ),
      );
      expect(surfaceOf(tester).color, scrim);
    });

    testWidgets('blurs and saturates its backdrop from the theme', (
      tester,
    ) async {
      await pumpUna(tester, const Center(child: Glass(child: Text('Hi'))));

      final filter = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(Glass),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(
        filter.filter,
        same(Backdrop.filterFor(blur: 24, saturation: 1.6)),
      );
    });

    testWidgets('blur and saturation can be set per surface', (tester) async {
      await pumpUna(
        tester,
        const Center(child: Glass(blur: 6, saturation: 1, child: Text('Hi'))),
      );
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter,
        same(Backdrop.filterFor(blur: 6)),
      );

      // With both neutral there is no backdrop layer at all, only the tint.
      await pumpUna(
        tester,
        const Center(child: Glass(blur: 0, saturation: 1, child: Text('Hi'))),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(surfaceOf(tester).color, isNotNull);
    });

    testWidgets("the filter is clipped to the surface's corners", (
      tester,
    ) async {
      await pumpUna(tester, const Center(child: Glass(child: Text('Hi'))));
      final theme = themeOf(tester, find.byType(Glass));
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(Glass),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, theme.glassTheme.borderRadius);
      expect(surfaceOf(tester).borderRadius, theme.glassTheme.borderRadius);

      const custom = BorderRadius.all(Radius.circular(3));
      await pumpUna(
        tester,
        const Center(
          child: Glass(borderRadius: custom, child: Text('Hi')),
        ),
      );
      expect(
        tester
            .widget<ClipRRect>(
              find.descendant(
                of: find.byType(Glass),
                matching: find.byType(ClipRRect),
              ),
            )
            .borderRadius,
        custom,
      );
      expect(surfaceOf(tester).borderRadius, custom);
    });

    testWidgets("draws a hairline in the theme's glass border colour", (
      tester,
    ) async {
      await pumpUna(tester, const Center(child: Glass(child: Text('Hi'))));
      final theme = themeOf(tester, find.byType(Glass));
      final border = surfaceOf(tester).border! as Border;
      expect(border.top.color, theme.colorScheme.border);
      expect(border.top.width, 1);
      expect(border.isUniform, isTrue);
    });

    testWidgets('a border of none removes the hairline', (tester) async {
      await pumpUna(
        tester,
        const Center(
          child: Glass(
            width: 100,
            height: 60,
            border: Border.fromBorderSide(BorderSide.none),
            child: SizedBox.expand(key: Key('fill')),
          ),
        ),
      );
      expect(
        (surfaceOf(tester).border! as Border).top.style,
        BorderStyle.none,
      );
      // With no border the content gets the whole box.
      expect(
        tester.getSize(find.byKey(const Key('fill'))),
        const Size(100, 60),
      );
    });

    testWidgets('width, height and padding are border-box', (tester) async {
      await pumpUna(
        tester,
        const Center(
          child: Glass(
            width: 120,
            height: 80,
            padding: EdgeInsets.all(10),
            child: SizedBox.expand(key: Key('fill')),
          ),
        ),
      );
      expect(tester.getSize(find.byType(Glass)), const Size(120, 80));
      // 10 of padding and the 1px hairline on each side.
      expect(tester.getSize(find.byKey(const Key('fill'))), const Size(98, 58));
    });

    testWidgets('hugs its child without a size', (tester) async {
      await pumpUna(
        tester,
        const Center(
          child: Glass(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SizedBox(width: 50, height: 20),
          ),
        ),
      );
      expect(tester.getSize(find.byType(Glass)), const Size(68, 30));
    });

    testWidgets('constraints and alignment reach the surface', (tester) async {
      await pumpUna(
        tester,
        const Center(
          child: Glass(
            constraints: BoxConstraints(minWidth: 200, minHeight: 100),
            child: SizedBox(key: Key('dot'), width: 10, height: 10),
          ),
        ),
      );
      expect(tester.getSize(find.byType(Glass)), const Size(200, 100));

      await pumpUna(
        tester,
        const Center(
          child: Glass(
            width: 200,
            height: 100,
            alignment: Alignment.bottomRight,
            child: SizedBox(key: Key('dot'), width: 10, height: 10),
          ),
        ),
      );
      final glass = tester.getRect(find.byType(Glass));
      final dot = tester.getRect(find.byKey(const Key('dot')));
      expect(glass.size, const Size(200, 100));
      // Inside the hairline.
      expect(dot.right, glass.right - 1);
      expect(dot.bottom, glass.bottom - 1);
    });

    testWidgets('casts no shadow unless given one', (tester) async {
      await pumpUna(tester, const Center(child: Glass(child: Text('Hi'))));
      expect(
        find.descendant(
          of: find.byType(Glass),
          matching: find.byType(DecoratedBox),
        ),
        // Only the Container's own decoration.
        findsOneWidget,
      );
    });

    testWidgets('shadows are painted outside the surface, never under the '
        'glass', (tester) async {
      const shadows = [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ];
      await pumpUna(
        tester,
        const Center(
          child: Glass(shadows: shadows, child: SizedBox.square(dimension: 50)),
        ),
      );
      final theme = themeOf(tester, find.byType(Glass));

      // Carried by a `ShadowDecoration`, which clips them to the outside of
      // the surface's outline — a raw `BoxShadow` would show through the
      // translucent tint.
      final outer = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(Glass),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(outer.decoration, isA<ShadowDecoration>());
      expect(shadowsOf(outer.decoration), shadows);
      expect(
        boxDecorationOf(outer.decoration)!.borderRadius,
        theme.glassTheme.borderRadius,
      );
      // The tinted surface itself carries none.
      expect(surfaceOf(tester).boxShadow, isNull);
      // And the shadow takes no space.
      expect(tester.getSize(find.byType(Glass)), const Size.square(52));
    });

    testWidgets('follows a theme override', (tester) async {
      await pumpUna(
        tester,
        const Center(child: Glass(child: Text('Hi'))),
        theme: ThemeData(
          glassTheme: const GlassTheme(
            color: Color(0xff102030),
            opacity: .5,
            borderColor: Color(0xff405060),
            borderWidth: 3,
            borderRadius: BorderRadius.all(Radius.circular(7)),
            blur: 0,
            saturation: 1,
          ),
        ),
      );
      final decoration = surfaceOf(tester);
      expect(decoration.color, const Color(0xff102030).withValues(alpha: .5));
      expect((decoration.border! as Border).top.color, const Color(0xff405060));
      expect((decoration.border! as Border).top.width, 3);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(7)),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('with no child it is still a surface', (tester) async {
      await pumpUna(
        tester,
        const Center(child: Glass(width: 40, height: 40)),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Glass)), const Size.square(40));
    });
  });
}

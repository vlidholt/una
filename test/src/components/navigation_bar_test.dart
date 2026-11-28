import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/utils/moving_indicator.dart';
import 'package:una/una.dart';

import '../../decoration_finders.dart';
import '../../una_harness.dart';

/// Icons are told apart by key: `home` / `home-selected`, and so on.
List<NavigationDestination> destinations(
  int count, {
  Map<int, int> badgeCounts = const {},
  Set<int> dots = const {},
}) {
  const names = ['Home', 'Jobs', 'Chat', 'Me', 'More', 'Six'];
  return [
    for (var i = 0; i < count; i++)
      NavigationDestination(
        icon: Icon(PhosphorIconsRegular.house, key: Key('${names[i]}-icon')),
        selectedIcon: Icon(
          PhosphorIconsFill.house,
          key: Key('${names[i]}-selected'),
        ),
        label: names[i],
        badgeCount: badgeCounts[i],
        showBadge: dots.contains(i),
      ),
  ];
}

/// The badges that show: every destination carries one, hidden until it has
/// something to say, so that it can pop in.
Iterable<IndicatorBadge> shownBadges(WidgetTester tester) => tester
    .widgetList<IndicatorBadge>(find.byType(IndicatorBadge))
    .where((badge) => badge.visible);

/// The travelling selection indicator of the bar of type [bar].
RenderMovingIndicator movingIndicator(WidgetTester tester, Type bar) =>
    tester.renderObject<RenderMovingIndicator>(
      find.descendant(
        of: find.byType(bar),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_MovingIndicatorRenderWidget',
        ),
      ),
    );

void main() {
  group('NavigationBarTheme', () {
    test('is fed by the style and the scheme', () {
      for (final brightness in Brightness.values) {
        final theme = ThemeData(brightness: brightness);
        final nav = theme.navigationBarTheme;
        final s = theme.colorScheme;
        expect(nav.itemWidth, 88);
        expect(nav.iconSize, 24);
        expect(nav.gap, 4);
        expect(nav.labelStyle!.fontSize, 12);
        expect(nav.labelStyle!.fontWeight, FontWeight.w500);
        expect(nav.labelStyle!.height, 1);
        expect(nav.foregroundColor, s.mutedForeground);
        expect(nav.selectedIconColor, s.tint);
        expect(nav.selectedLabelColor, s.foreground);
        expect(nav.hoverColor, s.foreground);
        expect(nav.indicatorColor, s.tint);
        expect(nav.indicatorHeight, 3);
        expect(nav.indicatorInset, 12);
      }
    });
  });

  group('NavigationBar', () {
    Widget bar({
      int count = 4,
      int? selectedIndex = 0,
      ValueChanged<int>? onDestinationSelected,
      double? height,
      Map<int, int> badgeCounts = const {},
      Set<int> dots = const {},
    }) {
      return Center(
        child: NavigationBar(
          destinations: destinations(
            count,
            badgeCounts: badgeCounts,
            dots: dots,
          ),
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          height: height,
        ),
      );
    }

    Finder item(int i) => find
        .descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(Pressable),
        )
        .at(i);

    /// Where the line under the selected destination is painted, in global
    /// coordinates, or null when there is none. The line is one shape, drawn
    /// by the bar, that travels between the destinations.
    Rect? indicator(WidgetTester tester) {
      final render = movingIndicator(tester, NavigationBar);
      final rect = render.indicatorRect;
      if (rect == null) return null;
      return MatrixUtils.transformRect(render.getTransformTo(null), rect);
    }

    /// What the line looks like on the selected destination.
    BoxDecoration indicatorDecoration(WidgetTester tester) =>
        tester
                .renderObjectList<RenderMovingIndicatorTarget>(
                  find.byType(MovingIndicatorTarget),
                )
                .singleWhere((target) => target.selected)
                .decoration
            as BoxDecoration;

    Color iconColor(WidgetTester tester, String key) =>
        IconTheme.of(tester.element(find.byKey(Key(key)))).color!;

    Color labelColor(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;

    testWidgets('renders in both form factors and text directions', (
      tester,
    ) async {
      await expectBuildsInEveryLayout(
        tester,
        (layout) => bar(
          onDestinationSelected: (_) {},
          badgeCounts: const {2: 120},
          dots: const {3},
        ),
      );
    });

    testWidgets('each destination is the theme width and the app bar height', (
      tester,
    ) async {
      for (final formFactor in FormFactor.values) {
        await pumpUna(tester, bar(), formFactor: formFactor);
        final theme = themeOf(tester, find.byType(NavigationBar));
        final height = formFactor == FormFactor.mobile ? 44.0 : 64.0;
        expect(theme.appBarTheme.height, height);
        expect(
          tester.getSize(find.byType(NavigationBar)),
          Size(88 * 4, height),
        );
        for (var i = 0; i < 4; i++) {
          expect(tester.getSize(item(i)), Size(88, height));
        }
      }
    });

    testWidgets('height overrides the app bar height', (tester) async {
      await pumpUna(tester, bar(height: 48));
      expect(tester.getSize(find.byType(NavigationBar)).height, 48);
    });

    testWidgets('lays the destinations out in reading order', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpUna(tester, bar(), textDirection: direction);
        final first = tester.getRect(item(0));
        final last = tester.getRect(item(3));
        if (direction == TextDirection.ltr) {
          expect(first.left, lessThan(last.left));
        } else {
          expect(first.left, greaterThan(last.left));
        }
      }
    });

    testWidgets('stacks a 24px icon over its label, centred', (tester) async {
      await pumpUna(tester, bar());
      final cell = tester.getRect(item(1));
      final icon = tester.getRect(find.byKey(const Key('Jobs-icon')));
      final label = tester.getRect(find.text('Jobs'));

      expect(icon.size, const Size.square(24));
      expect(icon.center.dx, closeTo(cell.center.dx, .5));
      expect(label.center.dx, closeTo(cell.center.dx, .5));
      // 4 between them, and the pair is centred in the bar.
      expect(label.top, icon.bottom + 4);
      expect(
        (icon.top + label.bottom) / 2,
        closeTo(cell.center.dy, .5),
      );
    });

    testWidgets('a label wider than its cell truncates', (tester) async {
      await pumpUna(
        tester,
        const Center(
          child: NavigationBar(
            selectedIndex: 0,
            destinations: [
              NavigationDestination(
                icon: Icon(PhosphorIconsRegular.house),
                label: 'Notifications and more',
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('Notifications and more'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(find.text('Notifications and more')).width,
        lessThanOrEqualTo(88),
      );
    });

    testWidgets("a tap reports the destination's index", (tester) async {
      final taps = <int>[];
      await pumpUna(tester, bar(onDestinationSelected: taps.add));
      await tester.tap(find.text('Chat'));
      await tester.tap(find.byKey(const Key('Me-icon')));
      // Anywhere in the cell.
      await tester.tapAt(tester.getRect(item(1)).topLeft + const Offset(3, 3));
      expect(taps, [2, 3, 1]);
    });

    testWidgets('the keyboard reaches and activates each destination', (
      tester,
    ) async {
      final taps = <int>[];
      await pumpUna(tester, bar(onDestinationSelected: taps.add));
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(
          i.isEven ? LogicalKeyboardKey.enter : LogicalKeyboardKey.space,
        );
      }
      expect(taps, [0, 1, 2]);
    });

    testWidgets('without a callback the destinations are inert', (
      tester,
    ) async {
      await pumpUna(tester, bar());
      await tester.tap(find.text('Chat'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the selected destination takes the tint, the selected icon '
        'and a foreground label', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpUna(
          tester,
          bar(selectedIndex: 1, onDestinationSelected: (_) {}),
          theme: ThemeData(brightness: brightness),
        );
        final s = themeOf(tester, find.byType(NavigationBar)).colorScheme;

        expect(find.byKey(const Key('Jobs-selected')), findsOneWidget);
        expect(find.byKey(const Key('Jobs-icon')), findsNothing);
        expect(iconColor(tester, 'Jobs-selected'), s.tint);
        expect(labelColor(tester, 'Jobs'), s.foreground);
        // Everything else rests in the muted foreground, with its plain
        // icon.
        for (final other in ['Home', 'Chat', 'Me']) {
          expect(find.byKey(Key('$other-icon')), findsOneWidget);
          expect(find.byKey(Key('$other-selected')), findsNothing);
          expect(iconColor(tester, '$other-icon'), s.mutedForeground);
          expect(labelColor(tester, other), s.mutedForeground);
        }
      }
    });

    testWidgets('moving the selection moves the colours and the icon', (
      tester,
    ) async {
      await pumpUna(tester, bar());
      final selected = iconColor(tester, 'Home-selected');
      final resting = iconColor(tester, 'Chat-icon');
      expect(selected, isNot(resting));

      await pumpUna(tester, bar(selectedIndex: 2));
      expect(iconColor(tester, 'Chat-selected'), selected);
      expect(iconColor(tester, 'Home-icon'), resting);
    });

    testWidgets('a destination without a selected icon keeps its icon', (
      tester,
    ) async {
      await pumpUna(
        tester,
        const Center(
          child: NavigationBar(
            selectedIndex: 0,
            destinations: [
              NavigationDestination(
                icon: Icon(PhosphorIconsRegular.house, key: Key('only')),
                label: 'Home',
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(const Key('only')), findsOneWidget);
    });

    testWidgets('hover brings a resting destination to the foreground', (
      tester,
    ) async {
      useTraditionalHighlights();
      await pumpUna(tester, bar(onDestinationSelected: (_) {}));
      final s = themeOf(tester, find.byType(NavigationBar)).colorScheme;

      final gesture = await hoverAt(tester, tester.getCenter(item(2)));
      // The colours fade.
      await settle(tester);
      expect(iconColor(tester, 'Chat-icon'), s.foreground);
      expect(labelColor(tester, 'Chat'), s.foreground);
      // The selected one is unaffected by where the pointer is.
      expect(iconColor(tester, 'Home-selected'), s.tint);

      await gesture.moveTo(Offset.zero);
      await settle(tester);
      expect(iconColor(tester, 'Chat-icon'), s.mutedForeground);
    });

    testWidgets('draws one indicator under the selected destination', (
      tester,
    ) async {
      for (final direction in TextDirection.values) {
        for (var selected = 0; selected < 4; selected++) {
          await pumpUna(
            tester,
            bar(selectedIndex: selected),
            textDirection: direction,
          );
          final theme = themeOf(tester, find.byType(NavigationBar));
          final cell = tester.getRect(item(selected));
          final line = indicator(tester)!;
          // Inset 12 from each side of the cell, 3 tall.
          expect(line.left, closeTo(cell.left + 12, .1));
          expect(line.right, closeTo(cell.right - 12, .1));
          expect(line.height, closeTo(3, .1));
          expect(indicatorDecoration(tester).color, theme.colorScheme.tint);
        }
      }
    });

    testWidgets('no selection, or one out of range, draws no indicator', (
      tester,
    ) async {
      for (final selected in [null, -1, 9]) {
        await pumpUna(tester, bar(selectedIndex: selected));
        expect(indicator(tester), isNull, reason: '$selected');
        expect(tester.takeException(), isNull);
        // And nothing is tinted.
        expect(find.byKey(const Key('Home-selected')), findsNothing);
      }
    });

    testWidgets("in an app bar the indicator sits on the bar's bottom edge, "
        'over its hairline', (tester) async {
      await pumpUna(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: AppBar(
            primary: false,
            middle: NavigationBar(
              selectedIndex: 1,
              destinations: destinations(4),
            ),
          ),
        ),
      );
      final appBar = tester.getRect(find.byType(AppBar));
      final line = indicator(tester)!;
      expect(line.bottom, closeTo(appBar.bottom, .1));
      expect(line.top, closeTo(appBar.bottom - 3, .1));
      // The navigation bar is centred in the app bar.
      expect(
        tester.getCenter(find.byType(NavigationBar)).dx,
        closeTo(appBar.center.dx, .5),
      );
    });

    testWidgets('a badge count shows on the icon; zero shows none', (
      tester,
    ) async {
      await pumpUna(
        tester,
        bar(badgeCounts: const {1: 3, 2: 0, 3: 250}),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(shownBadges(tester), hasLength(2));
      expect(tester.takeException(), isNull);
      // The badge is pinned to the icon, not the cell.
      final icon = tester.getRect(find.byKey(const Key('Jobs-icon')));
      final badge = tester.getRect(find.text('3'));
      expect(badge.center.dx, greaterThan(icon.center.dx));
      expect(badge.center.dy, lessThan(icon.center.dy));
      // A 99+ pill on a 24px icon keeps its digits.
      expect(
        tester.getSize(find.text('99+')).width,
        greaterThan(tester.getSize(find.text('3')).width * 2),
      );
    });

    testWidgets('showBadge shows a dot when there is no count', (
      tester,
    ) async {
      await pumpUna(tester, bar(dots: const {2}));
      final badge = shownBadges(tester).single;
      expect(badge.count, isNull);
      expect(
        find.descendant(
          of: find.byType(IndicatorBadge),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('a count wins over the dot', (tester) async {
      await pumpUna(
        tester,
        bar(badgeCounts: const {2: 5}, dots: const {2}),
      );
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('keyboard focus rings the focused destination only', (
      tester,
    ) async {
      useTraditionalHighlights();
      await pumpUna(tester, bar(onDestinationSelected: (_) {}));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester
            .widgetList<FocusRing>(find.byType(FocusRing))
            .map((r) => r.visible),
        [false, true, false, false],
      );
      // Inside the destination's bounds: the app bar clips for its backdrop
      // blur, which would cut an outside ring off.
      expect(
        tester
            .widgetList<FocusRing>(find.byType(FocusRing))
            .every((r) => r.inset),
        isTrue,
      );
    });

    testWidgets('each destination is a labelled button; the selected one '
        'says so', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUna(
        tester,
        bar(selectedIndex: 2, onDestinationSelected: (_) {}),
      );
      const names = ['Home', 'Jobs', 'Chat', 'Me'];
      for (var i = 0; i < 4; i++) {
        final data = tester.getSemantics(item(i)).getSemanticsData();
        expect(data.label, names[i]);
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
        // A destination is one of a set: each says whether it is the
        // selected one.
        expect(
          data.flagsCollection.isSelected,
          i == 2 ? ui.Tristate.isTrue : ui.Tristate.isFalse,
        );
      }
      handle.dispose();
    });

    testWidgets('follows a theme override', (tester) async {
      const colour = Color(0xffcc5500);
      await pumpUna(
        tester,
        bar(),
        theme: ThemeData(
          navigationBarTheme: const NavigationBarTheme(
            itemWidth: 60,
            iconSize: 18,
            selectedIconColor: colour,
            indicatorColor: colour,
            indicatorHeight: 5,
            indicatorInset: 4,
          ),
        ),
      );
      expect(tester.getSize(item(0)).width, 60);
      expect(
        tester.getSize(find.byKey(const Key('Home-selected'))),
        const Size.square(18),
      );
      expect(iconColor(tester, 'Home-selected'), colour);
      final line = indicator(tester)!;
      expect(line.height, closeTo(5, .1));
      expect(line.width, closeTo(52, .1));
      expect(indicatorDecoration(tester).color, colour);
    });
  });

  group('BottomNavigationBarTheme', () {
    test('is a floating glass pill in the una style', () {
      for (final brightness in Brightness.values) {
        final theme = ThemeData(
          brightness: brightness,
          formFactor: FormFactor.mobile,
        );
        final bar = theme.bottomNavigationBarTheme;
        final s = theme.colorScheme;
        expect(bar.floating, isTrue);
        expect(bar.itemWidth, 52);
        expect(bar.itemHeight, 52);
        expect(bar.iconSize, 26);
        expect(bar.actionIconSize, 22);
        expect(bar.padding, const EdgeInsets.all(6));
        expect(bar.margin, const EdgeInsets.only(bottom: 22));
        expect(bar.gap, 4);
        expect(bar.borderRadius, theme.radii.full);
        expect(bar.backgroundColor!.a, lessThan(1));
        expect(bar.blur, 24);
        expect(bar.saturation, 1.6);
        if (brightness == Brightness.light) {
          // On the light page a white pill and its shadow are enough.
          expect(bar.backgroundColor!.withValues(alpha: 1), s.bar);
          expect(bar.borderColor, s.border);
          expect(bar.rimColor, isNull);
          expect(bar.shadows, theme.style.floatingShadow);
        } else {
          // On the dark page the bar is lifted toward the foreground, a
          // little thinner, and outlined in a brighter hairline with a lit
          // top edge; see "the dark bar stands off the dark page" below.
          expect(
            bar.backgroundColor,
            Color.alphaBlend(
              s.foreground.withValues(alpha: .08),
              s.bar,
            ).withValues(alpha: .84),
          );
          expect(bar.borderColor, s.foreground.withValues(alpha: .12));
          expect(bar.rimColor, s.foreground.withValues(alpha: .26));
          expect(bar.shadows, theme.style.floatingShadowDark);
          expect(bar.shadows, isNot(theme.style.floatingShadow));
        }
        expect(bar.foregroundColor, s.foregroundSubtle);
        expect(bar.selectedForegroundColor, s.tint);
        expect(bar.selectedBackgroundColor, s.accent);
        expect(bar.actionBackgroundColor, s.primary);
        expect(bar.actionForegroundColor, s.primaryForeground);
      }
    });
  });

  group('the floating bar on a dark page', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + .05) / (lo + .05);
    }

    Color over(Color color, Color backdrop) =>
        Color.alphaBlend(color, backdrop);

    ThemeData dark() =>
        ThemeData(brightness: Brightness.dark, formFactor: FormFactor.mobile);

    test('is told from the page and from a card by its fill and its rim', () {
      final theme = dark();
      final s = theme.colorScheme;
      final bar = theme.bottomNavigationBarTheme;
      for (final (name, backdrop) in [
        ('the page', s.background),
        ('a card', over(theme.cardTheme.backgroundColor!, s.background)),
      ]) {
        final fill = over(bar.backgroundColor!, backdrop);
        // The plain bar colour at the bar opacity is a shade from the page
        // (1.03:1) and *under* a card; lifted, the fill alone reads over
        // both…
        final before = over(s.bar.withValues(alpha: .95), backdrop);
        expect(
          contrast(fill, backdrop),
          greaterThan(1.12),
          reason: 'the fill on $name',
        );
        expect(
          contrast(fill, backdrop),
          greaterThan(contrast(before, backdrop) + .05),
          reason: 'the fill on $name, against what it was',
        );
        // …the hairline reads on the fill and on the backdrop, and its top
        // edge more than the rest of it.
        final hairline = over(bar.borderColor!, fill);
        final rim = over(bar.rimColor!, fill);
        expect(contrast(hairline, backdrop), greaterThan(1.5), reason: name);
        expect(contrast(rim, backdrop), greaterThan(2.2), reason: name);
        expect(contrast(rim, fill), greaterThan(contrast(hairline, fill)));
        // It is still glass, and still quiet: nowhere near a light surface.
        expect(bar.backgroundColor!.a, inInclusiveRange(.75, .9));
        expect(bar.blur, greaterThan(0));
        expect(contrast(fill, backdrop), lessThan(1.6), reason: name);
        expect(bar.rimColor!.a, lessThanOrEqualTo(.3));
        expect(bar.borderColor!.a, inInclusiveRange(.1, .14));
      }
      // The shadow is deeper and reaches further than the light one.
      final shadows = bar.shadows!;
      expect(shadows, theme.style.floatingShadowDark);
      expect(
        shadows.last.color.a,
        greaterThan(theme.style.floatingShadow.last.color.a * 2),
      );
      expect(
        shadows.last.spreadRadius,
        greaterThan(theme.style.floatingShadow.last.spreadRadius),
      );
    });

    test('its icons, its lens and its action read on it', () {
      final theme = dark();
      final s = theme.colorScheme;
      final bar = theme.bottomNavigationBarTheme;
      // Over the page, and over the darkest and the brightest thing that
      // can scroll under glass.
      for (final backdrop in [
        s.background,
        const Color(0xff000000),
        const Color(0xffffffff),
      ]) {
        final fill = over(bar.backgroundColor!, backdrop);
        final lens = over(bar.selectedBackgroundColor!, fill);
        expect(
          contrast(bar.foregroundColor!, fill),
          greaterThanOrEqualTo(4.5),
          reason: 'an unselected icon over $backdrop',
        );
        expect(
          contrast(bar.selectedForegroundColor!, lens),
          greaterThanOrEqualTo(3),
          reason: 'the selected icon on its lens over $backdrop',
        );
        if (backdrop == s.background) {
          expect(contrast(lens, fill), greaterThan(1.15), reason: 'the lens');
        }
        expect(
          contrast(bar.actionForegroundColor!, bar.actionBackgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(bar.actionBackgroundColor!, fill),
          greaterThan(1.3),
          reason: 'the action over $backdrop',
        );
      }
    });

    test('it is never thicker than the other bars, and solid when they '
        'are', () {
      ThemeData withBars(double opacity) => ThemeData(
        brightness: Brightness.dark,
        formFactor: FormFactor.mobile,
        style: StyleTokens.fluid.copyWith(
          barOpacity: opacity,
          barOpacityDark: opacity,
        ),
      );
      // Solid bars: `barOpacity` is the one switch, for this bar too.
      final solid = withBars(1).bottomNavigationBarTheme;
      expect(solid.backgroundColor!.a, 1);
      expect(solid.blur, 0);
      // Thinner bars than the pill asks for: it follows them down.
      expect(
        withBars(.5).bottomNavigationBarTheme.backgroundColor!.a,
        closeTo(.5, .001),
      );
      // Thicker: it keeps its own.
      expect(
        withBars(.98).bottomNavigationBarTheme.backgroundColor!.a,
        closeTo(.84, .001),
      );
    });

    test('the light bar and the shadcn styles are as they were', () {
      final light = ThemeData(formFactor: FormFactor.mobile);
      final bar = light.bottomNavigationBarTheme;
      expect(
        bar.backgroundColor,
        light.colorScheme.bar.withValues(alpha: .94),
      );
      expect(bar.borderColor, light.colorScheme.border);
      expect(bar.rimColor, isNull);
      for (final style in [
        StyleTokens.crisp,
        StyleTokens.pebble,
        StyleTokens.sharp,
      ]) {
        for (final brightness in Brightness.values) {
          final theme = ThemeData(
            style: style,
            brightness: brightness,
            formFactor: FormFactor.mobile,
            colorScheme: brightness == Brightness.dark
                ? const GraphiteColorScheme.dark()
                : const GraphiteColorScheme.light(),
          );
          final bar = theme.bottomNavigationBarTheme;
          expect(bar.backgroundColor, theme.colorScheme.bar);
          expect(bar.borderColor, theme.colorScheme.border);
          expect(bar.rimColor, isNull);
          expect(bar.shadows, style.floatingShadow);
        }
      }
    });

    testWidgets('the rim is painted along the top edge, and the shadow is '
        'outside the pill', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 300);
      addTearDown(tester.view.reset);
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);
      final theme = dark();
      final page = theme.colorScheme.background;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UnaApp(
            theme: theme,
            darkTheme: theme,
            home: ColoredBox(
              color: page,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: BottomNavigationBar(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  destinations: destinations(4),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final pill = tester.getRect(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byType(ClipRRect),
        ),
      );
      late ui.Image image;
      late ByteData data;
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()!;
        image = await (boundary as RenderRepaintBoundary).toImage();
        data = (await image.toByteData())!;
      });
      Color at(Offset p) {
        final i = (p.dy.floor() * image.width + p.dx.floor()) * 4;
        return Color.fromARGB(
          255,
          data.getUint8(i),
          data.getUint8(i + 1),
          data.getUint8(i + 2),
        );
      }

      final bar = theme.bottomNavigationBarTheme;
      // Between two destinations, clear of the lens and the icons.
      final x = pill.center.dx;
      final inside = at(Offset(x, pill.center.dy));
      final top = at(Offset(x, pill.top + .5));
      final bottom = at(Offset(x, pill.bottom - .5));
      final under = at(Offset(x, pill.bottom + 6));
      final far = at(const Offset(20, 20));

      // The glass is its tint over the page and nothing else: no shadow
      // behind it.
      final fill = Color.alphaBlend(bar.backgroundColor!, page);
      for (final (seen, wanted) in [
        (inside.r, fill.r),
        (inside.g, fill.g),
        (inside.b, fill.b),
      ]) {
        // Within a rounding step of the blend, twice over.
        expect((seen - wanted).abs() * 255, lessThanOrEqualTo(2));
      }
      expect(far, page);
      // Lighter than the page; the hairline lighter than the bar; its top
      // edge the lightest thing about it.
      expect(contrast(inside, page), greaterThan(1.12));
      expect(bottom.computeLuminance(), greaterThan(inside.computeLuminance()));
      expect(top.computeLuminance(), greaterThan(bottom.computeLuminance()));
      // And the page under it is darker than the page elsewhere.
      expect(under.computeLuminance(), lessThan(page.computeLuminance()));
      image.dispose();
    });
  });

  group('BottomNavigationBar', () {
    Widget bar({
      int count = 4,
      int? selectedIndex = 0,
      ValueChanged<int>? onDestinationSelected,
      NavigationAction? action,
      bool? floating,
      bool? showLabels,
      Map<int, int> badgeCounts = const {},
      double bottomInset = 0,
    }) {
      return MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: BottomNavigationBar(
            destinations: destinations(count, badgeCounts: badgeCounts),
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            action: action,
            floating: floating,
            showLabels: showLabels,
          ),
        ),
      );
    }

    testWidgets('floating with labels, the lens takes in the label too; '
        'docked, it is behind the icon only', (tester) async {
      Rect lens() => tester.getRect(
        find.byWidgetPredicate(
          (w) => w is MovingIndicatorTarget && w.selected,
        ),
      );
      await pumpUna(
        tester,
        bar(floating: true, showLabels: true),
        formFactor: FormFactor.mobile,
      );
      final label = tester.getRect(find.text('Home'));
      expect(lens().top, lessThan(label.top));
      expect(lens().bottom, greaterThanOrEqualTo(label.bottom));

      await pumpUna(
        tester,
        bar(floating: false, showLabels: true),
        formFactor: FormFactor.mobile,
      );
      expect(
        lens().bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Home')).top),
      );
    });

    NavigationAction action([VoidCallback? onPressed]) => NavigationAction(
      icon: const Icon(PhosphorIconsRegular.plus, key: Key('action-icon')),
      label: 'Create post',
      onPressed: onPressed ?? () {},
    );

    Finder items() => find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.byType(Pressable),
    );

    /// The bar's own surface: the pill, or the full-width strip.
    Finder surface() => find
        .descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w is! AnimatedContainer,
          ),
        )
        .first;

    /// The fill behind item [i]: the lens when it is the selected
    /// destination — one pill, painted by the bar, that travels between
    /// them — and otherwise the item's own (its hover wash, or the action's
    /// colour).
    BoxDecoration itemBox(WidgetTester tester, int i) {
      final target = find.ancestor(
        of: items().at(i),
        matching: find.byType(MovingIndicatorTarget),
      );
      if (target.evaluate().isNotEmpty) {
        final lens = tester.widget<MovingIndicatorTarget>(target.first);
        if (lens.selected) return lens.decoration as BoxDecoration;
      }
      final fill = tester.widget<AnimatedFill>(
        find.descendant(
          of: items().at(i),
          matching: find.byType(AnimatedFill),
        ),
      );
      return BoxDecoration(
        color: fill.color,
        borderRadius: fill.borderRadius,
      );
    }

    Color iconColor(WidgetTester tester, String key) =>
        IconTheme.of(tester.element(find.byKey(Key(key)))).color!;

    testWidgets('renders in both form factors and text directions, floating '
        'and docked', (tester) async {
      for (final floating in [true, false]) {
        await expectBuildsInEveryLayout(
          tester,
          (layout) => bar(
            onDestinationSelected: (_) {},
            action: action(),
            floating: floating,
            badgeCounts: const {2: 120},
            bottomInset: 34,
          ),
        );
      }
    });

    testWidgets('floating: a pill as wide as its destinations, centred above '
        'the bottom edge', (tester) async {
      await pumpUna(tester, bar(), formFactor: FormFactor.mobile);
      final screen = tester.getRect(find.byType(MediaQuery).first);
      final pill = tester.getRect(surface());

      // Four 52px items, three 4px gaps, 6 of padding and a 1px outline all
      // round.
      expect(pill.width, 52 * 4 + 4 * 3 + 12 + 2);
      expect(pill.height, 52 + 12 + 2);
      expect(pill.center.dx, closeTo(screen.center.dx, .5));
      // The theme's 22px margin under it.
      expect(pill.bottom, 844 - 22);
      for (var i = 0; i < 4; i++) {
        expect(tester.getSize(items().at(i)), const Size(52, 52));
      }
    });

    testWidgets('floating: keeps clear of the bottom safe area', (
      tester,
    ) async {
      await pumpUna(
        tester,
        bar(bottomInset: 34),
        formFactor: FormFactor.mobile,
      );
      expect(tester.getRect(surface()).bottom, 844 - 22 - 34);
    });

    testWidgets('floating: is fully rounded, outlined and shadowed', (
      tester,
    ) async {
      await pumpUna(tester, bar(), formFactor: FormFactor.mobile);
      final theme = themeOf(tester, find.byType(BottomNavigationBar));
      final decoration =
          tester.widget<Container>(surface()).decoration! as BoxDecoration;

      expect(decoration.borderRadius, theme.radii.full);
      expect(decoration.color, theme.bottomNavigationBarTheme.backgroundColor);
      expect(
        (decoration.border! as Border).top.color,
        theme.colorScheme.border,
      );
      expect((decoration.border! as Border).isUniform, isTrue);
      // The shadow is carried outside the clipped glass.
      final shadow = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.byWidgetPredicate(
                (w) => w is DecoratedBox && w.decoration is ShadowDecoration,
              ),
            )
            .first,
      );
      expect(shadowsOf(shadow.decoration), theme.style.floatingShadow);
      expect(theme.style.floatingShadow, isNotEmpty);
    });

    testWidgets('blurs what scrolls beneath it while the bar is translucent', (
      tester,
    ) async {
      await pumpUna(tester, bar(), formFactor: FormFactor.mobile);
      final filter = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(
        filter.filter,
        same(Backdrop.filterFor(blur: 24, saturation: 1.6)),
      );

      // nova's bars are opaque, so there is no backdrop layer.
      await pumpUna(
        tester,
        bar(),
        formFactor: FormFactor.mobile,
        theme: ThemeData(
          style: StyleTokens.crisp,
          colorScheme: const GraphiteColorScheme.light(),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('heightOf is the height the bar takes', (tester) async {
      for (final bottomInset in [0.0, 34.0]) {
        late double reported;
        await pumpUna(
          tester,
          MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
            child: Builder(
              builder: (context) {
                reported = BottomNavigationBar.heightOf(context);
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: BottomNavigationBar(
                    destinations: destinations(4),
                    selectedIndex: 0,
                  ),
                );
              },
            ),
          ),
          formFactor: FormFactor.mobile,
        );
        // 52 + 12 of padding + 2 of outline + 22 of margin, plus the inset.
        expect(reported, 88 + bottomInset);
        expect(
          tester.getSize(find.byType(BottomNavigationBar)).height,
          reported,
        );
      }
    });

    testWidgets('heightOf matches a docked bar too', (tester) async {
      for (final bottomInset in [0.0, 34.0]) {
        late double reported;
        await pumpUna(
          tester,
          MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
            child: Builder(
              builder: (context) {
                reported = BottomNavigationBar.heightOf(context);
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: BottomNavigationBar(
                    destinations: destinations(4),
                    selectedIndex: 0,
                  ),
                );
              },
            ),
          ),
          formFactor: FormFactor.mobile,
          theme: ThemeData(
            bottomNavigationBarTheme: const BottomNavigationBarTheme(
              floating: false,
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(BottomNavigationBar)).height,
          reported,
          reason: 'inset $bottomInset',
        );
      }
    });

    testWidgets('docked: spans the width, shares it between the '
        'destinations and pads for the safe area', (tester) async {
      await pumpUna(
        tester,
        bar(floating: false, bottomInset: 34),
        formFactor: FormFactor.mobile,
      );
      final theme = themeOf(tester, find.byType(BottomNavigationBar));
      final strip = tester.getRect(find.byType(BottomNavigationBar));
      expect(strip.width, 390);
      expect(strip.bottom, 844);
      // Items, padding, a top hairline and the inset inside the strip.
      expect(strip.height, 52 + 12 + 1 + 34);

      final widths = [
        for (var i = 0; i < 4; i++) tester.getSize(items().at(i)).width,
      ];
      expect(widths.toSet(), hasLength(1));
      expect(widths.first, (390 - 12 - 3 * 4) / 4);

      final decoration =
          tester.widget<Container>(surface()).decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.zero);
      final border = decoration.border! as Border;
      expect(border.top.color, theme.colorScheme.border);
      expect(border.bottom, BorderSide.none);
      // A docked bar casts no floating shadow.
      expect(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && w.decoration is ShadowDecoration,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('lays the destinations out in reading order', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpUna(
          tester,
          bar(),
          formFactor: FormFactor.mobile,
          textDirection: direction,
        );
        final first = tester.getRect(find.byKey(const Key('Home-selected')));
        final last = tester.getRect(find.byKey(const Key('Me-icon')));
        if (direction == TextDirection.ltr) {
          expect(first.left, lessThan(last.left));
        } else {
          expect(first.left, greaterThan(last.left));
        }
      }
    });

    testWidgets("a tap reports the destination's index", (tester) async {
      final taps = <int>[];
      await pumpUna(
        tester,
        bar(onDestinationSelected: taps.add),
        formFactor: FormFactor.mobile,
      );
      await tester.tap(find.byKey(const Key('Chat-icon')));
      await tester.tap(find.byKey(const Key('Me-icon')));
      await tester.tap(find.byKey(const Key('Home-selected')));
      expect(taps, [2, 3, 0]);
    });

    testWidgets('the keyboard reaches and activates the destinations', (
      tester,
    ) async {
      final taps = <int>[];
      await pumpUna(
        tester,
        bar(onDestinationSelected: taps.add),
        formFactor: FormFactor.mobile,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, [1]);
    });

    testWidgets('the selected destination takes the accent fill, the tint '
        'and its selected icon', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpUna(
          tester,
          bar(selectedIndex: 1, onDestinationSelected: (_) {}),
          formFactor: FormFactor.mobile,
          theme: ThemeData(brightness: brightness),
        );
        final s = themeOf(tester, find.byType(BottomNavigationBar)).colorScheme;

        expect(find.byKey(const Key('Jobs-selected')), findsOneWidget);
        expect(find.byKey(const Key('Jobs-icon')), findsNothing);
        expect(itemBox(tester, 1).color, s.accent, reason: '$brightness');
        expect(iconColor(tester, 'Jobs-selected'), s.tint);
        expect(
          tester.getSize(find.byKey(const Key('Jobs-selected'))),
          const Size.square(26),
        );
        // The rest are bare icons in the subtle foreground.
        for (final (i, other) in [(0, 'Home'), (2, 'Chat'), (3, 'Me')]) {
          expect(itemBox(tester, i).color!.a, 0);
          expect(iconColor(tester, '$other-icon'), s.foregroundSubtle);
        }
      }
    });

    testWidgets('moving the selection moves the fill and the tint', (
      tester,
    ) async {
      await pumpUna(
        tester,
        bar(),
        formFactor: FormFactor.mobile,
      );
      final fill = itemBox(tester, 0).color;
      final tint = iconColor(tester, 'Home-selected');
      expect(itemBox(tester, 2).color, isNot(fill));

      await pumpUna(
        tester,
        bar(selectedIndex: 2),
        formFactor: FormFactor.mobile,
      );
      expect(itemBox(tester, 2).color, fill);
      expect(iconColor(tester, 'Chat-selected'), tint);
      expect(itemBox(tester, 0).color, isNot(fill));
    });

    testWidgets('no selection highlights nothing', (tester) async {
      await pumpUna(
        tester,
        bar(selectedIndex: null),
        formFactor: FormFactor.mobile,
      );
      for (var i = 0; i < 4; i++) {
        expect(itemBox(tester, i).color!.a, 0);
      }
    });

    testWidgets('floating items are pills', (tester) async {
      await pumpUna(tester, bar(), formFactor: FormFactor.mobile);
      final theme = themeOf(tester, find.byType(BottomNavigationBar));
      expect(itemBox(tester, 0).borderRadius, theme.radii.full);
    });

    testWidgets('the action sits between the two halves of the destinations', (
      tester,
    ) async {
      Future<List<String>> orderWith(int count) async {
        await pumpUna(
          tester,
          bar(count: count, selectedIndex: null, action: action()),
          formFactor: FormFactor.mobile,
          surfaceSize: const Size(430, 844),
        );
        expect(tester.takeException(), isNull);
        const names = ['Home', 'Jobs', 'Chat', 'Me', 'More'];
        final positions = <String, double>{
          for (var i = 0; i < count; i++)
            names[i]: tester.getCenter(find.byKey(Key('${names[i]}-icon'))).dx,
          '+': tester.getCenter(find.byKey(const Key('action-icon'))).dx,
        };
        return positions.keys.toList()
          ..sort((a, b) => positions[a]!.compareTo(positions[b]!));
      }

      expect(await orderWith(4), ['Home', 'Jobs', '+', 'Chat', 'Me']);
      expect(await orderWith(2), ['Home', '+', 'Jobs']);
      // With an odd count the extra destination goes before the action.
      expect(await orderWith(5), ['Home', 'Jobs', 'Chat', '+', 'Me', 'More']);
      expect(await orderWith(3), ['Home', 'Jobs', '+', 'Chat']);
      expect(await orderWith(1), ['Home', '+']);
    });

    testWidgets('the action is a primary-filled button that calls onPressed '
        'and shifts no index', (tester) async {
      var created = 0;
      final taps = <int>[];
      await pumpUna(
        tester,
        bar(
          onDestinationSelected: taps.add,
          action: action(() => created++),
        ),
        formFactor: FormFactor.mobile,
      );
      final s = themeOf(tester, find.byType(BottomNavigationBar)).colorScheme;

      // The action is the third pressable of five.
      expect(items(), findsNWidgets(5));
      expect(itemBox(tester, 2).color, s.primary);
      expect(iconColor(tester, 'action-icon'), s.primaryForeground);
      expect(
        tester.getSize(find.byKey(const Key('action-icon'))),
        const Size.square(22),
      );

      await tester.tap(find.byKey(const Key('action-icon')));
      expect(created, 1);
      expect(taps, isEmpty);
      // The destinations after it keep their own indices.
      await tester.tap(find.byKey(const Key('Chat-icon')));
      await tester.tap(find.byKey(const Key('Me-icon')));
      expect(taps, [2, 3]);
    });

    testWidgets('an action with no callback is disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUna(
        tester,
        bar(
          action: const NavigationAction(
            icon: Icon(PhosphorIconsRegular.plus),
            label: 'Create post',
            onPressed: null,
          ),
        ),
        formFactor: FormFactor.mobile,
      );
      final data = tester
          .getSemantics(find.bySemanticsLabel('Create post'))
          .getSemanticsData();
      expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('badges ride on the icons', (tester) async {
      await pumpUna(
        tester,
        bar(badgeCounts: const {1: 4, 2: 0, 3: 300}),
        formFactor: FormFactor.mobile,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      expect(shownBadges(tester), hasLength(2));
    });

    testWidgets('each destination is announced by its label, as a button; '
        'the selected one says so', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUna(
        tester,
        bar(
          selectedIndex: 1,
          onDestinationSelected: (_) {},
          action: action(),
        ),
        formFactor: FormFactor.mobile,
      );
      for (final (label, selected) in [
        ('Home', ui.Tristate.isFalse),
        ('Jobs', ui.Tristate.isTrue),
        ('Chat', ui.Tristate.isFalse),
        ('Me', ui.Tristate.isFalse),
        // The action is not one of the set: a plain button, with no
        // selected state at all.
        ('Create post', ui.Tristate.none),
      ]) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        // The label alone: the icon adds nothing to it.
        expect(data.label, label);
        expect(data.value, isEmpty, reason: label);
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
        expect(data.flagsCollection.isSelected, selected, reason: label);
      }
      handle.dispose();
    });

    testWidgets("a destination's badge count is its semantic value", (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpUna(
        tester,
        MediaQuery(
          data: const MediaQueryData(),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              action: action(),
              destinations: [
                ...destinations(3, badgeCounts: const {1: 4, 2: 0}),
                // A dot says "something new", not how much.
                const NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.bell),
                  label: 'Alerts',
                  showBadge: true,
                ),
                const NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.chatCircleDots),
                  label: 'Inbox',
                  badgeCount: 300,
                ),
              ],
            ),
          ),
        ),
        formFactor: FormFactor.mobile,
      );
      String valueOf(String label) => tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData()
          .value;

      expect(valueOf('Home'), isEmpty);
      expect(valueOf('Jobs'), '4');
      expect(valueOf('Chat'), isEmpty, reason: 'a zero count shows no badge');
      expect(valueOf('Alerts'), isEmpty);
      // The real number, not the "99+" the badge is capped at.
      expect(valueOf('Inbox'), '300');
      expect(valueOf('Create post'), isEmpty);
      // The badge's own text is not read a second time.
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Jobs'))
            .getSemanticsData()
            .label,
        'Jobs',
      );
      handle.dispose();
    });

    testWidgets('keyboard focus rings the focused item, inside its bounds', (
      tester,
    ) async {
      useTraditionalHighlights();
      await pumpUna(
        tester,
        bar(onDestinationSelected: (_) {}, action: action()),
        formFactor: FormFactor.mobile,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final rings = tester
          .widgetList<FocusRing>(find.byType(FocusRing))
          .toList();
      expect(rings.map((r) => r.visible), [true, false, false, false, false]);
      // The pill clips for its backdrop blur; an outside ring would be cut.
      expect(rings.every((r) => r.inset), isTrue);
      final theme = themeOf(tester, find.byType(BottomNavigationBar));
      expect(rings.every((r) => r.borderRadius == theme.radii.full), isTrue);
    });

    testWidgets('five destinations and an action fit a 360-point phone', (
      tester,
    ) async {
      await pumpUna(
        tester,
        bar(count: 5, action: action()),
        formFactor: FormFactor.mobile,
        surfaceSize: const Size(360, 780),
      );
      expect(tester.takeException(), isNull);
      // With the 16px margin the bar keeps on each side.
      expect(tester.getSize(surface()).width, lessThanOrEqualTo(360 - 32));
    });

    testWidgets('five destinations and an action fit a 320-point phone: the '
        'items give up width evenly rather than overflow', (tester) async {
      await pumpUna(
        tester,
        bar(count: 5, action: action()),
        formFactor: FormFactor.mobile,
        surfaceSize: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
      final theme = themeOf(tester, find.byType(BottomNavigationBar));
      final themed = theme.bottomNavigationBarTheme.itemWidth!;
      expect(themed, 52);

      // Six items in 320 less two 16px margins, 6 + 6 of padding, a 1px
      // outline each side and five 4px gaps.
      const fit = (320 - 32 - 12 - 2 - 4 * 5) / 6;
      expect(items(), findsNWidgets(6));
      for (var i = 0; i < 6; i++) {
        final size = tester.getSize(items().at(i));
        expect(size.width, lessThan(themed), reason: 'item $i');
        expect(size.width, closeTo(fit, .01), reason: 'item $i');
        // Only the width gives: the touch height stays.
        expect(size.height, 52, reason: 'item $i');
      }
      final pill = tester.getRect(surface());
      expect(pill.width, closeTo(320 - 32, .01));
      expect(pill.left, closeTo(16, .01));
      expect(pill.right, closeTo(320 - 16, .01));
    });

    testWidgets('at 390 points the same six items are exactly the theme '
        'width', (tester) async {
      await pumpUna(
        tester,
        bar(count: 5, action: action()),
        formFactor: FormFactor.mobile,
        surfaceSize: const Size(390, 844),
      );
      expect(tester.takeException(), isNull);
      final themed = themeOf(
        tester,
        find.byType(BottomNavigationBar),
      ).bottomNavigationBarTheme.itemWidth!;
      expect(items(), findsNWidgets(6));
      for (var i = 0; i < 6; i++) {
        expect(tester.getSize(items().at(i)), Size(themed, 52));
      }
      expect(tester.getSize(surface()).width, 52 * 6 + 4 * 5 + 12 + 2);
    });

    testWidgets('a docked bar never shrinks its items below their share', (
      tester,
    ) async {
      await pumpUna(
        tester,
        bar(count: 5, action: action(), floating: false),
        formFactor: FormFactor.mobile,
        surfaceSize: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(surface()).width, 320);
    });

    testWidgets('follows a theme override', (tester) async {
      const colour = Color(0xffcc5500);
      await pumpUna(
        tester,
        bar(),
        formFactor: FormFactor.mobile,
        theme: ThemeData(
          bottomNavigationBarTheme: const BottomNavigationBarTheme(
            itemWidth: 60,
            itemHeight: 40,
            iconSize: 20,
            selectedBackgroundColor: colour,
            margin: EdgeInsets.only(bottom: 10),
          ),
        ),
      );
      expect(tester.getSize(items().first), const Size(60, 40));
      expect(itemBox(tester, 0).color, colour);
      expect(
        tester.getSize(find.byKey(const Key('Home-selected'))),
        const Size.square(20),
      );
      expect(tester.getRect(surface()).bottom, 844 - 10);
    });
  });
}

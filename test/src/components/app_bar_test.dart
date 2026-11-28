import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';

import '../../app_bar_metrics.dart';
import '../../una_harness.dart';

void main() {
  const logo = SizedBox(key: Key('logo'), width: 32, height: 32);
  const actionA = SizedBox(key: Key('a'), width: 36, height: 36);
  const actionB = SizedBox(key: Key('b'), width: 36, height: 36);

  Widget top(Widget bar, {double statusBar = 0}) {
    return MediaQuery(
      data: MediaQueryData(padding: EdgeInsets.only(top: statusBar)),
      child: Align(alignment: Alignment.topCenter, child: bar),
    );
  }

  /// The bar's own box: fill and hairline.
  Finder surface() => find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(Container),
  );

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester.widget<Container>(surface().first).decoration! as BoxDecoration;

  group('AppBarTheme', () {
    test('follows the form factor', () {
      final desktop = ThemeData().appBarTheme;
      final mobile = ThemeData(formFactor: FormFactor.mobile).appBarTheme;
      expect(desktop.height, 64);
      expect(mobile.height, 44);
      expect(desktop.padding, const EdgeInsets.symmetric(horizontal: 24));
      expect(mobile.padding, const EdgeInsets.symmetric(horizontal: 16));
      // The gap between the bar's zones is the layout scale's xl.
      expect(desktop.gap, 24);
      expect(mobile.gap, 16);
      // The content is as wide as a page's padding box: the page's maximum
      // width, with the bar's own margins outside it.
      expect(desktop.maxWidth, 1280 + 24 * 2);
      expect(mobile.maxWidth, 1280 + 16 * 2);
    });

    test("is the bar colour at the style's bar opacity, over a blur", () {
      final light = ThemeData();
      final dark = ThemeData(brightness: Brightness.dark);
      expect(
        light.appBarTheme.backgroundColor,
        light.colorScheme.bar.withValues(alpha: .94),
      );
      expect(
        dark.appBarTheme.backgroundColor,
        dark.colorScheme.bar.withValues(alpha: .95),
      );
      expect(light.appBarTheme.blur, 24);
      expect(light.appBarTheme.saturation, 1.6);
      expect(light.appBarTheme.foregroundColor, light.colorScheme.foreground);
      expect(light.appBarTheme.borderColor, light.colorScheme.border);
      expect(light.appBarTheme.titleStyle!.fontSize, 16);
      expect(light.appBarTheme.titleStyle!.fontWeight, FontWeight.w600);
    });

    test('an opaque bar asks for no blur', () {
      for (final style in [
        StyleTokens.crisp,
        StyleTokens.pebble,
        StyleTokens.sharp,
      ]) {
        final theme = ThemeData(style: style);
        expect(theme.appBarTheme.backgroundColor!.a, 1, reason: style.name);
        expect(theme.appBarTheme.blur, 0, reason: style.name);
        expect(theme.appBarTheme.saturation, 1, reason: style.name);
      }
    });
  });

  group('AppBar layout', () {
    testWidgets('renders in both form factors and text directions', (
      tester,
    ) async {
      await expectBuildsInEveryLayout(
        tester,
        (layout) => top(
          AppBar(
            leading: logo,
            title: const Text('Messages'),
            actions: [
              IconButton.ghost(
                icon: const Icon(PhosphorIconsRegular.bell),
                onPressed: () {},
              ),
              IconButton.ghost(
                icon: const Icon(PhosphorIconsRegular.gear),
                onPressed: () {},
              ),
            ],
          ),
          statusBar: 44,
        ),
      );
    });

    testWidgets('with a middle, renders in both text directions on a '
        'desktop', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpUna(
          tester,
          top(
            AppBar(
              leading: logo,
              title: const Text('Search'),
              middle: NavigationBar(
                selectedIndex: 0,
                destinations: [
                  for (final label in ['Home', 'Jobs', 'Chat', 'Me'])
                    NavigationDestination(
                      icon: const Icon(PhosphorIconsRegular.house),
                      label: label,
                    ),
                ],
              ),
              actions: const [actionA, actionB],
            ),
          ),
          textDirection: direction,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('spans the width and is the theme height plus its '
        'hairline', (tester) async {
      for (final formFactor in FormFactor.values) {
        await pumpUna(
          tester,
          top(const AppBar(title: Text('Jobs'))),
          formFactor: formFactor,
        );
        final size = tester.getSize(find.byType(AppBar));
        expect(size.width, kSurfaceSizes[formFactor]!.width);
        final theme = themeOf(tester, find.byType(AppBar));
        expect(
          theme.appBarTheme.height,
          formFactor == FormFactor.mobile ? 44 : 64,
        );
        // A filled bar has room around its buttons: on a phone more than
        // the style's 44, the height of iOS's bar of bare glyphs. With no
        // status bar above it, as here, it needs no margin over that.
        final themed = filledToolbarHeight(theme);
        expect(themed, formFactor == FormFactor.mobile ? 60 : 64);
        expect(size.height, themed + 1);
      }
    });

    testWidgets('a primary bar extends under the status bar and keeps its '
        'content below it', (tester) async {
      late double reported;
      await pumpUna(
        tester,
        top(
          Builder(
            builder: (context) {
              reported = AppBar.heightOf(context);
              return const AppBar(leading: logo, title: Text('Jobs'));
            },
          ),
          statusBar: 44,
        ),
      );
      final bar = tester.getRect(find.byType(AppBar));
      // Status bar, the bar's own 64, and the hairline under it.
      expect(bar.height, 44 + 64 + 1);
      expect(reported, bar.height);
      // The content has the whole 64 below the status bar: the hairline is
      // added under it, not taken out of it.
      final logoRect = tester.getRect(find.byKey(const Key('logo')));
      expect(logoRect.top, greaterThanOrEqualTo(44));
      expect(logoRect.center.dy, closeTo(44 + 64 / 2, .01));
    });

    testWidgets('primary: false ignores the status bar', (tester) async {
      late double reported;
      await pumpUna(
        tester,
        top(
          Builder(
            builder: (context) {
              reported = AppBar.heightOf(context, primary: false);
              return const AppBar(primary: false, title: Text('Jobs'));
            },
          ),
          statusBar: 44,
        ),
      );
      expect(tester.getSize(find.byType(AppBar)).height, 65);
      expect(reported, 65);
    });

    testWidgets('height overrides the theme', (tester) async {
      await pumpUna(
        tester,
        top(const AppBar(height: 80, title: Text('Jobs')), statusBar: 20),
      );
      // 80 for the content, 20 of status bar, 1 of hairline.
      expect(tester.getSize(find.byType(AppBar)).height, 101);

      await pumpUna(
        tester,
        top(
          const AppBar(height: 80, showBorder: false, title: Text('Jobs')),
          statusBar: 20,
        ),
      );
      expect(tester.getSize(find.byType(AppBar)).height, 100);
    });

    testWidgets('leading, title and actions run in reading order between the '
        'page margins', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpUna(
          tester,
          top(
            const AppBar(
              leading: logo,
              title: Text('Jobs'),
              actions: [actionA, actionB],
            ),
          ),
          textDirection: direction,
        );
        final bar = tester.getRect(find.byType(AppBar));
        final lead = tester.getRect(find.byKey(const Key('logo')));
        final title = tester.getRect(find.text('Jobs'));
        final a = tester.getRect(find.byKey(const Key('a')));
        final b = tester.getRect(find.byKey(const Key('b')));

        if (direction == TextDirection.ltr) {
          expect(lead.left, bar.left + 24);
          // Half the bar's gap between the leading widget and the title.
          expect(title.left, lead.right + 12);
          expect(b.right, bar.right - 24);
          // The layout scale's sm between two actions.
          expect(b.left - a.right, 8);
        } else {
          expect(lead.right, bar.right - 24);
          expect(title.right, lead.left - 12);
          expect(b.left, bar.left + 24);
          expect(a.left - b.right, 8);
        }
        for (final rect in [lead, title, a, b]) {
          expect(rect.center.dy, closeTo(bar.top + 63 / 2, .5));
        }
      }
    });

    testWidgets("on a phone the margins are the phone's page margins", (
      tester,
    ) async {
      await pumpUna(
        tester,
        top(const AppBar(leading: logo, actions: [actionA])),
        formFactor: FormFactor.mobile,
      );
      final bar = tester.getRect(find.byType(AppBar));
      expect(tester.getRect(find.byKey(const Key('logo'))).left, 16);
      expect(tester.getRect(find.byKey(const Key('a'))).right, bar.right - 16);
    });

    testWidgets('the title takes the space between leading and actions and '
        'truncates', (tester) async {
      await pumpUna(
        tester,
        top(
          const AppBar(
            leading: logo,
            title: Text(
              'A conversation title that is far too long to fit in the bar',
            ),
            actions: [actionA, actionB],
          ),
        ),
        formFactor: FormFactor.mobile,
      );
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.textContaining('A conversation'));
      expect(
        title.right,
        lessThanOrEqualTo(tester.getRect(find.byKey(const Key('a'))).left),
      );
      final text = tester.widget<RichText>(
        find.descendant(
          of: find.textContaining('A conversation'),
          matching: find.byType(RichText),
        ),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('a middle is centred in the bar whatever sits beside it', (
      tester,
    ) async {
      for (final direction in TextDirection.values) {
        await pumpUna(
          tester,
          top(
            const AppBar(
              leading: logo,
              title: Text('Search'),
              middle: SizedBox(key: Key('middle'), width: 200, height: 30),
              // Lopsided on purpose: one action against a logo and a title.
              actions: [actionA],
            ),
          ),
          textDirection: direction,
        );
        final bar = tester.getRect(find.byType(AppBar));
        final middle = tester.getRect(find.byKey(const Key('middle')));
        final lead = tester.getRect(find.byKey(const Key('logo')));
        final a = tester.getRect(find.byKey(const Key('a')));

        expect(middle.center.dx, closeTo(bar.center.dx, .5));
        if (direction == TextDirection.ltr) {
          expect(lead.left, bar.left + 24);
          expect(a.right, bar.right - 24);
          // 4 tighter than the bar's gap between the leading widget and
          // the title.
          expect(tester.getRect(find.text('Search')).left, lead.right + 20);
        } else {
          expect(lead.right, bar.right - 24);
          expect(a.left, bar.left + 24);
        }
      }
    });

    testWidgets('a middle with nothing else is still centred', (tester) async {
      await pumpUna(
        tester,
        top(
          const AppBar(
            middle: SizedBox(key: Key('middle'), width: 200, height: 30),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.byKey(const Key('middle'))).dx,
        closeTo(640, .5),
      );
    });

    testWidgets('an empty bar builds', (tester) async {
      await pumpUna(tester, top(const AppBar()));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppBar)).height, 65);
    });

    testWidgets('on a very wide window the content is capped and centred', (
      tester,
    ) async {
      await pumpUna(
        tester,
        top(const AppBar(leading: logo, actions: [actionA])),
        surfaceSize: const Size(2000, 900),
      );
      final bar = tester.getRect(find.byType(AppBar));
      final lead = tester.getRect(find.byKey(const Key('logo')));
      final a = tester.getRect(find.byKey(const Key('a')));
      // The surface still spans the window…
      expect(bar.width, 2000);
      // …and the content is 1280 wide in the middle of it: the page's
      // maximum width, one page margin wider on each side than the content
      // of a `PageContainer` below.
      expect(lead.left, (2000 - 1280) / 2);
      expect(a.right, 2000 - (2000 - 1280) / 2);
    });

    testWidgets('maxWidth, padding, gap and actionsGap override the theme', (
      tester,
    ) async {
      await pumpUna(
        tester,
        top(
          const AppBar(
            leading: logo,
            title: Text('Jobs'),
            actions: [actionA, actionB],
            maxWidth: 600,
            padding: EdgeInsets.symmetric(horizontal: 10),
            gap: 40,
            actionsGap: 2,
          ),
        ),
      );
      final lead = tester.getRect(find.byKey(const Key('logo')));
      final a = tester.getRect(find.byKey(const Key('a')));
      final b = tester.getRect(find.byKey(const Key('b')));
      expect(lead.left, (1280 - 600) / 2 + 10);
      expect(b.right, 1280 - (1280 - 600) / 2 - 10);
      expect(tester.getRect(find.text('Jobs')).left, lead.right + 20);
      expect(b.left - a.right, 2);
    });
  });

  group('AppBar surface', () {
    testWidgets("is filled with the theme's bar colour over a hairline", (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pumpUna(
          tester,
          top(const AppBar(title: Text('Jobs'))),
          theme: ThemeData(brightness: brightness),
        );
        final theme = themeOf(tester, find.byType(AppBar));
        final decoration = decorationOf(tester);
        final border = decoration.border! as Border;

        expect(decoration.color, theme.appBarTheme.backgroundColor);
        expect(border.bottom.color, theme.colorScheme.border);
        expect(border.bottom.width, 1);
        expect(border.top, BorderSide.none);
      }
    });

    testWidgets('the hairline is added to the height, not taken out of it', (
      tester,
    ) async {
      const content = SizedBox.expand(key: Key('content'));
      await pumpUna(
        tester,
        top(const AppBar(padding: EdgeInsets.zero, title: content)),
      );
      // A 64-point bar is 65 tall with its hairline…
      expect(tester.getSize(find.byType(AppBar)).height, 65);
      // …and its content still gets all 64.
      expect(tester.getSize(find.byKey(const Key('content'))).height, 64);

      await pumpUna(
        tester,
        top(
          const AppBar(
            showBorder: false,
            padding: EdgeInsets.zero,
            title: content,
          ),
        ),
      );
      expect(decorationOf(tester).border, isNull);
      expect(tester.getSize(find.byType(AppBar)).height, 64);
      expect(tester.getSize(find.byKey(const Key('content'))).height, 64);
    });

    testWidgets('heightOf is the theme height, the hairline and — for a '
        'primary bar — the status bar, on both form factors', (tester) async {
      for (final formFactor in FormFactor.values) {
        late double primary;
        late double secondary;
        await pumpUna(
          tester,
          top(
            Builder(
              builder: (context) {
                primary = AppBar.heightOf(context);
                secondary = AppBar.heightOf(context, primary: false);
                return const AppBar(title: Text('Jobs'));
              },
            ),
            statusBar: 30,
          ),
          formFactor: formFactor,
        );
        final themed = filledToolbarHeight(
          themeOf(tester, find.byType(AppBar)),
        );
        expect(secondary, themed + 1, reason: formFactor.name);
        expect(primary, themed + 1 + 30, reason: formFactor.name);
        expect(
          tester.getSize(find.byType(AppBar)).height,
          primary,
          reason: formFactor.name,
        );
      }
    });

    testWidgets('backgroundColor overrides the fill', (tester) async {
      const colour = Color(0xff112233);
      await pumpUna(
        tester,
        top(const AppBar(backgroundColor: colour, title: Text('Jobs'))),
      );
      expect(decorationOf(tester).color, colour);
    });

    testWidgets('a translucent bar blurs what scrolls beneath it', (
      tester,
    ) async {
      await pumpUna(tester, top(const AppBar(title: Text('Jobs'))));
      final filter = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(BackdropFilter),
      );
      expect(filter, findsOneWidget);
      expect(
        tester.widget<BackdropFilter>(filter).filter,
        same(Backdrop.filterFor(blur: 24, saturation: 1.6)),
      );
      // Confined to the bar.
      expect(tester.getSize(filter), tester.getSize(find.byType(AppBar)));
    });

    testWidgets('an opaque bar builds no backdrop layer', (tester) async {
      await pumpUna(
        tester,
        top(const AppBar(title: Text('Jobs'))),
        theme: ThemeData(
          style: StyleTokens.crisp,
          colorScheme: const GraphiteColorScheme.light(),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(decorationOf(tester).color!.a, 1);
    });

    testWidgets('the title takes the title style in the foreground', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pumpUna(
          tester,
          top(const AppBar(title: Text('Jobs'))),
          theme: ThemeData(brightness: brightness),
        );
        final theme = themeOf(tester, find.byType(AppBar));
        final style = DefaultTextStyle.of(
          tester.element(find.text('Jobs')),
        ).style;
        expect(style.color, theme.colorScheme.foreground);
        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w600);
      }
    });

    testWidgets('icons in the bar take the foreground', (tester) async {
      await pumpUna(
        tester,
        top(const AppBar(leading: Icon(PhosphorIconsRegular.arrowLeft))),
      );
      final theme = themeOf(tester, find.byType(AppBar));
      expect(
        IconTheme.of(tester.element(find.byType(Icon))).color,
        theme.colorScheme.foreground,
      );
    });

    testWidgets('follows a theme override', (tester) async {
      const fill = Color(0xff203040);
      const ink = Color(0xfff0e0d0);
      await pumpUna(
        tester,
        top(const AppBar(title: Text('Jobs'))),
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            height: 52,
            backgroundColor: fill,
            foregroundColor: ink,
            blur: 0,
            saturation: 1,
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppBar)).height, 52 + 1);
      expect(decorationOf(tester).color, fill);
      expect(
        DefaultTextStyle.of(tester.element(find.text('Jobs'))).style.color,
        ink,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('AppBar semantics', () {
    testWidgets('the title and the actions are reachable', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpUna(
        tester,
        top(
          AppBar(
            title: const Text('Messages'),
            actions: [
              IconButton.ghost(
                icon: const Icon(
                  PhosphorIconsRegular.bell,
                  semanticLabel: 'Notifications',
                ),
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Messages'), findsOneWidget);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('the bar is its own semantic container', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUna(tester, top(const AppBar(title: Text('Messages'))));
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.container, isTrue);
      // The bar itself is chrome, not a heading: announcing it as a header
      // made everything in it one. Its title is the page's heading.
      expect(semantics.properties.header, isNull);
      expect(
        tester
            .getSemantics(find.text('Messages'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.text('Messages'))
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isFalse,
      );
      handle.dispose();
    });

    testWidgets('in a bar that carries the navigation, what sits in the '
        "title's place is not a heading", (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUna(
        tester,
        top(
          const AppBar(
            title: Text('Search'),
            middle: Text('Destinations'),
            actions: [Text('Bell')],
          ),
        ),
      );
      for (final text in ['Search', 'Destinations', 'Bell']) {
        expect(
          tester
              .getSemantics(find.text(text))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isFalse,
          reason: text,
        );
      }
      handle.dispose();
    });
  });
}

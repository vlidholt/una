import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';

import '../../una_harness.dart';

List<NavigationDestination> _destinations({
  Set<int> topOnly = const {},
  Set<int> bottomOnly = const {},
}) {
  const names = ['Home', 'Jobs', 'Chat', 'Alerts', 'Me'];
  return [
    for (var i = 0; i < names.length; i++)
      NavigationDestination(
        icon: Icon(PhosphorIconsRegular.house, key: Key('${names[i]}-icon')),
        label: names[i],
        showInTopBar: !bottomOnly.contains(i),
        showInBottomBar: !topOnly.contains(i),
      ),
  ];
}

/// A body that remembers something, to show it is not rebuilt from scratch.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => count++),
    child: Center(child: Text('count $count')),
  );
}

void main() {
  /// Pumps [scaffold] under a status bar and a home indicator.
  Future<void> pump(
    WidgetTester tester,
    Widget scaffold, {
    FormFactor formFactor = FormFactor.desktop,
    TextDirection textDirection = TextDirection.ltr,
    EdgeInsets padding = const EdgeInsets.only(top: 44, bottom: 34),
    ThemeData? theme,
    Size? surfaceSize,
  }) {
    return pumpUna(
      tester,
      MediaQuery(
        data: MediaQueryData(padding: padding),
        child: scaffold,
      ),
      formFactor: formFactor,
      textDirection: textDirection,
      theme: theme,
      surfaceSize: surfaceSize,
    );
  }

  /// Records the padding the body sees.
  Widget probe(void Function(EdgeInsets) record) => Builder(
    builder: (context) {
      record(MediaQuery.paddingOf(context));
      return const SizedBox.expand(key: Key('body'));
    },
  );

  BottomNavigationBar bottomBar() => BottomNavigationBar(
    destinations: _destinations().sublist(0, 4),
    selectedIndex: 0,
  );

  group('Scaffold', () {
    testWidgets('renders in both form factors and text directions', (
      tester,
    ) async {
      for (final layout in kLayouts) {
        await pump(
          tester,
          Scaffold(
            appBar: const AppBar(title: Text('Messages')),
            bottomNavigationBar: bottomBar(),
            body: ListView(
              children: [
                for (var i = 0; i < 30; i++) ListTile(title: Text('Row $i')),
              ],
            ),
          ),
          formFactor: layout.formFactor,
          textDirection: layout.textDirection,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the body fills the scaffold, under both bars', (tester) async {
      await pump(
        tester,
        Scaffold(
          appBar: const AppBar(title: Text('Messages')),
          bottomNavigationBar: bottomBar(),
          body: const SizedBox.expand(key: Key('body')),
        ),
        formFactor: FormFactor.mobile,
      );
      final scaffold = tester.getRect(find.byType(Scaffold));
      final body = tester.getRect(find.byKey(const Key('body')));
      final appBar = tester.getRect(find.byType(AppBar));
      final bar = tester.getRect(find.byType(BottomNavigationBar));

      expect(scaffold.size, const Size(390, 844));
      // Laid over the page, not above and below it: a translucent bar shows
      // the page scrolling beneath.
      expect(body, scaffold);
      expect(appBar.top, 0);
      expect(appBar.width, 390);
      expect(bar.bottom, 844);
      expect(bar.width, 390);
    });

    testWidgets('paints the theme background, or the colour it is given', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pump(
          tester,
          const Scaffold(body: SizedBox.expand()),
          theme: ThemeData(brightness: brightness),
        );
        final theme = themeOf(tester, find.byType(Scaffold));
        final box = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(Scaffold),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(box.color, theme.colorScheme.background, reason: '$brightness');
      }

      const colour = Color(0xff123456);
      await pump(
        tester,
        const Scaffold(backgroundColor: colour, body: SizedBox.expand()),
      );
      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(
                    of: find.byType(Scaffold),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            )
            .color,
        colour,
      );
    });

    testWidgets("insets the body's MediaQuery padding by the bars' heights", (
      tester,
    ) async {
      for (final formFactor in FormFactor.values) {
        late EdgeInsets seen;
        await pump(
          tester,
          Scaffold(
            appBar: const AppBar(title: Text('Messages')),
            bottomNavigationBar: bottomBar(),
            body: probe((p) => seen = p),
          ),
          formFactor: formFactor,
        );
        final appBar = tester.getRect(find.byType(AppBar));
        final bar = tester.getRect(find.byType(BottomNavigationBar));

        // The app bar's height including the 44 of status bar it extends
        // under; the bottom bar's including its margin and the 34 of home
        // indicator.
        // …and the hairline under the app bar, which is added to its height.
        expect(seen.top, (formFactor == FormFactor.mobile ? 60 : 64) + 1 + 44);
        expect(seen.top, appBar.height);
        expect(seen.bottom, (formFactor == FormFactor.mobile ? 88 : 84) + 34);
        expect(seen.bottom, bar.height);
        expect(seen.left, 0);
        expect(seen.right, 0);
      }
    });

    testWidgets('without bars the body keeps the padding it was given', (
      tester,
    ) async {
      late EdgeInsets seen;
      await pump(
        tester,
        Scaffold(body: probe((p) => seen = p)),
        padding: const EdgeInsets.fromLTRB(10, 44, 12, 34),
      );
      expect(seen, const EdgeInsets.fromLTRB(10, 44, 12, 34));
    });

    testWidgets('each bar insets only its own edge', (tester) async {
      late EdgeInsets seen;
      await pump(
        tester,
        Scaffold(
          appBar: const AppBar(title: Text('Messages')),
          body: probe((p) => seen = p),
        ),
        padding: const EdgeInsets.fromLTRB(10, 44, 12, 34),
      );
      expect(seen, const EdgeInsets.fromLTRB(10, 64 + 1 + 44, 12, 34));

      await pump(
        tester,
        Scaffold(
          bottomNavigationBar: bottomBar(),
          body: probe((p) => seen = p),
        ),
        formFactor: FormFactor.mobile,
        padding: const EdgeInsets.fromLTRB(10, 44, 12, 34),
      );
      expect(seen, const EdgeInsets.fromLTRB(10, 44, 12, 88 + 34));
    });

    testWidgets('appBarHeight and bottomNavigationBarHeight replace the '
        'measured insets', (tester) async {
      late EdgeInsets seen;
      await pump(
        tester,
        Scaffold(
          appBar: const SizedBox(height: 30),
          appBarHeight: 30,
          bottomNavigationBar: const SizedBox(height: 50),
          bottomNavigationBarHeight: 50,
          body: probe((p) => seen = p),
        ),
      );
      expect(seen.top, 30);
      expect(seen.bottom, 50);
    });

    testWidgets('appBarHeight wins over the measurement of a real bar, on '
        'every frame', (tester) async {
      final seen = <EdgeInsets>[];
      await pump(
        tester,
        Scaffold(
          appBar: const AppBar(height: 80, title: Text('Messages')),
          appBarHeight: 20,
          bottomNavigationBar: bottomBar(),
          bottomNavigationBarHeight: 0,
          body: probe(seen.add),
        ),
        formFactor: FormFactor.mobile,
      );
      // The bars really are another size…
      expect(tester.getSize(find.byType(AppBar)).height, 80 + 1 + 44);
      expect(tester.getSize(find.byType(BottomNavigationBar)).height, 88 + 34);
      // …and the body never saw it.
      expect(seen, isNotEmpty);
      for (final padding in seen) {
        expect(padding.top, 20);
        expect(padding.bottom, 0);
      }
    });

    testWidgets('an AppBar and a BottomNavigationBar are inset exactly on the '
        'first frame: the measurement changes nothing', (tester) async {
      for (final formFactor in FormFactor.values) {
        final seen = <EdgeInsets>[];
        // A fresh app each time: a form factor changing under a mounted
        // scaffold is a theme animation, and a different test.
        await tester.pumpWidget(const SizedBox.shrink());
        await pump(
          tester,
          Scaffold(
            appBar: const AppBar(title: Text('Messages')),
            bottomNavigationBar: bottomBar(),
            body: probe(seen.add),
          ),
          formFactor: formFactor,
        );
        await tester.pump();
        expect(seen, isNotEmpty);
        expect(seen.toSet(), hasLength(1), reason: formFactor.name);
        expect(seen.first.top, tester.getSize(find.byType(AppBar)).height);
        expect(
          seen.first.bottom,
          tester.getSize(find.byType(BottomNavigationBar)).height,
        );
      }
    });

    testWidgets('measures an app bar of its own height: the inset is right '
        'on the first frame', (tester) async {
      for (final showBorder in [true, false]) {
        final seen = <EdgeInsets>[];
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = kSurfaceSizes[FormFactor.desktop]!;
        addTearDown(tester.view.reset);
        // A fresh scaffold each time, so the first frame is a first frame.
        await tester.pumpWidget(const SizedBox.shrink());
        late double themed;
        await tester.pumpWidget(
          UnaApp(
            formFactor: FormFactor.desktop,
            home: MediaQuery(
              data: const MediaQueryData(
                padding: EdgeInsets.only(top: 44, bottom: 34),
              ),
              child: Builder(
                builder: (context) {
                  themed = AppBar.heightOf(context);
                  return Scaffold(
                    appBar: AppBar(
                      height: 96,
                      showBorder: showBorder,
                      title: const Text('Messages'),
                    ),
                    body: probe(seen.add),
                  );
                },
              ),
            ),
          ),
        );
        // Measured in the frame it is laid out in, so the first frame is
        // already right and the theme's height is never used as a guess.
        expect(themed, 64 + 1 + 44);
        expect(seen.last.top, 96 + 44 + (showBorder ? 1 : 0));

        await tester.pump();
        final bar = tester.getSize(find.byType(AppBar)).height;
        expect(bar, 96 + 44 + (showBorder ? 1 : 0));
        expect(seen.last.top, bar, reason: 'showBorder: $showBorder');
        // No bottom bar: the home indicator is all there is.
        expect(seen.last.bottom, 34);

        // And it stays there.
        await settle(tester);
        expect(seen.last.top, bar);
      }
    });

    testWidgets('measures any widget used as a bar', (tester) async {
      final seen = <EdgeInsets>[];
      await pump(
        tester,
        Scaffold(
          // A two-row header and a message composer: neither is an AppBar
          // or a BottomNavigationBar, so neither height is in the theme.
          appBar: const Column(
            key: Key('header'),
            mainAxisSize: MainAxisSize.min,
            children: [SizedBox(height: 40), SizedBox(height: 33)],
          ),
          bottomNavigationBar: const Glass(
            key: Key('composer'),
            height: 57,
            child: SizedBox.expand(),
          ),
          body: probe(seen.add),
        ),
        formFactor: FormFactor.mobile,
      );
      expect(tester.getSize(find.byKey(const Key('header'))).height, 73);
      expect(tester.getSize(find.byKey(const Key('composer'))).height, 57);
      expect(seen.last.top, 73);
      expect(seen.last.bottom, 57);
      // The bars still span the width, at the top and the bottom.
      expect(
        tester.getRect(find.byKey(const Key('header'))),
        const Rect.fromLTWH(0, 0, 390, 73),
      );
      expect(
        tester.getRect(find.byKey(const Key('composer'))),
        const Rect.fromLTWH(0, 844 - 57, 390, 57),
      );
    });

    testWidgets('an arbitrary bottom widget is measured on the first '
        'frame', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = kSurfaceSizes[FormFactor.mobile]!;
      addTearDown(tester.view.reset);
      final seen = <EdgeInsets>[];
      late double themed;
      await tester.pumpWidget(
        UnaApp(
          formFactor: FormFactor.mobile,
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: Builder(
              builder: (context) {
                themed = BottomNavigationBar.heightOf(context);
                return Scaffold(
                  bottomNavigationBar: const SizedBox(
                    key: Key('composer'),
                    height: 50,
                  ),
                  body: probe(seen.add),
                );
              },
            ),
          ),
        ),
      );
      // Measured in the frame it is laid out in: the theme's height for a
      // `BottomNavigationBar` is never used as a guess.
      expect(themed, 88 + 34);
      expect(seen.last.bottom, 50);
      // No app bar: the status bar is all there is.
      expect(seen.last.top, 44);

      await tester.pump();
      expect(seen.last.bottom, 50);
      expect(seen.last.top, 44);
    });

    testWidgets('follows a bar that changes height while on screen', (
      tester,
    ) async {
      final height = ValueNotifier<double>(48);
      addTearDown(height.dispose);
      final seen = <EdgeInsets>[];
      await pump(
        tester,
        Scaffold(
          bottomNavigationBar: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (context, value, _) => SizedBox(height: value),
          ),
          body: probe(seen.add),
        ),
        formFactor: FormFactor.mobile,
      );
      expect(seen.last.bottom, 48);

      // A composer growing as the message wraps.
      height.value = 96;
      await tester.pump();
      await tester.pump();
      expect(seen.last.bottom, 96);

      height.value = 48;
      await tester.pump();
      await tester.pump();
      expect(seen.last.bottom, 48);
    });

    testWidgets('removing a bar hands its edge back, and a new bar is '
        'measured afresh', (tester) async {
      final seen = <EdgeInsets>[];
      Widget scaffold(Widget? appBar) =>
          Scaffold(appBar: appBar, body: probe(seen.add));

      await pump(tester, scaffold(const SizedBox(height: 30)));
      expect(seen.last.top, 30);

      await pump(tester, scaffold(null));
      expect(seen.last.top, 44);

      await pump(tester, scaffold(const SizedBox(height: 70)));
      expect(seen.last.top, 70);
    });

    testWidgets('the body keeps its state while the bars are measured', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(appBar: SizedBox(height: 30), body: _Counter()),
      );
      await tester.tap(find.text('count 0'));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);

      await pump(
        tester,
        const Scaffold(appBar: SizedBox(height: 90), body: _Counter()),
      );
      expect(find.text('count 1'), findsOneWidget);
    });

    testWidgets('a list in the body starts below the app bar and can scroll '
        'beneath it', (tester) async {
      await pump(
        tester,
        Scaffold(
          appBar: const AppBar(title: Text('Messages')),
          bottomNavigationBar: bottomBar(),
          body: ListView(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(key: Key('row$i'), height: 50),
            ],
          ),
        ),
        formFactor: FormFactor.mobile,
      );
      final appBar = tester.getRect(find.byType(AppBar));
      // The list pads itself by the MediaQuery padding.
      expect(tester.getRect(find.byKey(const Key('row0'))).top, appBar.bottom);

      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pump();
      // Scrolled, the first row is under the bar rather than clipped at it.
      expect(
        tester.getRect(find.byKey(const Key('row0'))).top,
        appBar.bottom - 120,
      );

      // At the end the last row clears the bottom bar.
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      // Past the end the list stretches for a moment, as it does on
      // Android.
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byType(BottomNavigationBar));
      expect(tester.getRect(find.byKey(const Key('row39'))).bottom, bar.top);
    });

    testWidgets('a SafeArea in the body clears the bars', (tester) async {
      await pump(
        tester,
        Scaffold(
          appBar: const AppBar(title: Text('Messages')),
          bottomNavigationBar: bottomBar(),
          body: const SafeArea(child: SizedBox.expand(key: Key('safe'))),
        ),
        formFactor: FormFactor.mobile,
      );
      final safe = tester.getRect(find.byKey(const Key('safe')));
      expect(safe.top, tester.getRect(find.byType(AppBar)).bottom);
      expect(safe.bottom, tester.getRect(find.byType(BottomNavigationBar)).top);
    });

    testWidgets('the page beside a floating bar still takes taps', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        Scaffold(
          bottomNavigationBar: bottomBar(),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
        formFactor: FormFactor.mobile,
      );
      final bar = tester.getRect(find.byType(BottomNavigationBar));
      // In the bar's row, but to the side of the pill.
      await tester.tapAt(Offset(6, bar.top + 30));
      // And in the margin under the pill.
      await tester.tapAt(Offset(195, bar.bottom - 40));
      expect(taps, 2);
    });

    testWidgets('the bars are painted over the body', (tester) async {
      var bodyTaps = 0;
      var barTaps = 0;
      await pump(
        tester,
        Scaffold(
          appBar: AppBar(
            title: const Text('Messages'),
            actions: [
              // The key on what takes the tap: a SizedBox with no child
              // is not hit itself.
              GestureDetector(
                key: const Key('action'),
                behavior: HitTestBehavior.opaque,
                onTap: () => barTaps++,
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => bodyTaps++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('action')));
      expect(barTaps, 1);
      expect(bodyTaps, 0);
    });
  });

  group('NavigationScaffold', () {
    Widget scaffold({
      int? selectedIndex = 0,
      ValueChanged<int>? onDestinationSelected,
      List<NavigationDestination>? destinations,
      NavigationAction? action,
      List<Widget>? mobileActions,
      Widget? mobileAppBar,
      bool showMobileAppBar = true,
      bool showBottomNavigationBar = true,
      Widget body = const SizedBox.expand(key: Key('body')),
    }) {
      return NavigationScaffold(
        destinations: destinations ?? _destinations(),
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        leading: const SizedBox(key: Key('logo'), width: 32, height: 32),
        title: const SizedBox(key: Key('search'), width: 120, height: 36),
        actions: const [SizedBox(key: Key('bell'), width: 36, height: 36)],
        mobileActions: mobileActions,
        action: action,
        mobileAppBar: mobileAppBar,
        showMobileAppBar: showMobileAppBar,
        showBottomNavigationBar: showBottomNavigationBar,
        body: body,
      );
    }

    testWidgets('renders in both form factors and text directions', (
      tester,
    ) async {
      for (final layout in kLayouts) {
        await pump(
          tester,
          scaffold(
            onDestinationSelected: (_) {},
            action: NavigationAction(
              icon: const Icon(PhosphorIconsRegular.plus),
              label: 'Create',
              onPressed: () {},
            ),
          ),
          formFactor: layout.formFactor,
          textDirection: layout.textDirection,
        );
        expect(tester.takeException(), isNull, reason: '$layout');
      }
    });

    testWidgets('on a desktop the destinations sit in the app bar', (
      tester,
    ) async {
      await pump(tester, scaffold());

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      // Leading, title and actions are all there, around a centred bar.
      expect(find.byKey(const Key('logo')), findsOneWidget);
      expect(find.byKey(const Key('search')), findsOneWidget);
      expect(find.byKey(const Key('bell')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(NavigationBar),
        ),
        findsOneWidget,
      );
      expect(
        tester.getCenter(find.byType(NavigationBar)).dx,
        closeTo(640, .5),
      );
      for (final label in ['Home', 'Jobs', 'Chat', 'Alerts', 'Me']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('on a phone they move to a bottom bar and the app bar '
        'shrinks', (tester) async {
      await pump(
        tester,
        scaffold(
          action: NavigationAction(
            icon: const Icon(PhosphorIconsRegular.plus, key: Key('plus')),
            label: 'Create',
            onPressed: () {},
          ),
        ),
        formFactor: FormFactor.mobile,
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // The app bar keeps the logo and the actions; the title is a desktop
      // thing.
      expect(find.byKey(const Key('logo')), findsOneWidget);
      expect(find.byKey(const Key('bell')), findsOneWidget);
      expect(find.byKey(const Key('search')), findsNothing);
      // The bottom bar shows icons, not labels, and carries the action.
      expect(find.text('Home'), findsNothing);
      expect(find.byKey(const Key('Home-icon')), findsOneWidget);
      expect(find.byKey(const Key('plus')), findsOneWidget);
    });

    testWidgets('the action is a phone thing', (tester) async {
      await pump(
        tester,
        scaffold(
          action: NavigationAction(
            icon: const Icon(PhosphorIconsRegular.plus, key: Key('plus')),
            label: 'Create',
            onPressed: () {},
          ),
        ),
      );
      expect(find.byKey(const Key('plus')), findsNothing);
    });

    testWidgets('switches bars when the form factor changes, keeping the '
        "body's state", (tester) async {
      await pump(tester, scaffold(body: const _Counter()));
      await tester.tap(find.text('count 0'));
      await tester.pump();
      await tester.tap(find.text('count 1'));
      await tester.pump();
      expect(find.text('count 2'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await pump(
        tester,
        scaffold(body: const _Counter()),
        formFactor: FormFactor.mobile,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      // The page was not thrown away with the bars.
      expect(find.text('count 2'), findsOneWidget);

      await pump(tester, scaffold(body: const _Counter()));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.text('count 2'), findsOneWidget);
    });

    testWidgets('follows the window when the app does not pin a form factor', (
      tester,
    ) async {
      Future<void> pumpAt(Size size) => pumpUna(
        tester,
        scaffold(body: const _Counter()),
        surfaceSize: size,
        pinFormFactor: false,
      );

      await pumpAt(const Size(1280, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      await pumpAt(const Size(390, 844));
      expect(tester.takeException(), isNull);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await pumpAt(const Size(1280, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('insets the body for whichever bars it shows', (tester) async {
      late EdgeInsets seen;
      await pump(tester, scaffold(body: probe((p) => seen = p)));
      // A desktop has no bottom bar, so only the home indicator remains.
      expect(seen, const EdgeInsets.only(top: 64 + 1 + 44, bottom: 34));

      await pump(
        tester,
        scaffold(body: probe((p) => seen = p)),
        formFactor: FormFactor.mobile,
      );
      expect(
        seen,
        const EdgeInsets.only(top: 60 + 1 + 44, bottom: 88 + 34),
      );
    });

    testWidgets('taps report indices into the full list, on both bars', (
      tester,
    ) async {
      final taps = <int>[];
      await pump(tester, scaffold(onDestinationSelected: taps.add));
      await tester.tap(find.text('Chat'));
      await tester.tap(find.text('Me'));
      expect(taps, [2, 4]);

      taps.clear();
      await pump(
        tester,
        scaffold(onDestinationSelected: taps.add),
        formFactor: FormFactor.mobile,
      );
      await tester.tap(find.byKey(const Key('Chat-icon')));
      await tester.tap(find.byKey(const Key('Me-icon')));
      expect(taps, [2, 4]);
    });

    testWidgets('a destination can opt out of either bar; indices still '
        'refer to the full list', (tester) async {
      // "Alerts" (3) lives in the top bar only; "Jobs" (1) in the bottom
      // bar only.
      final all = _destinations(topOnly: {3}, bottomOnly: {1});
      final taps = <int>[];

      await pump(
        tester,
        scaffold(destinations: all, onDestinationSelected: taps.add),
      );
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Jobs'), findsNothing);
      // "Chat" is the second destination shown, and still index 2.
      await tester.tap(find.text('Chat'));
      await tester.tap(find.text('Alerts'));
      await tester.tap(find.text('Me'));
      expect(taps, [2, 3, 4]);

      taps.clear();
      await pump(
        tester,
        scaffold(destinations: all, onDestinationSelected: taps.add),
        formFactor: FormFactor.mobile,
      );
      expect(find.byKey(const Key('Alerts-icon')), findsNothing);
      expect(find.byKey(const Key('Jobs-icon')), findsOneWidget);
      await tester.tap(find.byKey(const Key('Jobs-icon')));
      await tester.tap(find.byKey(const Key('Chat-icon')));
      await tester.tap(find.byKey(const Key('Me-icon')));
      expect(taps, [1, 2, 4]);
    });

    testWidgets("the selection is mapped into each bar's own list", (
      tester,
    ) async {
      final all = _destinations(topOnly: {3}, bottomOnly: {1});

      // Index 4 ("Me") is the fourth of the four shown in the top bar.
      await pump(tester, scaffold(destinations: all, selectedIndex: 4));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
      // And the fourth of four in the bottom bar too, by a different route.
      await pump(
        tester,
        scaffold(destinations: all, selectedIndex: 4),
        formFactor: FormFactor.mobile,
      );
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .selectedIndex,
        3,
      );
    });

    testWidgets('selecting a destination a bar does not show selects '
        'nothing in it', (tester) async {
      final all = _destinations(topOnly: {3}, bottomOnly: {1});

      // "Jobs" is not in the top bar.
      await pump(tester, scaffold(destinations: all, selectedIndex: 1));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        isNull,
      );
      // "Alerts" is not in the bottom bar.
      await pump(
        tester,
        scaffold(destinations: all, selectedIndex: 3),
        formFactor: FormFactor.mobile,
      );
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .selectedIndex,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a null selection selects nothing', (tester) async {
      for (final formFactor in FormFactor.values) {
        await pump(
          tester,
          scaffold(selectedIndex: null),
          formFactor: formFactor,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('without a callback both bars are inert', (tester) async {
      for (final formFactor in FormFactor.values) {
        await pump(tester, scaffold(), formFactor: formFactor);
        final callback = formFactor == FormFactor.desktop
            ? tester
                  .widget<NavigationBar>(find.byType(NavigationBar))
                  .onDestinationSelected
            : tester
                  .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
                  .onDestinationSelected;
        expect(callback, isNull);
      }
    });

    testWidgets('mobileActions replace the actions on a phone only', (
      tester,
    ) async {
      const mobile = [SizedBox(key: Key('menu'), width: 36, height: 36)];
      await pump(tester, scaffold(mobileActions: mobile));
      expect(find.byKey(const Key('bell')), findsOneWidget);
      expect(find.byKey(const Key('menu')), findsNothing);

      await pump(
        tester,
        scaffold(mobileActions: mobile),
        formFactor: FormFactor.mobile,
      );
      expect(find.byKey(const Key('bell')), findsNothing);
      expect(find.byKey(const Key('menu')), findsOneWidget);
    });

    testWidgets('mobileAppBar replaces the app bar on a phone only', (
      tester,
    ) async {
      const header = AppBar(key: Key('conversation'), title: Text('Omar'));
      await pump(tester, scaffold(mobileAppBar: header));
      expect(find.text('Omar'), findsNothing);
      expect(find.byKey(const Key('logo')), findsOneWidget);

      await pump(
        tester,
        scaffold(mobileAppBar: header),
        formFactor: FormFactor.mobile,
      );
      expect(find.text('Omar'), findsOneWidget);
      expect(find.byKey(const Key('logo')), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('a mobileAppBar of any height insets the body by what it '
        'measures', (tester) async {
      late EdgeInsets seen;
      await pump(
        tester,
        scaffold(
          mobileAppBar: const SizedBox(key: Key('thread'), height: 72),
          body: probe((p) => seen = p),
        ),
        formFactor: FormFactor.mobile,
      );
      expect(tester.getSize(find.byKey(const Key('thread'))).height, 72);
      expect(seen.top, 72);
      expect(seen.bottom, 88 + 34);
    });

    testWidgets('showMobileAppBar: false drops the app bar and its inset', (
      tester,
    ) async {
      late EdgeInsets seen;
      await pump(
        tester,
        scaffold(showMobileAppBar: false, body: probe((p) => seen = p)),
        formFactor: FormFactor.mobile,
      );
      expect(find.byType(AppBar), findsNothing);
      expect(seen.top, 44);
      expect(seen.bottom, 88 + 34);

      // A desktop always has its app bar: that is where navigation lives.
      await pump(tester, scaffold(showMobileAppBar: false));
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('showBottomNavigationBar: false gives a phone screen the '
        'whole height', (tester) async {
      late EdgeInsets seen;
      await pump(
        tester,
        scaffold(showBottomNavigationBar: false, body: probe((p) => seen = p)),
        formFactor: FormFactor.mobile,
      );
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(seen.bottom, 34);
      expect(seen.top, 60 + 1 + 44);
    });

    testWidgets('five destinations, a logo, a search field and two actions '
        'fit the narrowest desktop window', (tester) async {
      await pumpUna(
        tester,
        NavigationScaffold(
          destinations: _destinations(),
          selectedIndex: 0,
          leading: const SizedBox(width: 32, height: 32),
          title: const SizedBox(width: 240, height: 36),
          actions: const [
            SizedBox(width: 36, height: 36),
            SizedBox(width: 36, height: 36),
          ],
          body: const SizedBox.expand(),
        ),
        // The md breakpoint: the first width that is a desktop.
        surfaceSize: const Size(768, 600),
        pinFormFactor: false,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

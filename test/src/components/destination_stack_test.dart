import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';

import '../../una_harness.dart';

/// [DestinationStack] shows one destination's page and keeps the others
/// alive off stage; and a [BottomNavigationBar] can show its labels.
const _frame = Duration(milliseconds: 16);

/// A page that counts its builds and holds a text field, to tell whether
/// it was kept.
class _Page extends StatefulWidget {
  const _Page(this.name, this.log);

  final String name;
  final List<String> log;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  int taps = 0;

  @override
  void initState() {
    super.initState();
    // Started here, not when it is first read.
    controller.value;
    widget.log.add('init ${widget.name}');
  }

  @override
  void dispose() {
    controller.dispose();
    widget.log.add('dispose ${widget.name}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => taps++),
      child: Column(
        children: [
          Text('${widget.name} $taps'),
          Focus(child: Text('focus ${widget.name}')),
          Text(
            Visibility.of(context) ? 'seen' : 'unseen',
            key: ValueKey('visibility ${widget.name}'),
          ),
        ],
      ),
    );
  }
}

/// The pages animate for ever, so nothing here settles by itself.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Widget _stack(
  int index,
  List<String> log, {
  Axis axis = Axis.horizontal,
}) {
  return DestinationStack(
    index: index,
    axis: axis,
    builders: [
      for (final name in ['home', 'search', 'me'])
        (context) => _Page(name, log),
    ],
  );
}

/// Where the route's page is painted, and how strongly the wash covers it.
({Offset offset, double wash}) _incoming(WidgetTester tester, String name) {
  final offset = tester.getTopLeft(
    find.byWidgetPredicate((w) => w is _Page && w.name == name),
  );
  final wash = tester
      .widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(DestinationStack),
          matching: find.byType(ColoredBox),
        ),
      )
      .last
      .color
      .a;
  return (offset: offset, wash: wash);
}

void main() {
  group('DestinationStack', () {
    testWidgets('builds a destination when it is first shown, and keeps it', (
      tester,
    ) async {
      final log = <String>[];
      var index = 0;
      late StateSetter rebuild;
      await pumpUna(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _stack(index, log);
          },
        ),
      );
      expect(log, ['init home']);
      await tester.tap(find.text('home 0'));
      await tester.pump();
      expect(find.text('home 1'), findsOneWidget);

      rebuild(() => index = 2);
      await _settle(tester);
      // Only the one that was asked for: search has not been visited.
      expect(log, ['init home', 'init me']);
      expect(find.text('me 0'), findsOneWidget);
      expect(find.text('home 1'), findsNothing);
      expect(find.text('home 1', skipOffstage: false), findsOneWidget);

      rebuild(() => index = 0);
      await _settle(tester);
      // The same page, with what was done to it.
      expect(log, ['init home', 'init me']);
      expect(find.text('home 1'), findsOneWidget);
    });

    testWidgets('a destination that is not showing stands still, is not '
        'seen, and is out of the focus order', (tester) async {
      final log = <String>[];
      var index = 0;
      late StateSetter rebuild;
      await pumpUna(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _stack(index, log);
          },
        ),
      );
      rebuild(() => index = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      _PageState state(String name) => tester.state(
        find.byWidgetPredicate(
          (w) => w is _Page && w.name == name,
          skipOffstage: false,
        ),
      );
      // Its ticker is muted: the value does not move while it is hidden.
      final held = state('home').controller.value;
      final running = state('search').controller.value;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state('home').controller.value, held);
      expect(state('search').controller.value, isNot(running));
      // `Visibility.of` says so, which is what keeps a menu from opening
      // over the wrong page.
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('visibility home'),
                skipOffstage: false,
              ),
            )
            .data,
        'unseen',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('visibility search')))
            .data,
        'seen',
      );
      // Tab finds the one focusable thing that shows, and no other.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          find.descendant(
            of: find.byElementPredicate(
              (e) => e == FocusManager.instance.primaryFocus!.context,
            ),
            matching: find.text('focus search'),
          ),
          findsOneWidget,
        );
      }
      // It is not painted or hit.
      await tester.tapAt(const Offset(40, 8));
      await tester.pump();
      expect(state('home').taps, 0);
      expect(state('search').taps, 1);
    });

    testWidgets('the page comes in from the side its destination is on, out '
        'of the page colour, and is live from the first frame', (
      tester,
    ) async {
      for (final direction in TextDirection.values) {
        final log = <String>[];
        var index = 0;
        late StateSetter rebuild;
        await pumpUna(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return _stack(index, log);
            },
          ),
          textDirection: direction,
        );
        const rest = 0.0;
        rebuild(() => index = 1);
        await tester.pump();
        await tester.pump(_frame);
        final sign = direction == TextDirection.ltr ? 1 : -1;
        final first = _incoming(tester, 'search');
        // A later destination comes from the end side.
        expect((first.offset.dx - rest) * sign, greaterThan(0));
        expect(first.wash, inExclusiveRange(0, .61));
        // Not a blank frame: the page is already there under the wash.
        await tester.tap(find.text('search 0'));
        await tester.pump(_frame);
        expect(find.text('search 1'), findsOneWidget);
        final xs = <double>[];
        final washes = <double>[];
        for (var i = 0; i < 30; i++) {
          final now = _incoming(tester, 'search');
          xs.add((now.offset.dx - rest) * sign);
          washes.add(now.wash);
          await tester.pump(_frame);
        }
        for (var i = 1; i < xs.length; i++) {
          expect(xs[i], lessThanOrEqualTo(xs[i - 1] + 1e-6));
          expect(washes[i], lessThanOrEqualTo(washes[i - 1] + 1e-6));
        }
        await _settle(tester);
        expect(_incoming(tester, 'search').offset.dx, rest);
        expect(_incoming(tester, 'search').wash, 0);

        // An earlier one from the start side.
        rebuild(() => index = 0);
        await tester.pump();
        await tester.pump(_frame);
        expect(
          (_incoming(tester, 'home').offset.dx - rest) * sign,
          lessThan(0),
        );
        await _settle(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('on a vertical axis it comes from below or above', (
      tester,
    ) async {
      final log = <String>[];
      var index = 0;
      late StateSetter rebuild;
      await pumpUna(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _stack(index, log, axis: Axis.vertical);
          },
        ),
      );
      rebuild(() => index = 2);
      await tester.pump();
      await tester.pump(_frame);
      final now = _incoming(tester, 'me');
      expect(now.offset.dx, 0);
      expect(now.offset.dy, greaterThan(0));
      await _settle(tester);
    });

    testWidgets('with reduced motion it does not slide; with none it is '
        'simply there', (tester) async {
      final log = <String>[];
      var index = 0;
      late StateSetter rebuild;
      Widget app() => StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _stack(index, log);
        },
      );
      await pumpUna(
        tester,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 800),
            disableAnimations: true,
          ),
          child: app(),
        ),
      );
      rebuild(() => index = 1);
      await tester.pump();
      await tester.pump(_frame);
      final reduced = _incoming(tester, 'search');
      expect(reduced.offset.dx, 0);
      expect(reduced.wash, greaterThan(0));
      await _settle(tester);
      await tester.pumpWidget(const SizedBox.shrink());

      index = 0;
      await pumpUna(tester, app(), theme: ThemeData(motion: Motion.none));
      rebuild(() => index = 1);
      await tester.pump();
      final none = _incoming(tester, 'search');
      expect(none.offset.dx, 0);
      expect(none.wash, 0);
    });

    testWidgets('gives its page the size it has, and costs no layer for a '
        'fade', (tester) async {
      final log = <String>[];
      await pumpUna(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 300,
            child: DestinationStack(
              index: 0,
              builders: [
                (context) => const SizedBox.expand(key: Key('page')),
                (context) => _Page('other', log),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('page'))),
        const Size(400, 300),
      );
      expect(
        find.descendant(
          of: find.byType(DestinationStack),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(DestinationStack),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });
  });

  group('BottomNavigationBar labels', () {
    const destinations = [
      NavigationDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.house),
        label: 'Home',
      ),
      NavigationDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.chatCircleDots),
        label: 'Messages',
        badgeCount: 2,
      ),
      NavigationDestination(
        icon: PhosphorIcon(PhosphorIconsRegular.user),
        label: 'Me',
      ),
    ];

    Widget bar({bool? showLabels, bool? floating, int index = 0}) => Align(
      alignment: Alignment.bottomCenter,
      child: BottomNavigationBar(
        destinations: destinations,
        selectedIndex: index,
        onDestinationSelected: (_) {},
        showLabels: showLabels,
        floating: floating,
        action: NavigationAction(
          icon: const PhosphorIcon(PhosphorIconsBold.plus),
          label: 'Compose',
          onPressed: () {},
        ),
      ),
    );

    testWidgets('are off by default: icons only', (tester) async {
      await pumpUna(tester, bar(), formFactor: FormFactor.mobile);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('shown, each label is under its icon and the bar is a line '
        'taller, floating or docked, in every style', (tester) async {
      for (final style in [StyleTokens.fluid, StyleTokens.crisp]) {
        for (final floating in [true, false]) {
          await pumpUna(
            tester,
            bar(floating: floating),
            formFactor: FormFactor.mobile,
            theme: ThemeData(style: style),
          );
          final plain = tester.getSize(find.byType(BottomNavigationBar)).height;
          await tester.pumpWidget(const SizedBox.shrink());

          await pumpUna(
            tester,
            bar(showLabels: true, floating: floating),
            formFactor: FormFactor.mobile,
            theme: ThemeData(style: style),
          );
          expect(tester.takeException(), isNull);
          final theme = Theme.of(
            tester.element(find.byType(BottomNavigationBar)),
          );
          final labelled = tester
              .getSize(find.byType(BottomNavigationBar))
              .height;
          final line = theme.bottomNavigationBarTheme.labelStyle!.fontSize!;
          expect(labelled - plain, moreOrLessEquals(line + 4, epsilon: .01));
          for (final destination in destinations) {
            final label = tester.getRect(find.text(destination.label));
            final icon = tester.getRect(
              find.byWidget(destination.icon, skipOffstage: false).first,
            );
            expect(label.top, greaterThanOrEqualTo(icon.bottom));
            expect(
              label.center.dx,
              moreOrLessEquals(icon.center.dx, epsilon: 1),
            );
          }
          // The action is a button, not a place: it has no label.
          expect(find.text('Compose'), findsNothing);
          // Docked, the lens is behind the icon, not the label; floating,
          // it takes in the label as well, as the Liquid Glass lens does.
          final lens = tester.getRect(
            find.byWidgetPredicate(
              (w) => w is MovingIndicatorTarget && w.selected,
            ),
          );
          final home = tester.getRect(find.text('Home'));
          if (floating) {
            expect(lens.top, lessThan(home.top));
            expect(lens.bottom, greaterThanOrEqualTo(home.bottom));
          } else {
            expect(lens.bottom, lessThanOrEqualTo(home.top));
            expect(lens.height, theme.bottomNavigationBarTheme.itemHeight);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    });

    testWidgets('the theme switches them on, and heightOf follows', (
      tester,
    ) async {
      late double measured;
      await pumpUna(
        tester,
        Builder(
          builder: (context) {
            measured = BottomNavigationBar.heightOf(context);
            return bar();
          },
        ),
        formFactor: FormFactor.mobile,
        theme: ThemeData(
          bottomNavigationBarTheme: const BottomNavigationBarTheme(
            showLabels: true,
          ),
        ),
      );
      expect(find.text('Messages'), findsOneWidget);
      expect(
        tester.getSize(find.byType(BottomNavigationBar)).height,
        moreOrLessEquals(measured, epsilon: .01),
      );
    });

    testWidgets('the selected label takes the selected colour; a label is '
        'not read twice', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUna(
        tester,
        bar(showLabels: true, index: 1),
        formFactor: FormFactor.mobile,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final theme = Theme.of(tester.element(find.byType(BottomNavigationBar)));
      Color colourOf(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;
      expect(
        colourOf('Messages'),
        theme.bottomNavigationBarTheme.selectedForegroundColor,
      );
      expect(colourOf('Home'), theme.bottomNavigationBarTheme.foregroundColor);
      expect(find.bySemanticsLabel('Messages'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('survive a text scale of two without clipping', (tester) async {
      await pumpUna(
        tester,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: bar(showLabels: true),
        ),
        formFactor: FormFactor.mobile,
      );
      expect(tester.takeException(), isNull);
      final barRect = tester.getRect(find.byType(BottomNavigationBar));
      final label = tester.getRect(find.text('Home'));
      expect(label.bottom, lessThanOrEqualTo(barRect.bottom));
    });
  });
}

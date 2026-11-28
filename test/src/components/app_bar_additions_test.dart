import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/components/app_bar_layout.dart';
import 'package:una/una.dart';

import '../../app_bar_metrics.dart';
import '../../frame_sampler.dart';
import '../../una_harness.dart';

void main() {
  final navigator = GlobalKey<NavigatorState>();

  Future<void> pumpHome(
    WidgetTester tester,
    Widget home, {
    FormFactor formFactor = FormFactor.mobile,
    ThemeData? theme,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = kSurfaceSizes[formFactor]!;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UnaApp(
        navigatorKey: navigator,
        formFactor: formFactor,
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: padding),
          child: child!,
        ),
        home: home,
      ),
    );
    await tester.pump();
  }

  Widget page({Widget? leading, bool imply = true, Widget? drawer}) => Scaffold(
    drawer: drawer,
    appBar: AppBar(
      leading: leading,
      automaticallyImplyLeading: imply,
      title: const Text('Page'),
    ),
    body: const SizedBox.expand(),
  );

  group('the leading button a bar shows by itself', () {
    testWidgets('nothing on the first page', (tester) async {
      await pumpHome(tester, page());
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(CloseButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('a back button on a page that can be popped, and it pops', (
      tester,
    ) async {
      await pumpHome(tester, const Center(child: Text('Home')));
      navigator.currentState!.push(
        UnaPageRoute<void>(builder: (_) => page()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      // At the start of the bar, before the title.
      expect(
        tester.getCenter(find.byType(BackButton)).dx,
        lessThan(tester.getTopLeft(find.text('Page')).dx),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('a close button on a full-screen dialog', (tester) async {
      await pumpHome(tester, const Center(child: Text('Home')));
      navigator.currentState!.push(
        UnaPageRoute<void>(fullscreenDialog: true, builder: (_) => page()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CloseButton), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('a menu button over a scaffold with a drawer, and it opens '
        'the drawer', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, page(drawer: const Text('Drawer')));
      expect(find.byIcon(PhosphorIconsRegular.list), findsOneWidget);
      expect(find.bySemanticsLabel('Open menu'), findsOneWidget);
      await tester.tap(find.byIcon(PhosphorIconsRegular.list));
      await tester.pumpAndSettle();
      expect(find.text('Drawer'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('going back comes before the menu', (tester) async {
      await pumpHome(tester, const Center(child: Text('Home')));
      navigator.currentState!.push(
        UnaPageRoute<void>(
          builder: (_) => page(drawer: const Text('Drawer')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.list), findsNothing);
    });

    testWidgets('a leading of its own wins, and '
        'automaticallyImplyLeading: false shows none', (tester) async {
      await pumpHome(tester, const Center(child: Text('Home')));
      navigator.currentState!.push(
        UnaPageRoute<void>(
          builder: (_) => page(leading: const Text('Logo')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Logo'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);

      navigator.currentState!.pushReplacement(
        UnaPageRoute<void>(builder: (_) => page(imply: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });
  });

  group('bottom', () {
    testWidgets('is a row under the toolbar, inside the surface and above '
        'the hairline, and the page is inset for it', (tester) async {
      EdgeInsets? seen;
      await pumpHome(
        tester,
        Scaffold(
          appBar: const AppBar(
            title: Text('Inbox'),
            bottom: SizedBox(key: Key('bottom'), height: 48),
          ),
          body: Builder(
            builder: (context) {
              seen = MediaQuery.paddingOf(context);
              return const SizedBox.expand();
            },
          ),
        ),
        padding: const EdgeInsets.only(top: 44),
      );
      final theme = themeOf(tester, find.byType(AppBar));
      final toolbar = filledToolbarHeight(theme);
      final bar = tester.getRect(find.byType(AppBar));
      final bottom = tester.getRect(find.byKey(const Key('bottom')));
      expect(bar.height, 44 + toolbar + 48 + 1);
      expect(bottom.top, 44 + toolbar);
      expect(bottom.bottom, bar.bottom - 1);
      expect(bottom.width, 390);
      expect(seen!.top, bar.height);
      // The toolbar is as tall as it was.
      expect(tester.getCenter(find.text('Inbox')).dy, 44 + toolbar / 2);
    });

    testWidgets('builds in every layout with a tab bar in it', (tester) async {
      await expectBuildsInEveryLayout(
        tester,
        (layout) => Scaffold(
          appBar: AppBar(
            title: const Text('Library'),
            bottom: TabBar<int>(
              tabs: const [
                Tab(value: 0, child: Text('Albums')),
                Tab(value: 1, child: Text('Artists')),
                Tab(value: 2, child: Text('Songs')),
              ],
              value: 0,
              onChanged: (_) {},
            ),
          ),
          body: const SizedBox.expand(),
        ),
      );
    });
  });

  group('centerTitle', () {
    testWidgets('puts the title in the centre of the bar, whatever is '
        'beside it', (tester) async {
      await pumpHome(
        tester,
        const Scaffold(
          appBar: AppBar(
            leading: SizedBox(width: 44, height: 44),
            centerTitle: true,
            title: Text('Title'),
            actions: [
              SizedBox(width: 44, height: 44),
              SizedBox(width: 44, height: 44),
            ],
          ),
          body: SizedBox.expand(),
        ),
      );
      expect(tester.getCenter(find.text('Title')).dx, 195);
    });

    testWidgets('a title too long for the centre is pushed aside and cut '
        'short, not laid under the buttons', (tester) async {
      await pumpHome(
        tester,
        const Scaffold(
          appBar: AppBar(
            leading: SizedBox(key: Key('leading'), width: 44, height: 44),
            centerTitle: true,
            title: Text('A very long title that cannot possibly fit here'),
            actions: [SizedBox(key: Key('action'), width: 44, height: 44)],
          ),
          body: SizedBox.expand(),
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.byType(Text));
      expect(
        title.left,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const Key('leading'))).right,
        ),
      );
      expect(
        title.right,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('action'))).left,
        ),
      );
    });

    testWidgets('follows the theme, and the widget overrides the theme', (
      tester,
    ) async {
      final theme = ThemeData(
        appBarTheme: const AppBarTheme(centerTitle: true),
      );
      await pumpHome(
        tester,
        const Scaffold(
          appBar: AppBar(title: Text('Title')),
          body: SizedBox.expand(),
        ),
        theme: theme,
      );
      expect(tester.getCenter(find.text('Title')).dx, 195);

      await pumpHome(
        tester,
        const Scaffold(
          appBar: AppBar(centerTitle: false, title: Text('Title')),
          body: SizedBox.expand(),
        ),
        theme: theme,
      );
      expect(tester.getTopLeft(find.text('Title')).dx, lessThan(40));
      // By default it is at the start.
      expect(ThemeData().appBarTheme.centerTitle, isFalse);
    });

    testWidgets('mirrors in a right-to-left language', (tester) async {
      await pumpUna(
        tester,
        const Scaffold(
          appBar: AppBar(
            leading: SizedBox(key: Key('leading'), width: 44, height: 44),
            centerTitle: true,
            title: Text('Title'),
          ),
          body: SizedBox.expand(),
        ),
        formFactor: FormFactor.mobile,
        textDirection: TextDirection.rtl,
      );
      expect(tester.getCenter(find.text('Title')).dx, 195);
      expect(
        tester.getCenter(find.byKey(const Key('leading'))).dx,
        greaterThan(300),
      );
    });
  });

  group('surfaceBehavior: whenScrolled', () {
    final sampler = FrameSampler();
    final controller = ScrollController();
    const fill = Color(0xffe04040);
    const pageColor = Color(0xff204080);

    Widget scaffold({
      AppBarSurfaceBehavior? behavior = AppBarSurfaceBehavior.whenScrolled,
      Color? barColor = fill,
      bool reverse = false,
      Widget? inPage,
    }) => sampler.wrap(
      Scaffold(
        backgroundColor: pageColor,
        appBar: AppBar(
          title: const Text('Feed'),
          backgroundColor: barColor,
          surfaceBehavior: behavior,
        ),
        body: ListView(
          controller: controller,
          reverse: reverse,
          children: [?inPage, const SizedBox(height: 3000)],
        ),
      ),
    );

    // In the bar, clear of its title.
    const inBar = Offset(300, 20);

    testWidgets('the bar is bare at the top of the page and takes its fill '
        'and hairline once the page has scrolled under it, in one fade', (
      tester,
    ) async {
      await pumpHome(tester, scaffold());
      expect(await sampler.pixel(tester, inBar), pageColor);

      controller.jumpTo(40);
      await tester.pump();
      final frames = await sampler.record(tester, inBar, frames: 16);
      expectMonotone(frames, reason: 'appearing');
      expect(frames.last, fill);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Scrolling on changes nothing more.
      controller.jumpTo(400);
      await tester.pump();
      expect(await sampler.pixel(tester, inBar), fill);

      controller.jumpTo(0);
      await tester.pump();
      final back = await sampler.record(tester, inBar, frames: 16);
      expectMonotone(back, reason: 'leaving');
      expect(back.last, pageColor);
    });

    testWidgets('scrolling builds nothing in the bar', (tester) async {
      var builds = 0;
      await pumpHome(
        tester,
        Scaffold(
          appBar: AppBar(
            surfaceBehavior: AppBarSurfaceBehavior.whenScrolled,
            title: Builder(
              builder: (context) {
                builds++;
                return const Text('Feed');
              },
            ),
          ),
          body: ListView(
            controller: controller,
            children: const [SizedBox(height: 3000)],
          ),
        ),
      );
      final before = builds;
      for (final offset in [10.0, 80.0, 300.0, 0.0, 50.0]) {
        controller.jumpTo(offset);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(builds, before);
    });

    testWidgets('a translucent bar blurs only once the page is under it', (
      tester,
    ) async {
      // The default style's bars are glass.
      await pumpHome(tester, scaffold(barColor: null));
      RenderBackdropFilter filter() => tester.renderObject(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(FadingBackdrop),
        ),
      );
      expect(filter().enabled, isFalse);
      controller.jumpTo(40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 300));
      expect(filter().enabled, isTrue);
      controller.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 300));
      expect(filter().enabled, isFalse);
    });

    testWidgets('a list that scrolls sideways inside the page, or a list '
        'nested in it, says nothing about the bar', (tester) async {
      final sideways = ScrollController();
      final nested = ScrollController();
      addTearDown(sideways.dispose);
      addTearDown(nested.dispose);
      await pumpHome(
        tester,
        scaffold(
          inPage: Column(
            children: [
              SizedBox(
                height: 100,
                child: ListView(
                  controller: sideways,
                  scrollDirection: Axis.horizontal,
                  children: const [SizedBox(width: 3000)],
                ),
              ),
              SizedBox(
                height: 100,
                child: ListView(
                  controller: nested,
                  children: const [SizedBox(height: 3000)],
                ),
              ),
            ],
          ),
        ),
      );
      sideways.jumpTo(200);
      nested.jumpTo(200);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(await sampler.pixel(tester, inBar), pageColor);
    });

    testWidgets('a list in a page of a TabBarView is the page scrolling '
        'under the bar', (tester) async {
      final tabs = TabsController<String>(value: 'a');
      addTearDown(tabs.dispose);
      await pumpHome(
        tester,
        sampler.wrap(
          Scaffold(
            backgroundColor: pageColor,
            appBar: AppBar(
              title: const Text('Feed'),
              backgroundColor: fill,
              surfaceBehavior: AppBarSurfaceBehavior.whenScrolled,
              bottom: TabBar<String>(
                controller: tabs,
                tabs: const [
                  Tab(value: 'a', child: Text('A')),
                  Tab(value: 'b', child: Text('B')),
                ],
              ),
            ),
            body: TabBarView<String>(
              controller: tabs,
              pages: {
                'a': (context) => ListView(
                  controller: controller,
                  children: const [SizedBox(height: 3000)],
                ),
                'b': (context) => const SizedBox.expand(),
              },
            ),
          ),
        ),
      );
      expect(await sampler.pixel(tester, inBar), pageColor);
      controller.jumpTo(40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 300));
      expect(await sampler.pixel(tester, inBar), fill);
    });

    testWidgets('a reversed list starts at the bottom: the bar is bare '
        'there', (tester) async {
      await pumpHome(tester, scaffold(reverse: true));
      expect(await sampler.pixel(tester, inBar), pageColor);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 300));
      expect(await sampler.pixel(tester, inBar), pageColor);
      controller.jumpTo(100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 300));
      expect(await sampler.pixel(tester, inBar), fill);
    });

    testWidgets('with motion off the surface is there or not', (tester) async {
      await pumpHome(tester, scaffold(), theme: ThemeData(motion: Motion.none));
      controller.jumpTo(40);
      await tester.pump();
      await tester.pump();
      expect(await sampler.pixel(tester, inBar), fill);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets("is the theme's to set, and always by default", (
      tester,
    ) async {
      expect(
        ThemeData().appBarTheme.surfaceBehavior,
        AppBarSurfaceBehavior.always,
      );
      await pumpHome(tester, scaffold(behavior: null));
      expect(await sampler.pixel(tester, inBar), fill);

      await pumpHome(
        tester,
        scaffold(behavior: null),
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            surfaceBehavior: AppBarSurfaceBehavior.whenScrolled,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(await sampler.pixel(tester, inBar), pageColor);
    });

    testWidgets('without a scaffold above it the bar simply stays bare', (
      tester,
    ) async {
      await pumpUna(
        tester,
        const Align(
          alignment: Alignment.topCenter,
          child: AppBar(
            title: Text('Loose'),
            surfaceBehavior: AppBarSurfaceBehavior.whenScrolled,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the status bar', () {
    SystemUiOverlayStyle? styleAtTop(WidgetTester tester) => tester
        .binding
        .renderViews
        .first
        .debugLayer!
        .find<SystemUiOverlayStyle>(const Offset(195, 10));

    testWidgets('its icons read on the bar, not on the page: a dark bar on '
        'a light page gets light icons', (tester) async {
      await pumpHome(
        tester,
        const Scaffold(
          appBar: AppBar(
            title: Text('Dark'),
            backgroundColor: Color(0xff101010),
          ),
          body: SizedBox.expand(),
        ),
        padding: const EdgeInsets.only(top: 44),
      );
      final style = styleAtTop(tester)!;
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
      expect(style.statusBarColor, const Color(0x00000000));
      // Below the bar the page still decides.
      expect(
        tester.binding.renderViews.first.debugLayer!
            .find<SystemUiOverlayStyle>(const Offset(195, 800))!
            .statusBarIconBrightness,
        Brightness.dark,
      );
    });

    testWidgets('a translucent bar is judged over the page behind it', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pumpHome(
          tester,
          const Scaffold(
            appBar: AppBar(title: Text('Glass')),
            body: SizedBox.expand(),
          ),
          theme: ThemeData(brightness: brightness),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          styleAtTop(tester)!.statusBarIconBrightness,
          brightness == Brightness.light ? Brightness.dark : Brightness.light,
        );
      }
    });

    testWidgets('systemOverlayStyle overrides it, and a bar that is not '
        'primary leaves it alone', (tester) async {
      await pumpHome(
        tester,
        const Scaffold(
          appBar: AppBar(
            title: Text('Bar'),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          body: SizedBox.expand(),
        ),
      );
      expect(styleAtTop(tester), SystemUiOverlayStyle.light);

      await pumpHome(
        tester,
        const Scaffold(
          appBar: AppBar(
            title: Text('Bar'),
            primary: false,
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          body: SizedBox.expand(),
        ),
      );
      // The scaffold's.
      expect(styleAtTop(tester)!.statusBarIconBrightness, Brightness.dark);
    });
  });
}

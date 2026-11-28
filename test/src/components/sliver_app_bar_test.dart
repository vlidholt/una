import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/components/bar_button_scope.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart'
    show LiquidGlassScrollEdge;
import 'package:una/una.dart';

import '../../frame_sampler.dart';
import '../../una_harness.dart';

const _fill = Color(0xffe04040);
const _page = Color(0xff204080);
const _row = Key('row-0');
const _bottom = Key('bottom');

void main() {
  final controller = ScrollController();
  final sampler = FrameSampler();

  Widget page(
    Widget bar, {
    ScrollPhysics? physics,
    int rows = 40,
    Color? background = _page,
  }) => sampler.wrap(
    Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
        controller: controller,
        physics: physics,
        slivers: [
          bar,
          SliverList.builder(
            itemCount: rows,
            itemBuilder: (context, index) => SizedBox(
              key: index == 0 ? _row : null,
              height: 60,
              child: Text('Row $index'),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    FormFactor formFactor = FormFactor.mobile,
    TextDirection direction = TextDirection.ltr,
    EdgeInsets padding = EdgeInsets.zero,
    double textScale = 1,
    bool reduce = false,
    ThemeData? theme,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = kSurfaceSizes[formFactor]!;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UnaApp(
        navigatorKey: navigatorKey,
        formFactor: formFactor,
        theme: theme,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: padding,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduce,
          ),
          child: Directionality(textDirection: direction, child: app!),
        ),
        home: child,
      ),
    );
    await tester.pump();
  }

  Future<void> scrollTo(WidgetTester tester, double offset) async {
    controller.jumpTo(offset);
    await tester.pump();
  }

  Finder bar() => find.byType(SliverAppBar);
  Finder inBar(Finder finder) => find.descendant(of: bar(), matching: finder);

  /// The large title is the first 'Library' in the bar: the toolbar, and
  /// the small one in it, is built after the expanded area.
  Finder largeTitle(String text) => inBar(find.text(text)).first;
  Finder smallTitle(String text) => inBar(find.text(text)).last;

  double smallTitleOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(inBar(find.byType(FadeTransition)))
      .opacity
      .value;

  // A filled bar keeps no margin above its toolbar where there is no
  // status bar, as in these tests: its toolbar has room of its own.
  double topInset(WidgetTester tester) => 0;

  // The filled toolbar's height: the theme's, at least an icon button with
  // the small gap above and below.
  double barHeight(WidgetTester tester) {
    final theme = themeOf(tester, bar());
    return math.max(
      theme.appBarTheme.height!,
      theme.style.iconButtonSize + 2 * theme.layoutTheme.gap(GapSize.sm),
    );
  }

  // How far down the toolbar reaches: its margin and its height.
  double toolbarHeight(WidgetTester tester) =>
      topInset(tester) + barHeight(tester);

  // Where the middle of the toolbar's row is.
  double toolbarCenter(WidgetTester tester) =>
      topInset(tester) + barHeight(tester) / 2;

  group('SliverAppBar.large', () {
    Widget large({
      Widget? bottom,
      Widget? background,
      double? expandedHeight,
      bool pinned = true,
      bool stretch = true,
      Widget? subtitle,
      List<Widget> actions = const [],
    }) => SliverAppBar.large(
      title: const Text('Library'),
      subtitle: subtitle,
      backgroundColor: _fill,
      bottom: bottom,
      background: background,
      expandedHeight: expandedHeight,
      pinned: pinned,
      stretch: stretch,
      actions: actions,
    );

    testWidgets('builds in every layout', (tester) async {
      await expectBuildsInEveryLayout(
        tester,
        (layout) => page(
          large(
            subtitle: const Text('128 albums'),
            bottom: const SizedBox(height: 40),
          ),
        ),
      );
    });

    testWidgets('at the top the title is large under the toolbar, at the '
        'page margin, on the bare page; the list starts under it', (
      tester,
    ) async {
      await pump(tester, page(large()));
      final theme = themeOf(tester, bar());
      final toolbar = toolbarHeight(tester);
      final title = tester.getRect(largeTitle('Library'));
      final margin = theme.layoutTheme.pagePadding!.horizontal / 2;
      expect(title.left, margin);
      expect(title.top, toolbar + theme.layoutTheme.gapMd!);
      final style = DefaultTextStyle.of(
        tester.element(largeTitle('Library')),
      ).style;
      expect(style.fontSize, theme.appBarTheme.largeTitleStyle!.fontSize);
      expect(
        style.fontSize,
        greaterThan(theme.appBarTheme.titleStyle!.fontSize!),
      );
      // The small one is there but not shown.
      expect(smallTitleOpacity(tester), 0);
      // No surface: the page colour, in the toolbar and under the title.
      expect(await sampler.pixel(tester, const Offset(300, 20)), _page);
      expect(await sampler.pixel(tester, Offset(300, toolbar + 20)), _page);
      // The first row is right under the expanded area and its hairline.
      final expanded = title.height + 2 * theme.layoutTheme.gapMd!;
      expect(tester.getRect(find.byKey(_row)).top, toolbar + expanded + 1);
    });

    testWidgets('scrolled, the large title goes under the toolbar, the small '
        'one fades in and the bar takes its surface: all tied to the scroll, '
        'one way', (tester) async {
      await pump(tester, page(large()));
      final toolbar = toolbarHeight(tester);
      final start = tester.getRect(largeTitle('Library')).top;
      final expanded = tester.getRect(find.byKey(_row)).top - toolbar - 1;

      final opacities = <double>[];
      final reds = <double>[];
      for (var offset = 0.0; offset <= expanded + 20; offset += 4) {
        await scrollTo(tester, offset);
        final shift = offset < expanded ? offset : expanded;
        // Point for point with the page while it collapses.
        expect(tester.getRect(largeTitle('Library')).top, start - shift);
        // The toolbar and the small title do not move.
        expect(
          tester.getRect(smallTitle('Library')).center.dy,
          toolbarCenter(tester),
        );
        opacities.add(smallTitleOpacity(tester));
        reds.add((await sampler.pixel(tester, const Offset(300, 20))).r);
      }
      for (var i = 1; i < opacities.length; i++) {
        expect(opacities[i], greaterThanOrEqualTo(opacities[i - 1]));
        expect(reds[i], greaterThanOrEqualTo(reds[i - 1] - .005));
      }
      expect(opacities.first, 0);
      expect(opacities.last, 1);
      // Collapsed: the fill, and the bar is the toolbar and its hairline.
      expect(await sampler.pixel(tester, const Offset(300, 20)), _fill);
      await scrollTo(tester, 400);
      expect(await sampler.pixel(tester, Offset(300, toolbar + 20)), _page);

      // And back again.
      await scrollTo(tester, 0);
      expect(smallTitleOpacity(tester), 0);
      expect(await sampler.pixel(tester, const Offset(300, 20)), _page);
      expect(tester.getRect(largeTitle('Library')).top, start);
    });

    testWidgets('the large title goes under the toolbar, which takes its '
        'surface over it as it does, instead of being cut off at the '
        "toolbar's edge", (tester) async {
      await pump(tester, page(large(subtitle: const Text('128 albums'))));
      final toolbar = toolbarHeight(tester);
      final title = tester.getRect(largeTitle('Library'));
      // The title's top line six points under the toolbar.
      final under = title.top - toolbar + 6;
      await scrollTo(tester, under);
      final inBand = await sampler.pixel(
        tester,
        Offset(title.left + 4, toolbar - 3),
      );
      // Not the bare page there, nor the bar's surface alone: the title,
      // under the surface coming in.
      expect(inBand, isNot(_page));
      expect(inBand, isNot(_fill));
      final band = await sampler.pixel(tester, const Offset(300, 20));
      expect(band.r, greaterThan(_page.r));
      expect(band, isNot(_fill));
      // The small title is not in yet: the large one is not half under.
      expect(smallTitleOpacity(tester), 0);
      // Below the toolbar the titles still stand on the bare page.
      expect(await sampler.pixel(tester, Offset(300, toolbar + 4)), _page);

      // Once the title line is under, the toolbar is the bar's surface,
      // and the small title is coming in.
      await scrollTo(tester, under - 6 + title.height + 2);
      expect(await sampler.pixel(tester, const Offset(300, 20)), _fill);
      expect(smallTitleOpacity(tester), greaterThan(0));
      // The fill is laid on once: the toolbar reads as the collapsed bar.
      await scrollTo(tester, 400);
      expect(await sampler.pixel(tester, const Offset(300, 20)), _fill);
      expect(barHeight(tester) + topInset(tester), toolbar);
    });

    testWidgets('over a picture the titles go under the toolbar like any '
        'other, and nothing is blurred, on Liquid Glass either', (
      tester,
    ) async {
      const picture = Color(0xff00ff00);
      bool blurred() {
        var found = false;
        void visit(Layer? first) {
          for (var layer = first; layer != null; layer = layer.nextSibling) {
            if (layer is ImageFilterLayer) found = true;
            if (layer is ContainerLayer) visit(layer.firstChild);
          }
        }

        visit(tester.binding.renderViews.first.debugLayer);
        return found;
      }

      await pump(
        tester,
        page(
          large(
            expandedHeight: 200,
            background: const ColoredBox(color: picture),
          ),
        ),
      );
      await scrollTo(tester, 400);
      expect(blurred(), isFalse);
      // Collapsed, the bar is its own surface: the picture has gone.
      expect(await sampler.pixel(tester, const Offset(300, 20)), _fill);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      LiquidGlass.debugHasShaderFilters = true;
      try {
        await pump(
          tester,
          page(
            large(
              expandedHeight: 200,
              background: const ColoredBox(color: picture),
            ),
          ),
        );
        await scrollTo(tester, 400);
        // The picture is not kept behind the toolbar: what is there is the
        // page, under the scroll edge.
        final sample = await sampler.pixel(tester, const Offset(300, 20));
        expect(sample.g, lessThan(.9));
      } finally {
        debugDefaultTargetPlatformOverride = null;
        LiquidGlass.debugHasShaderFilters = null;
      }
    });

    testWidgets('scrolling builds nothing in the bar', (tester) async {
      var builds = 0;
      await pump(
        tester,
        page(
          SliverAppBar.large(
            title: Builder(
              builder: (context) {
                builds++;
                return const Text('Library');
              },
            ),
            bottom: Builder(
              builder: (context) {
                builds++;
                return const SizedBox(height: 40);
              },
            ),
            actions: [
              Builder(
                builder: (context) {
                  builds++;
                  return const SizedBox(width: 20, height: 20);
                },
              ),
            ],
          ),
        ),
      );
      final before = builds;
      for (final offset in [5.0, 30.0, 60.0, 200.0, 900.0, 40.0, 0.0]) {
        await scrollTo(tester, offset);
      }
      expect(builds, before);
    });

    testWidgets('collapsed and pinned, a scroll paints nothing of the bar; '
        'while it collapses, the bar is painted', (tester) async {
      var paints = 0;
      await pump(
        tester,
        page(
          SliverAppBar.large(
            title: const Text('Library'),
            actions: [
              CustomPaint(
                size: const Size(20, 20),
                painter: _CountingPainter(() => paints++),
              ),
            ],
          ),
        ),
      );
      // Under way: the bar is painted as it collapses.
      var before = paints;
      for (final offset in [10.0, 20.0, 30.0]) {
        await scrollTo(tester, offset);
      }
      expect(paints, greaterThan(before));
      // Collapsed: the page goes on under a bar that stays as it is.
      await scrollTo(tester, 400);
      before = paints;
      for (final offset in [450.0, 600.0, 900.0, 700.0]) {
        await scrollTo(tester, offset);
      }
      expect(paints, before);
    });

    testWidgets('bottom stays under the toolbar when the title has gone, '
        'inside the surface, and still takes taps', (tester) async {
      var taps = 0;
      await pump(
        tester,
        page(
          large(
            bottom: GestureDetector(
              key: _bottom,
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(height: 44),
            ),
          ),
        ),
      );
      final toolbar = toolbarHeight(tester);
      final expanded = tester.getRect(find.byKey(_bottom)).top - toolbar;
      expect(expanded, greaterThan(30));
      await tester.tap(find.byKey(_bottom));
      expect(taps, 1);

      await scrollTo(tester, 500);
      final bottom = tester.getRect(find.byKey(_bottom));
      expect(bottom.top, toolbar);
      expect(bottom.height, 44);
      await tester.tap(find.byKey(_bottom));
      expect(taps, 2);
      // The surface reaches down behind it; the page is below.
      expect(await sampler.pixel(tester, Offset(300, toolbar + 20)), _fill);
      expect(await sampler.pixel(tester, Offset(300, toolbar + 60)), _page);
    });

    testWidgets('what has gone under the toolbar is not shown and cannot be '
        "touched; the toolbar's buttons always can", (tester) async {
      var taps = 0;
      var titleTaps = 0;
      await pump(
        tester,
        page(
          SliverAppBar.large(
            title: GestureDetector(
              onTap: () => titleTaps++,
              child: const Text('Library'),
            ),
            actions: [
              GestureDetector(
                key: const Key('action'),
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(width: 44, height: 44),
              ),
            ],
          ),
        ),
      );
      await scrollTo(tester, 30);
      await tester.tap(find.byKey(const Key('action')));
      expect(taps, 1);
      await scrollTo(tester, 600);
      await tester.tap(find.byKey(const Key('action')));
      expect(taps, 2);
      // The row that scrolled up behind the bar is not reachable through
      // it.
      await tester.tapAt(const Offset(60, 30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('unpinned, the whole bar scrolls away once it has collapsed', (
      tester,
    ) async {
      await pump(tester, page(large(pinned: false)));
      final toolbar = toolbarHeight(tester);
      final full = tester.getRect(find.byKey(_row)).top;
      await scrollTo(tester, full - 10);
      // The expanded area went first; ten points of the toolbar are left.
      expect(
        tester.getRect(smallTitle('Library')).center.dy,
        toolbarCenter(tester) - (toolbar + 1 - 10),
      );
      await scrollTo(tester, full + 100);
      expect(await sampler.pixel(tester, const Offset(300, 20)), _page);
    });

    testWidgets('pulled down past the top with bouncing physics, the '
        'expanded area grows and the title a little with it', (tester) async {
      await pump(
        tester,
        page(
          large(),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
        ),
      );
      final rest = tester.getRect(largeTitle('Library'));
      final row = tester.getRect(find.byKey(_row)).top;

      final gesture = await tester.startGesture(const Offset(200, 500));
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();
      final pulled = -controller.offset;
      expect(pulled, greaterThan(40));
      // The toolbar stays; the list goes down with the pull, and the bar
      // fills the gap.
      expect(
        tester.getRect(smallTitle('Library')).center.dy,
        toolbarCenter(tester),
      );
      expect(tester.getRect(find.byKey(_row)).top, closeTo(row + pulled, .5));
      final stretched = tester.getRect(largeTitle('Library'));
      // (Grown about the bottom of its area, a gap below the text.)
      expect(stretched.bottom, closeTo(rest.bottom + pulled, 1.5));
      // Grown from its start corner, and no more than a tenth.
      expect(stretched.left, rest.left);
      expect(stretched.width, greaterThan(rest.width));
      expect(stretched.width, lessThanOrEqualTo(rest.width * 1.1 + .01));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(largeTitle('Library')), rest);
    });

    testWidgets('with reduced motion, or stretch: false, the title keeps '
        'its size', (tester) async {
      for (final (reduce, stretch) in [(true, true), (false, false)]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await pump(
          tester,
          page(
            large(stretch: stretch),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
          ),
          reduce: reduce,
        );
        final rest = tester.getRect(largeTitle('Library'));
        final gesture = await tester.startGesture(const Offset(200, 500));
        await gesture.moveBy(const Offset(0, 30));
        await gesture.moveBy(const Offset(0, 200));
        await tester.pump();
        expect(controller.offset, lessThan(-40));
        expect(tester.getRect(largeTitle('Library')).width, rest.width);
        await gesture.up();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a background fills the expanded area and the toolbar, lags '
        'behind the page and fades out', (tester) async {
      const picture = Color(0xff00ff00);
      await pump(
        tester,
        page(
          large(
            expandedHeight: 200,
            background: const ColoredBox(
              key: Key('picture'),
              color: picture,
            ),
          ),
        ),
      );
      final toolbar = toolbarHeight(tester);
      final rect = tester.getRect(find.byKey(const Key('picture')));
      expect(rect, Rect.fromLTWH(0, 0, 390, toolbar + 200));
      // The picture shows through in the middle; the page colour is
      // brought up behind the title at the bottom.
      final middle = await sampler.pixel(tester, Offset(300, toolbar + 60));
      expect(middle.g, greaterThan(.8));
      final low = await sampler.pixel(tester, Offset(300, toolbar + 197));
      final themed = themeOf(tester, bar()).colorScheme.background;
      expect(low.g, closeTo(themed.g, .05));
      expect(low.r, closeTo(themed.r, .05));

      await scrollTo(tester, 100);
      // Half the page's speed.
      expect(tester.getRect(find.byKey(const Key('picture'))).top, -50);
      final fading = await sampler.pixel(tester, Offset(300, toolbar + 20));
      expect(fading.g, lessThan(middle.g));

      // Collapsed, it has faded out and the bar is its own surface.
      await scrollTo(tester, 400);
      expect(await sampler.pixel(tester, const Offset(300, 20)), _fill);
    });

    testWidgets('a solid bar keeps its fill over a picture, which starts '
        'below it, and its buttons plain', (tester) async {
      // Liquid Glass without shader filters, as in a browser.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      LiquidGlass.debugHasShaderFilters = false;
      try {
        const picture = Color(0xff00ff00);
        await pump(
          tester,
          page(
            large(
              expandedHeight: 200,
              background: const ColoredBox(
                key: Key('picture'),
                color: picture,
              ),
              actions: [
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.bell),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
        final toolbar = toolbarHeight(tester);
        final rect = tester.getRect(find.byKey(const Key('picture')));
        expect(rect.top, toolbar);
        expect(rect.bottom, toolbar + 200);
        // The toolbar is the bar's own colour at rest, not the picture.
        expect(await sampler.pixel(tester, const Offset(200, 10)), _fill);
        expect(
          (await sampler.pixel(tester, Offset(200, toolbar + 40))).g,
          greaterThan(.8),
        );
        final button = tester.widget<Button>(
          find.descendant(of: bar(), matching: find.byType(Button)).first,
        );
        expect(
          BarButtonScope.variantOf(
            tester.element(find.byWidget(button)),
            button.variant,
          ),
          ButtonVariant.ghost,
        );

        // Collapsed, nothing of the picture shows under the toolbar.
        await scrollTo(tester, 400);
        expect(await sampler.pixel(tester, const Offset(200, 10)), _fill);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        LiquidGlass.debugHasShaderFilters = null;
      }
    });

    testWidgets("on Liquid Glass the scroll edge is the collapsed bar's "
        'height and reaches below it', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      LiquidGlass.debugHasShaderFilters = true;
      try {
        await pump(tester, page(large(expandedHeight: 200)));
        await scrollTo(tester, 600);
        // A glass bar keeps iOS's height, with a margin above it.
        final theme = themeOf(tester, bar());
        final toolbar =
            theme.layoutTheme.gap(GapSize.sm) + theme.appBarTheme.height!;
        final edge = find.byType(LiquidGlassScrollEdge);
        expect(edge, findsOneWidget);
        // The collapsed bar (with the glass bar's margin above its
        // toolbar), not the whole expanded box: only its top would show.
        expect(
          tester.getSize(edge).height,
          inInclusiveRange(toolbar, toolbar + 12),
        );
        // Its fade below the bar is not cut off at the bar's edge.
        final clip = tester.renderObject<RenderClipRect>(
          find.ancestor(of: edge, matching: find.byType(ClipRect)).first,
        );
        expect(
          clip.clipper!.getClip(clip.size).bottom,
          greaterThan(toolbar + 20),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
        LiquidGlass.debugHasShaderFilters = null;
      }
    });

    testWidgets('expandedHeight is a floor from the widget or the theme; '
        'the titles sit at its bottom', (tester) async {
      await pump(tester, page(large(expandedHeight: 180)));
      final toolbar = toolbarHeight(tester);
      expect(tester.getRect(find.byKey(_row)).top, toolbar + 180 + 1);
      final gap = themeOf(tester, bar()).layoutTheme.gapMd!;
      expect(tester.getRect(largeTitle('Library')).bottom, toolbar + 180 - gap);

      await pump(
        tester,
        page(large()),
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            expandedHeight: 140,
            largeTitleStyle: TextStyle(fontSize: 40, height: 1),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getRect(find.byKey(_row)).top, toolbar + 140 + 1);
      expect(tester.getSize(largeTitle('Library')).height, 40);
    });

    testWidgets('a subtitle sits under the large title in the muted style', (
      tester,
    ) async {
      await pump(tester, page(large(subtitle: const Text('128 albums'))));
      final theme = themeOf(tester, bar());
      final title = tester.getRect(largeTitle('Library'));
      final subtitle = tester.getRect(find.text('128 albums'));
      expect(subtitle.top, greaterThan(title.bottom));
      expect(subtitle.left, title.left);
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('128 albums')),
        ).style.color,
        theme.textTheme.muted.color,
      );
    });

    testWidgets('mirrors in a right-to-left language', (tester) async {
      await pump(tester, page(large()), direction: TextDirection.rtl);
      final margin = themeOf(tester, bar()).layoutTheme.pagePadding!.horizontal;
      expect(tester.getRect(largeTitle('Library')).right, 390 - margin / 2);
    });

    testWidgets('a primary bar covers the status bar and styles it', (
      tester,
    ) async {
      await pump(
        tester,
        page(large(), background: null),
        padding: const EdgeInsets.only(top: 44),
        theme: ThemeData(brightness: Brightness.dark),
      );
      expect(
        tester.getRect(smallTitle('Library')).center.dy,
        44 + barHeight(tester) / 2,
      );
      final style = tester.binding.renderViews.first.debugLayer!
          .find<SystemUiOverlayStyle>(const Offset(195, 10))!;
      expect(style.statusBarIconBrightness, Brightness.light);
    });

    testWidgets('grows with the text scale instead of clipping', (
      tester,
    ) async {
      await pump(tester, page(large(subtitle: const Text('128 albums'))));
      final normal = tester.getRect(find.byKey(_row)).top;
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(
        tester,
        page(large(subtitle: const Text('128 albums'))),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final scaled = tester.getRect(find.byKey(_row)).top;
      expect(scaled, greaterThan(normal + 30));
      expect(
        tester.getRect(find.text('128 albums')).bottom,
        lessThan(scaled),
      );
    });

    testWidgets('is read as one heading, with its subtitle', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, page(large(subtitle: const Text('128 albums'))));
      expect(find.bySemanticsLabel('Library'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Library'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(find.bySemanticsLabel('128 albums'), findsOneWidget);
      // The same after it has collapsed.
      await scrollTo(tester, 500);
      expect(find.bySemanticsLabel('Library'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('shows the back button a pushed page calls for', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await pump(
        tester,
        const Center(child: Text('Home')),
        navigatorKey: navigator,
      );
      navigator.currentState!.push(
        UnaPageRoute<void>(builder: (_) => page(large())),
      );
      await tester.pumpAndSettle();
      expect(inBar(find.byType(BackButton)), findsOneWidget);
      await scrollTo(tester, 300);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });

  testWidgets('a long title over a picture stands on the page colour', (
    tester,
  ) async {
    const picture = Color(0xff000000);
    await pump(
      tester,
      page(
        const SliverAppBar.large(
          title: Text('A name long enough to wrap onto a second line'),
          subtitle: Text('A headline that also runs onto two lines here'),
          expandedHeight: 120,
          background: ColoredBox(color: picture),
        ),
      ),
    );
    final context = tester.element(find.byType(SliverAppBar));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final toolbar = theme.appBarTheme.height!;
    final rows = tester.getRect(find.byKey(_row));
    // At the end of the subtitle's line, under the first line of the
    // title, and the gap above the title: the page colour, not the
    // picture, wherever the titles are.
    final title = tester.getRect(
      find.text('A name long enough to wrap onto a second line').first,
    );
    for (final y in [
      title.top - 2,
      title.top + 4,
      title.bottom - 2,
      rows.top - 4,
    ]) {
      expect(
        await sampler.pixel(tester, Offset(rows.right - 2, y)),
        scheme.background,
        reason: 'at $y',
      );
    }
    // Above the fade, under the toolbar, the picture still shows.
    if (title.top - theme.layoutTheme.gapMd! * 5 > toolbar) {
      expect(
        await sampler.pixel(tester, Offset(rows.right - 2, toolbar + 1)),
        isNot(scheme.background),
      );
    }
  });

  group('SliverAppBar', () {
    Widget plain({
      bool pinned = true,
      bool floating = false,
      AppBarSurfaceBehavior? behavior,
      Widget? bottom,
      bool? centerTitle,
    }) => SliverAppBar(
      title: const Text('Feed'),
      backgroundColor: _fill,
      pinned: pinned,
      floating: floating,
      surfaceBehavior: behavior,
      bottom: bottom,
      centerTitle: centerTitle,
    );

    testWidgets('builds in every layout', (tester) async {
      await expectBuildsInEveryLayout(
        tester,
        (layout) => page(plain(bottom: const SizedBox(height: 40))),
      );
    });

    testWidgets('pinned, it looks and measures like an AppBar and stays put', (
      tester,
    ) async {
      await pump(tester, page(plain()));
      final toolbar = toolbarHeight(tester);
      expect(tester.getRect(find.byKey(_row)).top, toolbar + 1);
      expect(await sampler.pixel(tester, const Offset(300, 20)), _fill);
      await scrollTo(tester, 700);
      expect(
        tester.getRect(find.text('Feed')).center.dy,
        toolbarCenter(tester),
      );
      expect(await sampler.pixel(tester, const Offset(300, 20)), _fill);
      expect(await sampler.pixel(tester, Offset(300, toolbar + 30)), _page);
    });

    testWidgets('whenScrolled: bare at the top, its surface once the page '
        'moves', (tester) async {
      await pump(
        tester,
        page(plain(behavior: AppBarSurfaceBehavior.whenScrolled)),
      );
      expect(await sampler.pixel(tester, const Offset(300, 20)), _page);
      // The surface fades: see below.
      await scrollTo(tester, 10);
      await tester.pump(const Duration(milliseconds: 300));
      expect(await sampler.pixel(tester, const Offset(300, 20)), _fill);
      await scrollTo(tester, 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(await sampler.pixel(tester, const Offset(300, 20)), _page);
    });

    testWidgets('whenScrolled: the surface fades in and out, as an AppBar '
        'does', (tester) async {
      await pump(
        tester,
        page(plain(behavior: AppBarSurfaceBehavior.whenScrolled)),
      );
      const inToolbar = Offset(300, 20);
      await scrollTo(tester, 10);
      final frames = await sampler.record(tester, inToolbar, frames: 16);
      expectMonotone(frames, reason: 'appearing');
      expect(frames.first, isNot(_fill), reason: 'snapped in');
      expect(frames.last, _fill);
      // Scrolling on changes nothing more.
      await scrollTo(tester, 300);
      expect(await sampler.pixel(tester, inToolbar), _fill);
      await scrollTo(tester, 0);
      final back = await sampler.record(tester, inToolbar, frames: 16);
      expectMonotone(back, reason: 'leaving');
      expect(back.first, isNot(_page), reason: 'snapped out');
      expect(back.last, _page);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('unpinned, it scrolls away with the page and only comes '
        'back at the top', (tester) async {
      await pump(tester, page(plain(pinned: false)));
      await scrollTo(tester, 30);
      expect(
        tester.getRect(find.text('Feed')).center.dy,
        toolbarCenter(tester) - 30,
      );
      await scrollTo(tester, 600);
      expect(await sampler.pixel(tester, const Offset(300, 20)), _page);
      await scrollTo(tester, 500);
      expect(await sampler.pixel(tester, const Offset(300, 20)), _page);
      await scrollTo(tester, 0);
      expect(
        tester.getRect(find.text('Feed')).center.dy,
        toolbarCenter(tester),
      );
    });

    testWidgets('floating, it comes back as soon as the page turns round, '
        'point for point', (tester) async {
      await pump(tester, page(plain(pinned: false, floating: true)));
      final toolbar = toolbarHeight(tester);
      final full = toolbar + 1;
      await scrollTo(tester, 600);
      expect(await sampler.pixel(tester, const Offset(300, 20)), _page);

      await scrollTo(tester, 580);
      // Twenty points back: twenty points of bar.
      expect(
        tester.getRect(find.text('Feed')).center.dy,
        toolbarCenter(tester) - (full - 20),
      );
      await scrollTo(tester, 600 - full);
      expect(
        tester.getRect(find.text('Feed')).center.dy,
        toolbarCenter(tester),
      );
      // On down again and it goes out again.
      await scrollTo(tester, 600 - full + 25);
      expect(
        tester.getRect(find.text('Feed')).center.dy,
        toolbarCenter(tester) - 25,
      );
      // The rows are where the page has them throughout.
      expect(
        tester.getRect(find.text('Row 20')).top,
        full + 20 * 60 - controller.offset,
      );
    });

    testWidgets('left half shown when the scrolling stops, a floating bar '
        'settles fully in or out', (tester) async {
      await pump(tester, page(plain(pinned: false, floating: true)));
      final toolbar = toolbarHeight(tester);
      controller.jumpTo(600);
      await tester.pump();

      // A drag back that shows most of it, then let go.
      var gesture = await tester.startGesture(const Offset(200, 400));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(Offset(0, toolbar * .4));
      await tester.pump();
      expect(
        tester.getRect(find.text('Feed')).center.dy,
        inExclusiveRange(0, toolbarCenter(tester)),
      );
      await gesture.up();
      final positions = <double>[];
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        positions.add(tester.getRect(find.text('Feed')).center.dy);
      }
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThanOrEqualTo(positions[i - 1] - .01));
      }
      expect(positions.last, toolbarCenter(tester));
      await tester.pumpAndSettle();

      // A drag on that hides most of it: it goes out.
      gesture = await tester.startGesture(const Offset(200, 400));
      await gesture.moveBy(const Offset(0, -20));
      await gesture.moveBy(Offset(0, -toolbar * .4));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(await sampler.pixel(tester, const Offset(300, 20)), _page);
    });

    testWidgets('bottom is part of the bar, under the toolbar', (tester) async {
      await pump(
        tester,
        page(plain(bottom: const SizedBox(key: _bottom, height: 40))),
      );
      final toolbar = toolbarHeight(tester);
      expect(tester.getRect(find.byKey(_bottom)).top, toolbar);
      expect(tester.getRect(find.byKey(_row)).top, toolbar + 40 + 1);
      await scrollTo(tester, 500);
      expect(tester.getRect(find.byKey(_bottom)).top, toolbar);
    });

    testWidgets('centerTitle centres the title', (tester) async {
      await pump(tester, page(plain(centerTitle: true)));
      expect(tester.getCenter(find.text('Feed')).dx, 195);
    });

    testWidgets('a glass bar blurs what scrolls under it; an opaque one '
        'builds no filter', (tester) async {
      await pump(
        tester,
        page(const SliverAppBar(title: Text('Feed'))),
      );
      expect(inBar(find.byType(BackdropFilter)), findsOneWidget);
      await pump(
        tester,
        page(const SliverAppBar(title: Text('Feed'))),
        theme: ThemeData(style: StyleTokens.crisp),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(inBar(find.byType(BackdropFilter)), findsNothing);
    });
  });
}

/// Counts how often it is painted.
class _CountingPainter extends CustomPainter {
  _CountingPainter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_CountingPainter oldDelegate) => false;
}

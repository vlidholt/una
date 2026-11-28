import 'package:example/docs/docs.dart';
import 'package:example/docs/examples/sliver_app_bar/sliver_app_bar_background.dart';
import 'package:example/docs/examples/sliver_app_bar/sliver_app_bar_bottom.dart';
import 'package:example/docs/examples/sliver_app_bar/sliver_app_bar_floating.dart';
import 'package:example/docs/examples/sliver_app_bar/sliver_app_bar_large.dart';
import 'package:example/docs/examples/sliver_app_bar/sliver_app_bar_liquid_glass.dart';
import 'package:flutter/widgets.dart';

final sliverAppBarDoc = ComponentDoc(
  slug: 'sliver_app_bar',
  title: 'Sliver App Bar',
  description:
      'An app bar that lives in the scroll view: it can carry a large title '
      'that collapses into the toolbar, scroll away with the page, or come '
      'back when the reader turns round. Make it the first sliver of the '
      '`CustomScrollView` in a `Scaffold`\'s body and give the scaffold no '
      '`appBar`. It follows the scroll at paint time — scrolling builds and '
      'lays out nothing in it.',
  examples: [
    ComponentExample(
      id: 'sliver_app_bar_large',
      title: 'Large title',
      description:
          '`SliverAppBar.large` sets the title large under the toolbar, at '
          'the page margin. As the page scrolls the large title slides '
          'under the toolbar, the same title fades in small and the bar '
          'takes its fill, hairline and blur. With bouncing physics, '
          'pulling down grows the expanded area and the title a little '
          '(`stretch`). The style comes from '
          '`AppBarTheme.largeTitleStyle`.',
      minPreviewHeight: 620,
      padding: const EdgeInsets.all(24),
      builder: (_) => const SliverAppBarLargeExample(),
    ),
    ComponentExample(
      id: 'sliver_app_bar_bottom',
      title: 'With a search field',
      description:
          '`bottom` stays when the title has gone: a search field, a '
          '`TabBar`, filter chips. The bar is measured, so it can be any '
          'height.',
      minPreviewHeight: 620,
      padding: const EdgeInsets.all(24),
      builder: (_) => const SliverAppBarBottomExample(),
    ),
    ComponentExample(
      id: 'sliver_app_bar_background',
      title: 'With a picture',
      description:
          '`background` fills the expanded area behind the title and the '
          'toolbar. It lags behind the page, fades as the bar collapses and '
          'grows when the page is pulled down. `expandedHeight` gives it '
          'room. With reduced motion it neither lags nor grows.',
      minPreviewHeight: 620,
      padding: const EdgeInsets.all(24),
      builder: (_) => const SliverAppBarBackgroundExample(),
    ),
    ComponentExample(
      id: 'sliver_app_bar_liquid_glass',
      title: 'Filled or Liquid Glass, over a picture',
      description:
          'Over a `background` picture both bars put their buttons on '
          'discs. The picture goes with the page as the bar collapses. '
          'Collapsed, the filled bar is its own surface and ends on its '
          'hairline, with no blur. On Liquid Glass the bar has no fill: the '
          'page scrolled under it is blurred and faded into the page '
          'colour, and the buttons stand on capsules of glass. In a browser '
          'the glass bar keeps that '
          'soft edge only with `LiquidGlassMode.always` or '
          '`LiquidGlassTheme.webScrollEdge`.',
      minPreviewHeight: 600,
      padding: const EdgeInsets.all(24),
      builder: (_) => const SliverAppBarLiquidGlassExample(),
    ),
    ComponentExample(
      id: 'sliver_app_bar_floating',
      title: 'Floating',
      description:
          'The plain constructor looks like an `AppBar`. `pinned`, the '
          'default, keeps it at the top. Unpinned it scrolls away, and '
          'with `floating` it returns as soon as the page moves the other '
          'way, wherever the page is.',
      minPreviewHeight: 620,
      padding: const EdgeInsets.all(24),
      builder: (_) => const SliverAppBarFloatingExample(),
    ),
  ],
);

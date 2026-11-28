# Sliver App Bar

An app bar that lives in the scroll view: it can carry a large title that collapses into the toolbar, scroll away with the page, or come back when the reader turns round. Make it the first sliver of the `CustomScrollView` in a `Scaffold`'s body and give the scaffold no `appBar`. It follows the scroll at paint time — scrolling builds and lays out nothing in it.

## Large title

`SliverAppBar.large` sets the title large under the toolbar, at the page margin. As the page scrolls the large title slides under the toolbar, the same title fades in small and the bar takes its fill, hairline and blur. With bouncing physics, pulling down grows the expanded area and the title a little (`stretch`). The style comes from `AppBarTheme.largeTitleStyle`.

```dart
import 'package:example/docs/phone_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// A large title. Scroll: it slides under the toolbar, the same title fades
/// in small, and the bar takes its surface. Pull down at the top and the
/// title grows a little.
class SliverAppBarLargeExample extends StatelessWidget {
  const SliverAppBarLargeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        // No `appBar`: the bar is the first sliver of the page.
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar.large(
              title: const Text('Library'),
              subtitle: const Text('128 albums'),
              actions: [
                IconButton.ghost(
                  icon: const PhosphorIcon(PhosphorIconsRegular.plus),
                  semanticLabel: 'Add',
                  onPressed: () {},
                ),
              ],
            ),
            SliverList.builder(
              itemCount: 30,
              itemBuilder: (context, index) => ListTile(
                leading: const IconTile(
                  icon: PhosphorIcon(PhosphorIconsRegular.vinylRecord),
                ),
                title: Text('Album ${index + 1}'),
                subtitle: const Text('12 songs'),
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## With a search field

`bottom` stays when the title has gone: a search field, a `TabBar`, filter chips. The bar is measured, so it can be any height.

```dart
import 'package:example/docs/phone_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// A search field in `bottom`. It stays under the toolbar when the large
/// title has gone, inside the bar's surface.
class SliverAppBarBottomExample extends StatefulWidget {
  const SliverAppBarBottomExample({super.key});

  @override
  State<SliverAppBarBottomExample> createState() =>
      _SliverAppBarBottomExampleState();
}

class _SliverAppBarBottomExampleState extends State<SliverAppBarBottomExample> {
  static const _people = [
    'Aisha Rahman',
    'Claire Dubois',
    'Elena Petrova',
    'Freya Holm',
    'Irina Volkova',
    'Julian Reyes',
    'Mateo Alvarez',
    'Mei Tanaka',
    'Noor Haddad',
    'Omar Rahimi',
    'Rafael Cruz',
    'Sara Lindqvist',
  ];

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = theme.layoutTheme.gap(GapSize.lg);
    final matches = [
      for (final person in _people)
        if (person.toLowerCase().contains(_query.toLowerCase())) person,
    ];
    return PhoneFrame(
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('Contacts'),
              bottom: Padding(
                padding: EdgeInsets.fromLTRB(
                  margin,
                  0,
                  margin,
                  theme.layoutTheme.gap(GapSize.md),
                ),
                // Cancel slides in beside the field while it has the
                // focus, as in a search bar on iOS.
                child: SearchField(
                  showCancel: true,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) => ListTile(
                leading: Avatar('', fallback: Text(matches[index][0])),
                title: Text(matches[index]),
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## With a picture

`background` fills the expanded area behind the title and the toolbar. It lags behind the page, fades as the bar collapses and grows when the page is pulled down. `expandedHeight` gives it room. With reduced motion it neither lags nor grows.

```dart
import 'package:example/docs/phone_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// A picture behind the large title. It moves at half the page's speed,
/// fades as the bar collapses, and grows when the page is pulled down. The
/// page colour is brought up behind the title, so the title reads on any
/// picture in either brightness.
class SliverAppBarBackgroundExample extends StatelessWidget {
  const SliverAppBarBackgroundExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PhoneFrame(
      child: Scaffold(
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar.large(
              title: const Text('Lofoten'),
              subtitle: const Text('Seven days above the Arctic Circle'),
              expandedHeight: 220,
              background: Image.asset(
                'assets/images/photo_alpine_lake.jpg',
                fit: BoxFit.cover,
              ),
              leading: BackButton(onPressed: () {}),
              actions: [
                IconButton.ghost(
                  icon: const PhosphorIcon(PhosphorIconsRegular.shareNetwork),
                  semanticLabel: 'Share',
                  onPressed: () {},
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.all(theme.layoutTheme.gap(GapSize.lg)),
              sliver: SliverList.separated(
                itemCount: 7,
                separatorBuilder: (_, _) => const Gap.md(),
                itemBuilder: (context, index) => Card(
                  title: Text('Day ${index + 1}'),
                  description: const Text('Reine to Hamnøy'),
                  child: Text(
                    'Up before the light for the ridge above the harbour, '
                    'then the long road north along the water.',
                    style: theme.textTheme.small,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Filled or Liquid Glass, over a picture

Over a `background` picture both bars put their buttons on discs. The picture goes with the page as the bar collapses. Collapsed, the filled bar is its own surface and ends on its hairline, with no blur. On Liquid Glass the bar has no fill: the page scrolled under it is blurred and faded into the page colour, and the buttons stand on capsules of glass. In a browser the glass bar keeps that soft edge only with `LiquidGlassMode.always` or `LiquidGlassTheme.webScrollEdge`.

```dart
import 'package:example/docs/phone_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// A large bar over a photograph, filled and on Liquid Glass. The picture
/// goes with the page; collapsed, the filled bar is its surface and ends
/// on its hairline, and the glass bar has no fill: the page under it is
/// blurred and faded into the page colour.
class SliverAppBarLiquidGlassExample extends StatelessWidget {
  const SliverAppBarLiquidGlassExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 24,
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: [
        _Screen(label: 'Filled', liquidGlass: LiquidGlassMode.never),
        _Screen(label: 'Liquid Glass', liquidGlass: LiquidGlassMode.always),
      ],
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.label, required this.liquidGlass});

  final String label;
  final LiquidGlassMode liquidGlass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Text(label, style: theme.textTheme.small),
        PhoneFrame(
          height: 520,
          child: Scaffold(
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar.large(
                  liquidGlass: liquidGlass,
                  title: const Text('Summit Stage'),
                  subtitle: const Text('Three nights in the mountains'),
                  expandedHeight: 200,
                  background: Image.asset(
                    'assets/images/photo_summit_stage.jpg',
                    fit: BoxFit.cover,
                  ),
                  leading: BackButton(onPressed: () {}),
                  actions: [
                    IconButton.ghost(
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.shareNetwork,
                      ),
                      semanticLabel: 'Share',
                      onPressed: () {},
                    ),
                  ],
                ),
                SliverPadding(
                  padding: EdgeInsets.all(theme.layoutTheme.gap(GapSize.lg)),
                  sliver: SliverList.separated(
                    itemCount: 6,
                    separatorBuilder: (_, _) => const Gap.md(),
                    itemBuilder: (context, index) => Card(
                      title: Text('Night ${index + 1}'),
                      description: const Text('Main stage, 21:00'),
                      child: Text(
                        'Doors at 20:00, the first act as the light goes, '
                        'and the headliner under the stars.',
                        style: theme.textTheme.small,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

## Floating

The plain constructor looks like an `AppBar`. `pinned`, the default, keeps it at the top. Unpinned it scrolls away, and with `floating` it returns as soon as the page moves the other way, wherever the page is.

```dart
import 'package:example/docs/phone_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// A plain bar that is not pinned. It scrolls away with the page; with
/// `floating` it comes back the moment the page is scrolled the other way,
/// and settles fully in or out when the scrolling stops.
class SliverAppBarFloatingExample extends StatelessWidget {
  const SliverAppBarFloatingExample({super.key});

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: true,
              title: const Text('Feed'),
              actions: [
                IconButton.ghost(
                  icon: const PhosphorIcon(PhosphorIconsRegular.bell),
                  semanticLabel: 'Notifications',
                  onPressed: () {},
                ),
              ],
            ),
            SliverList.builder(
              itemCount: 40,
              itemBuilder: (context, index) => ListTile(
                title: Text('Post ${index + 1}'),
                subtitle: const Text('Scroll down, then a little back up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

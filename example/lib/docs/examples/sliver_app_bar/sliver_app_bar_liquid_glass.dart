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

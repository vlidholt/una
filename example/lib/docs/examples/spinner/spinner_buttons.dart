import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// A spinner takes the colour of what it sits in: a button's content, a
/// line of muted text.
class SpinnerButtonsExample extends StatelessWidget {
  const SpinnerButtonsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            Button(
              loading: true,
              onPressed: () {},
              child: const Text('Save changes'),
            ),
            Button.secondary(
              onPressed: () {},
              leading: const Spinner.orbit(),
              child: const Text('Syncing'),
            ),
            Button.outline(
              onPressed: () {},
              leading: const Spinner.morph(),
              child: const Text('Thinking'),
            ),
          ],
        ),
        IconTheme(
          data: IconThemeData(color: theme.colorScheme.mutedForeground),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              const Spinner.goo(),
              Text('Uploading 3 photos…', style: theme.textTheme.muted),
            ],
          ),
        ),
        // A status pill in the page's ink, the halo in the colour of its
        // text.
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.foreground,
            borderRadius: theme.radii.full,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
            child: IconTheme(
              data: IconThemeData(color: theme.colorScheme.background),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  const Spinner.halo(size: 24),
                  Text(
                    'Working',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.background,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

# Spinner

A small animated loading indicator for a button or a line of text. Five looks: the ring, orbit, morph, goo and halo.

## Sizes

The default spinner is the indeterminate progress ring, small: an arc that turns while it grows and shrinks. `size` is its diameter (16 by default) and the stroke follows it. It takes the ambient icon colour.

```dart
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

class SpinnerBasicExample extends StatelessWidget {
  const SpinnerBasicExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [
        Spinner(),
        Spinner(size: 24),
        Spinner(size: 32),
        Spinner(size: 48),
      ],
    );
  }
}
```

## Variants

`variant:` picks a look, or use the named constructors: `Spinner.orbit()` is three comets chasing round a circle, bunching up and flinging apart; `Spinner.morph()` a shape that twists from clover to sun to pill and on; `Spinner.goo()` a drop that splits into three droplets on stretching necks and pulls itself back together; `Spinner.halo()` a ring of dots with a wave of light running round it, each dot swelling and glowing as it passes. Each reads at 16 points and holds up at any size. Under reduced motion a spinner holds still and breathes.

```dart
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// The five looks of a spinner, small and large.
class SpinnerVariantsExample extends StatelessWidget {
  const SpinnerVariantsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 40,
      runSpacing: 32,
      alignment: WrapAlignment.center,
      children: [
        for (final variant in SpinnerVariant.values)
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 16,
                children: [
                  Spinner(variant: variant),
                  Spinner(variant: variant, size: 24),
                  Spinner(variant: variant, size: 56),
                ],
              ),
              Text(variant.name, style: theme.textTheme.muted),
            ],
          ),
      ],
    );
  }
}
```

## In buttons and text

A spinner spins in the colour of what it sits in: a button's content colour, the icon colour around a line of muted text. A button's own `loading` puts one over its label.

```dart
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
```

## One look for the whole app

`SpinnerTheme(variant: ...)` in `ThemeData(spinnerTheme:)` sets the look of every spinner that does not choose one, a button's `loading` spinner and a loading toast's among them. `SpinnerTheme.duration` sets the pace of one cycle.

```dart
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// `SpinnerTheme.variant` changes every spinner below that does not choose
/// one — here the buttons' loading spinners.
class SpinnerThemeExample extends StatefulWidget {
  const SpinnerThemeExample({super.key});

  @override
  State<SpinnerThemeExample> createState() => _SpinnerThemeExampleState();
}

class _SpinnerThemeExampleState extends State<SpinnerThemeExample> {
  var _variant = SpinnerVariant.goo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [
        SegmentedControl<SpinnerVariant>(
          value: _variant,
          onChanged: (variant) => setState(() => _variant = variant),
          segments: [
            for (final variant in SpinnerVariant.values)
              Segment(value: variant, label: Text(variant.name)),
          ],
        ),
        SpinnerThemeScope(variant: _variant),
      ],
    );
  }
}

/// The part of the app that the spinner theme reaches.
class SpinnerThemeScope extends StatelessWidget {
  const SpinnerThemeScope({super.key, required this.variant});

  final SpinnerVariant variant;

  @override
  Widget build(BuildContext context) {
    // In an app this is `ThemeData(spinnerTheme: ...)`; here it is set for
    // the buttons below only.
    final ambient = Theme.of(context);
    return Theme(
      data: _themes[variant]![ambient] ??= ambient.copyWith(
        spinnerTheme: SpinnerTheme(variant: variant),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          Button(loading: true, onPressed: () {}, child: const Text('Pay')),
          Button.outline(
            loading: true,
            onPressed: () {},
            child: const Text('Publishing'),
          ),
        ],
      ),
    );
  }

  /// A theme is derived once per variant and ambient theme, not on every
  /// build: `copyWith` derives every component theme again.
  static final _themes = {
    for (final variant in SpinnerVariant.values) variant: Expando<ThemeData>(),
  };
}
```

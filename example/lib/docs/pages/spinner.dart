import 'package:example/docs/docs.dart';
import 'package:example/docs/examples/spinner/spinner_basic.dart';
import 'package:example/docs/examples/spinner/spinner_buttons.dart';
import 'package:example/docs/examples/spinner/spinner_theme.dart';
import 'package:example/docs/examples/spinner/spinner_variants.dart';

final spinnerDoc = ComponentDoc(
  slug: 'spinner',
  title: 'Spinner',
  description:
      'A small animated loading indicator for a button or a line of text. '
      'Five looks: the ring, orbit, morph, goo and halo.',
  examples: [
    ComponentExample(
      id: 'spinner_basic',
      title: 'Sizes',
      description:
          'The default spinner is the indeterminate progress ring, small: '
          'an arc that turns while it grows and shrinks. `size` is its '
          'diameter (16 by default) and the stroke follows it. It takes the '
          'ambient icon colour.',
      builder: (_) => const SpinnerBasicExample(),
    ),
    ComponentExample(
      id: 'spinner_variants',
      title: 'Variants',
      description:
          '`variant:` picks a look, or use the named constructors: '
          '`Spinner.orbit()` is three comets chasing round a circle, '
          'bunching up and flinging apart; `Spinner.morph()` a shape that '
          'twists from clover to sun to pill and on; `Spinner.goo()` a drop '
          'that splits into three droplets on stretching necks and pulls '
          'itself back together; `Spinner.halo()` a ring of dots with a wave '
          'of light running round it, each dot swelling and glowing as it '
          'passes. Each reads at 16 points and holds up at '
          'any size. Under reduced motion a spinner holds still and '
          'breathes.',
      minPreviewHeight: 260,
      builder: (_) => const SpinnerVariantsExample(),
    ),
    ComponentExample(
      id: 'spinner_buttons',
      title: 'In buttons and text',
      description:
          'A spinner spins in the colour of what it sits in: a button\'s '
          'content colour, the icon colour around a line of muted text. A '
          'button\'s own `loading` puts one over its label.',
      builder: (_) => const SpinnerButtonsExample(),
    ),
    ComponentExample(
      id: 'spinner_theme',
      title: 'One look for the whole app',
      description:
          '`SpinnerTheme(variant: ...)` in `ThemeData(spinnerTheme:)` sets '
          'the look of every spinner that does not choose one, a button\'s '
          '`loading` spinner and a loading toast\'s among them. '
          '`SpinnerTheme.duration` sets the pace of one cycle.',
      builder: (_) => const SpinnerThemeExample(),
    ),
  ],
);

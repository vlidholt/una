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

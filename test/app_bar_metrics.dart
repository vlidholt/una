import 'dart:math' as math;

import 'package:una/una.dart';

/// The height of a filled bar's toolbar under [theme] at a text scale of
/// 1: the theme's bar height, at least an icon button with the small gap
/// above and below it (`appBarStyleHeight`).
double filledToolbarHeight(ThemeData theme) => math.max(
  theme.appBarTheme.height!,
  theme.style.iconButtonSize + 2 * theme.layoutTheme.gap(GapSize.sm),
);

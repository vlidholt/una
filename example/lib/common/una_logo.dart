import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// The Una mark — an uppercase "U" on a soft tile in the
/// theme's primary colour — and, beside it, the wordmark.
///
/// Una is Latin for "one": one letter, one tile. The tile carries a faint
/// sheen from the top, the package's soft-glass look in miniature. The
/// same painter draws the web app icons (see `web/icons/`).
class UnaLogo extends StatelessWidget {
  const UnaLogo({this.onPressed, this.showWordmark = true, super.key});

  /// Called when the logo is tapped.
  final VoidCallback? onPressed;

  /// Whether "una" is written beside the tile.
  final bool showWordmark;

  // Off the theme's scales on purpose: the mark is a brand asset.
  static const _wordmarkGap = 10.0;
  static const _tileRadius = 9.0;

  static double _tileSize(ThemeData theme) =>
      theme.formFactor == FormFactor.mobile ? 30 : 32;

  static TextStyle _wordmarkStyle(ThemeData theme) =>
      theme.textTheme.large.copyWith(
        fontSize: 19,
        height: 1,
        fontWeight: FontWeight.w700,
        letterSpacing: -.03 * 19,
        color: theme.colorScheme.foreground,
      );

  /// The width the logo takes in [context], with or without its wordmark.
  static double widthOf(BuildContext context, {bool showWordmark = true}) {
    final theme = Theme.of(context);
    final tile = _tileSize(theme);
    if (!showWordmark) return tile;
    final painter = TextPainter(
      text: TextSpan(text: 'una', style: _wordmarkStyle(theme)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return tile + _wordmarkGap + width.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = _tileSize(theme);
    final scheme = theme.colorScheme;
    final logo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: tile,
          child: CustomPaint(
            painter: UnaMarkPainter(
              color: scheme.primary,
              ink: scheme.primaryForeground,
              radius: _tileRadius / tile,
            ),
          ),
        ),
        if (showWordmark) ...[
          const Gap.raw(_wordmarkGap),
          Text(
            'una',
            maxLines: 1,
            softWrap: false,
            style: _wordmarkStyle(theme),
          ),
        ],
      ],
    );

    if (onPressed == null) {
      return Semantics(
        label: 'Una',
        child: ExcludeSemantics(child: logo),
      );
    }
    return Pressable(
      onPressed: onPressed,
      semanticLabel: 'Una home',
      builder: (context, states) => FocusRing(
        visible: states.contains(WidgetState.focused),
        borderRadius: BorderRadius.circular(_tileRadius),
        child: ExcludeSemantics(child: logo),
      ),
    );
  }
}

/// Paints the Una mark into its whole box: the tile in a diagonal gradient
/// round [color] with a sheen from the top, corners [radius] of the side (0 for a square that
/// a platform masks itself), and the "U" in [ink] at [glyph] of the side.
class UnaMarkPainter extends CustomPainter {
  const UnaMarkPainter({
    required this.color,
    required this.ink,
    this.radius = .28,
    this.glyph = .62,
  });

  final Color color;
  final Color ink;
  final double radius;
  final double glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final box = Offset.zero & Size.square(side);
    final shape = RSuperellipse.fromRectAndRadius(
      box,
      Radius.circular(side * radius),
    );
    // A diagonal from a lighter, clearer step of the primary's hue to a
    // deeper one beside it, as the demo apps' icons run: a flat tile read
    // as a placeholder next to them.
    final base = HSLColor.fromColor(color);
    HSLColor step(double hue, double saturation, double lightness) => base
        .withHue((base.hue + hue) % 360)
        .withSaturation((base.saturation * saturation).clamp(0.0, .9))
        .withLightness((base.lightness + lightness).clamp(0.0, 1.0));
    final light = step(-10, 1.7, .1).toColor();
    final deep = step(16, 1.5, -.05).toColor();
    // Through a clip and a rectangle, not `drawRSuperellipse`: on the web
    // that draws about the shape's centre and the gradient moves with it.
    canvas
      ..save()
      ..clipRSuperellipse(shape)
      ..drawRect(
        box,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [light, deep],
          ).createShader(box),
      )
      ..restore();
    // The sheen: a soft lighter band across the top, as glass catches it.
    canvas
      ..save()
      ..clipRSuperellipse(shape)
      ..drawRect(
        Rect.fromLTWH(0, 0, side, side * .5),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xffffffff).withValues(alpha: .1),
              const Color(0xffffffff).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, side, side * .5)),
      )
      ..restore();

    // The "U": one stroke on a 24-unit grid, centred in [glyph] of the tile.
    final unit = side * glyph / 24;
    canvas
      ..save()
      ..translate(side * (1 - glyph) / 2, side * (1 - glyph) / 2)
      ..scale(unit);
    // Two stems from the cap height, joined by a round bowl: as tall as
    // the lowercase letter's stem and tail were, centred on the grid.
    final u = Path()
      ..moveTo(7, 5.5)
      ..lineTo(7, 13.5)
      ..arcToPoint(
        const Offset(17, 13.5),
        radius: const Radius.circular(5),
        clockwise: false,
      )
      ..lineTo(17, 5.5);
    canvas
      ..drawPath(
        u,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(UnaMarkPainter oldDelegate) =>
      color != oldDelegate.color ||
      ink != oldDelegate.ink ||
      radius != oldDelegate.radius ||
      glyph != oldDelegate.glyph;
}

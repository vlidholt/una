import 'package:flutter/widgets.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/backdrop.dart';
import 'package:una/src/utils/shadow.dart';

/// How much of the backdrop a [Glass] surface lets through.
enum GlassLevel {
  /// A light tint: the backdrop stays clearly visible. For chrome that floats
  /// over photographs and for secondary panels.
  regular,

  /// A heavy tint that is still not opaque. For surfaces that carry text.
  strong,

  /// The bars' own glass: the bottom bar's tint, and on Liquid Glass the
  /// bottom bar's glass as the theme sets it, untinted — with the floating
  /// bar's corner radius and shadow unless given others. For a panel that
  /// floats beside the bars and should read as one of them — a player or
  /// a route in progress above the tab bar.
  bar,
}

/// A frosted-glass surface: a translucent tint over a blurred, saturated
/// backdrop, with a hairline border.
///
/// ```dart
/// Glass(
///   padding: const EdgeInsets.all(12),
///   child: const Text('Floating above the feed'),
/// )
/// ```
///
/// Blur, saturation, tint and both opacities come from the theme's
/// `GlassTheme`, which the style's `glass*` tokens feed, so glass follows the
/// colour scheme and the brightness. [color] replaces the tint outright —
/// `Glass(color: Color(0x52090909))` is the dark scrim used for labels over a
/// photo — and is then used at its own alpha.
///
/// A backdrop filter reads back and blurs everything behind the surface on
/// every frame the surface is on screen. A handful of them — the bars, an
/// open menu, a floating composer — is what glass is for; one per item of a
/// scrolling list is not, which is why `Card` only blurs when the style
/// asks for it. Where the blur would show nothing (the surface lies on a
/// flat fill) or is repeated down a list (a label on every photograph of a
/// feed), pass `frosted: false`: the same tint, border and shadow with no
/// filter and no layer.
class Glass extends StatelessWidget {
  /// Creates a glass surface.
  const Glass({
    this.child,
    this.level = GlassLevel.regular,
    this.color,
    this.frosted = true,
    this.blur,
    this.saturation,
    this.borderRadius,
    this.border,
    this.shadows,
    this.padding,
    this.width,
    this.height,
    this.constraints,
    this.alignment,
    super.key,
  });

  /// The content on the surface.
  final Widget? child;

  /// How heavy the tint is. Ignored when [color] is given.
  final GlassLevel level;

  /// The tint, used at its own alpha. Defaults to the theme's glass colour at
  /// the opacity [level] names.
  final Color? color;

  /// Whether the backdrop is blurred and saturated.
  ///
  /// False leaves the tint alone over whatever is behind it — plain
  /// translucency — and builds no backdrop filter, whatever [blur] and
  /// [saturation] say. Use it for glass inside scrolling content and for
  /// glass over a flat surface, where the filter is all cost.
  final bool frosted;

  /// The sigma of the backdrop blur. Defaults to the theme's.
  final double? blur;

  /// How much the backdrop is saturated. Defaults to the theme's.
  final double? saturation;

  /// The corner radius. Defaults to the theme's glass radius.
  final BorderRadius? borderRadius;

  /// The border. Defaults to a hairline in the theme's glass border colour;
  /// pass [Border.fromBorderSide] with [BorderSide.none] for none.
  final BoxBorder? border;

  /// Shadows cast by the surface. They are painted outside it and never show
  /// through the glass. Default to none — at the [GlassLevel.bar] level, to
  /// the floating bottom bar's.
  final List<BoxShadow>? shadows;

  /// Padding around [child].
  final EdgeInsetsGeometry? padding;

  /// A fixed width.
  final double? width;

  /// A fixed height.
  final double? height;

  /// Additional constraints on the surface.
  final BoxConstraints? constraints;

  /// How [child] is aligned within the surface.
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = theme.glassTheme;
    final bar = theme.bottomNavigationBarTheme;
    // At the bar level, the floating bottom bar's shape and shadow too.
    final radius =
        borderRadius ??
        (level == GlassLevel.bar
            ? bar.borderRadius ?? theme.radii.full
            : glass.borderRadius ?? theme.radius);
    final shadows =
        this.shadows ??
        (level == GlassLevel.bar
            ? bar.shadows ?? theme.style.floatingShadow
            : const <BoxShadow>[]);
    // A scrim (an explicit colour) and unfrosted glass stay as they are:
    // Liquid Glass stands in for the frosted surface only.
    final effectiveBorder =
        border ??
        Border.all(
          color: glass.borderColor ?? theme.colorScheme.border,
          width: glass.borderWidth ?? 1,
        );
    final base = glass.color ?? theme.colorScheme.card;
    final tint =
        color ??
        switch (level) {
          GlassLevel.bar =>
            theme.bottomNavigationBarTheme.backgroundColor ??
                base.withValues(alpha: base.a * (glass.opacity ?? .7)),
          // Multiplied, so a scheme whose card is already translucent keeps
          // that.
          GlassLevel.regular => base.withValues(
            alpha: base.a * (glass.opacity ?? .7),
          ),
          GlassLevel.strong => base.withValues(
            alpha: base.a * (glass.strongOpacity ?? .9),
          ),
        };

    if (frosted &&
        color == null &&
        LiquidGlass.isActive(context, glass.liquidGlass)) {
      if (level == GlassLevel.bar) {
        // The bottom bar's glass, with nothing of its own on it.
        return LiquidGlassSurface(
          radius: radius.topLeft.x,
          child: Container(
            width: width,
            height: height,
            constraints: constraints,
            alignment: alignment,
            padding: effectiveBorder.dimensions.add(
              padding ?? EdgeInsets.zero,
            ),
            child: child,
          ),
        );
      }
      // The same tint, blur and saturation as the frosted surface, so the
      // two read as one design; Liquid Glass adds its rim, highlights and
      // refraction on top. Left to the iOS presets, a panel was clear
      // glass whatever its level, and the text on it unreadable over a
      // photograph wherever the package has no frost to draw (the web).
      return LiquidGlassSurface(
        radius: radius.topLeft.x,
        tint: tint,
        blur: blur ?? glass.blur,
        saturation: saturation ?? glass.saturation,
        child: Container(
          width: width,
          height: height,
          constraints: constraints,
          alignment: alignment,
          // The border's point stays as padding, as a decoration's border
          // takes it, so the content sits where it does on frosted glass.
          padding: effectiveBorder.dimensions.add(
            padding ?? EdgeInsets.zero,
          ),
          child: child,
        ),
      );
    }
    Widget surface = Backdrop(
      blur: frosted ? blur ?? glass.blur ?? 0 : 0,
      saturation: frosted ? saturation ?? glass.saturation ?? 1 : 1,
      borderRadius: radius,
      child: Container(
        width: width,
        height: height,
        constraints: constraints,
        alignment: alignment,
        padding: padding,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: radius,
          border: effectiveBorder,
        ),
        child: child,
      ),
    );
    if (shadows.isNotEmpty) {
      // Outside the clip, and after the surface: a shadow painted first
      // would be sampled by the filter and blurred back into the glass.
      surface = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShadowDecoration.box(
          borderRadius: radius,
          shadows: shadows,
        ),
        child: surface,
      );
    }
    return surface;
  }
}

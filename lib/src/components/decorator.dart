import 'package:flutter/widgets.dart';
import 'package:una/src/theme/components/decorator.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/border.dart';
import 'package:una/src/utils/shadow.dart';

/// Paints a [UnaDecoration] around [child].
///
/// Picks the normal, focused or error form of each border from [focused] and
/// `decoration.hasError`, and merges [decoration] over
/// `ThemeData.decoration`.
class Decorator extends StatelessWidget {
  /// Creates a decorator.
  const Decorator({
    super.key,
    this.child,
    this.decoration,
    this.focused = false,
  });

  /// The child to decorate.
  final Widget? child;

  /// The decoration to apply to the child.
  final UnaDecoration? decoration;

  /// Whether the child has focus, defaults to false.
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDirection = Directionality.of(context);

    final effectiveDecoration = theme.decoration.merge(decoration);

    final effectiveFallbackToBorder =
        effectiveDecoration.fallbackToBorder ?? true;

    final effectiveDisableSecondaryBorder =
        effectiveDecoration.disableSecondaryBorder ??
        theme.disableSecondaryBorder;

    final hasError = effectiveDecoration.hasError ?? false;

    final fallbackBorder = switch (focused) {
      true => effectiveDecoration.focusedBorder,
      false => effectiveDecoration.border,
    };

    var border = switch (hasError) {
      true => effectiveDecoration.errorBorder,
      false => fallbackBorder,
    };

    if (effectiveFallbackToBorder && border == null) {
      border = fallbackBorder ?? effectiveDecoration.border;
    }

    final fallbackSecondaryBorder = switch (focused) {
      true => effectiveDecoration.secondaryFocusedBorder,
      false => effectiveDecoration.secondaryBorder,
    };

    var secondaryBorder = switch (hasError) {
      true => effectiveDecoration.secondaryErrorBorder,
      false => fallbackSecondaryBorder,
    };

    if (effectiveFallbackToBorder && secondaryBorder == null) {
      secondaryBorder =
          fallbackSecondaryBorder ?? effectiveDecoration.secondaryBorder;
    }

    // The shape is the control's. A radius the caller gives the
    // decoration's border — a pill-shaped field, say — is the radius of the
    // focused and error borders too, and the ring goes round it, unless the
    // caller shaped those as well: the theme's are baked at its own radius.
    final ownRadius = decoration?.border?.borderRadius;
    if (ownRadius != null) {
      final stateRadius = hasError
          ? decoration?.errorBorder?.borderRadius
          : focused
          ? decoration?.focusedBorder?.borderRadius
          : null;
      final current = border;
      if (stateRadius == null &&
          current != null &&
          current is! UnaRoundedSuperellipseBorder) {
        border = current.copyWith(borderRadius: ownRadius);
      }
      final ring = secondaryBorder;
      final ownRing =
          (hasError
                  ? decoration?.secondaryErrorBorder
                  : focused
                  ? decoration?.secondaryFocusedBorder
                  : decoration?.secondaryBorder)
              ?.borderRadius;
      if (ring != null && ownRing == null) {
        // Concentric: each corner grows by the ring's distance from it, as
        // the theme's own ring does from the theme's radius.
        final grow = ring.offset ?? 0;
        Radius around(Radius corner) => corner == Radius.zero
            ? Radius.zero
            : Radius.elliptical(corner.x + grow, corner.y + grow);
        final r = ownRadius.resolve(textDirection);
        secondaryBorder = ring.copyWith(
          borderRadius: BorderRadius.only(
            topLeft: around(r.topLeft),
            topRight: around(r.topRight),
            bottomLeft: around(r.bottomLeft),
            bottomRight: around(r.bottomRight),
          ),
        );
      }
    }

    // The shadows go on the wrapper rather than the decoration itself so they
    // are clipped to the control's own outline; see [ShadowDecoration].
    final primaryDecoration = ShadowDecoration(
      shadows: effectiveDecoration.shadows ?? const [],
      decoration: switch (border) {
        final UnaRoundedSuperellipseBorder border => ShapeDecoration(
          color: effectiveDecoration.color,
          image: effectiveDecoration.image,
          gradient: effectiveDecoration.gradient,
          shape: border.toBorder(
            textDirection: textDirection,
            defaultBorderRadius: theme.radius,
          ),
        ),
        final UnaBorder? border => BoxDecoration(
          border: true == border?.hasBorder ? border?.toBorder() : null,
          borderRadius: effectiveDecoration.shape == BoxShape.circle
              ? null
              : border?.borderRadius,
          color: effectiveDecoration.color,
          shape: effectiveDecoration.shape ?? BoxShape.rectangle,
          backgroundBlendMode: effectiveDecoration.backgroundBlendMode,
          gradient: effectiveDecoration.gradient,
          image: effectiveDecoration.image,
        ),
      },
    );

    Widget decorated = Container(
      decoration: primaryDecoration,
      padding: border?.padding,
      child: child,
    );

    if (secondaryBorder != null && !effectiveDisableSecondaryBorder) {
      decorated = Padding(
        padding: secondaryBorder.padding ?? EdgeInsets.zero,
        child: CustomPaint(
          foregroundPainter: OutwardBorderPainter(
            border: secondaryBorder.toBorder(),
            offset: secondaryBorder.offset ?? 0,
            radius:
                secondaryBorder.borderRadius?.resolve(textDirection) ??
                BorderRadius.zero,
            textDirection: textDirection,
          ),
          child: decorated,
        ),
      );
    }

    return decorated;
  }
}

/// {@template outwardBorderPainter}
/// A [CustomPainter] that paints a border outward from the given rectangle.
/// {@endtemplate}
class OutwardBorderPainter extends CustomPainter {
  /// {@macro outwardBorderPainter}
  const OutwardBorderPainter({
    required this.border,
    required this.offset,
    required this.radius,
    required this.textDirection,
  });

  /// The border to paint.
  final Border border;

  /// The offset to inflate the border by.
  final double offset;

  /// The radius of the border.
  final BorderRadius? radius;

  /// The text direction to use when painting the border.
  final TextDirection? textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    border.paint(
      canvas,
      (Offset.zero & size).inflate(offset),
      borderRadius: radius,
      textDirection: textDirection,
    );
  }

  @override
  bool shouldRepaint(covariant OutwardBorderPainter oldDelegate) {
    return border != oldDelegate.border ||
        offset != oldDelegate.offset ||
        radius != oldDelegate.radius ||
        textDirection != oldDelegate.textDirection;
  }
}

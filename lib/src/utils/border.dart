import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Converts a [UnaBorderSide] to a Flutter [BorderSide].
extension BorderSideToBorderSide on UnaBorderSide {
  /// Returns the Flutter [BorderSide] for this side.
  ///
  /// A side with no width becomes a zero-width side that keeps its color,
  /// instead of [BorderSide.none]. A null color becomes transparent.
  /// Otherwise the width defaults to 1, the style to [BorderStyle.solid] and
  /// the stroke alignment to [BorderSide.strokeAlignInside].
  BorderSide toBorderSide() {
    if (width == null || width == 0) {
      // Deliberately not `BorderSide.none`: that carries an opaque black, and
      // `Border` asserts that every side shares a colour before it will paint
      // a radius. A component that draws only some of its sides — the OTP
      // strip shares its vertical edges — would crash on that assertion.
      return BorderSide(
        color: color ?? const Color(0x00000000),
        width: 0,
        style: BorderStyle.none,
      );
    }
    return BorderSide(
      color: color ?? const Color(0x00000000),
      width: width ?? 1,
      style: style ?? BorderStyle.solid,
      strokeAlign: strokeAlign ?? BorderSide.strokeAlignInside,
    );
  }
}

/// Converts a [UnaBorder] to a Flutter [Border].
extension BorderToBorder on UnaBorder {
  /// Returns a [UnaBoxBorder] with the four sides of this border.
  ///
  /// Missing sides become [BorderSide.none]. The radius, padding and offset are
  /// not part of the result.
  Border toBorder() {
    return UnaBoxBorder(
      top: top?.toBorderSide() ?? BorderSide.none,
      right: right?.toBorderSide() ?? BorderSide.none,
      bottom: bottom?.toBorderSide() ?? BorderSide.none,
      left: left?.toBorderSide() ?? BorderSide.none,
    );
  }
}

/// A [Border] that tolerates differently coloured sides inside a radius.
///
/// [Border.paint] throws when given a border radius while the visible sides
/// show more than one colour. Theme animation makes that state routine:
/// lerping a boxed field towards an underlined or borderless style fades
/// three sides out while the bottom crosses to another colour, so mid-flight
/// the sides legitimately disagree. This subclass paints that case as mitred
/// straight sides clipped to the rounded outline — at field hairline widths
/// the corners are indistinguishable from the real thing, and the state only
/// lasts for the frames of the transition.
class UnaBoxBorder extends Border {
  /// Creates a border with the given sides.
  const UnaBoxBorder({super.top, super.right, super.bottom, super.left});

  /// Mirrors the cases [Border.paint] can draw inside a radius itself: a
  /// fully uniform border, a uniformly invisible one, or sides that show a
  /// single colour with no hairlines. Everything else asserts there.
  bool get _radiusSafeForSuper {
    if (isUniform) return true;
    final topStyle = top.style;
    final stylesUniform =
        left.style == topStyle &&
        bottom.style == topStyle &&
        right.style == topStyle;
    if (stylesUniform && topStyle == BorderStyle.none) return true;
    final visibleColors = <Color>{
      for (final side in [top, right, bottom, left])
        if (side.style != BorderStyle.none) side.color,
    };
    final hasHairline = [
      top,
      right,
      bottom,
      left,
    ].any((side) => side.style == BorderStyle.solid && side.width == 0);
    return visibleColors.length == 1 && !hasHairline;
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    if (shape == BoxShape.rectangle &&
        borderRadius != null &&
        borderRadius != BorderRadius.zero &&
        !_radiusSafeForSuper) {
      canvas
        ..save()
        ..clipRRect(borderRadius.toRRect(rect));
      paintBorder(
        canvas,
        rect,
        top: top,
        right: right,
        bottom: bottom,
        left: left,
      );
      canvas.restore();
      return;
    }
    super.paint(
      canvas,
      rect,
      textDirection: textDirection,
      shape: shape,
      borderRadius: borderRadius,
    );
  }
}

/// {@template UnaBorder}
/// A wrapper around the [Border] class with a reasonable merge.
/// {@endtemplate}
@immutable
class UnaBorder {
  /// {@macro UnaBorder}
  const UnaBorder({
    this.canMerge = true,
    this.padding,
    this.borderRadius,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.offset,
  });

  /// Creates a border whose sides are all the same.
  const UnaBorder.fromBorderSide(
    UnaBorderSide side, {
    this.canMerge = true,
    this.padding,
    this.borderRadius,
    this.offset,
  }) : top = side,
       right = side,
       bottom = side,
       left = side;

  /// Creates a border with symmetrical vertical and horizontal sides.
  ///
  /// The `vertical` argument applies to the [left] and [right] sides, and the
  /// `horizontal` argument applies to the [top] and [bottom] sides.
  const UnaBorder.symmetric({
    UnaBorderSide? vertical,
    UnaBorderSide? horizontal,
    this.canMerge = true,
    this.padding,
    this.borderRadius,
    this.offset,
  }) : left = vertical,
       top = horizontal,
       right = vertical,
       bottom = horizontal;

  /// A uniform border with all sides the same color and width.
  ///
  /// The sides default to black solid borders, one logical pixel wide.
  factory UnaBorder.all({
    bool canMerge = true,
    Color? color,
    double? width,
    BorderStyle? style,
    double? strokeAlign,
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry? borderRadius,
    double? offset,
  }) {
    final side = UnaBorderSide(
      color: color,
      width: width,
      style: style,
      strokeAlign: strokeAlign,
    );
    return UnaBorder.fromBorderSide(
      side,
      padding: padding,
      canMerge: canMerge,
      borderRadius: borderRadius,
      offset: offset,
    );
  }

  /// Interpolates between two borders.
  ///
  /// The [canMerge] value comes from [b] when it is not null.
  static UnaBorder? lerp(UnaBorder? a, UnaBorder? b, double t) {
    if (identical(a, b)) return a;
    return UnaBorder(
      canMerge: b?.canMerge ?? a?.canMerge ?? true,
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
      borderRadius: BorderRadiusGeometry.lerp(
        a?.borderRadius,
        b?.borderRadius,
        t,
      ),
      top: UnaBorderSide.lerp(
        a?.top,
        b?.top,
        t,
      ),
      right: UnaBorderSide.lerp(
        a?.right,
        b?.right,
        t,
      ),
      bottom: UnaBorderSide.lerp(
        a?.bottom,
        b?.bottom,
        t,
      ),
      left: UnaBorderSide.lerp(
        a?.left,
        b?.left,
        t,
      ),
      offset: lerpDouble(a?.offset, b?.offset, t),
    );
  }

  /// Whether any side has a width other than zero.
  bool get hasBorder =>
      (top?.width ?? 0) != 0 ||
      (right?.width ?? 0) != 0 ||
      (bottom?.width ?? 0) != 0 ||
      (left?.width ?? 0) != 0;

  /// A border with no sides that replaces any border it is merged into.
  static const UnaBorder none = UnaBorder(canMerge: false);

  /// Creates a [UnaBorder] that represents the addition of the two given
  /// [UnaBorder]s.
  UnaBorder merge(UnaBorder? other) {
    if (other == null) return this;
    if (!other.canMerge) return other;
    if (other is UnaRoundedSuperellipseBorder) {
      return UnaRoundedSuperellipseBorder(
        side: switch (this) {
          final UnaRoundedSuperellipseBorder border =>
            border.side?.merge(other.side) ?? other.side,
          _ => other.side,
        },
        borderRadius: other.borderRadius ?? borderRadius,
        // Null-aware, like the rest of a merge: an override that sets only
        // the radius keeps the offset, or a focus ring collapses onto the
        // element's own border.
        padding: other.padding ?? padding,
        offset: other.offset ?? offset,
      );
    }
    if (this case final UnaRoundedSuperellipseBorder border) {
      // A plain override keeps the superellipse shape. It has one side for
      // every edge, so the override's sides apply only when they agree.
      final uniform =
          other.top == other.right &&
          other.top == other.bottom &&
          other.top == other.left;
      final otherSide = uniform ? other.top : null;
      return UnaRoundedSuperellipseBorder(
        side: border.side?.merge(otherSide) ?? otherSide,
        borderRadius: other.borderRadius ?? borderRadius,
        padding: other.padding ?? padding,
        offset: other.offset ?? offset,
      );
    }
    return copyWith(
      // The merged result is always mergeable again: [other] opted into the
      // merge (checked above), so the combination stays open to further
      // overrides regardless of this border's own [canMerge].
      canMerge: true,
      top: top?.merge(other.top) ?? other.top,
      right: right?.merge(other.right) ?? other.right,
      bottom: bottom?.merge(other.bottom) ?? other.bottom,
      left: left?.merge(other.left) ?? other.left,
      padding: other.padding,
      borderRadius: other.borderRadius,
      offset: other.offset,
    );
  }

  /// Returns a copy with the given fields replaced.
  UnaBorder copyWith({
    bool? canMerge,
    EdgeInsetsGeometry? padding,
    UnaBorderSide? top,
    UnaBorderSide? right,
    UnaBorderSide? bottom,
    UnaBorderSide? left,
    BorderRadiusGeometry? borderRadius,
    double? offset,
  }) {
    return UnaBorder(
      canMerge: canMerge ?? this.canMerge,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      left: left ?? this.left,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      offset: offset ?? this.offset,
    );
  }

  /// Whether to merge with another border, defaults to true.
  final bool canMerge;

  /// The padding of the border, defaults to null.
  final EdgeInsetsGeometry? padding;

  /// The border radius of the border, defaults to null.
  final BorderRadiusGeometry? borderRadius;

  /// The top side of this border.
  final UnaBorderSide? top;

  /// The right side of this border.
  final UnaBorderSide? right;

  /// The bottom side of this border.
  final UnaBorderSide? bottom;

  /// The left side of this border.
  final UnaBorderSide? left;

  /// The offset between the border and the widget.
  ///
  /// NOTE: This is supported only by the secondaryBorder, because the border is
  /// drawn outward of the widget.
  final double? offset;

  @override
  String toString() {
    return '''UnaBorder(canMerge: $canMerge, padding: $padding, borderRadius: $borderRadius, top: $top, right: $right, bottom: $bottom, left: $left, offset: $offset)''';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Guards against a base [UnaBorder] comparing equal to a subclass
    // instance, keeping `==` symmetric with [UnaRoundedSuperellipseBorder].
    if (other.runtimeType != runtimeType) return false;
    return other is UnaBorder &&
        other.canMerge == canMerge &&
        other.padding == padding &&
        other.borderRadius == borderRadius &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
        other.left == left &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(
    canMerge,
    padding,
    borderRadius,
    top,
    right,
    bottom,
    left,
    offset,
  );
}

/// Creates the side of a border.
@immutable
class UnaBorderSide with Diagnosticable {
  /// Creates the side of a border.
  const UnaBorderSide({
    this.canMerge = true,
    this.color,
    this.width,
    this.style,
    this.strokeAlign,
  }) : assert(width == null || width >= 0.0);

  /// Merges two border sides into one
  UnaBorderSide merge(UnaBorderSide? other) {
    if (other == null) return this;
    if (!other.canMerge) return other;
    return copyWith(
      color: other.color,
      width: other.width,
      style: other.style,
      strokeAlign: other.strokeAlign,
    );
  }

  /// Whether to merge the border side
  final bool canMerge;

  /// The color of this side of the border.
  final Color? color;

  /// The width of this side of the border, in logical pixels.
  ///
  /// Setting width to 0.0 will result in a hairline border. This means that
  /// the border will have the width of one physical pixel. Hairline
  /// rendering takes shortcuts when the path overlaps a pixel more than once.
  /// This means that it will render faster than otherwise, but it might
  /// double-hit pixels, giving it a slightly darker/lighter result.
  final double? width;

  /// The style of this side of the border.
  final BorderStyle? style;

  /// A hairline black border that is not rendered.
  static const UnaBorderSide none = UnaBorderSide(canMerge: false);

  /// The relative position of the stroke on a [UnaBorderSide] in an
  /// [OutlinedBorder] or [Border].
  ///
  /// Values typically range from -1.0 ([BorderSide.strokeAlignInside], inside
  /// border, default) to 1.0 ([BorderSide.strokeAlignOutside], outside border),
  /// without any bound constraints (e.g., a value of -2.0 is not typical, but
  /// allowed).
  /// A value of 0 ([BorderSide.strokeAlignCenter]) will center the border on
  /// the edge of the widget.
  ///
  /// When set to [BorderSide.strokeAlignInside], the stroke is drawn completely
  /// inside
  /// the widget. For [BorderSide.strokeAlignCenter] and
  /// [BorderSide.strokeAlignOutside], a property
  /// such as [Container.clipBehavior] can be used in an outside widget to clip
  /// it. If [Container.decoration] has a border, the container may incorporate
  /// [width] as additional padding:
  /// - [BorderSide.strokeAlignInside] provides padding with full [width].
  /// - [BorderSide.strokeAlignCenter] provides padding with half [width].
  /// - [BorderSide.strokeAlignOutside] provides zero padding, as stroke is
  /// drawn entirely outside.
  ///
  /// This property is not honored by toPaint (because the [Paint] object
  /// cannot represent it); it is intended that classes that use
  /// [UnaBorderSide] objects implement this property when painting borders
  /// by suitably inflating or deflating their regions.
  final double? strokeAlign;

  /// Creates a copy of this border but with the given fields replaced with the
  /// new values.
  UnaBorderSide copyWith({
    bool? canMerge,
    Color? color,
    double? width,
    BorderStyle? style,
    double? strokeAlign,
  }) {
    return UnaBorderSide(
      canMerge: canMerge ?? this.canMerge,
      color: color ?? this.color,
      width: width ?? this.width,
      style: style ?? this.style,
      strokeAlign: strokeAlign ?? this.strokeAlign,
    );
  }

  /// Interpolates between two border sides.
  ///
  /// The style switches from [a] to [b] at the midpoint.
  static UnaBorderSide? lerp(
    UnaBorderSide? a,
    UnaBorderSide? b,
    double t,
  ) {
    if (identical(a, b)) return a;
    return UnaBorderSide(
      canMerge: b?.canMerge ?? a?.canMerge ?? true,
      color: Color.lerp(a?.color, b?.color, t),
      width: lerpDouble(a?.width, b?.width, t),
      style: t < 0.5 ? a?.style : b?.style,
      strokeAlign: lerpDouble(a?.strokeAlign, b?.strokeAlign, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is UnaBorderSide &&
        other.canMerge == canMerge &&
        other.color == color &&
        other.width == width &&
        other.style == style &&
        other.strokeAlign == strokeAlign;
  }

  @override
  int get hashCode => Object.hash(canMerge, color, width, style, strokeAlign);

  @override
  String toStringShort() => 'UnaBorderSide';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsProperty<Color>(
          'color',
          color,
          defaultValue: const Color(0xFF000000),
        ),
      )
      ..add(
        DiagnosticsProperty<bool>(
          'canMerge',
          canMerge,
          defaultValue: true,
        ),
      );

    // ignore: cascade_invocations
    properties
      ..add(DoubleProperty('width', width, defaultValue: 1.0))
      ..add(
        DoubleProperty(
          'strokeAlign',
          strokeAlign,
          defaultValue: BorderSide.strokeAlignInside,
        ),
      )
      ..add(
        EnumProperty<BorderStyle>(
          'style',
          style,
          defaultValue: BorderStyle.solid,
        ),
      );
  }
}

/// Converts a [UnaRoundedSuperellipseBorder] to a Flutter [ShapeBorder].
extension RoundedSuperellipseBorderExt on UnaRoundedSuperellipseBorder {
  /// Returns a [RoundedSuperellipseBorder] with the side and radius of this
  /// border.
  ///
  /// [textDirection] resolves a directional radius and defaults to
  /// [TextDirection.ltr]. [defaultBorderRadius] is used when [borderRadius]
  /// is null.
  ShapeBorder toBorder({
    TextDirection? textDirection,
    BorderRadius defaultBorderRadius = BorderRadius.zero,
  }) {
    final effectiveTextDirection = textDirection ?? TextDirection.ltr;
    return _ShaderSafeSuperellipseBorder(
      side: side?.toBorderSide() ?? BorderSide.none,
      borderRadius:
          borderRadius?.resolve(effectiveTextDirection) ?? defaultBorderRadius,
    );
  }
}

/// A [RoundedSuperellipseBorder] whose gradient or image fill stays put on
/// the web.
///
/// Flutter fills the shape with `drawRSuperellipse`, which on the web
/// (CanvasKit and skwasm) moves the canvas to the shape's centre and draws
/// a centred path: a shader moves with it, so a gradient showed only the
/// half of itself that landed on the shape. A fill with a shader is drawn
/// as a rectangle clipped to the shape instead; a clip is geometry only.
class _ShaderSafeSuperellipseBorder extends RoundedSuperellipseBorder {
  const _ShaderSafeSuperellipseBorder({super.side, super.borderRadius});

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    if (!kIsWeb || paint.shader == null) {
      super.paintInterior(canvas, rect, paint, textDirection: textDirection);
      return;
    }
    canvas
      ..save()
      ..clipRSuperellipse(
        borderRadius.resolve(textDirection).toRSuperellipse(rect),
      )
      ..drawRect(rect, paint)
      ..restore();
  }
}

/// A rectangular border with rounded corners following the shape of an
/// [RSuperellipse].
@immutable
class UnaRoundedSuperellipseBorder extends UnaBorder {
  /// Creates a superellipse border with [side] on every edge.
  const UnaRoundedSuperellipseBorder({
    super.canMerge,
    this.side,
    super.borderRadius,
    super.padding,
    super.offset,
  });

  /// The side drawn on every edge.
  final UnaBorderSide? side;

  @override
  String toString() {
    return '''UnaRoundedSuperellipseBorder(canMerge: $canMerge, side: $side, borderRadius: $borderRadius, padding: $padding, offset: $offset)''';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is UnaRoundedSuperellipseBorder &&
        other.canMerge == canMerge &&
        other.side == side &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.offset == offset;
  }

  @override
  int get hashCode =>
      Object.hash(canMerge, side, borderRadius, padding, offset);
}

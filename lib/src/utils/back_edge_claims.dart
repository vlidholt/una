import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The pages under a scaffold that take its start edge for their back
/// swipe: a page pushed in a navigator inside the scaffold's body — a
/// destination's own stack under a shell — asks for the edge while it is
/// current and can go back, and the scaffold's drawer stops listening
/// there. Asked at hit-test time, so nothing is rebuilt when a page comes
/// or goes.
class BackEdgeClaims {
  final _claims = <bool Function()>{};

  /// Adds a claim, asked whenever a pointer comes down on the edge.
  void add(bool Function() claim) => _claims.add(claim);

  /// Removes a claim.
  void remove(bool Function() claim) => _claims.remove(claim);

  /// Whether a page wants the edge now.
  bool get claimed => _claims.any((claim) => claim());
}

/// Makes [claims] the ones the pages below report to.
class BackEdgeScope extends InheritedWidget {
  /// Publishes [claims] to [child].
  const BackEdgeScope({required this.claims, required super.child, super.key});

  /// The claims of the scaffold around [child].
  final BackEdgeClaims claims;

  /// The claims of the nearest scaffold around [context], if any. Not a
  /// dependency: the claims object of a scaffold never changes.
  static BackEdgeClaims? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BackEdgeScope>()?.claims;

  @override
  bool updateShouldNotify(BackEdgeScope oldWidget) =>
      !identical(claims, oldWidget.claims);
}

/// [child], which takes no pointers while [claims] are claimed.
class UnlessEdgeClaimed extends SingleChildRenderObjectWidget {
  /// Hides [child] from pointers while a page claims the edge.
  const UnlessEdgeClaimed({required this.claims, super.child, super.key});

  /// The claims asked at each hit test.
  final BackEdgeClaims claims;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderUnlessClaimed(claims);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderUnlessClaimed).claims = claims;
  }
}

class _RenderUnlessClaimed extends RenderProxyBox {
  _RenderUnlessClaimed(this.claims);

  BackEdgeClaims claims;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !claims.claimed && super.hitTest(result, position: position);
}

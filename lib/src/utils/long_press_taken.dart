import 'package:flutter/widgets.dart';

/// Marks a subtree where a held finger already does something — lifts a
/// board card or a reorderable row — so that what is inside does not
/// answer the same long press with something else.
///
/// A `ContextMenuRegion` inside opens on neither a touch's tap nor its long
/// press by default — a tap's down comes first in a long press, and a card
/// that rose to be dragged opened its menu as well. It still opens on a
/// secondary tap and from the menu key; give the item a button for its
/// menu on a touch screen.
class LongPressTaken extends InheritedWidget {
  /// Marks [child] as having its long press [taken] or not.
  const LongPressTaken({required this.taken, required super.child, super.key});

  /// Whether a long press in [child] is taken.
  final bool taken;

  /// Whether a long press at [context] is already taken.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LongPressTaken>()?.taken ??
      false;

  @override
  bool updateShouldNotify(LongPressTaken oldWidget) => taken != oldWidget.taken;
}

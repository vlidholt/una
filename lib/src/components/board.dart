import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/i18n/localizations_delegate.dart';
import 'package:una/src/icons/phosphor_icons.dart';
import 'package:una/src/raw_components/pressable.dart';
import 'package:una/src/theme/components/board.dart';
import 'package:una/src/theme/data.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/debug_check.dart';
import 'package:una/src/utils/haptics.dart';
import 'package:una/src/utils/long_press_taken.dart';
import 'package:una/src/utils/shadow.dart';

part 'board_column.dart';
part 'board_motion.dart';
part 'board_state.dart';
part 'reorderable_list_view.dart';

/// Builds one item of a [Board].
///
/// It is called for the item in its column and, while the item is being
/// dragged, a second time for the lifted copy that follows the pointer; see
/// [BoardItemDetails.dragging].
typedef BoardItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  BoardItemDetails<T> details,
);

/// What starts a drag in a [Board].
enum BoardDragTrigger {
  /// The whole item: a mouse drags it straight away, a finger after a long
  /// press, so the column still scrolls.
  item,

  /// Only a [BoardDragHandle] inside the item, which drags at once for a
  /// finger too.
  handle,
}

/// One column of a [Board]: a header, a list of items and an optional
/// footer.
///
/// ```dart
/// BoardColumn(
///   id: 'doing',
///   label: 'In progress',
///   items: doing,
///   limit: 3,
///   footer: Button.ghost(onPressed: add, child: const Text('Add a card')),
/// )
/// ```
@immutable
class BoardColumn<T> {
  /// Creates a column.
  const BoardColumn({
    required this.id,
    required this.label,
    required this.items,
    this.title,
    this.leading,
    this.trailing,
    this.footer,
    this.empty,
    this.limit,
    this.canAccept,
    this.showCount = true,
  }) : assert(limit == null || limit >= 0, 'limit must not be negative');

  /// What identifies the column: [BoardMove.fromColumn] and
  /// [BoardMove.toColumn] are column ids. Compared with `==`, and unique in
  /// a board.
  final Object id;

  /// The column's name. It is the header's title unless [title] is given,
  /// and what assistive technology calls the column: "Move to In progress".
  final String label;

  /// The items, top to bottom.
  final List<T> items;

  /// The header's title, in place of [label].
  final Widget? title;

  /// A widget before the title: a status dot, an icon.
  final Widget? leading;

  /// A widget at the end of the header: a menu button, an add button.
  final Widget? trailing;

  /// A widget pinned under the items: an "Add a card" row.
  final Widget? footer;

  /// What the column shows while it has no items, in place of the dashed
  /// drop target.
  final Widget? empty;

  /// The most items the column takes. A full column refuses an item dragged
  /// in from another column, and its count shows `2/2` in the destructive
  /// colour. Null is no limit.
  final int? limit;

  /// Whether the column takes an item from another column. Null accepts
  /// everything [limit] allows.
  final bool Function(T item)? canAccept;

  /// Whether the header shows how many items the column holds.
  final bool showCount;

  /// Whether the column has reached its [limit].
  bool get isFull => limit != null && items.length >= limit!;
}

/// A move a [Board] asks for: [item] leaves [fromColumn] and goes into
/// [toColumn].
///
/// [toIndex] is where the item is inserted *after* it has been removed from
/// [fromColumn], so applying a move is always remove, then insert:
///
/// ```dart
/// void onMove(BoardMove<Task> move) => setState(() {
///   move.apply(lists[move.fromColumn]!, lists[move.toColumn]!);
/// });
/// ```
@immutable
class BoardMove<T> {
  /// Creates a move.
  const BoardMove({
    required this.item,
    required this.fromColumn,
    required this.fromIndex,
    required this.toColumn,
    required this.toIndex,
  });

  /// The item that moves.
  final T item;

  /// The id of the column the item leaves.
  final Object fromColumn;

  /// The item's index in [fromColumn].
  final int fromIndex;

  /// The id of the column the item goes into.
  final Object toColumn;

  /// The index the item takes in [toColumn], counted once the item has
  /// been removed from [fromColumn].
  final int toIndex;

  /// Whether the item stays in its column.
  bool get isReorder => fromColumn == toColumn;

  /// Carries the move out on the two lists: removes the item from [from]
  /// and inserts it into [to]. Pass the same list twice for a reorder.
  void apply(List<T> from, List<T> to) {
    final moved = from.removeAt(fromIndex);
    to.insert(math.min(toIndex, to.length), moved);
  }

  @override
  bool operator ==(Object other) =>
      other is BoardMove<T> &&
      other.item == item &&
      other.fromColumn == fromColumn &&
      other.fromIndex == fromIndex &&
      other.toColumn == toColumn &&
      other.toIndex == toIndex;

  @override
  int get hashCode =>
      Object.hash(item, fromColumn, fromIndex, toColumn, toIndex);

  @override
  String toString() =>
      'BoardMove($item: $fromColumn[$fromIndex] → $toColumn[$toIndex])';
}

/// Where an item is when a [BoardItemBuilder] builds it.
@immutable
class BoardItemDetails<T> {
  /// Creates the details of one build.
  const BoardItemDetails({
    required this.column,
    required this.index,
    this.dragging = false,
  });

  /// The column the item is in.
  final BoardColumn<T> column;

  /// The item's index in [column].
  final int index;

  /// Whether this is the lifted copy that follows the pointer. The board
  /// already scales it, tilts it and gives it a shadow; use this for
  /// anything more.
  final bool dragging;
}

/// Moves items and scrolls a [Board] from code.
///
/// ```dart
/// final board = BoardController<Task>();
///
/// // The same checks, callbacks and animation as a drag:
/// board.move(task, toColumn: 'done');
/// ```
///
/// It notifies its listeners when a drag starts and when it ends.
class BoardController<T extends Object> extends ChangeNotifier {
  _BoardState<T>? _state;

  /// Whether an item is being dragged, by a pointer or from the keyboard.
  bool get isDragging => _state?._drag != null;

  /// Moves [item] to [toColumn], at [toIndex] or at the end, as if it had
  /// been dragged there: the column's rules apply, `Board.onMove` is called
  /// and the item flies to its new place.
  ///
  /// [toIndex] counts as [BoardMove.toIndex] does. Returns whether the move
  /// was asked for — false when the column refused it, when the item is not
  /// on the board or when it is already there.
  bool move(T item, {required Object toColumn, int? toIndex}) {
    final state = _state;
    if (state == null) return false;
    return state._moveDirect(
      state._idOf(item),
      toColumn,
      toIndex,
      announce: false,
    );
  }

  /// Drops the drag in progress back where it came from.
  void cancelDrag() => _state?._cancelDrag();

  /// Scrolls the board until the column with [columnId] is in view.
  Future<void> showColumn(Object columnId) async {
    await _state?._showColumn(columnId);
  }

  void _detach(_BoardState<T> state) {
    if (_state == state) _state = null;
  }

  void _dragChanged() => notifyListeners();
}

/// A board of columns whose items are dragged to reorder them and to move
/// them between columns, like a kanban or Trello board.
///
/// The board does not own the items. It reports each move through [onMove]
/// and the parent updates its lists, as with a `TextField` and its
/// controller:
///
/// ```dart
/// Board<Task>(
///   columns: [
///     BoardColumn(id: 'todo', label: 'To do', items: todo),
///     BoardColumn(id: 'doing', label: 'In progress', items: doing, limit: 3),
///     BoardColumn(id: 'done', label: 'Done', items: done),
///   ],
///   itemBuilder: (context, task, details) => Card(child: Text(task.title)),
///   onMove: (move) => setState(() {
///     move.apply(lists[move.fromColumn]!, lists[move.toColumn]!);
///   }),
/// )
/// ```
///
/// A mouse drags an item as soon as it moves; a finger picks one up with a
/// long press, so the columns still scroll. The other items make way, the
/// board and the column under the pointer scroll when it nears an edge, and
/// on release the item flies to its slot. From the keyboard, focus an item,
/// press Space to pick it up, move it with the arrow keys and press Space
/// again to drop it, or Escape to put it back. Assistive technology gets
/// "Move up", "Move down" and "Move to *column*" actions on every item.
///
/// ## Size
///
/// A board needs a bounded width. It normally needs a bounded height too,
/// which its columns fill, each scrolling its own items and building only
/// the ones in view. Inside a vertically scrolling page — where the height
/// is unbounded — pass [shrinkWrap]: the columns are then as tall as their
/// items and the page scrolls instead.
///
/// ## Items
///
/// Items are told apart by [itemId], or by `==` without one, so an item
/// keeps its state — and the keyboard focus, if it has it — when it moves,
/// to another place in its column or to another column. (A column that
/// scrolls builds only the items in view: an item sent somewhere that is
/// not built starts afresh when it is scrolled to.) Columns are told apart
/// by `BoardColumn.id` in the same way, so removing, adding or reordering
/// columns leaves the others, and how far each is scrolled, as they were.
///
/// A `Card` returned by [itemBuilder] takes the board's own, tighter
/// metrics (`BoardTheme.itemPadding`, `itemBorderRadius`) and an opaque fill.
///
/// The lifted copy is built by the same builder, as an overlay child of
/// the board: it inherits everything the board inherits, and it is painted
/// in the nearest `Overlay` right above the page the board is on — over
/// the rest of that page, under a dialog or a page opened on top of it. It
/// is a picture of the item: it takes no pointer, no focus and no part in
/// the semantics tree, and it is a second instance, with a state of its
/// own that lasts as long as the item is in the air.
///
/// ## When the rules are asked
///
/// [BoardColumn.limit], [BoardColumn.canAccept] and [canMove] are asked
/// when the item comes over a new place, again whenever the board is
/// rebuilt while it is held, and once more as it is dropped — not for
/// every movement of the pointer. A drop the rules no longer allow is not
/// reported: the item goes back.
///
/// ## Off stage
///
/// A board that cannot be seen sets nothing in motion. When a page covers
/// its route, when it is in the hidden child of an `IndexedStack` or a
/// `Visibility`, when a `TickerMode` above it is switched off or when the
/// app goes to the background, a held item is put back (with
/// [onDragEnd], and without [onMove]) and an item still flying to its
/// slot is simply there.
///
/// See also:
///
///  * [BoardColumn], one column.
///  * [BoardController], which moves items from code.
///  * [BoardDragHandle], a grip inside an item.
class Board<T extends Object> extends StatefulWidget {
  /// Creates a board.
  const Board({
    required this.columns,
    required this.itemBuilder,
    required this.onMove,
    this.itemId,
    this.controller,
    this.canMove,
    this.onDragStart,
    this.onDragEnd,
    this.itemSemanticLabel,
    this.dragTrigger = BoardDragTrigger.item,
    this.longPressDelay = kLongPressTimeout,
    this.enabled = true,
    this.shrinkWrap = false,
    this.expandColumns = true,
    this.columnWidth,
    this.columnGap,
    this.itemGap,
    this.padding,
    this.scrollController,
    this.snap,
    super.key,
  });

  /// The columns, in reading order.
  final List<BoardColumn<T>> columns;

  /// Builds an item.
  final BoardItemBuilder<T> itemBuilder;

  /// Called when an item has been dropped somewhere new, or moved from the
  /// keyboard, by assistive technology or by a [BoardController].
  ///
  /// Update the lists the [columns] are built from. Until then the item
  /// stays where it was, and it flies to wherever the next build puts it —
  /// so a parent that sorts a column, or that turns the move down, is
  /// animated correctly too.
  final ValueChanged<BoardMove<T>> onMove;

  /// What identifies an item across builds and columns. Defaults to the
  /// item itself, compared with `==`. Ids are unique in a board.
  final Object Function(T item)? itemId;

  /// Moves items and scrolls the board from code.
  final BoardController<T>? controller;

  /// Whether a move is allowed, on top of each column's own
  /// [BoardColumn.limit] and [BoardColumn.canAccept]. A refused move shows
  /// on the column while the item is over it and springs back on release.
  final bool Function(BoardMove<T> move)? canMove;

  /// Called when an item is picked up.
  final ValueChanged<T>? onDragStart;

  /// Called when a picked-up item has been let go, whether or not it moved.
  final ValueChanged<T>? onDragEnd;

  /// What assistive technology calls an item, when its content does not say
  /// it well enough.
  final String Function(T item)? itemSemanticLabel;

  /// What starts a drag: the whole item, or only a [BoardDragHandle].
  final BoardDragTrigger dragTrigger;

  /// How long a finger rests on an item before it is picked up.
  final Duration longPressDelay;

  /// Whether items can be moved at all.
  final bool enabled;

  /// Whether the columns are as tall as their items instead of filling the
  /// board's height and scrolling. Every item is then built, so use it for
  /// a board inside a scrolling page, not for one with hundreds of items.
  final bool shrinkWrap;

  /// Whether the columns share the board's width when they all fit in it,
  /// between the theme's `columnMinWidth` and `columnMaxWidth`. Otherwise,
  /// and when they do not fit, each is [columnWidth] wide and the board
  /// scrolls.
  final bool expandColumns;

  /// The width of a column in a board that scrolls, in place of the
  /// theme's.
  final double? columnWidth;

  /// The gap between two columns, in place of the theme's.
  final double? columnGap;

  /// The gap between two items, in place of the theme's.
  final double? itemGap;

  /// The padding around the columns, inside the board's scroll view.
  final EdgeInsetsGeometry? padding;

  /// The controller of the board's horizontal scroll view.
  final ScrollController? scrollController;

  /// Whether the board comes to rest with a column at its leading edge.
  /// Defaults to the theme's: on for a phone, off for a desktop.
  final bool? snap;

  @override
  State<Board<T>> createState() => _BoardState<T>();
}

/// A grip that drags the [Board] item it is in.
///
/// With `Board.dragTrigger` set to [BoardDragTrigger.handle] it is the only
/// way to pick an item up with a pointer; otherwise it is a second one that
/// does not wait for a long press.
///
/// ```dart
/// Card(
///   leading: const BoardDragHandle(
///     child: PhosphorIcon(PhosphorIconsRegular.dotsSixVertical),
///   ),
///   child: Text(task.title),
/// )
/// ```
class BoardDragHandle extends StatelessWidget {
  /// Creates a drag handle around [child].
  const BoardDragHandle({required this.child, super.key});

  /// The grip: usually an icon.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_BoardItemScope>();
    // The lifted copy has no scope, and a disabled board drags nothing:
    // the grip is then only a picture. It is the same tree either way, so
    // whatever is inside keeps its state when the board is switched off
    // and on.
    final active = scope != null && scope.enabled;
    return MouseRegion(
      cursor: active ? SystemMouseCursors.grab : MouseCursor.defer,
      opaque: active,
      child: Listener(
        behavior: active
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        onPointerDown: active ? scope.startHandleDrag : null,
        child: Semantics(
          label: active ? UnaLocalizations.of(context).board.dragHandle : null,
          child: child,
        ),
      ),
    );
  }
}

/// Tells a [BoardDragHandle] which item it is in.
class _BoardItemScope extends InheritedWidget {
  const _BoardItemScope({
    required this.id,
    required this.enabled,
    required this.startHandleDrag,
    required super.child,
  });

  final Object id;
  final bool enabled;
  final void Function(PointerDownEvent event) startHandleDrag;

  @override
  bool updateShouldNotify(_BoardItemScope oldWidget) =>
      id != oldWidget.id || enabled != oldWidget.enabled;
}

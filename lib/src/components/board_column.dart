part of 'board.dart';

/// How a column looks while an item is dragged.
enum _ColumnMood { idle, target, refused }

/// The slot painted behind a column's items where a dragged item will land.
class _SlotModel extends ChangeNotifier {
  Rect? rect;
  double opacity = 0;

  void changed() => notifyListeners();
}

class _BoardColumnView<T extends Object> extends StatefulWidget {
  const _BoardColumnView({
    required this.board,
    required this.column,
    required this.index,
    required this.width,
    super.key,
  });

  final _BoardState<T> board;
  final BoardColumn<T> column;
  final int index;
  final double width;

  @override
  State<_BoardColumnView<T>> createState() => _BoardColumnState<T>();
}

class _BoardColumnState<T extends Object> extends State<_BoardColumnView<T>> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final Set<_BoardSlotState<T>> _mounted = {};
  final ValueNotifier<_ColumnMood> _mood = ValueNotifier(_ColumnMood.idle);
  final ValueNotifier<double> _trailing = ValueNotifier(0);
  final _SlotModel _slot = _SlotModel();

  _BoardState<T> get _board => widget.board;

  @override
  void initState() {
    super.initState();
    _board._columnStates[widget.column.id] = this;
    _scroll.addListener(_board._scrolled);
  }

  @override
  void didUpdateWidget(_BoardColumnView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.column.id != widget.column.id) {
      if (_board._columnStates[oldWidget.column.id] == this) {
        _board._columnStates.remove(oldWidget.column.id);
      }
      _board._columnStates[widget.column.id] = this;
    }
  }

  @override
  void dispose() {
    if (_board._columnStates[widget.column.id] == this) {
      _board._columnStates.remove(widget.column.id);
    }
    _scroll
      ..removeListener(_board._scrolled)
      ..dispose();
    _mood.dispose();
    _trailing.dispose();
    _slot.dispose();
    super.dispose();
  }

  /// The box the items are laid out in: the scroll view's viewport, or the
  /// plain column of a shrink-wrapped board.
  RenderBox? get _listBox {
    final box = _listKey.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  /// The column's whole surface, in global coordinates.
  Rect? get _rect {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The area the items show in, in global coordinates.
  Rect? get _listRect {
    final box = _listBox;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  ScrollPosition? get _position => _scroll.hasClients ? _scroll.position : null;

  /// Where the tops of this column's mounted slots are, in global
  /// coordinates.
  ///
  /// Each slot is measured in the list, a few render objects up, and the
  /// list once in the window: asking every slot for its own global position
  /// walks the whole tree for each, on every pointer event.
  double Function(_RenderBoardSlot box)? get _slotTops {
    final list = _listBox;
    if (list == null) return null;
    final toGlobal = list.getTransformTo(null);
    return (box) => MatrixUtils.transformPoint(
      toGlobal,
      box.localToGlobal(Offset.zero, ancestor: list),
    ).dy;
  }

  /// The index a dragged item whose centre is at [centerY] would take here:
  /// an index into this column's items without the dragged one.
  ///
  /// Each item is compared at the middle of the span it covers in its two
  /// possible places, above the slot and below it. That makes the answer a
  /// function of the pointer alone, not of where the items have got to in
  /// their animation, so a slot never flickers between two indices.
  int _indexAt(double centerY, _Drag<T> drag) {
    final source = _board._locations[drag.id];
    final own = source != null && source.column == widget.index;
    final list = _listRect;
    final topOf = _slotTops;
    if (list == null || topOf == null) return 0;
    final y = centerY.clamp(list.top, list.bottom);
    final gap = _board._style.itemGap;

    int? first;
    var above = 0;
    for (final slot in _mounted) {
      if (slot.widget.id == drag.id) continue;
      final box = slot._box;
      if (box == null) continue;
      final after = own && slot.widget.index > source.index;
      final reduced = after ? slot.widget.index - 1 : slot.widget.index;
      if (first == null || reduced < first) first = reduced;
      final top = topOf(box) - (after ? drag.extent : 0);
      final card = box.size.height - gap;
      if (top + (card + drag.extent) / 2 < y) above++;
    }
    return (first ?? 0) + above;
  }

  /// Where the slot for a dragged item is when it lands at [index], in
  /// global coordinates, or null when that place is out of view.
  Rect? _slotRect(int index, _Drag<T> drag) {
    final list = _listRect;
    final topOf = _slotTops;
    if (list == null || topOf == null) return null;
    final style = _board._style;
    final padding = style.columnPadding;
    final left = list.left + padding.left;
    final width = list.width - padding.horizontal;

    final source = _board._locations[drag.id];
    final own = source != null && source.column == widget.index;
    final count = widget.column.items.length - (own ? 1 : 0);
    if (count == 0) {
      return Rect.fromLTWH(
        left,
        list.top + padding.top,
        width,
        drag.size.height,
      );
    }
    for (final slot in _mounted) {
      if (slot.widget.id == drag.id) continue;
      final after = own && slot.widget.index > source.index;
      final reduced = after ? slot.widget.index - 1 : slot.widget.index;
      final last = reduced == index - 1 && index == count;
      if (reduced != index && !last) continue;
      final box = slot._box;
      if (box == null) continue;
      final top = topOf(box) - (after ? drag.extent : 0);
      return Rect.fromLTWH(
        left,
        last ? top + box.size.height : top,
        width,
        drag.size.height,
      );
    }
    return null;
  }

  void _setSlot(Rect? global, {required bool restart}) {
    final list = global == null ? null : _listRect;
    final local = global == null || list == null
        ? null
        : global.shift(-list.topLeft);
    if (local == _slot.rect) return;
    final appearing = _slot.rect == null || restart;
    _slot.rect = local;
    if (local == null || appearing) _slot.opacity = 0;
    _slot.changed();
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final style = board._style;
    final column = widget.column;
    final shrinkWrap = board.widget.shrinkWrap;
    final padding = style.columnPadding;
    // Every slot carries the gap under it, so the last one brings the
    // list's bottom padding with it.
    final listPadding = padding.copyWith(
      bottom: math.max(0, padding.bottom - style.itemGap),
    );

    Widget slotFor(int index) {
      final item = column.items[index];
      final id = board._idOf(item);
      return _BoardSlot<T>(
        key: ValueKey<Object>(id),
        board: board,
        columnState: this,
        column: column,
        index: index,
        item: item,
        id: id,
      );
    }

    final empty = column.items.isEmpty
        ? Padding(
            padding: EdgeInsets.only(bottom: style.itemGap),
            child: ValueListenableBuilder<_ColumnMood>(
              valueListenable: _mood,
              // While an item hovers over the column the slot takes the
              // hint's place.
              builder: (context, mood, child) => AnimatedOpacity(
                opacity: mood == _ColumnMood.target ? 0 : 1,
                duration: style.fade,
                curve: style.fadeCurve,
                child: child,
              ),
              child:
                  column.empty ??
                  CustomPaint(
                    painter: _DashedBorderPainter(
                      color: style.placeholderBorderColor,
                      radius: style.itemRadius,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: style.emptyHeight,
                    ),
                  ),
            ),
          )
        : null;

    // Room at the end for the slot of an item dragged in from another
    // column, which the items below it are pushed into.
    final trailing = ValueListenableBuilder<double>(
      valueListenable: _trailing,
      builder: (context, extent, _) => shrinkWrap
          ? TweenAnimationBuilder<double>(
              tween: Tween(end: extent),
              duration: style.reduced ? Duration.zero : style.fade,
              curve: style.fadeCurve,
              builder: (context, value, _) => SizedBox(height: value),
            )
          : SizedBox(height: extent),
    );

    final Widget list;
    if (shrinkWrap) {
      list = Padding(
        key: _listKey,
        padding: listPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?empty,
            for (var i = 0; i < column.items.length; i++) slotFor(i),
            trailing,
          ],
        ),
      );
    } else {
      list = CustomScrollView(
        key: _listKey,
        controller: _scroll,
        slivers: [
          SliverPadding(
            padding: listPadding,
            sliver: empty != null
                ? SliverToBoxAdapter(child: empty)
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => slotFor(index),
                      childCount: column.items.length,
                      // The slot paints through a boundary of its own,
                      // inside its translation.
                      addRepaintBoundaries: false,
                      findChildIndexCallback: (key) {
                        final location =
                            board._locations[(key as ValueKey<Object>).value];
                        return location != null &&
                                location.column == widget.index
                            ? location.index
                            : null;
                      },
                    ),
                  ),
          ),
          SliverToBoxAdapter(child: trailing),
        ],
      );
    }

    final body = Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SlotPainter(
                model: _slot,
                color: style.placeholderColor,
                borderColor: style.placeholderBorderColor,
                radius: style.itemRadius,
              ),
            ),
          ),
        ),
        list,
      ],
    );

    final surface = ValueListenableBuilder<_ColumnMood>(
      valueListenable: _mood,
      builder: (context, mood, child) {
        return AnimatedContainer(
          duration: style.fade,
          curve: style.fadeCurve,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: style.columnRadius,
            color: switch (mood) {
              _ColumnMood.idle => style.columnColor,
              _ColumnMood.target => style.targetColumnColor,
              _ColumnMood.refused => style.refusedColumnColor,
            },
          ),
          // In the foreground, so the outline costs the content no room
          // and changing its width moves nothing.
          foregroundDecoration: BoxDecoration(
            borderRadius: style.columnRadius,
            border: Border.all(
              color: switch (mood) {
                _ColumnMood.idle => style.columnBorderColor,
                _ColumnMood.target => style.targetColumnBorderColor,
                _ColumnMood.refused => style.refusedColumnBorderColor,
              },
              width: mood == _ColumnMood.idle ? 1 : 1.5,
            ),
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BoardColumnHeader<T>(column: column, style: style),
          if (shrinkWrap) body else Expanded(child: body),
          if (column.footer != null)
            Padding(padding: style.footerPadding, child: column.footer),
        ],
      ),
    );

    // A group of its own for assistive technology; its header names it.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SizedBox(width: widget.width, child: surface),
    );
  }
}

class _BoardColumnHeader<T> extends StatelessWidget {
  const _BoardColumnHeader({required this.column, required this.style});

  final BoardColumn<T> column;
  final _BoardStyle style;

  @override
  Widget build(BuildContext context) {
    final count = column.items.length;
    final full = column.isFull;
    final limit = column.limit;
    return Padding(
      padding: style.headerPadding,
      child: ConstrainedBox(
        // A header with a button at its end and one without line up.
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            if (column.leading != null) ...[
              column.leading!,
              const SizedBox(width: 8),
            ],
            // The title gives way to the count; the two together take what
            // the trailing widget leaves.
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: DefaultTextStyle.merge(
                      style: style.headerTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: Semantics(
                        header: true,
                        child: column.title ?? Text(column.label),
                      ),
                    ),
                  ),
                  if (column.showCount) ...[
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: style.fade,
                      curve: style.fadeCurve,
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: full ? style.fullCountColor : style.countColor,
                      ),
                      child: Text(
                        limit == null ? '$count' : '$count/$limit',
                        textAlign: TextAlign.center,
                        style: style.countTextStyle.copyWith(
                          color: full
                              ? style.fullCountForegroundColor
                              : style.countForegroundColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?column.trailing,
          ],
        ),
      ),
    );
  }
}

/// Paints the slot a dragged item will land in. It sits behind the items,
/// so it comes into view as they slide off it.
class _SlotPainter extends CustomPainter {
  _SlotPainter({
    required this.model,
    required this.color,
    required this.borderColor,
    required this.radius,
  }) : super(repaint: model);

  final _SlotModel model;
  final Color color;
  final Color borderColor;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = model.rect;
    if (rect == null || model.opacity <= 0) return;
    final shape = radius.toRRect(rect);
    canvas
      ..drawRRect(
        shape,
        Paint()..color = color.withValues(alpha: color.a * model.opacity),
      )
      ..drawRRect(
        shape.deflate(.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = borderColor.withValues(
            alpha: borderColor.a * model.opacity,
          ),
      );
  }

  @override
  bool shouldRepaint(_SlotPainter oldDelegate) =>
      model != oldDelegate.model ||
      color != oldDelegate.color ||
      borderColor != oldDelegate.borderColor ||
      radius != oldDelegate.radius;
}

/// One place in a column: the translation that makes way for a dragged
/// item, and the item that is there.
///
/// The item itself — the builder's widget, its focus and its gestures — is
/// a [_BoardItem] under a key the board owns, so it moves with its state
/// from one slot to another when the item changes column.
class _BoardSlot<T extends Object> extends StatefulWidget {
  const _BoardSlot({
    required this.board,
    required this.columnState,
    required this.column,
    required this.index,
    required this.item,
    required this.id,
    super.key,
  });

  final _BoardState<T> board;
  final _BoardColumnState<T> columnState;
  final BoardColumn<T> column;
  final int index;
  final T item;
  final Object id;

  @override
  State<_BoardSlot<T>> createState() => _BoardSlotState<T>();
}

class _BoardSlotState<T extends Object> extends State<_BoardSlot<T>>
    with AutomaticKeepAliveClientMixin {
  _BoardState<T> get _board => widget.board;

  // Handed over by the render object widget rather than looked up: the
  // board's ticker reaches for it at moments when an element that a lazy
  // list has just let go of may not be asked for its render object.
  _RenderBoardSlot? _render;

  /// The slot's render box once it has been laid out. It sits at the item's
  /// place in the list; the translation applies inside it.
  _RenderBoardSlot? get _box {
    final render = _render;
    if (render == null || !render.attached || !render.hasSize) return null;
    // A slot a lazy list keeps alive off screen is not laid out anywhere.
    // The list's own child is a few wrappers up (its semantic index).
    RenderObject? node = render;
    for (var i = 0; i < 4 && node != null; i++) {
      final data = node.parentData;
      if (data is SliverMultiBoxAdaptorParentData) {
        return data.keptAlive ? null : render;
      }
      node = node.parent;
    }
    return render;
  }

  /// The slot of a dragged or focused item outlives its scrolling out of
  /// view: it holds the focus that a keyboard drag is driven from, and the
  /// item's own state.
  @override
  bool get wantKeepAlive =>
      _board._hasFocus(widget.id) ||
      _board._isHidden(widget.id) ||
      _board._drag?.id == widget.id;

  // Whether the slot was created in this frame wanting to be kept alive.
  // The list is told of that after the frame — the slot has no child yet to
  // carry the answer — and may not be told the opposite in the meantime:
  // `AutomaticKeepAlive` asserts. So until then the wish stands, and is
  // looked at again when the frame is over.
  bool _wishPending = false;

  @override
  void initState() {
    super.initState();
    widget.columnState._mounted.add(this);
    _board._slotMounted(this);
    if (wantKeepAlive) {
      _wishPending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _wishPending = false;
        if (mounted) updateKeepAlive();
      });
    }
  }

  void _keepAliveChanged() {
    if (!_wishPending) updateKeepAlive();
  }

  @override
  void didUpdateWidget(_BoardSlot<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columnState != widget.columnState) {
      oldWidget.columnState._mounted.remove(this);
      widget.columnState._mounted.add(this);
    }
    if (oldWidget.id != widget.id) {
      _board._slotUnmounted(this, oldWidget.id);
      _board._slotMounted(this);
    }
  }

  @override
  void dispose() {
    widget.columnState._mounted.remove(this);
    _board._slotUnmounted(this, widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final board = _board;
    return _SlotShift(
      owner: this,
      host: board,
      id: widget.id,
      columnId: widget.column.id,
      child: Padding(
        padding: EdgeInsets.only(bottom: board._style.itemGap),
        child: RepaintBoundary(
          child: _BoardItem<T>(
            key: board._itemKey(widget.id),
            board: board,
            column: widget.column,
            index: widget.index,
            item: widget.item,
            id: widget.id,
          ),
        ),
      ),
    );
  }
}

/// One item: the builder's widget plus everything the board hangs on it —
/// the gesture that picks it up, keyboard focus and the semantics actions.
///
/// It is built under a `GlobalKey` per item id (`_BoardState._itemKey`), so
/// when the lists put the item in another column its element is moved into
/// the new slot instead of being built again: the item keeps its state and
/// its keyboard focus.
class _BoardItem<T extends Object> extends StatefulWidget {
  const _BoardItem({
    required this.board,
    required this.column,
    required this.index,
    required this.item,
    required this.id,
    super.key,
  });

  final _BoardState<T> board;
  final BoardColumn<T> column;
  final int index;
  final T item;
  final Object id;

  @override
  State<_BoardItem<T>> createState() => _BoardItemState<T>();
}

class _BoardItemState<T extends Object> extends State<_BoardItem<T>> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Board item');
  bool _showFocus = false;
  bool _traversable = true;

  _BoardState<T> get _board => widget.board;

  @override
  void initState() {
    super.initState();
    _board._itemMounted(this);
    _traversable = _wantsTraversal;
    _focusNode.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(_BoardItem<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _board._itemUnmounted(this, oldWidget.id);
      _board._itemMounted(this);
    }
    _traversable = _wantsTraversal;
  }

  @override
  void dispose() {
    _board._itemUnmounted(this, widget.id);
    _focusNode.dispose();
    super.dispose();
  }

  /// An item whose copy is in the air is not a Tab stop, and neither is
  /// anything inside it: its slot paints nothing, and a lazy list may be
  /// keeping it alive off screen, where it has no position for the focus
  /// traversal to scroll to. The item that has the focus keeps it.
  bool get _wantsTraversal =>
      !_board._isHidden(widget.id) || _focusNode.hasFocus;

  /// Called when the item's lifted copy comes or goes.
  void _hiddenChanged() {
    final traversable = _wantsTraversal;
    if (traversable != _traversable) setState(() => _traversable = traversable);
  }

  void _focusChanged() {
    _board._itemFocusChanged(widget.id, focused: _focusNode.hasFocus);
    if (mounted) _hiddenChanged();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) =>
      _board._handleItemKey(this, event);

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final style = board._style;
    final config = board.widget;
    final column = widget.column;
    final id = widget.id;
    final strings = UnaLocalizations.of(context).board;
    final draggable = config.enabled;

    // Every wrapper below is there whether or not the board is enabled and
    // whatever starts a drag: one that came and went would rebuild the item
    // from scratch each time.
    Widget child = Theme(
      data: style.itemTheme,
      // A finger held on the item lifts it: a menu region inside must not
      // open on the same press.
      child: LongPressTaken(
        taken: draggable && config.dragTrigger == BoardDragTrigger.item,
        child: Builder(
          builder: (context) => config.itemBuilder(
            context,
            widget.item,
            BoardItemDetails<T>(column: column, index: widget.index),
          ),
        ),
      ),
    );

    child = Listener(
      onPointerDown: draggable && config.dragTrigger == BoardDragTrigger.item
          ? (event) => board._itemPointerDown(event, id, immediate: false)
          : null,
      child: child,
    );

    child = FocusRing(
      visible: _showFocus && board._ringsFocus(this),
      borderRadius: style.itemRadius,
      child: child,
    );

    child = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      descendantsAreTraversable: _traversable,
      onKeyEvent: _handleKey,
      child: FocusableActionDetector(
        focusNode: _focusNode,
        enabled: draggable,
        onShowFocusHighlight: (value) {
          if (value != _showFocus) setState(() => _showFocus = value);
        },
        child: child,
      ),
    );

    final columns = config.columns;
    child = Semantics(
      container: true,
      label: config.itemSemanticLabel?.call(widget.item),
      customSemanticsActions: !draggable
          ? null
          : {
              if (widget.index > 0)
                CustomSemanticsAction(label: strings.moveUp): () =>
                    board._moveDirect(id, column.id, widget.index - 1),
              if (widget.index < column.items.length - 1)
                CustomSemanticsAction(label: strings.moveDown): () =>
                    board._moveDirect(id, column.id, widget.index + 1),
              for (final other in columns)
                if (other.id != column.id)
                  CustomSemanticsAction(
                    label: strings.moveTo(column: other.label),
                  ): () =>
                      board._moveDirect(id, other.id, null),
              ...board._moreItemActions(this),
            },
      child: child,
    );

    return _BoardItemScope(
      id: id,
      enabled: draggable,
      startHandleDrag: (event) =>
          board._itemPointerDown(event, id, immediate: true),
      child: child,
    );
  }
}

/// What a [_RenderBoardSlot] asks of the board.
abstract interface class _SlotHost {
  double _shiftOf(Object id);
  bool _isHidden(Object id);
  int get _flipGeneration;

  /// The item's place before the lists last changed, measured in its
  /// column, or null when it was not on screen.
  double? _flipOrigin(Object id, Object columnId);
  RenderObject? _flipAncestor(Object columnId);
  void _adoptShift(Object id, double shift);
}

class _SlotShift extends SingleChildRenderObjectWidget {
  const _SlotShift({
    required this.owner,
    required this.host,
    required this.id,
    required this.columnId,
    required super.child,
  });

  final _BoardSlotState<Object> owner;
  final _SlotHost host;
  final Object id;
  final Object columnId;

  @override
  _RenderBoardSlot createRenderObject(BuildContext context) =>
      owner._render = _RenderBoardSlot(
        host: host,
        id: id,
        columnId: columnId,
      );

  @override
  void didUnmountRenderObject(_RenderBoardSlot renderObject) {
    if (owner._render == renderObject) owner._render = null;
  }

  @override
  void updateRenderObject(BuildContext context, _RenderBoardSlot renderObject) {
    renderObject
      ..host = host
      ..id = id
      ..columnId = columnId;
  }
}

/// Paints an item away from where it is laid out.
///
/// The offset is how the other items make way for a dragged one: it is set
/// by the board's ticker and only repaints, so opening a slot lays nothing
/// out. A hidden slot paints nothing — its item is in the overlay — but
/// keeps its size, its semantics and its hit testing.
class _RenderBoardSlot extends RenderProxyBox {
  _RenderBoardSlot({
    required this.host,
    required Object id,
    required this.columnId,
  }) : _id = id,
       _shift = host._shiftOf(id),
       _hidden = host._isHidden(id),
       _flipGeneration = host._flipGeneration;

  _SlotHost host;
  Object columnId;

  Object get id => _id;
  Object _id;
  set id(Object value) {
    if (value == _id) return;
    _id = value;
    shift = host._shiftOf(value);
    hidden = host._isHidden(value);
    markNeedsSemanticsUpdate();
  }

  double get shift => _shift;
  double _shift;
  set shift(double value) {
    if (value == _shift) return;
    _shift = value;
    markNeedsPaint();
  }

  /// Called when the shift has come to rest. The semantics tree is told
  /// where the item is then, once, rather than on every frame of the way.
  void shiftSettled() => markNeedsSemanticsUpdate();

  bool get hidden => _hidden;
  bool _hidden;
  set hidden(bool value) {
    if (value == _hidden) return;
    _hidden = value;
    markNeedsPaint();
  }

  int _flipGeneration;

  /// When the lists have just changed, works out where this item was and
  /// starts it from there: first, last, invert, play.
  ///
  /// It runs in paint because that is the first moment the new layout is
  /// known, and the last at which the item can still be drawn where it was
  /// instead of jumping for a frame.
  void _resolveFlip() {
    if (_flipGeneration == host._flipGeneration) return;
    _flipGeneration = host._flipGeneration;
    final origin = host._flipOrigin(_id, columnId);
    final ancestor = host._flipAncestor(columnId);
    if (origin == null || ancestor == null) return;
    final now = localToGlobal(Offset.zero, ancestor: ancestor).dy;
    final shift = origin - now;
    if ((shift - _shift).abs() < .01) return;
    // Not through the setter: this is paint, and it is about to draw.
    _shift = shift;
    host._adoptShift(_id, shift);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _resolveFlip();
    if (child == null || _hidden) return;
    context.paintChild(child!, offset.translate(0, _shift));
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.translateByDouble(0, _shift, 0, 1);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // A shifted item is outside its own slot, so the bounds are not the
    // test.
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(
      offset: Offset(0, _shift),
      position: position,
      hitTest: (result, transformed) =>
          super.hitTestChildren(result, position: transformed),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('shift', _shift))
      ..add(FlagProperty('hidden', value: _hidden, ifTrue: 'hidden'));
  }
}

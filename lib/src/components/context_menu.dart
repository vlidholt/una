import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/components/button.dart';
import 'package:una/src/components/divider.dart';
import 'package:una/src/components/dropdown_menu.dart';
import 'package:una/src/components/popover.dart';
import 'package:una/src/components/scroll_area.dart';
import 'package:una/src/i18n/localizations_delegate.dart';
import 'package:una/src/icons/phosphor_icons.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/liquid_glass/menu.dart';
import 'package:una/src/raw_components/portal.dart';
import 'package:una/src/theme/components/button.dart';
import 'package:una/src/theme/components/context_menu.dart';
import 'package:una/src/theme/components/decorator.dart';
import 'package:una/src/theme/components/layout.dart';
import 'package:una/src/theme/data.dart';
import 'package:una/src/theme/form_factor.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/theme/theme_scope.dart';
import 'package:una/src/utils/arrow_key_focus.dart';
import 'package:una/src/utils/border.dart';
import 'package:una/src/utils/browser_context_menu/browser_context_menu.dart';
import 'package:una/src/utils/dismiss_shortcut.dart';
import 'package:una/src/utils/entrance.dart';
import 'package:una/src/utils/extensions/text_style.dart';
import 'package:una/src/utils/focus_visibility.dart';
import 'package:una/src/utils/gesture_detector.dart';
import 'package:una/src/utils/haptics.dart';
import 'package:una/src/utils/long_press_taken.dart';
import 'package:una/src/utils/mouse_area.dart';
import 'package:una/src/utils/pop_in.dart';
import 'package:una/src/utils/provider.dart';

part 'menu_items.dart';
part 'show_menu.dart';

/// {@template ContextMenuRegion}
/// A widget that shows the context menu when the user right clicks the [child]
/// or long presses it (only on android and ios), unless a value to
/// [longPressEnabled] is provided.
///
/// On Android and iOS, tapping the [child] also shows the context menu by
/// default. This can be overridden using [tapEnabled].
/// {@endtemplate}
class ContextMenuRegion extends StatefulWidget {
  /// {@macro ContextMenuRegion}
  const ContextMenuRegion({
    super.key,
    required this.child,
    this.items = const [],
    this.itemsBuilder,
    this.open,
    this.constraints,
    this.padding,
    this.shadows,
    this.decoration,
    this.filter,
    this.controller,
    this.supportedDevices,
    this.longPressEnabled,
    this.tapEnabled,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.requestFocus = true,
  });

  /// {@macro ContextMenu.requestFocus}
  final bool requestFocus;

  /// {@template ContextMenuRegion.child}
  /// The child that triggers the visibility of the context menu.
  /// {@endtemplate}
  final Widget child;

  /// {@macro ContextMenu.items}
  final List<Widget> items;

  /// {@macro ContextMenu.itemsBuilder}
  final List<Widget> Function(BuildContext context)? itemsBuilder;

  /// {@macro ContextMenu.open}
  final bool? open;

  /// {@macro ContextMenu.constraints}
  final BoxConstraints? constraints;

  /// {@macro ContextMenu.padding}
  final EdgeInsetsGeometry? padding;

  /// {@macro Popover.shadows}
  final List<BoxShadow>? shadows;

  /// {@macro Popover.decoration}
  final UnaDecoration? decoration;

  /// {@macro Popover.filter}
  final ImageFilter? filter;

  /// {@macro ContextMenu.controller}
  final PopoverController? controller;

  /// {@template ContextMenuRegion.hitTestBehavior}
  /// How this gesture detector should behave during hit testing.
  ///
  /// This defaults to [HitTestBehavior.opaque].
  /// {@endtemplate}
  final HitTestBehavior hitTestBehavior;

  /// The kind of devices that are allowed to be recognized.
  ///
  /// If set to null, events from all device types will be recognized. Defaults
  /// to null.
  final Set<PointerDeviceKind>? supportedDevices;

  /// {@template ContextMenuRegion.longPressEnabled}
  /// Whether the context menu should be shown when the user long presses the
  /// child, defaults to true only on Android and iOS.
  /// {@endtemplate}
  final bool? longPressEnabled;

  /// {@template ContextMenuRegion.tapEnabled}
  /// Whether the context menu should be shown when the user taps/left-clicks
  /// the child.
  ///
  /// Defaults to true on Android and iOS, false on other platforms.
  /// {@endtemplate}
  final bool? tapEnabled;

  @override
  State<ContextMenuRegion> createState() => _ContextMenuRegionState();
}

class _ContextMenuRegionState extends State<ContextMenuRegion> {
  PopoverController? _controller;
  PopoverController get controller =>
      widget.controller ??
      (_controller ??= PopoverController(isOpen: widget.open ?? false));
  Offset? offset;

  @override
  void didUpdateWidget(covariant ContextMenuRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != null) {
      controller.setOpen(widget.open!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void showAtOffset(Offset offset) {
    if (!mounted) return;
    setState(() => this.offset = offset);
    controller.open();
  }

  void hide() {
    controller.close();
  }

  void show(Offset offset) {
    showAtOffset(offset);
  }

  /// The context menu key, or Shift+F10, with the focus in the child:
  /// opens the menu at the child's bottom start corner, where a pointer
  /// would have nothing to say about the place.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final menuKey =
        key == LogicalKeyboardKey.contextMenu ||
        (key == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed);
    if (!menuKey) return KeyEventResult.ignored;
    if (widget.items.isEmpty && widget.itemsBuilder == null) {
      return KeyEventResult.ignored;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return KeyEventResult.ignored;
    final corner = Directionality.of(context) == TextDirection.ltr
        ? box.size.bottomLeft(Offset.zero)
        : box.size.bottomRight(Offset.zero);
    showAtOffset(box.localToGlobal(corner));
    return KeyEventResult.handled;
  }

  void onLongPress() {
    assert(offset != null, 'offset must not be null');
    // A held finger is answered with a firm tick as the menu comes up.
    Haptics.impact(context, HapticImpact.medium);
    showAtOffset(offset!);
  }

  @override
  Widget build(BuildContext context) {
    // Not where a held finger already lifts something to drag it.
    final effectiveLongPressEnabled =
        widget.longPressEnabled ??
        ((defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS) &&
            !LongPressTaken.of(context));

    // A touch inside a lifting item is the item's: a tap opens it, a held
    // finger lifts it — and a tap's down comes first in a long press.
    final effectiveTapEnabled =
        widget.tapEnabled ??
        ((defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS) &&
            !LongPressTaken.of(context));

    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    return ContextMenu.internal(
      // Radix opens a context menu with its corner at the pointer, not
      // centred on it.
      anchor: offset == null
          ? null
          : GlobalAnchor(
              offset!,
              followerAnchor: AlignmentDirectional.topStart,
            ),
      controller: controller,
      items: widget.items,
      itemsBuilder: widget.itemsBuilder,
      constraints: widget.constraints,
      padding: widget.padding,
      shadows: widget.shadows,
      decoration: widget.decoration,
      filter: widget.filter,
      requestFocus: widget.requestFocus,
      child: UnaGestureDetector(
        behavior: widget.hitTestBehavior,
        supportedDevices: widget.supportedDevices,
        onTapDown: (d) {
          if (effectiveTapEnabled) {
            if (controller.isOpen) {
              hide();
            } else {
              show(d.globalPosition);
            }
          } else {
            hide();
          }
        },
        // The browser's native menu is cancelled per event, never by
        // flipping `BrowserContextMenu`'s global flag: `SelectionArea`
        // changes its tree shape on that flag, and remounting its selection
        // container mid-flight trips `SelectableRegion`'s
        // `assert(_selectable == null)`. See suppressBrowserContextMenu.
        onSecondaryTapDown: (d) {
          if (kIsWeb) suppressBrowserContextMenu();
          if (!isWindows) show(d.globalPosition);
        },
        onSecondaryTapUp: (d) {
          // On Windows the browser fires `contextmenu` on button up, which
          // can be arbitrarily long after the down — re-arm so a slow click
          // stays covered, and only then open the menu.
          if (kIsWeb) suppressBrowserContextMenu();
          if (isWindows) show(d.globalPosition);
        },
        onLongPressStart: effectiveLongPressEnabled
            ? (d) {
                offset = d.globalPosition;
              }
            : null,
        onLongPress: effectiveLongPressEnabled ? onLongPress : null,
        // Hears the menu key with the focus anywhere in the child, and is
        // no stop of its own.
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: _onKey,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A menu of [MenuItem]s shown in a popover next to [child].
///
/// This is the menu surface behind shadcn's `DropdownMenuContent` and
/// `ContextMenuContent`. It opens when [open] or [controller] says so —
/// `controller.openAt(point)` opens it with its corner at a point, as a
/// context menu opens at the pointer — and [ContextMenuRegion] opens it on a
/// right click or long press. With no [items] and no [itemsBuilder], it
/// builds only [child].
class ContextMenu extends StatefulWidget {
  /// Creates a context menu anchored to [child].
  const ContextMenu({
    super.key,
    required this.child,
    this.items = const [],
    this.itemsBuilder,
    this.anchor,
    this.open,
    this.constraints,
    this.padding,
    this.shadows,
    this.decoration,
    this.filter,
    this.controller,
    this.requestFocus = true,
  }) : areaGroupId = null,
       onHoverArea = null,
       entrance = null,
       onTapOutside = null,
       onTapUpInside = null,
       onDismissed = null,
       onMoveAcross = null,
       announcesOpen = true,
       liquidGlassMorph = true;

  /// Creates a context menu with the plumbing the package's own menus need:
  /// the hover group and tap callbacks that tie a submenu to its row and a
  /// menubar's menu to its trigger, and an entrance of its own.
  @internal
  const ContextMenu.internal({
    super.key,
    required this.child,
    this.items = const [],
    this.itemsBuilder,
    this.anchor,
    this.open,
    this.constraints,
    this.padding,
    this.shadows,
    this.decoration,
    this.filter,
    this.controller,
    this.requestFocus = true,
    this.areaGroupId,
    this.onHoverArea,
    this.entrance,
    this.onTapOutside,
    this.onTapUpInside,
    this.onDismissed,
    this.onMoveAcross,
    this.announcesOpen = false,
    this.liquidGlassMorph = false,
  });

  /// Called with 1 or -1 when Right or Left, in the reading direction,
  /// leads out of the menu sideways: from a row with no submenu that way,
  /// or back from the top level. A menubar moves to the next menu.
  @internal
  final ValueChanged<int>? onMoveAcross;

  /// Whether the trigger tells a screen reader whether the menu is open
  /// (`expanded`). A [ContextMenuRegion], which opens at the pointer, and a
  /// submenu's row, which says it itself, do not.
  @internal
  final bool announcesOpen;

  /// Whether the menu may morph out of [child] on Liquid Glass (see
  /// `LiquidGlassMorphPopover`): on a phone or a tablet, for a root menu
  /// opened at its own anchor. A `ContextMenuRegion`'s menu, which opens
  /// at the pointer, never does.
  @internal
  final bool liquidGlassMorph;

  /// {@template ContextMenu.requestFocus}
  /// Whether the menu takes the keyboard focus when it opens, defaults to
  /// true: the arrow keys, Home, End and type-ahead then work straight
  /// away, and the focus goes back to where it was when the menu closes.
  ///
  /// Set it to false for a menu that assists what it is anchored to — the
  /// completions under a text field — so the caret stays put. Tab then
  /// moves from the anchor into the menu, where the arrow keys take over,
  /// and Escape closes the menu from either. See `Popover.requestFocus`.
  /// {@endtemplate}
  final bool requestFocus;

  /// {@template ContextMenu.child}
  /// The child of the context menu.
  /// {@endtemplate}
  final Widget child;

  /// {@template ContextMenu.items}
  /// The items of the context menu.
  /// {@endtemplate}
  final List<Widget> items;

  /// {@template ContextMenu.itemsBuilder}
  /// Builds the items each time the menu opens, instead of [items].
  ///
  /// The items are not built while the menu is closed, which matters for a
  /// menu whose items are expensive or depend on state that changes while it
  /// is closed.
  /// {@endtemplate}
  final List<Widget> Function(BuildContext context)? itemsBuilder;

  /// {@template ContextMenu.anchor}
  /// The anchor of the context menu.
  /// {@endtemplate}
  final AnchorBase? anchor;

  /// {@template ContextMenu.open}
  /// Whether the context menu is open. Null, the default, leaves that to
  /// the controller.
  /// {@endtemplate}
  final bool? open;

  /// {@template ContextMenu.constraints}
  /// The constraints of the context menu, defaults to
  /// `BoxConstraints(minWidth: 128)`.
  /// {@endtemplate}
  final BoxConstraints? constraints;

  /// Called when the pointer enters or leaves the menu's hover area: its
  /// child, its surface and every area that shares [areaGroupId].
  @internal
  final ValueChanged<bool>? onHoverArea;

  /// {@template ContextMenu.padding}
  /// The padding of the context menu, defaults to
  /// `EdgeInsets.symmetric(vertical: 4)`.
  /// {@endtemplate}
  final EdgeInsetsGeometry? padding;

  /// The hover group of the menu: the row a submenu hangs from and the
  /// submenu itself are one area to the pointer.
  @internal
  final Object? areaGroupId;

  /// The entrance, when it is not the theme's: the plain fade of a menu
  /// that takes over from the one beside it.
  @internal
  final EntranceSpec? entrance;

  /// {@macro Popover.shadows}
  final List<BoxShadow>? shadows;

  /// {@macro Popover.decoration}
  final UnaDecoration? decoration;

  /// {@macro Popover.filter}
  final ImageFilter? filter;

  /// {@template ContextMenu.controller}
  /// Opens and closes the menu. `openAt` opens it with its corner at a
  /// point in global coordinates instead of at its [anchor].
  /// {@endtemplate}
  final PopoverController? controller;

  /// Called when a tap down lands outside the menu tree.
  @internal
  final TapRegionCallback? onTapOutside;

  /// Called when a tap is released inside the menu tree.
  @internal
  final TapRegionUpCallback? onTapUpInside;

  /// Called when a menu that [open] holds open closes itself: Escape, with
  /// the focus in it. A row uses it to keep the submenu it dismissed shut.
  @internal
  final VoidCallback? onDismissed;

  @override
  State<ContextMenu> createState() => _ContextMenuState();
}

/// The state of a [ContextMenu].
///
/// Its items and submenus find it in the widget tree.
class _ContextMenuState extends State<ContextMenu> {
  PopoverController? _controller;

  /// How wide a menu that morphs out of its trigger is, at most: an iOS
  /// menu's width.
  static const _morphWidth = 250.0;

  /// Whether the last build morphed the menu out of its trigger.
  bool _builtMorph = false;

  /// This menu's tap-region group when it is a root menu.
  final Object _ownTapRegionGroupId = Object();

  /// The root menu above this one, if this is a submenu.
  _ContextMenuState? _root;

  /// The row of this menu, or of one of its submenus, that was chosen and
  /// is showing that it was before the menu closes. Another row is not
  /// chosen meanwhile.
  _MenuItemState? _confirming;

  /// The menu's content, which takes focus when a root menu opens so that
  /// arrow keys, Home/End and type-ahead work straight away, as in Radix.
  final _contentFocusNode = FocusNode(debugLabel: 'ContextMenu content');

  /// The row of this menu level the pointer was last over.
  _MenuItemState? _hoveredItem;

  /// Called when the pointer reaches [item], a row of this menu level. The
  /// row it left gives up its highlight and closes its submenu at once,
  /// without waiting for its grace period, so only one submenu is ever open.
  void _itemHovered(_MenuItemState item) {
    final previous = _hoveredItem;
    _hoveredItem = item;
    if (previous == null || identical(previous, item) || !previous.mounted) {
      return;
    }
    previous._unhoverNow();
  }

  /// How many checkable rows of this menu level are mounted. Rows that are
  /// direct children of the menu are seen in its item list; this finds the
  /// ones a wrapper hides.
  int _checkables = 0;

  /// Whether the last build gave this level an indicator column.
  bool _builtIndicatorColumn = false;

  void _checkableMounted() {
    _checkables++;
    _syncIndicatorColumn();
  }

  void _checkableUnmounted() {
    _checkables--;
    _syncIndicatorColumn();
  }

  /// Rebuilds once the frame is over when the rows that registered
  /// disagree with what the item list said: a row is mounted during the
  /// build that would have to change.
  void _syncIndicatorColumn() {
    if ((_checkables > 0) == _builtIndicatorColumn) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (_checkables > 0) != _builtIndicatorColumn) {
        setState(() {});
      }
    });
  }

  /// Whether any of [items] is a checkable row, so that every row of the
  /// level reserves the indicator column and the labels line up.
  static bool _anyCheckable(List<Widget> items) => items.any(
    (item) =>
        item is MenuCheckboxItem ||
        item is MenuRadioGroup ||
        item is MenuRadioItem,
  );

  /// The characters typed in quick succession, for type-ahead.
  String _typeAhead = '';
  Timer? _typeAheadReset;

  PopoverController? _listened;

  void _listenTo(PopoverController controller) {
    if (identical(controller, _listened)) return;
    _listened?.removeListener(_onOpenChanged);
    _listened = controller..addListener(_onOpenChanged);
  }

  void _onOpenChanged() {
    final controller = this.controller;
    // A menu opened at a point is a una popover, never a morph.
    if (_builtMorph && controller.position != null) setState(() {});
    // Closed from inside while its parent still says open.
    if (!controller.isOpen && (widget.open ?? false)) {
      widget.onDismissed?.call();
    }
    if (controller.isOpen && !_wasOpen) {
      // Where Tab moves on from; see [_leaveByTab].
      _focusBeforeOpen = FocusManager.instance.primaryFocus;
      _contentFocusNode.descendantsAreFocusable = true;
      _skippedScope?.skipTraversal = false;
      _skippedScope = null;
    }
    _wasOpen = controller.isOpen;
    // A hover-opened submenu leaves focus where it is, and so does a menu
    // that was asked to.
    if (!controller.isOpen || _root != null || !widget.requestFocus) return;
    // Opened from the keyboard, the first row takes the focus, as in Radix;
    // opened by a pointer, the menu does, and the arrows enter it at either
    // end.
    FocusVisibility.ensureInstalled();
    final byKeyboard =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    _focusOnOpen(byKeyboard: byKeyboard, framesLeft: 4);
  }

  /// Focuses the menu, or its first row, after the frame. The rows are
  /// built a frame or two after the menu opens — the portal lays the
  /// overlay out unseen first — so a first row that is not there yet is
  /// asked for again after the next frame, the menu having the focus
  /// meanwhile.
  void _focusOnOpen({required bool byKeyboard, required int framesLeft}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.isOpen || _hasFocusedItem) return;
      final first = byKeyboard ? _itemNodes.firstOrNull : null;
      if (first != null) {
        first.requestFocus();
        return;
      }
      if (!_contentFocusNode.hasFocus) _contentFocusNode.requestFocus();
      if (byKeyboard && framesLeft > 0) {
        _focusOnOpen(byKeyboard: true, framesLeft: framesLeft - 1);
        WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  bool _wasOpen = false;

  /// What had the focus when the menu opened: the trigger, as a rule.
  FocusNode? _focusBeforeOpen;

  /// The popover's scope, taken out of the traversal by [_leaveByTab]
  /// until the menu opens again.
  FocusScopeNode? _skippedScope;

  /// Tab or Shift+Tab in a menu: the menu does not trap the focus, it
  /// closes, and the focus moves on from the trigger as if the menu had not
  /// been there (WAI-ARIA's menu button).
  void _leaveByTab({required bool forward}) {
    final root = _root ?? this;
    final from = root._focusBeforeOpen;
    if (from != null && from.context != null && from.canRequestFocus) {
      // The rows go out of the traversal at once: the menu is still in the
      // tree while it leaves, and Tab from the trigger would land in it —
      // in its rows, or in the scope of the popover around them.
      root._contentFocusNode.descendantsAreFocusable = false;
      final scope = root._contentFocusNode.ancestors
          .whereType<FocusScopeNode>()
          .firstOrNull;
      if (scope != null && !identical(scope, from.nearestScope)) {
        scope.skipTraversal = true;
        root._skippedScope = scope;
      }
      // Traversal moves on from the scope's focused child, which is the
      // menu: back on the trigger first, synchronously, and on from there.
      // Before the menu closes: the focus it hands back to the trigger is
      // only asked for when the focus is still in it by then.
      from.requestFocus();
      forward ? from.nextFocus() : from.previousFocus();
    }
    root.controller.close();
  }

  /// The focusable items of this menu level, in order. Submenu items are
  /// focus descendants too (their overlay is built below this one), so they
  /// are told apart by the level they were built in.
  List<FocusNode> get _itemNodes => [
    for (final node in _contentFocusNode.traversalDescendants)
      if (node.context?.getInheritedWidgetOfExactType<_MenuLevel>()?.menu ==
          this)
        node,
  ];

  bool get _hasFocusedItem => _itemNodes.any((n) => n.hasPrimaryFocus);

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.tab &&
        event is KeyDownEvent &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isAltPressed) {
      _leaveByTab(forward: !keyboard.isShiftPressed);
      return KeyEventResult.handled;
    }
    final items = _itemNodes;
    if (items.isEmpty) return KeyEventResult.ignored;
    final current = items.indexWhere((n) => n.hasPrimaryFocus);

    final across = (_root ?? this).widget.onMoveAcross;
    if (across != null &&
        (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowLeft)) {
      final forward =
          (key == LogicalKeyboardKey.arrowRight) ==
          (Directionality.of(context) == TextDirection.ltr);
      final row = current == -1
          ? null
          : items[current].context?.findAncestorStateOfType<_MenuItemState>();
      // Into the focused row's submenu, or back out of this one, is the
      // arrow keys' own move.
      final intoSubmenu = forward && (row?.widget.items.isNotEmpty ?? false);
      final outOfSubmenu = !forward && _root != null;
      if (!intoSubmenu && !outOfSubmenu) {
        across(forward ? 1 : -1);
        return KeyEventResult.handled;
      }
    }
    // Back out of a submenu: it closes, as with Escape, and the focus goes
    // back to its row. The submenu is a focus scope of its own, which the
    // arrows' directional focus does not leave.
    if (_root != null &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight) &&
        (key == LogicalKeyboardKey.arrowLeft) ==
            (Directionality.of(context) == TextDirection.ltr)) {
      controller.close();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.home) {
      items.first.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      items.last.requestFocus();
      return KeyEventResult.handled;
    }
    // From the content itself (after a pointer open), the arrows enter the
    // list at either end.
    if (current == -1 && key == LogicalKeyboardKey.arrowDown) {
      items.first.requestFocus();
      return KeyEventResult.handled;
    }
    if (current == -1 && key == LogicalKeyboardKey.arrowUp) {
      items.last.requestFocus();
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character == null ||
        character.trim().isEmpty ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    _typeAheadReset?.cancel();
    _typeAheadReset = Timer(
      const Duration(milliseconds: 500),
      () => _typeAhead = '',
    );
    _typeAhead += character.toLowerCase();
    // Repeating one letter cycles through the items starting with it.
    final query = _typeAhead.split('').toSet().length == 1
        ? _typeAhead[0]
        : _typeAhead;
    final start = query.length == 1 ? current + 1 : math.max(current, 0);
    for (var i = 0; i < items.length; i++) {
      final candidate = items[(start + i) % items.length];
      final label = _labelOf(candidate.context);
      if (label != null && label.toLowerCase().startsWith(query)) {
        candidate.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.handled;
  }

  /// The first text below [context] outside an icon: an item's label.
  static String? _labelOf(BuildContext? context) {
    String? label;
    void visit(Element element) {
      if (label != null) return;
      final widget = element.widget;
      // An Icon renders its glyph as RichText; a leading icon would otherwise
      // be taken for the label.
      if (widget is Icon) return;
      if (widget is Text) {
        label = widget.data ?? widget.textSpan?.toPlainText();
      } else if (widget is RichText) {
        label = widget.text.toPlainText();
      }
      if (label == null) element.visitChildren(visit);
    }

    if (context is Element) context.visitChildren(visit);
    return label;
  }

  /// The tap-region group of this menu tree: a root menu's own, shared with
  /// every submenu below it, so taps inside any of them count as inside.
  /// Distinct per root menu, so a tap on another menu's trigger counts as
  /// outside and closes this one.
  Object get tapRegionGroupId =>
      _root?.tapRegionGroupId ?? _ownTapRegionGroupId;

  /// The controller in use: [ContextMenu.controller] when given, otherwise
  /// an internal one that starts open when [ContextMenu.open] is true.
  PopoverController get controller =>
      widget.controller ??
      (_controller ??= PopoverController(isOpen: widget.open ?? false));

  @override
  void initState() {
    super.initState();
    _listenTo(controller);
    // A menu that is open from the start — `visible: true`, or the route of
    // `showMenu` — gets no change to hear of, and takes the focus like one
    // that was opened later. After the frame: whether it is a submenu is
    // only known once it has been built.
    if (controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onOpenChanged();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listenTo(controller);
    if (widget.open != null) {
      controller.setOpen(widget.open!);
    }
  }

  @override
  void dispose() {
    _listened?.removeListener(_onOpenChanged);
    _typeAheadReset?.cancel();
    _contentFocusNode.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// Opens the menu when [open] is true, and closes it otherwise.
  void setOpen(bool open) {
    controller.setOpen(open);
  }

  @override
  Widget build(BuildContext context) {
    // A submenu is built below its root menu's provider; a root menu finds
    // none, since it puts its own provider below itself.
    _root = context.maybeRead<_ContextMenuState>();

    // if the context menu has no items, just return the child
    if (widget.items.isEmpty && widget.itemsBuilder == null) {
      return widget.child;
    }

    final theme = Theme.of(context);

    final effectiveConstraints =
        widget.constraints ??
        theme.contextMenuTheme.constraints ??
        const BoxConstraints(minWidth: 128);

    final effectivePadding =
        widget.padding ??
        theme.contextMenuTheme.padding ??
        const EdgeInsets.symmetric(vertical: 4);

    final effectiveDecoration =
        (theme.contextMenuTheme.decoration ?? const UnaDecoration()).merge(
          widget.decoration,
        );

    final effectiveFilter = widget.filter ?? theme.contextMenuTheme.filter;

    final effectiveShadows = widget.shadows ?? theme.contextMenuTheme.shadows;

    final controller = this.controller;

    // Long menus scroll instead of running off screen; Radix caps them at
    // the available height the same way.
    final resolvedPadding = effectivePadding.resolve(
      Directionality.of(context),
    );
    final maxHeight = math
        .max(
          0,
          MediaQuery.sizeOf(context).height - resolvedPadding.vertical - 16,
        )
        .toDouble();

    Widget menu(BuildContext context, {bool fixedWidth = false}) {
      final items = widget.itemsBuilder?.call(context) ?? widget.items;
      final indicatorColumn = _checkables > 0 || _anyCheckable(items);
      _builtIndicatorColumn = indicatorColumn;
      Widget list = TapRegion(
        onTapOutside: widget.onTapOutside,
        onTapUpInside: widget.onTapUpInside,
        groupId: tapRegionGroupId,
        // The arrows walk the rows wherever the app runs; the
        // web's default shortcuts would scroll the page instead.
        child: ArrowKeyFocus(
          child: Focus(
            focusNode: _contentFocusNode,
            skipTraversal: true,
            onKeyEvent: _handleKey,
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ScrollArea(
                  child: _MenuLevel(
                    menu: this,
                    indicatorColumn: indicatorColumn,
                    // A menu to a screen reader: its rows are menu
                    // items, and a submenu is a menu of its own.
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      role: items.isEmpty ? null : SemanticsRole.menu,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: MenuEdge.mark(items),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      if (!fixedWidth) {
        list = ConstrainedBox(
          constraints: effectiveConstraints,
          child: IntrinsicWidth(child: list),
        );
      }
      return MouseArea(
        groupId: widget.areaGroupId,
        key: ValueKey(widget.areaGroupId),
        child: list,
      );
    }

    var triggerChild = widget.child;
    if (widget.announcesOpen) {
      // A menu button says whether its menu is open, as one node with the
      // trigger's own label and action.
      triggerChild = ListenableBuilder(
        listenable: controller,
        builder: (context, child) => MergeSemantics(
          child: Semantics(expanded: controller.isOpen, child: child),
        ),
        child: triggerChild,
      );
    }
    final trigger = MouseArea(
      groupId: widget.areaGroupId,
      onEnter: (_) => widget.onHoverArea?.call(true),
      onExit: (_) => widget.onHoverArea?.call(false),
      child: TapRegion(groupId: tapRegionGroupId, child: triggerChild),
    );

    _builtMorph =
        widget.liquidGlassMorph &&
        _root == null &&
        widget.requestFocus &&
        controller.position == null &&
        theme.formFactor != FormFactor.desktop &&
        LiquidGlass.isActive(context, theme.popoverTheme.liquidGlass);
    if (_builtMorph) {
      final radius = theme.radii.resolve(theme.style.popoverRadius);
      Widget child = LiquidGlassMorphPopover(
        controller: controller,
        width: math.min(
          _morphWidth,
          MediaQuery.sizeOf(context).width -
              2 * theme.layoutTheme.gap(GapSize.md),
        ),
        radius: radius.topLeft.x,
        builder: (context) => Padding(
          padding: effectivePadding,
          child: menu(context, fixedWidth: true),
        ),
        child: trigger,
      );
      child = DismissShortcut(
        isActive: () => controller.isOpen,
        onDismiss: controller.close,
        child: child,
      );
      return Provider(data: this, child: child);
    }

    Widget child = Popover.internal(
      controller: controller,
      padding: effectivePadding,
      areaGroupId: widget.areaGroupId,
      groupId: tapRegionGroupId,
      // A point given to the controller's `openAt` wins over this; the
      // popover sees to that.
      anchor: widget.anchor,
      decoration: effectiveDecoration,
      entrance: widget.entrance,
      shadows: effectiveShadows,
      filter: effectiveFilter,
      // A submenu that closes is being replaced by a sibling's, or the
      // pointer has left the menu: it goes at once rather than fading out
      // over the one that replaces it.
      exitDuration: _root != null ? Duration.zero : null,
      useSameGroupIdForChild: false,
      requestFocus: widget.requestFocus,
      builder: menu,
      child: trigger,
    );

    // just put one context menu inherited widget.
    if (_root == null) {
      child = Provider(data: this, child: child);
    }

    return child;
  }
}

/// Tracks whether a [MenuItem] is hovered or focused, and the same
/// for the items in its submenu.
///
/// Used internally. It is not exported from `package:una/una.dart`.
class _MenuItemController extends ChangeNotifier {
  /// Creates a controller for the item identified by [itemKey].
  _MenuItemController({
    required this.itemKey,
    bool hovered = false,
    bool focused = false,
  }) : _hovered = hovered,
       _focused = focused;

  bool _hovered = false;

  /// Whether the pointer is over the item.
  bool get hovered => _hovered;

  /// Sets [hovered], and notifies listeners when it changes.
  void setHovered(bool hovered) {
    if (hovered == _hovered) return;
    _hovered = hovered;
    notifyListeners();
  }

  bool _focused = false;

  /// Whether the item has keyboard focus.
  bool get focused => _focused;

  /// Sets [focused], and notifies listeners when it changes.
  void setFocused(bool focused) {
    if (focused == _focused) return;
    _focused = focused;
    notifyListeners();
  }

  /// Identifies the item in its parent's [items] map.
  final Key itemKey;

  /// Maps the item key to the item controller
  final Map<Key, _MenuItemController> items = {};

  /// Whether the item is highlighted: it is hovered or focused, or an item in
  /// its submenu is.
  bool get selected =>
      _hovered || _focused || items.values.any((e) => e.selected);

  /// Clears [hovered] on this item and on every item in its submenu.
  void clearHovered() {
    for (final item in items.values) {
      item.clearHovered();
    }
    setHovered(false);
  }

  /// Adds [controller] to the items of this item's submenu.
  void registerSubItem(_MenuItemController controller) {
    items[controller.itemKey] = controller;
  }

  /// Removes [controller] from the items of this item's submenu.
  void unregisterSubItem(_MenuItemController controller) {
    items.remove(controller.itemKey);
  }
}

/// The variant of the context menu item.
enum MenuItemVariant {
  /// A regular row.
  primary,

  /// A row with extra start padding, so that its label lines up with rows that
  /// have a leading icon. shadcn's `inset` prop.
  inset,
}

/// A row in a [ContextMenu], shadcn's `DropdownMenuItem`.
///
/// When [items] is not empty, the row opens a submenu with them on hover.
class MenuItem extends StatefulWidget {
  /// Creates a menu item: a regular row unless [variant] says otherwise.
  const MenuItem({
    super.key,
    this.variant = MenuItemVariant.primary,
    required this.child,
    this.items = const [],
    this.enabled = true,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onTapDown,
    this.style,
    this.closeOnTap,
    this.destructive = false,
    this.shortcut,
    this.value,
  });

  /// Creates an inset menu item, whose label lines up with items that have a
  /// leading icon.
  const MenuItem.inset({
    super.key,
    required this.child,
    this.items = const [],
    this.enabled = true,
    this.leading,
    this.trailing,
    this.onPressed,
    this.onTapDown,
    this.style,
    this.closeOnTap,
    this.destructive = false,
    this.shortcut,
    this.value,
  }) : variant = MenuItemVariant.inset;

  /// {@template MenuItem.variant}
  /// The variant of the context menu item, defaults to
  /// [MenuItemVariant.primary].
  /// {@endtemplate}
  final MenuItemVariant variant;

  /// {@template MenuItem.child}
  /// The child of the context menu item.
  /// {@endtemplate}
  final Widget child;

  /// {@template MenuItem.enabled}
  /// Whether the context menu item is enabled, defaults to true.
  /// {@endtemplate}
  final bool enabled;

  /// {@template MenuItem.leading}
  /// The leading widget of the context menu item.
  /// {@endtemplate}
  final Widget? leading;

  /// {@template MenuItem.trailing}
  /// The trailing widget of the context menu item.
  /// {@endtemplate}
  final Widget? trailing;

  /// {@template MenuItem.onPressed}
  /// The callback called when the context menu item is pressed.
  /// {@endtemplate}
  final VoidCallback? onPressed;

  /// {@template MenuItem.onTapDown}
  /// The callback called when a pointer down event is detected on the context
  /// menu item. Useful when the action must fire immediately before the
  /// overlay is dismissed (e.g. text selection context menus).
  /// {@endtemplate}
  final ValueChanged<TapDownDetails>? onTapDown;

  /// Overrides of the theme's `ContextMenuTheme` for this row: its
  /// padding, height, decoration, colours, text styles and the anchor and
  /// delay of its submenu. It is merged over the theme, so only the fields
  /// that are set change anything; the fields about the menu itself
  /// (`constraints`, `subMenuPadding`) apply to this row's submenu.
  final ContextMenuTheme? style;

  /// {@template MenuItem.closeOnTap}
  /// Whether the context menu should be closed when the item is tapped,
  /// defaults to `true` when [items] is empty, otherwise `false`.
  /// {@endtemplate}
  final bool? closeOnTap;

  /// {@template MenuItem.items}
  /// The submenu items of the context menu item.
  /// {@endtemplate}
  final List<Widget> items;

  /// {@template MenuItem.destructive}
  /// Whether this is a destructive action, shadcn's
  /// `data-[variant=destructive]`: the label and icons take the destructive
  /// colour and the hover highlight becomes a destructive wash.
  /// {@endtemplate}
  final bool destructive;

  /// {@template MenuItem.shortcut}
  /// The keyboard shortcut shown at the end of the row, before [trailing].
  ///
  /// It is only displayed: binding the keys is the app's job.
  /// {@endtemplate}
  final MenuShortcut? shortcut;

  /// {@template MenuItem.value}
  /// What [showMenu] completes with when this item is chosen.
  ///
  /// It is read when the item closes its menu (see [closeOnTap]). A menu
  /// that was not shown with [showMenu] ignores it.
  /// {@endtemplate}
  final Object? value;

  @override
  State<MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<MenuItem> {
  final itemKey = UniqueKey();
  late final controller = _MenuItemController(itemKey: itemKey);

  /// Shared with the item's button so the trailing widget and text colours
  /// can follow the button's own hover state — a leaf item is only ever
  /// hovered, never "selected", so selection alone cannot drive them.
  final statesController = WidgetStatesController();
  // get the parent item controller, if any, meaning this item is a submenu
  late final parentItemController = context.maybeRead<_MenuItemController>();

  bool get hasTrailingIcon => widget.items.isNotEmpty;

  /// Pending un-hover of an item with a submenu, so the pointer can cross the
  /// gap to the submenu without closing it.
  Timer? _unhoverTimer;

  /// Ends the grace period now: drops the highlight and closes the submenu,
  /// including any nested submenu still in its own grace period.
  void _unhoverNow() {
    _unhoverTimer?.cancel();
    _unhoverTimer = null;
    controller.clearHovered();
  }

  /// Whether this row's submenu was closed with Escape. It stays shut,
  /// though the row is still highlighted, until the pointer or the focus
  /// has left the row, or the arrow key that leads into it asks for it
  /// again: one press of Escape closes one layer, and it would not be
  /// closed if the row it returns the focus to opened it straight away.
  bool _submenuDismissed = false;

  void _onSubmenuDismissed() {
    if (!mounted || _submenuDismissed) return;
    setState(() => _submenuDismissed = true);
  }

  /// The row is done with: the next time it is reached its submenu opens.
  void _onSelectionChanged() {
    if (_submenuDismissed && !controller.hovered && !controller.focused) {
      setState(() => _submenuDismissed = false);
    }
  }

  /// The arrow that leads into the submenu opens it again.
  KeyEventResult _onRowKey(FocusNode node, KeyEvent event) {
    if (!_submenuDismissed || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final towards = Directionality.of(context) == TextDirection.ltr
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    if (event.logicalKey != towards) return KeyEventResult.ignored;
    setState(() => _submenuDismissed = false);
    return KeyEventResult.handled;
  }

  bool _buttonHovered = false;

  /// Tells the menu level when the pointer reaches this row, so the row it
  /// came from lets go at once. The button's own hover is used because leaf
  /// rows have no hover area of their own.
  void _onStatesChanged() {
    final hovered = statesController.value.contains(WidgetState.hovered);
    if (hovered == _buttonHovered) return;
    _buttonHovered = hovered;
    if (hovered) {
      context.getInheritedWidgetOfExactType<_MenuLevel>()?.menu._itemHovered(
        this,
      );
    }
  }

  void _onHoverArea(bool hovered, Duration grace) {
    if (hovered || grace == Duration.zero) {
      _unhoverTimer?.cancel();
      _unhoverTimer = null;
      controller.setHovered(hovered);
      return;
    }
    // The mouse area reports an exit on every pointer event outside it, not
    // once. Restarting the timer on each would keep the item highlighted,
    // and its submenu open, for as long as the pointer moves.
    if (!controller.hovered || (_unhoverTimer?.isActive ?? false)) return;
    _unhoverTimer = Timer(grace, () {
      if (mounted) controller.setHovered(false);
    });
  }

  /// The menu level this row told that it is checkable.
  _ContextMenuState? _registeredWith;

  @override
  void initState() {
    super.initState();
    statesController.addListener(_onStatesChanged);
    controller.addListener(_onSelectionChanged);
    // register the subitem controller if this item is a submenu
    parentItemController?.registerSubItem(controller);
    if (context.getInheritedWidgetOfExactType<_MenuCheckable>() != null) {
      _registeredWith = context
          .getInheritedWidgetOfExactType<_MenuLevel>()
          ?.menu;
      _registeredWith?._checkableMounted();
    }
  }

  /// Whether the row is showing that it was chosen: its highlight blinks
  /// off and on again, as a macOS menu's does, before the menu closes.
  bool _confirming = false;

  /// Whether the highlight is in the off half of the blink.
  bool _blinkOff = false;

  Timer? _confirmTimer;

  /// The root menu told that this row is confirming.
  _ContextMenuState? _confirmRoot;

  /// What the row does once its blink is over: its callback, and closing
  /// the menu.
  VoidCallback? _pendingAction;

  /// Shows that the row was chosen, then runs [action]: the highlight goes
  /// off for a moment and comes back, and only then does the menu close and
  /// the row's callback run, so the choice is seen to be made. It takes
  /// `Motion.fast`, and nothing under `Motion.none`.
  void _confirm(_ContextMenuState contextMenu, VoidCallback action) {
    final root = contextMenu._root ?? contextMenu;
    if (root._confirming != null) return;
    final duration = Motion.of(context).fast;
    if (duration <= Duration.zero) {
      action();
      return;
    }
    root._confirming = this;
    _confirmRoot = root;
    _pendingAction = action;
    setState(() {
      _confirming = true;
      _blinkOff = true;
    });
    _confirmTimer = Timer(duration * .4, () {
      if (!mounted) return;
      setState(() => _blinkOff = false);
      _confirmTimer = Timer(duration * .6, () {
        if (!mounted) return;
        _finishConfirm(root);
      });
    });
  }

  void _finishConfirm(_ContextMenuState root) {
    final action = _pendingAction;
    _pendingAction = null;
    _confirmTimer?.cancel();
    _confirmTimer = null;
    if (identical(root._confirming, this)) root._confirming = null;
    _confirmRoot = null;
    if (mounted && _confirming) {
      setState(() {
        _confirming = false;
        _blinkOff = false;
      });
    }
    action?.call();
  }

  /// Closes the whole menu after this row was chosen, handing its value to
  /// [showMenu] when that is what opened the menu.
  void _close(_ContextMenuState contextMenu) {
    context.getInheritedWidgetOfExactType<_MenuResult>()?.holder.value =
        widget.value;
    contextMenu.setOpen(false);
  }

  @override
  void dispose() {
    _unhoverTimer?.cancel();
    _confirmTimer?.cancel();
    // A row taken away while it shows its choice still makes it: the
    // callback runs once the tree is done being torn down.
    final pending = _pendingAction;
    if (pending != null) {
      _pendingAction = null;
      final root = _confirmRoot;
      if (root != null && identical(root._confirming, this)) {
        root._confirming = null;
      }
      scheduleMicrotask(() {
        widget.onPressed?.call();
      });
    }
    final registeredWith = _registeredWith;
    if (registeredWith != null && registeredWith.mounted) {
      registeredWith._checkableUnmounted();
    }
    parentItemController?.unregisterSubItem(controller);
    controller.dispose();
    statesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menuTheme = theme.contextMenuTheme.merge(widget.style);

    final contextMenu = context.read<_ContextMenuState>();

    // Set by `MenuCheckboxItem` and `MenuRadioItem` around their row.
    final checkable = context
        .dependOnInheritedWidgetOfExactType<_MenuCheckable>();
    final indicatorColumn =
        checkable != null ||
        (context
                .dependOnInheritedWidgetOfExactType<_MenuLevel>()
                ?.indicatorColumn ??
            false);
    final effectiveIndicatorSize = _menuIndicatorSize(context, theme);

    final effectivePadding =
        menuTheme.itemPadding ?? const EdgeInsets.symmetric(horizontal: 4);

    // The row's own horizontal padding (`px-2`), from the style tokens so a
    // denser or roomier style moves it. An inset row reserves shadcn's
    // `pl-8`-style gutter: the base padding plus a 24px icon column.
    final itemPaddingX = theme.style.itemPaddingX * theme.spacing.step / 4;
    final defaultInsetPadding = switch (widget.variant) {
      MenuItemVariant.primary => EdgeInsets.symmetric(
        horizontal: itemPaddingX,
      ),
      MenuItemVariant.inset => EdgeInsetsDirectional.only(
        start: itemPaddingX + 24,
        end: itemPaddingX,
      ),
    };

    final effectiveInsetPadding = menuTheme.insetPadding ?? defaultInsetPadding;

    final effectiveLeadingPadding =
        menuTheme.leadingPadding ?? const EdgeInsetsDirectional.only(end: 8);

    final effectiveTrailingPadding =
        menuTheme.trailingPadding ?? const EdgeInsetsDirectional.only(start: 8);

    // A submenu opens beside its item and flips to the other side when it
    // would cross the screen edge, instead of sliding over its parent.
    final submenuOffsetY = parentItemController != null ? -5.0 : -3.0;
    final effectiveAnchor =
        menuTheme.anchor ??
        AnchorAuto(
          offset: Offset(-8, submenuOffsetY),
          targetAnchor: Alignment.topRight,
          followerAnchor: Alignment.bottomRight,
          fallback: AnchorAuto(
            offset: Offset(8, submenuOffsetY),
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
          ),
        );

    final effectiveHeight = menuTheme.height ?? 32;

    final effectiveShowDelay =
        menuTheme.showDelay ?? const Duration(milliseconds: 100);

    final effectiveButtonVariant =
        menuTheme.buttonVariant ?? ButtonVariant.ghost;

    final effectiveDecoration = MenuEdge.round(
      context,
      const UnaDecoration(
        secondaryBorder: UnaBorder.none,
        secondaryFocusedBorder: UnaBorder.none,
      ).merge(menuTheme.itemDecoration),
      menu: menuTheme.decoration,
      inset: menuTheme.padding?.resolve(Directionality.of(context)).top ?? 4,
    );

    // Menu rows draw their colours from the menu palette slots. shadcn's
    // states, per `cn-dropdown-menu-item`: rest is the popover foreground,
    // hover/open is `bg-accent text-accent-foreground` with every descendant
    // (icons included) following, and a destructive row keeps its destructive
    // text over a `destructive/10` wash (`/20` in dark).
    final effectiveTextStyle =
        (menuTheme.textStyle ??
                theme.textTheme.small.copyWith(fontWeight: FontWeight.normal))
            .fallback(color: theme.colorScheme.popoverForeground);

    final effectiveSelectedTextStyle =
        (menuTheme.selectedTextStyle ?? effectiveTextStyle).fallback(
          color: theme.colorScheme.accentForeground,
        );

    final effectiveTrailingTextStyle =
        (menuTheme.trailingTextStyle ??
                theme.textTheme.muted.copyWith(
                  fontSize: 12,
                  height: 1,
                ))
            .fallback(color: theme.colorScheme.mutedForeground);

    final effectiveSelectedTrailingTextStyle =
        menuTheme.selectedTrailingTextStyle ??
        effectiveTrailingTextStyle.copyWith(
          color: effectiveSelectedTextStyle.color,
        );

    // The shortcut is trailing text with the style's own spacing; its
    // colour is the trailing style's for the row's state.
    final effectiveShortcutTextStyle =
        menuTheme.shortcutTextStyle ?? effectiveTrailingTextStyle;

    final effectiveBackgroundColor = menuTheme.backgroundColor;

    var effectiveSelectedBackgroundColor =
        menuTheme.selectedBackgroundColor ?? theme.colorScheme.accent;

    var foregroundColor = effectiveTextStyle.color!;
    var selectedForegroundColor = effectiveSelectedTextStyle.color!;

    if (widget.destructive) {
      final destructive =
          menuTheme.destructiveForegroundColor ?? theme.colorScheme.destructive;
      foregroundColor = destructive;
      selectedForegroundColor = destructive;
      effectiveSelectedBackgroundColor =
          menuTheme.destructiveSelectedBackgroundColor ??
          destructive.withValues(
            alpha:
                destructive.a * (theme.brightness == Brightness.dark ? .2 : .1),
          );
    }

    final effectiveCloseOnTap =
        widget.closeOnTap ?? menuTheme.closeOnTap ?? widget.items.isEmpty;

    /// if the item has submenu items, use the current item key,
    /// otherwise use the parent item controller's item key
    /// or the current item key if there is no parent item
    final effectiveGroupId = widget.items.isNotEmpty
        ? itemKey
        : parentItemController?.itemKey ?? itemKey;

    Widget child = ListenableBuilder(
      listenable: Listenable.merge([controller, statesController]),
      builder: (context, _) {
        // While the row shows that it was chosen, its highlight is the
        // blink's and nothing else's.
        final hovered = _confirming
            ? !_blinkOff
            : statesController.value.contains(WidgetState.hovered);
        final selected = _confirming ? !_blinkOff : controller.selected;
        // Rest vs highlight, resolved here because a leaf item's hover lives
        // in the button's own states — selection alone cannot see it.
        final highlighted = selected || hovered;

        return ContextMenu.internal(
          open: controller.selected && !_submenuDismissed,
          onDismissed: _onSubmenuDismissed,
          anchor: effectiveAnchor,
          constraints: widget.style?.constraints,
          padding: menuTheme.subMenuPadding,
          areaGroupId: effectiveGroupId,
          onHoverArea: (hovered) => _onHoverArea(hovered, effectiveShowDelay),
          items: widget.items,
          child: Padding(
            padding: effectivePadding,
            child: _CheckableSemantics(
              checkable: checkable,
              // A row with a submenu says whether it is open.
              expanded: widget.items.isEmpty
                  ? null
                  : controller.selected && !_submenuDismissed,
              child: Button(
                enabled: widget.enabled,
                variant: effectiveButtonVariant,
                statesController: statesController,
                style: ButtonTheme(
                  pressScale: 1,
                  height: effectiveHeight,
                  decoration: effectiveDecoration,
                  width: double.infinity,
                  padding: effectiveInsetPadding,
                  backgroundColor: selected
                      ? effectiveSelectedBackgroundColor
                      : effectiveBackgroundColor,
                  hoverBackgroundColor: _confirming && _blinkOff
                      ? effectiveBackgroundColor
                      : effectiveSelectedBackgroundColor,
                  // Through the button rather than a wrapping
                  // DefaultTextStyle, so its IconTheme recolours leading and
                  // trailing icons with the text — shadcn's
                  // `focus:**:text-accent-foreground`.
                  foregroundColor: selected
                      ? selectedForegroundColor
                      : foregroundColor,
                  hoverForegroundColor: _confirming && _blinkOff
                      ? foregroundColor
                      : selectedForegroundColor,
                  // A menu's highlight follows the pointer and the arrow
                  // keys row by row: it is there or it is not, with no fade
                  // and no glide between rows.
                  transitionDuration: Duration.zero,
                  textStyle: highlighted
                      ? effectiveSelectedTextStyle
                      : effectiveTextStyle,
                ),
                onFocusChange: controller.setFocused,
                onPressed: () {
                  // Space on a checkable row toggles it and leaves the menu
                  // open, so several can be set in one visit; Enter and a
                  // click do what the row's `closeOnTap` says. The button
                  // binds both keys to this callback, so the key is asked.
                  final stays =
                      checkable != null &&
                      HardwareKeyboard.instance.isLogicalKeyPressed(
                        LogicalKeyboardKey.space,
                      );
                  if (!effectiveCloseOnTap || stays) {
                    widget.onPressed?.call();
                    return;
                  }
                  // A row that closes the menu shows the choice first.
                  _confirm(contextMenu, () {
                    widget.onPressed?.call();
                    if (mounted) _close(contextMenu);
                  });
                },
                child: Expanded(
                  child: Row(
                    children: [
                      if (indicatorColumn)
                        Padding(
                          padding: effectiveLeadingPadding,
                          child: SizedBox.square(
                            dimension: effectiveIndicatorSize,
                            child: checkable == null
                                ? null
                                : _MenuIndicator(
                                    checked: checkable.checked,
                                    radio: checkable.radio,
                                    size: effectiveIndicatorSize,
                                  ),
                          ),
                        ),
                      if (widget.leading != null)
                        Padding(
                          padding: effectiveLeadingPadding,
                          child: widget.leading,
                        ),
                      // The button centres its text (`TextAlign.center` in its
                      // DefaultTextStyle); a menu row is start-aligned.
                      Expanded(
                        child: DefaultTextStyle.merge(
                          textAlign: TextAlign.start,
                          child: widget.child,
                        ),
                      ),
                      if (widget.shortcut != null)
                        Padding(
                          padding: effectiveTrailingPadding,
                          child: DefaultTextStyle(
                            style: effectiveShortcutTextStyle.copyWith(
                              color: highlighted
                                  ? effectiveSelectedTrailingTextStyle.color
                                  : effectiveTrailingTextStyle.color,
                            ),
                            child: widget.shortcut!,
                          ),
                        ),
                      if (widget.trailing != null)
                        Padding(
                          padding: effectiveTrailingPadding,
                          child: DefaultTextStyle(
                            style: highlighted
                                ? effectiveSelectedTrailingTextStyle
                                : effectiveTrailingTextStyle,
                            child: widget.trailing!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (widget.items.isNotEmpty) {
      // Above the row's own focus, so it hears the key the row has no use
      // for.
      child = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onRowKey,
        child: child,
      );
    }

    final itemConstraints = menuTheme.itemConstraints;
    if (itemConstraints != null) {
      child = ConstrainedBox(constraints: itemConstraints, child: child);
    }

    // On the way down, before anything else hears of the press: the row's
    // own tap comes on the way up, and by then a press that is also a tap
    // outside what the menu belongs to has taken the menu away.
    final onTapDown = widget.onTapDown;
    if (onTapDown != null && widget.enabled) {
      child = Listener(
        onPointerDown: (event) {
          if (event.buttons != kPrimaryButton) return;
          onTapDown(
            TapDownDetails(
              globalPosition: event.position,
              localPosition: event.localPosition,
              kind: event.kind,
            ),
          );
          if (effectiveCloseOnTap) _close(contextMenu);
        },
        child: child,
      );
    }

    // if the item has at least one submenu item, wrap it in a provider to
    //provide the controller to the submenu items
    if (widget.items.isNotEmpty) {
      child = Provider(
        data: controller,
        child: child,
      );
    }

    return child;
  }
}

/// Marks the items built by one menu level, so a menu can tell its own items
/// from those of a submenu below it.
class _MenuLevel extends InheritedWidget {
  const _MenuLevel({
    required this.menu,
    required this.indicatorColumn,
    required super.child,
  });

  final _ContextMenuState menu;

  /// Whether a row of this level is checkable. Every row then keeps the
  /// column of the check marks free, so the labels line up.
  final bool indicatorColumn;

  @override
  bool updateShouldNotify(_MenuLevel oldWidget) =>
      menu != oldWidget.menu || indicatorColumn != oldWidget.indicatorColumn;
}

/// Marks the first and the last row of a menu, so that their highlight
/// follows the menu's own corners.
///
/// A row's highlight is rounded to the item radius, which sits well inside
/// a menu with large corners (a phone's, 24): at the top and bottom of the
/// menu its corners stood square against the curve. The rows at the ends
/// round their outer corners concentrically instead — the menu's radius
/// less the padding between them.
@internal
class MenuEdge extends InheritedWidget {
  /// Marks [child] as at the [top] or the [bottom] of its menu, or both.
  const MenuEdge({
    required this.top,
    required this.bottom,
    required super.child,
    super.key,
  });

  /// Whether the row is the first of its menu.
  final bool top;

  /// Whether the row is the last of its menu.
  final bool bottom;

  /// [items] with the first and the last marked, and every other one
  /// marked as at neither edge, so a row inside a group among them (a
  /// [MenuRadioGroup]) does not take the edge of the group's own mark.
  ///
  /// [top] and [bottom] say whether the list itself is at that edge of its
  /// menu: a group marks its rows with its own place, from [of].
  static List<Widget> mark(
    List<Widget> items, {
    bool top = true,
    bool bottom = true,
  }) => [
    for (final (i, item) in items.indexed)
      MenuEdge(
        // The item's own key, so keyed rows keep their state as they move.
        key: item.key == null ? null : ValueKey(item.key),
        top: top && i == 0,
        bottom: bottom && i == items.length - 1,
        child: item,
      ),
  ];

  /// The edges of its menu that [context] is at, or null outside a marked
  /// list.
  static ({bool top, bool bottom})? of(BuildContext context) {
    final edge = context.dependOnInheritedWidgetOfExactType<MenuEdge>();
    return edge == null ? null : (top: edge.top, bottom: edge.bottom);
  }

  /// [decoration], a row's, with the corners it has at an edge of its menu
  /// rounded to [menu]'s radius less [inset].
  static UnaDecoration round(
    BuildContext context,
    UnaDecoration decoration, {
    required UnaDecoration? menu,
    required double inset,
  }) {
    final border = decoration.border;
    if (border == null) return decoration;
    final direction = Directionality.of(context);
    final own = (border.borderRadius ?? BorderRadius.zero).resolve(direction);
    final rounded = roundRadius(
      context,
      own,
      menu: menu?.border?.borderRadius?.resolve(direction),
      inset: inset,
    );
    if (rounded == own) return decoration;
    return decoration.copyWith(border: border.copyWith(borderRadius: rounded));
  }

  /// [own], a row's corners, with those at an edge of its menu rounded to
  /// [menu] less [inset]: the menu's curve, carried in by the padding.
  static BorderRadius roundRadius(
    BuildContext context,
    BorderRadius own, {
    required BorderRadius? menu,
    required double inset,
  }) {
    final edge = context.dependOnInheritedWidgetOfExactType<MenuEdge>();
    if (edge == null || menu == null || !(edge.top || edge.bottom)) {
      return own;
    }
    Radius inner(Radius r, Radius current) => Radius.elliptical(
      math.max(current.x, r.x - inset),
      math.max(current.y, r.y - inset),
    );
    return own.copyWith(
      topLeft: edge.top ? inner(menu.topLeft, own.topLeft) : null,
      topRight: edge.top ? inner(menu.topRight, own.topRight) : null,
      bottomLeft: edge.bottom ? inner(menu.bottomLeft, own.bottomLeft) : null,
      bottomRight: edge.bottom
          ? inner(menu.bottomRight, own.bottomRight)
          : null,
    );
  }

  @override
  bool updateShouldNotify(MenuEdge oldWidget) =>
      top != oldWidget.top || bottom != oldWidget.bottom;
}

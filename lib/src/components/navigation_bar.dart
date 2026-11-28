import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/components/bottom_bar_surface.dart';
import 'package:una/src/components/indicator_badge.dart';
import 'package:una/src/i18n/localizations_delegate.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/liquid_glass/tab_bar.dart';
import 'package:una/src/raw_components/pressable.dart';
import 'package:una/src/theme/components/bottom_navigation_bar.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/motion_color.dart';
import 'package:una/src/utils/moving_indicator.dart';
import 'package:una/src/utils/spring.dart';

/// One place a [NavigationBar], a [BottomNavigationBar] or a
/// rail of a `NavigationScaffold` can take the user.
@immutable
class NavigationDestination {
  /// Creates a destination.
  const NavigationDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badgeCount,
    this.showBadge = false,
    this.showInTopBar = true,
    this.showInBottomBar = true,
    this.showInRail,
  });

  /// The icon, usually an [Icon]. Any widget works — a bottom bar's "me"
  /// destination is often an avatar.
  final Widget icon;

  /// The icon while the destination is selected, usually the filled version
  /// of [icon]. Defaults to [icon].
  final Widget? selectedIcon;

  /// The destination's name. A top bar and a rail show it with the icon; a
  /// bottom bar reads it to assistive technology unless it shows labels.
  final String label;

  /// A count shown as a badge on the icon; null or zero shows none.
  final int? badgeCount;

  /// Whether to show a dot badge when there is no [badgeCount].
  final bool showBadge;

  /// Whether a `NavigationScaffold` lists the destination in its top bar.
  final bool showInTopBar;

  /// Whether a `NavigationScaffold` lists the destination in its bottom bar.
  final bool showInBottomBar;

  /// Whether a `NavigationScaffold` lists the destination in its rail.
  /// Defaults to [showInTopBar]: a rail is the top bar's destinations down
  /// the side.
  final bool? showInRail;
}

/// The primary action in the middle of a [BottomNavigationBar] or at the
/// top of a `NavigationScaffold`'s rail: compose, create, scan.
@immutable
class NavigationAction {
  /// Creates an action.
  const NavigationAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// The action's icon.
  final Widget icon;

  /// The action's name, read to assistive technology.
  final String label;

  /// Called when the action is tapped.
  final VoidCallback? onPressed;
}

/// [icon] with [destination]'s badge on its corner. Shared by the
/// navigation bars and the rail; not exported.
Widget badgedDestinationIcon(
  NavigationDestination destination,
  Widget icon,
  Offset offset,
) {
  final count = destination.badgeCount ?? 0;
  // The badge stays in the tree while it has nothing to show, so it pops
  // in when the first notification arrives and out when the last is read.
  return IndicatorBadge(
    count: count > 0 || !destination.showBadge ? count : null,
    visible: count > 0 || destination.showBadge,
    offset: offset,
    child: icon,
  );
}

/// A destination's icon, changing from [icon] to [selectedIcon] — usually
/// from the regular weight to the filled one — as a cross-fade with a small
/// pop, and in [color], which fades.
///
/// Both icons are in the tree only while one fades into the other; at rest
/// there is the one that shows. They are keyed, so the one that stays keeps
/// its state — an avatar does not reload — when the other comes or goes.
/// Deselecting only fades: the pop belongs to the destination the user
/// chose.
///
/// Shared by the navigation bars and the rail; not exported.
class DestinationIcon extends StatelessWidget {
  /// Creates a destination's icon.
  const DestinationIcon({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.color,
    required this.size,
    super.key,
  });

  /// Whether the destination is the selected one.
  final bool selected;

  /// The icon at rest.
  final Widget icon;

  /// The icon while selected; [icon] when null.
  final Widget? selectedIcon;

  /// The icon's colour, which fades when it changes.
  final Color color;

  /// The icon's size.
  final double size;

  static const _restKey = ValueKey('rest');
  static const _selectedKey = ValueKey('selected');

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    // How far the icon grows at the top of the pop: four times the press
    // shrink, so a style with a calmer press pops less and reduced motion
    // not at all.
    final pop = (1 - motion.pressScale) * 4;
    final filled = selectedIcon;
    return AnimatedColorBuilder(
      color: color,
      duration: motion.fast,
      curve: motion.standard,
      builder: (context, color, child) => IconTheme.merge(
        data: IconThemeData(size: size, color: color),
        child: child!,
      ),
      child: SpringBuilder(
        value: selected ? 1 : 0,
        spring: selected ? motion.bouncy : motion.snappy,
        builder: (context, value, _) {
          final t = value.clamp(0.0, 1.0);
          // Up and back over the course of the change, and only on the way
          // in: 4t(1 − t) is 0 at both ends and 1 half-way.
          final scale = selected ? 1 + pop * 4 * t * (1 - t) : 1.0;
          return Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (filled == null || t < 1)
                  KeyedSubtree(
                    key: _restKey,
                    child: Opacity(
                      opacity: filled == null ? 1 : 1 - t,
                      child: icon,
                    ),
                  ),
                if (filled != null && t > 0)
                  KeyedSubtree(
                    key: _selectedKey,
                    child: Opacity(opacity: t, child: filled),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A row of destinations for the top of a wide screen: an icon over a label,
/// with a bar under the selected one.
///
/// ```dart
/// NavigationBar(
///   selectedIndex: index,
///   onDestinationSelected: (i) => setState(() => index = i),
///   destinations: const [
///     NavigationDestination(
///       icon: PhosphorIcon(PhosphorIconsRegular.house),
///       selectedIcon: PhosphorIcon(PhosphorIconsFill.house),
///       label: 'Home',
///     ),
///     NavigationDestination(
///       icon: PhosphorIcon(PhosphorIconsRegular.chatCircleDots),
///       label: 'Messages',
///       badgeCount: 3,
///     ),
///   ],
/// )
/// ```
///
/// It is meant for an `AppBar`'s `middle` and fills the bar's height, so the
/// selection indicator sits on the bar's bottom edge. On a phone use a
/// [BottomNavigationBar]; a `NavigationScaffold` switches between the two.
class NavigationBar extends StatelessWidget {
  /// Creates a top navigation bar.
  const NavigationBar({
    required this.destinations,
    required this.selectedIndex,
    this.onDestinationSelected,
    this.height,
    this.semanticLabel,
    super.key,
  });

  /// The destinations, in order.
  final List<NavigationDestination> destinations;

  /// The index of the selected destination, or null or out of range for
  /// none.
  final int? selectedIndex;

  /// Called with the index of the destination that was tapped.
  final ValueChanged<int>? onDestinationSelected;

  /// The bar's height. Defaults to the app bar's.
  final double? height;

  /// {@template NavigationBar.semanticLabel}
  /// The name assistive technology gives the bar's navigation landmark.
  /// Defaults to the localised "Main navigation"; pass another when a
  /// screen has more than one.
  /// {@endtemplate}
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nav = theme.navigationBarTheme;
    final motion = Motion.of(context);
    final barHeight = height ?? theme.appBarTheme.height ?? 64;
    final inset = nav.indicatorInset ?? 12;
    final indicatorHeight = nav.indicatorHeight ?? 3;
    final indicator = BoxDecoration(
      color: nav.indicatorColor ?? theme.colorScheme.tint,
      borderRadius: BorderRadius.circular(indicatorHeight),
    );

    Widget item(int index, NavigationDestination destination) {
      final selected = index == selectedIndex;
      return SizedBox(
        width: nav.itemWidth ?? 88,
        height: barHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Pressable(
                selected: selected,
                onPressed: onDestinationSelected == null
                    ? null
                    : () => onDestinationSelected!(index),
                builder: (context, states) {
                  final hovered = states.contains(WidgetState.hovered);
                  final rest =
                      nav.foregroundColor ?? theme.colorScheme.mutedForeground;
                  final iconColor = selected
                      ? nav.selectedIconColor ?? theme.colorScheme.tint
                      : hovered
                      ? nav.hoverColor ?? theme.colorScheme.foreground
                      : rest;
                  final labelColor = selected
                      ? nav.selectedLabelColor ?? theme.colorScheme.foreground
                      : hovered
                      ? nav.hoverColor ?? theme.colorScheme.foreground
                      : rest;
                  final labelStyle = nav.labelStyle ?? theme.textTheme.small;
                  return FocusRing(
                    visible: states.contains(WidgetState.focused),
                    borderRadius: theme.radius,
                    // The app bar clips for its backdrop blur, which would
                    // cut an outside ring off at the top and bottom.
                    inset: true,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: nav.gap ?? 4,
                        children: [
                          badgedDestinationIcon(
                            destination,
                            DestinationIcon(
                              selected: selected,
                              icon: destination.icon,
                              selectedIcon: destination.selectedIcon,
                              color: iconColor,
                              size: nav.iconSize ?? 24,
                            ),
                            const Offset(4, 0),
                          ),
                          AnimatedColorBuilder(
                            color: labelColor,
                            duration: motion.fast,
                            curve: motion.standard,
                            builder: (context, color, _) => Text(
                              destination.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: labelStyle.copyWith(color: color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Where the bar under the destinations goes when this one is
            // selected. It is painted once, by the row, and travels. Outside
            // the pressable, so a press does not shrink its end of the bar.
            PositionedDirectional(
              start: inset,
              end: inset,
              // Over the app bar's own hairline.
              bottom: -1,
              height: indicatorHeight,
              child: IgnorePointer(
                child: MovingIndicatorTarget(
                  selected: selected,
                  decoration: indicator,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.navigation,
      label: semanticLabel ?? UnaLocalizations.of(context).navigation.main,
      child: SizedBox(
        height: barHeight,
        // In front of the destinations, so the bar also covers the app
        // bar's hairline.
        child: MovingIndicator(
          position: DecorationPosition.foreground,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, destination) in destinations.indexed)
                item(index, destination),
            ],
          ),
        ),
      ),
    );
  }
}

/// The destinations at the bottom of a phone screen, with an optional
/// primary [action] in the middle.
///
/// ```dart
/// BottomNavigationBar(
///   selectedIndex: index,
///   onDestinationSelected: (i) => setState(() => index = i),
///   action: NavigationAction(
///     icon: const PhosphorIcon(PhosphorIconsRegular.plus),
///     label: 'Create post',
///     onPressed: _compose,
///   ),
///   destinations: destinations,
/// )
/// ```
///
/// In a style whose bottom bar floats — Una's default — it is a glass
/// pill hovering above the page, as wide as its destinations; otherwise it
/// spans the bottom edge and shares the width between them. Either way it
/// respects the bottom safe area. Put it in a `Scaffold` so the page scrolls
/// beneath it.
class BottomNavigationBar extends StatelessWidget {
  /// Creates a bottom navigation bar.
  const BottomNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    this.onDestinationSelected,
    this.action,
    this.actionPlacement,
    this.floating,
    this.showLabels,
    this.semanticLabel,
    super.key,
  });

  /// The destinations, in order.
  final List<NavigationDestination> destinations;

  /// The index of the selected destination, or null or out of range for
  /// none.
  final int? selectedIndex;

  /// Called with the index of the destination that was tapped.
  final ValueChanged<int>? onDestinationSelected;

  /// A primary action shown between the two halves of [destinations], or
  /// beside the bar (see [actionPlacement]).
  final NavigationAction? action;

  /// Where [action] goes: between the destinations, or on a disc of its own
  /// at the end of a floating bar, as on Liquid Glass. Defaults to the
  /// theme's, which is between. On Liquid Glass it is always detached.
  final NavigationActionPlacement? actionPlacement;

  /// Whether the bar floats as a pill. Defaults to the theme's.
  final bool? floating;

  /// Whether each destination shows its label under its icon. Defaults to
  /// the theme's, which is icons only. A bar with labels is as much
  /// taller as a line of the label.
  final bool? showLabels;

  /// {@macro NavigationBar.semanticLabel}
  final String? semanticLabel;

  /// How much taller a bar with labels is than one without, in [context]:
  /// the gap under the icon and one line of the label.
  static double _labelExtent(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        theme.bottomNavigationBarTheme.labelStyle ?? theme.textTheme.caption;
    return _labelGap +
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 12) *
            (style.height ?? 1.2) +
        _labelGap;
  }

  static const _labelGap = 2.0;

  /// The height a [BottomNavigationBar] takes in [context], including its
  /// margin and the bottom safe area. A `Scaffold` uses it to inset its body.
  static double heightOf(BuildContext context) {
    final bar = Theme.of(context).bottomNavigationBarTheme;
    return (bar.itemHeight ?? 48) +
        ((bar.showLabels ?? false) ? _labelExtent(context) : 0) +
        BottomBarSurface.extentAround(
          context,
          floating: BottomBarSurface.floatsIn(context),
        );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    // One landmark, on Liquid Glass or not.
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.navigation,
    label: semanticLabel ?? UnaLocalizations.of(context).navigation.main,
    child: LayoutBuilder(
      builder: (context, constraints) => _build(context, constraints.maxWidth),
    ),
  );

  Widget _build(BuildContext context, double maxWidth) {
    final theme = Theme.of(context);
    final bar = theme.bottomNavigationBarTheme;
    final isFloating = floating ?? bar.floating ?? true;
    final barPadding = (bar.padding ?? const EdgeInsets.all(6)).resolve(
      Directionality.of(context),
    );
    final gap = bar.gap ?? 4;
    final selected = selectedIndex;
    if (isFloating && LiquidGlass.isActive(context, bar.liquidGlass)) {
      // A screen that is none of the destinations (a page reached from
      // the app bar) keeps the same bar, with no lens on any tab.
      final valid =
          selected != null && selected >= 0 && selected < destinations.length;
      return _buildLiquid(context, valid ? selected : null, barPadding);
    }
    // A floating bar is as wide as its items, but never wider than the
    // screen: on a narrow phone the items give up width evenly rather than
    // overflow.
    final detached =
        isFloating &&
        action != null &&
        (actionPlacement ?? bar.actionPlacement) ==
            NavigationActionPlacement.detached;
    // A detached action is as wide as it is tall, on a disc of its own.
    final itemHeight = bar.itemHeight ?? 48;
    final discWidth = itemHeight + barPadding.horizontal + 2;
    final itemCount =
        destinations.length + (action == null || detached ? 0 : 1);
    final labeled = showLabels ?? bar.showLabels ?? false;
    final baseWidth = bar.itemWidth ?? 52;
    var itemWidth = labeled
        ? bar.labeledItemWidth ?? (baseWidth + 16)
        : baseWidth;
    final labelStyle = bar.labelStyle ?? theme.textTheme.caption;
    final motion = Motion.of(context);
    if (isFloating && maxWidth.isFinite && itemCount > 0) {
      const sideMargin = 16.0;
      final available =
          maxWidth -
          2 * sideMargin -
          barPadding.horizontal -
          2 -
          gap * (itemCount - 1) -
          // The disc, and at least a gap between it and the bar.
          (detached ? discWidth + 2 * gap : 0);
      final fit = available / itemCount;
      if (fit < itemWidth) itemWidth = fit < 0 ? 0 : fit;
    }
    final itemRadius = isFloating ? theme.radii.full : theme.radii.lg;
    // On a floating bar the lens and the hover wash take in the label as
    // well, as the Liquid Glass bar's lens does: a pill behind the icon
    // alone, with the label hanging under it, read as two things. A
    // docked bar keeps Material's pill behind the icon.
    final wholeItem = labeled && isFloating;

    // The lens: one pill behind the selected destination, painted by the
    // row and travelling between them.
    final lens = BoxDecoration(
      color: bar.selectedBackgroundColor ?? theme.colorScheme.accent,
      borderRadius: itemRadius,
    );

    Widget item({
      required Widget Function(Color color, double size) icon,
      required String label,
      required VoidCallback? onPressed,
      required bool? selected,
      String? value,
      Color? background,
      Color? foreground,
      double? iconSize,
      double? width,
    }) {
      final isSelected = selected ?? false;
      Widget child = Pressable(
        selected: selected,
        onPressed: onPressed,
        semanticLabel: label,
        semanticValue: value,
        builder: (context, states) {
          final hovered = states.contains(WidgetState.hovered);
          // The selected destination's fill is the lens behind it; only
          // the hover wash and the action's own fill are painted here. The
          // wash stays on a hovered destination that becomes selected:
          // taking it away while the lens is still on its way would flash
          // the bar's own colour through for a few frames.
          final color =
              background ??
              (hovered ? theme.colorScheme.muted : const Color(0x00000000));
          final ink =
              foreground ??
              (isSelected
                  ? bar.selectedForegroundColor ?? theme.colorScheme.tint
                  : bar.foregroundColor ?? theme.colorScheme.foregroundSubtle);
          // A cross-fade, not `Color.lerp`: from nothing to the wash that
          // one passes through a half-opaque dark grey, which is the flash
          // a tap on a destination used to make.
          Widget filled(Widget child) => AnimatedFill(
            color: color,
            borderRadius: itemRadius,
            child: child,
          );
          final glyph = Center(
            child: ExcludeSemantics(
              child: icon(ink, iconSize ?? bar.iconSize ?? 26),
            ),
          );
          final box = SizedBox(
            width: width ?? (isFloating ? itemWidth : null),
            height: bar.itemHeight ?? 48,
            child: wholeItem && selected != null ? glyph : filled(glyph),
          );
          Widget content = !labeled
              ? box
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: _labelGap,
                  children: [
                    box,
                    // Under the lens, not on it. The action has none: it
                    // is a button, not a place.
                    Container(
                      width: isFloating ? itemWidth : null,
                      // A little air between the label and the bar's
                      // rounded edge.
                      padding: const EdgeInsets.only(bottom: _labelGap),
                      child: AnimatedColorBuilder(
                        color: selected == null ? const Color(0x00000000) : ink,
                        duration: motion.fast,
                        curve: motion.standard,
                        builder: (context, color, _) => Text(
                          selected == null ? '' : label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: labelStyle.copyWith(color: color),
                        ),
                      ),
                    ),
                  ],
                );
          if (wholeItem && selected != null) content = filled(content);
          return FocusRing(
            visible: states.contains(WidgetState.focused),
            borderRadius: itemRadius,
            inset: true,
            child: content,
          );
        },
      );
      if (selected != null) {
        // Outside the pressable, not inside it: a press shrinks the icon,
        // not the lens under it.
        child = labeled && !wholeItem
            ? Stack(
                children: [
                  // Behind the icon only; the label sits below the lens.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: bar.itemHeight ?? 48,
                    child: MovingIndicatorTarget(
                      selected: isSelected,
                      decoration: lens,
                    ),
                  ),
                  child,
                ],
              )
            : MovingIndicatorTarget(
                selected: isSelected,
                decoration: lens,
                child: child,
              );
      }
      return isFloating ? child : Expanded(child: child);
    }

    Widget actionIcon(Color color, double size) => IconTheme.merge(
      data: IconThemeData(size: size, color: color),
      child: action!.icon,
    );

    final actionIndex = (destinations.length / 2).ceil();
    final children = <Widget>[
      for (final (index, destination) in destinations.indexed) ...[
        if (action != null && !detached && index == actionIndex)
          item(
            icon: actionIcon,
            label: action!.label,
            onPressed: action!.onPressed,
            selected: null,
            background: bar.actionBackgroundColor ?? theme.colorScheme.primary,
            foreground:
                bar.actionForegroundColor ??
                theme.colorScheme.primaryForeground,
            iconSize: bar.actionIconSize ?? 22,
          ),
        item(
          icon: (color, size) => badgedDestinationIcon(
            destination,
            DestinationIcon(
              selected: index == selectedIndex,
              icon: destination.icon,
              selectedIcon: destination.selectedIcon,
              color: color,
              size: size,
            ),
            Offset.zero,
          ),
          label: destination.label,
          value: (destination.badgeCount ?? 0) > 0
              ? '${destination.badgeCount}'
              : null,
          onPressed: onDestinationSelected == null
              ? null
              : () => onDestinationSelected!(index),
          selected: index == selectedIndex,
        ),
      ],
      if (action != null && !detached && actionIndex >= destinations.length)
        item(
          icon: actionIcon,
          label: action!.label,
          onPressed: action!.onPressed,
          selected: null,
          background: bar.actionBackgroundColor ?? theme.colorScheme.primary,
          foreground:
              bar.actionForegroundColor ?? theme.colorScheme.primaryForeground,
          iconSize: bar.actionIconSize ?? 22,
        ),
    ];

    return BottomBarSurface(
      floating: isFloating,
      detached: detached
          ? item(
              icon: actionIcon,
              label: action!.label,
              onPressed: action!.onPressed,
              selected: null,
              background:
                  bar.actionBackgroundColor ?? theme.colorScheme.primary,
              foreground:
                  bar.actionForegroundColor ??
                  theme.colorScheme.primaryForeground,
              iconSize: bar.actionIconSize ?? 22,
              width: itemHeight,
            )
          : null,
      child: MovingIndicator(
        child: Row(
          mainAxisSize: isFloating ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: gap,
          children: children,
        ),
      ),
    );
  }
}

extension on BottomNavigationBar {
  /// The bar on Liquid Glass: the package's tab bar, its lens travelling
  /// between the destinations, and the [action] on a capsule of its own
  /// beside them rather than between them.
  Widget _buildLiquid(
    BuildContext context,
    int? selected,
    EdgeInsets barPadding,
  ) {
    final theme = Theme.of(context);
    final bar = theme.bottomNavigationBarTheme;
    final selectedColor = bar.selectedForegroundColor ?? theme.colorScheme.tint;
    final color = bar.foregroundColor ?? theme.colorScheme.foregroundSubtle;
    final iconSize = bar.iconSize ?? 26;
    final margin = (bar.margin ?? const EdgeInsets.only(bottom: 22)).resolve(
      Directionality.of(context),
    );
    Widget icon(NavigationDestination destination, {required bool active}) =>
        badgedDestinationIcon(
          destination,
          DestinationIcon(
            selected: active,
            icon: destination.icon,
            selectedIcon: destination.selectedIcon,
            color: active ? selectedColor : color,
            size: iconSize,
          ),
          Offset.zero,
        );
    final action = this.action;
    return LiquidGlassTabBar(
      tabs: [
        for (final destination in destinations)
          LiquidGlassTab(
            icon: icon(destination, active: false),
            activeIcon: icon(destination, active: true),
            label: destination.label,
          ),
      ],
      selectedIndex: selected,
      onSelected: onDestinationSelected,
      action: action == null
          ? null
          : LiquidGlassTabAction(
              icon: IconTheme.merge(
                data: IconThemeData(
                  size: bar.actionIconSize ?? 22,
                  color: selectedColor,
                ),
                child: action.icon,
              ),
              label: action.label,
              onPressed: action.onPressed,
            ),
      barHeight: (bar.itemHeight ?? 48) + barPadding.vertical,
      iconSize: iconSize,
      selectedColor: selectedColor,
      unselectedColor: color,
      showLabels: showLabels ?? bar.showLabels ?? false,
      bottomMargin: margin.bottom,
    );
  }
}

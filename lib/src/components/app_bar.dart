import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/components/app_bar_layout.dart';
import 'package:una/src/components/app_bar_morph.dart';
import 'package:una/src/liquid_glass/liquid_glass_theme.dart';
import 'package:una/src/theme/components/app_bar.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/utils/system_overlay_style.dart';

/// The bar across the top of a screen: a logo or back button, a title, and
/// actions.
///
/// ```dart
/// AppBar(
///   title: const Text('Settings'),
///   actions: [
///     IconButton.ghost(
///       tooltip: 'Notifications',
///       onPressed: _openNotifications,
///       icon: const PhosphorIcon(PhosphorIconsRegular.bell),
///     ),
///   ],
/// )
/// ```
///
/// **Zones.** With a [middle], the bar has three zones: [leading] and
/// [title] start aligned, [middle] centred in the bar, [actions] end
/// aligned. Without one, [title] takes the space between [leading] and
/// [actions] — or, with [centerTitle], sits in the centre of the bar the
/// way a pushed page's title does on iOS.
///
/// **The leading button.** A bar that is given no [leading] shows the one
/// its place calls for: a `CloseButton` on a full-screen dialog, a
/// `BackButton` on a page that can be popped, a menu button over a
/// `Scaffold` with a drawer. [automaticallyImplyLeading] turns that off.
/// Likewise a bar with no [actions] over a `Scaffold` with an end drawer
/// shows the button that opens it, unless [automaticallyImplyActions] is
/// false.
///
/// **Under the toolbar.** [bottom] is a second row inside the same surface
/// and above the hairline: a `TabBar`, a search field, a row of filter
/// chips. It adds its own height.
///
/// **The surface.** The bar's height follows the theme's form factor and
/// its fill follows the style's bar opacity: a translucent bar blurs
/// whatever scrolls beneath it, which is the reason to put it in a
/// `Scaffold` rather than a `Column`. With
/// [AppBarSurfaceBehavior.whenScrolled] the bar is bare while the page is
/// at its top and takes its fill, hairline and blur once content scrolls
/// under it. A primary bar also styles the system's status bar so that its
/// icons read on the bar.
///
/// The content is centred and capped at the width of a `PageContainer`'s
/// padding box, so on a wide screen the bar's ends sit one page margin
/// outside the page content below it.
class AppBar extends StatelessWidget {
  /// Creates an app bar.
  const AppBar({
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.centerTitle,
    this.middle,
    this.actions = const [],
    this.automaticallyImplyActions = true,
    this.bottom,
    this.height,
    this.padding,
    this.backgroundColor,
    this.showBorder = true,
    this.surfaceBehavior,
    this.systemOverlayStyle,
    this.maxWidth,
    this.gap,
    this.actionsGap,
    this.primary = true,
    this.liquidGlass,
    super.key,
  });

  /// The widget at the start: a logo, a back button.
  final Widget? leading;

  /// Whether a bar without a [leading] shows the button its place calls
  /// for: close, back, or the scaffold's menu.
  final bool automaticallyImplyLeading;

  /// The widget after [leading]: a title, a search field, a person's name.
  ///
  /// It is announced as the page's heading — unless the bar has a [middle]:
  /// a bar that carries the app's navigation is not headed by what sits
  /// beside its logo.
  final Widget? title;

  /// Whether [title] is centred in the bar instead of following [leading].
  /// Defaults to the theme's, which is false. A [middle] has the centre
  /// first.
  final bool? centerTitle;

  /// A widget centred in the bar, usually a `NavigationBar`.
  final Widget? middle;

  /// The widgets at the end, usually icon buttons.
  final List<Widget> actions;

  /// Whether a bar without [actions] over a scaffold with an end drawer
  /// shows the button that opens it.
  final bool automaticallyImplyActions;

  /// A row under the toolbar, inside the bar's surface: a `TabBar`, a
  /// search field, filter chips. It takes the bar's width; give it its own
  /// margins.
  final Widget? bottom;

  /// The toolbar's height, not counting the safe area, [bottom] or the
  /// hairline under the bar. Defaults to the theme's.
  ///
  /// It is the height at the platform's own text size. With the text
  /// scaled up far enough that a line of the title no longer fits, the
  /// toolbar is as tall as that line; [heightOf] reports the result.
  final double? height;

  /// Padding around the toolbar's content. Defaults to the theme's page
  /// margin.
  final EdgeInsetsGeometry? padding;

  /// The bar's fill. Defaults to the theme's.
  final Color? backgroundColor;

  /// Whether a hairline is drawn under the bar.
  final bool showBorder;

  /// When the bar shows its fill, hairline and blur. Defaults to the
  /// theme's, which is always.
  ///
  /// [AppBarSurfaceBehavior.whenScrolled] needs a `Scaffold` above the bar:
  /// that is what tells it the page has scrolled.
  final AppBarSurfaceBehavior? surfaceBehavior;

  /// The style of the system's status bar over this bar. Defaults to
  /// transparent, with icons that read on the bar's fill. Only a [primary]
  /// bar sets one.
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// The widest the bar's content box grows, its horizontal [padding]
  /// included, before it is centred. Defaults to the theme's: the page's
  /// width plus its margins, so the bar lines up with a `PageContainer`.
  /// A screen whose columns are wider sets the bar to match them.
  final double? maxWidth;

  /// The gap between [leading], [title], [middle] and [actions].
  final double? gap;

  /// The gap between two [actions].
  final double? actionsGap;

  /// Whether the bar sits at the top of the screen and should extend under
  /// the status bar.
  final bool primary;

  /// Whether the bar is Liquid Glass: no fill and no hairline, its buttons
  /// on capsules of glass, and the page that scrolls under it blurred and
  /// faded into the page colour. Over `AppBarTheme.liquidGlass`, which is
  /// over `ThemeData.liquidGlass`.
  ///
  /// [LiquidGlassMode.always] asks for the glass on every platform and form
  /// factor, and in a browser too (see `LiquidGlassTheme.webScrollEdge`
  /// for what the edge costs there). [LiquidGlassMode.never] keeps una's
  /// own bar.
  final LiquidGlassMode? liquidGlass;

  /// The height an [AppBar] without a `bottom` takes in [context],
  /// including the status bar when [primary], at the text scale of
  /// [context].
  static double heightOf(BuildContext context, {bool primary = true}) {
    final theme = Theme.of(context);
    final liquid = appBarUsesLiquidGlass(
      context,
      theme.appBarTheme.liquidGlass,
    );
    return appBarToolbarHeight(
          context,
          appBarStyleHeight(context, null, liquid: liquid),
        ) +
        // The hairline under the bar.
        1 +
        (primary ? appBarTopInset(context, liquid: liquid) : 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = theme.appBarTheme;
    final material = appBarMaterial(context, liquidGlass ?? bar.liquidGlass);
    final liquid = material == AppBarMaterial.liquid;
    final toolbarHeight = appBarToolbarHeight(
      context,
      appBarStyleHeight(context, height, liquid: liquid),
    );
    // Liquid Glass without shader filters: the bar colour, opaque.
    final solid = material == AppBarMaterial.solid;
    final barFill =
        backgroundColor ?? bar.backgroundColor ?? theme.colorScheme.card;
    final fill = solid ? barFill.withValues(alpha: 1) : barFill;
    final topInset = primary ? appBarTopInset(context, liquid: liquid) : 0.0;
    // On Liquid Glass the scroll edge shows once content is under the bar,
    // as on iOS: at the top it would only blur the page's own first lines.
    // Not with a row under the toolbar: tabs over a photograph had nothing
    // to stand on, so that bar keeps its edge. A solid bar is there at rest
    // too.
    final behavior = liquid
        ? bottom == null
              ? AppBarSurfaceBehavior.whenScrolled
              : AppBarSurfaceBehavior.always
        : solid
        ? AppBarSurfaceBehavior.always
        : surfaceBehavior ??
              bar.surfaceBehavior ??
              AppBarSurfaceBehavior.always;

    final implied = leading == null && automaticallyImplyLeading
        ? impliedLeading(context)
        : null;
    var effectiveLeading = leading ?? implied;
    var effectiveActions = automaticallyImplyActions
        ? impliedActions(context, actions)
        : actions;
    // The parts before they go on capsules, for the bar's flight to the
    // next page's on Liquid Glass.
    final rawLeading = effectiveLeading;
    final rawActions = effectiveActions;
    if (liquid) {
      (effectiveLeading, effectiveActions) = liquidGlassBarSlots(
        context,
        leading: effectiveLeading,
        actions: effectiveActions,
        actionsGap: actionsGap,
        leadingIsButton: implied != null,
      );
    }
    final buttonVariant = appBarButtonVariant(material: material);
    final centered = centerTitle ?? bar.centerTitle ?? false;
    // On Liquid Glass the toolbar's capsules stay in place between two
    // pages and turn into the next page's, as iOS 26's do.
    final toolbar = liquid && middle == null
        ? BarMorph(
            height: toolbarHeight,
            leading: effectiveLeading,
            rawLeading: rawLeading,
            title: title,
            actions: effectiveActions,
            rawActions: rawActions,
            buttonVariant: buttonVariant,
            centerTitle: centered,
            padding: padding,
            maxWidth: maxWidth,
            gap: gap,
            actionsGap: actionsGap,
          )
        : AppBarToolbar(
            height: toolbarHeight,
            leading: effectiveLeading,
            buttonVariant: buttonVariant,
            title: title,
            middle: middle,
            actions: effectiveActions,
            centerTitle: centered,
            padding: padding,
            maxWidth: maxWidth,
            gap: gap,
            actionsGap: actionsGap,
          );
    final content = bottom == null
        ? toolbar
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [toolbar, bottom!],
          );

    Widget surface(Animation<double>? visibility, double edgeBelow) =>
        AppBarSurface(
          color: fill,
          borderColor: showBorder
              ? bar.borderColor ?? theme.colorScheme.border
              : null,
          blur: solid ? 0 : bar.blur ?? 0,
          saturation: solid ? 1 : bar.saturation ?? 1,
          // The hairline is added to the height rather than taken from it, so
          // a 64-point bar has 64 points for its content.
          padding: EdgeInsets.only(top: topInset),
          visibility: visibility,
          liquid: liquid,
          edgeBelow: edgeBelow,
          child: content,
        );

    Widget surfaceFor(double edgeBelow) =>
        behavior == AppBarSurfaceBehavior.always
        ? surface(null, edgeBelow)
        : _ScrolledUnder(
            builder: (visibility) => surface(visibility, edgeBelow),
          );

    Widget result = Semantics(
      container: true,
      // On Liquid Glass the scroll edge reaches down under a scaffold's
      // banner too, which the scaffold says in the bar's constraints.
      child: liquid
          ? LayoutBuilder(
              builder: (context, constraints) =>
                  surfaceFor(ScaffoldBarConstraints.belowOf(constraints)),
            )
          : surfaceFor(0),
    );
    if (primary) {
      result = AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            systemOverlayStyle ??
            systemOverlayStyleFor(
              surfaceBrightness(fill, theme.colorScheme.background),
            ),
        child: result,
      );
    }
    return result;
  }
}

/// Runs an animation up to 1 while the page under the nearest `Scaffold`
/// has scrolled away from its top, and back to 0 when it returns.
///
/// The builder runs once: what it builds follows the animation at paint
/// time.
class _ScrolledUnder extends StatefulWidget {
  const _ScrolledUnder({required this.builder});

  final Widget Function(Animation<double> scrolledUnder) builder;

  @override
  State<_ScrolledUnder> createState() => _ScrolledUnderState();
}

class _ScrolledUnderState extends State<_ScrolledUnder>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  ScrollNotificationObserverState? _observer;
  double _target = 0;

  /// How far the page scrolls under the bar for its surface to come in
  /// all the way. Tied to the scroll, the surface rises with the page as
  /// iOS's scroll edge does; run on a timer as soon as anything was under
  /// it, a blur popped in over the page's first lines.
  static const _reach = 32.0;

  /// The largest step the surface takes with the scroll in one go; a jump
  /// further (a page restored mid-way, a programmatic scroll) is eased.
  static const _maxStep = .25;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = ScrollNotificationObserver.maybeOf(context);
    if (identical(observer, _observer)) return;
    _observer?.removeListener(_onScroll);
    _observer = observer?..addListener(_onScroll);
  }

  void _onScroll(ScrollNotification notification) {
    // The page's own scroll view, not one nested inside it.
    if (notification is! ScrollUpdateNotification || notification.depth != 0) {
      return;
    }
    final metrics = notification.metrics;
    final under = switch (metrics.axisDirection) {
      AxisDirection.down => metrics.extentBefore,
      // A reversed list, a conversation: its start is at the bottom.
      AxisDirection.up => metrics.extentAfter,
      // A carousel in the page says nothing about what is under the bar.
      AxisDirection.left || AxisDirection.right => null,
    };
    if (under == null) return;
    final target = (under / _reach).clamp(0.0, 1.0);
    if (target == _target) return;
    _target = target;
    if ((target - _controller.value).abs() <= _maxStep &&
        !_controller.isAnimating) {
      _controller.value = target;
      return;
    }
    final motion = Motion.of(context);
    _controller.animateTo(
      target,
      duration: motion.normal,
      curve: motion.standard,
    );
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

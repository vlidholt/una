import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:una/src/components/spinner.dart';
import 'package:una/src/icons/phosphor_icons.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/raw_components/pressable.dart';
import 'package:una/src/theme/data.dart';
import 'package:una/src/theme/motion.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/theme/themes/shadows.dart';
import 'package:una/src/utils/backdrop.dart';
import 'package:una/src/utils/border.dart';
import 'package:una/src/utils/dismiss_shortcut.dart';
import 'package:una/src/utils/overlay_insets.dart';
import 'package:una/src/utils/pop_in.dart';
import 'package:una/src/utils/shadow.dart';
import 'package:una/src/utils/spring.dart';

/// What a [Toast] is about. It decides the icon the toast leads with; the
/// surface is the same for all of them.
enum ToastVariant {
  /// A plain message, with no icon.
  neutral,

  /// Something worked: a check in the scheme's `success` colour.
  success,

  /// Something needs attention: a warning sign in the scheme's `warning`
  /// colour.
  warning,

  /// Something failed: a cross in the scheme's `destructive` colour.
  /// Announced assertively.
  destructive,

  /// Something is in progress: a spinner. A loading toast stays until it is
  /// dismissed or, more usually, replaced with its result through
  /// `ToasterState.update`.
  loading,
}

/// A short message that floats over the app and leaves by itself: "Saved",
/// "Invitation sent", "Could not connect".
///
/// Show one through the app's [Toaster]:
///
/// ```dart
/// Toaster.of(context).show(
///   const Toast(
///     variant: ToastVariant.success,
///     title: Text('Changes saved'),
///   ),
/// );
/// ```
///
/// A toast is a floating surface like a popover — glass in a style whose
/// popovers are — and takes its look from `ThemeData.toastTheme`. On a
/// desktop it sits in the bottom end corner, on a phone it spans the bottom
/// of the page; either way it is swiped away (with a finger, a mouse or a
/// trackpad) and has no close button.
///
/// The widget is also usable on its own, as a picture of a toast in a
/// settings page or a design review; it is then as wide as its parent lets
/// it be, up to the toaster theme's width.
class Toast extends StatelessWidget {
  /// Creates a toast.
  const Toast({
    super.key,
    this.id,
    this.title,
    this.description,
    this.leading,
    this.action,
    this.variant = ToastVariant.neutral,
    this.duration,
    this.dismissible = true,
    this.onDismissed,
  });

  /// What identifies the toast in its [Toaster]. Showing a toast with the
  /// id of one already on screen replaces that one in place. Null gives it
  /// a new identity, which `ToasterState.show` returns.
  final Object? id;

  /// The message, usually a `Text`.
  final Widget? title;

  /// A second, quieter line under the [title].
  final Widget? description;

  /// What the toast leads with, in place of its [variant]'s icon.
  final Widget? leading;

  /// A control at the end of the toast, usually a small outline `Button`:
  /// "Undo", "Retry". Pressing it does not dismiss the toast by itself.
  final Widget? action;

  /// What the toast is about; see [ToastVariant].
  final ToastVariant variant;

  /// How long the toast stays before it leaves by itself.
  ///
  /// Null uses the theme's (five seconds), except for
  /// [ToastVariant.loading], which stays. `Duration.zero` keeps the toast
  /// until it is dismissed.
  ///
  /// While a screen reader is in use (`MediaQuery.accessibleNavigationOf`)
  /// a toast with an [action] stays until it is dismissed, whatever this
  /// says: finding the action takes longer than any time out.
  final Duration? duration;

  /// Whether the user can dismiss the toast: by swiping it away, or with
  /// Escape while it has the focus. A toast that is
  /// not dismissible still leaves when its [duration] is over.
  final bool dismissible;

  /// Called once when the toast starts to leave, whatever made it: its
  /// time ran out, the user dismissed it, or `ToasterState.dismiss` was
  /// called. Not called when the toast is replaced by another with its
  /// [id].
  final VoidCallback? onDismissed;

  /// How long this toast stays on screen under [theme]; zero is for ever.
  Duration _durationUnder(ThemeData theme) =>
      duration ??
      (variant == ToastVariant.loading
          ? Duration.zero
          : theme.toastTheme.duration ?? const Duration(seconds: 5));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toastTheme = theme.toastTheme;
    final scheme = theme.colorScheme;
    final slot = _ToastSlotScope.maybeOf(context);

    final radius = toastTheme.borderRadius ?? theme.radius;
    final shadows = toastTheme.shadows ?? Shadows.lg;
    final background = toastTheme.backgroundColor ?? scheme.popover;
    final filter = toastTheme.filter;
    final border =
        toastTheme.border ?? UnaBorder.all(color: scheme.border, width: 1);
    final gap = toastTheme.gap ?? 12;
    final iconSize = toastTheme.iconSize ?? 18;
    final titleStyle =
        toastTheme.titleStyle ??
        theme.textTheme.small.copyWith(color: scheme.popoverForeground);
    final descriptionStyle =
        toastTheme.descriptionStyle ??
        theme.textTheme.muted.copyWith(
          color: scheme.popoverForeground.withValues(alpha: .9),
        );

    final accent = switch (variant) {
      ToastVariant.neutral => titleStyle.color,
      ToastVariant.success => toastTheme.successColor ?? scheme.success,
      ToastVariant.warning => toastTheme.warningColor ?? scheme.warning,
      ToastVariant.destructive =>
        toastTheme.destructiveColor ?? scheme.destructive,
      ToastVariant.loading => toastTheme.loadingColor ?? scheme.mutedForeground,
    };
    // A status toast washes its surface and its outline in its colour.
    final status = switch (variant) {
      ToastVariant.success => scheme.success,
      ToastVariant.warning => scheme.warning,
      ToastVariant.destructive => scheme.destructive,
      ToastVariant.neutral || ToastVariant.loading => null,
    };
    final tintOpacity = toastTheme.statusTintOpacity ?? 0;
    final tint = status == null || tintOpacity == 0
        ? null
        : status.withValues(alpha: status.a * tintOpacity);
    final edgeTint = tint == null
        ? null
        : status!.withValues(alpha: status.a * math.min(1, tintOpacity * 2));
    final effectiveLeading =
        leading ??
        switch (variant) {
          ToastVariant.neutral => null,
          ToastVariant.success => const PhosphorIcon(
            PhosphorIconsFill.checkCircle,
          ),
          ToastVariant.warning => const PhosphorIcon(PhosphorIconsFill.warning),
          ToastVariant.destructive => const PhosphorIcon(
            PhosphorIconsFill.xCircle,
          ),
          ToastVariant.loading => Spinner(size: iconSize, color: accent),
        };

    // The icon is centred on the first line of text, the title's when
    // there is one, not on the whole block: beside a title and a two-line
    // description it stays with the title.
    final firstLine = TextPainter(
      text: TextSpan(
        text: ' ',
        style: DefaultTextStyle.of(
          context,
        ).style.merge(title != null ? titleStyle : descriptionStyle),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    final lineHeight = firstLine.preferredLineHeight;
    firstLine.dispose();

    Widget content = Padding(
      padding: toastTheme.padding ?? const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (effectiveLeading != null) ...[
                  SizedBox(
                    height: math.max(lineHeight, iconSize),
                    child: Center(
                      widthFactor: 1,
                      child: IconTheme.merge(
                        data: IconThemeData(size: iconSize, color: accent),
                        // A loading toast that turns into its result says
                        // so.
                        child: PopOnChange(
                          value: variant,
                          child: effectiveLeading,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                ],
                Expanded(
                  child: Padding(
                    // A line shorter than the icon is centred on it.
                    padding: EdgeInsets.only(
                      top: effectiveLeading == null
                          ? 0
                          : math.max(0, iconSize - lineHeight) / 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null)
                          DefaultTextStyle.merge(
                            style: titleStyle,
                            child: title!,
                          ),
                        if (title != null && description != null)
                          const SizedBox(height: 2),
                        if (description != null)
                          DefaultTextStyle.merge(
                            style: descriptionStyle,
                            child: description!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[SizedBox(width: gap), action!],
        ],
      ),
    );
    // Behind the front of a closed stack only a toast's edge shows; its
    // words would show through a glass toast in front of it.
    if (slot != null) {
      content = FadeTransition(opacity: slot.contentOpacity, child: content);
    }

    if (LiquidGlass.isActive(context, toastTheme.liquidGlass)) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: theme.toasterTheme.width ?? _fallbackWidth,
        ),
        child: LiquidGlassSurface(
          radius: radius.resolve(Directionality.of(context)).topLeft.x,
          overlay: true,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tint),
            child: Padding(
              padding: border.toBorder().dimensions,
              child: content,
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: theme.toasterTheme.width ?? _fallbackWidth,
      ),
      // Through a `BackdropSurface` even without a filter, so the fade of an
      // entrance has one place to go either way: a glass toast fades inside
      // its filter, a solid one as a whole.
      child: BackdropSurface(
        filter: filter,
        tintOpacity: background.a,
        borderRadius: radius,
        // A filter is clipped, which would cut the shadow off; it is
        // painted outside the clip instead.
        shadow: filter == null
            ? null
            : ShadowDecoration.box(borderRadius: radius, shadows: shadows),
        child: DecoratedBox(
          decoration: ShadowDecoration.box(
            border:
                (edgeTint == null
                        ? border
                        : border.copyWith(
                            top: border.top?.copyWith(color: edgeTint),
                            right: border.right?.copyWith(color: edgeTint),
                            bottom: border.bottom?.copyWith(color: edgeTint),
                            left: border.left?.copyWith(color: edgeTint),
                          ))
                    .toBorder(),
            borderRadius: radius,
            shadows: filter == null ? shadows : const [],
            color: tint == null
                ? background
                : Color.alphaBlend(tint, background),
          ),
          child: content,
        ),
      ),
    );
  }
}

const _fallbackWidth = 356.0;

/// The room around a toast: every toast in the stack is laid out in a box
/// this much larger on each side, for the focus ring drawn outside it.
const _overhang = 8.0;

/// How far, in logical pixels, a toast has to be dragged to be dismissed
/// when it is let go at rest, and how fast a flick has to be to dismiss it
/// from any distance.
const _swipeDistance = 48.0;
const _swipeVelocity = 500.0;

/// Shows [Toast]s over [child]: the host `UnaApp` installs above the
/// navigator, so a toast outlives the page that showed it.
///
/// ```dart
/// final toaster = Toaster.of(context);
/// final id = toaster.show(
///   const Toast(
///     variant: ToastVariant.loading,
///     title: Text('Uploading…'),
///   ),
/// );
/// await upload();
/// toaster.update(
///   id,
///   const Toast(
///     variant: ToastVariant.success,
///     title: Text('Upload complete'),
///   ),
/// );
/// ```
///
/// Toasts stack. The newest is in front and the ones behind it show an
/// edge; pointing at the stack, or moving the focus into it, opens it and
/// stops the clocks of every toast until the pointer and the focus have
/// left again. More than [maxVisible] wait unseen and come back as the ones
/// in front of them leave.
///
/// A toast is swiped away, towards the edge it sits against or sideways,
/// with a finger, a mouse or a trackpad; it has no close button. The
/// toasts are above the navigator, outside the page's focus scope, so Tab
/// does not wander into them: [shortcut] (F6) moves the focus to the front
/// toast (its action, or the toast itself) and back, Tab then walks the
/// toasts' controls, and Escape dismisses
/// the toast that has the focus and gives the focus back to the page.
///
/// An app built on `UnaApp` already has one. Under another app widget,
/// use `UnaAppBuilder`, or put a [Toaster] around the navigator.
class Toaster extends StatefulWidget {
  /// Creates a host for toasts over [child].
  const Toaster({
    super.key,
    required this.child,
    this.alignment,
    this.maxVisible,
    this.gap,
    this.shortcut = const SingleActivator(LogicalKeyboardKey.f6),
  });

  /// The widget the toasts are shown over: usually the app's navigator.
  final Widget child;

  /// Where the stack sits. Defaults to the theme's: the bottom end corner
  /// on a desktop, the bottom centre on a phone. An alignment in the upper
  /// half stacks the toasts down from the top.
  final AlignmentGeometry? alignment;

  /// How many toasts show at once. Defaults to the theme's, 3.
  final int? maxVisible;

  /// The space between two toasts while the stack is open. Defaults to the
  /// theme's.
  final double? gap;

  /// The key that moves the focus into the toasts, to the first control of
  /// the one in front, and back to where it was. F6 by default, the key
  /// desktop platforms move between the panes of a window with; null for
  /// none. It is only listened for while a toast is showing.
  final ShortcutActivator? shortcut;

  @override
  State<Toaster> createState() => ToasterState();

  /// The state of the nearest [Toaster] above [context].
  ///
  /// Throws a [FlutterError] when there is none.
  static ToasterState of(BuildContext context) {
    final state = maybeOf(context);
    if (state == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No Toaster found above this context.'),
        ErrorDescription(
          'Toaster.of() was called with a context that has no Toaster above '
          'it.',
        ),
        ErrorHint(
          'UnaApp provides one. Under another app widget, pass a '
          'UnaAppBuilder as its builder or wrap the navigator in a '
          'Toaster. A context from above the app (the one that builds '
          'UnaApp itself) does not see it either.',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return state;
  }

  /// The state of the nearest [Toaster] above [context], or null.
  ///
  /// It does not make [context] depend on the toaster, so it is safe in an
  /// `initState` and in a callback.
  static ToasterState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ToasterScope>()?.state;
}

class _ToasterScope extends InheritedWidget {
  const _ToasterScope({required this.state, required super.child});

  final ToasterState state;

  @override
  bool updateShouldNotify(_ToasterScope oldWidget) => state != oldWidget.state;
}

/// The state of a [Toaster]: shows, replaces and dismisses toasts.
///
/// Get it with `Toaster.of(context)`.
class ToasterState extends State<Toaster> with TickerProviderStateMixin {
  /// Oldest first, toasts on their way out included.
  final _entries = <_ToastEntry>[];

  /// Toasts shown while the tree was being built, which join [_entries]
  /// after the frame. They are found by id from the moment they are shown:
  /// two widgets that show the same id in one build give one toast, and
  /// the id that `show` returned can be updated or dismissed at once.
  final _pending = <_ToastEntry>[];

  /// How open the stack is: 0 closed, 1 every toast laid out by itself.
  late final _expansion = SpringController(vsync: this);

  /// The height the closed stack takes from its front toast. Follows the
  /// front when it changes, so the toasts behind glide to their new place.
  late final _frontHeight = SpringController(vsync: this, tolerance: .05);

  /// The way from [_insetsFrom] to [_insetsTo].
  late final _insetsProgress = SpringController(vsync: this, value: 1);
  EdgeInsets _insetsFrom = EdgeInsets.zero;
  EdgeInsets _insetsTo = EdgeInsets.zero;

  /// What the app asked to be kept clear, through [insets].
  EdgeInsets _givenInsets = EdgeInsets.zero;

  /// What the screens under the toaster say they cover: the registry of a
  /// scope above the toaster when there is one, otherwise the toaster's
  /// own, which it puts around its child.
  OverlayInsets? _ownOverlayInsets;
  OverlayInsets? _overlayInsets;

  /// The safe area and the keyboard, which the stack is clear of already.
  EdgeInsets _systemInsets = EdgeInsets.zero;

  /// The toasts' own focus scope: they are not part of any page.
  final _scope = FocusScopeNode(debugLabel: 'Toaster');
  bool _listensForShortcut = false;

  bool _hovered = false;
  late Motion _motion;
  late ThemeData _theme;

  /// Whether a screen reader is in use; see [Toast.duration].
  bool _accessibleNavigation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = Theme.of(context);
    _motion = Motion.of(context);
    final media = MediaQuery.maybeOf(context);
    final accessibleNavigation = media?.accessibleNavigation ?? false;
    if (accessibleNavigation != _accessibleNavigation) {
      _accessibleNavigation = accessibleNavigation;
      // After the build: a time out that ends now dismisses a toast.
      if (_entries.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncTimers();
        });
      }
    }
    _systemInsets =
        (media?.padding ?? EdgeInsets.zero) +
        EdgeInsets.only(bottom: media?.viewInsets.bottom ?? 0);
    final overlayInsets =
        OverlayInsets.maybeOf(context) ??
        (_ownOverlayInsets ??= OverlayInsets());
    if (!identical(overlayInsets, _overlayInsets)) {
      _overlayInsets?.removeListener(_syncInsets);
      _overlayInsets = overlayInsets..addListener(_syncInsets);
    }
    _syncInsets();
  }

  @override
  void didUpdateWidget(Toaster oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncShortcut();
  }

  @override
  void dispose() {
    for (final entry in [..._entries, ..._pending]) {
      entry.dispose();
    }
    _entries.clear();
    _pending.clear();
    _syncShortcut();
    _scope.dispose();
    _expansion.dispose();
    _frontHeight.dispose();
    _insetsProgress.dispose();
    _overlayInsets?.removeListener(_syncInsets);
    _ownOverlayInsets?.dispose();
    super.dispose();
  }

  int get _maxVisible =>
      math.max(1, widget.maxVisible ?? _theme.toasterTheme.maxVisible ?? 3);

  /// The toasts on screen or waiting behind the stack, newest last. Toasts
  /// that are leaving are not among them.
  List<Toast> get toasts => [
    for (final entry in [..._entries, ..._pending])
      if (!entry.leaving) entry.toast,
  ];

  /// The space kept clear between the stack and the edges of the toaster,
  /// on top of the safe area and the keyboard, for something in the way
  /// that the toaster cannot know of.
  ///
  /// What a `Scaffold` under the toaster puts at the bottom of the screen —
  /// a bottom bar, a footer, a floating action button — is kept clear of
  /// without this: the scaffold reports it (see `OverlayInsets`) and the
  /// stack sits above whichever is larger.
  ///
  /// A change moves the stack there on the theme's smooth spring.
  EdgeInsets get insets => _givenInsets;

  set insets(EdgeInsets value) {
    if (value == _givenInsets) return;
    _givenInsets = value;
    _syncInsets();
  }

  /// Moves the stack to where [insets] and the screens' reports put it.
  void _syncInsets() {
    // A screen reports what it covers from the edge of the screen, the
    // safe area and the keyboard included; the stack is clear of those two
    // already. Only the bottom is followed: a toast at the top belongs
    // over an app bar, as a notification does.
    final reported = _overlayInsets?.insets.bottom ?? 0;
    final value = _givenInsets.copyWith(
      bottom: math.max(
        _givenInsets.bottom,
        reported - _systemInsets.bottom,
      ),
    );
    if (value == _insetsTo) return;
    _insetsFrom = _currentInsets;
    _insetsTo = value;
    _insetsProgress.jumpTo(0);
    if (_entries.isEmpty) {
      // Nothing to move.
      _insetsProgress.jumpTo(1);
    } else {
      _insetsProgress.animateTo(1, spring: _motion.smooth);
    }
  }

  EdgeInsets get _currentInsets => EdgeInsets.lerp(
    _insetsFrom,
    _insetsTo,
    _insetsProgress.value,
  )!;

  _ToastEntry? _find(Object id) {
    for (final entry in [..._entries, ..._pending]) {
      if (!entry.leaving && entry.id == id) return entry;
    }
    return null;
  }

  // --- Keyboard --------------------------------------------------------

  void _syncShortcut() {
    final wanted = _entries.isNotEmpty && widget.shortcut != null;
    if (wanted == _listensForShortcut) return;
    _listensForShortcut = wanted;
    if (wanted) {
      HardwareKeyboard.instance.addHandler(_onKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
  }

  bool _onKey(KeyEvent event) {
    final shortcut = widget.shortcut;
    if (shortcut == null || event is! KeyDownEvent) return false;
    if (!shortcut.accepts(event, HardwareKeyboard.instance)) return false;
    if (_scope.hasFocus) {
      _returnFocus();
      return true;
    }
    return focusToasts();
  }

  /// Moves the focus to the toast in front — to its first control, its
  /// action, if it has one, otherwise to the toast itself, where Escape
  /// dismisses it — and returns whether there was a toast to take it. What
  /// [Toaster.shortcut] does.
  bool focusToasts() {
    for (final entry in _entries.reversed) {
      if (!entry.present) continue;
      for (final node in entry.focusNode.traversalDescendants) {
        node.requestFocus();
        return true;
      }
      // With no control, the toast itself takes the focus — while it has
      // it, and only if there is something for Escape to do.
      if (!entry.toast.dismissible) continue;
      entry.focusNode
        ..canRequestFocus = true
        ..requestFocus();
      return true;
    }
    return false;
  }

  /// Gives the focus back to whatever had it before it came to the toasts.
  void _returnFocus() {
    if (!_scope.hasFocus) return;
    _scope.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
  }

  // ---------------------------------------------------------------------

  /// Runs [change] in a `setState`, or after the frame when the tree is
  /// being built: a page may well show a toast from its first build.
  void _mutate(VoidCallback change) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(change);
      });
    } else {
      setState(change);
    }
  }

  /// Shows [toast] in front of the stack and returns what identifies it:
  /// its [Toast.id], or a new object when it has none.
  ///
  /// A toast with the id of one already showing replaces that one where it
  /// is, and its time starts again.
  Object show(Toast toast) {
    final id = toast.id ?? UniqueKey();
    final existing = _find(id);
    if (existing != null) {
      _replace(existing, toast);
      return id;
    }
    final motion = _motion;
    final entry = _ToastEntry(id: id, toast: toast, vsync: this)
      ..standard = motion.standard
      ..exit = motion.exit
      ..maxVisible = _maxVisible
      ..expansion = _expansion.animation;
    entry.fade.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && entry.leaving) _remove(entry);
    });
    _pending.add(entry);
    _mutate(() {
      // Dismissed before it got here.
      if (!_pending.remove(entry)) return;
      _entries.add(entry);
      _syncShortcut();
      if (motion.normal <= Duration.zero) {
        entry.fade.value = 1;
      } else {
        entry.fade.animateTo(1, duration: motion.normal);
      }
      // With reduced motion a toast fades in where it will rest.
      entry.enter.animateTo(
        1,
        spring: motion.reduced ? MotionSpring.instant : motion.snappy,
      );
      _reflow();
    });
    return id;
  }

  /// Replaces the toast identified by [id] with [toast], where it is: a
  /// loading toast with its result, a count with the next one. Its time
  /// starts again.
  ///
  /// Returns false, and shows nothing, when no such toast is showing.
  bool update(Object id, Toast toast) {
    final entry = _find(id);
    if (entry == null) return false;
    _replace(entry, toast);
    return true;
  }

  void _replace(_ToastEntry entry, Toast toast) {
    _mutate(() {
      entry
        ..toast = toast
        ..timer?.cancel()
        ..timer = null;
      _syncTimers();
    });
  }

  /// Dismisses the toast identified by [id]. The future completes when it
  /// has left the screen; at once when no such toast is showing.
  Future<void> dismiss(Object id) {
    final entry = _find(id);
    if (entry == null) return Future<void>.value();
    return _dismiss(entry);
  }

  /// Dismisses every toast. The future completes when the last has left.
  Future<void> dismissAll() => Future.wait([
    for (final entry in [..._entries, ..._pending])
      if (!entry.leaving) _dismiss(entry),
  ]);

  Future<void> _dismiss(_ToastEntry entry) {
    if (entry.leaving) return entry.gone.future;
    final motion = _motion;
    final from = entry.fade.value;
    entry
      ..exitOpacityFrom = entry.opacity.value
      ..exitFadeFrom = from
      ..exit = motion.exit
      ..leaving = true
      ..timer?.cancel()
      ..timer = null;
    entry.enter.stop();
    // A toast that leaves must not take the keyboard with it.
    if (entry.focusNode.hasFocus) _returnFocus();
    entry.toast.onDismissed?.call();
    final duration = motion.reduced ? motion.fast : motion.normal;
    if (from <= 0 || duration <= Duration.zero || !mounted) {
      // Nothing to play: a toast that never showed, or no motion at all.
      _remove(entry);
      return entry.gone.future;
    }
    // Listened for, not awaited: a `TickerFuture` that is cancelled never
    // completes, and the toast would stay in the tree unseen, taking taps.
    entry.fade.animateBack(0, duration: duration);
    _mutate(_reflow);
    return entry.gone.future;
  }

  void _remove(_ToastEntry entry) {
    if (_pending.remove(entry)) {
      // Never shown: nothing on screen to take down.
      entry.dispose();
      if (!entry.gone.isCompleted) entry.gone.complete();
      return;
    }
    if (!_entries.remove(entry)) return;
    if (entry.focusNode.hasFocus) _returnFocus();
    entry.dispose();
    _syncShortcut();
    if (!entry.gone.isCompleted) entry.gone.complete();
    if (!mounted) return;
    if (_entries.isEmpty) {
      _frontHeight.jumpTo(0);
      _hovered = false;
    }
    _mutate(_reflow);
  }

  /// Gives every toast its place in the stack — the newest is 0 — and
  /// brings the clocks and the stack in line with it.
  void _reflow() {
    final motion = _motion;
    var rank = 0;
    for (final entry in _entries.reversed) {
      if (entry.leaving) continue;
      entry
        ..rank = rank
        ..maxVisible = _maxVisible;
      if (entry.placed) {
        entry.depth.animateTo(rank.toDouble(), spring: motion.smooth);
      } else {
        entry
          ..placed = true
          ..depth.jumpTo(rank.toDouble());
      }
      rank++;
    }
    _syncTimers();
    _syncExpansion();
  }

  bool get _engaged =>
      _hovered || _entries.any((entry) => !entry.leaving && entry.focused);

  /// A toast's time runs while it can be seen and nobody is busy with the
  /// stack; it starts again, in full, when it resumes.
  void _syncTimers() {
    final paused =
        _engaged || _entries.any((entry) => !entry.leaving && entry.dragging);
    for (final entry in _entries) {
      if (entry.leaving) continue;
      final duration = entry.toast._durationUnder(_theme);
      final runs =
          !paused &&
          entry.rank < _maxVisible &&
          duration > Duration.zero &&
          !(_accessibleNavigation && entry.toast.action != null);
      if (!runs) {
        entry.timer?.cancel();
        entry.timer = null;
      } else {
        entry.timer ??= Timer(duration, () {
          entry.timer = null;
          _dismiss(entry);
        });
      }
    }
  }

  void _syncExpansion() {
    final target = _engaged ? 1.0 : 0.0;
    if (_expansion.target == target) return;
    _expansion.animateTo(target, spring: _motion.smooth);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    _hovered = value;
    _syncTimers();
    _syncExpansion();
  }

  void _setEntryFocused(_ToastEntry entry, bool value) {
    // Taken only from [focusToasts], never by Tab or a click.
    if (!value) entry.focusNode.canRequestFocus = false;
    if (entry.focused == value || !mounted) return;
    setState(() => entry.focused = value);
    _syncTimers();
    _syncExpansion();
  }

  /// Called by the stack when it has laid its toasts out.
  void _onFrontHeight(double height) {
    if (height == _frontHeight.target) return;
    if (_frontHeight.target == 0) {
      _frontHeight.jumpTo(height);
    } else {
      _frontHeight.animateTo(height, spring: _motion.smooth);
    }
  }

  // --- Swiping ---------------------------------------------------------

  /// +1 when the stack sits against the bottom edge, -1 against the top:
  /// the direction on the vertical axis a toast leaves in.
  double get _edgeSign => _alignment.y < 0 ? -1 : 1;

  Alignment get _alignment =>
      (widget.alignment ??
              _theme.toasterTheme.alignment ??
              AlignmentDirectional.bottomEnd)
          .resolve(Directionality.of(context));

  void _dragStart(_ToastEntry entry) {
    entry
      ..dragging = true
      ..dragRaw = entry.drag.value;
    if (entry.drag.value == 0) entry.dragAxis = null;
    entry.drag.stop();
    _syncTimers();
  }

  void _dragUpdate(_ToastEntry entry, DragUpdateDetails details) {
    final delta = details.delta;
    final axis = entry.dragAxis ??= delta.dx.abs() > delta.dy.abs()
        ? Axis.horizontal
        : Axis.vertical;
    entry.dragRaw += axis == Axis.horizontal ? delta.dx : delta.dy;
    entry.drag.jumpTo(_resisted(entry, entry.dragRaw));
  }

  /// A drag follows the finger where the toast can leave, and gives only a
  /// little where it cannot: away from its edge, or at all when the toast
  /// is not dismissible.
  double _resisted(_ToastEntry entry, double raw) {
    final free =
        entry.toast.dismissible &&
        (entry.dragAxis == Axis.horizontal || raw * _edgeSign > 0);
    return free ? raw : raw.sign * 24 * (1 - math.exp(-raw.abs() / 96));
  }

  void _dragEnd(_ToastEntry entry, Velocity velocity) {
    if (!entry.dragging) return;
    entry.dragging = false;
    final motion = _motion;
    final axis = entry.dragAxis ?? Axis.vertical;
    final speed = axis == Axis.horizontal
        ? velocity.pixelsPerSecond.dx
        : velocity.pixelsPerSecond.dy;
    final offset = entry.drag.value;
    bool leaves(double direction) =>
        entry.toast.dismissible &&
        direction != 0 &&
        (axis == Axis.horizontal || direction * _edgeSign > 0);
    final flung = speed.abs() > _swipeVelocity && speed * offset >= 0;
    final direction = flung ? speed.sign : offset.sign;
    if (!entry.leaving &&
        leaves(direction) &&
        (flung || offset.abs() > _swipeDistance)) {
      // On with the speed it was let go at, fading as it goes. With
      // reduced motion it fades where the finger left it.
      if (!motion.reduced) {
        final extent = axis == Axis.horizontal
            ? (context.size?.width ?? 400)
            : entry.height + 96;
        entry.drag.animateTo(
          offset + direction * extent,
          spring: motion.snappy,
          velocity: speed,
        );
      }
      _dismiss(entry);
    } else {
      entry.drag.animateTo(0, spring: motion.snappy, velocity: speed);
      _syncTimers();
    }
  }

  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    Widget? layer;
    if (_entries.isNotEmpty) {
      final toasterTheme = _theme.toasterTheme;
      final media = MediaQuery.maybeOf(context);
      final direction = Directionality.of(context);
      final padding =
          (toasterTheme.padding ?? const EdgeInsets.all(16)).resolve(
            direction,
          ) +
          (media?.padding ?? EdgeInsets.zero) +
          EdgeInsets.only(bottom: media?.viewInsets.bottom ?? 0);
      final motion = _motion;
      layer = FocusScope(
        node: _scope,
        child: MouseRegion(
          opaque: false,
          hitTestBehavior: HitTestBehavior.deferToChild,
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: _ToastStack(
            alignment: _alignment,
            padding: padding,
            insets: () => _currentInsets,
            width: toasterTheme.width ?? _fallbackWidth,
            gap: widget.gap ?? toasterTheme.gap ?? 8,
            stackOffset: toasterTheme.stackOffset ?? 12,
            stackScale: toasterTheme.stackScale ?? .05,
            enterScale: motion.overlayScale,
            travels: !motion.reduced,
            shadowReach: _shadowReach(
              _theme.toastTheme.shadows ?? Shadows.lg,
            ),
            expansion: _expansion.animation,
            frontHeight: _frontHeight.animation,
            onFrontHeight: _onFrontHeight,
            repaint: Listenable.merge([
              _expansion.animation,
              _frontHeight.animation,
              _insetsProgress.animation,
              for (final entry in _entries) entry.motion,
            ]),
            children: [
              for (final entry in _entries)
                _ToastSlot(
                  key: ObjectKey(entry),
                  entry: entry,
                  toast: entry.toast,
                  leaving: entry.leaving,
                  state: this,
                ),
            ],
          ),
        ),
      );
    }
    return _ToasterScope(
      state: this,
      // The page is always the first child, so it keeps its place in the
      // tree — and its state — when the first toast arrives.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // The screens under the toaster say what they cover, unless a
          // scope further up already collects it.
          OverlayInsetsScope(insets: _overlayInsets, child: widget.child),
          if (layer != null) Positioned.fill(child: layer),
        ],
      ),
    );
  }
}

/// How far [shadows] reach past the box that casts them.
double _shadowReach(List<BoxShadow> shadows) {
  var reach = 0.0;
  for (final shadow in shadows) {
    reach = math.max(
      reach,
      shadow.spreadRadius +
          shadow.blurSigma * 3 +
          math.max(shadow.offset.dx.abs(), shadow.offset.dy.abs()),
    );
  }
  return reach;
}

/// One toast in a [Toaster], with everything that moves it.
class _ToastEntry {
  _ToastEntry({
    required this.id,
    required this.toast,
    required TickerProvider vsync,
  }) : enter = SpringController(vsync: vsync),
       fade = AnimationController(vsync: vsync),
       depth = SpringController(vsync: vsync),
       drag = SpringController(vsync: vsync, tolerance: .05) {
    motion = Listenable.merge([
      enter.animation,
      fade,
      depth.animation,
      drag.animation,
    ]);
    opacity = _Computed([fade, depth.animation], () => _opacity);
  }

  final Object id;
  Toast toast;

  /// The way in: 0 off towards the edge, 1 at rest.
  final SpringController enter;

  /// 0 gone, 1 fully there, linear; [opacity] puts the curves on it.
  final AnimationController fade;

  /// The place in the stack, 0 in front, gliding to [rank].
  final SpringController depth;

  /// How far a swipe has moved the toast along [dragAxis].
  final SpringController drag;

  /// Everything that moves this toast, for the stack to repaint on.
  late final Listenable motion;

  /// Around the toast's controls: says whether the focus is in the toast.
  /// It takes the focus itself only from `focusToasts`, for a toast with
  /// no control.
  final focusNode = FocusNode(
    debugLabel: 'Toast',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// What the toast is faded by: its entrance or exit, and its place when
  /// that is past the last one shown.
  late final Animation<double> opacity;

  /// The fade of the content of a toast behind the front of a closed
  /// stack.
  late final Animation<double> contentOpacity = _Computed(
    [depth.animation, expansion],
    () => math.max(
      expansion.value.clamp(0.0, 1.0),
      1 - depth.value.clamp(0.0, 1.0),
    ),
  );

  late Animation<double> expansion;
  Curve standard = Curves.linear;
  Curve exit = Curves.linear;
  int maxVisible = 3;

  /// The place among the toasts that are staying, 0 in front.
  int rank = 0;

  /// Whether [depth] has been given its first value.
  bool placed = false;

  bool leaving = false;
  double exitFadeFrom = 1;
  double exitOpacityFrom = 1;
  final gone = Completer<void>();

  Timer? timer;
  bool focused = false;
  bool dragging = false;
  Axis? dragAxis;
  double dragRaw = 0;

  /// The height the toast was last laid out at.
  double height = 0;

  /// How far along its exit the toast is, from 0 to 1; 0 while it stays.
  double get exitProgress {
    if (!leaving) return 0;
    if (exitFadeFrom <= 0) return 1;
    return exit.transform((1 - fade.value / exitFadeFrom).clamp(0.0, 1.0));
  }

  double get _opacity {
    if (leaving) return exitOpacityFrom * (1 - exitProgress);
    final shown = (maxVisible - depth.value).clamp(0.0, 1.0);
    return standard.transform(fade.value.clamp(0.0, 1.0)) * shown;
  }

  /// Whether the toast is there to be pointed at, read and focused.
  bool get present => !leaving && rank < maxVisible;

  void dispose() {
    timer?.cancel();
    timer = null;
    focusNode.dispose();
    enter.dispose();
    fade.dispose();
    depth.dispose();
    drag.dispose();
  }
}

/// A number worked out from other animations, as an animation.
class _Computed extends Animation<double> {
  _Computed(List<Listenable> sources, this._compute)
    : _sources = Listenable.merge(sources);

  final Listenable _sources;
  final double Function() _compute;

  @override
  double get value => _compute();

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void addListener(VoidCallback listener) => _sources.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _sources.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}
}

/// What a [Toast] in a [Toaster] is told by its place in the stack.
class _ToastSlotScope extends InheritedWidget {
  const _ToastSlotScope({required this.contentOpacity, required super.child});

  final Animation<double> contentOpacity;

  static _ToastSlotScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToastSlotScope>();

  @override
  bool updateShouldNotify(_ToastSlotScope oldWidget) =>
      contentOpacity != oldWidget.contentOpacity;
}

/// A toast as the stack holds it: with its gestures, its focus and its
/// semantics.
class _ToastSlot extends StatelessWidget {
  const _ToastSlot({
    required this.entry,
    required this.toast,
    required this.leaving,
    required this.state,
    super.key,
  });

  final _ToastEntry entry;
  final Toast toast;
  final bool leaving;
  final ToasterState state;

  @override
  Widget build(BuildContext context) {
    // On the web an alert role is the assertive live region; elsewhere the
    // live region flag is what is announced, and a node may not carry both.
    final alert = kIsWeb && toast.variant == ToastVariant.destructive;
    void dismiss() => state._dismiss(entry);

    return _ToastSlotData(
      entry: entry,
      child: ExcludeFocus(
        // A toast on its way out is not there to be focused.
        excluding: leaving,
        // Around the toast's own node, which has the focus itself when the
        // toast has no control.
        child: DismissShortcut(
          isActive: () => toast.dismissible && !entry.leaving,
          onDismiss: dismiss,
          child: Focus(
            focusNode: entry.focusNode,
            onFocusChange: (focused) => state._setEntryFocused(entry, focused),
            child: Padding(
              padding: const EdgeInsets.all(_overhang),
              // The toast may be glass, which an opacity layer around
              // it would switch off; see [BackdropFade].
              child: BackdropFadeHost(
                opacity: entry.opacity,
                child: Semantics(
                  container: true,
                  liveRegion: !alert,
                  role: alert ? SemanticsRole.alert : null,
                  onDismiss: toast.dismissible ? dismiss : null,
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      PanGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            PanGestureRecognizer
                          >(
                            () => PanGestureRecognizer(
                              // Every pointer: a toast has no close
                              // button, and a mouse or a trackpad
                              // swipes it away as a finger does.
                              supportedDevices: const {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.stylus,
                                PointerDeviceKind.invertedStylus,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                              },
                            ),
                            (recognizer) => recognizer
                              ..onStart = ((_) => state._dragStart(entry))
                              ..onUpdate = ((details) =>
                                  state._dragUpdate(entry, details))
                              ..onEnd = ((details) => state._dragEnd(
                                entry,
                                details.velocity,
                              ))
                              ..onCancel = (() => state._dragEnd(
                                entry,
                                Velocity.zero,
                              )),
                          ),
                    },
                    child: _ToastSlotScope(
                      contentOpacity: entry.contentOpacity,
                      // Shown when the toast itself has the focus,
                      // which it takes when it has no control.
                      child: FocusRing(
                        visible:
                            entry.focused && entry.focusNode.hasPrimaryFocus,
                        borderRadius:
                            Theme.of(context).toastTheme.borderRadius ??
                            Theme.of(context).radii.lg,
                        child: toast,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastStackParentData extends ContainerBoxParentData<RenderBox> {
  _ToastEntry? entry;
}

class _ToastSlotData extends ParentDataWidget<_ToastStackParentData> {
  const _ToastSlotData({required this.entry, required super.child});

  final _ToastEntry entry;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as _ToastStackParentData;
    if (identical(parentData.entry, entry)) return;
    parentData.entry = entry;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _ToastStack;
}

/// Lays the toasts out once, at their own height, and from then on only
/// paints: where each one is drawn — its place in the stack, how open the
/// stack is, its entrance, a swipe — is a transform worked out per frame
/// from the animations, so nothing is laid out again while they run.
class _ToastStack extends MultiChildRenderObjectWidget {
  const _ToastStack({
    required this.alignment,
    required this.padding,
    required this.insets,
    required this.width,
    required this.gap,
    required this.stackOffset,
    required this.stackScale,
    required this.enterScale,
    required this.travels,
    required this.shadowReach,
    required this.expansion,
    required this.frontHeight,
    required this.onFrontHeight,
    required this.repaint,
    required super.children,
  });

  final Alignment alignment;
  final EdgeInsets padding;
  final EdgeInsets Function() insets;
  final double width;
  final double gap;
  final double stackOffset;
  final double stackScale;
  final double enterScale;
  final bool travels;
  final double shadowReach;
  final Animation<double> expansion;
  final Animation<double> frontHeight;
  final ValueChanged<double> onFrontHeight;
  final Listenable repaint;

  @override
  RenderToastStack createRenderObject(BuildContext context) => RenderToastStack(
    alignment: alignment,
    padding: padding,
    insets: insets,
    width: width,
    gap: gap,
    stackOffset: stackOffset,
    stackScale: stackScale,
    enterScale: enterScale,
    travels: travels,
    shadowReach: shadowReach,
    expansion: expansion,
    frontHeight: frontHeight,
    onFrontHeight: onFrontHeight,
    repaint: repaint,
  );

  @override
  void updateRenderObject(BuildContext context, RenderToastStack renderObject) {
    renderObject
      ..alignment = alignment
      ..padding = padding
      ..insets = insets
      ..width = width
      ..gap = gap
      ..stackOffset = stackOffset
      ..stackScale = stackScale
      ..enterScale = enterScale
      ..travels = travels
      ..shadowReach = shadowReach
      ..expansion = expansion
      ..frontHeight = frontHeight
      ..onFrontHeight = onFrontHeight
      ..repaint = repaint;
  }
}

/// Where one toast is drawn in a frame.
class _Placement {
  const _Placement(this.transform, this.clip, this.bounds);

  /// From the toast's box (overhang included) to the stack.
  final Matrix4 transform;

  /// What of the toast's box is drawn, or null for all of it.
  final Rect? clip;

  /// The toast itself, in the stack's coordinates.
  final Rect bounds;
}

/// The render object of a `Toaster`'s stack of toasts.
///
/// Public for tests, which ask it what it left of each toast.
@visibleForTesting
class RenderToastStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ToastStackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ToastStackParentData> {
  /// Creates the stack.
  RenderToastStack({
    required Alignment alignment,
    required EdgeInsets padding,
    required this.insets,
    required double width,
    required double gap,
    required double stackOffset,
    required double stackScale,
    required double enterScale,
    required bool travels,
    required double shadowReach,
    required this.expansion,
    required this.frontHeight,
    required this.onFrontHeight,
    required Listenable repaint,
  }) : _alignment = alignment,
       _padding = padding,
       _width = width,
       _gap = gap,
       _stackOffset = stackOffset,
       _stackScale = stackScale,
       _enterScale = enterScale,
       _travels = travels,
       _shadowReach = shadowReach,
       _repaint = repaint;

  /// The animated extra insets, read at paint.
  EdgeInsets Function() insets;

  /// How open the stack is.
  Animation<double> expansion;

  /// The height the closed stack takes from its front toast.
  Animation<double> frontHeight;

  /// Told the front toast's height after each layout.
  ValueChanged<double> onFrontHeight;

  /// Where the stack sits.
  Alignment get alignment => _alignment;
  Alignment _alignment;
  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsPaint();
  }

  /// The space kept clear at the edges.
  EdgeInsets get padding => _padding;
  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  /// The most a toast is wide.
  double get width => _width;
  double _width;
  set width(double value) {
    if (_width == value) return;
    _width = value;
    markNeedsLayout();
  }

  /// The space between toasts in the open stack.
  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsPaint();
  }

  /// How far a toast shows past the one in front in the closed stack.
  double get stackOffset => _stackOffset;
  double _stackOffset;
  set stackOffset(double value) {
    if (_stackOffset == value) return;
    _stackOffset = value;
    markNeedsPaint();
  }

  /// How much smaller each toast behind the front is.
  double get stackScale => _stackScale;
  double _stackScale;
  set stackScale(double value) {
    if (_stackScale == value) return;
    _stackScale = value;
    markNeedsPaint();
  }

  /// The scale a toast enters from and leaves to.
  double get enterScale => _enterScale;
  double _enterScale;
  set enterScale(double value) {
    if (_enterScale == value) return;
    _enterScale = value;
    markNeedsPaint();
  }

  /// Whether a toast travels as it enters and leaves, or only fades.
  bool get travels => _travels;
  bool _travels;
  set travels(bool value) {
    if (_travels == value) return;
    _travels = value;
    markNeedsPaint();
  }

  /// How far a toast's shadow reaches past it.
  double get shadowReach => _shadowReach;
  double _shadowReach;
  set shadowReach(double value) {
    if (_shadowReach == value) return;
    _shadowReach = value;
    markNeedsPaint();
  }

  /// What the stack repaints on.
  Listenable get repaint => _repaint;
  Listenable _repaint;
  set repaint(Listenable value) {
    if (identical(_repaint, value)) return;
    if (attached) {
      _repaint.removeListener(_onTick);
      value.addListener(_onTick);
    }
    _repaint = value;
    _onTick();
  }

  void _onTick() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  double _toastWidth = 0;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(_onTick);
  }

  @override
  void detach() {
    _repaint.removeListener(_onTick);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ToastStackParentData) {
      child.parentData = _ToastStackParentData();
    }
  }

  _ToastEntry _entryOf(RenderBox child) =>
      (child.parentData! as _ToastStackParentData).entry!;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    final available = math.max(0, size.width - padding.horizontal);
    _toastWidth = math.min(width, available).toDouble();
    final childConstraints = BoxConstraints.tightFor(
      width: _toastWidth + _overhang * 2,
    );
    double? front;
    var child = firstChild;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final entry = _entryOf(child)
        ..height = math.max(0, child.size.height - _overhang * 2);
      if (!entry.leaving && entry.rank == 0) front = entry.height;
      child = childAfter(child);
    }
    if (front != null) onFrontHeight(front);
  }

  /// The heights of the toasts that are staying, front first.
  List<double> _heights() {
    final heights = <double>[];
    var child = lastChild;
    while (child != null) {
      final entry = _entryOf(child);
      if (!entry.leaving) heights.add(entry.height);
      child = childBefore(child);
    }
    return heights;
  }

  /// How far from the edge the toast at [depth] starts in the open stack.
  double _distanceAt(double depth, List<double> heights) {
    if (depth <= 0 || heights.isEmpty) return 0;
    double at(int rank) {
      var distance = 0.0;
      for (var i = 0; i < rank && i < heights.length; i++) {
        distance += heights[i] + gap;
      }
      return distance;
    }

    final below = depth.floor();
    return lerpDouble(at(below), at(below + 1), depth - below)!;
  }

  _Placement _place(_ToastEntry entry, List<double> heights) {
    final top = alignment.y < 0;
    final open = expansion.value.clamp(0.0, 1.0);
    final depth = math.max(0, entry.depth.value).toDouble();
    final frontness = 1 - depth.clamp(0.0, 1.0);
    final h = entry.height;
    final w = _toastWidth;
    final h0 = frontHeight.value <= 0 ? h : frontHeight.value;

    // Measured from the edge the stack sits against, away from it.
    final closedHeight = lerpDouble(h0, h, frontness)!;
    final closedFar = closedHeight + depth * stackOffset;
    final openFar = _distanceAt(depth, heights) + h;
    final far = lerpDouble(closedFar, openFar, open)!;
    final visible = lerpDouble(closedHeight, h, open)!;
    final stackScaleNow = math.max(
      .5,
      lerpDouble(1 - depth * stackScale, 1, open)!,
    );

    // The entrance, the exit and a vertical swipe, towards the edge.
    final entered = entry.enter.value;
    final leaving = entry.exitProgress;
    var towardsEdge = 0.0;
    var presenceScale = 1.0;
    if (travels) {
      towardsEdge += (1 - entered) * h * .5 + leaving * h * .25;
      presenceScale =
          lerpDouble(enterScale, 1, entered)! *
          lerpDouble(1, enterScale, leaving)!;
    }
    final edgeSign = top ? -1.0 : 1.0;
    var dx = 0.0;
    if (entry.dragAxis == Axis.horizontal) {
      dx = entry.drag.value;
    } else {
      towardsEdge += entry.drag.value * edgeSign;
    }

    final extra = insets();
    final left =
        padding.left +
        extra.left +
        (size.width - padding.horizontal - extra.horizontal - w) *
            (alignment.x + 1) /
            2 +
        dx;
    final double y;
    if (top) {
      final edge = padding.top + extra.top;
      y = edge + far - h - towardsEdge;
    } else {
      final edge = size.height - padding.bottom - extra.bottom;
      y = edge - far + towardsEdge;
    }

    // In the toast's own box, which is `_overhang` larger on every side.
    final farEdge = Offset(_overhang + w / 2, top ? _overhang + h : _overhang);
    final centre = Offset(_overhang + w / 2, _overhang + h / 2);
    final transform = Matrix4.translationValues(
      left - _overhang,
      y - _overhang,
      0,
    );
    if (stackScaleNow != 1) {
      transform
        ..translateByDouble(farEdge.dx, farEdge.dy, 0, 1)
        ..scaleByDouble(stackScaleNow, stackScaleNow, 1, 1)
        ..translateByDouble(-farEdge.dx, -farEdge.dy, 0, 1);
    }
    if (presenceScale != 1) {
      transform
        ..translateByDouble(centre.dx, centre.dy, 0, 1)
        ..scaleByDouble(presenceScale, presenceScale, 1, 1)
        ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
    }

    // A toast behind the front of a closed stack is cropped to the front's
    // height, and its shadow with it: under the toast in front a shadow
    // would only show through. Each gets its own as the stack opens.
    final room = math.max(open, frontness);
    Rect? clip;
    if (room < 1 || visible < h - .01) {
      final shown = Rect.fromLTWH(
        _overhang,
        top ? _overhang + h - visible : _overhang,
        w,
        visible,
      );
      clip = shown.inflate(math.max(shadowReach, _overhang) * room);
    }
    return _Placement(
      transform,
      clip,
      MatrixUtils.transformRect(
        transform,
        Rect.fromLTWH(_overhang, _overhang, w, h),
      ),
    );
  }

  /// Back to front, as they are painted.
  List<RenderBox> _paintOrder() {
    final children = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }
    // Stable: equal depths keep the order they arrived in.
    final depths = {
      for (final child in children) child: _entryOf(child).depth.value,
    };
    final order = {
      for (final (index, child) in children.indexed) child: index,
    };
    children.sort((a, b) {
      final byDepth = depths[b]!.compareTo(depths[a]!);
      return byDepth != 0 ? byDepth : order[a]!.compareTo(order[b]!);
    });
    return children;
  }

  /// How much room the clip around [child] leaves its shadow, in logical
  /// pixels on each side; infinite when the toast is not clipped at all.
  @visibleForTesting
  double debugShadowRoomOf(RenderBox child) {
    RenderObject? slot = child;
    while (slot != null && slot.parent != this) {
      slot = slot.parent;
    }
    final entry = _entryOf(slot! as RenderBox);
    final clip = _place(entry, _heights()).clip;
    if (clip == null) return double.infinity;
    return _overhang - clip.left;
  }

  @override
  bool paintsChild(RenderBox child) => _entryOf(child).opacity.value > 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    final heights = _heights();
    for (final child in _paintOrder()) {
      final entry = _entryOf(child);
      // A toast waiting behind the stack costs nothing, its filter least
      // of all.
      if (entry.opacity.value <= 0) continue;
      final placement = _place(entry, heights);
      context.pushTransform(needsCompositing, offset, placement.transform, (
        context,
        offset,
      ) {
        final clip = placement.clip;
        if (clip == null) {
          context.paintChild(child, offset);
        } else {
          context.pushClipRect(
            needsCompositing,
            offset,
            clip,
            (context, offset) => context.paintChild(child, offset),
          );
        }
      });
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_place(_entryOf(child), _heights()).transform);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    var child = firstChild;
    while (child != null) {
      if (_entryOf(child).present) visitor(child);
      child = childAfter(child);
    }
  }

  /// The box around every toast that can be pointed at, gaps included, so
  /// the stack stays open while the pointer crosses from one to the next.
  Rect? _reach() {
    final heights = _heights();
    Rect? reach;
    var child = firstChild;
    while (child != null) {
      final entry = _entryOf(child);
      if (entry.present) {
        final bounds = _place(entry, heights).bounds;
        reach = reach?.expandToInclude(bounds) ?? bounds;
      }
      child = childAfter(child);
    }
    return reach;
  }

  @override
  bool hitTestSelf(Offset position) => _reach()?.contains(position) ?? false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final heights = _heights();
    for (final child in _paintOrder().reversed) {
      final entry = _entryOf(child);
      // A toast on its way out, or waiting behind the stack, is not there
      // to be tapped.
      if (!entry.present) continue;
      final placement = _place(entry, heights);
      final hit = result.addWithPaintTransform(
        transform: placement.transform,
        position: position,
        hitTest: (result, position) {
          final clip = placement.clip;
          if (clip != null && !clip.contains(position)) return false;
          return child.hitTest(result, position: position);
        },
      );
      if (hit) return true;
    }
    return false;
  }
}

// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:una/src/components/scroll_area.dart';
import 'package:una/src/components/toast.dart';
import 'package:una/src/i18n/localizations_delegate.dart';
import 'package:una/src/liquid_glass/liquid_glass.dart';
import 'package:una/src/page_route.dart';
import 'package:una/src/theme/cross_fade_theme.dart';
import 'package:una/src/theme/data.dart';
import 'package:una/src/theme/form_factor.dart';
import 'package:una/src/theme/theme.dart';
import 'package:una/src/theme/theme_scope.dart';
import 'package:una/src/utils/mouse_area.dart';
import 'package:una/src/utils/mouse_cursor_provider.dart';

/// Which of [UnaApp.theme] and [UnaApp.darkTheme] the app uses.
enum ThemeMode {
  /// Follow the platform's brightness setting.
  system,

  /// Always use [UnaApp.theme].
  light,

  /// Always use [UnaApp.darkTheme], or [UnaApp.theme] when it is null.
  dark,
}

/// The kind of app that [UnaApp] builds.
enum UnaAppType {
  /// The standard una app: a [WidgetsApp] with una defaults. Used by
  /// [UnaApp.new] and [UnaApp.router].
  standard,

  /// Calls [UnaApp.appBuilder], so you can build your own app widget, for
  /// example a `MaterialApp`. Used by [UnaApp.custom].
  custom,
}

/// The root widget of a una app.
///
/// It provides the [Theme], the localizations and the toaster. Below them
/// it builds a [WidgetsApp], or calls [appBuilder] for [UnaApp.custom].
///
/// una does not depend on Material or Cupertino. To use their widgets in the
/// same app, wrap them in a `UnaMaterial` from `package:una/material.dart`,
/// usually through [builder].
class UnaApp extends StatefulWidget {
  /// Creates a [UnaApp] providing a [Theme].
  const UnaApp({
    super.key,
    this.navigatorKey,
    this.onGenerateRoute,
    this.onGenerateInitialRoutes,
    this.onUnknownRoute,
    this.onNavigationNotification,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.initialRoute,
    this.home,
    this.routes = const <String, WidgetBuilder>{},
    this.builder,
    this.title = '',
    this.onGenerateTitle,
    this.color,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.showPerformanceOverlay = false,
    this.showSemanticsDebugger = false,
    this.debugShowCheckedModeBanner = false,
    this.shortcuts,
    this.actions,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.formFactor,
    this.restorationScopeId,
    this.scrollBehavior = const UnaScrollBehavior(),
    this.pageRouteBuilder,
    this.themeCurve = Curves.linear,
    this.backgroundColor,
  }) : routeInformationProvider = null,
       routeInformationParser = null,
       routerDelegate = null,
       backButtonDispatcher = null,
       routerConfig = null,
       appBuilder = null,
       type = UnaAppType.standard;

  /// Creates a [UnaApp] that uses the [Router] instead of a [Navigator].
  const UnaApp.router({
    super.key,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.formFactor,
    this.routeInformationProvider,
    this.routeInformationParser,
    this.routerDelegate,
    this.backButtonDispatcher,
    this.routerConfig,
    this.builder,
    this.title = '',
    this.onGenerateTitle,
    this.onNavigationNotification,
    this.color,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.showPerformanceOverlay = false,
    this.showSemanticsDebugger = false,
    this.debugShowCheckedModeBanner = false,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    this.scrollBehavior = const UnaScrollBehavior(),
    this.themeCurve = Curves.linear,
    this.backgroundColor,
  }) : navigatorObservers = null,
       navigatorKey = null,
       onGenerateRoute = null,
       home = null,
       onGenerateInitialRoutes = null,
       onUnknownRoute = null,
       routes = null,
       initialRoute = null,
       pageRouteBuilder = null,
       appBuilder = null,
       type = UnaAppType.standard;

  /// Creates a [UnaApp] that provides the theme but calls [appBuilder] to
  /// build the app widget.
  ///
  /// Use it to put a `MaterialApp` or a `CupertinoApp` below the una theme.
  /// Theme it with `materialThemeFrom(Theme.of(context))` from
  /// `package:una/material.dart`, and return a [UnaAppBuilder] from its
  /// `builder` to get the toaster.
  const UnaApp.custom({
    super.key,
    required WidgetBuilder this.appBuilder,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.formFactor,
  }) : actions = null,
       backButtonDispatcher = null,
       onNavigationNotification = null,
       builder = null,
       color = null,
       debugShowCheckedModeBanner = false,
       home = null,
       initialRoute = null,
       locale = null,
       localeListResolutionCallback = null,
       localeResolutionCallback = null,
       localizationsDelegates = null,
       navigatorKey = null,
       navigatorObservers = null,
       onGenerateInitialRoutes = null,
       onGenerateRoute = null,
       onGenerateTitle = null,
       onUnknownRoute = null,
       pageRouteBuilder = null,
       restorationScopeId = null,
       routeInformationParser = null,
       routeInformationProvider = null,
       routerConfig = null,
       routerDelegate = null,
       routes = null,
       backgroundColor = null,
       scrollBehavior = const UnaScrollBehavior(),
       shortcuts = null,
       showPerformanceOverlay = false,
       showSemanticsDebugger = false,
       supportedLocales = const <Locale>[Locale('en', 'US')],
       themeCurve = Curves.linear,
       title = '',
       type = UnaAppType.custom;

  /// The type of app to use.
  ///
  /// If you are going to use only Una components, use
  /// [UnaAppType.standard]. To build your own app widget, such as a
  /// `MaterialApp`, use [UnaAppType.custom].
  final UnaAppType type;

  /// Default visual properties, like colors fonts and shapes, for this app's
  /// una widgets.
  ///
  /// A second [darkTheme] [ThemeData] value, which is used to provide a
  /// dark version of the user interface can also be specified. [themeMode] will
  /// control which theme will be used if a [darkTheme] is provided.
  ///
  /// The default value of this property is the value of
  /// `ThemeData(brightness: Brightness.light)`.
  final ThemeData? theme;

  /// The [ThemeData] to use when a 'dark mode' is requested by the
  /// system.
  ///
  /// Some host platforms allow the users to select a system-wide 'dark mode',
  /// or the application may want to offer the user the ability to choose a
  /// dark theme just for this application. This is theme that will be used for
  /// such cases. [themeMode] will control which theme will be used.
  ///
  /// This theme should have a [ThemeData.brightness] set to
  /// [Brightness.dark].
  ///
  /// Uses [theme] instead when null. Defaults to the value of
  /// [ThemeData(brightness: Brightness.light)] when both [darkTheme] and
  /// [theme] are null.
  final ThemeData? darkTheme;

  /// Determines which theme will be used by the application if both [theme]
  /// and [darkTheme] are provided.
  ///
  /// If set to [ThemeMode.system], the choice of which theme to use will
  /// be based on the user's system preferences. If the
  /// [MediaQuery.platformBrightnessOf] is [Brightness.light], [theme] will be
  /// used. If it is [Brightness.dark], [darkTheme] will be used (unless it is
  /// null, in which case [theme] will be used.
  ///
  /// If set to [ThemeMode.light] the [theme] will always be used,
  /// regardless of the user's system preference.
  ///
  /// If set to [ThemeMode.dark] the [darkTheme] will be used
  /// regardless of the user's system preference. If [darkTheme] is null
  /// then it will fallback to using [theme].
  ///
  /// The default value is [ThemeMode.system].
  final ThemeMode? themeMode;

  /// The class of screen the theme is laid out for.
  ///
  /// Null, the default, follows the window: narrower than the theme's `md`
  /// breakpoint is [FormFactor.mobile], anything wider [FormFactor.desktop].
  /// Every `StyleTokens` carries metrics for both, so the same widgets come
  /// out with larger touch targets, larger body text and tighter page
  /// margins on a phone. Set it to pin one regardless of width.
  final FormFactor? formFactor;

  /// A key for the [Navigator] that the app creates.
  ///
  /// Use it to push or pop routes without a [BuildContext].
  /// See [WidgetsApp.navigatorKey].
  final GlobalKey<NavigatorState>? navigatorKey;

  /// The widget shown at the default route (`/`).
  ///
  /// See [WidgetsApp.home].
  final Widget? home;

  /// The application's top-level routing table.
  ///
  /// When a named route is pushed with [Navigator.pushNamed], the route name is
  /// looked up in this map. If the name is present, the associated
  /// [WidgetBuilder] is used to build a page with [pageRouteBuilder] (by
  /// default a short fade), including [Hero] animations, to the new route.
  ///
  /// See [WidgetsApp.routes].
  final Map<String, WidgetBuilder>? routes;

  /// The name of the first route to show, when the app starts with a
  /// [Navigator].
  ///
  /// See [WidgetsApp.initialRoute].
  final String? initialRoute;

  /// Builds a route for a named route that is not in [routes].
  ///
  /// See [WidgetsApp.onGenerateRoute].
  final RouteFactory? onGenerateRoute;

  /// Builds the first routes from [initialRoute].
  ///
  /// See [WidgetsApp.onGenerateInitialRoutes].
  final InitialRouteListFactory? onGenerateInitialRoutes;

  /// Builds a route when [onGenerateRoute] does not give one.
  ///
  /// See [WidgetsApp.onUnknownRoute].
  final RouteFactory? onUnknownRoute;

  /// Called when a [NavigationNotification] reaches the app.
  ///
  /// See [WidgetsApp.onNavigationNotification].
  final NotificationListenerCallback<NavigationNotification>?
  onNavigationNotification;

  /// The observers for the [Navigator] that the app creates.
  ///
  /// See [WidgetsApp.navigatorObservers].
  final List<NavigatorObserver>? navigatorObservers;

  /// Gives route information to the [Router]. Used by [UnaApp.router].
  ///
  /// See [WidgetsApp.routeInformationProvider].
  final RouteInformationProvider? routeInformationProvider;

  /// Parses route information into a configuration for [routerDelegate].
  /// Used by [UnaApp.router].
  ///
  /// See [WidgetsApp.routeInformationParser].
  final RouteInformationParser<Object>? routeInformationParser;

  /// Builds the [Navigator] from the route configuration. Used by
  /// [UnaApp.router].
  ///
  /// See [WidgetsApp.routerDelegate].
  final RouterDelegate<Object>? routerDelegate;

  /// Tells the [Router] when the system back button is pressed. Used by
  /// [UnaApp.router].
  ///
  /// See [WidgetsApp.backButtonDispatcher].
  final BackButtonDispatcher? backButtonDispatcher;

  /// A single object that holds the router delegates, as an alternative to
  /// [routeInformationProvider], [routeInformationParser], [routerDelegate] and
  /// [backButtonDispatcher]. Used by [UnaApp.router].
  ///
  /// See [WidgetsApp.routerConfig].
  final RouterConfig<Object>? routerConfig;

  /// The [PageRoute] generator callback used when the app is navigated to a
  /// named route.
  ///
  /// A [PageRoute] represents the page in a [Navigator], so that it can
  /// correctly animate between pages, and to represent the "return value" of
  /// a route (e.g. which button a user selected in a modal dialog).
  ///
  /// Defaults to a [UnaPageRoute]: the platform's whole-width slide on
  /// iOS and macOS, a short slide and fade elsewhere, with the back swipe
  /// on iOS and macOS and the preview of the predictive back gesture on
  /// Android. Pass a `MaterialPageRoute` or a `CupertinoPageRoute` here for
  /// their platform transitions instead.
  ///
  /// The [PageRouteFactory] type is generic, meaning the provided function must
  /// itself be generic. For example (with special emphasis on the `<T>` at the
  /// start of the closure):
  ///
  /// ```dart
  /// pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) => PageRouteBuilder<T>(
  ///   settings: settings,
  ///   pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => builder(context),
  /// ),
  /// ```
  final PageRouteFactory? pageRouteBuilder;

  /// Wraps the widget below the [Navigator] or [Router].
  ///
  /// Use it to insert widgets above every route, such as an inherited widget.
  /// The child it receives already contains the toaster.
  /// See [WidgetsApp.builder].
  final TransitionBuilder? builder;

  /// A one-line description of the app, used by the operating system, for
  /// example in the task switcher.
  ///
  /// This value is passed unmodified to [WidgetsApp.title].
  final String title;

  /// Builds the [title] from a context that has the app's [Localizations].
  /// Use it to localize the title.
  ///
  /// This value is passed unmodified to [WidgetsApp.onGenerateTitle].
  final GenerateAppTitle? onGenerateTitle;

  /// The primary color of the app, used by the operating system, for example
  /// in the task switcher. Defaults to blue.
  ///
  /// See [WidgetsApp.color].
  final Color? color;

  /// The initial locale of the app. When null, the app uses the system locale.
  ///
  /// See [WidgetsApp.locale].
  final Locale? locale;

  /// Extra localization delegates for the app.
  ///
  /// The app always adds the una and widgets delegates after these. Add
  /// `GlobalMaterialLocalizations.delegate` and
  /// `GlobalCupertinoLocalizations.delegate` here for Material or Cupertino
  /// widgets, or wrap them in a `UnaMaterial`, which adds them. See [WidgetsApp.localizationsDelegates].
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// Selects the app locale from the list of system locales.
  ///
  /// See [WidgetsApp.localeListResolutionCallback].
  ///
  /// This callback is passed along to the [WidgetsApp] built by this widget.
  final LocaleListResolutionCallback? localeListResolutionCallback;

  /// Selects the app locale from one system locale, when
  /// [localeListResolutionCallback] is null.
  ///
  /// This callback is passed along to the [WidgetsApp] built by this widget.
  final LocaleResolutionCallback? localeResolutionCallback;

  /// The locales that the app supports. Defaults to `en_US`.
  ///
  /// See [WidgetsApp.supportedLocales].
  ///
  /// It is passed along unmodified to the [WidgetsApp] built by this widget.
  final Iterable<Locale> supportedLocales;

  /// Turns on a performance overlay.
  ///
  /// See also:
  ///
  ///  * <https://flutter.dev/debugging/#performanceoverlay>
  final bool showPerformanceOverlay;

  /// Turns on an overlay that shows the accessibility information
  /// reported by the framework.
  final bool showSemanticsDebugger;

  /// Shows a "DEBUG" banner in debug mode. Defaults to false.
  ///
  /// See [WidgetsApp.debugShowCheckedModeBanner].
  final bool debugShowCheckedModeBanner;

  /// The default keyboard shortcuts for the app. When null, the app uses
  /// [WidgetsApp.defaultShortcuts].
  ///
  /// {@tool snippet}
  /// This example shows how to add a single shortcut for
  /// LogicalKeyboardKey.select to the default shortcuts without needing to
  /// add your own [Shortcuts] widget.
  ///
  /// Alternatively, you could insert a [Shortcuts] widget with just the mapping
  /// you want to add between the [UnaApp] and its child and get the same
  /// effect.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   return UnaApp(
  ///     shortcuts: <ShortcutActivator, Intent>{
  ///       ... WidgetsApp.defaultShortcuts,
  ///       const SingleActivator(LogicalKeyboardKey.select):
  ///         const ActivateIntent(),
  ///     },
  ///     color: const Color(0xFFFF0000),
  ///     builder: (BuildContext context, Widget? child) {
  ///       return const Placeholder();
  ///     },
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [WidgetsApp.shortcuts], which this value is passed to.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// The default actions for the app. When null, the app uses
  /// [WidgetsApp.defaultActions].
  ///
  /// {@tool snippet}
  /// This example shows how to add a single action handling an
  /// [ActivateAction] to the default actions without needing to
  /// add your own [Actions] widget.
  ///
  /// Alternatively, you could insert a [Actions] widget with just the mapping
  /// you want to add between the [UnaApp] and its child and get the same
  /// effect.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   return UnaApp(
  ///     actions: <Type, Action<Intent>>{
  ///       ... WidgetsApp.defaultActions,
  ///       ActivateAction: CallbackAction(
  ///         onInvoke: (Intent intent) {
  ///           // Do something here...
  ///           return null;
  ///         },
  ///       ),
  ///     },
  ///     color: const Color(0xFFFF0000),
  ///     builder: (BuildContext context, Widget? child) {
  ///       return const Placeholder();
  ///     },
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [WidgetsApp.actions], which this value is passed to.
  final Map<Type, Action<Intent>>? actions;

  /// The restoration scope ID for the app's state restoration. When null,
  /// state restoration is off.
  ///
  /// See [WidgetsApp.restorationScopeId].
  final String? restorationScopeId;

  /// How [Scrollable] widgets in the app behave. Defaults to
  /// [UnaScrollBehavior].
  ///
  /// See also:
  ///
  ///  * [ScrollConfiguration], which controls how [Scrollable] widgets behave
  ///    in a subtree.
  final ScrollBehavior scrollBehavior;

  /// The curve of the cross-fade from one [ThemeData] to another (see
  /// [CrossFadeTheme]), defaults to [Curves.linear].
  final Curve themeCurve;

  /// A custom app widget builder.
  final WidgetBuilder? appBuilder;

  /// {@macro UnaAppBuilder.backgroundColor}
  final Color? backgroundColor;

  @override
  State<UnaApp> createState() => _AppState();
}

class _AppState extends State<UnaApp> {
  final heroController = HeroController();

  bool get usesRouter =>
      widget.routerDelegate != null || widget.routerConfig != null;

  /// The app's own delegates, followed by una's and the widgets layer's.
  Iterable<LocalizationsDelegate<dynamic>>
  get effectiveLocalizationsDelegates sync* {
    final localizationsDelegates = widget.localizationsDelegates;
    if (localizationsDelegates != null) {
      yield* localizationsDelegates;
    }
    yield GlobalUnaLocalizations.delegate;
    yield GlobalWidgetsLocalizations.delegate;
  }

  @override
  void dispose() {
    heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: widget.scrollBehavior,
      child: HeroControllerScope(
        controller: heroController,
        // Applied at once, with the previous frame faded out over it:
        // interpolating the theme instead rebuilds the whole app on every
        // frame of the transition.
        child: CrossFadeTheme(
          data: theme(context),
          curve: widget.themeCurve,
          child: MouseAreaSurface(
            child: MouseCursorProvider(
              child: Builder(
                builder: _buildApp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // One instance, not one per build: constructing a `ThemeData` derives
  // every component theme, and a new one each time is also a miss in the
  // form-factor cache and a full comparison in `CrossFadeTheme`.
  static final ThemeData _defaultLightTheme = ThemeData(
    brightness: Brightness.light,
  );

  ThemeData get effectiveLightTheme => widget.theme ?? _defaultLightTheme;

  ThemeData? get effectiveDarkTheme => widget.darkTheme;

  ThemeData theme(BuildContext context) {
    final mode = widget.themeMode ?? ThemeMode.system;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final useDarkStyle =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system && platformBrightness == Brightness.dark);

    final data = () {
      late ThemeData result;
      final lightTheme = effectiveLightTheme;
      if (useDarkStyle) {
        result = effectiveDarkTheme ?? lightTheme;
      } else {
        result = lightTheme;
      }
      return result;
    }();
    final formFactor =
        widget.formFactor ??
        (MediaQuery.sizeOf(context).width < data.breakpoints.md.value
            ? FormFactor.mobile
            : FormFactor.desktop);
    return data.withFormFactor(formFactor);
  }

  Widget _builder(BuildContext context, Widget? child) {
    return UnaAppBuilder(
      backgroundColor: widget.backgroundColor,
      builder: widget.builder,
      child: child,
    );
  }

  Widget _buildApp(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.type) {
      case UnaAppType.standard:
        if (usesRouter) {
          return DefaultStyles(
            data: theme,
            child: WidgetsApp.router(
              key: GlobalObjectKey(this),
              routeInformationProvider: widget.routeInformationProvider,
              routeInformationParser: widget.routeInformationParser,
              routerDelegate: widget.routerDelegate,
              routerConfig: widget.routerConfig,
              backButtonDispatcher: widget.backButtonDispatcher,
              onNavigationNotification: widget.onNavigationNotification,
              builder: _builder,
              title: widget.title,
              onGenerateTitle: widget.onGenerateTitle,
              color: widget.color ?? _defaultColor,
              locale: widget.locale,
              localeResolutionCallback: widget.localeResolutionCallback,
              localeListResolutionCallback: widget.localeListResolutionCallback,
              supportedLocales: widget.supportedLocales,
              showPerformanceOverlay: widget.showPerformanceOverlay,
              showSemanticsDebugger: widget.showSemanticsDebugger,
              debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
              shortcuts: widget.shortcuts,
              actions: widget.actions,
              restorationScopeId: widget.restorationScopeId,
              localizationsDelegates: effectiveLocalizationsDelegates,
              // A plain `Text` reads as body copy in the theme's own face,
              // the way it would under a Material `Scaffold`.
              textStyle: theme.textTheme.p.copyWith(
                color: theme.colorScheme.foreground,
              ),
            ),
          );
        }

        return DefaultStyles(
          data: theme,
          child: WidgetsApp(
            key: GlobalObjectKey(this),
            navigatorKey: widget.navigatorKey,
            navigatorObservers: widget.navigatorObservers!,
            home: widget.home,
            routes: widget.routes!,
            initialRoute: widget.initialRoute,
            onGenerateRoute: widget.onGenerateRoute,
            onGenerateInitialRoutes: widget.onGenerateInitialRoutes,
            onUnknownRoute: widget.onUnknownRoute,
            onNavigationNotification: widget.onNavigationNotification,
            builder: _builder,
            title: widget.title,
            onGenerateTitle: widget.onGenerateTitle,
            color: widget.color ?? _defaultColor,
            locale: widget.locale,
            localeResolutionCallback: widget.localeResolutionCallback,
            localeListResolutionCallback: widget.localeListResolutionCallback,
            supportedLocales: widget.supportedLocales,
            showPerformanceOverlay: widget.showPerformanceOverlay,
            showSemanticsDebugger: widget.showSemanticsDebugger,
            debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
            shortcuts: widget.shortcuts,
            actions: widget.actions,
            restorationScopeId: widget.restorationScopeId,
            localizationsDelegates: effectiveLocalizationsDelegates,
            // A plain `Text` reads as body copy in the theme's own face,
            // the way it would under a Material `Scaffold`.
            textStyle: theme.textTheme.p.copyWith(
              color: theme.colorScheme.foreground,
            ),
            pageRouteBuilder:
                widget.pageRouteBuilder ??
                <T>(RouteSettings settings, WidgetBuilder builder) =>
                    UnaPageRoute<T>(settings: settings, builder: builder),
          ),
        );
      case UnaAppType.custom:
        return DefaultStyles(
          data: theme,
          child: Builder(builder: widget.appBuilder!),
        );
    }
  }
}

/// Describes how [Scrollable] widgets behave for [UnaApp]s.
///
/// Vertical scrollables get a [Scrollbar] on every platform but Android
/// and Fuchsia, where scrollbars are not shown. On those two a scrollable
/// dragged past its end stretches, as it has on Android since version 12,
/// instead of showing the glow the widgets layer falls back to.
///
/// See also:
///
///  * [ScrollBehavior], the default scrolling behavior extended by this class.
class UnaScrollBehavior extends ScrollBehavior {
  /// Creates a UnaScrollBehavior that decorates vertical [Scrollable]s with
  /// a [Scrollbar] based on the current platform.
  const UnaScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        switch (getPlatform(context)) {
          case TargetPlatform.macOS:
          case TargetPlatform.iOS:
          case TargetPlatform.linux:
          case TargetPlatform.windows:
            return Scrollbar(controller: details.controller, child: child);
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
            return child;
        }
    }
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return child;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return StretchingOverscrollIndicator(
          axisDirection: details.direction,
          clipBehavior: details.decorationClipBehavior ?? Clip.hardEdge,
          child: child,
        );
    }
  }
}

// The WidgetsApp colour used for the app in the task switcher; Material's
// `Colors.blue`, which this default used to be.
const _defaultColor = Color(0xFF2196F3);

/// {@template UnaAppBuilder}
/// The builder for an `*App` instance.
///
/// Must be placed in the builder of the `*App` widget.
/// {@endtemplate}
class UnaAppBuilder extends StatelessWidget {
  /// {@macro UnaAppBuilder}
  const UnaAppBuilder({
    super.key,
    this.builder,
    this.child,
    this.backgroundColor,
  });

  /// Wraps the child with more widgets. See [WidgetsApp.builder].
  final TransitionBuilder? builder;

  /// The widget below this one, usually the app's [Navigator].
  final Widget? child;

  /// {@template UnaAppBuilder.backgroundColor}
  /// The background color of the page, defaults to `Theme.of(context).colorScheme.background`.
  /// {@endtemplate}
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // Why are we surrounding a builder with a builder?
    //
    // The widget.builder may contain code that invokes
    // Theme.of(), which should return the theme we selected
    // above in CrossFadeTheme. However, if we invoke
    // widget.builder() directly as the child of CrossFadeTheme
    // then there is no Context separating them, and the
    // widget.builder() will not find the theme. Therefore, we
    // surround widget.builder with yet another builder so that
    // a context separates them and Theme.of() correctly
    // resolves to the theme we passed to CrossFadeTheme.
    return Builder(
      builder: (BuildContext context) {
        // The `Toaster` goes around the [child], inside [builder], so that
        // any `InheritedWidget` the [builder] introduces (such as a
        // `Directionality`) is inherited by the toasts.
        final effectiveChild = child != null ? Toaster(child: child!) : child;
        return ColoredBox(
          color: backgroundColor ?? Theme.of(context).colorScheme.background,
          // The app-wide half of Liquid Glass: the package's accessibility
          // switch and, if the theme asks, its adaptive quality.
          child: switch (builder?.call(context, effectiveChild) ??
              effectiveChild) {
            null => null,
            final app => LiquidGlassAppScope(child: app),
          },
        );
      },
    );
  }
}

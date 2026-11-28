## 0.1.0

The first release of `una`, a fork of
[`shad`](https://pub.dev/packages/shad) 1.0.2. This entry describes the
package as it is, compared with shad.

It needs Flutter 3.50 or later (Dart 3.14).

The example app is the component library: a page per component and guide,
and a theme editor that restyles it live. Demo, the app the default look
was measured from (Strand, until it moved), is its own repository,
[una_demo](https://github.com/vlidholt/una_demo), deployed to
<https://vlidholt.github.io/una_demo/>.

### Changed from shad

#### Names and vocabulary

- **The `Shad` prefix is gone.** `ShadButton` is `Button`, `ShadTheme.of` is
  `Theme.of`, `ShadThemeData` is `ThemeData`. Names that would clash with
  Flutter's widgets layer keep a `Una` prefix: `UnaApp`,
  `UnaRow`, `UnaColumn`, `UnaPadding`, `UnaForm`,
  `UnaFormField`, `UnaTable`, `UnaBorder`, `UnaDecoration`,
  `UnaGestureDetector`, `UnaRadioGroup`, `UnaPageRoute`,
  `UnaMaterial` and a few more.
- **Flutter names where they exist.** `ShadInput` is `TextField`,
  `ShadInputFormField` is `TextFormField`, `ShadInputOTP` is `OtpField`,
  `ShadSeparator` is `Divider`, `ShadProgress` is `ProgressBar`,
  `ShadOption` is `SelectOption` and `ShadContextMenuItem` is `MenuItem`
  (`MenuItemVariant`), beside the new `MenuCheckboxItem`, `MenuRadioItem`,
  `MenuLabel`, `MenuDivider` and `MenuShortcut`. Their themes follow
  (`ThemeData.textFieldTheme`, `dividerTheme`, `progressBarTheme`, …).
- **Everything `@Deprecated` in shad 1.0 is removed**, along with its
  data-driven fixes. There are no deprecation shims for the renames below.
- **Flutter's `WidgetState`, not a state enum of our own.** `ShadState` and
  `ShadStatesController` are gone. `Button`, `IconButton` and `Toggle` take
  Flutter's `WidgetStatesController`, and the states are
  `WidgetState.hovered`, `pressed`, `focused`, `disabled` and `selected`,
  the vocabulary every pressable widget uses. `WidgetStatesController`
  changes its `value` set in place before it notifies, where
  `ShadStatesController` assigned a new set, so a listener that compares
  against the previous states keeps its own copy of them.
- **`ShadAppType.shadcn` is `UnaAppType.standard`**, the app
  `UnaApp.new` and `UnaApp.router` build.
- **No `.raw` constructors.** `Button`, `IconButton`, `Badge`, `Toggle`,
  `Dialog`, `Alert`, `UnaTableCell` and `MenuItem` take `variant:` on
  their unnamed constructor; the named ones (`Button.outline`,
  `Badge.secondary`, `Dialog.alert`, `MenuItem.inset`, …) are shortcuts.
  `Select()` takes `SelectVariant.primary` or `.search` and
  `Select.multiple()` takes `.multiple` or `.multipleWithSearch`; the select
  form fields follow. `Divider()` is the horizontal line (`Divider.vertical()`
  stays).
- **A `BorderRadius` is `borderRadius`**: on `Card`, `Dialog`, `Divider`,
  `Menubar`, `SelectOption`, `Skeleton`, `Sheet`, their themes, the themes
  of `Chip`, `Glass`, `IconTile`, `ListSection`, `ListTile`, the bottom
  navigation bar and the floating action button, and on `UnaBorder`.
  Named corners follow (`Command.itemBorderRadius`,
  `OtpFieldSlot.firstBorderRadius`, `CalendarTheme.dayButtonBorderRadius`,
  `SheetTheme.dragHandleBorderRadius`, `SidebarTheme.menuButtonBorderRadius`
  and the rest). `ThemeData.radius`, the design token, keeps its name.
- **`cursor` is `mouseCursor`** (`Button`, `IconButton`, `Pressable`,
  `UnaGestureDetector`, their themes, `MenubarTheme.buttonMouseCursor`,
  `TabsTheme.tabMouseCursor`) and `onHoverChange` is `onHover`.
- **Open state has one vocabulary.** `Popover`, `ContextMenu` and
  `ContextMenuRegion` take `open:` (was `visible:`); `onOpenChange` is
  `onOpenChanged`; `SidebarScaffold.defaultOpen` is `initiallyOpen`.
  Controllers have `isOpen`, `open()`, `close()`, `toggle()` and
  `setOpen(bool)`: `PopoverController.show`/`hide` are `open`/`close`, and
  `CollapsibleController` and `SidebarController` lose their settable
  `open` (`SidebarController.openMobile` is `isMobileOpen`, with
  `openMobile()`, `closeMobile()` and `setMobileOpen(bool)`).
- **`onTap`, not `onPressed`**, on `Card`, `TextField`, `Textarea`, `Select`
  and their form fields; the text fields' `onPressedAlwaysCalled` and
  `onPressedOutside` are `onTapAlwaysCalled` and `onTapOutside`.
- **Icons are widgets.** `AccordionItem.iconData`,
  `ResizablePanelGroup.handleIconData` and `Dialog.closeIconData` are gone;
  `AccordionTheme.icon`, `ResizableTheme.handleIcon` and
  `CalendarTheme.backNavigationButtonIcon`/`forwardNavigationButtonIcon`
  are const widgets. The calendar's carets follow the text direction when
  the theme gives none.
- **No `textDirection` parameters** on `Alert`, `Breadcrumb`, `Button`,
  `ResizablePanelGroup`, `RovingFocus` or the button, menubar and resizable
  themes, and no `SelectOption.direction`: wrap in a `Directionality`.
- **Smaller renames.** `Popover(popover:)` is `Popover(builder:)`.
  `Command.onItemSelected` is `onSelected`.
  `ProgressBar.semanticsLabel`/`semanticsValue` and
  `StreamingText.semanticsLabel` are `semanticLabel`/`semanticValue`; a
  determinate bar announces its percentage by default, as a `ProgressRing`
  does. `ProgressBar.backgroundColor` and `minHeight` are `trackColor` and
  `height` (the bar's height, not a floor), also on `ProgressBarTheme`.
  `SidebarMenuButton.isActive` and `SidebarMenuSubButton.isActive` are
  `selected`. `Calendar.hideNavigation`/`hideWeekdayNames` are
  `showNavigation`/`showWeekdayNames` (default true), also on
  `CalendarTheme`. `Disabled(disabled:)` is `Disabled(enabled:)`, inverted.
  `sublabel` is `description` and `direction` is
  `controlAffinity` (`ControlAffinity`) on checkboxes, radios and switches.
- **A smaller public surface.** The barrel no longer exports state classes
  (`AccordionState`, `CollapsibleState`, `ContextMenuState`, `CommandState`,
  `OtpFieldState`, `SelectState`, every `*FormFieldState`), render objects
  or plumbing (`SurfacePainter`, `MouseAreaSurface`, `PopoverTapGroups`,
  `DefaultResizeGrip`, `PanelInfo`, `ResizeResult`,
  `IndeterminateProgressBar`, `DeterminateProgressBar`; use
  `ProgressBar`). The exported names are pinned by a test.

#### Look and theme

- **A new default look.** `ThemeData()` is the `fluid` style on the
  `SlateColorScheme`: 10-point controls, 18-point translucent cards, bars
  and menus of frosted glass, soft tinted shadows. Pass
  `style: StyleTokens.crisp` and
  `colorScheme: const GraphiteColorScheme.light()` for the classic
  shadcn/ui look.
- **Four styles, renamed.** `fluid` (the default, measured from the Demo
  designs), and `crisp`, `pebble` and `sharp`, made from shadcn's Nova,
  Maia and Lyra; `StyleTokens.fluidMobile` is Fluid's phone metrics. Every
  token a style sets can be set on its own through `StyleTokens.copyWith`.
- **Seven colour schemes instead of shadcn's palettes and accents.**
  `ColorSchemes` lists `slate` (the default, a quiet slate blue — what
  `ColorScheme.fromSeed` makes of Tailwind's slate-500), `ocean` (a
  standard blue), `graphite`
  (monochrome), `forest`, `iris`, `ember` and `rose`, each a light and a
  dark palette setting every token. They are generated from one ladder of
  lightness (`scripts/generate_color_schemes.dart`), so none is louder or
  more washed out than another — shadcn's seventeen accents ranged from a
  near-white yellow to a near-black violet. `BlueColorScheme`,
  `NeutralColorScheme`, `ZincColorScheme`, `StoneColorScheme`,
  `AccentScheme` and `applyAccentScheme` are gone; change any colour with
  `copyWith`, or the accent from one colour with `applyAccent`.
- **`ColorScheme.applyAccent` moves the tint as well as the primary.** With
  a colour that reads against both the background and the card (a contrast
  of at least 4.5:1), `tint` becomes that colour, `tintForeground` its
  foreground and `accentBorder` the tint at 32%. A colour too faint for
  that leaves the three alone.
- **Icons are Phosphor**, not Lucide, and they ship in the package: all six
  weights (`PhosphorIconsRegular`, `Bold`, `Fill`, `Light`, `Thin` and
  `PhosphorIconsDuotone` with `PhosphorDuotoneIcon`) with no extra
  dependency. The fonts are MIT licensed; the notice is in `LICENSE` and
  reaches an app's licence page automatically. The components draw their
  icons with `PhosphorIcon`: in a test, `find.byType(Icon)` does not find
  them (use `find.bySubtype<Icon>()`), and a thickened icon has no
  `RichText` beneath it.
- **Floating surfaces are glass in the default style.** Popovers, menus, a
  select's list, the command palette, tooltips and toasts are translucent
  over a blurred backdrop (`StyleTokens.popoverOpacity` and
  `tooltipOpacity`); they stay solid in `crisp`, `pebble` and `sharp`.
  `ThemeData.menuTranslucent` is three-state: null follows the style, true
  is shadcn's 70% finish and false keeps menus solid. A tooltip's arrow is
  part of the bubble's outline. A toast is a popover surface in every
  style: it takes the scheme's `popover` and `popoverForeground` colours.
- **Cards do not blur.** They stay translucent, but a backdrop filter per
  card is paid on every frame; opt in with
  `StyleTokens.fluid.copyWith(cardBlur: true)` or `CardTheme(blur: …)`.
- **Menu highlights are a wash in the default style.** The highlighted row
  of a menu, a `Select` and the `Command` palette is tinted with the menu's
  own foreground (`StyleTokens.menuHighlightOpacity`, 6% on a light menu and
  9% on a dark one) and its text and icons keep their colour. `crisp`,
  `pebble` and `sharp` keep the accent fill.
- **`ThemeData.menuAccent` changes menus only.** `MenuAccent.bold` fills
  the highlighted row of a menu with the primary colour and leaves the
  colour scheme alone; in shad it rewrote the scheme's accent pair, which
  also recoloured selected chips, cards, sidebar rows and icon tiles.
- **Table rows are lighter.** Row hover is a faint wash and a selected row
  is tinted (`TableTheme.rowHoverColor`, `rowSelectedColor`, `footerColor`,
  `footerHoverColor`); `DataTable` fills its selected rows.
- **Themes switch instead of interpolating.** `UnaApp` applies a new
  theme in one build and cross-fades the previous frame out over it
  (`CrossFadeTheme`); `AnimatedTheme` remains for an explicit lerp.
- **A custom `ThemeVariant`** has to implement a method for every component
  theme, the new ones included, and `TextTheme.custom` requires a `caption`
  style.

#### Motion

- **Motion comes from the theme, and `flutter_animate` is gone.** No
  component takes `effects`, `duration`, `curve` or a reverse duration, and
  no theme holds an entrance: removed are `effects` on `Popover`,
  `ContextMenu`, `ContextMenuRegion`, `Select`, `AccordionItem`
  (`iconEffects` too) and their themes; `reverseDuration` and
  `popoverReverseDuration` on the overlays and their themes;
  `duration`/`curve` on the accordion, collapsible, checkbox, radio and
  switch and their themes; `showDialog(animateIn:, animateOut:, variant:)`
  and `DialogTheme.animateIn`/`animateOut`; `Toast` and `Toaster` motion
  parameters; and `EntranceEffect`, `SizeEffect`, `PaddingEffect`,
  `AnimEffect` and the `flutter_animate` re-export. Overlays grow from
  their anchor and leave in `Motion.fast`; set `ThemeData(motion:)` on a
  subtree for different motion, `Motion.none` for none.
- **Controls respond to a press.** Buttons, toggles, cards, list tiles and
  anything built on `Pressable` scale slightly while pressed and fade
  between their state colours; `ButtonTheme(pressScale: 1)` switches it off
  for one button. Menu rows, select options and command items are the
  exception: their highlight changes at once.
- **A selection travels instead of jumping.** The selected tab no longer
  paints its own fill and shadow, and a menubar trigger no longer paints
  its own highlight: the list paints one indicator that moves between them.
- **Smaller changes in behaviour.** A tooltip fades out instead of
  vanishing. `UnaPageRoute` slides as well as fades. `Skeleton`
  shimmers in the default style and holds still under reduced motion.
  `FocusRing` and `IndicatorBadge` keep the same tree shape whether shown
  or hidden.

#### Buttons and pressing

- **`Button`, `IconButton` and `Toggle` are built on `Pressable`** and take
  one `style` (a `ButtonTheme`, or a `ToggleTheme` for a toggle, merged
  over the variant's) in place of some thirty colour, size and decoration
  parameters (`width`, `height`, `padding`, `gap`, `iconSize`, the
  background and foreground colours per state, `decoration`, `shadows`,
  `gradient`, `textStyle`, `pressScale`, …). A `MenuItem`, a row that is a
  button, likewise takes one `style` (a `ContextMenuTheme`, merged over
  the theme's) in place of `padding`, `insetPadding`, `leadingPadding`,
  `trailingPadding`, `height`, `buttonVariant`, `decoration`, the text
  styles, the background colours, `anchor`, `showDelay`, `constraints` and
  `subMenuPadding`. A `Card` takes one `style` (a `CardTheme`) in place of
  `padding`, `width`, `height`, `backgroundColor`, `borderRadius`,
  `border`, `shadows`, `clipBehavior`, `gap`, `sectionGap`, `titleStyle`,
  `descriptionStyle` and the six `row*`/`column*` alignment and size
  parameters. `Dialog` and `Sheet` take a `style` (a `DialogTheme`, a
  `SheetTheme`) for their size, padding, gaps, fill, filter, border,
  corners, shadows, text styles and alignment, the layout of a dialog's
  actions and where the close button sits; what they show and how they
  behave (`scrollable`, `useSafeArea`, the `*Pinned` flags, detents,
  dragging, the close button itself) stay parameters. `DialogTheme` gains
  `filter`.
- **Rarer gestures are not button parameters.** Double tap, secondary tap,
  tap down and the long-press phases are a `UnaGestureDetector` around
  the button. `hoverStrategies` and `longPressDuration` are gone from
  buttons, tabs, the menubar and the tooltip, and `HoverStrategies`,
  `HoverStrategy` and `ThemeData.hoverStrategies` with them: a press
  standing in for hover on a touch screen is built into
  `UnaGestureDetector`, and the tooltip has its own long press.
  `Button.canRequestFocus` is gone (pass a `focusNode`, or `ExcludeFocus`).
- **A button with nothing to do is disabled.** A `Button` or `IconButton`
  with no `onPressed`, no `onLongPress` and not loading is dimmed by
  `ThemeData.disabledOpacity`, is no Tab stop and has no hover or click
  cursor, as a `Toggle`, `Chip`, `ListTile` or FAB with no callback. The
  current page of a `Pagination` keeps a callback, so it stays a Tab stop.
  `IconButton` is a `StatefulWidget`.
- **`ButtonSize.icon` is removed**: use `IconButton`, sized from the
  theme's square sizes for `sm`, `regular` and `lg`.
- **`Badge` is a static pill.** `onPressed`, `enabled`,
  `hoverBackgroundColor` and `mouseCursor` are removed from it and from
  `BadgeTheme`; a pressable pill is a `Chip`. `shape` is `borderRadius`
  (null is a pill), on `Badge` and `BadgeTheme`, and the theme's outline
  is `BadgeTheme.borderColor`.
- **`UnaGestureDetector` reports true global positions.** It used to
  rewrite `globalPosition` to be overlay-local inside a nested navigator
  (the shad #319 workaround); `GlobalAnchor.offset` is global as
  documented, and the portal converts it.

#### Overlays

- **One `PopoverController`** drives popovers, context menus, tooltips and
  hover cards; `TooltipController` and `UnaContextMenuController` are
  gone (`openAt(Offset)` replaces `showAt`).
- **Tap-region plumbing is internal.** `Popover.areaGroupId` and
  `useSameGroupIdForChild`, the context menus' `groupId`, `onHoverArea`
  and `onTapOutside`/`Inside`/`UpInside`/`UpOutside`, and `groupId` on
  `Select`, `Calendar` and `TimeField` are gone: a popover opened inside
  another joins its tap region by itself. `Popover.groupId` stays, for a
  text field that keeps its focus through a tap on the popover.
- **Dialogs have no close button by default.** Pass
  `showCloseButton: true` (with `closeIcon` for another glyph, or
  `closeButton` to replace the whole button), or set it on the dialog
  theme. Sheets keep theirs. A tap on the barrier and Escape still dismiss.
  What the close button does instead of popping is `onDismissed`, on
  `Dialog` and `Sheet` alike, the name `Alert` and `Toast` use for being
  dismissed.
  On a phone a dialog's actions stack full-width from the form factor;
  `expandActionsWhenTiny` and `removeBorderRadiusWhenTiny` are gone.
- **Popovers and the keyboard focus.** A popover gives the focus back when
  it is closed, not when its exit has finished, and its child and its
  content are one focus traversal group, the child first.
  `Popover.focusNode` is removed; `DatePicker.focusNode` is the trigger's.
- **A tooltip's arrow sits on the edge that faces its trigger** by default.
- **One toast system.** `ShadSonner`, `ShadToaster` and their scopes,
  states and themes are one `Toaster` that `UnaApp` provides:
  `Toaster.of(context).show(Toast(...))` returns an id for `update`,
  `dismiss` and `dismissAll`. `Toast` takes `title`, `description`,
  `leading`, `action`, `variant` (`ToastVariant.neutral`, `success`,
  `warning`, `destructive`, `loading`), `duration`, `dismissible` and
  `onDismissed`; `Toast.destructive` and `Toast.raw` are gone, and
  `ThemeData.toastTheme`/`toasterTheme` replace `primaryToastTheme`,
  `destructiveToastTheme` and `sonnerTheme`.
- **Sheets rest on detents.** `Sheet` takes `detents` (`SheetDetent.content`,
  `medium`, `large`, `full`, `fraction`, `height`) and a `SheetController`
  that moves between them, and can be dragged from its content; the old
  sizing, snapping, animation and alignment parameters (`expandable`,
  `initialSize`, `minSize`, `maxSize`, `snap*`, `isScrollControlled`,
  `animationController`, `dragHandleBuilder`, `onSizeChanged`, …) are
  gone. `showSheet` takes `dismissible` (was `isDismissible`) and a
  `builder` that returns the `Sheet`; `closeIcon: SizedBox.shrink()` is
  `showCloseButton: false`. `MenubarItem` takes only `child`, `items`,
  `leading`, `trailing`, `enabled` and `focusNode`.

#### Inputs and pickers

- **Value controls are controlled.** `value` + `onChanged`, or
  `initialValue` for a widget that holds its own state: `Slider` and
  `RangeSlider` (their controllers are gone; `Slider.label` is
  `semanticLabel`), `UnaRadioGroup` (`RadioController` is gone),
  `ToggleGroup` (`ToggleGroupController` is gone), `Select`
  (`SelectController` is gone, `popoverController` is `controller`),
  `Calendar` (`selected` is `value`, `.range` takes `range`,
  `fromMonth`/`toMonth` are `min`/`max`), `DatePicker` (`selected` is
  `value`) and `OtpField` (`onChanged` reports the user's edits only).
- **One value, or a set.** The unnamed constructor of `Select`,
  `Calendar`, `ToggleGroup` and `ChipGroup` holds one value (`value`,
  `initialValue`, `onChanged`) and `.multiple` a set (`values`,
  `initialValues`, `onValuesChanged`): `Select.multiple` reports through
  `onValuesChanged`, and a single `ToggleGroup` takes a `T?`, not a set of
  at most one; `Accordion.multiple` takes `initialValues`. `ToggleGroup`
  takes `items` (was `children`) and `variant` (was `toggleVariant`);
  `ToggleGroupVariant` is gone. Whether the selection may become empty is
  `allowDeselection` everywhere, on
  `TimePicker` (from `TimePickerTheme.allowDeselection`, true in every
  style, so a time can be cleared by default) as on `DatePicker`; in a
  `Select.multiple` it keeps the last option rather than every one.
- **A null callback disables a control.** A `ToggleGroup`, a
  `UnaRadioGroup` or a `Select` with no callback (a select with an
  `onTap` excepted) is drawn disabled
  and takes no input, as a `Toggle`, a `Chip` or a `SegmentedControl` is.
- **Pickers.** The inline time picker is `TimeField` (`TimeFieldTheme`,
  `TimeFormField`); `TimePicker` is now a trigger that opens it in a
  popover, or wheels in a sheet on a phone, and `TimePickerFormField` is
  that picker's field. `DatePicker.range` is `DateRangePicker`.
  `TimePickerController`, `TimePickerField`, `TimePickerVariant`,
  `DatePicker.raw` and `DatePickerVariant` are gone, as are the
  parameters the date picker forwarded to its button and calendar;
  `closeOnSelection` defaults to true and `DatePickerTheme` has eight
  fields. `TimeOfDay` has no `period` argument and its `second` is
  optional. The calendar's styling moved to `CalendarTheme`.
  `TimeField.onChanged` takes a `TimeOfDay?`: it reports null when a field
  of a complete time is emptied.
- **Picker triggers are fields.** `DatePicker`, `DateRangePicker` and
  `TimePicker` look like a text field by default; `variant:` (or the
  theme's `buttonVariant`, now null by default) makes them a button.
- **Text fields on a touch screen** have selection handles, a horizontal
  toolbar and a magnifier by default: `magnifierConfiguration` null is
  `TextMagnifier.adaptiveConfiguration`, `selectionControls` null is
  `UnaTextSelectionControls.adaptive`, and
  `TextFieldState.defaultContextMenuBuilder` returns the horizontal toolbar
  on iOS and Android.
- **Tabs are value-based.** `TabBar<T>` takes `tabs: [Tab(value:, child:)]`,
  `value` and `onChanged`, in an underline or a segmented look; `Tab` is a
  data class, not a widget (its forwarded button parameters are gone).
  `Tabs<T>` is a tab bar over swipeable content, and lost `tabsGap`,
  `dragStartBehavior`, `physics`, `padding`, `decoration`,
  `tabBarConstraints` and `contentConstraints`. `TabsController.selected`
  is `value`. A tab bar is one Tab stop; the arrows move the selection. A
  segmented strip is as wide as its tabs unless `expandTabs` is set, and
  `tabAlignment` places it — on `TabBar`, `Tabs` and `TabsTheme` alike
  (`TabsTheme.tabBarAlignment` is `tabAlignment`); `showBorder` drops the
  hairline under an underline bar on both. A tab's label ends in an
  ellipsis when its tab is too narrow. A `Tabs` controlled by `value`
  selects a tab only once the value names it, and without `onChanged` (or
  a `controller`) its tabs are inert, as a `TabBar`'s are.

### Added

- **A Liquid Glass option on the bar itself.** `AppBar.liquidGlass` and
  `SliverAppBar.liquidGlass` choose per bar, over `AppBarTheme.liquidGlass`.
  `LiquidGlassMode.always` gives a transparent bar with its buttons on
  capsules of glass on any platform and form factor.
- **The soft scroll edge in a browser, on request.** A browser cannot draw
  the graduated blur under a Liquid Glass bar, so by default the bar is
  solid there, as before. `LiquidGlassTheme.webScrollEdge` (or a bar asking
  for `LiquidGlassMode.always`) draws it with una's own fragment shader
  (`shaders/scroll_edge.frag`) over a third-resolution snapshot of the
  `Scaffold`'s body, taken while the frame's scene is built: the page under
  the bar blurred more the nearer it is to the top and faded into the page
  colour, with no line where it ends, over a list or a picture at the top
  of the page alike. The snapshot costs a copy of that strip every frame
  the edge shows, which is why it is not the default.
- **A detached action on the floating bottom bar.**
  `BottomNavigationBar.actionPlacement` /
  `BottomNavigationBarTheme.actionPlacement`:
  `NavigationActionPlacement.detached` puts the `NavigationAction` on a
  disc of its own at the end of the bar and the destinations on a pill as
  wide as they are — iOS 26's split bar, as on Liquid Glass — in una's
  frosted glass too.
- **Spinners.** `Spinner` defaults to the progress ring's look, and
  `SpinnerVariant` adds `orbit` (three comets that bunch and fling apart),
  `morph` (a blob turning through six shapes), `goo` (droplets pushed
  out on stretching necks and pulled back in) and `halo` (a ring of dots
  with a wave of light running round it, each swelling and glowing as it
  passes); `Spinner.orbit`, `.morph`, `.goo`, `.halo` and
  `SpinnerTheme.variant`. Each is one painter on one clock;
  under reduced motion they hold still and breathe.
- **Skeleton shapes.** `Skeleton.avatar`, `Skeleton.button`,
  `Skeleton.chip`, `SkeletonText`, `SkeletonListTile`, `SkeletonCard`,
  `SkeletonChatBubble` and `SkeletonTableRow`, sized from the real
  components' themes.
- **`SwipeActionsTheme`** (`edgeShadowColor`, `edgeShadowWidth`): a row
  casts a soft shadow onto the actions it uncovers, stronger in dark
  themes, and none at rest.
- **`GlassLevel.bar`**: the bars' own glass for a panel beside them — the
  bottom bar's tint frosted, its untinted glass on Liquid Glass — so a
  player above a tab bar reads as one of the bars.
- **A page's own bar finds the shell's drawer.** A page with its own
  `Scaffold` inside a navigator inside another scaffold — a destination
  with its own stack of pages — shows the menu button for the outer
  scaffold's drawer (and end drawer) on its root page, and the back
  button above it. The app-structure guide has the recipe for a stack per
  destination with URLs (`UnaApp.router`, `StatefulShellRoute`,
  `UnaPage`).

#### Liquid Glass

- **Liquid Glass on iOS and macOS**, natively and in a browser, through
  [`liquid_glass_widgets`](https://pub.dev/packages/liquid_glass_widgets)
  (now a dependency, with `cupertino_icons`). `ThemeData(liquidGlass:
  LiquidGlassTheme(...))` decides where: `LiquidGlassMode.auto` (the
  default) is Liquid Glass on Apple platforms and una's frosted glass
  elsewhere; `always` and `never` decide for every platform. Each component
  that switches has a nullable `liquidGlass` on its component theme that
  wins over the theme's.
- **What switches:** `AppBar` on a phone or a tablet (no fill and no
  hairline; the content under it is blurred more the nearer the top and
  faded into the page, a little past the bar's bottom; a leading button and
  the actions on glass capsules, a logo bare — a desktop's top bar stays
  solid unless `AppBarTheme.liquidGlass` is `always`), the floating
  `BottomNavigationBar` (the package's tab bar,
  with a lens that slides between tabs and the `action` on its own capsule
  beside them), `Toolbar`, `NavigationRail`, a glass `FloatingActionButton`,
  `Glass`, popovers, menus, a select's list, `Surface`, `Command` in a
  dialog, `Dialog`, `Sheet`, toasts, and the lens controls `Switch`,
  `Slider` and `SegmentedControl`. Tooltips, cards, list tiles, fields and
  content buttons stay as they are.
- `LiquidGlassTheme` passes on the package's options: `style`
  (`GlassStyle.ios27` or `ios26`), `quality` (`GlassQuality`),
  `adaptiveQuality`, `respectSystemAccessibility`, and `light`/`dark`
  `GlassThemeSettings`. The glass is tinted from the scheme's `bar` colour
  unless `tintFromColorScheme` is false.
- **On a phone or a tablet a menu morphs out of its trigger** — a
  `DropdownMenu` or a root `ContextMenu` opened at its own anchor — through
  the package's `GlassPopover`, still opened and closed by its
  `PopoverController`. A desktop menu, a right-click or long-press menu
  and a submenu are una's popovers on glass.
- **Without shader filters** (every browser, Skia) the package draws a
  lighter glass whose blur and rim do little over a light page. una
  gives overlays there a stronger blur and a whitened body and keeps its
  own hairline round them. A phone's or tablet's top bar that would be
  Liquid Glass is solid there instead: the bar colour at full opacity with
  its hairline, no blur, no scroll edge and no capsules, at rest too. A
  graduated blur built from backdrop filters showed bands and cost every
  frame of a scroll on an iPhone; native keeps the package's graduated
  blur. A blur too faint to see (the
  iOS presets' 0.6) is dropped there rather than costing a backdrop pass
  under every capsule, bar and control.
- **A bar picks its buttons' look.** `Button.variant` and
  `IconButton.variant` are nullable: null is primary, except in an
  `AppBar`'s or `SliverAppBar`'s toolbar, where the bar gives the look for
  what it is drawn on — ghost on its own surface (frosted or solid), ghost
  on a capsule of Liquid Glass, outline over a `SliverAppBar.background`
  picture. `BackButton` and `CloseButton` follow it too. An app writes
  `IconButton(icon: …)` and never asks which material the bar is on; a
  named variant is kept. A menu opened from a bar button is not the bar's.
  A bare (ghost) icon button at either end of a bar — also an explicit
  `leading`, also inside an `IndicatorBadge`, `Tooltip` or
  `RepaintBoundary` — stands with its glyph, not its box, on the bar's
  margin; a button with a surface, and a capsule of glass, with its edge.
- **`ColorPicker` has iOS's three modes** (`ColorPickerMode`): the
  spectrum, a grid of twelve hues in nine shades under a row of greys
  (tap or drag; the arrow keys move between cells), and red, green and
  blue sliders with their values, switched by a segmented control that
  spans the picker on a phone and sits centred on a desktop. `modes`
  picks which are offered. A null `onChanged` disables the picker, and
  its swatches are a finger's size on a phone. The example's theme
  editor uses it for a custom accent colour, exported as
  `applyAccent`.
- **The theme editor edits everything.** Pick one of eighteen colours in
  Tailwind's order — Slate, Graphite, then red around the wheel to rose,
  seven of them the built-in schemes and the rest seeds — or a chart
  palette, then any of its colours (a colour picked in light mode carries
  over to dark, adjusted to the dark palette, until one is picked there),
  and every field of the style under "All settings", grouped and
  searchable, for the form factor the app shows. Liquid Glass Auto / On /
  Off sits with the other preview settings.
- **The selected tab shows in every style.** Crisp, Pebble and Sharp drew
  the selected segment in the page colour, a grey here nearly the strip's
  own; it takes the card colour in light and a lifted wash in dark.
- **A menu's first and last rows follow its corners**, so a phone's menu,
  rounded to 24, has no square highlight at its ends; a `Select`'s option
  list too.
- **A Liquid Glass bottom bar with no `action` stays at the bottom**; it
  took the whole height of its slot and sat mid-screen.
- **`ColorScheme.fromSeed`**: a whole scheme from one colour, made the
  way the seven built-in schemes are (Ocean's lightness, the seed's hue), so
  any seed gets their contrast; a grey seed gives a monochrome scheme. A
  `neutral` sets the greys' colour on its own.
- **`ControlSize.sm`** on `NumberField`, `Select` and `SegmentedControl`:
  a small button's height, padding and text, for dense panels. A small
  number field puts its minus and plus at the two ends on every form
  factor.
- **A sidebar's phone sheet follows a sidebar that changes** while it is
  open (a search typed into it, a group opened in it).
- **The example opens on a showcase** — the components as pieces of real
  screens, under a header that restyles the app — with the editor open
  beside it on a desktop; Showcase and Components are tabs in the top bar,
  the floating bar on a phone. The reference is grouped into categories.
  The editor opens on the four looks and Liquid Glass, then a colour
  (twenty-one swatches, or any) and a neutral; it shows the key
  colours with the rest a fold away, uses the small controls, treats a
  value set back to its original as no edit, and shows its code
  highlighted.
- **In a browser the top bar is the filled one** unless its theme asks
  for Liquid Glass with `always`: a page there has no status bar for the
  glass capsules to hang under. A large `SliverAppBar` over a picture
  keeps its toolbar filled at rest there, the picture starting below it.
- **No flicker on hover.** `AnimatedColorBuilder` (and so every button,
  toggle and chip fill) cross-fades premultiplied: between Fluid's glass
  outline button and its hover wash, `Color.lerp` painted a half-opaque
  mid-grey for a frame or two.
- **A Liquid Glass slider in a short row keeps its thumb on its track.**
  The package's slider places its thumb for its own height; squeezed, the
  thumb sat below the track.
- **A docked bottom bar on Liquid Glass is the page's scroll edge**
  (blurred and faded from the bottom up, the controls standing on it), not
  a slab of glass; without shader filters it is solid, as the top bar is.
- **A large bar's picture goes with the page.** `SliverAppBar.background`
  fades out as the bar collapses and the collapsed bar is its own
  surface, filled or on glass; there is no option to keep the picture
  behind the toolbar, which left it a grey slab or a toolbar with nothing
  to stand on.
- **A sliver bar's scroll edge on Liquid Glass is the collapsed bar's
  height and reaches below it.** It was stretched over the whole
  expanded box and clipped to the visible bar, so collapsed it showed
  only its strongest blur, cut off on a line.
- **A large bar's titles stand on the page colour over its picture.** The
  page colour is painted behind the title and subtitle and rises a short
  fade into the `background` above them, measured from the titles rather
  than as fractions of the bar, so a two-line name or headline is never
  set on the photograph itself.
- **A bar's capsule of glass does not clip**, so a badge on its last
  button hangs over the capsule's end as on iOS 26 instead of being cut
  off; the buttons on it are round, so their fills stay inside its ends.
- **The bottom bar's tabs keep their own width**: the capsule hugs them,
  with the free space between it and the `action`, as on iOS 26, and it is
  centred when there is no action. A screen that is none of the
  destinations keeps the glass bar, with no lens.
- A bar on glass with no status bar above it (a browser, a desktop
  window) keeps a small gap above its buttons.
- `LiquidGlass.initialize()` keeps the package's progress messages
  (`[LiquidGlass] Initializing library...`, `Created web shader...`) out
  of the console.
- The example's theme editor has a Liquid Glass toggle (Auto / On / Off)
  that previews it on any platform.
- `LiquidGlass.initialize()` loads the shaders before the first frame; if
  they fail to load, una falls back to frosted glass. Under Increase
  Contrast una draws frosted glass.
- **The phone metrics of `StyleTokens.fluid` are Liquid Glass's**, so a
  phone layout is the same frosted or liquid: a 44-point app bar (was 60),
  a 64-point bottom bar (item height 52, was 48), a 58 × 26 switch (was
  44 × 24), a 28-point slider thumb (was 22), and 24-point corners on
  popovers and dialogs (`RadiusToken.xl4`; were `lg` and `xl3`). Desktop
  metrics and the shadcn styles are unchanged.

#### App and screen structure

- **Form factors.** Every style carries metrics for a desktop and for a
  phone. `UnaApp` picks between them from the window width (or
  `formFactor:` pins one), so the same widgets get 44-point touch targets,
  15-point body text and tighter page margins on a narrow screen.
  `ThemeData.formFactor`, `ThemeData.withFormFactor`, `FormFactorBuilder`.
- **Layout from the theme.** A named gap scale (`GapSize`, `Gap.md()`,
  `UnaRow(gap: GapSize.lg)`), `PageContainer` for page margins and
  maximum width, and `ThemeData.layoutTheme`.
- `Scaffold`: `appBar`, `body`, `bottomNavigationBar`, `footer`,
  `bottomSheet`, `banner`, `floatingActionButton`
  (`FloatingActionButtonLocation`), `drawer` and `endDrawer` with an edge
  drag, `resizeToAvoidBottomInset`, `systemOverlayStyle`,
  `Scaffold.of`/`ScaffoldState`. The bars lie over the body, which is
  inset by their measured heights from the first frame.
- `AppBar` (`bottom`, `centerTitle`, `surfaceBehavior`, an implied back,
  close or menu button and an implied end-drawer button) and
  `SliverAppBar` / `SliverAppBar.large`, a collapsing bar with a large
  title. `BackButton`, `CloseButton`.
- `FloatingActionButton` (primary, secondary or glass; small, regular or
  large; `extended`) and `FloatingActionButtonTheme`.
- `Toolbar`, `ListDetailLayout` (a list beside its detail, or a nested
  navigator on a phone) and `OverlayInsets`/`OverlayInsetsScope`, which
  tell floating things how much of each screen edge the bars cover.

#### Navigation

- `NavigationBar` for the top of a wide screen, a floating
  `BottomNavigationBar` for a phone (`showLabels`), `NavigationRail`
  (`NavigationRailTheme`; translucent, and frosted only with `blur`) and
  `NavigationScaffold`, which places them by
  `layout` (`NavigationLayout.auto`, `bottomBar`, `topBar`, `rail`).
  `NavigationDestination.showInRail`.
- `DestinationStack`: the destinations' pages, each built on first visit
  and kept alive.
- `NavigationMenu`, `NavigationMenuItem`, `NavigationMenuLink`,
  `NavigationMenuTheme`: a site navigation bar with panels.
- `TabBar`, `Tab`, `TabBarView` (swipeable pages keyed by value),
  `TabsController` (shared by a bar and its view, with `swipePosition`),
  `RestorableTabsController` (saved as the index of its tab, so a value of
  any type is restored),
  `SegmentedControl`, `Segment`, `SegmentedControlFormField`.
- Back gestures on `UnaPageRoute`: the iOS edge swipe and Android's
  predictive back preview (`backGesture`), and `UnaPage` for the
  pages API. `UnaScrollBehavior` stretches on Android.

#### Overlays and sheets

- `Sheet` on detents, from any edge, as a route (`showSheet`) or inline
  (`Scaffold.bottomSheet`), with a drag handle; `Sheet.closeButton`.
- `ActionSheet`, `showActionSheet`, `ActionSheetAction`, `ActionSheetTheme`.
- Menu rows: `MenuCheckboxItem`, `MenuRadioGroup`/`MenuRadioItem`,
  `MenuLabel`, `MenuDivider`, `MenuShortcut`, `MenuItem.shortcut` and
  `value`, and `showMenu` at a point or under a rectangle. Menus carry
  semantics roles (`menu`, `menuItem`, `menuItemCheckbox`,
  `menuItemRadio`, `menuBar`).
- `Popover(showArrow:)` and `SurfaceArrow`, `HoverCard`,
  `showPopover(showArrow:)`, `Surface(arrow:)`,
  `PopoverController.openAt`.
- `Popover.requestFocus`, also on `ContextMenu`, `ContextMenuRegion`,
  `DropdownMenu`, `DatePicker`, `DateRangePicker`, `TimePicker` and
  `showPopover`: with false the caret
  stays in the field the popover hangs under, Tab moves on into the
  popover and Escape closes it from either.
- The `Toaster`: toasts stack, expand on hover, pause while hovered,
  swipe away, have a close button and a status variant, clear the bars
  (`ToasterState.insets`), and F6 moves the focus to them. `ToasterTheme`.
- `Dialog.filter`, `Tooltip.filter`, `Command.surfaceFilter`,
  `ToastTheme.filter`.

#### Inputs and pickers

- `TextField(clearable:, onCleared:, revealable:, showCounter:)`,
  `TextField.password`, `TextFormField.password`, `TextFieldState.clear()`,
  `Textarea(showCounter:)`.
- `SearchField` (`isSearchShortcut`, `shortcutLabel`, `clearOnEscape`),
  `showSearch` with `SearchViewBuilder`, `Autocomplete`, `NumberField`
  (`NumberField.stepper`, `NumberFieldVariant`), `TagField`.
- Text selection on touch: `UnaTextSelectionControls`
  (`unaTextSelectionControls`), `TextSelectionToolbar`,
  `TextSelectionToolbarButton`, `TextMagnifier`, `SelectionArea`,
  `TextSelectionTheme`, `TextFieldTheme.useSystemContextMenu`.
- `DateField`: typed day, month and year in the locale's order, with a
  calendar button.
- `WheelPicker` (`WheelPicker.builder`, `WheelPickerItem`,
  `WheelPickerGroup`, `WheelPickerTheme`), `TimeWheelPicker`,
  `DateWheelPicker`, `formatTimeOfDay`, `uses24HourFormat`.
- Pickers open in a sheet on a phone (`PickerPresentation`): `DatePicker`
  and `DateRangePicker` with a full-width calendar or wheels, `TimePicker`
  with wheels, and a searchable or multiple `Select`. `SelectOption.label`.
- `Slider` and `RangeSlider` value indicators (`SliderValueIndicator`),
  `RangeSlider.focusNode` (its lowest thumb's),
  `Checkbox(tristate:)`, `UnaRadioGroup(child:)`, `RadioGroupScope`.
- `Chip` (`onDeleted`, `showCheckmark`, `enabled`) and `ChipGroup`
  (`ChipGroupItem`; one, or several with `ChipGroup.multiple`, wrapping or
  scrolling, with `leading` and `trailing` actions).
- `Rating`, `ColorPicker`, `ColorPickerButton`, `colorToHex`,
  `colorFromHex`.
- `OtpField(value:, initialValue:, onCompleted:, autofillHints:)`: a paste
  or autofill spreads from the slot it lands in.
- Form fields for the new controls: `AutocompleteFormField`,
  `ChipGroupFormField` and `ChipGroupMultipleFormField`,
  `ColorPickerFormField`, `DateFormField`, `NumberFormField`,
  `RangeSliderFormField`, `RatingFormField`, `SegmentedControlFormField`,
  `SliderFormField`, `TagFormField`, `TimeFormField`, and
  `ToggleGroupFormField` and `ToggleGroupMultipleFormField`.

#### Lists and data

- `ListTile` (`value`, `showChevron`, `onLongPress`, `enabled`,
  `destructive`), `ListSection` (card or plain) and the lazy
  `SliverListSection`, `SwitchListTile`, `CheckboxListTile` (tristate),
  `RadioListTile` (one choice of the `UnaRadioGroup` around it, as a
  `Radio` is), and `ExpansionTile`.
- `SwipeActions` (`fullSwipe`, `onRemoved`) with `SwipeAction`s,
  `RefreshIndicator`, `Carousel` (`CarouselController`), `PageIndicator`.
- `ReorderableListView`, `ReorderableListView.builder(itemId:)`,
  `SliverReorderableListView` and `ReorderableDragHandle`, on the board's
  springs: a row lifts and lands, the others make way, and every move can
  be made from the keyboard or by assistive technology.
- **Board.** `Board`, `BoardColumn`, `BoardMove`, `BoardController` and
  `BoardDragHandle`: a kanban board whose cards are dragged to reorder them
  and to move them between columns. Columns build lazily and scroll on their
  own, the board auto-scrolls while a card is held near an edge and snaps
  column by column on a phone, a column can limit or refuse what it takes,
  and every move can also be made from the keyboard or by assistive
  technology. An item keeps its state and its keyboard focus when it
  changes column. `BoardTheme`.
- **Chat.** `ChatList` is a lazily built conversation anchored to its
  newest message: a new message opens its height on a spring, the list
  follows while the reader is at the end and holds still once they have
  scrolled back, with a count of what arrived and a way back
  (`ChatListController`, `ChatListTheme`). `StreamingText` reveals text that
  is still arriving — a string that grows, a stream of chunks or a
  `StreamingTextController` — at an even pace, without splitting an emoji,
  and becomes a plain `Text` when it is complete (`StreamingTextTheme`).
  `ChatBubble` (following its content's size on a spring) and
  `TypingIndicator`.
- `DataTableController.remote` serves rows the table does not hold:
  sorting, paging and a query go to the source (`DataTablePageRequest`)
  and come back as a `DataTablePage`, with skeleton rows while a page
  loads and `DataTable.errorBuilder` for a failure.
  `DataTableColumn(sortable: true)` sorts at the source.
- `ResizableController.sizes`, `setSizes` and `reset`.
- `AvatarGroup`, `IconTile`, `StatTile`, `Timeline`, `IndicatorBadge`.
- **Chart palettes.** `ChartPalette` holds the colours a chart's series
  are drawn in, five for a light page and five for a dark one, and
  `ThemeData(chartPalette:)` writes one into the scheme's `chart1`…`chart5`.
  The presets are shadcn/ui's chart themes: `multicolor` (its categorical
  set), `slate`, and one per Tailwind colour from `red` to `rose`, each five
  shades that alternate lighter and darker around the first. Every built-in
  scheme, and every `ColorScheme.fromSeed`, charts in `ChartPalette.green`
  (the chart colours used to follow the accent). The theme editor offers
  them under Color, and exports `chartPalette:`.
- **Charts.** `LineChart` (over categories or `xValues`; monotone, straight
  or stepped lines, `area`, `dots`), `BarChart` (grouped or `stacked`,
  vertical or `direction: Axis.horizontal`), `DonutChart` (a pie with
  `holeRatio: 0`, a `center` widget) and `Sparkline`, with `ChartSeries`,
  `ChartSegment` and `ChartLegend`. Series take the scheme's
  `chart1`…`chart5`; value axes have round ticks. Hover, touch and the
  arrow keys show a glass tooltip and a cursor or highlight; assistive
  technology reads and steps through the points. Values grow from the
  baseline on the theme's motion and a change of data moves from the old
  values to the new, painted without rebuilding. `ChartTheme`
  (`ThemeData.chartTheme`).

#### Buttons and feedback

- `Button(loading:, semanticLabel:)`, `IconButton(loading:, tooltip:)`,
  `Toggle(onHover:, mouseCursor:)`, `ButtonTheme.iconSize` and `padding`,
  `ToggleTheme.width`.
- `ButtonGroup`, `ButtonGroupSeparator`, `ButtonGroupText`,
  `ButtonGroupScope`: joined buttons and toggles.
- `Pressable` and `FocusRing`, the press, hover, focus and fill of every
  pressable widget, for an app's own controls (`enabled`, `selected`,
  `toggled`, `statesController`, `onHover`, `onFocusChange`,
  `semanticContainer`, `pressScale`).
- `Stepper`, `Step`, `StepState`, `StepperControls`, `StepperTheme`.
- `AlertVariant.success`, `warning` and `info`, and `Alert(onDismissed:)`.
- `ProgressRing`, which takes its colours and its spring from the
  `ProgressBarTheme`; `Skeleton.shimmer`.
- `LicensePage` and `showLicensePage`.

#### Motion

- `Motion`: one vocabulary of durations, curves and springs on the style
  (`StyleTokens.motion`: `Motion.lively` in the default style,
  `Motion.calm` in the shadcn ones, `Motion.none` to switch it off),
  overridable with `ThemeData(motion:)`. `Motion.of(context)` honours the
  platform's reduced-motion setting. Menus, popovers, tooltips and dialogs
  grow from their anchor; tabs, tab bars, navigation bars, toggle groups
  and the menubar have one travelling indicator; switches, checkboxes,
  accordions, progress bars, toasts, sheets and badges move on springs.
- The building blocks: `MotionSpring`, `SpringController`, `SpringBuilder`,
  `SpringSize`, `PressScale`, `MovingIndicator` and
  `MovingIndicatorTarget`, `Entrance`, `EntranceProgress`, `MotionOrigin`,
  `PopIn`, `PopOnChange`, `ExpandReveal`, `ContentSwitch`, `AnimatedFill`,
  `AnimatedColorBuilder`, `MotionColorTween` and `lerpColorThroughAlpha`.

#### Surfaces, icons and utilities

- **Glass.** `Glass` (`frosted: false` for a tint without a filter),
  `Backdrop`, and style tokens for blur, saturation and the opacity of
  cards, bars and glass surfaces. `BackdropSurface`, `BackdropFade`,
  `BackdropFadeHost` and `BackdropFadeHandle` fade a blurred surface inside
  its filter.
- **Colour tokens.** `ColorScheme.tint`, `tintForeground`,
  `foregroundSubtle`, `success`, `successMuted`, `warning`, `borderStrong`,
  `accentBorder` and `bar`, each with a fallback so existing schemes keep
  working.
- **A configurable radius scale.** `RadiusScale` and `StyleTokens.radius`.
- **Icons that keep their weight when small.** `PhosphorIcon` is an `Icon`
  that draws a regular Phosphor icon smaller than 24 with a slightly
  thicker line: 1.25 pixels at 16 where the font alone gives 1.
  `PhosphorIconTheme` (`referenceSize`, `strength`),
  `ThemeData.phosphorIconTheme`, and the style tokens `iconOpticalSize` and
  `iconOpticalStrength`; a strength of 0 switches it off. An app bundles
  only the glyphs it uses, of each weight.
- **Haptics.** `Haptics.selection` and `Haptics.impact` (`HapticImpact`)
  tick on Android and iOS; the board and reorderable list, slider, wheel,
  rating, number field, tab bars and segmented control, swipe actions,
  refresh indicator, sheet detents, switch, checkbox and long-press
  context menus use them.
  `ThemeData(haptics: false)` switches them off.
- `CrossFadeTheme` and `ThemeChange`; `TextTheme.caption` for fine print;
  `DismissShortcut` (Escape closes something of yours without taking the
  key from the dialog around it); `isShownOnTop` and `isInTopRoute` (what a
  key handler or a system gesture asks before it acts: shown, and in the
  top route of every navigator up — a route's `isCurrent` answers for its
  own navigator only); `UnaTable.rowSelected`;
  `Portal.onShown`; `BottomNavigationBarTheme.rimColor` and `shadows`.
- Style tokens `tableHoverOpacity`, `tableSelectionTinted`,
  `menuHighlightOpacity`, `floatingShadowDark`, `fabSize` (`Sm`, `Lg`)
  and, for the floating bottom bar, `bottomNavigationOpacity`,
  `bottomNavigationLift`, `bottomNavigationBorderOpacity` and
  `bottomNavigationRimOpacity` (each with a `Dark` twin).
- `UnaLocalizations` strings for every new widget, in English; the
  other 81 locales fall back to it.
- **`RevealImage`** (`.network`, `.asset`): a placeholder while the
  picture loads, then Material's exposure reveal — a quick fade, an
  over-exposed and colourless start that settles into its exposure and
  then its colour — or a plain fade (`ImageReveal.fade`). A picture
  already in the cache shows at once; `RevealImage.precache` and
  `precacheNetwork` put one there ahead of time.
- `ThemeData.cornerRadius`: a radius for a surface no component theme
  covers, square under a style whose cards are square.
- `Focusable.visibleOnly`: the focus reported only while focus shows
  (after a key, not a click).

### Fixed

- **The date picker opens with no empty row and nothing springing into
  place.** Its calendar's days were a `GridView`: in a popover it took the
  padding of the overlay — under a scaffold's bar, the bar's height, a
  blank row above the first week — and on a scrolled page it restored the
  page's saved scroll offset and sprang back. The days are plain rows now,
  and a popover's content no longer inherits the overlay's padding.
- **A board card dropped further along its own column, or a row in a
  `ReorderableListView`, lands like a card dropped into another column.**
  Its own hidden slot slid to its new place under it, so the card turned
  back towards where it was picked up before landing. A dragged card leans
  2.5 times as far into a sideways drag (`BoardTheme.dragTilt` .065).
- **A swipe action row shuts without flashing the other side's actions.**
  The closing spring swung past shut for a few frames, further the faster
  the flick; it closes without bounce now, and never draws past shut.
- **An indeterminate `ProgressRing` grows and shrinks while it turns**, as
  Material's does, instead of turning a fixed arc.
- **A filled bar has room around its buttons.** A phone's toolbar was
  44, iOS's height for a bar of bare glyphs, and una's 44-point buttons
  filled it: the hover and press disc met the bar's edges. A filled bar's
  toolbar is at least an icon button with the small gap above and below
  (60 on a phone; Material's is 64 around a 40-point state layer), and it
  needs no margin above it where there is no status bar. A bar of Liquid
  Glass keeps 44 and its margin: its capsules float.
- **On Liquid Glass the bar's soft edge reaches under the scaffold's
  banner**, so the page scrolled under the two is blurred as one; the
  banner used to sit over sharp content.
- **A bar's surface comes in with the scroll.** `whenScrolled` and Liquid
  Glass bars rise over the first 32 points the page moves under them,
  instead of fading in on a timer as soon as anything was under them,
  which read as a blur popping in.
- **A floating bottom bar with labels lights the label too**: its lens
  and hover wash take in the icon and its label, as on Liquid Glass. A
  docked bar keeps Material's pill behind the icon.
- **Toasts have no close button.** A mouse or a trackpad swipes a toast
  away as a finger does; F6 focuses a toast that has no control itself,
  with a ring, and Escape dismisses it.
- **A reshaped field's focus ring follows its shape.** A radius given to
  a decoration's `border` (a pill-shaped field) now shapes its focused
  and error borders and its ring too; the ring stayed at the theme's
  radius, a rounded rectangle round a pill.
- **A gradient or image in a superellipse stays put on the web.** Flutter
  fills a `RoundedSuperellipseBorder` with `drawRSuperellipse`, which in a
  browser moves a shader with the shape's centre; una's superellipse
  border fills a shader through a clip there.
- **Skeletons shimmer as one.** One clock drives every skeleton on screen
  and a soft diagonal band crosses them together; the highlight is lighter
  than the base in light and dark (it was a dark band on the translucent
  schemes).
- **Avatars clip only a picture**, to an oval or a rounded rectangle
  rather than a path; initials need no clip.

- **A slider takes a sideways swipe on a phone.** Inside something that
  swipes sideways — a pager, a carousel, the docs' preview and code
  pages — the swipe moved the page instead of the thumb: the slider
  listened for a pan, which waits for twice the movement of a horizontal
  drag. It listens for horizontal drags now, which it wins as the deeper
  one, and a vertical swipe on it still scrolls the page.
- **A Liquid Glass slider stays glass for as long as it is held.** A
  finger held still on the thumb lost it to a long press around the
  slider (selectable text, for one) half a second in, and the lens turned
  back into the handle. The thumb is the finger's from the moment it
  lands; the active range ends in a round cap under the clear lens, as the
  native slider's does.
- **Every Liquid Glass slider draws the package's thumb, unclipped.** A
  range, or a slider with its bubble or division marks, had a thumb of
  una's own; all of them now draw `GlassSlider`'s thumb, press, lens and
  squash included, with room for the lens's stretch, which the package's
  own slider clipped at its top and bottom in a fast drag.
- **Fewer clips and layers.** An avatar in an `AvatarGroup` is clipped
  once, by the group, not by the group and then by itself. An outer shadow
  under an opaque gradient or an opaque fill of any shape (a superellipse
  control) is no longer clipped to the outside of the element, as under an
  opaque colour already. The Liquid Glass slider thumb paints its drop
  shadow whole, as the package does, and fades its handle by its colour
  instead of through an opacity layer.
- A popover, menu, select list, date picker or tooltip stayed on screen
  when its anchor was hidden: in an `IndexedStack` child that is not
  showing, a hidden `Visibility`, an `Offstage`, under an `Opacity` of zero
  or on a kept-alive page.
- A context menu at a point, `showMenu` and `showPopover(anchorRect:)`
  opened in the wrong place inside a nested navigator that does not start
  at the window's corner.
- An overlay moved in to stay on screen touched the screen's edge; it
  keeps a small gap now, and one that fits is not moved.
- Escape in a submenu took three presses to close it; one press closes one
  layer.
- On the web, Enter did not activate a focused button, checkbox, radio,
  switch or accordion trigger, and the arrow keys did not move through the
  rows of a menu or the options of a select.
- On the web, an outer shadow was painted behind the whole element instead
  of only outside it, and showed through any translucent fill as a grey
  wash.
- A failed validation on an OTP, radio-group, time-picker or date-picker
  form field gave the keyboard focus to a node no widget owned: the focus
  left the UI, and "FocusNode used after disposed" followed later. It now
  goes to the field's first control.
- The Escape that closed a popover, tooltip or select was reported to the
  platform as unhandled, and a closed popover inside a shown tooltip kept
  Escape from closing the tooltip.
- A label was cut off at a larger text size in tabs, small buttons and
  toggles; their style height is now a minimum once the text scale is
  above 1. Calendar cells grow with the text scale, and a month wider than
  the room is scaled down.
- The calendar's header and the ends of a selected range did not mirror in
  a right-to-left locale, and neither did `Slider` and `RangeSlider`,
  which assistive technology could not adjust either.
- An accordion's header was not announced as a button with its expanded
  state, and a closed item kept by `maintainState` was a Tab stop, a tap
  target and read out.
- A sortable `DataTable` column's header could not be reached from the
  keyboard and did not announce how the column is sorted.
- A disabled `Button` was dimmed by a fixed half instead of
  `ThemeData.disabledOpacity`; `ButtonTheme.pressedOffset` moved a pressed
  button sideways by a hundredth of its width instead of in logical
  pixels, and shifted one with no height out of sight; an `IconButton`
  ignored the size of its variant's `ButtonTheme`.
- `ProgressBar` threw when it went indeterminate a second time.
- `Tabs(restorationId:)` threw for a value that is not a string, a number
  or a bool, and `Tabs(expandContent: true)` threw in a scroll view.
- `SidebarScaffold`'s keyboard shortcut toggled a sidebar under a dialog
  or in a hidden tab, took Ctrl+B from a focused text field (which moves
  the caret back on a Mac) and answered both modifiers everywhere: it is
  ⌘B on Apple platforms and Ctrl+B elsewhere, heard after the focused
  widget has passed on the key. Its label is localized, and it follows
  the form factor rather than the window's width.
- An uncontrolled `Select.multiple` lost its choice when rebuilt with equal
  `initialValues`, and a custom search field of `Select.withSearch` did
  not take Space or Enter.
- A menubar menu closed by a choice or by Escape left the menubar open.
- A `Popover` could not switch between `controller:` and `open:`, and
  `ContextMenuTheme.subMenuPadding` did not reach submenus.
- A reset of a `UnaForm` called a text form field's `onChanged` and
  the form's `onReset` twice.
- A calendar or date picker whose value was set to null from outside kept
  its selection, and a picker trigger's long label overflowed.
- A button was not one semantics node (the text beside it joined its
  name), and an icon button with a `semanticLabel` could not be pressed by
  a screen reader.
- A dialog's actions in a `Wrap` did not fill its width on a phone.
- A sheet's barrier did not lighten as the sheet was dragged away.
- A `ContextMenu` open from its first build did not take the keyboard
  focus.
- Toasts had their shadow clipped off.
- Merging a `UnaRoundedSuperellipseBorder` dropped its `offset` and
  `padding`, so a focus ring drawn with one collapsed onto the element's
  own border, and a plain `UnaBorder` merged into one replaced the
  superellipse with a rectangle.
- A `Dialog` on a narrow screen, an open `Tooltip` and a `UnaApp` given
  no theme derived the whole theme again on every build, and the page,
  dialog and `showPopover` routes set their transition up again on every
  tick of it.
- Hover and selection fills flashed darker midway, because colours of
  different opacity were blended channel by channel.
- Table hover and footer rows came out far too dark on a scheme whose
  `muted` is translucent, `UnaTable.list` never repainted its hover,
  and the `DataTable` selection count was not localized.
- A dialog's barrier blur popped in at the end of the transition.
- `SelectOption.hoveredBackgroundColor` was ignored.
- A controlled `ToggleGroup` called `setState` during build.
- A tooltip re-hovered while it was leaving disappeared anyway.
- Scrolling a `PageContainer` repainted the whole page on every frame, a
  switch of theme rebuilt the app on every frame of its transition, and a
  `Spinner` rebuilt on every frame instead of painting.
- `UnaMaterial` derived its Material theme on every rebuild.

From the component review:

- **Calendars and date pickers.** A month changes without sliding in, a
  day takes the hover at once, and `DatePicker`, `DateRangePicker` and
  `TimePicker` open and close their popover with no entrance. Once a range
  has both its days the next tap starts a new one, so `DateRangePicker`
  stays open until the new range is complete; `minDays`/`maxDays` bound
  only an unfinished range. A new `initialMonth` already on screen no
  longer moves the months. The range examples show one month.
- **Menus.** A chosen row (or a select option that closes its list)
  blinks its highlight before the menu closes and its callback runs
  (`Motion.fast`; at once under `Motion.none`). `MenuCheckboxItem`
  closes its menu on a click or Enter like any row (`closeOnTap` defaults
  to true); Space toggles and stays. A `MenuRadioGroup` at a menu's edge
  rounds only its own end row, and select options follow the select's own
  radius. Overlay content is no longer part of a `SelectionArea` around
  its anchor. A Liquid Glass overlay without shader filters (the web) no
  longer darkens its rim, which framed the rows as a white block.
- **`Select` has no scroll arrows**: `showScrollToTopChevron` and
  `showScrollToBottomChevron` are gone from it, its form fields and
  `SelectTheme`; a long list scrolls like any list.
- **Sliders.** A thumb stays inside the track at either end, as in Radix,
  so it can be taken by its outer edge; a thumb grabbed off-centre no
  longer jumps to the pointer, and a tap anywhere across the slider's
  height moves it. The same for the colour picker's area.
- **Liquid Glass.** A `SegmentedControl` segment with an icon and a label
  shows them side by side instead of overflowing. `Glass` keeps the tint of
  its `level` and the theme's glass blur and saturation, so it looks like
  the frosted panel.
- **Inputs.** Content inside a glass dialog or popover keeps its state as
  the surface fades out, so a search view no longer shows every result
  again while it closes. A `TagField` suggestion picked by touch in Safari
  on iOS is added rather than dropped, and `TagField` and `Autocomplete`
  keep their options while their list closes. The password toggle shows a
  crossed-out eye while the text is hidden. `SearchField`'s Cancel sits a
  medium gap from the field. A selected colour swatch's ring is concentric
  with the swatch.
- **Surfaces.** A disabled `Button`, `IconButton` or `Toggle` in a
  `ButtonGroup` (or a joined `ToggleGroup`) keeps the group's hairline at
  its enabled colour. `Sheet` shows no close button unless
  `showCloseButton` or `SheetTheme.showCloseButton` asks for one. Success,
  warning and destructive toasts are washed in their colour
  (`ToastTheme.statusTintOpacity`), with the icon on the title's line.
  Links in a phone's navigation-menu sheet have room around their text,
  and buttons on a floating `Toolbar` follow the bar's curve.
- **Scrolling and dragging.** `SliverAppBar.large`'s title goes up under
  the toolbar, whose surface (or scroll edge, on Liquid Glass) comes in
  over it, instead of being cut off. A
  `ReorderableListView` row with no handle drags from anywhere with a
  mouse, as on a `Board`. `SwipeActions` takes a mouse drag and a
  two-finger trackpad swipe.
- **Focus shows only after the keyboard is used**, as CSS's
  `:focus-visible` does: a row or button focused by or after a click (the
  first action of a sheet a button opened, the button once it closed)
  shows no ring or highlight.
- **`NavigationRail` is no longer exported.** The rail is
  `NavigationScaffold(layout: NavigationLayout.rail)`, styled by
  `NavigationRailTheme`; for a panel of sections beside the page use
  `Sidebar`.
- **A sidebar under a `Scaffold`'s bars keeps its column clear of them**:
  its header starts below the top bar and its footer ends above the bottom
  one, while its surface runs on beneath them (a floating panel keeps
  clear of them altogether).
- **`OtpField.obscureText`** (and on `OtpFormField`): a filled slot
  shows a dot, as a PIN is entered.
- **Example.** Previews stand on a card, the browser's own context menu
  is off on the web, and a docs page runs on under the floating bottom
  bar on a phone.
- **A select, checkbox, radio, switch, slider or sidebar row shows its
  focus ring only after a key**, not after the click that chose: the
  select's trigger kept its ring after an option was picked, and after a
  click elsewhere.
- **Every slider on Liquid Glass.** A range slider, a slider with its
  value bubble always shown or with division marks draws the package's
  capsule thumb, which swells into a lens while held, as the plain slider
  does.
- **The `sharp` look's stat tiles, icon tiles, board cards and empty-state
  icons are square** like the rest of its surfaces.
- **Example.** A Demos menu beside the logo links the four apps built
  with una; the mark is an uppercase U; the theme editor's look tiles show
  the shape alone, and it offers three more colours (Lime, Citron, Grape);
  the showcase's photographs develop in with `RevealImage`.
- **Keyboard and assistive technology, across the library** (from a
  review against the WAI-ARIA patterns and WCAG 2.2 AA):
  - *Controls.* A null `onChanged` disables a switch or checkbox (Space
    on a callback-less switch threw); checkbox, switch and radio are one
    node with their label and state; a radio group, toggle group and chip
    group are one Tab stop walked with the arrows; sliders are named on
    the thumb, read as a percentage and take Home, End, Page Up and Down;
    pagination pages are buttons; the accordion trigger shows focus; a
    collapsed `Collapsible` is out of the Tab order; a chip's delete names
    its chip; carousels stop auto-playing under a screen reader and get a
    pause button; the colour picker's area and tracks are adjustable.
  - *Fields.* Every text field is named (by `semanticLabel`, or the form
    field's label through the new `InputDecoratorScope`) and carries its
    description and error, announced when it appears; an obscured OTP
    never exposes its digits; Autocomplete and TagField announce the
    option the arrows reach; time-field parts step with Up and Down; the
    clear and show-password buttons take taps over 24 × 24.
  - *Pickers.* A select's trigger is a named button with its value and
    open state, its options are selectable, and the keyboard reaches them
    (Down opens, Home, End, type-ahead); the calendar is one Tab stop with
    the date-grid keys, crossing months, each day named with its full
    date, today and range ends, and its month changes announced; a date
    picker opens on a day.
  - *Overlays.* Focusing a menubar trigger no longer opens its menu, and
    Left and Right move between menus; tooltips show on keyboard focus,
    can be hovered and close on Escape; dialogs have a role, a name from
    their title and focus their first control; `ContextMenuRegion` opens
    from the Menu key or Shift+F10; menu triggers expose their open state,
    a keyboard-opened menu focuses its first row and Tab leaves it; the
    command palette announces its highlight and results; a toast with an
    action waits under a screen reader; alerts are announced.
  - *Navigation and data.* Sidebar rows, trigger and actions work from the
    keyboard (they are `Pressable`s now) and a closed sidebar is out of the
    Tab order; resizable dividers are focusable window splitters; table
    rows with `onRowTap` are reachable and headers are headers; navigation
    bars, the rail, the sidebar and breadcrumbs are labelled landmarks;
    `Avatar.semanticLabel`; `ChatList.announcementOf` reads new messages;
    progress bars, rings and spinners have their roles.

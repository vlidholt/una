# App structure: scaffolds, bars, navigation and routes

How a una screen is put together, from the frame of one page to the
destinations of a whole app. Every piece here follows the form factor by
itself: write the screen once and it becomes a phone screen below the `md`
breakpoint (see [form-factors.md](form-factors.md)).

## One screen: `Scaffold`

A `Scaffold` lays its slots over the body and tells the body how far to
inset itself. The bars are drawn *over* the page, so the page scrolls
beneath a translucent bar, and the body's `MediaQuery` padding includes
the bars' heights: a `PageContainer`, a `ListView` or a `SafeArea` inside
it clears them without being told.

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('Inbox'),
    actions: [
      // No variant: the bar picks the look (see "Buttons in bars").
      IconButton(
        icon: const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass),
        semanticLabel: 'Search',
        onPressed: () {},
      ),
    ],
  ),
  floatingActionButton: FloatingActionButton(
    icon: const PhosphorIcon(PhosphorIconsRegular.notePencil),
    label: const Text('Compose'),
    onPressed: () {},
  ),
  body: const PageContainer(
    scrollable: true,
    child: Text('Messages'),
  ),
)
```

| Slot | What goes there |
| --- | --- |
| `appBar` | An `AppBar`. For a bar that scrolls with the page, leave this empty and make a `SliverAppBar` the first sliver of the body. |
| `banner` | A notice under the app bar, usually an `Alert(onDismissed:)`. |
| `bottomNavigationBar` | A `BottomNavigationBar` or a `Toolbar`. |
| `footer` | A strip over the end of the page that rises with the keyboard: a message composer, a row of actions. Wrap one that is not a bar in a `SafeArea`. |
| `bottomSheet` | A panel above the footer that does not block the page: a mini player, an inline `Sheet` resting at its detents. |
| `floatingActionButton` | A `FloatingActionButton`; `floatingActionButtonLocation` is `start`, `center` or `end`. It is kept clear of the bars and the keyboard. |
| `drawer`, `endDrawer` | Panels that slide in from an edge, also by a drag from that edge. `Scaffold.of(context).openDrawer()` / `openEndDrawer()`. |

- The body is measured in the same layout pass as the bars, so its inset
  is right on the first frame whatever the bars' heights.
- With `resizeToAvoidBottomInset` (the default) the body ends where the
  keyboard begins and sees no `viewInsets.bottom` of its own; the footer,
  the bottom sheet and the action button ride up with the keyboard, and the
  bottom navigation bar stays where it is and is covered. Pass `false` to
  handle the keyboard yourself.
- `systemOverlayStyle` styles the status bar; by default its icons follow
  the page and the app bar.

## Bars

`AppBar` is a logo or back button, a title and actions. Its height
follows the form factor (and grows when large text needs a second line),
and its fill is the style's bar opacity over a blur.

- **Leading is implied.** With no `leading`, a bar on a page that can be
  popped shows a `BackButton`, on a full-screen dialog a `CloseButton`,
  and over a scaffold with a `drawer` a menu button. Pass
  `automaticallyImplyLeading: false` to show nothing. Never hand-build a
  back button.
- **Actions are implied too**: with no `actions` over a scaffold that has an
  `endDrawer`, the bar shows the button that opens it
  (`automaticallyImplyActions`).
- `title` is announced as a heading; `centerTitle: true` centres it.
  `middle` replaces the title with any widget (a search field).
- `bottom` holds a `TabBar` under the bar; share a `TabsController` with the
  `TabBarView` in the body.
- `surfaceBehavior: AppBarSurfaceBehavior.whenScrolled` keeps the bar clear
  until the page scrolls beneath it.
- The bar's content is capped at the page width (`maxWidth`), so its title
  lines up with a `PageContainer` below it. A full-bleed tool (a docs
  browser, an editor) passes `maxWidth: double.infinity`.

### Buttons in bars

Write the buttons in a bar's `leading` and `actions` **with no variant**:
`IconButton(icon: ..., semanticLabel: ..., onPressed: ...)`, `Button(...)`.
The bar knows what it is drawn on and gives them the look that reads
there: ghost on its own surface (the last icon's glyph, not its box, then
lines up with the page margin), an outline disc over a `SliverAppBar`'s
photograph, plain icons on a Liquid Glass capsule. `IconButton.ghost` in a
bar pins one look and loses the others. Name a variant only to *mean*
something: a pressed-in `IconButton.secondary` for a panel that is open,
`Button(variant: ButtonVariant.primary, ...)` for the one call to action
(a `Button` with no variant in a bar takes the bar's look, not primary).

```dart
AppBar(
  title: const Text('Messages'),
  actions: [
    IconButton(
      icon: const PhosphorIcon(PhosphorIconsRegular.notePencil),
      semanticLabel: 'New message',
      onPressed: () {},
    ),
    IndicatorBadge(
      count: 3,
      semanticLabel: '3 unread',
      child: IconButton(
        icon: const PhosphorIcon(PhosphorIconsRegular.bell),
        semanticLabel: 'Notifications',
        onPressed: () {},
      ),
    ),
  ],
)
```

Leave icon sizes, paddings and the gap between actions to the bar
(`actionsGap` only where a design packs them tighter). A logo is a widget
in `leading`; a logo and a search field together go in `title`, which is
flexible, so they can give way in a narrow window.

`SliverAppBar` lives in the scroll view instead: `SliverAppBar.large` has a
large title that collapses into the toolbar, `floating: true` comes back
when the reader scrolls up. Give the scaffold no `appBar` and make the
sliver bar the first sliver of the body's `CustomScrollView`. It follows
the scroll in paint, so a collapse builds and lays out nothing.

- `SliverAppBar.large(title:, subtitle:)`: the title large at the page
  margin under the toolbar, a muted line under it. As the page scrolls it
  slides under the toolbar and comes back small there. The top-level
  screen of a phone app (Settings, Library, Inbox).
- `background:` fills the expanded area with a picture or a gradient,
  which moves at half the page's speed; `expandedHeight:` sizes it. The
  titles stand on the page colour rising into the picture, so they read
  on any photo.
- The picture goes with the page and fades out as the bar collapses;
  the collapsed bar is the bar's own surface. A picture is never kept
  behind a collapsed toolbar.
- In a browser on Liquid Glass the toolbar stays filled and the picture
  starts below it. Nothing to handle.
- Wrap each action of a large bar in a `RepaintBoundary` when the bar
  collapses over a picture: the buttons then move instead of repainting.

```dart
CustomScrollView(
  slivers: [
    SliverAppBar.large(
      title: const Text('Ada Lovelace'),
      subtitle: const Text('Analyst, London'),
      expandedHeight: 220,
      background: const Image(
        image: AssetImage('assets/cover.jpg'),
        fit: BoxFit.cover,
      ),
      actions: [
        IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.dotsThree),
          semanticLabel: 'More options',
          onPressed: () {},
        ),
      ],
    ),
    SliverList.builder(
      itemCount: 20,
      itemBuilder: (context, index) => ListTile(title: Text('Post $index')),
    ),
  ],
)
```

```dart
Scaffold(
  body: CustomScrollView(
    slivers: [
      SliverAppBar.large(title: const Text('Settings')),
      SliverListSection(
        header: const Text('Account'),
        children: [
          ListTile(
            title: const Text('Profile'),
            showChevron: true,
            onTap: () {},
          ),
        ],
      ),
    ],
  ),
)
```

Along the bottom: `BottomNavigationBar` carries destinations (below), and
`Toolbar` carries actions on what is showing (`children`, usually
`IconButton.ghost`s, which a `Toolbar` does not pick for you, and a
`trailing` one that stands apart). Both float as a glass pill in a style
whose bottom bar floats, and span the edge otherwise.

## Many destinations: `NavigationScaffold`

An app with several top-level sections gives `NavigationScaffold` one list
of `NavigationDestination`s. On a desktop they sit in the app bar (a
`NavigationBar`); on a phone in a `BottomNavigationBar`; with
`layout: NavigationLayout.rail` down the start edge, an icon over a small
label (`ThemeData.navigationRailTheme`; there is no rail widget to place
yourself — for a panel of sections beside the page, use a `Sidebar`).
The default, `NavigationLayout.auto`, follows the form factor.

```dart
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return NavigationScaffold(
      title: const Text('Demo'),
      selectedIndex: _index,
      onDestinationSelected: (index) => setState(() => _index = index),
      destinations: const [
        NavigationDestination(
          icon: PhosphorIcon(PhosphorIconsRegular.house),
          selectedIcon: PhosphorIcon(PhosphorIconsFill.house),
          label: 'Home',
        ),
        NavigationDestination(
          icon: PhosphorIcon(PhosphorIconsRegular.chatCircleDots),
          selectedIcon: PhosphorIcon(PhosphorIconsFill.chatCircleDots),
          label: 'Messages',
          badgeCount: 3,
        ),
      ],
      body: DestinationStack(
        index: _index,
        builders: [
          (context) => const PageContainer(child: Text('Home')),
          (context) => const PageContainer(child: Text('Messages')),
        ],
      ),
    );
  }
}
```

- The selected destination's icon is the fill weight of the same glyph
  (`selectedIcon`); see [icons.md](icons.md).
- `DestinationStack` keeps each destination's page alive and off stage
  while another shows, so scroll positions and drafts survive a switch.
- `action:` is a `NavigationAction`, the one prominent button (Create
  post) that sits in the bars; `showInTopBar`, `showInBottomBar` and
  `showInRail` on a destination leave it out of one of them (Messages and
  Notifications as app-bar buttons on a phone, a "Me" avatar only in the
  bottom bar).
- `title`, `leading` and `actions` are the desktop top bar's;
  `mobileActions` replaces the actions on a phone, and `mobileAppBar` the
  whole phone bar (a logo and three icon buttons). `showMobileAppBar:
  false` drops it for a destination that draws its own (a profile whose
  `SliverAppBar.large` cover runs under the status bar).
- A destination's screen is page content, normally a `PageContainer`,
  never a second `Scaffold`: the shell's bars are already laid over it and
  its `MediaQuery` padding includes them. A view that needs the whole
  screen (a conversation, a detail on a phone) is a pushed route with its
  own `Scaffold` and `AppBar`.
- The desktop top bar holds the destinations only while they fit. A
  narrow desktop window (a tablet held upright) is better with
  `layout: NavigationLayout.rail`, chosen from a `LayoutBuilder` around the
  scaffold.
- A site-style row of links with drop-down panels is a `NavigationMenu`
  (`NavigationMenuItem`, `NavigationMenuLink`); it becomes a sheet on a
  phone.
- A collapsible side panel of navigation is a `Sidebar` inside a
  `SidebarScaffold` (an icon rail or off-canvas on a desktop, a sheet on a
  phone; `SidebarController` has `isOpen`, `open()`, `close()`,
  `toggle()`, and `isMobileOpen`/`openMobile()` for the phone sheet). It
  suits a tool with many sections (an admin, a docs browser);
  `NavigationScaffold` suits an app with five or fewer.

```dart
SidebarScaffold(
  sidebar: Sidebar(
    header: const TextField(
      placeholder: Text('Search'),
      leading: PhosphorIcon(PhosphorIconsRegular.magnifyingGlass),
    ),
    children: [
      SidebarGroup(
        label: const Text('Workspace'),
        children: [
          SidebarMenu(
            children: [
              SidebarMenuButton(
                selected: true,
                onPressed: () {},
                child: const Text('Projects'),
              ),
              SidebarMenuButton(
                onPressed: () {},
                child: const Text('Members'),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  child: const PageContainer(scrollable: true, child: Text('Projects')),
)
```

`SidebarTrigger()` anywhere under the scaffold toggles it (as does
Cmd/Ctrl+B).

## Pages and routes

`UnaApp` pushes `UnaPageRoute`s. On iOS and macOS, on a phone or a
tablet, that is the platform's push, as Material's route draws it there:
the page slides the whole width in, and the one under it moves a third
aside. Elsewhere it is a short slide and fade on the theme's motion, from
the end edge on a phone. Push one yourself the usual way:

```dart
Navigator.of(context).push(
  UnaPageRoute<void>(builder: (context) => const DetailPage()),
);
```

- A pushed page has its own `Scaffold` and `AppBar`; the bar shows the
  back button by itself. On Liquid Glass the bar's glass does not move
  with the page: the back button and the actions stay in place and turn
  into the next page's — a capsule reshaping to the next buttons on a
  spring, a changed button blurring into its successor, one both pages
  have holding still, the back button materializing — while the title
  goes with its page, as on iOS 26. Under a swipe back the glass holds
  still until the swipe is let go. A filled bar moves with its page, as
  Material's does.
- `fullscreenDialog: true` slides the page up and gives its bar a close
  button: a compose screen, a search on a phone.
- Back gestures are on: a drag from the start edge on iOS and macOS (the
  mouse too, on a Mac), the predictive back preview on Android. `backGesture: false` turns them off for one
  route. `UnaPage` is the same route for a declarative page list
  (`Navigator.pages`, a router).
- A list and the detail of what is chosen in it is a `ListDetailLayout`
  (`list:`, `detail:`, `placeholder:`, `listWidth:`, `onDetailClosed:`):
  side by side on a desktop, the detail pushed over the list on a phone,
  where the back gesture and button call `onDetailClosed`. An inbox or a
  file browser is one; do not build the two layouts yourself.

### A stack per destination, and URLs

An app with a bottom bar (or a rail, or a top bar of destinations) keeps
a stack of pages per destination, as iOS and Material apps do: a pushed
page slides in over its destination's root with a back button, the bar
stays, and switching destinations keeps each stack where it was. With
URLs on the web, use a router: `UnaApp.router` and `go_router`'s
`StatefulShellRoute`. The split is the same as Material's.

- **The shell owns the app's chrome**: one `NavigationScaffold` (or a
  `Scaffold` with a `bottomNavigationBar`) with the destinations, the
  drawer and end drawer, a FAB, a bottom sheet. Its `body` is the
  branches' navigators, in a `DestinationStack` so a switch animates. On
  a phone give it no app bar (`showMobileAppBar: false`).
- **Each page owns its header**: its own `Scaffold` with its own `AppBar`
  or `SliverAppBar.large`, its banner and its content. Leave `leading`
  out: the bar shows the back button on a pushed page, and on a
  destination's root the menu button for the shell's drawer — it finds
  the drawer on the scaffold around the navigator
  (`Scaffold.withDrawerOf(context, end: true)?.openEndDrawer()` for a
  button of your own). On iOS the edge swipe of a pushed page goes back;
  on a root page it opens the shell's drawer.
- **Every route returns an `UnaPage`** from `pageBuilder`, for una's
  transition and back gestures (go_router only knows Material's and
  Cupertino's apps; anything else gets no transition).
- The page's scaffold sits inside the shell's: its body is inset by the
  shell's bars through the `MediaQuery` padding, so a list scrolls under
  a floating bottom bar and stops above it, as it would in one scaffold.

```dart
final router = GoRouter(
  initialLocation: '/trips',
  routes: [
    StatefulShellRoute(
      builder: (context, state, shell) => NavigationScaffold(
        showMobileAppBar: false,
        destinations: destinations,
        selectedIndex: shell.currentIndex,
        // Again on the current destination: back to its root.
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        body: shell,
      ),
      navigatorContainerBuilder: (context, shell, children) =>
          DestinationStack(
            index: shell.currentIndex,
            builders: [for (final child in children) (_) => child],
          ),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/trips',
            pageBuilder: (context, state) =>
                UnaPage(key: state.pageKey, child: const TripsPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => UnaPage(
                  key: state.pageKey,
                  child: TripPage(id: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ]),
        // …a branch per destination.
      ],
    ),
  ],
);

// A page: its own scaffold and bar; the back button comes by itself.
class TripPage extends StatelessWidget {
  // …
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(trip.name)),
    body: ListView(children: [/* … */]),
  );
}
```

`context.push('/trips/lofoten')` pushes in the current branch with the
address following; a link to `/trips/lofoten` opens the trip with a back
button to the list; the browser's back and forward walk the stack. A
route that should cover the bottom bar (a compose screen) takes the root
navigator's key as its `parentNavigatorKey`, and `UnaPage(fullscreenDialog:
true)` slides it up with a close button.

Without a router, `DestinationStack` with a `Navigator` per builder does
the same, minus the URLs.

## Tabs and segments

| Widget | Use it to |
| --- | --- |
| `Tabs` | Show one of several sections of content, with the tab list above it. |
| `TabBar` + `TabBarView` | The same, apart: the list in an `AppBar.bottom`, the pages in the body, sharing a `TabsController`. |
| `SegmentedControl` | Pick one of a few *values* (a filter, a mode), not a view. |
| `ToggleGroup` | Turn several options on or off. |

All of them are controlled: `value` and `onChanged`. Tabs are data, not
widgets:

```dart
Tabs<String>(
  value: 'posts',
  onChanged: (value) {},
  tabs: const [
    Tab(value: 'posts', child: Text('Posts'), content: Text('Posts')),
    Tab(value: 'about', child: Text('About'), content: Text('About')),
  ],
)
```

`TabBarVariant.underline` is text tabs with a line under the selected one;
`TabBarVariant.segmented` is a filled strip with a raised pill. The
selection indicator travels between tabs on a spring.

## Insets for floating things

Toasts and other floating UI stay clear of the bars through
`OverlayInsets`: a `Scaffold` reports the screen edges its bars cover, and
`Toaster` (installed by `UnaApp`) is an `OverlayInsetsScope` that lifts
its toasts above them. Something of your own that floats over the page can
read the same value with `OverlayInsets.watch(context)`.

See also: [scaffold.md](../components/scaffold.md),
[app-bar.md](../components/app-bar.md),
[sliver-app-bar.md](../components/sliver-app-bar.md),
[navigation-bar.md](../components/navigation-bar.md),
[page-route.md](../components/page-route.md),
[list-detail-layout.md](../components/list-detail-layout.md),
[tab-bar.md](../components/tab-bar.md).

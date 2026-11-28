# Page Route

How one page replaces another. `UnaPageRoute` is the route `UnaApp` pushes by default. On iOS and macOS, on a phone or a tablet, it is the platform's push, as Material's route draws it there: the page slides the whole width in over the one under it, which moves a third of the way aside. Elsewhere it is a short slide and a fade from the end side on a phone, and a few pixels' rise on a desktop, on the theme's motion. A page can be taken back with a gesture: a drag from its start edge on iOS and macOS (with the mouse too on a Mac), and a preview of the predictive back gesture on Android. On Liquid Glass the bar stays in place and turns into the next page's. `UnaPage` is the same route for a declared page list.

## Pushing pages

`Navigator.push(UnaPageRoute(builder: ...))`. The page follows the finger for as long as it is held; past the middle, or flicked, it leaves, and otherwise it springs back with the speed it was let go at. `backGesture` is null by default, which follows the platform; `true`, as here, offers the swipe everywhere and `false` switches it off. A `fullscreenDialog` rises from below and never has one, and neither has a page under a `PopScope` that refuses to pop.

```dart
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// A navigator in a phone-sized frame. Pages are pushed with
/// `UnaPageRoute`; `backGesture: true` offers the swipe from the start
/// edge on every platform, where it is otherwise iOS's alone.
class PageRoutePushExample extends StatelessWidget {
  const PageRoutePushExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.withFormFactor(FormFactor.mobile),
      child: Container(
        width: 340,
        height: 460,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: theme.radii.xl2),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.border),
          borderRadius: theme.radii.xl2,
        ),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: Navigator(
            onGenerateRoute: (settings) => UnaPageRoute<void>(
              settings: settings,
              builder: (context) => const _Page(depth: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.depth, this.dialog = false});

  final int depth;
  final bool dialog;

  void _push(BuildContext context, {bool fullscreenDialog = false}) {
    Navigator.of(context).push(
      UnaPageRoute<void>(
        fullscreenDialog: fullscreenDialog,
        // Drag the page away from its left edge.
        backGesture: true,
        builder: (context) => _Page(depth: depth + 1, dialog: fullscreenDialog),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        // The bar shows the way back by itself: a caret on a page that
        // can be popped, a cross on a full-screen dialog.
        title: Text(dialog ? 'New note' : 'Page $depth'),
      ),
      body: PageContainer(
        child: UnaColumn(
          gap: GapSize.md,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              title: Text(dialog ? 'A full-screen dialog' : 'Page $depth'),
              description: Text(
                dialog
                    ? 'It rises from below and is closed, not swiped away.'
                    : canPop
                    ? 'Drag from the left edge to go back, or let go '
                          'early and it springs into place again.'
                    : 'The first page of a navigator has nowhere to go '
                          'back to.',
              ),
            ),
            Button(
              onPressed: () => _push(context),
              child: const Text('Push a page'),
            ),
            Button.outline(
              onPressed: () => _push(context, fullscreenDialog: true),
              child: const Text('Open a full-screen dialog'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Declared pages

With `Navigator.pages`, or a router package, pages are values. `UnaPage(child: ...)` shows one through the same route, with `fullscreenDialog`, `maintainState` and `backGesture`. In `go_router`, return it from a route's `pageBuilder` with `key: state.pageKey`.

```dart
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// Declared pages: the list of `UnaPage`s *is* the stack. A swipe back
/// or the back button removes the page, and `onDidRemovePage` brings the
/// state in line. A router package takes the same pages from its
/// `pageBuilder`.
class PageRoutePagesExample extends StatefulWidget {
  const PageRoutePagesExample({super.key});

  @override
  State<PageRoutePagesExample> createState() => _PageRoutePagesExampleState();
}

class _PageRoutePagesExampleState extends State<PageRoutePagesExample> {
  static const _people = ['Ada Okafor', 'Jonas Lind', 'Mei Tanaka'];

  String? open;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.withFormFactor(FormFactor.mobile),
      child: Container(
        width: 340,
        height: 420,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: theme.radii.xl2),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.border),
          borderRadius: theme.radii.xl2,
        ),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: Navigator(
            pages: [
              UnaPage<void>(
                key: const ValueKey('people'),
                child: Scaffold(
                  appBar: const AppBar(title: Text('People')),
                  body: PageContainer(
                    scrollable: true,
                    child: UnaColumn(
                      gap: GapSize.sm,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final person in _people)
                          ListTile(
                            title: Text(person),
                            trailing: const PhosphorIcon(
                              PhosphorIconsRegular.caretRight,
                            ),
                            onTap: () => setState(() => open = person),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (open case final person?)
                UnaPage<void>(
                  key: ValueKey(person),
                  backGesture: true,
                  child: Scaffold(
                    // The bar's back button pops the page, and
                    // `onDidRemovePage` below clears the state.
                    appBar: AppBar(title: Text(person)),
                    body: PageContainer(
                      child: Card(
                        title: Text(person),
                        description: const Text(
                          'Shown because the state says so. Going back '
                          'clears it.',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            onDidRemovePage: (page) => setState(() => open = null),
          ),
        ),
      ),
    );
  }
}
```

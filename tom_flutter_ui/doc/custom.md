# Custom Module

`custom/` is the **non-form composite kit** of `tom_flutter_ui`: eight
ready-made widgets that solve recurring *screen-level* problems — gating a
subtree by permission, showing an empty / loading / error placeholder, paging
a long list. They are not form fields and they do not edit a value, but where
they need one they reach for the **same authorization and resource systems**
the fields use, so they drop into a Tom screen with no extra wiring.

> **The kit is deliberately downstream-only.** Nothing in `tom_flutter_ui`
> consumes these eight; `forms/` builds on none of them, and that is a decision
> rather than an omission. Wiring `TomEmptyState` into the list renderers'
> empty slot was considered and declined: it would delete no duplicate —
> `TomInlineListForm` and its siblings resolve an empty list through
> `emptyBuilder`, then `emptyText` as a bare `Text`, then nothing at all, none
> of which reproduces an icon + headline + body + action — so what it would
> buy is a *default*, and an empty slot is the one place a default should not
> arrive unasked. Drawing nothing is a legitimate choice for a short list
> inside a card. Opting in costs one line:
> `emptyBuilder: (_) => TomEmptyState(title: 'No rows')`.
>
> `test/custom/module_boundary_test.dart` holds both directions: nothing in the
> package depends on `custom/`, and `custom/` reaches only for `widget_base`.
> A later default can be added; the coupling cannot be undone as cheaply.

> **Looking for the widgets on screen?**
> [`example/custom/custom_rendered_example.dart`](../example/custom/custom_rendered_example.dart)
> assembles all eight into one runnable app — `flutter run -t` it, or run the
> suite that renders and checks it. `custom_example.dart` beside it covers the
> parts that need no widget tree.
>
> **Looking for a signature?** This document explains what the widgets are for.
> [api/api_summary_custom.md](api/api_summary_custom.md) is the symbol-level
> mirror: every exported type with a section, and every public constructor
> parameter with what it does.

They reach sparingly, which decides what a host has to install:
`TomAuthGuard`, `TomAuthTreeView` and `TomChoiceGroup` resolve authorization;
`TomEmptyState` — and only when it is given a `tomId` — resolves strings
through the resource provider; the remaining four read neither. **None of the
eight resolves a colour or an icon through `TomUIColors` / `TomUIIcons`**, so a
screen built only from this kit needs no colours adapter and takes its
appearance from the ambient `ThemeData`.

Unlike the [widgets](widgets.md) kit (thin wrappers that extend a
`TomFamilyBase`), these are **composite** widgets that extend
`StatelessWidget` / `StatefulWidget` directly and assemble several Flutter
widgets into one idiom. Their value is in what they render, so most of it is
exercised by `testWidgets`; the pure, context-free part — the auth-resolution
lookup and the plain data models — is what the example demonstrates.

## Table of Contents

- [Overview](#overview)
- [Authorization widgets](#authorization-widgets)
- [Placeholder & state widgets](#placeholder--state-widgets)
- [The shared auth lookup](#the-shared-auth-lookup)
- [Dependencies](#dependencies)

---

## Overview

| Widget | Kind | What it does |
| ------ | ---- | ------------ |
| `TomAuthGuard` | class | Hide / disable a `child` by the `TomAuthState` resolved from a `tomId`. |
| `TomAuthTreeView` / `TomAuthTreeNode` | classes | A tree where every node resolves its own auth; a `disabled` node **caps** its whole subtree. |
| `TomChoiceGroup` / `TomChoiceGroupItem` | classes | A radio group whose whole selection is gated by one resource key. |
| `TomEmptyState` | class | Icon + title + description + optional action for "no data" surfaces. |
| `TomLoadingOverlay` | class | Translucent scrim + spinner (+ message) layered over a subtree while loading. |
| `TomSkeletonLoader` | class | Shimmer placeholder for async surfaces (static when `enabled: false`). |
| `TomErrorBoundary` | class | Catches build errors in `child` and renders a fallback instead of propagating. |
| `TomInfiniteScroll` | class | Paginated list with a `TomPageFetcher`, reusing the empty / skeleton / error widgets above. |

All eight are exported from the package barrel via
`lib/src/custom/tom_custom_widgets.dart`, together with the models and callback
signatures they take — `TomAuthTreeNode`, `TomChoiceGroupItem`,
`TomInfiniteScrollState`, `TomPageFetcher`, `TomInfiniteScrollItemBuilder` and
`TomErrorBoundaryFallbackBuilder`. The module readme
([`lib/src/custom/readme.md`](../lib/src/custom/readme.md)) tables all fourteen;
this document covers the eight widgets.

## Authorization widgets

Three of the eight gate their content on a resolved `TomAuthState`. They all
follow the same four-outcome contract:

| State | Treatment |
| ----- | --------- |
| `none` | removed from the tree (`SizedBox.shrink`, or `hiddenBuilder`) |
| `disabled` | rendered, faded to `disabledOpacity`, pointer-blocked |
| `read` | rendered, pointer-blocked (content visible, not interactive) |
| `full` | rendered as-is |

"Pointer-blocked" means an `IgnorePointer`, in all three — so a `trailing:`
action button, a `Radio`, anything the guarded content contains, is inert and
not merely un-styled. **What differs is the extent of the block**, which
follows from how many keys each widget has:

| Widget | Blocked region | Opt-out |
| ------ | -------------- | ------- |
| `TomAuthGuard` | the whole `child` subtree — one key governs it | `blockPointerOnRead: false` leaves `read` interactive |
| `TomChoiceGroup` | the whole group — one key governs the selection; each `Radio` is also `enabled: false` | none |
| `TomAuthTreeView` | **each node's own row only** | none |

The tree is the odd one because it is the only one of the three with a key
*per* node. Blocking a node's subtree would re-impose through the pointer layer
the very cap the propagation rules below exist to avoid: a `full` child under a
`read` parent must keep its own row live. And since a tree row that still fired
its taps would be indistinguishable from a `full` one, there is no
`blockPointerOnRead` equivalent to opt out of.

**`TomAuthGuard`** wraps an arbitrary `child`. Its resolution is pulled into a
`@visibleForTesting TomAuthState resolveAuthState()` method so the decision can
be unit-tested without a widget tree — call it on a constructed guard:

```dart
TomAuthorization.adapter = myAdapter;        // 'reports.export' → none
const TomAuthGuard(tomId: 'reports.export', child: ExportButton());
// build → SizedBox.shrink()  (resolveAuthState() == TomAuthState.none)
```

**`TomChoiceGroup`** applies **group-level** auth: one `tomId` controls the
entire selection (the per-item `Radio` auth in the widgets kit is per-field).
A `null` `tomId` means "no auth check — always full".

**The name is deliberately not `TomRadioGroup`.** `TomRadioGroupStyle` belongs
to the forms module and themes the radio-group *field*; it does nothing to this
widget, which is a composite and takes no part in the form style tree. While the two shared a name, a consumer who
found the style class and set it had no way to know it would have no effect —
and neither file said so. Like the rest of `custom/`, this one takes its
appearance from the ambient `ThemeData`.

It is the one widget here whose block takes two mechanisms rather than one.
The column sits under a Flutter `RadioGroup<T>` — that ancestor is what carries
the selection down to the radios, and it brings arrow-key navigation with it.
An `IgnorePointer` stops the pointer but not the keyboard, so `disabled` and
`read` additionally pass `enabled: false` to every `Radio`. Removing either
half leaves a way in.

**`TomAuthTreeView`** resolves auth **per node**. Each `TomAuthTreeNode`
carries its own `tomId`, and a node's own auth is folded with what it inherits
via `ownAuth.narrow(inheritedAuth)` — the `TomAuthState.narrow` lattice rule the
example demonstrates.

Keys compose along the branch: a node resolves
`<parentPath>.<ancestor ids…>.<own id>`, under the ambient scope when the tree
is given no `parentPath`. So `view` under `reports` is `app.reports.view` and
`view` under `invoices` is `app.invoices.view` — two grants, and an id need
only be unique among its siblings. A flat namespace would make those one key,
which is the distinction the widget exists to draw: without it a tree offers
nothing a list of `TomAuthGuard`s does not. What a node passes down depends on the state it lands on:

| Node's effective state | Rendered as | Passed to children |
| ---------------------- | ----------- | ------------------ |
| `none` | removed, subtree never built | — |
| `disabled` | faded, non-interactive | `disabled` — the subtree is capped |
| `read` | rendered, non-interactive | `full` — children judged on their own keys |
| `full` | interactive | `full` — children judged on their own keys |

So only a `disabled` node caps its descendants. A `read` parent renders itself
non-interactive but leaves a `full` child fully interactive, which is what a
navigation tree needs: a section header the user may not activate can still
contain entries they may.

**Expanding is not activation, and is not governed by any of the four.** The
chevron is a control of its own, outside the barrier and outside the fade, so a
withheld section can still be folded away — a read-only tree stuck fully
expanded is a read-only tree nobody can use, and the header most likely to be
withheld is exactly the one a user most wants to collapse. At `full` the whole
row remains a target and both toggles and activates; at the other two only the
chevron responds.

## Placeholder & state widgets

The remaining five are presentation idioms with no auth gate:

- **`TomEmptyState`** — a centred icon + title + description + optional action
  button. Strings resolve from resources when a `tomId` is supplied
  (`<basePath>.title`, `.description`, `.actionLabel`), falling back to the
  explicit parameters. The title is the one string that is genuinely
  required: with neither a `title` nor a `tomId` the **constructor** throws
  a `StateError`, rather than leaving a wordless icon on screen. It throws
  from the constructor and not from `build` so that the failure reaches the
  call site instead of being caught by an enclosing `TomErrorBoundary` and
  shown as an error card — which is why this is the one custom widget
  without a `const` constructor. A `tomId` whose resource is missing renders
  the key, the usual Tom development signal, not silence.
- **`TomLoadingOverlay`** — a `Stack` that lays a scrim + `CircularProgressIndicator`
  (+ optional message) over its `child` when `isLoading` is true; renders only
  the `child` otherwise. `blocksPointerEvents` decides whether the covered
  content stays usable: the scrim is a `ColoredBox`, whose hit testing is
  opaque, so taking the overlay out of hit testing is what hands the pointer
  back — nothing in it is interactive.
- **`TomSkeletonLoader`** — a `SingleTickerProviderStateMixin`-driven shimmer
  over a coloured rectangle, or masked to a `child` silhouette via `ShaderMask`.
  `enabled: false` drops the `ShaderMask` rather than freezing it, and the mask
  is what *paints* the skeleton — so the two forms stop in different places.
  Without a `child` the coloured rectangle remains: a static placeholder. With
  a `child` the child is returned exactly as passed, in its own colours, which
  the mask would otherwise have overpainted. A reduced-motion caller gets a
  placeholder only from the childless form, or from a `child` that is itself a
  silhouette rather than the real content.

  **Two ambient switches reach that same state without the flag**, which
  matters because the widget is often built by something else — this module's
  own `TomInfiniteScroll` default skeleton, where the caller never names it.
  `MediaQuery`'s disable-animations flag and an enclosing
  `TickerMode(enabled: false)` each stop the shimmer, and either is what lets
  `pumpAndSettle` return with a skeleton on screen: a repeating animation
  schedules frames forever, so the binding never reaches a quiescent one.
- **`TomErrorBoundary`** — installs a ref-counted global `ErrorWidget.builder`
  hook that routes a failing subtree's error to the *nearest enclosing*
  boundary (via `findAncestorStateOfType`), so nested boundaries contain their
  own errors regardless of mount order. Renders `fallbackBuilder` (or a
  Material error card) and offers a `retry`.

  **A fallback that throws is caught and stepped past, in bounded time.** A
  boundary falls back in stages, each taken once per failure: the caller's
  `fallbackBuilder`; then, if that throws, the default card — still reporting
  the child's *original* error, the one the user ran into; then, if the card
  fails too, the builder installed before any boundary. So a guarded row stays
  guarded when its fallback is broken, the boundary settles instead of
  rebuilding a failing fallback every frame, and `onError` fires once per
  stage. A `retry` starts again from the child.

  The count and the saved builder live in one private registry rather than as
  two library variables, and `TomErrorBoundary.debugReleaseGlobalHook()`
  (`@visibleForTesting`) hands the slot back and forgets every mounted
  boundary. That state is process-wide because the slot is: a boundary whose
  `dispose` never runs — a test that tears down its binding — would otherwise
  hold `ErrorWidget.builder` for the rest of the process, and everything after
  it would inherit an error widget belonging to a widget that is gone. A
  release is tagged with the run it was taken out in, so a boundary disposing
  after a reset cannot take the slot from whoever holds it now.

  **Ownership of the hook follows the boundary, not its appearance.** A
  boundary holds its share of the ref count for as long as it is in the tree,
  whether it is showing its child or a fallback — so a boundary that has caught
  is still guarding, including its own `fallbackBuilder`, which is caller code
  and can throw. Tying it to the un-caught state instead meant a lone boundary
  released the slot the moment it caught anything, and a list of guarded rows
  lost the hook as its rows failed.

  **An error raised outside every boundary goes where it would have gone
  anyway** — to the builder that held the global slot before the first boundary
  mounted, which is Flutter's red box in debug and the application's own widget
  in release. The slot has one occupant, so a mounted boundary also sees errors
  it does not guard; handing those anywhere else would make one guarded row
  suppress error reporting for the whole process. A boundary is a local guard,
  and mounting one changes nothing outside it.
  **The default skeleton shimmers, so `pumpAndSettle` cannot return while it
  is on screen.** A repeating animation schedules frames forever, and the
  default is six `TomSkeletonLoader`s the caller never names — so the usual
  first line of a downstream widget test hangs for its full timeout. Reduced
  motion (`MediaQuery`'s disable-animations flag) or an enclosing
  `TickerMode(enabled: false)` stops the shimmer and lets it settle. Flutter's
  own indeterminate `CircularProgressIndicator` behaves the same way; what is
  different here is that there is a way out.

- **`TomInfiniteScroll`** — a paginated `ListView` driven by a
  `TomPageFetcher<T>` (`Future<List<T>> Function(int page, int pageSize)`). It
  auto-fetches on two triggers — scrolling within `prefetchOffset` of the end,
  and a page landing that leaves the list with nothing to scroll — stops when a
  short page signals exhaustion, and
  delegates its empty / loading / error slots to `TomEmptyState`,
  `TomSkeletonLoader`, and a built-in error panel. The empty and skeleton slots
  are returned *instead of* the `ListView` and take the whole surface.

  **The error slot is one or the other, depending on whether there is anything
  to preserve.** With nothing loaded it takes the surface, because the failure
  is all there is to show. With items on screen it is the list's last tile and
  the rows stay where they are — a user who has scrolled through ten screens
  does not lose them because page six failed, and the report belongs at the
  boundary they reached. `errorBuilder` is called in both, and is told which by
  a `TomInfiniteScrollErrorPlacement`; a builder that assumes it owns the
  surface will produce a full-height panel inside a tile. Its `TomInfiniteScrollState<T>`
  is intentionally public so a `GlobalKey` can read `loadedCount` /
  `isPending` / `isExhausted` / `hasError` / `error` and call `refresh()`.
  The failure is among them because the other three cannot distinguish a list
  showing an error panel from one showing an empty state — both have nothing
  loaded, nothing in flight and an unexhausted source — and because
  `errorBuilder` receives the failure only inside the widget's own build, so
  there was no way to report it anywhere else.

  **The second trigger is why a full page that fits does not strand the list.**
  Scrolling cannot fire on a list that does not overflow, and exhaustion does
  not cover it either — a *full* page leaves the source unexhausted by
  definition — so a small `pageSize`, a tall viewport or short rows would leave
  one page showing with more data behind it. It applies only when there is no
  scrollable extent at all; anything scrollable is left to the gesture, which
  keeps a load from turning into an immediate second request.

  **`refresh()` is safe to call while a page is in flight, and the fetcher must
  be re-entrant.** It does not wait for the outstanding request — waiting is
  what makes a pull-to-refresh on a slow connection feel broken — so two calls
  can be open at once, and on a first load both are for page 0. The widget
  fences the older one with a generation counter and discards whatever it
  returns, success or failure alike; it cannot *cancel* it, because
  `TomPageFetcher` has no cancellation channel. A fetcher that does anything
  besides return items — writing a cache, marking a page consumed — has to
  tolerate doing it twice, and doing it for a result nobody reads.

## The shared auth lookup

Every auth-gated composite qualifies its `tomId` the same way before calling
`TomAuthorization.resolveAuth`: an explicit `scope` (or `TomScope.current`)
produces a scope path, and `<scopePath>.<tomId>` is the resolved key (a bare
`tomId` when the scope is empty). This is the same context-free lookup the
field widgets use, which is why the example can exercise it directly:

```dart
TomAuthorization.adapter = _PathAuthAdapter({'reports.view': TomAuthState.read});
TomAuthorization.resolveAuth('reports.view');     // TomAuthState.read
TomAuthState.full.narrow(TomAuthState.disabled);  // disabled — the tree's cap
```

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `flutter` | package | 8 of 9 files | `widgets.dart` and `material.dart` |
| `tom_core_kernel` | package | `tom_auth_guard.dart`, `tom_auth_tree.dart`, `tom_empty_state.dart`, `tom_choice_group.dart` | `TomAuthState`, `TomAuthorization`, `TomScope`, and the resource provider used by `TomEmptyState` |
| [widget_base](widget_base.md) | module | `tom_auth_guard.dart`, `tom_auth_tree.dart`, `tom_empty_state.dart`, `tom_choice_group.dart` | `TomCtr` resource resolvers (used by `TomEmptyState`) |

- the sibling custom widgets — `TomInfiniteScroll` reuses `TomEmptyState` and
  `TomSkeletonLoader`.

> The auth lookup, the `TomAuthState` lattice, and the data models are pure,
> but rendering needs a widget tree, and the package barrel pulls in
> `flutter/material` (→ `dart:ui`) — so run the example under the Flutter
> toolchain: see
> [`example/custom/custom_example.dart`](../example/custom/custom_example.dart),
> exercised together with the `testWidgets` render cases by
> [`test/custom/custom_example_test.dart`](../test/custom/custom_example_test.dart)
> via `flutter test`.

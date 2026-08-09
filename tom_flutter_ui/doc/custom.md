# Custom Module

`custom/` is the **non-form composite kit** of `tom_flutter_ui`: eight
ready-made widgets that solve recurring *screen-level* problems — gating a
subtree by permission, showing an empty / loading / error placeholder, paging
a long list. They are not form fields and they do not edit a value, but they
consume the **same authorization, resource, and state systems** the fields use,
so they drop into a Tom screen with no extra wiring.

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
| `TomAuthGuard` | `StatelessWidget` | Hide / disable a `child` by the `TomAuthState` resolved from a `tomId`. |
| `TomAuthTreeView` / `TomAuthTreeNode` | `StatelessWidget` + data model | A tree where every node resolves its own auth; a `disabled` node **caps** its whole subtree. |
| `TomRadioGroup` / `TomRadioGroupItem` | `StatelessWidget` + data model | A radio group whose whole selection is gated by one resource key. |
| `TomEmptyState` | `StatelessWidget` | Icon + title + description + optional action for "no data" surfaces. |
| `TomLoadingOverlay` | `StatelessWidget` | Translucent scrim + spinner (+ message) layered over a subtree while loading. |
| `TomSkeletonLoader` | `StatefulWidget` | Shimmer placeholder for async surfaces (static when `enabled: false`). |
| `TomErrorBoundary` | `StatefulWidget` | Catches build errors in `child` and renders a fallback instead of propagating. |
| `TomInfiniteScroll` | `StatefulWidget` | Paginated list with a `PageFetcher`, reusing the empty / skeleton / error widgets above. |

All eight are exported from the package barrel via
`lib/src/custom/tom_custom_widgets.dart`.

## Authorization widgets

Three of the eight gate their content on a resolved `TomAuthState`. They all
follow the same four-outcome contract:

| State | Treatment |
| ----- | --------- |
| `none` | removed from the tree (`SizedBox.shrink`, or `hiddenBuilder`) |
| `disabled` | rendered, faded to `disabledOpacity`, pointer-blocked |
| `read` | rendered, pointer-blocked (content visible, not interactive) |
| `full` | rendered as-is |

**`TomAuthGuard`** wraps an arbitrary `child`. Its resolution is pulled into a
`@visibleForTesting TomAuthState resolveAuthState()` getter so the decision can
be unit-tested without a widget tree:

```dart
TomAuthorization.adapter = myAdapter;        // 'reports.export' → none
const TomAuthGuard(tomId: 'reports.export', child: ExportButton());
// build → SizedBox.shrink()  (resolveAuthState() == TomAuthState.none)
```

**`TomRadioGroup`** applies **group-level** auth: one `tomId` controls the
entire selection (the per-item `Radio` auth in the widgets kit is per-field).
A `null` `tomId` means "no auth check — always full".

**`TomAuthTreeView`** resolves auth **per node**. Each `TomAuthTreeNode`
carries its own `tomId`, and a node's own auth is folded with what it inherits
via `ownAuth.narrow(inheritedAuth)` — the `TomAuthState.narrow` lattice rule the
example demonstrates. What a node passes down depends on the state it lands on:

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

## Placeholder & state widgets

The remaining five are presentation idioms with no auth gate:

- **`TomEmptyState`** — a centred icon + title + description + optional action
  button. Strings resolve from resources when a `tomId` is supplied
  (`<basePath>.title`, `.description`, `.actionLabel`), falling back to the
  explicit parameters.
- **`TomLoadingOverlay`** — a `Stack` that lays a scrim + `CircularProgressIndicator`
  (+ optional message) over its `child` when `isLoading` is true; renders only
  the `child` otherwise.
- **`TomSkeletonLoader`** — a `SingleTickerProviderStateMixin`-driven shimmer
  over a coloured rectangle, or masked to a `child` silhouette via `ShaderMask`.
  Setting `enabled: false` yields a static placeholder (for tests / reduced
  motion).
- **`TomErrorBoundary`** — installs a ref-counted global `ErrorWidget.builder`
  hook that routes a failing subtree's error to the *nearest enclosing*
  boundary (via `findAncestorStateOfType`), so nested boundaries contain their
  own errors regardless of mount order. Renders `fallbackBuilder` (or a
  Material error card) and offers a `retry`.
- **`TomInfiniteScroll`** — a paginated `ListView` driven by a
  `PageFetcher<T>` (`Future<List<T>> Function(int page, int pageSize)`). It
  auto-fetches near the bottom, stops when a short page signals exhaustion, and
  delegates its empty / loading / error slots to `TomEmptyState`,
  `TomSkeletonLoader`, and a built-in error tile. Its `TomInfiniteScrollState<T>`
  is intentionally public so a `GlobalKey` can read `loadedCount` / `isPending`
  / `isExhausted` and call `refresh()`.

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

- `package:flutter/material.dart` — the underlying widgets each composite
  assembles.
- `package:tom_core_kernel/...` — `TomAuthState`, `TomAuthorization`,
  `TomScope`, and the resource provider used by `TomEmptyState`.
- `../widget_base/tom_construction_helpers.dart` — `TomCtr` resource resolvers
  (used by `TomEmptyState`).
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

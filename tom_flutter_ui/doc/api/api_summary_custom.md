# Tom Flutter UI API Reference: Custom Module

Eight composites that are not form fields: authorization guards, list states,
and loading affordances.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Exported Surface](#exported-surface)
- [Authorization composites](#authorization-composites)
  - [TomAuthGuard](#tomauthguard)
  - [TomAuthTreeView](#tomauthtreeview)
  - [TomAuthTreeNode](#tomauthtreenode)
  - [TomChoiceGroup\<T\>](#tomchoicegroupt)
  - [TomChoiceGroupItem\<T\>](#tomchoicegroupitemt)
- [List and surface states](#list-and-surface-states)
  - [TomInfiniteScroll\<T\>](#tominfinitescrollt)
  - [TomInfiniteScrollState\<T\>](#tominfinitescrollstatet)
  - [TomInfiniteScrollErrorPlacement](#tominfinitescrollerrorplacement)
  - [TomPageFetcher\<T\>](#tompagefetchert)
  - [TomInfiniteScrollItemBuilder\<T\>](#tominfinitescrollitembuildert)
  - [TomInfiniteScrollErrorBuilder](#tominfinitescrollerrorbuilder)
  - [TomEmptyState](#tomemptystate)
- [Failure and progress](#failure-and-progress)
  - [TomErrorBoundary](#tomerrorboundary)
  - [TomErrorBoundaryFallbackBuilder](#tomerrorboundaryfallbackbuilder)
  - [TomLoadingOverlay](#tomloadingoverlay)
  - [TomSkeletonLoader](#tomskeletonloader)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/custom/tom_auth_guard.dart`, `lib/src/custom/tom_auth_tree.dart`, `lib/src/custom/tom_choice_group.dart`, `lib/src/custom/tom_custom_widgets.dart`, `lib/src/custom/tom_empty_state.dart`, `lib/src/custom/tom_error_boundary.dart`, `lib/src/custom/tom_infinite_scroll.dart`, `lib/src/custom/tom_loading_overlay.dart`, `lib/src/custom/tom_skeleton_loader.dart`.

The module `lib/src/custom/` is barrelled by `tom_custom_widgets.dart`.

These extend `StatelessWidget` / `StatefulWidget` directly rather than a
`TomFamilyBase`, and they reach for the package's systems only where each
genuinely needs one — `TomAuthGuard`, `TomAuthTreeView` and `TomChoiceGroup`
resolve authorization through the kernel, `TomEmptyState` resolves resources,
and the other four take their appearance from the ambient `ThemeData`. None of
them takes a Tom style object, which is why `TomChoiceGroup` is named apart
from the forms module's `TomRadioGroupStyle`.

Three of them gate content on a `TomAuthState` and share one contract:

| State | Treatment |
| ----- | --------- |
| `none` | removed from the tree |
| `disabled` | rendered, faded to `disabledOpacity`, pointer-blocked |
| `read` | rendered, pointer-blocked — visible, not interactive |
| `full` | rendered as-is |

"Pointer-blocked" is an `IgnorePointer` in all three, so arbitrary interactive
content inside is inert and not merely un-styled. What differs is the extent of
the block, which follows from how many keys each has: `TomAuthGuard` blocks its
whole `child`, `TomChoiceGroup` the whole group, and `TomAuthTreeView` each
node's own row.

## Class Hierarchy

```
Widget
├── StatelessWidget
│   ├── TomAuthGuard
│   ├── TomAuthTreeView
│   ├── TomChoiceGroup<T>
│   ├── TomEmptyState
│   └── TomLoadingOverlay
└── StatefulWidget
    ├── TomErrorBoundary
    ├── TomInfiniteScroll<T>        (State: TomInfiniteScrollState<T>, public)
    └── TomSkeletonLoader

(data models)
├── TomAuthTreeNode
└── TomChoiceGroupItem<T>

(enums)
└── TomInfiniteScrollErrorPlacement

(typedefs)
├── TomPageFetcher<T>
├── TomInfiniteScrollItemBuilder<T>
├── TomInfiniteScrollErrorBuilder
└── TomErrorBoundaryFallbackBuilder
```

`TomAuthState`, `TomAuthorization` and `TomScope` are declared in
`tom_core_kernel` and reach this module through its barrel.

## Exported Surface

| File | Public declarations |
| ---- | ------------------- |
| `tom_auth_guard.dart` | `TomAuthGuard` |
| `tom_auth_tree.dart` | `TomAuthTreeView`, `TomAuthTreeNode` |
| `tom_choice_group.dart` | `TomChoiceGroup`, `TomChoiceGroupItem` |
| `tom_empty_state.dart` | `TomEmptyState` |
| `tom_error_boundary.dart` | `TomErrorBoundary`, `TomErrorBoundaryFallbackBuilder` |
| `tom_infinite_scroll.dart` | `TomInfiniteScroll`, `TomInfiniteScrollState`, `TomInfiniteScrollErrorPlacement`, `TomPageFetcher`, `TomInfiniteScrollItemBuilder`, `TomInfiniteScrollErrorBuilder` |
| `tom_loading_overlay.dart` | `TomLoadingOverlay` |
| `tom_skeleton_loader.dart` | `TomSkeletonLoader` |

Fifteen public declarations. Two public static members,
`TomErrorBoundary.debugReleaseGlobalHook` and
`TomErrorBoundary.debugDefaultFallback`, and one `@visibleForTesting` instance
method, `TomAuthGuard.resolveAuthState`.

## Authorization composites

### TomAuthGuard

Hides, locks or passes through a subtree by the authorization state of one
resource key.

**Kind:** `class extends StatelessWidget`

```dart
const TomAuthGuard({
  Key? key,
  required String tomId,
  required Widget child,
  TomScope? scope,
  WidgetBuilder? hiddenBuilder,
  double disabledOpacity = 0.4,
  bool blockPointerOnRead = true,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `tomId` | `String` | Resource key, qualified by `scope` or the ambient `TomScope`. |
| `child` | `Widget` | The guarded subtree. One key governs all of it. |
| `scope` | `TomScope?` | Explicit scope; the ambient one when null. |
| `hiddenBuilder` | `WidgetBuilder?` | Rendered at `none` instead of `SizedBox.shrink()`. |
| `disabledOpacity` | `double` | Fade applied at `disabled`. |
| `blockPointerOnRead` | `bool` | Whether `read` also blocks pointers. The one documented way back into a withheld subtree. |

| Method | Description |
|--------|-------------|
| `resolveAuthState()` | The decision without a widget tree. `@visibleForTesting`. |

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `build` | `Widget build(BuildContext context)` |  |

### TomAuthTreeView

A tree in which **every node resolves its own authorization**.

**Kind:** `class extends StatelessWidget`

```dart
const TomAuthTreeView({
  Key? key,
  required List<TomAuthTreeNode> nodes,
  String? parentPath,
  double indentation = 24,
  bool initiallyExpanded = true,
  EdgeInsetsGeometry? padding,
  bool shrinkWrap = false,
  ScrollPhysics? physics,
  double disabledOpacity = 0.4,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `nodes` | `List<TomAuthTreeNode>` | Top-level nodes. |
| `parentPath` | `String?` | Prefix for the **top-level** nodes only; the ambient scope when null or empty. Deeper nodes are qualified by their own ancestors. |
| `indentation` | `double` | Pixels per nesting level. |
| `initiallyExpanded` | `bool` | Default for nodes that do not override it. |
| `padding` | `EdgeInsetsGeometry?` | Around the outer scroll view. |
| `shrinkWrap` | `bool` | Passed to the inner `ListView`. |
| `physics` | `ScrollPhysics?` | Passed to the inner `ListView`. |
| `disabledOpacity` | `double` | Fade applied to a `disabled` node's row. |

Only a `disabled` node caps its subtree; a `read` node leaves descendants to
their own keys. Expanding is independent of all four states — the chevron sits
outside the barrier and outside the fade.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `build` | `Widget build(BuildContext context)` |  |

### TomAuthTreeNode

One node of a [TomAuthTreeView](#tomauthtreeview).

**Kind:** `class`

```dart
TomAuthTreeNode({
  required String tomId,
  required Widget title,
  Widget? leading,
  Widget? trailing,
  List<TomAuthTreeNode> children = const [],
  bool? initiallyExpanded,
  VoidCallback? onTap,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `tomId` | `String` | Key segment, unique **among siblings**. Paths compose along the branch: `<parentPath>.<ancestor ids…>.<own id>`. |
| `title` | `Widget` | The row's content. |
| `leading` | `Widget?` | Icon, avatar, … Covered by the node's pointer block. |
| `trailing` | `Widget?` | Badge, action button, … Covered by the same block. |
| `children` | `List<TomAuthTreeNode>` | Child nodes; empty for a leaf. |
| `initiallyExpanded` | `bool?` | Overrides the tree's default. |
| `onTap` | `VoidCallback?` | Suppressed at `read` and `disabled`, as is everything else in the row. |

### TomChoiceGroup\<T\>

Single-select radio group whose authorization is **group-level**: one key
governs the whole selection.

**Kind:** `class extends StatelessWidget`

```dart
const TomChoiceGroup({
  Key? key,
  String? tomId,
  TomScope? scope,
  required List<TomChoiceGroupItem<T>> items,
  T? selected,
  void Function(T value)? onChanged,
  String? title,
  double disabledOpacity = 0.4,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `tomId` | `String?` | Group key. `null` means no check — always `full`. |
| `scope` | `TomScope?` | Explicit scope; the ambient one when null. |
| `items` | `List<TomChoiceGroupItem<T>>` | The options. |
| `selected` | `T?` | Current value. |
| `onChanged` | `void Function(T)?` | Selection handler. Suppressed at `read` and `disabled`. |
| `title` | `String?` | Optional heading above the options. |
| `disabledOpacity` | `double` | Fade applied at `disabled`. |

The column sits under a Flutter `RadioGroup<T>`, which is where a radio's
selection comes from and which brings arrow-key navigation with it — so the
two withheld states pass `enabled: false` to every `Radio` as well as blocking
the pointer. `IgnorePointer` does not stop a keyboard.

### TomChoiceGroupItem\<T\>

One option of a [TomChoiceGroup](#tomchoicegroupt).

**Kind:** `class`

```dart
const TomChoiceGroupItem({
  required T value,
  required String label,
  String? description,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | `T` | The value this option selects. |
| `label` | `String` | Primary text. |
| `description` | `String?` | Optional supporting line beneath the label. |

## List and surface states

### TomInfiniteScroll\<T\>

A paginated `ListView` driven by a page fetcher.

**Kind:** `class extends StatefulWidget`

```dart
const TomInfiniteScroll({
  Key? key,
  required TomPageFetcher<T> fetcher,
  required TomInfiniteScrollItemBuilder<T> itemBuilder,
  int pageSize = 20,
  double prefetchOffset = 200,
  WidgetBuilder? skeletonBuilder,
  WidgetBuilder? emptyBuilder,
  TomInfiniteScrollErrorBuilder? errorBuilder,
  EdgeInsetsGeometry? padding,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `fetcher` | `TomPageFetcher<T>` | Fetches one page. **Must be idempotent and re-entrant** — see the typedef. |
| `itemBuilder` | `TomInfiniteScrollItemBuilder<T>` | Builds one row. |
| `pageSize` | `int` | Items per page. A page shorter than this exhausts the source. |
| `prefetchOffset` | `double` | Pixels from the end at which a scroll triggers the next page. |
| `skeletonBuilder` | `WidgetBuilder?` | Initial-load slot. Defaults to six `TomSkeletonLoader` tiles, which shimmer — see [TomSkeletonLoader](#tomskeletonloader) for what that means for `pumpAndSettle`. |
| `emptyBuilder` | `WidgetBuilder?` | Empty slot. Defaults to a `TomEmptyState`. |
| `errorBuilder` | `TomInfiniteScrollErrorBuilder?` | Failure slot, called in **both** placements. |
| `padding` | `EdgeInsetsGeometry?` | Around the inner `ListView`. |

Pages are asked for on two triggers: a scroll within `prefetchOffset` of the
end, and a page landing that leaves the list with no scrollable extent. The
second exists because the first cannot fire on a list that does not overflow,
and a *full* page that happens to fit leaves the source unexhausted.

### TomInfiniteScrollState\<T\>

The list's state, public so a `GlobalKey<TomInfiniteScrollState<T>>` can drive
and inspect it.

**Kind:** `class extends State<TomInfiniteScroll<T>>`

| Member | Type | Description |
|--------|------|-------------|
| `loadedCount` | `int` | Items currently loaded. |
| `isPending` | `bool` | Whether a page fetch is in flight. |
| `isExhausted` | `bool` | Whether the last page came back short. |
| `hasError` | `bool` | Whether the list is reporting a failure. |
| `error` | `Object?` | That failure, or null. The other three cannot tell an error panel from an empty state. |
| `refresh()` | `Future<void>` | Clears the loaded set and re-issues page 0. Safe to call while a fetch is in flight: the outstanding request is abandoned, not awaited. |

### TomInfiniteScrollErrorPlacement

Where a page failure is being reported.

**Kind:** `enum`

| Value | Meaning |
|-------|---------|
| `surface` | Nothing is loaded, so the report takes the whole surface. |
| `tile` | Items are on screen and stay there; the report is the list's last tile. |

### TomPageFetcher\<T\>

**Kind:** `typedef` — `Future<List<T>> Function(int page, int pageSize)`.

`page` is zero-based. Returning fewer items than `pageSize` signals
end-of-source. **Must be idempotent**: a failed fetch does not advance the
cursor, so a retry re-requests the page that failed, and `refresh()` restarts
from page 0. **And re-entrant**: a `refresh()` during an in-flight fetch leaves
two calls outstanding, and the older one's result is discarded rather than
cancelled — there is no cancellation channel — so anything the callback does
besides returning items must be safe to do twice and safe to do for nothing.

### TomInfiniteScrollItemBuilder\<T\>

**Kind:** `typedef` — `Widget Function(BuildContext context, T item, int index)`.

### TomInfiniteScrollErrorBuilder

**Kind:** `typedef` — `Widget Function(BuildContext context, Object error, VoidCallback retry, TomInfiniteScrollErrorPlacement placement)`.

Called in both placements, so a builder that assumes it owns the surface will
produce a full-height panel inside a list tile. `retry` re-issues the page that
failed.

### TomEmptyState

Placeholder for a view that loaded and has nothing to show — distinct from a
loading state, which has not finished, and an error state, which failed.

**Kind:** `class extends StatelessWidget`

```dart
TomEmptyState({
  Key? key,
  String? tomId,
  TomScope? scope,
  IconData icon = Icons.inbox_outlined,
  String? title,
  String? description,
  String? actionLabel,
  VoidCallback? onActionPressed,
  double iconSize = 48,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `tomId` | `String?` | Base path for `<basePath>.title` / `.description` / `.actionLabel`. |
| `scope` | `TomScope?` | Explicit scope; the ambient one when null. |
| `icon` | `IconData` | Glyph above the headline. |
| `title` | `String?` | Headline **fallback**. A resource wins when both are present. |
| `description` | `String?` | Supporting copy fallback. |
| `actionLabel` | `String?` | Action button label fallback. |
| `onActionPressed` | `VoidCallback?` | Handler. The button appears only when a label resolves *and* this is given. |
| `iconSize` | `double` | Icon diameter. |

Not `const`, deliberately: the strings are resolved in the constructor so a
missing headline throws on the caller's own line rather than inside `build`,
where an enclosing [TomErrorBoundary](#tomerrorboundary) would convert it into
an error card. Supplying neither a `title` nor a `tomId` is a `StateError`; a
`tomId` whose resource is missing renders the key.

## Failure and progress

### TomErrorBoundary

Catches errors raised while the guarded subtree **builds** and renders a
fallback instead.

**Kind:** `class extends StatefulWidget`

```dart
const TomErrorBoundary({
  Key? key,
  required Widget child,
  TomErrorBoundaryFallbackBuilder? fallbackBuilder,
  void Function(FlutterErrorDetails details)? onError,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `child` | `Widget` | The guarded subtree. |
| `fallbackBuilder` | `TomErrorBoundaryFallbackBuilder?` | Replaces the default Material error card. If it throws, the boundary shows the default card with the original error; if that fails too, the error goes to the builder installed before any boundary. |
| `onError` | `void Function(FlutterErrorDetails)?` | Called once per caught error, for logging or routing elsewhere. |

| Static member | Description |
|---------------|-------------|
| `debugDefaultFallback` | Static `TomErrorBoundaryFallbackBuilder?` that replaces the default card, so a test can make it fail. `@visibleForTesting`; `null` in an application. |
| `debugReleaseGlobalHook()` | Hands `ErrorWidget.builder` back and forgets every mounted boundary. `@visibleForTesting`; the count is process-wide, so a boundary whose `dispose` never runs would otherwise hold the slot for the rest of the process. |

A boundary guards its own subtree and nothing else: while any is mounted its
hook also sees errors raised outside every boundary, and those are handed to
the builder that held the slot beforehand — Flutter's red box in debug, the
application's own widget in release. It keeps the hook for as long as it is in
the tree, whether or not it is currently showing a fallback.

### TomErrorBoundaryFallbackBuilder

**Kind:** `typedef` — `Widget Function(BuildContext context, FlutterErrorDetails details, VoidCallback retry)`.

`retry` resets the boundary and re-attempts the build.

### TomLoadingOverlay

A scrim and a progress indicator over a subtree.

**Kind:** `class extends StatelessWidget`

```dart
const TomLoadingOverlay({
  Key? key,
  required Widget child,
  required bool isLoading,
  String? message,
  Color scrimColor = const Color(0x66000000),
  double? progress,
  bool blocksPointerEvents = true,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `child` | `Widget` | What the overlay covers. |
| `isLoading` | `bool` | Whether the overlay is shown at all. |
| `message` | `String?` | Optional caption beneath the indicator. |
| `scrimColor` | `Color` | The veil over the child. |
| `progress` | `double?` | Progress from 0 to 1 for the indicator; `null` keeps it indeterminate. |
| `blocksPointerEvents` | `bool` | Whether the covered child stops receiving pointers. |

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `build` | `Widget build(BuildContext context)` |  |

### TomSkeletonLoader

Shimmer placeholder for a surface that is still loading.

**Kind:** `class extends StatefulWidget`

```dart
const TomSkeletonLoader({
  Key? key,
  Widget? child,
  double width = 120,
  double height = 16,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(4)),
  Color? baseColor,
  Color? highlightColor,
  Duration period = const Duration(milliseconds: 1200),
  bool enabled = true,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `child` | `Widget?` | Silhouette the shimmer is masked to. Only the silhouette survives — the mask replaces the child's colours. Pass a placeholder shape, not real content. |
| `width` / `height` | `double` | The rectangle drawn when there is no `child`. |
| `borderRadius` | `BorderRadius` | Corners of that rectangle. |
| `baseColor` | `Color?` | Shimmer base. Defaults to `colorScheme.surfaceContainerHighest`. |
| `highlightColor` | `Color?` | Shimmer highlight. Defaults to `colorScheme.surface`. |
| `period` | `Duration` | One shimmer cycle. |
| `enabled` | `bool` | Whether the shimmer runs. `false` **drops the mask** rather than freezing it, so the childless form keeps its rectangle and the `child` form comes back in its own colours. |

The shimmer also stops when the environment says so: `MediaQuery`'s
disable-animations flag and an enclosing `TickerMode(enabled: false)` each
reach the same state without the flag. Either is what lets a test
`pumpAndSettle` with a skeleton on screen — a repeating animation schedules
frames forever, so the binding never reaches a quiescent one.

## Global Functions and Constants

None — this module exports types only.

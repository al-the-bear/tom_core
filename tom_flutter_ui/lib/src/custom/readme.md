# custom

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The non-form composites: eight ready-made widgets that solve recurring
*screen-level* needs — guarding a subtree behind a permission, a tree whose
nodes are guarded one by one, empty / loading / error placeholders, an
infinite-scroll list, a skeleton placeholder, and a radio group.

Unlike the [`widgets`](../widgets/readme.md) kit, whose wrappers extend a
`TomFamilyBase`, these extend `StatelessWidget` / `StatefulWidget` directly and
assemble several Flutter widgets into one idiom. None of them is a field, none
edits a value, and none resolves colours or icons through
[`resource_auth`](../resource_auth/readme.md) — they take their appearance from
the ambient `ThemeData` like ordinary Flutter widgets.

What they do share with the rest of the package is the authorization and
resource systems, but only where each one genuinely needs them:

| Consumes | Widgets |
| -------- | ------- |
| the kernel's `TomAuthorization` / `TomAuthState` | `TomAuthGuard`, `TomAuthTreeView`, `TomChoiceGroup` |
| resources, via `TomCtr` from [`widget_base`](../widget_base/readme.md) — and only when given a `tomId` | `TomEmptyState` |
| neither — pure presentation | `TomErrorBoundary`, `TomLoadingOverlay`, `TomSkeletonLoader`, `TomInfiniteScroll` |

`tom_empty_state.dart` is this module's single import from `widget_base`, which
makes `custom` the one module that does not rest on it.

## Key types

Every type `tom_custom_widgets.dart` exports, the eight widgets first and then
the models and signatures they take:

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthGuard` | Renders / elides / locks a `child` by the `tomId`'s authorization state |
| `TomAuthTreeView` | Tree view whose nodes honour authorization |
| `TomEmptyState` | Title / description / optional action for empty collections |
| `TomErrorBoundary` | Catches and renders a child subtree's errors |
| `TomInfiniteScroll` | Lazy-loading scrollable list |
| `TomLoadingOverlay` | A scrim + message over a `child` while `isLoading` |
| `TomChoiceGroup` | A single-select radio group. Named apart from the forms module's `TomRadioGroupStyle`, which themes the radio-group *field* and does nothing here |
| `TomSkeletonLoader` | Shimmer placeholder while content loads |
| `TomAuthTreeNode` | One node of a `TomAuthTreeView` — its own `tomId`, title, children |
| `TomChoiceGroupItem` | One option of a `TomChoiceGroup` — value and label |
| `TomInfiniteScrollState` | `TomInfiniteScroll`'s state, public so a `GlobalKey` can read `loadedCount` / `isPending` / `isExhausted` / `hasError` / `error` and call `refresh()` |
| `TomPageFetcher` | Signature of `TomInfiniteScroll.fetcher`; **must be idempotent** |
| `TomInfiniteScrollItemBuilder` | Signature building one row of a `TomInfiniteScroll` |
| `TomInfiniteScrollErrorBuilder` | Signature of `TomInfiniteScroll.errorBuilder` — the error, a `retry`, and where it is being rendered |
| `TomInfiniteScrollErrorPlacement` | Whether a page failure takes the surface or is the list's last tile |
| `TomErrorBoundaryFallbackBuilder` | Signature of `TomErrorBoundary.fallbackBuilder` — the error details plus a `retry` closure |

## Static entry points

| Member | Purpose |
| ------ | ------- |
| `TomAuthGuard.resolveAuthState` | The guard's decision without a widget tree — `@visibleForTesting` |
| `TomErrorBoundary.debugReleaseGlobalHook` | Hands `ErrorWidget.builder` back and forgets every mounted boundary. The count that owns that slot is process-wide, so a boundary whose `dispose` never runs would otherwise hold it for the rest of the process. `@visibleForTesting`; an application never needs it |

## Quick start

Nothing has to be installed for the widgets below. No colours adapter, because
none of the eight resolves a colour through `TomUIColors`; and no resource
provider, because the only widget that reads resources — `TomEmptyState` — does
so only when given a `tomId`, and this one is passed literals. Add a `tomId` and
a `TomTextResourceProvider` becomes mandatory: an uninstalled lookup throws
rather than bootstrapping itself.

```dart
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void buildComposites() {
  const guard = TomAuthGuard(tomId: 'reports.export', child: SizedBox());
  const overlay = TomLoadingOverlay(
    isLoading: true,
    message: 'Saving…',
    child: SizedBox(),
  );
  // The one that is not const: TomEmptyState resolves its headline in the
  // constructor, so a missing title fails at the call site rather than
  // becoming an error card inside some enclosing TomErrorBoundary.
  final empty = TomEmptyState(title: 'No items', description: 'Nothing yet.');
  const currency = TomChoiceGroup<String>(
    tomId: 'currency',
    items: [TomChoiceGroupItem(value: 'eur', label: 'Euro')],
    selected: 'eur',
  );
  print([guard, overlay, empty, currency].length); // 4
}
```

---

## Where the rest is written down

| Document | Answers |
| -------- | ------- |
| [`doc/custom.md`](../../../doc/custom.md) | What each composite is for, the shared authorization contract, and how the eight differ. |
| [`doc/api/api_summary_custom.md`](../../../doc/api/api_summary_custom.md) | The symbol-level mirror: every exported type with a section, every public constructor parameter, and every public static. |

Two runnable examples sit under
[`example/custom/`](../../../example/custom).
`custom_rendered_example.dart` assembles all eight widgets into one app and
checks each once it is on screen; `custom_example.dart` covers the parts that
need no widget tree — the `TomAuthState` lattice, the resource-path lookup, and
the data models. Each names the suite that runs it.

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

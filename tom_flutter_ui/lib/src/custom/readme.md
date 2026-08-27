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
| the kernel's `TomAuthorization` / `TomAuthState` | `TomAuthGuard`, `TomAuthTreeView`, `TomRadioGroup` |
| resources, via `TomCtr` from [`widget_base`](../widget_base/readme.md) | `TomEmptyState` |
| neither — pure presentation | `TomErrorBoundary`, `TomLoadingOverlay`, `TomSkeletonLoader`, `TomInfiniteScroll` |

`tom_empty_state.dart` is this module's single import from `widget_base`, which
makes `custom` the one module that does not rest on it.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthGuard` | Renders / elides / locks a `child` by the `tomId`'s authorization state |
| `TomAuthTreeView` | Tree view whose nodes honour authorization |
| `TomEmptyState` | Title / description / optional action for empty collections |
| `TomErrorBoundary` | Catches and renders a child subtree's errors |
| `TomLoadingOverlay` | A scrim + message over a `child` while `isLoading` |
| `TomInfiniteScroll` | Lazy-loading scrollable list |
| `TomRadioGroup` / `TomRadioGroupItem` | A single-select radio group |
| `TomSkeletonLoader` | Shimmer placeholder while content loads |

## Quick start

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
  const currency = TomRadioGroup<String>(
    tomId: 'currency',
    items: [TomRadioGroupItem(value: 'eur', label: 'Euro')],
    selected: 'eur',
  );
  print([guard, overlay, empty, currency].length); // 4
}
```

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

# custom

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The non-form composites: ready-made, authorization-aware widgets that solve
recurring application needs — guarding a subtree behind a permission, an
empty/error/loading state, an infinite-scroll list, a skeleton placeholder, and a
radio group. They build on [`widget_base`](../widget_base/readme.md) and resolve
appearance through [`resource_auth`](../resource_auth/readme.md).

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
  TomUIColors.adapter = AllColorsAdapter();

  const guard = TomAuthGuard(tomId: 'reports.export', child: SizedBox());
  const overlay = TomLoadingOverlay(
    isLoading: true,
    message: 'Saving…',
    child: SizedBox(),
  );
  const empty = TomEmptyState(title: 'No items', description: 'Nothing yet.');
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

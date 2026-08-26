# advanced_container_layout

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The ACL engine: a fluent, row-based layout builder modelled on the Java Swing
`StdAdvancedContainer` / `AdvancedContainerLike` API, with first-class
authorization integration. You describe a form-like grid one component at a time
— sizing, growth, borders, titled groups, and responsive variants — and `build()`
hands back a plain Flutter widget.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `AclBuilder` | Fluent builder — `append`, `gap`, `newRow`, `setPSize` / `setMSize`, `expandX` |
| `Acl` / `AclLayout` / `AclContainer` | The rendered layout widgets `build()` returns |
| `AclFlags` | `expandX` / `expandY` / `expand` growth-flag constants |
| `AclBorderStyle` / `AclBorderKind` / `AclTitlePosition` | Border & titled-group styling |
| `AclFlowContainer` / `AclFlowKind` | Row-**generating** containers: `wrap` and `grid` |
| `AclVariant` / `AclRowBreakpoint` / `AclVariantDetector` | Responsive variants & breakpoints |
| `AclGroupVisibilityController` | Group show / hide control |
| `AclDeviceContext` / `AclFormFactor` / `AclDensity` | Adaptive device-sizing inputs |

## Quick start

```dart
import 'package:flutter/widgets.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget buildAddressLayout() {
  // Two rows; the second cell grows to fill surplus width.
  final Widget acl = AclBuilder(title: 'Address')
      .append(const Text('Street'))
      .gap()
      .append(const Text('No.'))
      .expandX()
      .newRow()
      .append(const Text('City'))
      .build();

  assert(acl is Acl);
  return acl;
}
```

`setPSize` / `setMSize` give a component a preferred / minimum width; `expandX()`
distributes surplus; `addVariant` / `addRowBreakpoint` make the layout responsive;
`AclBorderStyle` + `AclTitlePosition` draw a titled group.

## Flowing a flat child list — `wrap` and `grid`

`AclBuilder` is for layouts whose rows you author. When instead you have **one
undivided sequence** and want the container to decide where the rows break, use
`AclFlowContainer`:

```dart
// Break whenever the next chip no longer fits the line.
AclFlowContainer(
  kind: AclFlowKind.wrap,
  aclId: 'tags',
  components: tags.map((t) => AclComponent(child: Chip(label: Text(t)))).toList(),
);

// Three columns above 600 px wide, one below.
AclFlowContainer(
  kind: AclFlowKind.grid,
  columns: 1,
  columnsBpOverrides: const [(600.0, 3)],
  components: cells,
);
```

Both are **row-generating**, not a second layout engine: they compute an
`AclRow` list (`aclWrapRows` / `aclGridRows` — pure functions you can call and
assert on directly) and render it through the ordinary `AclContainer`, so ids,
alignment anchors, sizing and the hide-unauthorized pass all behave exactly as
they do for an authored layout. Give the container an `aclId` and each generated
row becomes addressable as `<aclId>.r<n>`. `AclVariant`s are the exception —
`AclFlowContainer` forwards no `variants` to the container it composes, so use
`columnsBpOverrides` for a flow container's own responsiveness.

Because the flow decision happens *before* layout, `wrap` sizes a component by
its declared preferred → minimum width, falling back to
`kAclDefaultFlowItemWidth`; declare a size on children whose natural width
matters.

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

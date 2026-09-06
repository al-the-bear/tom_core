# advanced_container_layout

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The ACL engine: a fluent, row-based layout builder modelled on the Java Swing
`StdAdvancedContainer` / `AdvancedContainerLike` API, with first-class
authorization integration. You describe a form-like grid one component at a time
— sizing, growth, borders, titled groups, and responsive variants — and `build()`
hands back a plain Flutter widget.

## Key types

This table is a complete inventory of what
`advanced_container_layout/advanced_container_layout.dart` exports;
`test/module_readme_inventory_test.dart` fails if the module gains a public
type or static this table does not name.

| Type | Responsibility |
| ---- | -------------- |
| `AclBuilder` | Fluent builder — `append`, `gap`, `newRow`, `setPSize` / `setMSize`, `expandX`. `AclBuilder.defaultPreferredWidth` (150) is the width a component gets when it declares none |
| `AclBuilderExtensions` | The builder's convenience methods, kept off the class so the core stays small |
| `AclFlags` | Growth and role flags: `AclFlags.expandX`, `expandY`, `expand`, `otherDimX`, `otherDimY`, `otherDim` (grow in the cross dimension) and `gapElement` (this cell is a gap, not content) |
| `Acl` / `AclLayout` / `AclContainer` | The rendered layout widgets `build()` returns |
| `AclComponent` / `AclRow` | One cell and one row of the computed grid — the data an authored or generated layout reduces to |
| `AclBorderStyle` / `AclBorderKind` | Border appearance and which kind is drawn |
| `AclTitlePosition` / `AclTitleBorderAlign` | Where a titled group's title sits, and how the border aligns to it |
| `AclAxisPointX` / `AclAxisPointY` | Horizontal and vertical anchor points for a component within its cell |
| `AclRowCrossAlignment` / `RowAlignment` | How a row aligns its components across the row's height |
| `AclSeparator` / `AclSeparatorStyle` / `AclSeparatorAlignment` | Rules drawn between rows: the separator, `single` vs `doubleLine`, and where in the gap it sits |
| `AclDirection` / `AclDirectionScope` | LTR / RTL for the layout, and the inherited widget that supplies it — read with `AclDirectionScope.maybeOf(context)`, which answers `null` rather than throwing when no scope is above |
| `AclScope` | Inherited id-scope for nested layouts; `AclScope.of(context)` reads it |
| `AclFlowContainer` / `AclFlowKind` | Row-**generating** containers: `wrap` and `grid` |
| `AclVariant` / `AclRowBreakpoint` / `AclVariantDetector` | Responsive variants & breakpoints |
| `AclDeviceContext` | Adaptive sizing inputs, with the four resolvers that derive them: `AclDeviceContext.resolveInputMode`, `resolveFormFactor`, `resolveDensity`, and `buildConvenienceDetector` (an `AclVariantDetector` assembled from plain thresholds) |
| `AclInputMode` / `AclFormFactor` / `AclDensity` | What those resolvers answer: `touch` vs `pointer`, the form factor band, and the density step |
| `AclGroupVisibilityController` | Group show / hide control, with `AclGroupVisibilityMode` selecting how a hidden group collapses |
| `AclBinaryVisibilityController` / `AclCallbackVisibilityController` | The two shipped controllers — a plain on/off flag, and one that asks a callback per group |

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
they do for an authored layout. Generated rows are named `r<n>`; give the
container an `aclId` **and** `idScope: true` and each becomes addressable as
`<aclId>.r<n>`. `AclVariant`s are the exception —
`AclFlowContainer` forwards no `variants` to the container it composes, so use
`columnsBpOverrides` for a flow container's own responsiveness.

Because the flow decision happens *before* layout, `wrap` sizes a component by
its declared preferred → minimum width, falling back to
`kAclDefaultFlowItemWidth`; declare a size on children whose natural width
matters.

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

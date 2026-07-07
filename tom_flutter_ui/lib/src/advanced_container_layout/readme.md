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

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

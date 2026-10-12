# groups

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Collective visibility and authorization control. A `TomAuthorizationGroup` lets
many widgets share one authorization decision without tagging every leaf with an
id: each member registers with the group, and its `effectiveAuthState` is
combined with the group's according to the group's mode — which narrows the
member, widens it, or replaces it outright. The group type is the kernel's, so
the same grouping concept spans widgets, forms, and actions.

This module owns only the widget-side wiring. The group itself
(`TomAuthorizationGroup`, `AuthGroupMode`) is defined in `tom_core_kernel` and
reaches consumers through `kernel_types.dart`, so importing `tom_flutter_ui` is
enough to name both.

Most Tom widgets resolve their own authorization, because they own a `build` to
resolve it in. A handful cannot: `DataCell`, `DataColumn`, `DataRow` and
`ExpansionPanel` are plain classes rather than widgets, and `SnackBar`,
`SnackBarAction` and `AnimatedPositioned` keep their `State` private to the
framework. Those wrappers put a `TomAuthGate` in the slot they own instead, so
the decision still comes from this module's one resolver rather than from a
second, weaker copy of it.

A widget is a member of its group while it is mounted, never merely because it
was constructed. A widget instance is replaced on every rebuild of its parent
and is not told when it leaves the tree, so the registration is held by its
element: every Tom widget returns a `TomGroupMemberElement` from
`createElement`, and a group's `members` are exactly the Tom widgets in the
tree. Fields and actions are not widgets; they are members from construction
until their form or controller is disposed.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthorizationGroup` | A named visibility/auth group — defined in `tom_core_kernel`, bridged by `kernel_types.dart` |
| `AuthGroupMode` | How the group's state applies to a member: `controlsAll` replaces it, `controlsWidest` (the default) caps it at a ceiling, `controlsNarrowest` lifts it to a floor |
| `TomWidgetMixin` | Mixed into a widget to give it a `tomId`, a `tomGroup` and the authorization helpers |
| `TomAuthGate` | Wraps one slot of a wrapper that cannot gate itself — because the Flutter original is not a widget, or keeps its `State` private. It is the member of its `tomGroup` for that slot while mounted; `TomAuthGate.resolve` answers the same question without building anything |
| `TomGroupMemberElement` | Element mixin that keeps a widget registered with its `tomGroup` exactly while the element is active: joined on mount, moved to the new widget on update, left on deactivate |
| `TomStatelessGroupMemberElement` | The `StatelessElement` a stateless Tom widget returns from `createElement` |
| `TomStatefulGroupMemberElement` | The `StatefulElement` a stateful Tom widget returns from `createElement` |
| `TomParentDataGroupMemberElement` | The `ParentDataElement` a parent-data Tom widget (`TomExpanded`, `TomFlexible`) returns from `createElement` |

## Quick start

```dart
import 'package:flutter/widgets.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

class MyField extends StatelessWidget with TomWidgetMixin {
  @override final String? tomId;
  @override final TomAuthorizationGroup? tomGroup;
  const MyField(this.tomId, {super.key, this.tomGroup});

  // Membership follows the element: a member while mounted, not before.
  @override
  StatelessElement createElement() => TomStatelessGroupMemberElement(this);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

final shipping = TomAuthorizationGroup('shipping'); // mode: controlsWidest

// Mounted somewhere in the tree, the field is a member of `shipping` and its
// effectiveAuthState is narrowed by the group's ceiling.
Widget street() => MyField('street', tomGroup: shipping);
```

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

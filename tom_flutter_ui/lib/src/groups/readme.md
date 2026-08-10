# groups

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Collective visibility and authorization control. A `TomAuthorizationGroup` lets
many widgets share one authorization ceiling without tagging every leaf with an
id: each member registers with the group, and its `effectiveAuthState` is
narrowed by the group's mode. The group type is the kernel's, so the same
grouping concept spans widgets, forms, and actions.

This module owns only the widget-side wiring. The group itself
(`TomAuthorizationGroup`, `AuthGroupMode`) is defined in `tom_core_kernel` and
re-exported by `resource_auth/tom_auth_state.dart`, so importing
`tom_flutter_ui` is enough to name both.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomAuthorizationGroup` | A named visibility/auth group — defined in `tom_core_kernel`, re-exported here |
| `AuthGroupMode` | How the group combines member states (`controlsWidest` default / `controlsAll`) |
| `TomWidgetMixin` | Mixed into a widget to give it a `tomId` + `tomGroup` and `registerWithGroup()` |

## Quick start

```dart
import 'package:flutter/widgets.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

class MyField extends StatelessWidget with TomWidgetMixin {
  @override final String? tomId;
  @override final TomAuthorizationGroup? tomGroup;
  const MyField(this.tomId, {super.key, this.tomGroup});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void groupFields() {
  final shipping = TomAuthorizationGroup('shipping'); // mode: controlsWidest (default)
  final field = MyField('street', tomGroup: shipping);
  field.registerWithGroup();
  print(field.effectiveAuthState); // narrowed by the group ceiling
}
```

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

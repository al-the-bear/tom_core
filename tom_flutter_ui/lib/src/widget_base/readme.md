# widget_base

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

The foundation every other module rests on: the base widget classes that carry a
`tomId` and the authorization contract, the Material/Cupertino family selection,
the screen-elements provider, and the construction-time resolvers (`TomCtr`,
`TomStyleResolvers`) that turn resource entries into concrete Flutter values.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomNodeBase` / `TomPolicyNodeBase` | Base widget classes carrying `tomId` + authorization |
| `TomWidgetFamily` | Material / Cupertino family selection |
| `TomStatelessWidget` / `TomStatefulWidget` / `TomState` | Construction-time base helpers |
| `TomScreenElementsProviderBase` | The element-provider contract forms/ACL build against |
| `TomCtr` | Resolver helpers — `text` / `color` / `doubleVal` / `textStyle` by resource path |
| `TomStyleResolvers` | Parse style maps into `ButtonStyle` / `ShapeBorder` etc. |

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void resolveFromResources() {
  TomUIColors.adapter = AllColorsAdapter();
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from({'login': {'title': 'Sign in', 'gap': 12}}),
  );

  final title = TomCtr.text('login', 'title');    // 'Sign in'
  final gap = TomCtr.doubleVal('login', 'gap');   // 12.0
  print('$title / $gap');

  final style = TomStyleResolvers.parseButtonStyle({
    'backgroundColor': '#FF5722',
    'elevation': 4,
  });
  print(style); // a ButtonStyle built from the map
}
```

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

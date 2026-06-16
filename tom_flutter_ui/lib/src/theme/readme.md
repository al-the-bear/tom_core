# theme

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

The Tom theme and its inherited scope. `TomTheme` carries the cross-cutting
appearance concerns the widget and form layers honour — notably the read-only
field styling — and `TomThemeScope` delivers it to a subtree. Semantic button
styles are derived from the ambient `ColorScheme` via `TomButtonVariants`.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomTheme` | The Tom theme value; `TomTheme.defaultTheme` + `copyWith` |
| `TomThemeScope` | Inherited widget delivering a `TomTheme` to its `child` |
| `TomReadonlyStyle` | The read-only field styling (opacity, pointer absorption, overlay) |
| `TomButtonVariants` | Semantic button `ButtonStyle` set from a `ColorScheme` |

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget themedApp(Widget home) {
  // Derive a dimmer read-only treatment from the default theme.
  const base = TomTheme.defaultTheme;
  final dimmed = base.copyWith(
    name: 'dimmed',
    readonlyStyle: const TomReadonlyStyle(opacity: 0.5),
  );

  // Deliver it to the subtree.
  return TomThemeScope(theme: dimmed, child: home);
}
```

`TomButtonVariants.fromColorScheme(scheme).primary` yields a ready
`ButtonStyle` for the primary action; `TomButtonVariants.of(context)` reads the
ambient set.

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

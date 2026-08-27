# theme

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The Tom theme and its inherited scope. `TomTheme` carries the one appearance
concern Flutter has no equivalent for — how Tom's two *withheld* authorization
states look — and `TomThemeScope` delivers it to a subtree. Semantic button
styles are derived from the ambient `ColorScheme` via `TomButtonVariants`.

Two of the four `TomAuthState`s render the widget but hold it back: `read`
(visible, not editable) and `disabled` (visible, not available). Both are Tom
authorization concepts — `disabled` here is *not* Material's
`enabled: false` — and both are dimmed and made non-interactive, so one class
describes them and the theme carries one instance per state.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomTheme` | The Tom theme value; `TomTheme.defaultTheme` + `copyWith`, one `TomStateStyle` per withheld state. `TomTheme.applyAuthState(state, content)` is the single mapping from authorization state to appearance, which both enforcement points come through |
| `TomThemeScope` | Inherited widget delivering a `TomTheme` to its `child`. `TomThemeScope.readonlyStyleOf(context)` / `disabledStyleOf(context)` are the lookups the widget layer actually calls — they fall back to the framework defaults, so a subtree with no scope above it still styles correctly; `TomThemeScope.applyAuthState(context, state, content)` combines the lookup and the mapping |
| `TomStateStyle` | The treatment of one withheld state (opacity within `0.0`..`1.0`, pointer absorption, overlay, optional builder). `TomStateStyle.readonly` and `TomStateStyle.disabled` are the framework defaults — `AbsorbPointer` plus 0.6 and 0.38 opacity respectively |
| `TomButtonVariants` | Semantic button `ButtonStyle` set from a `ColorScheme` |

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget themedApp(Widget home) {
  // Derive dimmer treatments from the default theme. The two states are
  // independent settings: how much a widget is dimmed is what tells a user
  // *why* it is inert.
  const base = TomTheme.defaultTheme;
  final dimmed = base.copyWith(
    name: 'dimmed',
    readonlyStyle: const TomStateStyle(opacity: 0.5),
    disabledStyle: const TomStateStyle(opacity: 0.2),
  );

  // Deliver it to the subtree.
  return TomThemeScope(theme: dimmed, child: home);
}
```

Building the theme in place like this is the intended usage even inside a
`build` method: `TomTheme` and `TomStateStyle` compare by value, so the
scope notifies its dependents only when a field actually changes, not merely
because `copyWith` allocated. The one field compared by reference is
`TomStateStyle.builder` — closures cannot be compared any other way — so
hoist a custom builder into a named function rather than writing it inline.

`TomButtonVariants.fromColorScheme(scheme).primary` yields a ready
`ButtonStyle` for the primary action; `TomButtonVariants.of(context)` reads the
ambient set.

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

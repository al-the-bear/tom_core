# Theme Module

`theme/` is the theming layer of `tom_flutter_ui`. Its guiding principle is
**Tom does not replace Flutter's theming.** Colours, typography, shapes,
elevation, dark/light mode, and per-widget theme data all stay with Flutter's
`Theme` / `ThemeData`. This module adds only the two things Flutter has no
concept of:

1. **Readonly visual treatment** — how an *authorization-readonly* widget looks
   (a Tom authorization concept, not a Material one).
2. **Semantic button variants** — primary / secondary / auxiliary / destructive
   styles derived from the ambient `ColorScheme`.

## Table of Contents

- [Overview](#overview)
- [`TomReadonlyStyle` — readonly treatment](#tomreadonlystyle--readonly-treatment)
- [`TomTheme` & `TomThemeScope` — delivery](#tomtheme--tomthemescope--delivery)
- [`TomButtonVariants` — semantic button styles](#tombuttonvariants--semantic-button-styles)
- [How it connects to `widget_base`](#how-it-connects-to-widget_base)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomReadonlyStyle` | value class | Describes the readonly treatment (opacity, pointer absorption, optional colour overlay, optional custom builder) and `apply`s it to a widget. |
| `TomTheme` | value class | The Tom-specific theme — currently just a `name` and a `readonlyStyle`. Immutable, with `copyWith`. |
| `TomThemeScope` | `InheritedWidget` | Delivers a `TomTheme` to a subtree; `of` / `readonlyStyleOf` accessors fall back to defaults when no scope is present. |
| `TomButtonVariants` | factory class | Produces standard `ButtonStyle` objects (`primary`, `secondary`, `auxiliary`, `destructive`) from a `ColorScheme`. |

## `TomReadonlyStyle` — readonly treatment

When `TomPolicyNodeBase` resolves a widget to `TomAuthState.read`, it calls
`buildReadonly`, which resolves a `TomReadonlyStyle` from the nearest
`TomThemeScope` and applies it. The style composes its effects in a fixed order:

| Field | Default | Effect (`apply`) |
| ----- | ------- | ---------------- |
| `colorOverlay` | `null` | `ColorFiltered` (`BlendMode.srcATop`) when set |
| `opacity` | `0.6` | `Opacity` when `< 1.0` |
| `absorbPointers` | `true` | `AbsorbPointer` |
| `builder` | `null` | **Replaces** all of the above when set |

`TomReadonlyStyle.defaultStyle` is the framework default (`AbsorbPointer` +
0.6 opacity). Setting `opacity: 1.0` disables dimming; setting
`absorbPointers: false` is for families that handle readonly at the widget
level (e.g. a text field that switches to a non-editable display).

**If you set `builder`, hoist the function — do not write it inline in
`build`.** Styles compare by value, but a function can only be compared by
reference, so a closure allocated during `build` makes every style unequal to
the last one and defeats the rebuild check described below. A top-level or
static function, or one kept in a `State` field, compares equal to itself:

```dart
Widget readOnlyBanner(Widget child) =>
    Banner(message: 'read-only', location: BannerLocation.topEnd, child: child);

const style = TomReadonlyStyle(builder: readOnlyBanner);
```

## `TomTheme` & `TomThemeScope` — delivery

`TomTheme` is intentionally tiny — it carries only what Flutter doesn't. Place a
`TomThemeScope` at (or near) the root, alongside Flutter's `Theme`:

```dart
TomThemeScope(
  theme: TomTheme(
    readonlyStyle: TomReadonlyStyle(opacity: 0.5),
  ),
  child: MaterialApp(theme: themeData, home: MyApp()),
)
```

Widgets read it via `TomThemeScope.of(context)` or the convenience
`TomThemeScope.readonlyStyleOf(context)`. Both fall back to
`TomTheme.defaultTheme` / `TomReadonlyStyle.defaultStyle` when no scope is in
the tree, so widgets work without any theme wiring. `updateShouldNotify`
compares themes by value, so dependents rebuild only when the theme actually
changes.

That comparison is what makes the snippet above safe. It builds the theme
inside `build`, as does the other common form, `TomTheme.defaultTheme.copyWith(
readonlyStyle: ...)` — both allocate a fresh instance on every ancestor
rebuild. Compared by identity each of those would count as a change and rebuild
every readonly widget in the subtree; compared by value, only a theme whose
fields moved does. `TomTheme` and `TomReadonlyStyle` both implement `==` and
`hashCode` over all their fields, so there is nothing to opt into — with the
single exception noted under `builder` above.

## `TomButtonVariants` — semantic button styles

`TomButtonVariants` is a thin factory: it does not introduce a new theming
concept, it just derives standard `ButtonStyle`s from a `ColorScheme` so a
caller can pass them straight to a button's `style`:

| Variant | Built from | Intended use |
| ------- | ---------- | ------------ |
| `primary` | `ElevatedButton.styleFrom` (primary / onPrimary) | Main action |
| `secondary` | `OutlinedButton.styleFrom` (primary foreground) | Supporting action |
| `auxiliary` | `TextButton.styleFrom` (onSurfaceVariant) | Subtle utility action |
| `destructive` | `ElevatedButton.styleFrom` (error / onError) | Dangerous / irreversible action |

Resolve from a context (`TomButtonVariants.of(context)`) or directly from a
scheme (`TomButtonVariants.fromColorScheme(scheme)`):

```dart
TomElevatedButton(
  style: TomButtonVariants.of(context).primary,
  onPressed: save,
  child: Text('Save'),
)
```

## How it connects to `widget_base`

`theme/` is consumed by `widget_base/`'s `TomPolicyNodeBase.buildReadonly`,
which is the single call site that turns the abstract `read` authorization state
into a concrete dimmed/non-interactive widget. Every Tom widget inherits that
behaviour, so customising `TomReadonlyStyle` once at the `TomThemeScope` level
re-styles readonly rendering across the whole app.

## Dependencies

- `package:flutter/widgets.dart` — `TomReadonlyStyle`, `TomTheme`,
  `TomThemeScope` (`InheritedWidget`, `Opacity`, `AbsorbPointer`,
  `ColorFiltered`).
- `package:flutter/material.dart` — `TomButtonVariants` (`ButtonStyle`,
  `ColorScheme`, the `*Button.styleFrom` factories).

> Because the barrel pulls in `flutter/material` (→ `dart:ui`), code that
> imports `theme` runs under the Flutter toolchain. See
> [`example/theme/theme_example.dart`](../example/theme/theme_example.dart),
> exercised by `flutter test`.

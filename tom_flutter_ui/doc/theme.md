# Theme Module

`theme/` is the theming layer of `tom_flutter_ui`. Its guiding principle is
**Tom does not replace Flutter's theming.** Colours, typography, shapes,
elevation, dark/light mode, and per-widget theme data all stay with Flutter's
`Theme` / `ThemeData`. This module adds only the two things Flutter has no
concept of:

1. **Withheld-state visual treatment** — how Tom's two non-interactive
   *authorization* states look. Both are Tom concepts, not Material ones:
   `read` (visible, not editable) and `disabled` (visible, not available —
   distinct from Material's `enabled: false`).
2. **Semantic button variants** — primary / secondary / auxiliary / destructive
   styles derived from the ambient `ColorScheme`.

## Table of Contents

- [Overview](#overview)
- [`TomStateStyle` — withheld-state treatment](#tomstatestyle--withheld-state-treatment)
- [`TomTheme` & `TomThemeScope` — delivery](#tomtheme--tomthemescope--delivery)
- [`TomButtonVariants` — semantic button styles](#tombuttonvariants--semantic-button-styles)
- [How it connects to `widget_base`](#how-it-connects-to-widget_base)
- [Dependencies](#dependencies)

---

## Overview

Four types, and each has its own section below: `TomStateStyle` describes the
treatment of one withheld state, `TomTheme` carries one style per withheld
state, `TomThemeScope` delivers a theme to a subtree, and `TomButtonVariants`
derives semantic `ButtonStyle`s from a `ColorScheme`.

The symbol table for the module is
[`lib/src/theme/readme.md`](../lib/src/theme/readme.md), which names every
public type and every public static and is held to that by
`test/module_readme_inventory_test.dart`. At four types the module is below the
threshold at which a module earns a summary under `doc/api/` — see
[`doc/api/api_summary_index.md`](api/api_summary_index.md) — so the readme is
the mirror, and this page is the explanation rather than a second copy of it.

## `TomStateStyle` — withheld-state treatment

Two of the four `TomAuthState`s render the widget but hold it back: `read` and
`disabled`. Both get the same treatment — dim the content, stop it receiving
pointers — so one class describes both and the theme carries one instance per
state. The style composes its effects in a fixed order:

| Field | Default | Effect (`apply`) |
| ----- | ------- | ---------------- |
| `colorOverlay` | `null` | `ColorFiltered` (`BlendMode.srcATop`) when set |
| `opacity` | `0.6` (`readonly`) / `0.38` (`disabled`) | `Opacity` when `< 1.0`; must be within `0.0`..`1.0` |
| `absorbPointers` | `true` | `AbsorbPointer` |
| `builder` | `null` | **Replaces** all of the above when set |

`TomStateStyle.readonly` and `TomStateStyle.disabled` are the framework
defaults. They differ only in opacity, which is exactly why they are two values
rather than one constant: how much a widget is dimmed is what tells a user
*why* it is inert. `0.38` is Material's disabled opacity, borrowed so a
Tom-disabled widget sits beside a Material-disabled one without looking wrong —
a default, not a rule. An app that wants to distinguish "you may not" from "not
right now" changes it on the theme.

Setting `opacity: 1.0` disables dimming; setting `absorbPointers: false` is for
families that handle the state at the widget level (e.g. a text field that
switches to a non-editable display).

`opacity` is a fraction, not a percentage, and the constructor asserts the
`0.0`..`1.0` range. The check earns its place because the `< 1.0` test in the
table above is what a too-large value would fail: `opacity: 60` written for
"60 %" would take the same branch as the deliberate pass-through, dimming
nothing and reporting nothing. A negative value did fail, but only later and
elsewhere — inside Flutter's own `Opacity` at render time, naming a frame in
`basic.dart` instead of the style that caused it. `TomStateStyle`'s constructor
is `const`, so both mistakes are now caught at the literal, at compile time
wherever the style is written as a constant.

**If you set `builder`, hoist the function — do not write it inline in
`build`.** Styles compare by value, but a function can only be compared by
reference, so a closure allocated during `build` makes every style unequal to
the last one and defeats the rebuild check described below. A top-level or
static function, or one kept in a `State` field, compares equal to itself:

```dart
Widget readOnlyBanner(Widget child) =>
    Banner(message: 'read-only', location: BannerLocation.topEnd, child: child);

const style = TomStateStyle(builder: readOnlyBanner);
```

## `TomTheme` & `TomThemeScope` — delivery

`TomTheme` is intentionally tiny — it carries only what Flutter doesn't. Place a
`TomThemeScope` at (or near) the root, alongside Flutter's `Theme`:

```dart
TomThemeScope(
  theme: TomTheme(
    readonlyStyle: TomStateStyle(opacity: 0.5),
    disabledStyle: TomStateStyle(opacity: 0.2),
  ),
  child: MaterialApp(theme: themeData, home: MyApp()),
)
```

Widgets read it via `TomThemeScope.of(context)` or the convenience
`readonlyStyleOf(context)` / `disabledStyleOf(context)`. All fall back to
`TomTheme.defaultTheme` / `TomStateStyle.readonly` / `TomStateStyle.disabled`
when no scope is in the tree, so widgets work without any theme wiring.
`updateShouldNotify` compares themes by value, so dependents rebuild only when
the theme actually changes.

Scopes nest, and the nearest one wins. A subtree that needs a different
treatment — a dialog that dims its withheld fields harder than the page behind
it — wraps itself in a second `TomThemeScope`; widgets outside that subtree
keep reading the outer theme. Nesting replaces the whole `TomTheme` rather than
merging field by field, so an inner scope that means to change only one state
should build from the outer one: `TomThemeScope.of(context).copyWith(
disabledStyle: ...)`.

`TomTheme.applyAuthState(state, content)` is the single mapping from an
authorization state to its appearance — `none` to a zero-size box, `read` and
`disabled` to their respective styles, `full` to the content unchanged — and
`TomThemeScope.applyAuthState(context, state, content)` is the lookup and the
mapping in one call. `content` is a callback rather than a widget because
`none` must not build what it is about to discard: a hidden widget's content
can be expensive, and under a state that hides it, it may not be constructible
at all.

That value comparison is what makes the snippet above safe. It builds the theme
inside `build`, as does the other common form, `TomTheme.defaultTheme.copyWith(
readonlyStyle: ...)` — both allocate a fresh instance on every ancestor
rebuild. Compared by identity each of those would count as a change and rebuild
every withheld widget in the subtree; compared by value, only a theme whose
fields moved does. `TomTheme` and `TomStateStyle` both implement `==` and
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

No widget in this package consumes `TomButtonVariants` — the snippet above is
application code, not an internal wiring. That is a decision, not a gap: the
button family already takes a plain `ButtonStyle`, and this produces one, so a
`variant:` parameter would only add a second spelling of what `style:` says.
Read it as a convenience for callers, on the same footing as writing the
`ElevatedButton.styleFrom` call yourself.

The four variants are computed once per instance rather than per read. Each is
a pure function of the `ColorScheme` the instance was built from, and that
scheme never changes for a given instance — so the idiom above, which reads a
variant inside `build`, no longer allocates a fresh `ButtonStyle` per button
per frame for a value that could not have differed from the last one. Reading
the same variant twice returns the identical object. The instance itself is
still cheap and short-lived: `of(context)` builds a new one on each call, so
hold it in a local if a `build` needs several variants.

## How it connects to `widget_base`

`theme/` is consumed by Tom's two authorization enforcement points, which is
where an abstract `TomAuthState` becomes a concrete dimmed / non-interactive
widget:

- `widget_base/`'s `TomPolicyNodeBase`, through the default bodies of its
  `buildReadonly` and `buildDisabled` hooks. The hooks stay overridable — a
  family that swaps a text field for a non-editable display overrides the hook
  rather than restyling the theme — but their *defaults* resolve from the
  theme.
- `groups/`'s `TomWidgetMixin.applyAuthState`, for widgets that extend a
  Flutter widget directly and so cannot inherit from `TomPolicyNodeBase`.

Both route through `TomTheme.applyAuthState` or the same two style lookups, so
customising a `TomStateStyle` once at the `TomThemeScope` level re-styles that
state across the whole app, whichever half of the package a widget comes from.

The theme resolves a treatment from the authorization state and nothing else —
a widget's `TomWidgetFamily` does not enter into it, so every widget under a
scope gets that scope's two styles. A family that needs something different
overrides `buildReadonly` / `buildDisabled`, as above; there is no per-family
map on the theme to consult. That is deliberate rather than pending: the
lookups take a `BuildContext` and no family, and two of the enforcement points —
`TomWidgetMixin` and `TomPolicyNodeBase` itself — carry no family to pass, so a
family-keyed theme would apply in some places and silently not in others.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `flutter` | package | `tom_state_style.dart`, `tom_style_variants.dart`, `tom_theme.dart` | `widgets.dart` and `material.dart` — `InheritedWidget` and the `ButtonStyle` / `ColorScheme` the variants build |
| `tom_core_kernel` | package | `tom_theme.dart` | `TomAuthState`, the enum `TomTheme.applyAuthState` switches over |

> Because the barrel pulls in `flutter/material` (→ `dart:ui`), code that
> imports `theme` runs under the Flutter toolchain. See
> [`example/theme/theme_example.dart`](../example/theme/theme_example.dart),
> exercised by `flutter test`.

# Widget Base Module

`widget_base/` is the foundational layer of `tom_flutter_ui`. Every other
module — `widgets/`, `forms/`, `custom/`, `actions/` — builds on the base
classes, the widget-family taxonomy, the scope-propagation widgets, and the
resource-resolution helpers defined here.

A Tom widget differs from a plain Flutter widget in three ways, all introduced
in this module:

1. **Identity & scope** — it carries a `tomId` and resolves a canonical
   resource `basePath` from the active `TomScope`.
2. **Authorization** — it passes through a four-state authorization gate before
   it ever renders.
3. **Resource binding** — its colours, icons, text, and styles are resolved
   from the kernel's resource provider rather than hard-coded.

## Table of Contents

- [Overview](#overview)
- [The node hierarchy](#the-node-hierarchy)
- [Authorization enforcement](#authorization-enforcement)
- [The widget-family taxonomy](#the-widget-family-taxonomy)
- [Scope propagation](#scope-propagation)
- [Screen-element providers](#screen-element-providers)
- [Resource resolution: `TomCtr`](#resource-resolution-tomctr)
- [Style resolution: `TomStyleResolvers`](#style-resolution-tomstyleresolvers)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomAuthorizable` | re-export | The kernel contract a Tom widget implements for group registration and auth participation. Re-exported from `tom_core_kernel` so existing imports keep working. |
| `TomNodeBase` | abstract `StatelessWidget` | Root of every Tom element. Holds `tomId`, `tomGroup`, `scope`, `authorizer`, and the resolved `basePath`. |
| `TomPolicyNodeBase` | abstract | Adds the authorization gate: resolves the effective `TomAuthState` and routes to `buildContent` / `buildReadonly` / `buildDisabled` / hidden. |
| `TomFamilyBase` | abstract | Adds widget-family reporting (`family`, `families`, `isFamily`). |
| 20 family branch bases | abstract | One per family — `TomButtonBase`, `TomInputBase`, `TomSelectBase`, … — each fixes `family` to its `TomWidgetFamily` value. |
| `TomWidgetFamily` | enum | The 26-value family taxonomy (20 Flutter-derived + 6 Tom form families). |
| `TomStatelessWidget` / `TomStatefulWidget` / `TomState` | abstract | Scope-capturing base widgets for non-Tom wrappers that still need scope propagation. |
| `TomScreenElementsProvider` / `TomScreenElementsProviderBase` | interface / class | Declarative, reflection-discoverable screen widget trees with chained scopes. |
| `TomCtr` | static helpers | The single entry point for resource resolution — text, colour, icon, numeric, `EdgeInsets`, `TextStyle`, `InputBorder`, `WidgetStateProperty<Color>`, breakpointed values. |
| `TomStyleResolvers` | static helpers | Parsing of complex Material objects (`TextStyle`, `ButtonStyle`, `InputDecoration`, `ShapeBorder`, `Decoration`, …) from JSON resource maps. |

## The node hierarchy

```
StatelessWidget
   └── TomNodeBase                 identity + scope + basePath  (implements TomAuthorizable)
         └── TomPolicyNodeBase     authorization gate (build → buildContent/…)
               └── TomFamilyBase   family reporting
                     ├── TomButtonBase      family = button
                     ├── TomInputBase       family = input
                     ├── TomSelectBase      family = select
                     ├── … (20 branch bases, one per Flutter-derived/form family)
                     └── TomBuilderBase      family = builder
```

A concrete widget (in `widgets/`, `forms/`, …) extends the branch base for its
family and implements `buildContent(context)` — never `build`. Construction
resolves `basePath` as `<scopePath>.<tomId>` and, if a `tomGroup` was supplied,
registers the widget with that group.

## Authorization enforcement

`TomPolicyNodeBase.build` runs the widget inside its construction-time scope and
resolves the effective `TomAuthState` by combining, in order:

1. **Resource auth** — `TomAuthorization.resolveAuth(basePath)` (`full` when no
   `basePath`).
2. **Group auth** — `tomGroup.applyMode(state, constructionScope)` when the
   widget is a group member. The scope is passed rather than left to
   `TomScope.current` so the group resolves in the same frame `basePath` was
   built from. `build` re-enters that frame anyway, so this only shows up when
   the state is read from outside a build — which is exactly what
   `TomAuthorizationGroup.members` and the inspection getters defined on it do.
3. **Per-widget `authorizer`** — `authorizer.effectiveAuth(state)` when set.
4. **`uiStateController`** — a build-time narrowing callback (can only narrow,
   never widen).

Resource and group together establish what is *granted*; the authorizer and the
controller then narrow it. The controller runs last because `applyMode` widens
under `controlsNarrowest` and replaces outright under `controlsAll` — a group
applied afterwards would undo the narrowing the controller just performed.

The resolved state selects the render path:

| `TomAuthState` | Rendered as |
| -------------- | ----------- |
| `none` | `SizedBox.shrink()` — removed from layout |
| `disabled` | `buildDisabled` — the `disabledStyle` from the nearest `TomThemeScope` (default: `AbsorbPointer` + 0.38 opacity) |
| `read` | `buildReadonly` — the `readonlyStyle` from the nearest `TomThemeScope` (default: `AbsorbPointer` + 0.6 opacity) |
| `full` | `buildContent` — normal rendering |

Subclasses may override `buildReadonly` / `buildDisabled` for a richer treatment
but always provide `buildContent`. That is why this switch does not delegate to
`TomTheme.applyAuthState` the way `TomWidgetMixin.applyAuthState` does: the
hooks are override points, and only their *default* bodies resolve from the
theme. The two enforcement points share the styling one level down — the same
`TomStateStyle` pair — rather than sharing the dispatch.

## The widget-family taxonomy

`TomWidgetFamily` classifies a widget by behavioural role so cross-cutting tools
(layout engines, action wiring, ACL builders) can reason about widgets
generically. A widget reports a primary `family` and may report extra
`families` (e.g. a date picker is both `formField` and `dateTimePicker`).

- **Flutter-derived (20):** `button`, `input`, `select`, `toggle`, `slider`,
  `container`, `dialog`, `table`, `label`, `image`, `navigation`, `progress`,
  `chip`, `list`, `tree`, `sliver`, `animated`, `effect`, `interaction`,
  `builder`.
- **Tom form families (6):** `formField`, `dateTimePicker`, `listEditor`,
  `masterDetail`, `searchField`, `fileUpload`.

## Scope propagation

`TomScope` (from the kernel) is a zone-like ambient context that supplies the
resource path prefix. Tom widgets capture `TomScope.current` at construction and
re-enter it at build, so widgets built lazily (inside `builder` callbacks, after
async gaps) still resolve against the scope they were declared in.

For **non-Tom** wrappers — demo pages, screen containers, layout shells — that
hold Tom widgets but have no `tomId` of their own, extend:

- `TomStatelessWidget` (implement `buildContent`), or
- `TomStatefulWidget` + `TomState` (implement `buildContent` on the state).

`TomNodeBase` subclasses handle scope propagation themselves; the scope widgets
are only for the gaps between them.

## Screen-element providers

A screen-element provider declares all of a screen's widgets as typed fields and
exposes a `scope`. With `@tomReflect`, reflection discovers the field list — no
manual registration.

- `TomScreenElementsProvider` is the interface (just `TomScope get scope`).
- `TomScreenElementsProviderBase` *is* a `TomScope` (via `TomScopeMixin`), so
  passing `scope: this` to child widgets nests them under the provider's path.
  Nesting providers chains scopes automatically:

  ```
  demo23.order.submit
  demo23.order.details.name
  ```

  where `order` and `details` are nested provider scope segments under the
  `demo23` zone scope.

## Resource resolution: `TomCtr`

`TomCtr` is the single entry point for reading values out of the kernel's
`TomTextResourceProvider`. Every method takes a `basePath` and an optional
`suffix` appended with a dot (`text(path, 'label')` → key `path.label`).

| Group | Methods |
| ----- | ------- |
| Path | `resolvePath(tomId, [scope])`, `childTomId(tomId, suffix)` |
| Text | `text`, `textOrNull`, `textOrFail`, `exists` |
| Colour | `color`, `colorOrFail` (resolved via `TomUIColors`) |
| Icon | `icon` (resolved via `TomUIIcons`) |
| Numeric | `doubleVal`, `doubleOrFail`, `intVal`, `intOrFail` |
| Bool | `boolVal` |
| Insets | `edgeInsets` (number / array / map forms) |
| Generic | `value`, `list`, `map` |
| Composite | `textStyle`, `inputBorder`, `widgetStateColor`, `breakpointed<T>` |
| Default widgets | `defaultText`, `defaultTextOrEmpty` |

The `…OrFail` variants throw `StateError` when neither an explicit value nor a
resource is available — used where a value is structurally required. The plain
variants return `null` (or the key string, for `text`, as a development
indicator) when nothing resolves.

## Style resolution: `TomStyleResolvers`

`TomStyleResolvers` parses complex Material objects from JSON resource maps.
Each type has a pure `parse…(map)` form (testable without installed resources)
and a `resolve…(basePath, suffix)` form that first reads the map via
`TomCtr.map`.

What separates it from `TomCtr` is that input, not the imports: both classes
require the Material library (see [Dependencies](#dependencies)), so that could
never have told them apart. The boundary is the resource provider — `TomCtr` is
the one place that reads it, turning a key into a raw value, while
`TomStyleResolvers` turns an already-decoded map into a composite Flutter
object. The dependency runs one way, which is why every `resolve…` reads its map
via `TomCtr.map` and then delegates to the matching `parse…` — four of them
(`resolveBorderRadius`, `resolveAlignment`, `resolveVisualDensity`,
`resolveScrollPhysics`) unwrap a nested key or accept a scalar form first, but
none reaches the provider twice. A new helper belongs here when it assembles an
object from a decoded map, and in `TomCtr` when it reaches the provider for a
value.

[`test/widget_base/style_resolvers_layering_test.dart`](../test/widget_base/style_resolvers_layering_test.dart)
reads the source and holds it to both halves of that rule, so a resolver that
opens a second route to the provider — or a parser that starts reading resources
and can no longer be called with a plain map — fails rather than silently moving
the boundary.

| Resolver | Parses |
| -------- | ------ |
| `parseTextStyle` / `resolveTextStyle` | `TextStyle` (font, colour, decoration, overflow) |
| `parseButtonStyle` / `resolveButtonStyle` | `ButtonStyle` (colours wrapped in `WidgetStatePropertyAll`, sizes, padding) |
| `parseInputDecoration` / `resolveInputDecoration` | `InputDecoration` (texts, colours, nested styles) |
| `parseMenuStyle` / `resolveMenuStyle` | `MenuStyle` |
| `parseShapeBorder` / `resolveShapeBorder` | `ShapeBorder` (rounded / beveled / stadium / circle / continuous) |
| `parseBorderSide` / `resolveBorderSide` | `BorderSide` |
| `parseBorderRadius` / `resolveBorderRadius` | `BorderRadius` (number / per-corner / `all`) |
| `parseDecoration` / `resolveDecoration` | `BoxDecoration` (colour, border, radius, shadows, shape) |
| `parseBoxConstraints` / `resolveBoxConstraints` | `BoxConstraints` |
| `parseAlignment` / `resolveAlignment` | `AlignmentGeometry` (named or `{x, y}`) |
| `parseOffset` / `resolveOffset` | `Offset` (`{dx, dy}` / `{x, y}` / `[dx, dy]`) |
| `parseTableBorder` / `resolveTableBorder` | `TableBorder` (per-side or `all`) |
| `parseVisualDensity` / `resolveVisualDensity` | `VisualDensity` |
| `parseIconThemeData` / `resolveIconThemeData` | `IconThemeData` |
| `parseStrutStyle` / `resolveStrutStyle` | `StrutStyle` |
| `parseTextHeightBehavior` / `resolveTextHeightBehavior` | `TextHeightBehavior` |
| `parseScrollPhysics` / `resolveScrollPhysics` | `ScrollPhysics` (bouncing / clamping / never / always / page / fixedExtent) |

All parsers return `null` for a `null`/empty map and skip unrecognised values,
so a partially-specified resource map yields a partially-populated object rather
than an error.

## Dependencies

- `package:flutter/material.dart` — `TomCtr` and `TomStyleResolvers` require the
  Material library; the base classes use `package:flutter/widgets.dart`.
- `tom_core_kernel` — `TomScope`, `TomAuthorization`, `TomAuthState`,
  `TomAuthorizable`, `TomAuthorizationGroup`, `TomAuthorizer`,
  `TomTextResourceProvider`.
- Sibling modules: `resource_auth/` (`TomUIColors`, `TomUIIcons`), `theme/`
  (`TomThemeScope`, `TomStateStyle`), `widgets/` (`TomText` for the
  default-widget helpers).

> Because the barrel pulls in `flutter/material` (→ `dart:ui`), code that
> imports `widget_base` runs under the Flutter toolchain. See
> [`example/widget_base/widget_base_example.dart`](../example/widget_base/widget_base_example.dart),
> which is exercised by `flutter test`.

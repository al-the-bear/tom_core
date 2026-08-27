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
- [Path composition: `TomScopePath`](#path-composition-tomscopepath)
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
| `TomWidgetFamily` | enum | The 26-value family taxonomy: 20 Flutter-derived values, each fixed by a branch base, plus 6 Tom form values that are reserved and claimed by nothing. |
| `TomStatelessWidget` / `TomStatefulWidget` / `TomState` | abstract | Scope-capturing base widgets for non-Tom wrappers that still need scope propagation. |
| `TomScreenElementsProvider` / `TomScreenElementsProviderBase` | interface / class | Declarative, reflection-discoverable screen widget trees with chained scopes. |
| `TomScopePath` | static helpers | The one place a scope path and a widget id are joined into a canonical resource path. Flutter-free, so the base classes can use it in an initialiser list. |
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
                     ├── … (20 branch bases, one per Flutter-derived family;
                     │      the 6 Tom form families have no branch base)
                     └── TomBuilderBase      family = builder
```

A concrete widget (in `widgets/`, and a handful in `forms/`) extends the branch
base for its family and implements `buildContent(context)` — never `build`.
Most of `forms/` does not appear here at all: its fields descend from
`TomField<T>`, not from `TomFamilyBase` — see
[the taxonomy](#the-widget-family-taxonomy). Construction
resolves `basePath` through
[`TomScopePath.resolve`](#path-composition-tomscopepath) and, if a `tomGroup`
was supplied, registers the widget with that group. `basePath` is computed in
the constructor, so it is readable on a node that has never been built —
[`example/widget_base/widget_base_nodes_example.dart`](../example/widget_base/widget_base_nodes_example.dart)
composes a nested provider and prints the paths that come out.

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

`resolveEffectiveAuth()` is public and takes no `BuildContext`, so the whole
gate can be exercised on a constructed node without a widget tree — which is
how
[`example/widget_base/widget_base_nodes_example.dart`](../example/widget_base/widget_base_nodes_example.dart)
walks one layer at a time: a resource grant, a group ceiling that narrows it,
an authorizer that overrides it, and a controller that cannot widen it back.

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
generically. A widget reports a primary `family`, fixed by its branch base, and
`families` allows it to report more than one.

The enum has 26 values, but they divide unevenly, and the split is worth
knowing before you write a tool that switches on it:

- **Flutter-derived (20) — carried.** `button`, `input`, `select`, `toggle`,
  `slider`, `container`, `dialog`, `table`, `label`, `image`, `navigation`,
  `progress`, `chip`, `list`, `tree`, `sliver`, `animated`, `effect`,
  `interaction`, `builder`. Each has a branch base that fixes `family` to it,
  and each branch base has concrete subclasses in `widgets/`.
- **Tom form families (6) — reserved, and claimed by nothing.** `formField`,
  `dateTimePicker`, `listEditor`, `masterDetail`, `searchField`, `fileUpload`
  have no branch base, and no widget reports them. The forms module does not
  use this enum at all — it does not even import it. Its fields descend from
  `TomField<T> extends TomObject<T>`, a kernel observable rendered through
  `TomFieldWidgetAdapter`, so a form field carries *no* family rather than one
  of these six. (`TomTextFormFieldBase` is on the `TomField` side too, despite
  the `-Base` suffix; the handful of genuine widgets in `forms/`, such as
  `TomReorderHandle`, extend ordinary Flutter-derived bases like
  `TomImageBase`.)

Two consequences follow, and both bite in practice:

- **`isFamily(TomWidgetFamily.formField)` is false for every widget in the
  package.** A tool that dispatches on the form values matches nothing; it will
  not fail, it will silently do no work.
- **`families` is never overridden.** The default `{family}` is its only
  implementation, so today every Tom widget reports exactly one family. The
  multi-family capability is real but has no users — do not infer from its
  presence that some widget somewhere reports two.

The six are kept, rather than deleted, because
[the ACL/layout design](container_widget_resources_authorization.md) §12.2
specifies them as the intended classification for form fields once those become
family-reporting widgets. They record an intent; they do not describe the code.
`test/widget_base/tom_widget_family_coverage_test.dart` pins the 20/6 split so
this section cannot drift back out of step with the enum, and
[`example/widget_base/widget_base_nodes_example.dart`](../example/widget_base/widget_base_nodes_example.dart)
shows both consequences on two concrete widgets — `families.single`, and
`isFamily(TomWidgetFamily.formField)` coming back false.

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

## Path composition: `TomScopePath`

A canonical resource path is `<scopePath>.<tomId>`, with the separator dropped
when the scope path is empty — a widget at the root addresses its resources by
its bare id, not by `.id`. `TomScopePath` is the one place that rule is written
down. Everything that addresses the resource tree goes through it: resource
lookups, `TomAuthorization` policy lookups and group registration all name the
same paths, so a widget that composed its path even slightly differently from
its neighbours would read a bundle belonging to something else while rendering
perfectly.

| Method | Parent | Id | Returns |
| ------ | ------ | -- | ------- |
| `join(parentPath, tomId)` | `String` | `String` | `String` |
| `qualify(tomId, [scope])` | `TomScope?` | `String` | `String` |
| `resolve(tomId, [scope])` | `TomScope?` | `String?` | `String?` |

`join` is the rule; `qualify` and `resolve` resolve a scope down to its path
and hand it over, so a change to the composition lands in exactly one place.
`resolve` is the widget-facing form — a node without a `tomId` has no path at
all, and `null` is what makes the `TomCtr` accessors return their defaults
rather than look up the empty string.

The class holds **no Flutter dependency**, and that is what places it here
rather than on `TomCtr`. `TomNodeBase` needs the path in its initialiser list,
and `TomCtr` reaches into `widgets/` for its default-widget helpers — a base
class that called `TomCtr` would depend on the layer built on top of it.
`TomCtr.resolvePath` remains as a one-line forwarder, because that is where the
widget layer already looks for path helpers and a delegation cannot drift from
what it delegates to.

Two callers legitimately need the raw scope path instead: `TomForm` derives a
field's base path from either its form's `basePath` or the ambient scope path —
a `String` either way, so it uses `join` — and `AclContainer` builds
*multi-segment* policy paths whose middle segments are opt-in (`idScope`),
which is a different rule rather than this one with extra steps. Both are named
in the allowlist that `test/widget_base/scope_path_test.dart` holds the module
to; every other file in `lib/` is forbidden from reading `getScopePath()` or
interpolating a scope path into an id.

## Resource resolution: `TomCtr`

`TomCtr` is the single entry point for reading values out of the kernel's
`TomTextResourceProvider`. Every method takes a `basePath` and an optional
`suffix` appended with a dot (`text(path, 'label')` → key `path.label`).

| Group | Methods |
| ----- | ------- |
| Path | `resolvePath(tomId, [scope])` (forwards to [`TomScopePath.resolve`](#path-composition-tomscopepath)), `childTomId(tomId, suffix)` |
| Text | `text`, `textOrNull`, `textOrFail`, `exists` |
| Colour | `color`, `colorOrFail` (resolved via `TomUIColors`) |
| Icon | `icon` (resolved via `TomUIIcons`) |
| Numeric | `doubleVal`, `doubleOrFail`, `intVal`, `intOrFail` |
| Bool | `boolVal` |
| Insets | `edgeInsets` (number / array / map forms, via `TomStyleResolvers.parseEdgeInsets`) |
| Generic | `value`, `list`, `map` |
| Composite | `textStyle`, `inputBorder`, `widgetStateColor`, `breakpointed<T>` |
| Default widgets | `defaultText`, `defaultTextOrEmpty` |

The plain variants return `null` (or the key string, for `text`, as a
development indicator) when nothing resolves.

The four `…OrFail` variants are for values a widget genuinely cannot render
without, and they can fail for two independent reasons: there is no `tomId`, so
there is no key to look up at all; or there is a key and nothing is installed at
it. **They agree on the first and disagree on the second.**

| Variant | No `tomId` | Key present, resource absent | Resource present but unusable |
| ------- | ---------- | ---------------------------- | ----------------------------- |
| `textOrFail` | throws `StateError` | **returns the key**, e.g. `'w.label'` | — (any resource reads as text) |
| `colorOrFail` | throws `StateError` | throws `StateError` | throws `StateError` |
| `doubleOrFail` | throws `StateError` | throws `StateError` | throws `StateError` |
| `intOrFail` | throws `StateError` | throws `StateError` | throws `StateError` |

`textOrFail` is the member whose behaviour its name does not announce, and the
difference is deliberate rather than an oversight. A missing label painted as
`checkout.submit.label` makes a missing translation obvious on screen during
development, where an exception would only say that *something* was absent;
`getText` on the group mixin answers the same way for the same reason (see
[Groups](groups.md)). So the useful reading of the name is "fails when there is
nothing to look up", not "fails when the lookup finds nothing" — and a caller
who needs a required label to fail loudly must check `exists` first, because
`textOrFail` will not do it.

A third exit is unique to `textOrFail`: passing `supersededBy` a non-null widget
returns `''` without consulting anything, including in the null-`tomId` case.
The text is not going to be rendered, so there is nothing to require.

`test/widget_base/tom_ctr_helpers_test.dart` asserts all four variants against
both conditions in one place, so the asymmetry is a stated contract rather than
an accident of four separate methods.

`widgetStateColor` reads a default colour at its own key and per-state
overrides beneath `<key>.states.<name>`, for the eight names `hovered`,
`focused`, `pressed`, `selected`, `disabled`, `error`, `dragged` and
`scrolledUnder`. A control is regularly in more than one of those states at
once — a pointer resting on a disabled button is both `hovered` and `disabled`
— so the resolver ranks them and returns the highest:

```text
disabled > error > dragged > pressed > selected > focused > hovered > scrolledUnder
```

Conditions outrank interactions: being unavailable or invalid is a fact about
the control that a passing pointer must not paint over. Within the interactions
the more committed act wins — a drag is a press that went somewhere, a press is
a stronger statement of intent than focus, and focus persists where hover is
merely wherever the pointer happens to be. Two ranks differ from Material,
deliberately: Flutter's own resolvers put `hovered` above `focused` and give
`error` no rank at all.

The ranking applies only to the states a bundle actually defines. A bundle that
colours hover alone paints the hover colour on a control that is hovered *and*
disabled — the higher rank is absent, not silently defaulted. When no ranked
state matches, the default colour applies; with neither a default nor any state
override the method returns `null`, and a bundle that defines state colours but
no default falls back to opaque black for the unmatched case.

## Style resolution: `TomStyleResolvers`

`TomStyleResolvers` parses complex Material objects from JSON resources. Each
type has a pure `parse…(value)` form (testable without installed resources) and
a `resolve…(basePath, suffix)` form that reads the resource first.

What separates it from `TomCtr` is that input, not the imports: both classes
require the Material library (see [Dependencies](#dependencies)), so that could
never have told them apart. The boundary is the resource provider — `TomCtr` is
the one place that reads it, turning a key into a raw value, while
`TomStyleResolvers` turns an already-decoded value into a composite Flutter
object. It is the *provider* dependency that runs one way, not the reference
between the two classes: every `resolve…` makes exactly one `TomCtr` call and
hands the result to the matching `parse…`, while no `parse…` mentions `TomCtr`
at all. A new helper belongs here when it assembles a Flutter object out of a
decoded value, and in `TomCtr` when it reaches the provider for one — and in
exactly one of the two.

Two parsers have their resolver on the other side of that boundary.
`parseEdgeInsets` and `parseFontWeight` are reached through `TomCtr.edgeInsets`
and `TomCtr.textStyle`, which are long-established entry points with call sites
throughout the widget layer; their resource route stays where callers already
find it rather than moving here as an eighteenth `resolve…`. What is not
allowed is the arrangement they replaced — `TomCtr` holding a private copy of
each parser, kept in step by hand. That is why both are public here: something
outside the class resolves them.

Which accessor a resolver reads through follows from its parser's own
signature, and is not a free choice. Twelve parsers take a
`Map<String, dynamic>?`, so their resolvers read `TomCtr.map`. The seven that
take a bare `dynamic` — `parseBorderRadius`, `parseAlignment`, `parseOffset`,
`parseVisualDensity`, `parseScrollPhysics` and the two resolved by `TomCtr`,
the rows below that advertise a scalar or list form — read the raw value
instead, because `TomCtr.map` yields `null` for anything that is not a map and
those forms would otherwise be documented here and unreachable from a resource.
Four of the five with a resolver in this class additionally unwrap a map
carrying the value under the property's own name (`radius`, `alignment`,
`visualDensity`, `physics`), so a resource can group it with siblings;
`resolveOffset` has no such key, `{dx, dy}` being a value form rather than a
wrapper.

[`test/widget_base/style_resolvers_layering_test.dart`](../test/widget_base/style_resolvers_layering_test.dart)
reads the source and holds it to every part of that rule — including the
derived one, so a parser widened to `dynamic` later drags its resolver along —
and so a resolver that opens a second route to the provider, or a parser that
starts reading resources and can no longer be called with a plain map, fails
rather than silently moving the boundary. It also fails if any member name is
declared in both classes, which is what keeps the private-copy arrangement from
coming back.
[`test/widget_base/style_resolvers_resource_route_test.dart`](../test/widget_base/style_resolvers_resource_route_test.dart)
exercises the same five through a real resource tree, asserting that each
scalar or list form yields exactly what the direct `parse…` call does, and
[`test/widget_base/shared_parsers_test.dart`](../test/widget_base/shared_parsers_test.dart)
does the same for the two `TomCtr` resolves.

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
| `parseVisualDensity` / `resolveVisualDensity` | `VisualDensity` (named or `{horizontal, vertical}`) |
| `parseIconThemeData` / `resolveIconThemeData` | `IconThemeData` |
| `parseStrutStyle` / `resolveStrutStyle` | `StrutStyle` |
| `parseTextHeightBehavior` / `resolveTextHeightBehavior` | `TextHeightBehavior` |
| `parseScrollPhysics` / `resolveScrollPhysics` | `ScrollPhysics` (bouncing / clamping / never / always / page / fixedExtent) |
| `parseEdgeInsets` / `TomCtr.edgeInsets` | `EdgeInsets` (number / `[…]` / `{all}` / `{horizontal, vertical}` / per-side) |
| `parseFontWeight` / `TomCtr.textStyle` | `FontWeight` (`normal` / `bold` / `w100`…`w900` in any case, or `100`…`900`) |

All parsers skip an entry they cannot use rather than raising, so a
partially-specified resource map yields a partially-populated object rather than
an error. They return `null` in the other case — when the input contributed
*nothing*, whether it was `null`, empty, or held only keys and values no parser
reads. Those are the only two outcomes; none of them has a failure mode.

Skipping is per entry, and for the list forms that means per *element*: what a
parser rejects is the individual value, never the container it arrived in.
`parseEdgeInsets(['x', 2])` still names a vertical inset of 2 and yields one,
and does so identically at every list length it reads. The shape itself is not
negotiable in the same way — a list of a length no form names, such as
`[1, 2, 3]`, is rejected outright, because there is no way to tell which three
sides were meant.

The distinction matters at the call site, where `parseX(map) ?? fallback` is the
shape the API invites. It only reaches the fallback if a map that contributed
nothing comes back `null`. A default-constructed object would render plausibly
instead — `TextStyle()` inherits from the ambient theme — so a typo'd bundle
would look styled, the fallback would never run, and nothing would report the
mistake. `TomCtr.textStyle` answers the same question the same way for the
resource-tree half of the module.

An unrecognised value for `type` in `parseShapeBorder` or `shape` in
`parseDecoration` counts as contributing nothing, on the same grounds: reading
a misspelled name as the default shape would turn a typo into a real shape.

[`test/widget_base/widget_base_resolvers_test.dart`](../test/widget_base/widget_base_resolvers_test.dart)
asserts the `null` return for 18 of the 19 parsers, and holds its own list of
them to the class's member count so a parser added later cannot be exempt in
silence. `parseEdgeInsets` is the one exception, and is named as such in the
test rather than left off the list: a value of a shape it reads but out of which
nothing parsed — `{'all': 'x'}`, `{'nonsense': 1}`, `['x']` — yields
`EdgeInsets.zero`, a real object built out of nothing. That is tracked as its
own fix; the test pins the current behaviour so the note cannot outlive it.

## Dependencies

- `package:flutter/material.dart` — `TomCtr` and `TomStyleResolvers` require the
  Material library; the base classes use `package:flutter/widgets.dart`, and
  `TomScopePath` uses no Flutter library at all.
- `tom_core_kernel` — `TomScope`, `TomAuthorization`, `TomAuthState`,
  `TomAuthorizable`, `TomAuthorizationGroup`, `TomAuthorizer`,
  `TomTextResourceProvider`.
- Sibling modules: `resource_auth/` (`TomUIColors`, `TomUIIcons`), `theme/`
  (`TomThemeScope`, `TomStateStyle`), `widgets/` (`TomText` for the
  default-widget helpers).

> Because the barrel pulls in `flutter/material` (→ `dart:ui`), code that
> imports `widget_base` runs under the Flutter toolchain. Two executable
> examples split the module along the same line this page does — resource
> binding on one side, nodes on the other — and both are exercised by
> `flutter test`:
>
> - [`example/widget_base/widget_base_example.dart`](../example/widget_base/widget_base_example.dart)
>   — resource binding: `TomCtr` lookups and `TomStyleResolvers` parsing.
> - [`example/widget_base/widget_base_nodes_example.dart`](../example/widget_base/widget_base_nodes_example.dart)
>   — identity and scope composition, the four-layer authorization gate, and
>   the family a widget reports. None of the three needs a widget tree:
>   `basePath` is computed in the constructor, `resolveEffectiveAuth()` takes
>   no `BuildContext`, and `family` is a plain getter, so the example asserts
>   on constructed nodes rather than pumping them.

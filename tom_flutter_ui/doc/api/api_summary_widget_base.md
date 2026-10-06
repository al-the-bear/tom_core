# Tom Flutter UI API Reference: Widget Base Module

The foundation every Tom widget stands on: the node chain that carries identity
and authorization, the family taxonomy, and the two static resolvers that turn
resource entries into Flutter values.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [The surface contract](#the-surface-contract)
  - [TomWidgetSurface](#tomwidgetsurface)
- [The node chain](#the-node-chain)
  - [TomNodeBase](#tomnodebase)
  - [TomPolicyNodeBase](#tompolicynodebase)
  - [TomFamilyBase](#tomfamilybase)
  - [TomButtonBase](#tombuttonbase)
  - [TomInputBase](#tominputbase)
  - [TomSelectBase](#tomselectbase)
  - [TomToggleBase](#tomtogglebase)
  - [TomSliderBase](#tomsliderbase)
  - [TomContainerBase](#tomcontainerbase)
  - [TomDialogBase](#tomdialogbase)
  - [TomTableBase](#tomtablebase)
  - [TomLabelBase](#tomlabelbase)
  - [TomImageBase](#tomimagebase)
  - [TomNavigationBase](#tomnavigationbase)
  - [TomProgressBase](#tomprogressbase)
  - [TomChipBase](#tomchipbase)
  - [TomListBase](#tomlistbase)
  - [TomTreeBase](#tomtreebase)
  - [TomSliverBase](#tomsliverbase)
  - [TomAnimatedBase](#tomanimatedbase)
  - [TomEffectBase](#tomeffectbase)
  - [TomInteractionBase](#tominteractionbase)
  - [TomBuilderBase](#tombuilderbase)
  - [TomWidgetFamily](#tomwidgetfamily)
- [Scope-capturing bases](#scope-capturing-bases)
  - [TomStatelessWidget](#tomstatelesswidget)
  - [TomStatefulWidget](#tomstatefulwidget)
  - [TomState](#tomstate)
- [Screen elements](#screen-elements)
  - [TomScreenElementsProvider](#tomscreenelementsprovider)
  - [TomScreenElementsProviderBase](#tomscreenelementsproviderbase)
- [Authorization](#authorization)
  - [TomAuthLayers](#tomauthlayers)
- [Path composition](#path-composition)
  - [TomScopePath](#tomscopepath)
- [Resource resolution](#resource-resolution)
  - [TomCtr](#tomctr)
- [Style resolution](#style-resolution)
  - [TomStyleResolvers](#tomstyleresolvers)

## Overview

Source: `lib/src/widget_base/`, barrelled by `widget_base.dart`.

A Tom widget is a Flutter widget plus exactly four things: an identity
(`tomId`), an optional group membership, a resource path derived from the
active scope, and an authorization state that can hide, disable or read-only
the widget before it ever builds. This module supplies all four, so neither the
widget kit nor the form system re-implements identity, resource lookup or the
authorization gate.

Thirty-four exported types and sixty-two public statics. The bulk of both is
two static classes — `TomCtr` (23 statics) and `TomStyleResolvers` (36) — plus
the twenty family branch bases, which exist to fix one getter each.

`TomAuthorizable` is named throughout and is **not** declared here: it is the
kernel's, reaching this package through `lib/src/kernel_types.dart`.
`TomWidgetSurface` implements it and adds the fourth member.

Headings carry the bare type name; generic parameters appear in the body.

## Class Hierarchy

```
TomAuthorizable (tom_core_kernel)
└── TomWidgetSurface
    └── TomNodeBase (StatelessWidget)
        └── TomPolicyNodeBase
            └── TomFamilyBase
                └── 20 branch bases (TomButtonBase, TomInputBase, …)

StatelessWidget → TomStatelessWidget
StatefulWidget  → TomStatefulWidget → TomState<T>

TomScreenElementsProvider → TomScreenElementsProviderBase

TomWidgetFamily   — 26 values
TomAuthLayers     — one static
TomScopePath      — three statics
TomCtr            — 23 statics
TomStyleResolvers — 36 statics
```

## The surface contract

### TomWidgetSurface

`abstract interface class TomWidgetSurface implements TomAuthorizable`. The
kernel's `TomAuthorizable` carries three of the four members a Tom widget adds —
`tomId`, `tomGroup`, `effectiveAuthState`; this adds the fourth, `String? get
basePath`, the resolved resource path. Naming one contract for both routes to a
Tom widget — the node chain and `TomWidgetMixin` in `groups/` — is what lets the
conformance suite treat them uniformly.

## The node chain

Every Tom widget in `widgets/` extends one of the twenty branch bases, so it
passes through all three classes below. That is why authorization cannot be
forgotten: it is not a mixin a wrapper opts into, it is a link in the chain.

### TomNodeBase

`abstract class TomNodeBase extends StatelessWidget implements TomWidgetSurface`.
Holds `tomId`, `tomGroup`, `scope`, `authorizer`, `uiStateController`, the
`constructionScope` captured at construction, and the resolved `basePath`. The
constructor captures `TomScope.current` if no `scope` is given, which is what
makes a widget built inside a scope resolve against it even when it is rendered
elsewhere.

### TomPolicyNodeBase

`abstract class TomPolicyNodeBase extends TomNodeBase`. Adds the gate: `build`
resolves `effectiveAuthState` through `resolveEffectiveAuth()` and routes to one
of three hooks a subclass may override — `buildContent` (abstract, the normal
rendering), `buildReadonly` and `buildDisabled` (defaulting to the nearest
`TomThemeScope`'s `readonlyStyle` / `disabledStyle`). `TomAuthState.none`
renders `SizedBox.shrink()` and never calls a hook.

### TomFamilyBase

`abstract class TomFamilyBase extends TomPolicyNodeBase`. Adds the family
report: `TomWidgetFamily get family` (abstract), `Set<TomWidgetFamily> get
families` (defaulting to `{family}`, overridden where a widget belongs to
several) and `bool isFamily(TomWidgetFamily type)`.

### TomButtonBase

Fixes `family` to `TomWidgetFamily.button`.

### TomInputBase

Fixes `family` to `TomWidgetFamily.input`.

### TomSelectBase

Fixes `family` to `TomWidgetFamily.select`.

### TomToggleBase

Fixes `family` to `TomWidgetFamily.toggle`.

### TomSliderBase

Fixes `family` to `TomWidgetFamily.slider`.

### TomContainerBase

Fixes `family` to `TomWidgetFamily.container`.

### TomDialogBase

Fixes `family` to `TomWidgetFamily.dialog`.

### TomTableBase

Fixes `family` to `TomWidgetFamily.table`.

### TomLabelBase

Fixes `family` to `TomWidgetFamily.label`.

### TomImageBase

Fixes `family` to `TomWidgetFamily.image`.

### TomNavigationBase

Fixes `family` to `TomWidgetFamily.navigation`.

### TomProgressBase

Fixes `family` to `TomWidgetFamily.progress`.

### TomChipBase

Fixes `family` to `TomWidgetFamily.chip`.

### TomListBase

Fixes `family` to `TomWidgetFamily.list`.

### TomTreeBase

Fixes `family` to `TomWidgetFamily.tree`.

### TomSliverBase

Fixes `family` to `TomWidgetFamily.sliver`.

### TomAnimatedBase

Fixes `family` to `TomWidgetFamily.animated`.

### TomEffectBase

Fixes `family` to `TomWidgetFamily.effect`.

### TomInteractionBase

Fixes `family` to `TomWidgetFamily.interaction`.

### TomBuilderBase

Fixes `family` to `TomWidgetFamily.builder`.

### TomWidgetFamily

The 26-value taxonomy of what a widget is *for*, not what it looks like. Twenty
values are fixed by a branch base above — `button`, `input`, `select`,
`toggle`, `slider`, `container`, `dialog`, `table`, `label`, `image`,
`navigation`, `progress`, `chip`, `list`, `tree`, `sliver`, `animated`,
`effect`, `interaction`, `builder` — and six belong to the form system, which
reports them without a branch base: `formField`, `dateTimePicker`,
`listEditor`, `masterDetail`, `searchField`, `fileUpload`.

## Scope-capturing bases

For a widget that is **not** a Tom wrapper but still has to resolve resources
against the scope it was built in. They capture `TomScope.current` in the
constructor and restore it around `buildContent`, which is the whole of what
they do — there is no `tomId` and no authorization.

### TomStatelessWidget

`abstract class TomStatelessWidget extends StatelessWidget`. Implement
`buildContent(BuildContext)`, not `build`.

### TomStatefulWidget

`abstract class TomStatefulWidget extends StatefulWidget`, exposing the
captured `constructionScope` to its state.

### TomState

`abstract class TomState<T extends TomStatefulWidget> extends State<T>`. The
state half of the pair: implement `buildContent(BuildContext)`.

## Screen elements

### TomScreenElementsProvider

`abstract interface class TomScreenElementsProvider`. The contract a screen
satisfies to declare its widgets as typed fields that reflection can discover:
one member, `TomScope get scope`.

### TomScreenElementsProviderBase

The concrete base, which is also a `TomScope`. Its constructor takes an
optional pass-through scope; `scope` answers that scope when one was given and
`this` otherwise, so a provider is either its own scope or transparent to an
enclosing one. `getScopePath()` is the resulting path.

## Authorization

### TomAuthLayers

One static, and the reason the class exists: `TomAuthLayers.resolve` is the
single place the layer order lives.

```dart
static TomAuthState resolve({
  required String? basePath,
  required TomAuthorizationGroup? group,
  required TomScope groupScope,
  required TomAuthorizer? authorizer,
  required TomUIStateController? uiStateController,
  TomAuthState? narrowBy,
})
```

Three callers share it — `TomPolicyNodeBase.resolveEffectiveAuth`,
`TomWidgetMixin.getAuth` and `TomField.resolveEffectiveAuth` — and only the
last supplies `narrowBy`. `groupScope` is passed rather than derived so the
group's rule and the widget's `basePath` are looked up in the same scope.

## Path composition

### TomScopePath

The one place a scope path and a widget id become a canonical resource path.

| Static | Signature | Returns |
| ------ | --------- | ------- |
| `join` | `String join(String parentPath, String tomId)` | `parentPath.tomId` |
| `qualify` | `String qualify(String tomId, [TomScope? scope])` | the id qualified by `scope` or the ambient one |
| `resolve` | `String? resolve(String? tomId, [TomScope? scope])` | the same, `null` when `tomId` is `null` |

`qualify` and `resolve` differ only in nullability, which is what lets a widget
with no id skip the lookup instead of composing a path ending in `null`.

## Resource resolution

### TomCtr

Twenty-three statics, each taking a `basePath` and an optional `suffix`. Three
shapes say what a *miss* means, so the caller chooses rather than the resolver:
the plain reader answers the key back (a missing label renders as its own path,
which is how you spot one on screen), `…OrNull` answers `null`, and `…OrFail`
throws a `StateError`.

| Static | Signature |
| ------ | --------- |
| `resolvePath` | `String? resolvePath(String? tomId, [TomScope? scope])` |
| `childTomId` | `String? childTomId(String? tomId, String suffix)` |
| `text` | `String text(String? basePath, [String suffix = ''])` |
| `textOrNull` | `String? textOrNull(String? basePath, [String suffix = ''])` |
| `textOrFail` | `String textOrFail(String? basePath, String suffix)` |
| `exists` | `bool exists(String? basePath, [String suffix = ''])` |
| `color` | `Color? color(String? basePath, [String suffix = ''])` |
| `colorOrFail` | `Color colorOrFail(String? basePath, String suffix)` |
| `icon` | `IconData? icon(String? basePath, [String suffix = ''])` |
| `iconOrFail` | `IconData iconOrFail(String? basePath, String suffix)` |
| `doubleVal` | `double? doubleVal(String? basePath, [String suffix = ''])` |
| `doubleOrFail` | `double doubleOrFail(String? basePath, String suffix)` |
| `intVal` | `int? intVal(String? basePath, [String suffix = ''])` |
| `intOrFail` | `int intOrFail(String? basePath, String suffix)` |
| `boolVal` | `bool? boolVal(String? basePath, [String suffix = ''])` |
| `value` | `dynamic value(String? basePath, [String suffix = ''])` |
| `list` | `List<dynamic>? list(String? basePath, [String suffix = ''])` |
| `map` | `Map<String, dynamic>? map(String? basePath, [String suffix = ''])` |
| `edgeInsets` | `EdgeInsets? edgeInsets(String? basePath, [String suffix = ''])` |
| `textStyle` | `TextStyle? textStyle(String? basePath, [String suffix = ''])` |
| `inputBorder` | `InputBorder? inputBorder(String? basePath, [String suffix = ''])` |
| `widgetStateColor` | `WidgetStateProperty<Color>? widgetStateColor(String? basePath, [String suffix = ''])` |
| `breakpointed` | `(T? value, List<(double, T)> overrides)? breakpointed<T>(String? basePath, [String suffix = ''])` |

`text` is the only reader with no `…OrNull`: its miss behaviour *is* the
fallback, so a nullable twin would answer a question nobody asks. `colorOrFail`
and `iconOrFail` throw on three distinct failures — no `tomId`, no resource,
and a resource that is present but unusable — because each is a wiring mistake
rather than a missing translation.

`breakpointed<T>` is the one reader that returns a pair: a base value and the
`(width, value)` overrides above it, which is what a responsive property is
stored as.

## Style resolution

### TomStyleResolvers

Thirty-six statics in `parse…` / `resolve…` pairs. `parse…` takes a map the
caller already holds; `resolve…` takes a resource path, reads the map through
`TomCtr.map`, and parses it. Every `resolve…` returns the same nullable type as
its `parse…` twin and answers `null` when the path holds nothing.

| Pair | Produces |
| ---- | -------- |
| `parseTextStyle` / `resolveTextStyle` | `TextStyle?` |
| `parseButtonStyle` / `resolveButtonStyle` | `ButtonStyle?` |
| `parseInputDecoration` / `resolveInputDecoration` | `InputDecoration?` |
| `parseMenuStyle` / `resolveMenuStyle` | `MenuStyle?` |
| `parseShapeBorder` / `resolveShapeBorder` | `ShapeBorder?` |
| `parseBorderSide` / `resolveBorderSide` | `BorderSide?` |
| `parseBorderRadius` / `resolveBorderRadius` | `BorderRadius?` |
| `parseDecoration` / `resolveDecoration` | `Decoration?` |
| `parseBoxConstraints` / `resolveBoxConstraints` | `BoxConstraints?` |
| `parseAlignment` / `resolveAlignment` | `AlignmentGeometry?` |
| `parseOffset` / `resolveOffset` | `Offset?` |
| `parseTableBorder` / `resolveTableBorder` | `TableBorder?` |
| `parseVisualDensity` / `resolveVisualDensity` | `VisualDensity?` |
| `parseIconThemeData` / `resolveIconThemeData` | `IconThemeData?` |
| `parseStrutStyle` / `resolveStrutStyle` | `StrutStyle?` |
| `parseTextHeightBehavior` / `resolveTextHeightBehavior` | `TextHeightBehavior?` |
| `parseScrollPhysics` / `resolveScrollPhysics` | `ScrollPhysics?` |

Two parsers have no `resolve…` twin, because nothing addresses them by their
own resource path — each is read as part of a larger map: `parseEdgeInsets`
(reached through `TomCtr.edgeInsets`) and `parseFontWeight` (reached through
`parseTextStyle`).

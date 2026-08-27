# Advanced Container Layout Module

`advanced_container_layout/` (ACL) is the **fluent, row-based layout engine**
of `tom_flutter_ui`. It is the Flutter re-implementation of the legacy Java AWT
`AdvancedContainerLike`: you *append* widgets into rows, tune their sizes,
gaps, and alignments declaratively, and the engine computes a constraint-driven
layout. On top of plain placement it layers **responsive variants**, **row
breakpoints**, per-group **visibility controllers**, **device-context variant
detection**, scoped **ids/groups**, and **authorization-aware hiding**.

The public entry point is [`AclBuilder`] — a fluent builder whose `build()`
returns an [`Acl`] widget. Everything the builder accumulates is plain data, so
a layout can be *constructed* (and asserted on) with no widget tree; only
*rendering* needs `BuildContext`.

Rows do not have to be written by hand. [`AclFlowContainer`] takes a flat child
list and *generates* the rows for it under one of two rules — `wrap` or `grid`
— then hands them to the same engine, so a flowed layout keeps ids, anchors,
sizing and authorization hiding intact.

> **Looking for *why*?** This document is the module reference: the public API
> of `advanced_container_layout/` in isolation. The reasoning behind the engine
> — coordinate conventions, the three-phase row-sizing algorithm, the
> convergence loop, and the precedence rules between container defaults, rows
> and components — is in
> [acl_design_specification.md](acl_design_specification.md), whose §17 is the
> complete `AclBuilder` surface. Both are registered in
> [README.md](README.md), which explains the split.

## Table of Contents

- [Overview](#overview)
- [`AclBuilder` and `Acl`](#aclbuilder-and-acl)
- [Layout attribute flags](#layout-attribute-flags)
- [Sizing and the default preferred width](#sizing-and-the-default-preferred-width)
- [Row alignment](#row-alignment)
- [Flow containers — `wrap` and `grid`](#flow-containers--wrap-and-grid)
- [Responsive variants and breakpoints](#responsive-variants-and-breakpoints)
- [Breakpoint resolution](#breakpoint-resolution)
- [Device context and variant detection](#device-context-and-variant-detection)
- [Group visibility controllers](#group-visibility-controllers)
- [Scopes, ids, and groups](#scopes-ids-and-groups)
- [Authorization integration](#authorization-integration)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `AclBuilder` | class | Fluent builder; `build()` returns an `Acl` widget. |
| `Acl` | widget | The built layout (`Acl extends AclLayout extends StatelessWidget`). |
| `AclContainer` | widget | The stateful render engine that lays rows/components out. |
| `AclComponent` / `AclRow` | class | The engine's data model — one placed child, and an ordered row of them. |
| `AclFlowContainer` | widget | Generates rows from a flat child list and renders them through an `AclContainer` it composes — not a subclass of one. |
| `AclFlowKind` | enum | `wrap` / `grid` — the two row-generation rules. |
| `aclWrapRows` / `aclGridRows` | function | The pure row generators behind those rules. |
| `aclResolveBreakpointed<T>` | function | The one `(minWidth, value)` "widest match wins" rule. |
| `AclFlags` | class | AWT-style attribute bit constants (`expandX`, `expandY`, …). |
| `RowAlignment` | enum | Horizontal row alignment (`left` / `center` / `right`). |
| `AclVariant` / `AclRowBreakpoint` | class | Responsive layout overrides keyed by width. |
| `AclDeviceContext` | class | Snapshot of device/layout environment + static resolvers. |
| `AclVariantDetector` | typedef | `bool Function(AclDeviceContext, Acl?, BuildContext)`. |
| `AclInputMode` / `AclFormFactor` / `AclDensity` | enum | Variant-detection facets. |
| `AclGroupVisibilityController` | class | Drives a named group's `visible`/`hidden`/`disabled` state. |
| `AclScope` | InheritedWidget | Propagates container/component/row/group id paths. |

## `AclBuilder` and `Acl`

A layout is declared by chaining fluent calls and finishing with `build()`:

```dart
final Acl layout = AclBuilder(title: 'Address')
    .append(const TomTextField(tomId: 'street')).expandX()
    .gap()
    .append(const TomTextField(tomId: 'no'))
    .newRow()
    .append(const TomTextField(tomId: 'city'))
    .build();
```

- `append(child, {dist})` adds a component; `gap({weight})` inserts an elastic
  spacer; `newRow(...)` / `gapRow(...)` start the next row.
- **Gaps are on by default.** Every appended component gets an 8 px leading gap
  and every `newRow()` an 8 px gap above it, so a layout that never mentions
  spacing is already spaced. Change them with `setAclDefaultAppendGap` /
  `setAclDefaultRowGap`, or pass 0 to either to switch that gap off; an
  explicit `dist` on the individual call always wins.
- Size methods (`setPSize` / `setMSize` / `setXSize` and their char-width
  variants) set preferred/minimum/maximum sizes; `setAttr` / `clearAttr` toggle
  [`AclFlags`].
- Alignment methods (`alignLeftToLeft` … `alignBottomToBottom`, plus the
  `setRowHorizontalAlignment` / `setRowVerticalAlignment` family) constrain a
  component against an earlier reference.
- `build()` is **pure construction** — it maps the accumulated row/component
  data into an `Acl` widget and performs no rendering.

`append()` rejects the **same widget instance** twice (identity-based key
generation must stay unambiguous), and the `alignX*` / `alignY*` methods throw
`UnsupportedError` on a forward, same-row, or cross-row reference violation —
so misuse fails loudly at build time, not silently at render time.

## Layout attribute flags

[`AclFlags`] mirrors the Java AWT constants as composable bits:

| Flag | Bit | Meaning |
| ---- | --- | ------- |
| `expandX` / `expandY` | 1 / 2 | Fill available width / height. |
| `expand` | 3 | `expandX \| expandY`. |
| `gapElement` | 4 | Component is a gap/spacer. |
| `panelBackground` | 8 | Follow the parent container background. |
| `charDim` | 16 | Sizes are in character units, not pixels. |
| `otherDimX` / `otherDimY` | 32 / 64 | Take X / Y dimension from a reference. |
| `otherDim` | 96 | `otherDimX \| otherDimY`. |

The `AclBuilderExtensions` extension surfaces `expandX()` / `expandY()` /
`expand()` shortcuts over `setAttr`.

## Sizing and the default preferred width

A component appended with no `setPSize` / `setMSize` / `setXSize` and no
`expandX` receives `AclBuilder.defaultPreferredWidth` (150) and is marked
`AclComponent.preferredWidthIsDefault`. That flag is what separates a
*fabricated* width from a *declared* one, and the fabricated one is a **floor,
not a cap**:

- content narrower than 150 still occupies 150, so a short label or a button
  does not collapse next to an elastic gap;
- content that needs more — a `Row` of controls, which cannot shrink below the
  sum of its children — is measured and the component is widened to fit before
  the fit/shrink distribution runs, so the geometry the engine pre-calculates
  in pure Dart is the geometry that renders;
- content that still does not fit is **clipped**, never overflowed. The child
  keeps the width it laid out at, so narrowing the container changes how much
  is visible and nothing reflows.

```dart
// No size hint at all — the three buttons are measured and the component is
// widened past the 150 default to hold them.
final Acl actions = AclBuilder()
    .append(TomRow(children: [saveButton, cancelButton, helpButton]))
    .build();
```

An author-declared `maximumSize.width` still caps the widening; the fabricated
default is the only value this pass may overrule. A declared width is honoured
literally. Measurement lands one frame after the component first renders, and
until then the plain default applies with the clip covering the difference; a
child that cannot answer the intrinsics protocol (a `LayoutBuilder`, a
scrolling viewport) keeps the plain default. Size hints are therefore a
statement of *intent* — "this field is 220 wide", "these two line up" — not a
guard against overflow.

## Row alignment

[`RowAlignment`] (`left` / `center` / `right`) controls a row's horizontal
packing. Set it per row with `setRowHorizontalAlignment`, or via the
extension shortcuts `setRowAlignLeft` / `setRowAlignCenter` /
`setRowAlignRight`. Vertical (cross-axis) packing uses `AclRowCrossAlignment`,
set per row with `setRowVerticalAlignment` and per component with
`setVerticalAlignment`.

`setAclDefaultRowHorizontalAlignment` sets the builder-wide default and applies
it **retroactively** to every row that has not set its own alignment —
including the first row, which `AclBuilder` creates eagerly in its constructor.
Call order in the chain is therefore irrelevant:

```dart
// Both rows are centred: the default reaches back to the eagerly-created
// first row as well as forward to the one newRow() starts.
final Acl centred = AclBuilder()
    .append(const Text('one'))
    .newRow()
    .append(const Text('two'))
    .setAclDefaultRowHorizontalAlignment(RowAlignment.center)
    .build();
```

A row that called `setRowHorizontalAlignment` keeps its own value, so an
explicit per-row override is never clobbered by a later default change.
`setAclDefaultRowVerticalAlignment` is the cross-axis counterpart.

## Flow containers — `wrap` and `grid`

[`AclFlowContainer`] is a widget that **generates** its rows from a flat,
ordered child list instead of having them written one `newRow()` at a time. It
does not extend `AclContainer` — it composes one: `build()` measures the
available width with a `LayoutBuilder`, computes the row assignment, and renders
the result through an ordinary `AclContainer`. [`AclFlowKind`] names the two
rules:

| Kind | Rule |
| ---- | ---- |
| `wrap` | Fill a row until the next component no longer fits, then break. |
| `grid` | Break every `columns` components, each cell the same width. |

Because both rules produce ordinary `AclRow`s that go to the ordinary engine,
what the engine applies per row and per component — id addressing, alignment
and anchoring, sizing, the hide-unauthorized pass and the `read`
styling — keeps working on a flowed layout, and each generated row is
addressable as `r<n>`, or `<aclId>.r<n>` when the container sets
`idScope: true` (see [`idScope`](#idscope--which-ids-become-path-segments)).

What does *not* carry over is the container's own responsive machinery.
`AclFlowContainer` forwards only a subset of `AclContainer`'s arguments —
`aclId`, `idScope`, `aclGroup`, `parentIdPath`, `padding`, `borderStyle`,
`backgroundColor`, `scrollableY` — and `variants` is not among them, so an
`AclVariant` can never replace a flow container's generated rows. Generated
rows carry no `breakpoints` either. A flow container's responsiveness is
`columnsBpOverrides` (below); to vary a flowed block any further, place it as a
component inside an authored layout and put the variants on *that* container.

```dart
Widget buildTagCloud(List<String> tags) {
  return AclFlowContainer(
    kind: AclFlowKind.wrap,
    aclId: 'tags',
    gutterWidth: 8,
    runSpacing: 8,
    components: [
      for (final tag in tags)
        AclComponent(
          child: Chip(label: Text(tag)),
          id: tag,
          preferredSize: const Size(120, 0),
        ),
    ],
  );
}
```

Declare a `preferredSize` on flowed children whose natural width matters: the
break decision happens *before* layout and so cannot measure. `aclFlowItemWidth`
mirrors the engine's own order — preferred → minimum → `defaultItemWidth` —
and an unsized component is assumed to be `kAclDefaultFlowItemWidth` (150) wide.

`grid` carries per-breakpoint column counts, which is what a responsive
dashboard needs and what a variant per column count used to cost:

```dart
AclFlowContainer(
  kind: AclFlowKind.grid,
  aclId: 'dashboard',
  columns: 1,
  columnsBpOverrides: const [(600.0, 2), (1024.0, 4)],
  components: cards.map((c) => AclComponent(child: c)).toList(),
);
```

One column on a phone, two from 600 px, four from 1024; each cell gets
`(availableWidth - gutterWidth * (columns - 1)) / columns`. `columns < 1`
throws `ArgumentError`. Setting `aclId` makes the generated rows addressable as
`dashboard.r0`, `dashboard.r1`, … — which is how a resource or authorization
rule reaches a row no author ever wrote.

The container measures the line with a `LayoutBuilder` and subtracts its own
horizontal padding, so the rule breaks against the *content* width; an
unbounded width means "never break". The row assignment itself is a pure
function of plain data, exposed both as `buildRows(availableWidth)` on the
container and as the free functions [`aclWrapRows`] / [`aclGridRows`], so it can
be asserted with no widget tree at all:

```dart
// 3 × 100 wide + 2 × 10 gutter = 320 fits in 340; a 4th would need 430.
final rows = aclWrapRows(
  List.generate(
    4,
    (i) => AclComponent(child: Text('c$i'), preferredSize: const Size(100, 0)),
  ),
  availableWidth: 340,
  gutterWidth: 10,
);

expect(rows.length, 2);
expect(rows[0].components.length, 3);
expect(rows[1].components.length, 1);
```

## Responsive variants and breakpoints

Two complementary mechanisms adapt a layout to width:

- **Variants** (`addVariant(name, atWidth:, builder:)`) describe an entirely
  separate row set that replaces the base layout below `atWidth`. Variants are
  sorted ascending by `atWidth` so the narrowest (most specific) match wins.
  The variant builder is a **fresh** `AclBuilder` that inherits none of the
  outer builder's `setAclDefault*` values — restate the ones the variant needs,
  or the layout silently changes spacing and alignment below the breakpoint.
  Container chrome is unaffected either way: it belongs to the container, and a
  variant supplies only rows.
- **Row breakpoints** (`addRowBreakpoint(atWidth:, splitRowDist:)`) split a
  single row into two when the container narrows past `atWidth`, recording the
  split index from the components appended so far. Unlike a variant, a split
  fragment keeps the original row's settings — it is the same logical row.

## Breakpoint resolution

Three attributes carry `(minWidth, value)` override lists — a row's
`defaultAppendGap`, a row's `height`, and `AclFlowContainer.columns`. All three
resolve through one public function:

```dart
T aclResolveBreakpointed<T>(T base, List<(double, T)> overrides, double? availableWidth);
```

The override with the **largest** `minWidth` still `<= availableWidth` wins;
`base` applies when no override qualifies, when the list is empty, or when the
width is not yet known. Being public means a caller can predict a gap or a
height exactly the way the engine will, without rendering:

```dart
const gaps = <(double, double)>[(600.0, 12.0), (1024.0, 24.0)];
aclResolveBreakpointed(8.0, gaps, 500);   // 8.0  — nothing qualifies
aclResolveBreakpointed(8.0, gaps, 800);   // 12.0
aclResolveBreakpointed(8.0, gaps, 1400);  // 24.0 — widest match wins
```

Two thin wrappers read the values off a row: `aclEffectiveGapBefore(comp, row,
availableWidth)` returns a component's resolved leading gap (falling back to the
row's breakpointed default only when the component set none of its own), and
`aclResolveRowHeight(row, availableWidth)` returns the row's resolved height, or
`null` when the row sets none.

Note the direction: these lists read "**at this width and above**", the
opposite of `AclVariant.atWidth` / `AclRowBreakpoint.atWidth`, which apply
*below* their width.

## Device context and variant detection

[`AclDeviceContext`] is an immutable snapshot of the render environment
(width/height, input mode, form factor, orientation, platform, web flag,
density, text direction, accessibility scale). `AclDeviceContext.of(context, …)`
builds one from a `BuildContext`, but the **classification logic is pure and
static** — testable with no widget tree:

| Resolver | Rule |
| -------- | ---- |
| `resolveFormFactor(width)` | `< 600` → phone, `< 1024` → tablet, else desktop. |
| `resolveDensity(visualDensity)` | avg of the two axes: `≤ −1.5` compact, `≤ −0.5` comfortable, else standard. |
| `resolveInputMode(platform)` | iOS/Android → touch; desktop + web → pointer. |

`buildConvenienceDetector({...})` assembles an [`AclVariantDetector`] from named
facets with **AND** semantics — every supplied condition must hold. It returns
`null` when no facet is given (the default variant); otherwise the predicate
treats `width`/`height` as **exclusive upper bounds** (`>=` → no match),
`minAccessibilityScale` as an **inclusive lower bound** (the two numeric facets
point in opposite directions), and compares the rest for equality/membership.

`height` is the one facet whose input can be absent: `AclDeviceContext.height` is
`double?`, and the container reports `null` for it whenever the incoming
constraints have unbounded height. An absent height **fails** the facet rather
than being skipped, so a `height`-gated variant never activates while the
container shrink-wraps — inside a `Column`, a `ListView`, or any scrollable —
and the row falls back to its default variant. Give the container a bounded
height if a height-gated variant is meant to fire. See
`test/advanced_container_layout/acl_variant_detector_test.dart`.

## Group visibility controllers

A named group's visibility is driven by an [`AclGroupVisibilityController`],
whose `modeNotifier` (a `ValueNotifier<AclGroupVisibilityMode>`) the container
listens to. The three modes are `visible`, `hidden` (removed from layout — zero
size, no paint), and `disabled` (shown but non-interactive). Two
implementations ship:

- **`AclBinaryVisibilityController`** — a direct toggle; assign `controller.mode`
  to flip it.
- **`AclCallbackVisibilityController<T>`** — derives the mode from an external
  `ValueListenable<T>` via a `modeBuilder`, re-evaluating on every source
  change.

Both are `ValueNotifier`-backed, so their behaviour is exercised without a
widget tree; remember to `dispose()` them with the container. Register one with
`builder.setGroupVisibilityController(groupName, controller)`.

## Scopes, ids, and groups

[`AclScope`] is an `InheritedWidget` that propagates the container, component,
row, and group id paths down the tree (`AclScope.of(context)` reads the
nearest). The builder assigns ids with `setAclId` / `setId` / `setRowId` and
groups with `startGroup` / `endGroup` / `group` / `setAclGroup` / `setRowGroup`;
`startGroup` rejects nesting and `endGroup` rejects an unmatched call.

### `idScope` — which ids become path segments

An id is not automatically a namespace. `idScope`, set with `setAclIdScope` for
the container and `setRowIdScope` for the current row, decides whether that id
is added to the paths of everything **beneath** it:

| Value | Meaning |
| ----- | ------- |
| `false` (default) | Layout container / layout row. The id addresses this container or row for its *own* authorization, and does not appear in descendant paths. |
| `true` | Identity container / identity row. The id is prepended to every descendant path. |

Segments compose in this order, each omitted when absent or not in scope:

```text
<TomScope path> . <aclId> . <group> . <rowId> . <componentId>
```

So the same layout addresses its delete button four different ways:

```dart
AclBuilder()
    .setAclId('order').setAclIdScope(true)     // ── drop this → 'actions.delete'
    .setRowId('actions').setRowIdScope(true)   // ── drop this → 'order.delete'
    .append(deleteButton).setId('delete')      // ── drop both → 'delete'
    .build();                                  //    as written → 'order.actions.delete'
```

A row is addressable by its own id regardless of its `idScope` — that is what
"for its own authorization" means — so `order.actions` resolves in every case
above. Rows generated by a flow container follow the same rule: they are layout
rows named `r<n>`, so they add no segment to their components and are
themselves addressable as `<aclId>.r<n>` when the container is an identity
container.

A composed path does not depend on the viewport. When a row breakpoint splits a
row, every fragment carries the original row's `id` and `idScope`, so the row
resolves one policy across all of its fragments and its components keep the
same paths at every width.

## Authorization integration

When a component child implements `TomAuthorizable`, the container honours its
`effectiveAuthState`. `setAclDefaultHideUnauthorized()` makes the whole
container hide components whose resolved state is `none`; an individual
component can opt out with a per-component `setHideUnauthorized(false)`. When a
hidden component (or a fully hidden row) is elided, the engine forwards the
appropriate gap so the surviving neighbours keep their spacing — the behaviour
covered in detail by `test/advanced_container_layout/acl_hide_unauthorized_test.dart`.

Rows and components carrying an `id` are additionally resolved by path through
`TomAuthorization.resolveAuth(...)`. Of the four `TomAuthState` values the
container acts on only two:

| State | What the container does |
| ----- | ----------------------- |
| `none` | Elided — the component (or row) is replaced by a zero-size box, or removed outright under `hideUnauthorized`. |
| `disabled` | **Nothing. It renders exactly as `full`** — full opacity, input live. |
| `read` | Wrapped in `TomThemeScope.readonlyStyleOf(context).apply(child)` — by default `AbsorbPointer` + `Opacity(0.6)`: the value stays readable, dimmed, and inert. Applies at both levels — a `read` row styles all its components, a `read` component styles itself. |
| `full` | Rendered as authored — no wrapper. |

`TomAuthState.disabled` is intended to render a component visible but inert,
and the container does not implement it — there is no `disabled` branch in the
component pipeline, so a `disabled` grant is not enforced. Do not confuse this
with the group-visibility axis above: `AclGroupVisibilityMode.disabled` *does*
dim and block input, but that wrapper keys on the group mode alone and never on
the resolved authorization state. Until the container consults
`TomAuthState.isInteractive`, express a "visible but not usable" grant as
`none`, or through the component's group.

The `read` treatment is the only authorization visual you can customise, and it
belongs to the theme rather than to the container. `TomTheme.readonlyStyle`
holds a [`TomReadonlyStyle`] — note the lowercase `o` — which the container
reaches through `TomThemeScope.readonlyStyleOf(context)`. Put a `TomThemeScope`
anywhere above the container to change it:

```dart
TomThemeScope(
  theme: const TomTheme(
    readonlyStyle: TomReadonlyStyle(
      opacity: 1.0,                      // 1.0 disables dimming
      colorOverlay: Color(0x33888888),   // tint via ColorFiltered instead
    ),
  ),
  child: acl,
)
```

`apply` wraps `ColorFiltered` → `Opacity` → `AbsorbPointer` outwards, omitting
the opacity wrapper at `opacity: 1.0` and the `AbsorbPointer` at
`absorbPointers: false`. Supplying a `builder` replaces the treatment
altogether — useful when a widget family renders its own read-only form (a text
field that swaps to a non-editable display, say) and should not be dimmed on
top of it.

## Dependencies

- `package:flutter/material.dart` — `Widget`, `BuildContext`, `InheritedWidget`,
  `VisualDensity`, `TargetPlatform`, the render primitives in `AclContainer`.
- `package:flutter/foundation.dart` — `ValueNotifier` / `ValueListenable` behind
  the visibility controllers, `kIsWeb`.
- `package:tom_core_kernel/...` — `TomAuthorizable` / `TomAuthState` for the
  authorization-aware hiding.

> The builder, flags, device-context resolvers, and visibility controllers are
> pure and need no widget tree (only the render path does), but the package
> barrel pulls in `flutter/material` (→ `dart:ui`), so run the example under the
> Flutter toolchain — see
> [`example/advanced_container_layout/advanced_container_layout_example.dart`](../example/advanced_container_layout/advanced_container_layout_example.dart),
> exercised by `flutter test`.

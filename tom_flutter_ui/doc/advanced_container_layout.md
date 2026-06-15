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

## Table of Contents

- [Overview](#overview)
- [`AclBuilder` and `Acl`](#aclbuilder-and-acl)
- [Layout attribute flags](#layout-attribute-flags)
- [Row alignment](#row-alignment)
- [Responsive variants and breakpoints](#responsive-variants-and-breakpoints)
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

## Row alignment

[`RowAlignment`] (`left` / `center` / `right`) controls a row's horizontal
packing. Set it per row with `setRowHorizontalAlignment`, or via the
extension shortcuts `setRowAlignLeft` / `setRowAlignCenter` /
`setRowAlignRight`. Vertical (cross-axis) packing uses `AclRowCrossAlignment`.

## Responsive variants and breakpoints

Two complementary mechanisms adapt a layout to width:

- **Variants** (`addVariant(name, atWidth:, builder:)`) describe an entirely
  separate row set that replaces the base layout below `atWidth`. Variants are
  sorted ascending by `atWidth` so the narrowest (most specific) match wins.
- **Row breakpoints** (`addRowBreakpoint(atWidth:, splitRowDist:)`) split a
  single row into two when the container narrows past `atWidth`, recording the
  split index from the components appended so far.

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
treats `width`/`height` as upper bounds (`>=` → no match) and compares the rest
for equality/membership.

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

## Authorization integration

When a component child implements `TomAuthorizable`, the container honours its
`effectiveAuthState`. `setAclDefaultHideUnauthorized()` makes the whole
container hide components whose resolved state is `none`; an individual
component can opt out with a per-component `setHideUnauthorized(false)`. When a
hidden component (or a fully hidden row) is elided, the engine forwards the
appropriate gap so the surviving neighbours keep their spacing — the behaviour
covered in detail by `test/advanced_container_layout/acl_hide_unauthorized_test.dart`.

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

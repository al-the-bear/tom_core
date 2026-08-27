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
- [Gap slots — elastic horizontal space](#gap-slots--elastic-horizontal-space)
- [Gap rows and separators](#gap-rows-and-separators)
- [Container borders](#container-borders)
- [Container titles](#container-titles)
- [Scrolling](#scrolling)
- [Layout direction — LTR and RTL](#layout-direction--ltr-and-rtl)
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

Every type the module barrel exports, grouped by the job it does.
`test/advanced_container_layout/acl_doc_coverage_test.dart` derives the
left-hand column from the barrel and fails if the two ever disagree, in either
direction — so this index is complete by construction rather than by review.

### Building and rendering

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `AclBuilder` | class | Fluent builder; `build()` returns an `Acl` widget. |
| `AclBuilderExtensions` | extension | Shorthand over `setAttr` and the row-alignment setters — `expandX()`, `setRowAlignCenter()`, … |
| `Acl` | widget | The built layout: an `AclLayout` that additionally draws a [container title](#container-titles). |
| `AclLayout` | widget | The title-less layout widget `Acl` extends. An `Acl` with no title renders exactly this. |
| `AclContainer` | widget | The stateful render engine that lays rows/components out. |
| `AclComponent` / `AclRow` | class | The engine's data model — one placed child, and an ordered row of them. |

### Sizing, flags and alignment

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `AclFlags` | class | AWT-style attribute bit constants (`expandX`, `expandY`, …). |
| `RowAlignment` | enum | Horizontal row packing (`left` / `center` / `right`). |
| `AclRowCrossAlignment` | enum | Vertical placement of a component within its row (`top` / `center` / `bottom`). |
| `AclAxisPointX` / `AclAxisPointY` | enum | The edge and centre anchors the `alignX*` / `alignY*` families record on `AclComponent`. Not passed directly — the named methods write them. |

### Container chrome

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `AclBorderStyle` | class | A [container border](#container-borders): kind, colour, line width, rounding, inner insets. |
| `AclBorderKind` | enum | Which edges that border draws — `none`, `solid`, `solidDouble`, and the per-side and per-axis variants. |
| `AclTitlePosition` | enum | Where the [title](#container-titles) label sits: `topLeft` / `topCenter` / `topRight`. |
| `AclTitleBorderAlign` | enum | How that label straddles the border line: `top` / `middle` / `bottom`. |
| `AclSeparator` | class | A horizontal rule drawn inside a [gap row](#gap-rows-and-separators). |
| `AclSeparatorStyle` | enum | `single` / `doubleLine`. |
| `AclSeparatorAlignment` | enum | Where in the gap row the rule is drawn: `top` / `middle` / `bottom`. |

### Flow containers

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `AclFlowContainer` | widget | Generates rows from a flat child list and renders them through an `AclContainer` it composes — not a subclass of one. |
| `AclFlowKind` | enum | `wrap` / `grid` — the two row-generation rules. |
| `aclWrapRows` / `aclGridRows` | function | The pure row generators behind those rules. |
| `aclResolveBreakpointed<T>` | function | The one `(minWidth, value)` "widest match wins" rule. |

### Responsive behaviour

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `AclVariant` / `AclRowBreakpoint` | class | Responsive layout overrides keyed by width. |
| `AclDeviceContext` | class | Snapshot of device/layout environment + static resolvers. |
| `AclVariantDetector` | typedef | `bool Function(AclDeviceContext, Acl?, BuildContext)`. |
| `AclInputMode` / `AclFormFactor` / `AclDensity` | enum | Variant-detection facets. |

### Identity, groups and direction

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `AclScope` | InheritedWidget | Propagates container/component/row/group id paths. |
| `AclGroupVisibilityController` | class | Drives a named group's `visible`/`hidden`/`disabled` state. |
| `AclGroupVisibilityMode` | enum | The three states that controller publishes. |
| `AclBinaryVisibilityController` | class | Direct toggle — assign `controller.mode`. |
| `AclCallbackVisibilityController<T>` | class | Derives the mode from an external `ValueListenable<T>`. |
| `AclDirection` | enum | [Layout direction](#layout-direction--ltr-and-rtl) — `ltr` / `rtl`. |
| `AclDirectionScope` | InheritedWidget | Supplies an `AclDirection` to every descendant container that sets none of its own. |

## `AclBuilder` and `Acl`

A layout is declared by chaining fluent calls and finishing with `build()`:

```dart
final Acl layout = AclBuilder(title: 'Address')
    .append(TomTextField(tomId: 'street')).expandX()
    .gap()
    .append(TomTextField(tomId: 'no'))
    .newRow()
    .append(TomTextField(tomId: 'city'))
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

| Flag | Bit | Meaning | Set with | Read with |
| ---- | --- | ------- | -------- | --------- |
| `expandX` / `expandY` | 1 / 2 | Claim the row's surplus width / fill the row height. | `expandX()` / `expandY()` | `.expandX` / `.expandY` |
| `expand` | 3 | `expandX \| expandY`. | `expand()` | — |
| `gapElement` | 4 | The component is an elastic spacer, not content — **its child is never built**. | `gap()` | `.isGap` |
| `otherDimX` / `otherDimY` | 32 / 64 | Take the X / Y dimension from `referenceKey`. | `sameWidthAs()` / `sameHeightAs()` | `.useOtherDimX` / `.useOtherDimY` |
| `otherDim` | 96 | `otherDimX \| otherDimY`. | `sameSize()` | — |

The bit values are sparse because they mirror the AWT constants the Java
`AdvancedContainerLike` used; 8 and 16 are unassigned. Every flag in the table
is one the container actually reads — `acl_flags_contract_test.dart` derives
this table's left three columns from `AclFlags` and fails if a flag is
declared but never read, documented with the wrong bit, or missing here.

The `AclBuilderExtensions` extension surfaces `expandX()` / `expandY()` /
`expand()` shortcuts over `setAttr`. The "Read with" column is a getter on
`AclComponent`, which is what lets you interpret a row you were handed rather
than one you built.

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

## Gap slots — elastic horizontal space

`gap({weight})` inserts an elastic **horizontal** spacer into the current row.
Slots share whatever width is left after the row's real components have been
fitted, divided by weight:

```dart
// Title hard left, buttons hard right — the slot absorbs the slack.
final Acl bar = AclBuilder()
    .append(const Text('Title'))
    .gap()
    .append(const Text('OK'))
    .append(const Text('Cancel'))
    .build();

// Two slots, 2:1 — the left one takes twice the surplus of the right.
final Acl split = AclBuilder()
    .gap(weight: 2)
    .append(const Text('centre-right'))
    .gap(weight: 1)
    .build();
```

A gap slot **is** an `AclComponent` — it sits in `AclRow.components` alongside
the real ones, and carries `AclFlags.gapElement`, which `AclComponent.isGap`
reads back. It differs from a content component in one decisive way: **its
`child` is never built.** The container skips it in both the measuring and the
building pass and emits a `Spacer` in its place. `gap()` therefore supplies a
`SizedBox.shrink()` as a placeholder child that never renders.

Two consequences follow from that, and both are easier to hit than to diagnose:

- **`gap()` is not a target for per-component calls.** The builder stops
  tracking a current component when it inserts a slot, so `setPSize`,
  `expandX`, `setVerticalAlignment` and friends chained straight after a
  `gap()` are silently ignored rather than applied to the slot. Size a gap
  with its `weight`, not with a size hint.
- **Setting `AclFlags.gapElement` by hand discards a widget.** Reaching for
  `.append(w).setAttr(AclFlags.gapElement)` turns `w` into a spacer and drops
  it from the tree. Use `gap()`; it sets the bit, the weight and the
  placeholder together.

| Situation | Slot width |
| --------- | ---------- |
| Surplus available, one slot | All of the surplus. |
| Surplus available, several slots | `surplus × weight / Σ weights`. |
| No surplus (row already full) | 0 — the slot collapses, content is never pushed out. |
| `setAclScrollableX()` | 0 — elastic distribution is meaningless on a scrollable axis. |

A row that contains any gap slot **overrides `setRowHorizontalAlignment` to
left**. The two mechanisms both decide where content sits in surplus width, and
a slot that has already absorbed the surplus leaves the alignment nothing to
distribute — so the container settles it rather than letting the result depend
on which one you set last. Justify a row with slots (`gap()` before, after, or
both) *or* with `setRowHorizontalAlignment`, not with both.

`gapRow()` is the vertical counterpart, and differs in kind — it is a *row*,
not a component. See the next section.

## Gap rows and separators

`gapRow({weight, separator, minSize})` inserts an elastic **vertical** spacer
between content rows. It holds no components and **implicitly starts a new
content row**, so no `newRow()` follows it:

```dart
AclBuilder()
    .append(header)
    .gapRow()                       // elastic spacer — no newRow() needed
    .append(body)
    .gapRow(weight: 2, separator: const AclSeparator())
    .append(footer)
    .build();
```

When the container has bounded height and no `expandY` component, gap rows
share the leftover vertical space in proportion to their weights:

```text
gapRow[i] height = (containerHeight − Σ content row heights) × weight[i] / Σ weights
```

**Elasticity is lost in three situations, and the fallback is not "zero".**
When the layout contains an `expandY` component, when the height is unbounded,
or when the container is [scrollable on Y](#scrolling), a gap row stops
competing for space and becomes fixed instead:

| Gap row | Fixed height |
| ------- | ------------ |
| With a `separator` | `max(9, minSize)` — enough for the line plus 4 px above and below. |
| Without one | `minSize`, and the row disappears entirely at the default `minSize: 0`. |

So a separator drawn in a scrollable or shrink-wrapping container still
renders; only the *spacing* collapses. Give a pure spacing gap row a `minSize`
when it must survive those situations.

### `AclSeparator`

The optional `separator` draws a horizontal rule inside the gap row's area:

```dart
gapRow(separator: const AclSeparator(
  style: AclSeparatorStyle.doubleLine,
  color: Colors.grey,                       // null → Theme.of(context).dividerColor
  lineWidth: 1.0,
  alignment: AclSeparatorAlignment.middle,
));
```

| Field | Type | Default | Meaning |
| ----- | ---- | ------- | ------- |
| `style` | `AclSeparatorStyle` | `single` | `single` draws one line; `doubleLine` draws two, separated by `lineWidth × 2`. |
| `color` | `Color?` | `null` | Falls back to the ambient `Theme.dividerColor`, so a separator follows the theme unless told otherwise. |
| `lineWidth` | `double` | `1.0` | Thickness of each line. |
| `alignment` | `AclSeparatorAlignment` | `middle` | `top` / `middle` / `bottom` of the gap row's computed height. |

The rule spans the full container width — it is not affected by
[`RowAlignment`](#row-alignment), which packs components rather than chrome.

## Container borders

A border belongs to the container, not to a row, and is described by an
[`AclBorderStyle`]. Pass it to the constructor or set it on the chain:

```dart
AclBuilder(borderStyle: const AclBorderStyle.solid(rounded: true))
    .append(field)
    .build();

// or
AclBuilder().setAclBorderStyle(const AclBorderStyle.solid()).append(field).build();
```

| Field | Type | Default | Meaning |
| ----- | ---- | ------- | ------- |
| `kind` | `AclBorderKind` | `none` | Which edges are drawn (below). |
| `color` | `Color` | `0xFF9E9E9E` | Line colour. |
| `lineWidth` | `double` | `1.0` | Line thickness. |
| `rounded` | `bool` | `false` | Whether corners are rounded. |
| `borderRadius` | `double` | `8.0` | Corner radius, used only when `rounded`. |
| `borderInsets` | `EdgeInsetsGeometry` | `EdgeInsets.zero` | Inner padding between the border and the content. |

`AclBorderKind` picks the edges: `none` (the default — no border is drawn at
all), `solid` for all four sides, `solidDouble` for two concentric lines, the
four single sides `top` / `bottom` / `left` / `right`, and the two pairs
`horizontal` (top + bottom) and `vertical` (left + right). `AclBorderStyle`
exposes an `enabled` getter, which is simply `kind != AclBorderKind.none`, and
two convenience constructors — `AclBorderStyle.none()` and
`AclBorderStyle.solid(...)`.

**The default inner inset is conditional, and the condition is padding.** When
a border is enabled and `borderInsets` is left at `EdgeInsets.zero`, the
container inserts `EdgeInsets.all(4)` so content does not sit against the line.
Setting container-level padding (`setAclPadding` and friends) *suppresses* that
default — the padding replaces it. An explicit `borderInsets` always applies.

Two further setters are worth knowing:

- `setAclBorderInsets(insets)` **`copyWith`s the style that is currently set**,
  so it must come *after* `setAclBorderStyle`. Called first, it edits the
  `none` default and is then discarded by the later assignment.
- `setAclFocusedBorderStyle(style)` supplies an alternative style used while
  focus is anywhere inside the container — the ordinary way to highlight the
  group a user is editing. It is only consulted when non-null; otherwise the
  base style is drawn at all times.

Shadows and 3D bevels are deliberately absent: they belong to the application
theme, not to a layout container.

## Container titles

A title turns the container into a labelled group — the classic field-set look,
where the label interrupts the border line. `Acl` is the widget that draws it;
[`AclLayout`], which `Acl` extends, is the same layout without one, and an
`Acl` whose `title` is null or empty and which has no `titleWidget` renders
exactly as an `AclLayout`.

```dart
AclBuilder(
  title: 'Address',
  borderStyle: const AclBorderStyle.solid(rounded: true),
).append(street).newRow().append(city).build();
```

Every constructor argument has a matching setter — `setAclTitle`,
`setAclTitleWidget`, `setAclTitleStyle`, `setAclTitlePosition`,
`setAclTitleBorderAlign` and `setAclTitleVerticalOffset`:

| Setting | Type | Default | Meaning |
| ------- | ---- | ------- | ------- |
| `title` | `String?` | `null` | The label text. |
| `titleWidget` | `Widget?` | `null` | An arbitrary label widget. When set it **wins over `title`** — a checkbox or an icon + text row, say. |
| `titleStyle` | `TextStyle?` | `null` | Applied to `title`; defaults to `bodyMedium` at `w600`. Ignored when `titleWidget` is used. |
| `titlePosition` | `AclTitlePosition` | `topLeft` | `topLeft` / `topCenter` / `topRight`. |
| `titleBorderAlign` | `AclTitleBorderAlign` | `bottom` | Where the label sits relative to the border line. |
| `titleVerticalOffset` | `double` | `0.0` | Nudges the label up or down from its computed position. |

`AclTitleBorderAlign` decides how the label meets the line: `bottom` floats it
just above the border (the field-set default), `middle` centres it on the line,
and `top` hangs it below the line into the container interior. The label is
drawn on a backing of the container's `backgroundColor` — or the ambient
`Theme.scaffoldBackgroundColor` when none is set — which is what masks the
border segment behind it. **Set `backgroundColor` when the container sits on a
surface that is not the scaffold background**, or the mask paints the wrong
colour over the line.

Two consequences follow from the way the title is positioned:

- The container reserves **14 px above itself** for the label, and the title is
  drawn in an unclipped `Stack` over that reserve.
- When a border is enabled and `borderInsets` was not set explicitly, a top
  inner inset is injected so the first row does not collide with a label that
  hangs below the line — 8 px at `bottom`, 10 px at `middle`, 18 px at `top`.

A title needs no border: without one the label simply sits above the content.
Under [RTL](#layout-direction--ltr-and-rtl) the position mirrors, `topLeft`
becoming `topRight` and back.

## Scrolling

`setAclScrollableX()` and `setAclScrollableY()` switch the respective axis into
scroll mode. **The two axes are independent** and either may be enabled alone.

```dart
AclBuilder()
    .setAclScrollableY()
    .append(const Text('row 1'))
    .newRow()
    .append(const Text('row 2'))
    .build();
```

On a scrollable axis the container stops expanding to fill the space offered
and takes its natural content size instead, wrapping the content in a
`SingleChildScrollView` on that axis. Elastic distribution goes with it,
because there is no longer a fixed extent to distribute:

| Axis | What changes |
| ---- | ------------ |
| `setAclScrollableX()` | `gap()` slots receive **zero width**, and an `expandX` component takes its preferred or intrinsic width rather than a share of the row. |
| `setAclScrollableY()` | Gap rows stop being elastic and take the fixed heights described under [gap rows](#gap-rows-and-separators) — a separator still draws, a pure spacing row survives only via `minSize`. |

Because a scrollable-Y container reports an unbounded height to the layout
pass, a variant gated on `height:` never activates inside one — see
[device context and variant detection](#device-context-and-variant-detection).

## Layout direction — LTR and RTL

ACL lays rows out left-to-right by default. `AclDirection.rtl` mirrors the
whole layout: components flow right-to-left, alignment semantics flip, and
horizontal offsets are negated.

There are two ways to set it, and they differ in reach:

```dart
// Per container — overrides any enclosing scope.
AclBuilder().setAclDirection(AclDirection.rtl).append(field).build();

// For a whole subtree — the usual choice, placed near the app root.
AclDirectionScope(
  direction: AclDirection.rtl,
  child: someLayout,
);
```

A container resolves its direction in this order: its own explicit
`direction`, then the nearest [`AclDirectionScope`] ancestor, then
`AclDirection.ltr`. Set the container's own value only when it must oppose its
surroundings; otherwise put a scope above the tree so nested containers agree
without each restating it.

Under `rtl`:

1. **Component order within a row** reverses — the first appended component
   renders on the right.
2. **Row alignment flips**: `RowAlignment.left` packs from the right edge and
   `RowAlignment.right` from the left.
3. **Horizontal offsets are negated**, so `alignX*` cross-row references keep
   pointing at the correct visual position.
4. **Padding** swaps its `left` and `right` sides.
5. **The [title](#container-titles) position mirrors** — `topLeft` renders at
   the right and vice versa; `topCenter` is unaffected.

One thing deliberately does **not** flip: `AclBorderKind.left` and
`AclBorderKind.right` are *physical* sides. A border asked for on the left
stays on the left in both directions, because the author choosing a single-side
border is choosing a visual edge. Use `horizontal` or `vertical` when the
intent is symmetric.

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

Two mechanisms can make an element disappear, and they are not variants of one
another: they read different inputs, run at different times, and leave
different gaps behind. Which one applies depends on how the element was
authored, not on a setting you choose between.

### The hide-unauthorized pass — driven by the child's own state

`setAclDefaultHideUnauthorized()` makes the container drop components whose
child implements `TomAuthorizable` and reports `effectiveAuthState ==
TomAuthState.none`; an individual component opts out with a per-component
`setHideUnauthorized(false)`. A child that is not `TomAuthorizable` is never
touched by this pass, whatever the flag says.

It runs **before layout** and rebuilds the row list, so it is the only one of
the two that can move a gap:

- a dropped component's own `gapBefore` is carried onto the next survivor, and
  that survivor's own `gapBefore` is discarded;
- a row whose components are all dropped is elided the same way — its own
  `gapBefore` travels to the next content row, whose own `gapBefore` is
  discarded.

The next visible element therefore lands exactly where the dropped one
started. `test/advanced_container_layout/acl_hide_unauthorized_test.dart`
covers the chains and the mixed cases.

### The policy gates — driven by the element's resolved path

Rows and components carrying an `id` are resolved by path through
`TomAuthorization.resolveAuth(...)` as the container builds. These gates are
**not** governed by `hideUnauthorized` — that flag names the pass above — and
they fire for any child, `TomAuthorizable` or not.

They run too late to rebuild a row, so they can only skip a widget. A denied
component and a denied row consequently reclaim different things:

| Denied element | Reclaimed | Left behind |
| -------------- | --------- | ----------- |
| **Component** | Its width only — the child becomes a `SizedBox.shrink()`. | **Both** neighbouring gaps. Its own `gapBefore` has already been emitted when the gate fires, and the next component emits its own as usual, so the two end up adjacent. |
| **Row** | The row's height **and its own `gapBefore`** — the gate returns before the gap is emitted. | The next row's own `gapBefore`. |

The arithmetic is thus the mirror image of the pass above: there, the removed
element's gap survives and its neighbour's is dropped; here, a removed
component keeps both and a removed row keeps neither of its own.

What neither mechanism does is reserve space. Nothing is left in place — no
placeholder, no empty box of the element's size — so a layout that must not
reflow when a grant changes cannot be built on either of them.
`test/advanced_container_layout/acl_auth_visibility_test.dart` measures all
four cases against one fixture.

### What the container does with each state

| State | What the container does |
| ----- | ----------------------- |
| `none` | Removed, by whichever of the two mechanisms applies — see above. |
| `disabled` | **Nothing. It renders exactly as `full`** — full opacity, input live. |
| `read` | Wrapped in `TomThemeScope.readonlyStyleOf(context).apply(child)` — by default `AbsorbPointer` + `Opacity(0.6)`: the value stays readable, dimmed, and inert. Applies at both levels — a `read` row styles all its components, a `read` component styles itself. Geometry is untouched. |
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

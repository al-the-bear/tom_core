# Tom Flutter UI API Reference: Advanced Container Layout Module

The row-based layout engine: a fluent builder that accumulates rows and
components, and the widgets that render the result.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Exported Surface](#exported-surface)
- [The builder](#the-builder)
  - [AclBuilder](#aclbuilder)
  - [AclBuilderSizing](#aclbuildersizing)
  - [AclBuilderAlignment](#aclbuilderalignment)
  - [AclBuilderChrome](#aclbuilderchrome)
  - [AclBuilderIdentity](#aclbuilderidentity)
  - [AclBuilderResponsive](#aclbuilderresponsive)
- [The layout model](#the-layout-model)
  - [AclComponent](#aclcomponent)
  - [AclRow](#aclrow)
  - [AclFlags](#aclflags)
- [The rendered widgets](#the-rendered-widgets)
  - [Acl](#acl)
  - [AclLayout](#acllayout)
  - [AclContainer](#aclcontainer)
  - [AclFlowContainer](#aclflowcontainer)
- [Global Functions and Constants](#global-functions-and-constants)
- [Appearance](#appearance)
  - [AclBorderStyle](#aclborderstyle)
  - [AclBorderKind](#aclborderkind)
  - [AclSeparator](#aclseparator)
  - [AclSeparatorStyle](#aclseparatorstyle)
  - [AclSeparatorAlignment](#aclseparatoralignment)
  - [AclTitlePosition](#acltitleposition)
  - [AclTitleBorderAlign](#acltitleborderalign)
- [Placement](#placement)
  - [AclRowAlignment](#aclrowalignment)
  - [AclRowCrossAlignment](#aclrowcrossalignment)
  - [AclAxisPointX](#aclaxispointx)
  - [AclAxisPointY](#aclaxispointy)
  - [AclDirection](#acldirection)
  - [AclDirectionScope](#acldirectionscope)
- [Responsive behaviour](#responsive-behaviour)
  - [AclVariant](#aclvariant)
  - [AclRowBreakpoint](#aclrowbreakpoint)
  - [AclVariantDetector](#aclvariantdetector)
  - [AclDeviceContext](#acldevicecontext)
  - [AclFormFactor](#aclformfactor)
  - [AclInputMode](#aclinputmode)
  - [AclDensity](#acldensity)
  - [AclFlowKind](#aclflowkind)
- [Groups and identity](#groups-and-identity)
  - [AclGroupVisibilityMode](#aclgroupvisibilitymode)
  - [AclGroupVisibilityController](#aclgroupvisibilitycontroller)
  - [AclBinaryVisibilityController](#aclbinaryvisibilitycontroller)
  - [AclCallbackVisibilityController\<T\>](#aclcallbackvisibilitycontrollert)
  - [AclScope](#aclscope)

## Overview

Source: `lib/src/advanced_container_layout/`, barrelled by
`advanced_container_layout.dart`. The container is one library split across
twelve files; the barrel names it once and the parts come with it, so the
surface below is unaffected by where a declaration sits.

The unit has three layers, and which one you touch depends on what you are
doing:

| Layer | Types | When |
| ----- | ----- | ---- |
| **Author** a layout | `AclBuilder` and its method-family extensions | Almost always. The builder is the only type most callers name. |
| **Describe** one | `AclRow`, `AclComponent`, `AclFlags`, plus the appearance and placement values | When a layout is generated, transformed, or asserted on without rendering. |
| **Render** one | `Acl`, `AclLayout`, `AclContainer`, `AclFlowContainer` | When `build()`'s result is not enough — an unwrapped variant, or a flat child list whose row breaks the container decides. |

The middle layer is immutable data with `copyWith`, which is what lets a layout
be inspected in a unit test: the geometry rules are decided from `AclRow` and
`AclComponent` alone, before any widget exists.

Two prose documents cover the unit and answer different questions.
`doc/advanced_container_layout.md` is the module reference — the API in
isolation, which is what you want while writing a layout.
`doc/acl_design_specification.md` is the design specification — why the engine
is shaped this way, and the cross-cutting rules (sizing resolution, variant
precedence, authorization) the reference assumes. This file is the symbol-level
mirror of the surface both describe.

## Class Hierarchy

```
Object
├── AclBuilder                                (fluent; its method families are extensions)
├── AclComponent                              (immutable cell)
├── AclRow                                    (immutable row)
├── AclFlags                                  (bit constants; not instantiable)
├── AclBorderStyle
├── AclSeparator
├── AclVariant
├── AclRowBreakpoint
├── AclDeviceContext
└── AclGroupVisibilityController              (abstract)
    ├── AclBinaryVisibilityController
    └── AclCallbackVisibilityController<T>

Widget
├── StatelessWidget
│   ├── AclLayout                             (rows, borders, scrolling, variants)
│   │   └── Acl                               (adds the title band)
│   └── AclFlowContainer                      (generates its own rows)
├── StatefulWidget
│   └── AclContainer                          (the render stage beneath AclLayout)
└── InheritedWidget
    ├── AclScope                              (id / group metadata for a subtree)
    └── AclDirectionScope                     (ltr / rtl for a subtree)

(enums)
AclBorderKind, AclSeparatorStyle, AclSeparatorAlignment, AclTitlePosition,
AclTitleBorderAlign, AclRowAlignment, AclRowCrossAlignment, AclAxisPointX,
AclAxisPointY, AclDirection, AclFlowKind, AclFormFactor, AclInputMode,
AclDensity, AclGroupVisibilityMode

(typedef)
AclVariantDetector = bool Function(AclDeviceContext, Acl?, BuildContext)
```

`build()` returns an `Acl`, so the title band is always available; `AclLayout`
is the same layout without one.

## Exported Surface

`advanced_container_layout.dart` exports nine files and every public
declaration in them:

| File | Public declarations |
| ---- | ------------------- |
| `acl_builder.dart` (and its parts) | `AclBuilder`, `AclBuilderSizing`, `AclBuilderAlignment`, `AclBuilderChrome`, `AclBuilderIdentity`, `AclBuilderResponsive` |
| `acl_container.dart` and its eleven `part` files | `Acl`, `AclLayout`, `AclContainer`, `AclRow`, `AclComponent`, `AclBorderStyle`, `AclBorderKind`, `AclSeparator`, `AclSeparatorStyle`, `AclSeparatorAlignment`, `AclTitlePosition`, `AclTitleBorderAlign`, `AclRowCrossAlignment`, `AclAxisPointX`, `AclAxisPointY`, `AclDirection`, `AclDirectionScope`, `aclResolveBreakpointed`, `aclEffectiveGapBefore`, `aclResolveRowHeight` |
| `acl_device_context.dart` | `AclDeviceContext`, `AclFormFactor`, `AclInputMode`, `AclDensity`, `AclVariantDetector` |
| `acl_flags.dart` | `AclFlags` |
| `acl_flow.dart` | `AclFlowContainer`, `AclFlowKind`, `aclWrapRows`, `aclGridRows`, `aclFlowItemWidth`, `kAclDefaultFlowItemWidth` |
| `acl_group_visibility.dart` | `AclGroupVisibilityMode`, `AclGroupVisibilityController`, `AclBinaryVisibilityController`, `AclCallbackVisibilityController` |
| `acl_responsive.dart` | `AclVariant`, `AclRowBreakpoint` |
| `acl_scope.dart` | `AclScope` |
| `row_alignment.dart` | `AclRowAlignment` |

Thirty-five public types, six top-level functions and constants, and fourteen
public static members — `AclBuilder.defaultPreferredWidth`, the seven
`AclFlags` bits, `AclDeviceContext.resolveInputMode` / `resolveFormFactor` /
`resolveDensity` / `buildConvenienceDetector`, `AclScope.of` and
`AclDirectionScope.maybeOf`.

## The builder

### AclBuilder

The fluent builder. Every method except `build()` returns `this`, so a whole
layout is one expression.

**Kind:** `class`

#### Constructors

```dart
AclBuilder({
  String? title,
  Widget? titleWidget,
  AclBorderStyle borderStyle = const AclBorderStyle.none(),
  AclBorderStyle? focusedBorderStyle,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  Color? backgroundColor,
  TextStyle? titleStyle,
  AclTitlePosition titlePosition = AclTitlePosition.topLeft,
  AclTitleBorderAlign titleBorderAlign = AclTitleBorderAlign.bottom,
  double titleVerticalOffset = 0.0,
})
```

Every constructor argument has a `setAcl…` setter equivalent; the constructor
is there so a container's chrome can be stated before its contents.

#### Static members

| Member | Type | Description |
|--------|------|-------------|
| `defaultPreferredWidth` | `static const double` | `150`. The width a component gets when it declares none — a **floor**, not a cap: content that needs more is measured and the component widened. |

Signatures are **not** repeated here. §17 of
[`acl_design_specification.md`](../acl_design_specification.md) is the complete
signature list, and `test/advanced_container_layout/acl_spec_api_test.dart`
holds it against the source on every run — a second hand-written copy would be
a second thing to keep right, and the one nobody checks is the one a reader
would follow.

#### Structure

| Method | Description |
|--------|-------------|
| `append` | Adds a component to the current row and makes it *current*. `dist` overrides the row's default gap before it. Refuses a widget instance the builder already holds — a `Flexible`, `Expanded` or `Spacer` is unwrapped for that comparison, since those three carry no key of their own. |
| `gap` | Inserts an elastic slot. The child is never built; `weight` is its share of the surplus. Clears the current component. |
| `newRow` | Starts a row. Clears the current component. |
| `gapRow` | Starts an elastic *row*, optionally drawing a separator in it. |
| `build` | Pure construction: maps the accumulated data into an `Acl`. Renders nothing. |

#### Sizing the current component

| Method | Description |
|--------|-------------|
| `setPSize` | Preferred size. |
| `setMSize` | Minimum size. |
| `setXSize` | Maximum size. |
| `setPWidthInChars` | Preferred width as a character count, height preserved. |
| `setMWidthInChars` | Minimum width as a character count. |
| `setXWidthInChars` | Maximum width as a character count. |
| `setAttr` / `clearAttr` | Set or clear `AclFlags` bits. |

Each of these — and every other per-component method below — throws a
`StateError` naming the setter when there is no current component: before the
first `append`, or after `gap`, `newRow` or `gapRow`, each of which clears it.

#### Size references

| Method | Description |
|--------|-------------|
| `setComp` | The shared primitive. `otherAttr` must carry `AclFlags.otherDimX`, `otherDimY` or `otherDim`; only those bits are taken, so an argument without them is an `ArgumentError`. |
| `sameWidthAs` | Adopt the reference's rendered width. |
| `sameHeightAs` | Adopt its rendered height. |
| `sameSize` | Both. |

The reference is the widget instance handed to an earlier `append`, and must be
in a **different row**. A widget the builder has no component for — never
appended, appended later, or a flex wrapper that carries no key — is refused
where the reference is written.

#### Alignment anchors

Eighteen methods, each taking the reference widget and an optional gap, named
*my point* → *reference's point*:

| Axis | Methods | Row rule |
|------|---------|----------|
| Horizontal | `alignLeftToLeft`, `alignLeftToCenter`, `alignLeftToRight`, `alignCenterToLeft`, `alignCenterToCenter`, `alignCenterToRight`, `alignRightToLeft`, `alignRightToCenter`, `alignRightToRight` | reference in a **different** row |
| Vertical | `alignTopToTop`, `alignTopToMiddle`, `alignTopToBottom`, `alignMiddleToTop`, `alignMiddleToMiddle`, `alignMiddleToBottom`, `alignBottomToTop`, `alignBottomToMiddle`, `alignBottomToBottom` | reference in the **same** row |

`setVerticalAlignment` overrides the row's cross alignment for the current
component, and cannot be combined with an `alignY*` method on the same
component.

#### Container chrome

| Method | Description |
|--------|-------------|
| `setAclPSize` / `setAclMSize` / `setAclXSize` | Preferred / minimum / maximum size of the container. |
| `setAclScrollableX` / `setAclScrollableY` | Scroll on that axis instead of fitting. |
| `setAclBorderStyle` / `setAclFocusedBorderStyle` / `setAclBorderInsets` | Border, focused border, and the inset between border and content. |
| `setAclPadding` / `setAclPaddingPx` / `setAclPaddingTop` / `setAclPaddingBottom` / `setAclPaddingLeft` / `setAclPaddingRight` | Padding, whole or per side. |
| `setAclBackgroundColor` | Background fill. |
| `setAclTitle` / `setAclTitleWidget` / `setAclTitleStyle` / `setAclTitlePosition` / `setAclTitleBorderAlign` / `setAclTitleVerticalOffset` | The title band. |
| `setAclDirection` | Force `ltr` / `rtl` for this container instead of inheriting. |

#### Builder-wide defaults

| Method | Description |
|--------|-------------|
| `setAclDefaultFlags` / `defaultFlags` | Flags every later `append` starts from. |
| `setAclExpandXDefault` | Shortcut over `setAclDefaultFlags` for `expandX`. |
| `setAclDefaultAppendGap` | Gap before each appended component; 8 px unless changed, with optional width breakpoints. |
| `setAclDefaultRowGap` | Gap above each `newRow`. |
| `setAclDefaultRowHeight` / `setRowHeight` | Fixed row height, for all rows or the current one. |
| `setAclDefaultUnknownMinimumSize` / `setAclDefaultUnknownPreferredSize` | What a component with no size hint gets. |
| `setAclDefaultRowVerticalAlignment` / `setAclDefaultRowHorizontalAlignment` | Default alignments. Both apply **retroactively** to rows already started. |
| `setAclDefaultHideUnauthorized` / `setHideUnauthorized` | Whether a withheld component is hidden or shown inert — container-wide, then per component. |

`setRowHorizontalAlignment` and `setRowVerticalAlignment` set the current row's.

#### Identity, groups and visibility

| Method | Description |
|--------|-------------|
| `setAclId` / `setAclIdScope` | The container's id, and whether it opens a new id scope. |
| `setRowId` / `setRowIdScope` | The current row's. |
| `setId` | The current component's. |
| `setAclGroup` / `setRowGroup` / `group` | Group name at container, row and component level. |
| `startGroup` / `endGroup` | Tag every component appended between the two. |
| `setGroupVisibilityController` | Bind a group to a controller that shows, hides or disables it at runtime. |

#### Responsive

| Method | Description |
|--------|-------------|
| `addVariant build)` | A whole alternative row set below a width. The nested builder inherits this one's row defaults. |
| `addRowBreakpoint` | Split the current row here below a width. The split index is where the chain has got to — the number of components appended to this row so far — so the call goes *between* the two `append`s it separates. |
| `startVariant` / `endVariant` | Tag components as belonging to an inline variant selected by a detector. |

### AclBuilderSizing

The sizing family: the methods under [Sizing the current component](#sizing-the-current-component)
and [Size references](#size-references), the container size and scrolling
setters, and the growth shorthands. One part of the `acl_builder` library;
called on an `AclBuilder` like any member.

**Kind:** `extension on AclBuilder`

| Shorthand | Equivalent to |
|-----------|---------------|
| `expandX()` | `setAttr(AclFlags.expandX)` |
| `expandY()` | `setAttr(AclFlags.expandY)` |
| `expand()` | `setAttr(AclFlags.expand)` |

### AclBuilderAlignment

The alignment family: the methods under [Alignment anchors](#alignment-anchors),
the row-alignment setters and their shorthands.

**Kind:** `extension on AclBuilder`

| Shorthand | Equivalent to |
|-----------|---------------|
| `setRowAlignLeft()` / `setRowAlignCenter()` / `setRowAlignRight()` | `setRowHorizontalAlignment(AclRowAlignment.…)` |
| `setRowAlignTop()` / `setRowAlignMiddle()` / `setRowAlignBottom()` | `setRowVerticalAlignment(AclRowCrossAlignment.…)` |

### AclBuilderChrome

The container's defaults and chrome: the methods under
[Builder-wide defaults](#builder-wide-defaults) and the border, padding,
background and title setters under [Container chrome](#container-chrome).

**Kind:** `extension on AclBuilder`

### AclBuilderIdentity

Ids, groups and group visibility: the methods under
[Identity, groups and visibility](#identity-groups-and-visibility).

**Kind:** `extension on AclBuilder`

### AclBuilderResponsive

Variants, row breakpoints and inline variants: the methods under
[Responsive](#responsive).

**Kind:** `extension on AclBuilder`

## The layout model

### AclComponent

One cell of the computed grid: a child plus every hint the geometry pass reads.
Immutable.

**Kind:** `class`

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `child` | `Widget` | What is rendered. A gap's child is never built. |
| `flags` | `int` | `AclFlags` bits. |
| `gapBefore` | `double` | Pixels of gap before this component. |
| `gapBeforeIsDefault` | `bool` | Whether `gapBefore` came from the row's default, so the container can resolve it against the current width instead of a baked-in number. |
| `gapWeight` | `double` | A gap slot's share of the row surplus. |
| `preferredSize` | `Size?` | Declared preferred size. |
| `preferredWidthIsDefault` | `bool` | Whether the preferred *width* was invented by the builder. Those components are measured and widened rather than capped. |
| `minimumSize` / `maximumSize` | `Size?` | Declared bounds. |
| `referenceKey` | `Key?` | The component whose dimension this one borrows, with `useOtherDimX` / `useOtherDimY`. |
| `alignXToKey`, `alignXFrom`, `alignXTo`, `alignXGap` | `Key?`, `AclAxisPointX?`, `AclAxisPointX?`, `double` | Cross-row horizontal anchor. |
| `alignYToKey`, `alignYFrom`, `alignYTo`, `alignYGap` | `Key?`, `AclAxisPointY?`, `AclAxisPointY?`, `double` | Same-row vertical anchor. |
| `rowCrossAlignment` | `AclRowCrossAlignment` | Where the component sits across the row's height. |
| `componentKey` | `Key?` | The key the builder assigned; what a reference resolves to. Null for a widget the row lays out itself. |
| `id` | `String?` | Component id, the last segment of its authorization path. |
| `group` | `String?` | Group name, for show / hide / disable. |
| `inlineVariant` | `bool` | Whether this component belongs to an inline variant. |
| `variantDetector` | `AclVariantDetector?` | The detector that selects it when it does. |
| `hideUnauthorized` | `bool?` | Per-component override of the container default. |

#### Getters

| Getter | Reads |
|--------|-------|
| `expandX` / `expandY` | `AclFlags.expandX` / `expandY` |
| `isGap` | `AclFlags.gapElement` |
| `useOtherDimX` / `useOtherDimY` | `AclFlags.otherDimX` / `otherDimY` |

#### Methods

| Method | Description |
|--------|-------------|
| `copyWith({…})` | Every field. What a transformation pass uses; the field count is held to the constructor's by a test. |
| `copyWithGapBefore(double gapBefore)` | The one field a row-splitting pass changes on its own. |

### AclRow

One row of the computed grid. Immutable.

**Kind:** `class`

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `components` | `List<AclComponent>` | Its cells, in order. |
| `alignment` | `AclRowAlignment` | How the row justifies its contents when there is surplus and no gap slot. |
| `gapBefore` | `double` | Pixels above this row. |
| `isGapRow` | `bool` | Whether the row is elastic vertical space rather than content. |
| `gapRowWeight` | `double` | Its share of the vertical surplus. |
| `gapRowMinSize` | `double` | The floor under that share. |
| `separator` | `AclSeparator?` | A rule drawn inside a gap row. |
| `id` | `String?` | Row id, a segment of the authorization path. |
| `group` | `String?` | Group name. |
| `idScope` | `bool` | Whether the row opens a new id scope. |
| `breakpoints` | `List<AclRowBreakpoint>` | Width rules that split this row. |
| `height` | `double?` | Fixed height, if declared. |
| `heightBpOverrides` | `List<(double, double?)>` | Width-keyed overrides of it. |
| `defaultAppendGap` | `double` | The gap a `gapBeforeIsDefault` component resolves to. |
| `defaultAppendGapBpOverrides` | `List<(double, double)>` | Width-keyed overrides of that. |
| `defaultRowCrossAlignment` | `AclRowCrossAlignment` | The row's cross alignment. |

#### Methods

| Method | Description |
|--------|-------------|
| `copyWith({…})` | Every field. Both rebuild passes route through it, so a field added to the row cannot be dropped by one of them. |

### AclFlags

Growth and role bits, mirroring the Java AWT constants the model came from.
Not instantiable.

**Kind:** `class` (private constructor)

| Constant | Bit | Meaning | Set with | Read with |
|----------|-----|---------|----------|-----------|
| `expandX` | 1 | Claim the row's surplus width, exclusively. | `expandX()` | `AclComponent.expandX` |
| `expandY` | 2 | Fill the row's height. | `expandY()` | `AclComponent.expandY` |
| `gapElement` | 4 | This cell is elastic space; its child is never built. | `gap()` | `AclComponent.isGap` |
| `otherDimX` | 32 | Take the X dimension from `referenceKey`. | `sameWidthAs()` | `AclComponent.useOtherDimX` |
| `otherDimY` | 64 | Take the Y dimension from `referenceKey`. | `sameHeightAs()` | `AclComponent.useOtherDimY` |
| `expand` | 3 | `expandX \| expandY`. | `expand()` | — |
| `otherDim` | 96 | `otherDimX \| otherDimY`. | `sameSize()` | — |

8 and 16 are unassigned: the values are sparse because they mirror the
constants the Java `AdvancedContainerLike` used. Every bit here is one the
container reads, which a contract test derives from this class and asserts.

## The rendered widgets

### Acl

What `build()` returns: an `AclLayout` with a title band.

**Kind:** `class extends AclLayout`

#### Constructors

```dart
const Acl({
  super.key,
  required super.rows,
  super.borderStyle = const AclBorderStyle.none(),
  super.focusedBorderStyle,
  super.padding = EdgeInsets.zero,
  super.backgroundColor,
  super.scrollableX = false,
  super.scrollableY = false,
  super.preferredContainerSize,
  super.minimumContainerSize,
  super.maximumContainerSize,
  super.aclId,
  super.idScope = false,
  super.aclGroup,
  super.groupVisibilityControllers = const {},
  super.variants = const [],
  super.direction,
  super.defaultHideUnauthorized = false,
  String? title,
  Widget? titleWidget,
  TextStyle? titleStyle,
  AclTitlePosition titlePosition = AclTitlePosition.topLeft,
  AclTitleBorderAlign titleBorderAlign = AclTitleBorderAlign.bottom,
  double titleVerticalOffset = 0.0,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String?` | Title text. |
| `titleWidget` | `Widget?` | Used instead of `title` when given. |
| `titleStyle` | `TextStyle?` | Style for `title`. |
| `titlePosition` | `AclTitlePosition` | Which end of the top edge the title sits at. Mirrored under `rtl`. |
| `titleBorderAlign` | `AclTitleBorderAlign` | Where the border passes relative to the title. |
| `titleVerticalOffset` | `double` | Nudge, for fonts whose metrics do not sit where the border expects. |

### AclLayout

The same layout without a title: rows, borders, background, scrolling, size
constraints, variants, groups and direction.

**Kind:** `class extends StatelessWidget`

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `rows` | `List<AclRow>` | The layout. |
| `borderStyle` | `AclBorderStyle` | The border. |
| `focusedBorderStyle` | `AclBorderStyle?` | Swapped in while focus is inside. |
| `padding` | `EdgeInsetsGeometry` | Inside the border. |
| `backgroundColor` | `Color?` | Fill. |
| `scrollableX` / `scrollableY` | `bool` | Scroll instead of fitting on that axis. |
| `preferredContainerSize` / `minimumContainerSize` / `maximumContainerSize` | `Size?` | Container-level size constraints. |
| `aclId` | `String?` | Container id — the root segment of every authorization path below it. |
| `idScope` | `bool` | Whether `aclId` opens a new scope rather than extending the enclosing one. |
| `aclGroup` | `String?` | Container-level group name: the default for every row and component that names no group of its own (component, else row, else container). |
| `groupVisibilityControllers` | `Map<String, AclGroupVisibilityController>` | Group name → controller. |
| `variants` | `List<AclVariant>` | Whole alternative row sets, selected by width. |
| `direction` | `AclDirection?` | Forced direction; inherits from `AclDirectionScope` or the ambient `TextDirection` when null. |
| `defaultHideUnauthorized` | `bool` | Whether a withheld component is hidden rather than shown inert. |

### AclContainer

The render stage beneath `AclLayout`: it runs the pre-calculation loop, resolves
variants and breakpoints, applies authorization and group visibility, and emits
the rows. Stateful because it caches measured natural sizes between frames.

**Kind:** `class extends StatefulWidget`

Its properties are `AclLayout`'s, which constructs one. Reach for it directly
only when the layout is assembled without the builder.

### AclFlowContainer

A container that **generates** its rows from a flat component list, rather than
being told them.

**Kind:** `class extends StatelessWidget`

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `kind` | `AclFlowKind` | `wrap` (break when the next item does not fit) or `grid` (fixed column count). |
| `components` | `List<AclComponent>` | The flat list. |
| `columns` | `int` | Columns, for `grid`. |
| `columnsBpOverrides` | `List<(double, int)>` | Width-keyed column counts. |
| `gutterWidth` | `double` | Horizontal space between items. |
| `runSpacing` | `double` | Vertical space between generated rows. |
| `defaultItemWidth` | `double` | Width assumed for an item that declares none. Defaults to `kAclDefaultFlowItemWidth`. |
| `alignment` | `AclRowAlignment` | Justification of each generated row. |
| `aclId` / `idScope` / `aclGroup` | `String?` / `bool` / `String?` | As on `AclLayout`. |
| `padding` / `borderStyle` / `backgroundColor` / `scrollableY` | | As on `AclLayout`. |

#### Methods

| Method | Description |
|--------|-------------|
| `buildRows(double? availableWidth)` | The rows this container would generate at that width. `null` means unbounded, and each kind answers it: `wrap` never breaks, `grid` gives its cells no width rather than dividing infinity. |

## Global Functions and Constants

| Declaration | Description |
|-------------|-------------|
| `const double kAclDefaultFlowItemWidth` | `150.0`. The width a flow item with no hint is assumed to take. |
| `double aclFlowItemWidth(AclComponent comp, double defaultItemWidth)` | That item's width: preferred, else minimum, else the default. |
| `List<AclRow> aclWrapRows(List<AclComponent> components, {required double availableWidth, double gutterWidth = 8.0, double runSpacing = 8.0, double defaultItemWidth = kAclDefaultFlowItemWidth, AclRowAlignment alignment = AclRowAlignment.left, String? rowIdPrefix})` | Break the list into rows that fit the width. |
| `List<AclRow> aclGridRows(List<AclComponent> components, {required int columns, double? availableWidth, double gutterWidth = 8.0, double runSpacing = 8.0, AclRowAlignment alignment = AclRowAlignment.left, String? rowIdPrefix})` | Break it into fixed-width columns. A null or infinite width gives the cells no width instead of an absurd one. |
| `T aclResolveBreakpointed<T>(T base, List<(double, T)> overrides, double? availableWidth)` | The value in force at a width: the override with the greatest `minWidth` at or below it, else `base`. The one breakpoint rule the row height, the append gap and the flow column count all use. |
| `double aclEffectiveGapBefore(AclComponent comp, AclRow row, double? availableWidth)` | The gap before a component: its own when declared, otherwise the row's default resolved at this width. |
| `double? aclResolveRowHeight(AclRow row, double? availableWidth)` | The row's height at this width, breakpoints applied. |

## Appearance

### AclBorderStyle

How a container's border is drawn.

**Kind:** `class`

#### Constructors

```dart
const AclBorderStyle({
  AclBorderKind kind = AclBorderKind.none,
  Color color = const Color(0xFF9E9E9E),
  double lineWidth = 1.0,
  bool rounded = false,
  double borderRadius = 8.0,
  EdgeInsetsGeometry borderInsets = EdgeInsets.zero,
})
const AclBorderStyle.none()
const AclBorderStyle.solid({Color color, double lineWidth, bool rounded, double borderRadius, EdgeInsetsGeometry borderInsets})
```

#### Properties and methods

| Member | Type | Description |
|--------|------|-------------|
| `kind` | `AclBorderKind` | Which sides are drawn. |
| `color` | `Color` | Line colour. |
| `lineWidth` | `double` | Line thickness. |
| `rounded` | `bool` | Whether corners are rounded. |
| `borderRadius` | `double` | The radius when they are. |
| `borderInsets` | `EdgeInsetsGeometry` | Space between the border and the content. |
| `enabled` | `bool` (getter) | `kind != AclBorderKind.none`. |
| `copyWith({…})` | `AclBorderStyle` | Every field. |

### AclBorderKind

Which sides of the border are drawn.

**Kind:** `enum`

`none`, `solid`, `solidDouble`, `top`, `bottom`, `left`, `right`, `horizontal`,
`vertical`.

Shadows and 3D bevels are deliberately absent — those belong to the theme
layer, not the layout container.

### AclSeparator

A rule drawn inside a gap row.

**Kind:** `class`

```dart
const AclSeparator({
  AclSeparatorStyle style = AclSeparatorStyle.single,
  Color? color,
  double lineWidth = 1.0,
  AclSeparatorAlignment alignment = AclSeparatorAlignment.middle,
})
```

| Property | Type | Description |
|----------|------|-------------|
| `style` | `AclSeparatorStyle` | One line or two. |
| `color` | `Color?` | Null takes the theme's divider colour. |
| `lineWidth` | `double` | Thickness. |
| `alignment` | `AclSeparatorAlignment` | Where in the gap the rule sits. |

### AclSeparatorStyle

**Kind:** `enum` — `single`, `doubleLine`.

### AclSeparatorAlignment

**Kind:** `enum` — `top`, `middle`, `bottom`. Where in the gap row's height the
rule is drawn.

### AclTitlePosition

**Kind:** `enum` — `topLeft`, `topCenter`, `topRight`. Mirrored under `rtl`, so
a `topLeft` title sits at the trailing edge in a right-to-left layout.

### AclTitleBorderAlign

**Kind:** `enum` — `top`, `middle`, `bottom`. Where the border passes relative
to the title band: above it, through it, or below it.

## Placement

### AclRowAlignment

How a row justifies its contents when it has surplus width and no gap slot to
absorb it.

**Kind:** `enum` — `left`, `center`, `right`.

### AclRowCrossAlignment

Where a component sits across its row's height.

**Kind:** `enum` — `top`, `center`, `bottom`.

### AclAxisPointX

The horizontal anchor point an `alignX*` method names.

**Kind:** `enum` — `left`, `center`, `right`.

### AclAxisPointY

The vertical anchor point an `alignY*` method names.

**Kind:** `enum` — `top`, `center`, `bottom`.

### AclDirection

**Kind:** `enum` — `ltr`, `rtl`.

### AclDirectionScope

Publishes an `AclDirection` to the subtree below it, so nested containers
inherit a forced direction instead of each declaring one.

**Kind:** `class extends InheritedWidget`

```dart
const AclDirectionScope({Key? key, required AclDirection direction, required Widget child})
```

| Member | Description |
|--------|-------------|
| `direction` | The direction in force below this widget. |
| `static AclDirection? maybeOf(BuildContext context)` | The nearest enclosing direction, or null. A container with no `direction` of its own falls back to this, then to the ambient `TextDirection`. |

## Responsive behaviour

### AclVariant

A whole alternative row set, selected below a width.

**Kind:** `class`

```dart
const AclVariant({required String name, required double atWidth, required List<AclRow> rows})
```

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Identifies the variant; what a test asserts on. |
| `atWidth` | `double` | The width at or below which it applies. The narrowest matching variant wins. |
| `rows` | `List<AclRow>` | The replacement layout. |

### AclRowBreakpoint

A rule that splits **one row** below a width, rather than replacing the layout.

**Kind:** `class`

```dart
const AclRowBreakpoint({required double atWidth, required int splitAfter, double splitRowDist = 0})
```

| Property | Type | Description |
|----------|------|-------------|
| `atWidth` | `double` | The width at or below which the split applies. |
| `splitAfter` | `int` | Break the row after this many components. |
| `splitRowDist` | `double` | The gap above the row the break creates. |

### AclVariantDetector

**Kind:** `typedef` — `bool Function(AclDeviceContext deviceContext, Acl? acl, BuildContext context)`.

The predicate an inline variant is selected by. It sees the whole device
context, so a variant can turn on a platform, an input mode or an
accessibility scale rather than only on width.

### AclDeviceContext

Everything a detector is allowed to decide from, gathered once per layout pass.

**Kind:** `class`

```dart
const AclDeviceContext({
  required double width,
  double? height,
  required AclInputMode inputMode,
  required AclFormFactor formFactor,
  required Orientation orientation,
  required TargetPlatform platform,
  required bool isWeb,
  required AclDensity density,
  required TextDirection textDirection,
  required double accessibilityScale,
})
factory AclDeviceContext.of(BuildContext context, {required double width, double? height})
```

| Property | Type | Description |
|----------|------|-------------|
| `width` | `double` | The width the layout is being resolved at. |
| `height` | `double?` | Its height, when bounded. |
| `inputMode` | `AclInputMode` | Touch or pointer. |
| `formFactor` | `AclFormFactor` | Phone, tablet or desktop. |
| `orientation` | `Orientation` | Portrait or landscape. |
| `platform` | `TargetPlatform` | The host platform. |
| `isWeb` | `bool` | Whether this is a web build. |
| `density` | `AclDensity` | Resolved from the theme's `VisualDensity`. |
| `textDirection` | `TextDirection` | The ambient direction. |
| `accessibilityScale` | `double` | The ambient text scale. |

#### Static methods

| Method | Description |
|--------|-------------|
| `resolveInputMode(TargetPlatform platform)` | Touch for mobile platforms, pointer otherwise. |
| `resolveFormFactor(double width)` | The form factor a width falls in. |
| `resolveDensity(VisualDensity visualDensity)` | The density a `VisualDensity` maps to. |
| `buildConvenienceDetector({double? width, double? height, AclInputMode? input, AclFormFactor? formFactor, Orientation? orientation, Set<TargetPlatform>? platforms, bool? isWeb, AclDensity? density, TextDirection? textDirection, double? minAccessibilityScale})` | Composes the conditions given into one `AclVariantDetector`, so the common cases need no closure. Returns null when no condition was given — a detector that accepts everything is a variant that is always on, which is not what an empty call means. |

### AclFormFactor

**Kind:** `enum` — `phone`, `tablet`, `desktop`.

### AclInputMode

**Kind:** `enum` — `touch`, `pointer`.

### AclDensity

**Kind:** `enum` — `compact`, `comfortable`, `standard`.

### AclFlowKind

How an `AclFlowContainer` turns a flat list into rows.

**Kind:** `enum`

| Value | Meaning |
|-------|---------|
| `wrap` | Break when the next item would not fit the available width. |
| `grid` | A fixed number of columns, each cell an equal share of the width. |

## Groups and identity

### AclGroupVisibilityMode

**Kind:** `enum`

| Value | Meaning |
|-------|---------|
| `visible` | Rendered and interactive. |
| `hidden` | Not rendered, and its width reclaimed. |
| `disabled` | Rendered inert, folded with authorization into one effective state so a component is never shown two shades of "off". |

### AclGroupVisibilityController

The contract a group's runtime visibility is driven through.

**Kind:** `abstract class`

| Member | Type | Description |
|--------|------|-------------|
| `mode` | `AclGroupVisibilityMode` (getter) | The current mode. |
| `modeNotifier` | `ValueNotifier<AclGroupVisibilityMode>` (getter) | What the container subscribes to. |
| `dispose()` | `void` | Releases the notifier. The container unsubscribes; the owner disposes. |

### AclBinaryVisibilityController

A controller set directly.

**Kind:** `class extends AclGroupVisibilityController`

```dart
AclBinaryVisibilityController({AclGroupVisibilityMode initialMode = AclGroupVisibilityMode.visible})
```

Adds a settable `mode`; `modeNotifier` and `dispose` are the base contract.

### AclCallbackVisibilityController\<T\>

A controller derived from someone else's state.

**Kind:** `class extends AclGroupVisibilityController`

```dart
AclCallbackVisibilityController({
  required ValueListenable<T> valueListenable,
  required AclGroupVisibilityMode Function(T value) modeBuilder,
})
```

Listens to `valueListenable` and republishes `modeBuilder(value)`, so a group
follows an existing observable rather than a second copy of its state.
`dispose` detaches the listener as well as releasing the notifier.

### AclScope

Publishes a component's identity and group to its own subtree, so a widget
inside a layout can find out where it sits without being told.

**Kind:** `class extends InheritedWidget`

```dart
const AclScope({
  Key? key,
  required Widget child,
  String? containerId,
  String? componentId,
  String? rowId,
  String? groupName,
  String? fullIdPath,
})
```

| Member | Description |
|--------|-------------|
| `containerId` | The enclosing container's id. |
| `componentId` | This component's id. |
| `rowId` | Its row's id. |
| `groupName` | The group in force. |
| `fullIdPath` | The resolved authorization path — the key every policy and resource lookup uses. |
| `static AclScope? of(BuildContext context)` | The nearest enclosing scope, or null. |

A flex-native child — `Flexible`, `Expanded`, `Spacer` — is **not** wrapped in
one: those are `ParentDataWidget`s and must be the row's direct child.

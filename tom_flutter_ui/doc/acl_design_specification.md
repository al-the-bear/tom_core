# Advanced Container Layout (ACL) — Design Specification

*Part of the [Tom Flutter UI documentation set](README.md).*

**Package:** `tom_flutter_ui`  
**Class:** `Acl` (widget) / `AclBuilder` (fluent builder)  
**Last updated:** 2026-08-27

## What this document is, and what to read instead

ACL is documented at two levels, and this is the deeper one.

- **[advanced_container_layout.md](advanced_container_layout.md) — the module reference.** The public API of `lib/src/advanced_container_layout/` in isolation: what each type is, what each entry point does, and how to call it. Start there if you want to *use* ACL.
- **This document — the design specification.** *Why* the engine behaves as it does: the coordinate conventions, the three-step row-sizing algorithm, the convergence loop, the precedence rules between defaults, rows and components, and the reasoning behind each. Read it when the module reference tells you *what* happens and you need to know why, or when you are changing the engine rather than calling it.

The split is the package-wide convention — see [README.md](README.md), which registers every subsystem under both headings.

Two consequences worth stating up front, because both look like mistakes:

- **The section numbering has gaps at 19 and 22.** Those sections recorded superseded design and were deleted. They were not renumbered away, because nineteen `§NN` citations in `lib/` resolve by number, and renumbering would silently redirect every one of them. `test/advanced_container_layout/acl_shipped_text_test.dart` pins those citations, and pins this document's internal cross-references against its own headings.
- **§31 documents `TomAclBuilder`, which is not part of this module.** It lives in `widget_base/`, `forms/` and `widgets/containers/acl/`, and wraps ACL with element providers, authorization and resources. It is specified here rather than in the module reference precisely because it spans modules — which is what a design specification is for.

---

## 1. Philosophy and Goals

The Advanced Container Layout system replaces hand-rolled `Row`/`Column`/`Stack`/`Positioned` compositions with a single declarative layout container that:

- **Uses available screen space automatically and by default.** An `Acl` fills all available width and height in its parent unless explicit size constraints are set. No wrapping in `Expanded` or `SizedBox.expand` is required — that is the default.
- **Specifies screens once.** The same layout definition works at any screen size — phone, tablet, desktop — without writing breakpoint-specific widget trees. Breakpoint support will be added as an opt-in overlay, not as a replacement.
- **Expresses cross-component relationships directly.** "This button should align its left edge to the right edge of that label" is written once and enforced by the engine.
- **Settles iteratively — without Flutter paint.** When a component's size depends on a component in another row, the engine runs a pre-calculation loop in pure Dart until all sizes and positions stabilise. Flutter layout is performed once at the end with all sizes already fixed.

---

## 2. Conceptual Model

```
┌─────────────────────────────────────────────────────────────┐
│  Acl (container)                                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Row 0                                                │  │
│  │  [comp A] [gap]  [comp B] [comp C]                    │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌  gapRow (elastic vertical spacer)  ──────────────────  ┐  │
│  └─────────────────────────────────────────────────────── ┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Row 1                                                │  │
│  │  [comp D]    [comp E ─── alignLeftToRight(A) ──►]     │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

- **Rows** are horizontal strips stacked vertically in a `Column`.
- **Components** inside a row are laid out sequentially (left-to-right).
- **Gap slots** (`gap()`) are elastic horizontal spacers within a row.
- **Gap rows** (`gapRow()`) are elastic vertical spacers between content rows.
- **Cross-row constraints** (`alignXToKey`) translate a component horizontally so one of its X-edges aligns with an X-edge of a component in a **different** row.
- **Same-row constraints** (`alignYToKey`) translate a component vertically so one of its Y-edges aligns with a Y-edge of a sibling in the **same** row.
- **Size constraints** (`sameWidthAs`, `sameHeightAs`) force a component to adopt the rendered size of an earlier-declared component, dynamically.

---

## 3. Default Size Behaviour & Scrollable Mode

### Default: fill available space

An `Acl` with no explicit size constraints expands to fill all available width and height offered by its parent. `gap()` and `gapRow()` elements are elastic and consume remaining space as described in Sections 6 and 7. This is the behaviour that makes single-layout adaptive design possible — no `Expanded`, `SizedBox.expand`, or `LayoutBuilder` wrapping is needed in the typical case.

### Explicit Acl sizes

When explicit size constraints are set at the container level (via `setAclPSize`, `setAclMSize`, `setAclXSize`), the `Acl` respects those bounds and behaves like any sized widget in the Flutter tree. When embedded as a nested component inside another `Acl`, these sizes are used by the outer container's fitting algorithm exactly as for ordinary components.

### Scrollable mode

`setAclScrollableX()` and `setAclScrollableY()` switch the respective axis into scroll mode:

- The container no longer expands beyond its natural content size on the scrollable axis.
- Scrollbars appear when content exceeds available space.
- On a **scrollable axis**, elastic distribution stops, because it is meaningless when content can overflow. `gap()` slots (horizontal) receive **zero size**. `gapRow()` slots (vertical) fall back to their *fixed* size — `minSize`, which collapses the row at the default of 0, or `max(9, minSize)` when the row carries a separator, so a separator still draws.
- `expandX` components in a horizontally-scrollable row likewise receive no gap space; their size becomes their preferred/intrinsic size only.
- The two axes are independent.

```
Normal (fill):    [Label] ░░░ gap(elastic) ░░░ [Button]
Scrollable-X:     [Label][gap=0][Button]   ← scrolls right if content overflows
```

---

## 4. Coordinate & Axis Conventions

```
  X axis ──────────────────────────────►
  │
  │   ┌──────────────────────────────┐
  │   │  left    center    right     │  AclAxisPointX
  │   │                              │
  Y   │  top                         │  ─┐
  │   │  middle (center-Y)           │   │  AclAxisPointY
  ▼   │  bottom                      │  ─┘
      └──────────────────────────────┘
```

**Gap sign convention for alignment methods:**  
The `gap` parameter is **subtracted** from the target reference point before the delta is computed:
```
delta = (referenceEdge − gap) − selfEdge
```
- `gap > 0`: component shifts *toward* the reference edge (overlap or tighter placement).
- `gap < 0`: component shifts *away* from the reference edge (separation / whitespace).

**Common usage:** `alignLeftToRight(ref, gap: -8)` leaves 8 px of whitespace between the reference's right edge and this component's left edge. Positive gap values overlap the reference.

---

## 5. Size Concepts per Component

Each component can carry up to three sizes:

| Name | Builder method | Meaning |
|---|---|---|
| Preferred | `setPSize(w, h)` | Target size; layout aims for this |
| Minimum | `setMSize(w, h)` | Floor; never shrinks below this |
| Maximum | `setXSize(w, h)` | Ceiling; never grows above this |

**Default size semantics:**

- **Preferred not set, minimum not set:** the component renders at its natural Flutter intrinsic size — no floor or ceiling is applied.
- **Preferred set, minimum not set:** the preferred size doubles as the minimum. The component aims for `preferred` and cannot shrink below it. This prevents accidental squeezing of components that have a clear target size.
- **Maximum not set:** always unlimited (`double.infinity`). The component may grow as large as needed.

These same rules apply at the container level: `setAclPSize` acts as the container's preferred and implicit minimum; `setAclMSize` overrides the minimum; `setAclXSize` sets a ceiling.

`setPWidthInChars(n)`, `setMWidthInChars(n)`, `setXWidthInChars(n)` set the preferred, minimum, and maximum width in character units respectively (default `charWidth = 8`). They are shorthand for `setPSize(n * charWidth, height)`, `setMSize(n * charWidth, existingMH)`, and `setXSize(n * charWidth, existingXH)` respectively.

---

## 5b. Container-Level Component Defaults

The builder provides five `setAcl*` methods that establish defaults applied to every subsequently appended component that does **not** override them explicitly. These reduce boilerplate when many components share the same sizing or spacing profile.

### `setAclExpandXDefault(bool enabled)`

Adds or removes `AclFlags.expandX` in the default flags register. When `true`, every subsequent `append()` call automatically receives `expandX` — equivalent to calling `.expandX()` after each append. Individual components can still opt out via `clearAttr(AclFlags.expandX)`.

### `setAclDefaultAppendGap(double gap, [List<(double, double)> gapBpOverrides = const []])`

Sets a horizontal gap (in pixels) inserted before each appended component. This is a convenience for the common pattern of calling `.append(widget, dist: 16)` on every field. The default applies to **all** components in the row, including the first. The default only takes effect when the individual `append()` call specifies `dist: 0` (the default). An explicit `dist` always wins. The built-in gap is **8**; pass 0 to disable it.

`gapBpOverrides` makes that gap responsive: it is a list of `(minWidth, gap)` pairs, and at render time the pair with the highest `minWidth` that is still `<= availableWidth` wins. Spacing and row height are the two things that usually have to give when a form is squeezed, so both carry this override list — `setAclDefaultRowHeight`, `setRowHeight` and `newRow` take the same shape with `(minWidth, height?)` pairs — and both can therefore be made responsive without declaring a whole layout variant (§27).

### `setAclDefaultRowGap(int pixels)`

Sets a fixed vertical gap (in pixels) inserted before each new content row started with `newRow()`. Only applies when the individual `newRow()` call specifies `dist: 0` (the default). An explicit `dist` always wins. The built-in gap is **8**; pass 0 to disable it.

### `setAclDefaultUnknownMinimumSize(double width, [double height = 0])`

Sets a default minimum size for components that lack an explicit `setMSize` / `setMWidthInChars` call. There is no built-in default — without this call a component keeps a null minimum size.

Both arguments are stored verbatim, zeros included, and a later call replaces both dimensions. A `0` is therefore a minimum of 0 on that axis, which the layout cannot distinguish from no minimum; that is what makes storing it harmless rather than a case the setter skips.

**Minimum ≤ preferred invariant:** The minimum size can never exceed the preferred size. If a minimum is set that is larger than the current preferred size, the preferred size is automatically raised to match the minimum.

**Interaction with the sizing phases:** When minimum < preferred (the normal case), space is distributed to **all** components proportionally based on the ratio `(preferred / minimum) − 1` until every non-expandX component has reached its preferred size. After that, remaining space goes **exclusively** to expandX components, again distributed by their `(preferred / minimum) − 1` ratio. If no expandX components exist in the row, all components keep growing proportionally (bounded by their maximum size, if set).

### `setAclDefaultUnknownPreferredSize(double width, [double height = 0])`

Replaces the built-in 150 × 0 default preferred size for components without an explicit `setPSize` / `setPWidthInChars`. A `0` width falls back to the **factory** 150 — not to whatever an earlier call to this setter passed. Height has no fallback: it is stored verbatim, and 0 leaves the height unconstrained because 0 already is the built-in height.

### What `0` means, setter by setter

`0` does not mean one thing across the builder. It means three, and which one applies depends on whether the setter has anything to fall back *to*:

| Setter | A `0` argument means |
| ------ | -------------------- |
| `setAclDefaultAppendGap`, `setAclDefaultRowGap` | **Off.** The gap is 0 — the built-in 8 is discarded. |
| `setAclDefaultUnknownPreferredSize` | **Width only:** fall back to the factory 150. Height is stored as 0. |
| `setAclDefaultUnknownMinimumSize` | **Stored as 0.** No fallback on either axis. |
| `setPSize`, `setMSize` (per-component) | **Leave that dimension alone** — keep the value an earlier call on the same component set, or 0 if there was none. |
| `setXSize` (per-component) | **Leave that dimension alone** — keep the value an earlier call set, or leave the axis **unconstrained** (`double.infinity`) if there was none. |

The split is structural rather than stylistic. A per-component setter targets a component that may already carry a size, so "leave it alone" names a real previous value. The builder-wide setters have no per-axis previous value to preserve — each call replaces the whole `Size` — so the only fallback available to them is a *factory constant*, and only the preferred width has one.

`setXSize` differs from its two siblings on the unset case because 0 does not mean the same thing to a maximum. A preferred or minimum of 0 is no constraint; a maximum of 0 is *no size at all*, and the container turns it into `BoxConstraints(maxHeight: 0)` faithfully enough to collapse the child. So `setXSize(200)` — the natural spelling of "cap the width at 200" — must leave the height alone rather than pin it to 0. This is also what makes the char-width shorthand above exact: `setXWidthInChars` has always fallen back to `double.infinity`, and `setXSize` now agrees with it.

A gap of 0 is meaningful in a way that a size of 0 is not, which is why the gap setters take it literally instead of falling back to the built-in 8.

`test/advanced_container_layout/acl_builder_defaults_test.dart` pins every row of that table, including the two-call cases where "fall back to the factory" and "keep the previous value" stop looking alike. It also fails if a `setAclDefault*` setter is added and never exercised there.

### Example

Note the chained `.` rather than a cascade `..`: every builder method returns the
builder, so a cascade works too — but a cascade evaluates to the *builder*, and
`build()` is the one call whose return value you actually want. `final acl = AclBuilder()..build();` types `acl` as `AclBuilder`, not `Acl`.

```dart
final Acl acl = AclBuilder()
    .setAclExpandXDefault(true)              // all fields expand
    .setAclDefaultAppendGap(16)              // 16 px before each field
    .setAclDefaultRowGap(12)                 // 12 px between rows
    .setAclDefaultUnknownPreferredSize(200)  // wider default than 150
    .append(nameField)                       // expandX, 16 px gap (auto)
    .append(industryField)                   // expandX, 16 px gap (auto)
    .newRow()                                // 12 px gap (auto)
    .append(emailField)
    .append(phoneField, dist: 24)            // explicit 24 px overrides default 16
    .build();
```

---

## 6. Row Sizing — Three Steps

Each content row is sized independently before cross-row constraints are applied.

```
Step 1 — Shrink to preferred
─────────────────────────────
If Σ preferred > availableWidth:

  shrinkable = components without alignXToKey, Flexible, or Expanded
  shrinkCap  = Σ (preferred[i] − minimum[i])  [default min = preferred]
  ratio      = (Σ preferred − availableWidth) / shrinkCap
  fitted[i]  = preferred[i] − (preferred[i] − minimum[i]) * ratio

Step 2 — Grow to preferred
────────────────────────────
If Σ fitted < availableWidth and any fitted[i] < preferred[i]:

  Grow under-preferred components toward preferred
  (pro-rata on the deficit)

Step 3 — Fill remaining space beyond preferred
────────────────────────────────────────────────
If Σ fitted < availableWidth AND the row contains gap()/expandX components:

  Option A — gap() slots present:
    remaining space is divided by slot weights and given to gap() slots

  Option B — expandX components present (no gap slots):
    remaining space is given exclusively to expandX components (via Flutter
    Flexible). Non-expandX components stay at their preferred width.
    expandX components grow without bound unless capped by setXSize().

If Σ fitted < availableWidth AND NO gap() AND NO expandX:

  Option C — proportional grow by preferred-width share:
    Truly natural-sized components (no ACL hints at all) are absent from
    naturalWidth because their pref was recorded as 0.  Their real widths are
    measured and subtracted before distributing, so distributed space never
    overlaps their footprint.

    naturalExcluded = Σ real_width[i]  (only widgets with no ACL hints at all)
    surplus   = availableWidth − naturalWidth − naturalExcluded
    grow-pool = {i : any ACL hint is present}  (preferredSize | minimumSize |
                                                 maximumSize | useOtherDimX)
    totalPref = Σ preferred[i]  (over grow-pool only)
    share[i]  = surplus × preferred[i] / totalPref
    grown[i]  = preferred[i] + share[i]
                  capped at maximumSize[i] if a finite max is declared.
                  No maximumSize → full share is used.

  Note: surplus is inherently self-limiting (= availableWidth − occupied).
  Growth can never push a component past the container edge because there is
  never more surplus than the actual remaining space.
  maximumSize is a CEILING that prevents further growth above a set value.
  Not setting it means the component may grow to fill its entire share.
  Use setXSize() / setXWidthInChars() only when growth must be capped.
```

```
Example — Option C (no expandX, no gap, availableWidth = 500):

  [Label  pref=90, setPSize only — no setXSize]
  [Field-A pref=96, no setXSize]
  [Field-B pref=96, setXSize=150]

  All three have ACL hints → grow-pool = {Label, Field-A, Field-B}
  totalPref = 90 + 96 + 96 = 282   surplus = 500 − 282 = 218
  share(Label)  = 218 × 90/282 ≈  70 → Label  = 90+70 = 160  (uncapped)
  share(Field-A)= 218 × 96/282 ≈  74 → Field-A= 96+74 = 170  (uncapped)
  share(Field-B)= 218 × 96/282 ≈  74 → Field-B= min(170, 150) = 150

Example — natural-sized label (no setPSize, no setXSize):

  [Label SizedBox(90) — no ACL hints]  [Field pref=96, no setXSize]
  (dist = 8 between them recorded as gapBefore of Field)

  naturalWidth (from loop) = 8 + 96 = 104  (Label had pref=0)
  naturalExcluded = 90  (SizedBox.width fallback or measured rect)
  surplus   = 500 − 104 − 90 = 306
  totalPref = 96  (only Field is in grow-pool; Label has no hints)
  share(Field) = 306 × 96/96 = 306  → grown = 96 + 306 = 402  (uncapped)

Example — Option B (expandX present, availableWidth = 500):

  [Label pref=90] [Field expandX pref=96]

  Steps 1/2: Label=90, Field=96
  Step 3 Option B: surplus=314 → all given to Field (expandX)
  Label stays at 90 (it is excluded by skip() because expandX is set)
```

---

## 7. Horizontal Gap Slots — `gap({double weight = 1})`

`gap()` inserts an elastic horizontal spacer. Multiple gaps share remaining space by weight.

```
Remaining space = availableWidth − Σ component_fitted_widths
Gap[i] width    = remaining × weight[i] / Σ weights
```

In scrollable-X mode, all gaps collapse to 0.

A gap slot is a normal `AclComponent` carrying `AclFlags.gapElement`, read back
through `AclComponent.isGap`, and holding its share in `AclComponent.gapWeight`.
The bit is what separates a spacer from content in every layout pass, and the
separation is total: **a gap slot's `child` is never built.** Both the measuring
pass and the building pass skip it and emit a `Spacer` in its place, which is
why `gap()` supplies a `SizedBox.shrink()` as a child that never renders. Two
things follow. The builder stops targeting a current component when it inserts a
slot, so per-component calls chained after `gap()` are ignored rather than
applied to the slot — a gap is sized by its `weight`, never by a size hint. And
setting `AclFlags.gapElement` on an appended component through `setAttr`
discards that component's widget, so `gap()` is the only sanctioned producer.

A row holding any gap slot has its horizontal alignment forced to left: the slot
has already claimed the surplus that `setRowHorizontalAlignment` would otherwise
distribute.

### Examples

```
Scenario A — title left, buttons right:
  ..append(title)
  ..gap()
  ..append(ok)..append(cancel)

  ┌──────────────────────────────────────────────┐
  │ Title  ░░░░░░░░░░░░░░░░░░░░░░░░░░  OK  Cancel│
  └──────────────────────────────────────────────┘

Scenario B — widget centred:
  ..gap()
  ..append(widget)
  ..gap()

  ┌──────────────────────────────────────────────┐
  │ ░░░░░░░░░░░░░  Widget  ░░░░░░░░░░░░░░░░░░░░░│
  └──────────────────────────────────────────────┘

Scenario C — weighted split (left 2/3, right 1/3 of slack):
  ..gap(weight: 2)..append(left_panel)..gap(weight: 1)..append(right_panel)
```

When no `gap()` slots are present, `setRowAlignment` / `setRowAlignLeft()` / `setRowAlignCenter()` / `setRowAlignRight()` controls row justification.

---

## 8. Vertical Gap Rows — `gapRow({double weight = 1, AclSeparator? separator, double minSize = 0})`

`gapRow()` inserts an elastic vertical spacer between content rows. It cannot contain components. Calling it implicitly starts a new content row, so no `newRow()` call is needed afterwards.

```
Remaining vertical = containerHeight − Σ content_row_heights
gapRow[i] height   = remaining × weight[i] / Σ weights
```

Elastic sizing needs a bounded height to divide up, and it is unavailable in
three cases: scrollable-Y mode, an unbounded incoming height, and a layout that
contains an `expandY` component (which claims the surplus, so gap rows must not
compete for it). In all three the gap row takes a **fixed** height instead —
`minSize`, which collapses the row to nothing at the default of 0, or
`max(9, minSize)` when the row carries a separator. A separator therefore still
draws in a scrolling container; only the elastic *spacing* disappears.

### Separator

The optional `separator` draws a horizontal line within the gap row area:

```dart
gapRow(separator: AclSeparator(
  style: AclSeparatorStyle.single,            // or .doubleLine
  color: Colors.grey,                         // defaults to theme divider colour
  lineWidth: 1.0,
  alignment: AclSeparatorAlignment.middle,    // top | middle | bottom
))
```

| `AclSeparatorStyle` | Rendering |
|---|---|
| `single` | One horizontal line (Flutter `Divider`-equivalent) |
| `doubleLine` | Two parallel horizontal lines, spaced `lineWidth × 2` apart |

`AclSeparatorAlignment` places the line(s) at the `top`, `middle`, or `bottom` of the gap row's computed height.

### Example

```dart
..newRow()..append(header)
..gapRow()                          // weight=1 elastic spacer, no separator
..append(body)                      // implicit new row
..gapRow(weight: 2, separator: AclSeparator(style: AclSeparatorStyle.single))   // or .doubleLine
..append(footer)                    // implicit new row
```

```
┌─────────────────────┐
│ Header              │
│                     │ ← gapRow(1) = 1/3 of remaining vertical
│                     │
│ Body                │
│  ─────────────────  │ ← separator at middle of gapRow(2)
│                     │
│                     │ ← gapRow(2) = 2/3 of remaining vertical
│ Footer              │
└─────────────────────┘
```

---

## 9. Cross-Row Horizontal Alignment — `alignXxx` (X axis)

These methods translate this component horizontally so that one of its X-edges aligns (with optional gap) to an X-edge of a component in a **different row**.

**Rule:** the reference component must be in a different row. Using a same-row reference throws.  
**Rule:** the reference must be declared earlier in the builder — forward references throw.

```
Row 0:  [  Label (key L)  ][  TextField  ]
                │
                │ alignLeftToLeft(label)
                ▼
Row 1:  [  Hint  ]
         L.left = Hint.left → Hint is translated to start at same X as Label
```

### Full method table

| Method | Self edge | Reference edge |
|---|---|---|
| `alignLeftToLeft(ref)` | left | left |
| `alignLeftToCenter(ref)` | left | center-X |
| `alignLeftToRight(ref)` | left | right |
| `alignCenterToLeft(ref)` | center-X | left |
| `alignCenterToCenter(ref)` | center-X | center-X |
| `alignCenterToRight(ref)` | center-X | right |
| `alignRightToLeft(ref)` | right | left |
| `alignRightToCenter(ref)` | right | center-X |
| `alignRightToRight(ref)` | right | right |

All accept `gap: double` (default 0).

### Interaction with subsequent components (`collapseToVisual`)

When a component has a **negative** alignment delta (it shifts leftward of its natural sequential position), the actual visual right boundary of the row falls to the left of where the sequential position tracker (`plannedX`) believes it to be. The **next** component that has no explicit alignment constraint automatically corrects for this: its `gapBefore` is applied relative to the real visual right edge, not `plannedX`. This means gap spacing between a left-shifted component and the following component is always measured from the visible edge, not from an invisible planned coordinate.

---

## 10. Same-Row Vertical Alignment — `alignYxx` (Y axis)

These methods translate this component vertically so that one of its Y-edges aligns to a Y-edge of a sibling in the **same row**.

**Rule:** the reference component must be in the same row. Using a different-row reference throws.  
**Rule:** the reference must be declared earlier in the builder — forward references throw.  
**Rule:** cannot be combined with `alignTopInRow`/`alignMiddleInRow`/`alignBottomInRow` — throws if both are set on the same component.

```
Same row:  [  TallWidget  ][  Icon → alignTopToBottom(tallWidget) → offset down  ]

  ┌──────────────┐
  │              │  TallWidget
  │              │──────────────── TallWidget.bottom
  │              │  ↕ gap
  └──────────────┘  ┌────┐
                    │Icon│  ← aligned top to TallWidget's bottom
                    └────┘
```

### Full method table

| Method | Self edge | Reference edge |
|---|---|---|
| `alignTopToTop(ref)` | top | top |
| `alignTopToMiddle(ref)` | top | middle (center-Y) |
| `alignTopToBottom(ref)` | top | bottom |
| `alignMiddleToTop(ref)` | middle | top |
| `alignMiddleToMiddle(ref)` | middle | middle |
| `alignMiddleToBottom(ref)` | middle | bottom |
| `alignBottomToTop(ref)` | bottom | top |
| `alignBottomToMiddle(ref)` | bottom | middle |
| `alignBottomToBottom(ref)` | bottom | bottom |

All accept `gap: double` (default 0).

---

## 11. Row Cross-Alignment (per-component vertical placement)

When `alignYToKey` is **not** set, a component's vertical position within the row is controlled by its `rowCrossAlignment`. This is the standard Flutter Row cross-axis alignment applied per component, and it is settable at three scopes:

| Scope | Method | Applies to |
|---|---|---|
| Component | `setVerticalAlignment(AclRowCrossAlignment align)` | the component currently being configured |
| Row | `setRowVerticalAlignment(AclRowCrossAlignment align)` | the current row, and every component in it that has not set its own |
| Container | `setAclDefaultRowVerticalAlignment(AclRowCrossAlignment alignment)` | every row that has not set its own |

The row-level setter has three no-argument spellings for the common cases —
`setRowAlignTop()`, `setRowAlignMiddle()` and `setRowAlignBottom()`, which
forward to `AclRowCrossAlignment.top`, `.center` and `.bottom` respectively.
(`AclRowCrossAlignment` names the middle value `center`; the convenience
methods spell it `Middle`. §18 lists the enum.)

**The default is `top`, not centre.** A row of form fields of unequal height
reads as a row when their captions line up at the top; centring makes a tall
field appear to float. Rows and components inherit downwards — a component with
no alignment of its own takes the row's, and a row with none takes the
container default — and both the row-level and container-level setters apply
**retroactively** to rows and components already appended, so call order does
not matter.

`setVerticalAlignment` cannot be combined with an `alignY*` method on the same
component: `alignY*` (§10) positions a component against another component's
edge, which overrides row cross-alignment entirely. Attempting both throws
`UnsupportedError` rather than silently letting one win.

---

## 12. Size Reference Constraints

These make one component adopt the **rendered** size of another. They are dynamic: if the referenced component's size changes during iterative settling, the constrained component updates in the next pass.

| Method | Effect |
|---|---|
| `sameWidthAs(ref)` | width = ref's rendered width |
| `sameHeightAs(ref)` | height = ref's rendered height |
| `sameSize(ref)` | both dimensions |

`setComp(ref, attr)` is the shared primitive; `attr` must carry at least one of `AclFlags.otherDimX` / `otherDimY`, since only those bits are read and an `attr` without them would record a reference nothing resolves.

**Rule:** `ref` must have been declared earlier in the builder — forward references throw. So does a widget that was never appended, and a `Flexible`, `Expanded` or `Spacer`, which the row lays out itself and which therefore carries no key to point at.

```
Row 0: [Label A (rendered: 120px wide)]
Row 1: [Label B] [Field → sameWidthAs(labelA) → Field.width = 120px]
```

---

## 13. Expand Flags

| Method | `AclFlags` | Effect |
|---|---|---|
| `expandX()` | `expandX = 1` | Component claims **exclusive** right to all remaining row width beyond preferred |
| `expandY()` | `expandY = 2` | Component grows to fill row height |
| `expand()` | `expandX \| expandY` | Both axes |

### Clarification: `expandX` is about exclusivity, not growth

`expandX` is **not** required for a component to grow beyond its preferred width.
Without `expandX`, all ACL-hinted components (those with any size hint set) grow
proportionally to fill any available surplus (Step 3 Option C above).
Components with a finite `maximumSize` are capped at that value; others grow
freely up to their proportional share of the remaining space.

`expandX` is used when a **specific component should receive ALL remaining surplus**,
preventing other components from growing beyond their preferred size:

```
Without expandX:   [A pref=100 max=150] [B pref=100 max=200]
                   → Surplus distributed proportionally: A & B both grow.

With A.expandX:    [A expandX pref=100 max=∞] [B pref=100 max=200]
                   → A gets all surplus (grows without bound); B stays at 100.
```

Typical uses of `expandX`:
- A text field in a search bar that should fill the remaining width
- A content area flanked by fixed toolbars
- Any component where "take as much space as possible" is the intent

> **⚠ Under Examination:** `expandX` components are currently implemented using Flutter's `Flexible`/`Expanded` widgets, which subjects them to Flutter's flex layout rules. Mixing `Acl` with external flex-based containers may produce unexpected results. This implementation detail may change in a future revision.

---

## 14. Layout Calculation Model

ACL separates **size determination** from **Flutter layout** to avoid multi-frame flicker and give a well-bounded deterministic calculation.

### Two categories of component size

| Category | How size is known |
|---|---|
| **Explicit** | Component has at least one ACL size hint (`setPSize`, `setMSize`, `setXSize`, or `sameWidthAs` / `sameHeightAs` / `sameSize`). Size is known at calculation time without consulting Flutter. |
| **Natural** | No ACL size hints. Flutter widget renders at its intrinsic size. Size must be read from Flutter's render tree. |

### Build-time flow

```
Step 0 — Collect natural sizes  (render tree, once per build)
  ∙ For every natural-sized component, read its cached measured size
    from the GlobalKey render tree (cached from the previous frame).
  ∙ If not yet measured (first frame), use 0×0 as initial estimate.
  ∙ This is the ONLY point where the Flutter render tree is consulted
    for sizing; all subsequent work is pure Dart.

Steps 1..N — Iterative pre-calculation loop  (pure Dart, no Flutter paint)
  For each iteration:
    1. Compute fitted widths for each row (3-step algorithm, Section 6)
    2. Compute gap slot widths (Section 7) and gap row heights (Section 8)
    3. Resolve sameWidthAs / sameHeightAs / sameSize from values computed
       in Step 1 of the current iteration
    4. Compute horizontal alignment deltas for alignXToKey components
    5. Compute vertical alignment deltas for alignYToKey components
    6. If any value changed by more than ε = 0.5 px → run iteration N+1
    7. Else → converged

  Maximum iterations: 20 (configurable).
  If not converged after max iterations, use best available values.
  Layout may have residual errors but will never crash or infinite-loop.

Final step — Single Flutter layout pass
  Build the Flutter widget tree with all sizes and positions pre-computed.
  ConstrainedBox / SizedBox / Transform.translate receive the pre-calculated
  values directly — no further measurement or setState is needed for layout.
```

### Post-frame natural-size refresh

After the layout pass, a `post-frame callback` re-measures all `GlobalKey` render boxes and updates the natural-size cache. If any measured size differs from the cached estimate by more than ε, `setState()` triggers a new build and pre-calculation loop. This keeps natural-sized components correct when their intrinsic size changes at runtime (e.g. a `Text` widget reflows after a font change).

Each triggered rebuild runs the full pre-calculation loop, so the visible result is always a fully-resolved layout — never a partially-laid-out intermediate frame.

### Frame-to-frame cache key remapping

`AclBuilder` generates new `GlobalKey` objects on every `build()` call (the builder is a transient object). When the parent widget rebuilds, the old keys are replaced before the new render tree is attached. To avoid a one-frame cache miss, the container remaps natural-size and position cache entries from old keys to new keys by **structural position** (row index × component index within that row). This means cached measurements survive a parent rebuild instantly.

---

## 14.5. Distinct-Instance Rule

Every `append()` takes responsibility for a widget instance, and no instance may be appended twice — the builder's maps are identity-keyed and the container attaches a `GlobalKey` per component, so a widget reaching the row twice leaves one key covering two places and a reference naming it meaning either.

A `Flexible`, `Expanded` or `Spacer` is **unwrapped** for the comparison, down the whole chain: those three get no key of their own, so the instance that has to be distinct is the one inside. `append(w)` followed by `append(Expanded(child: w))` is the same duplicate written two ways, and is refused.

The unwrapping covers `Flexible` and its subclasses — which is what `Expanded` is — and nothing else. Any other wrapper is a component in its own right and is compared as itself, so a widget may appear as *content* inside a later component without being a second component. Walking the whole subtree instead would refuse that, and it is harmless.

These three are also the widgets the row lays out natively: they reach the `Row` as its direct child, with no scope, sizing or alignment wrapper between, because a `ParentDataWidget` separated from its flex cannot apply its parent data.

---

## 15. Back-Reference Rule

Any reference passed to `alignXxx`, `alignYxx`, `sameWidthAs`, `sameHeightAs`, or `sameSize` must refer to a widget that was `append()`-ed **earlier** in the same `AclBuilder` call chain. The builder tracks declarations in order; a forward reference (the referenced widget has not been appended yet) throws an `UnsupportedError` with a descriptive message at build time.

References are passed as the **`Widget` instance directly** — the builder maps each appended widget to an auto-generated `GlobalKey` via an identity map. The parameter type is `Widget`, so a raw `Key` is a compile error rather than a reference that resolves to nothing.

The rule is enforced where the reference is written, not where the layout runs, because an unresolvable reference has no symptom of its own: the container lays out, the component keeps its own size, and what the reader sees is two widths that were supposed to match and do not.

---

## 16. Container-Level Border Styles

Borders use Flutter's standard `BoxBorder`/`BoxDecoration` system. Shadow and 3D-bevel effects are **not** supported — those belong to the application theme layer, not the layout container.

### Supported border types (`AclBorderKind`)

| Value | Description | Flutter backing |
|---|---|---|
| `none` | No border (default) | — |
| `solid` | Single line on all sides | `Border.all(...)` |
| `solidDouble` | Two concentric solid lines | outer + inner `Border.all` via `Padding` |
| `top` | Top side only | `Border(top: BorderSide(...))` |
| `bottom` | Bottom side only | `Border(bottom: BorderSide(...))` |
| `left` | Left side only | `Border(left: BorderSide(...))` |
| `right` | Right side only | `Border(right: BorderSide(...))` |
| `horizontal` | Top + bottom | `Border(top:..., bottom:...)` |
| `vertical` | Left + right | `Border(left:..., right:...)` |

### `AclBorderStyle` fields

| Field | Type | Default | Meaning |
|---|---|---|---|
| `kind` | `AclBorderKind` | `none` | Border type |
| `color` | `Color` | `Colors.grey` | Line colour |
| `lineWidth` | `double` | `1.0` | Line thickness |
| `rounded` | `bool` | `false` | Rounded corners |
| `borderRadius` | `double` | `8.0` | Corner radius (when `rounded`) |
| `borderInsets` | `EdgeInsetsGeometry` | `EdgeInsets.zero` | Explicit inner padding between border and content. When `EdgeInsets.zero` (the default) and no container-level `padding` is set, the implementation automatically applies `EdgeInsets.all(4)` as inner insets whenever the border is enabled. When container-level `padding` is set, the default 4px insets are suppressed (padding replaces them). Explicit `borderInsets` always apply regardless of `padding`. |

Convenience constructors:
- `AclBorderStyle.none()` — disabled (default)
- `AclBorderStyle.solid({Color color, double lineWidth, bool rounded, double borderRadius})`

---

## 17. Complete `AclBuilder` Public API

Every public method of `AclBuilder` and of the `AclBuilderExtensions`
extension, with the signature it actually has.
`test/advanced_container_layout/acl_spec_api_test.dart` pins this section
against `lib/src/advanced_container_layout/acl_builder.dart`: a signature that
drifts, or a method added to the builder and not listed here, fails that test.

### Constructor

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

### Component placement

```dart
// Append a component to the current row
AclBuilder append(Widget child, {double dist = 0})

// Insert an elastic horizontal gap into the current row
AclBuilder gap({double weight = 1})
```

### Row management

`height` fixes the row height (null = intrinsic); `heightBpOverrides` is the
usual list of `(minWidth, value)` pairs, widest match wins.

```dart
// Start a new content row
AclBuilder newRow({
  double dist = 0,
  double? height,
  List<(double, double?)> heightBpOverrides = const [],
})

// Insert an elastic vertical gap row; implicitly starts a new content row
AclBuilder gapRow({double weight = 1, AclSeparator? separator, double minSize = 0})

// Height of the current row / of every row that sets none of its own
AclBuilder setRowHeight(double? height, [List<(double, double?)> heightBpOverrides = const []])
AclBuilder setAclDefaultRowHeight(double? height, [List<(double, double?)> heightBpOverrides = const []])
```

### Container-level sizing

```dart
AclBuilder setAclPSize(double width, double height)    // preferred container size
AclBuilder setAclMSize(double width, double height)    // minimum container size
AclBuilder setAclXSize(double width, double height)    // maximum container size
```

### Container-level scroll mode

```dart
AclBuilder setAclScrollableX()   // switch horizontal axis to scroll mode
AclBuilder setAclScrollableY()   // switch vertical axis to scroll mode
```

### Per-component sizing

Height is optional on all three size setters: omitting it keeps the height an
earlier call on the same component set. With no earlier call the height is `0`
— see "What `0` means, setter by setter" (§5b), which is where the per-component
rule is contrasted with the builder-wide one.

```dart
AclBuilder setPSize(double width, [double height = 0])    // preferred
AclBuilder setMSize(double width, [double height = 0])    // minimum
AclBuilder setXSize(double width, [double height = 0])    // maximum
AclBuilder setPWidthInChars(int chars, {double charWidth = 8, double height = 40})
AclBuilder setMWidthInChars(int chars, {double charWidth = 8})
AclBuilder setXWidthInChars(int chars, {double charWidth = 8})
```

### Per-component expand flags

```dart
AclBuilder setAttr(int attr)     // raw flags (use extensions instead)
AclBuilder clearAttr(int attr)
// via AclBuilderExtensions:
AclBuilder expandX()
AclBuilder expandY()
AclBuilder expand()
```

### Per-component size references (dynamic, back-reference only)

`setComp` is the general form the three shortcuts are written in terms of; it
takes a raw `AclFlags.otherDimX` / `otherDimY` / `otherDim` mask.

```dart
AclBuilder sameWidthAs(Widget reference)
AclBuilder sameHeightAs(Widget reference)
AclBuilder sameSize(Widget reference)
AclBuilder setComp(Widget reference, int otherAttr)
```

### Vertical alignment within a row

One axis, three scopes — component, row, builder — resolved innermost-first.
Mutually exclusive with the `alignYxx` methods on the same component: setting
both throws. See §11.

```dart
// This component only
AclBuilder setVerticalAlignment(AclRowCrossAlignment align)

// The current row
AclBuilder setRowVerticalAlignment(AclRowCrossAlignment align)
// via AclBuilderExtensions:
AclBuilder setRowAlignTop()
AclBuilder setRowAlignMiddle()
AclBuilder setRowAlignBottom()

// Every row that sets none of its own
AclBuilder setAclDefaultRowVerticalAlignment(AclRowCrossAlignment alignment)
```

### Cross-row horizontal alignment (reference must be in a different row)

```dart
AclBuilder alignLeftToLeft(Widget reference,   {double gap = 0})
AclBuilder alignLeftToCenter(Widget reference, {double gap = 0})
AclBuilder alignLeftToRight(Widget reference,  {double gap = 0})
AclBuilder alignCenterToLeft(Widget reference,   {double gap = 0})
AclBuilder alignCenterToCenter(Widget reference, {double gap = 0})
AclBuilder alignCenterToRight(Widget reference,  {double gap = 0})
AclBuilder alignRightToLeft(Widget reference,   {double gap = 0})
AclBuilder alignRightToCenter(Widget reference, {double gap = 0})
AclBuilder alignRightToRight(Widget reference,  {double gap = 0})
```

### Same-row vertical alignment (reference must be in same row; mutually exclusive with setVerticalAlignment)

```dart
AclBuilder alignTopToTop(Widget reference,      {double gap = 0})
AclBuilder alignTopToMiddle(Widget reference,   {double gap = 0})
AclBuilder alignTopToBottom(Widget reference,   {double gap = 0})
AclBuilder alignMiddleToTop(Widget reference,   {double gap = 0})
AclBuilder alignMiddleToMiddle(Widget reference,{double gap = 0})
AclBuilder alignMiddleToBottom(Widget reference,{double gap = 0})
AclBuilder alignBottomToTop(Widget reference,   {double gap = 0})
AclBuilder alignBottomToMiddle(Widget reference,{double gap = 0})
AclBuilder alignBottomToBottom(Widget reference,{double gap = 0})
```

### Horizontal alignment of a whole row

Horizontal placement is a row-level concern — there is no per-component form.
*(Ignored for a row that contains any `gap()` slots: an elastic slot already
decides where the slack goes.)*

```dart
AclBuilder setRowHorizontalAlignment(RowAlignment align)  // left | center | right
// via AclBuilderExtensions:
AclBuilder setRowAlignLeft()
AclBuilder setRowAlignCenter()
AclBuilder setRowAlignRight()

// Every row that sets none of its own
AclBuilder setAclDefaultRowHorizontalAlignment(RowAlignment alignment)
```

### Container-level decoration

```dart
AclBuilder setAclDefaultFlags(int flags)
AclBuilder setAclBorderStyle(AclBorderStyle style)
AclBuilder setAclBorderInsets(EdgeInsetsGeometry insets)
AclBuilder setAclFocusedBorderStyle(AclBorderStyle style)
AclBuilder setAclPadding(EdgeInsetsGeometry padding)
AclBuilder setAclPaddingPx(double left, double top, double right, double bottom)
AclBuilder setAclPaddingTop(double value)
AclBuilder setAclPaddingBottom(double value)
AclBuilder setAclPaddingLeft(double value)
AclBuilder setAclPaddingRight(double value)
AclBuilder setAclBackgroundColor(Color color)
AclBuilder setAclTitle(String? title)
AclBuilder setAclTitleWidget(Widget? widget)
AclBuilder setAclTitleStyle(TextStyle style)
AclBuilder setAclTitlePosition(AclTitlePosition position)
AclBuilder setAclTitleBorderAlign(AclTitleBorderAlign align)
AclBuilder setAclTitleVerticalOffset(double offset)
```

### Container-level component defaults

See "What `0` means, setter by setter" (§5b) for the semantics — the four
setters below read a `0` argument three different ways.

```dart
// Enable/disable expandX for all subsequently appended components
AclBuilder setAclExpandXDefault(bool enabled)

// Default horizontal gap before each appended component, with optional
// (minWidth, gap) breakpoint overrides
AclBuilder setAclDefaultAppendGap(double gap, [List<(double, double)> gapBpOverrides = const []])

// Default vertical gap (pixels) before each new content row
AclBuilder setAclDefaultRowGap(int pixels)

// Default minimum size for components without explicit setMSize/setMWidthInChars
// Zeros are stored as zeros — no fallback on either axis
AclBuilder setAclDefaultUnknownMinimumSize(double width, [double height = 0])

// Default preferred size for components without explicit setPSize/setPWidthInChars
// Width = 0 falls back to the factory 150; height = 0 leaves height unconstrained
AclBuilder setAclDefaultUnknownPreferredSize(double width, [double height = 0])
```

### Identity, groups and visibility

Covered in depth by §24 (ids), §25 (groups) and §26 (visibility control);
listed here so this section stays a complete index of the builder surface.

```dart
// IDs — §24
AclBuilder setAclId(String id)
AclBuilder setRowId(String id)
AclBuilder setId(String id)
AclBuilder setAclIdScope(bool idScope)
AclBuilder setRowIdScope(bool idScope)

// Groups — §25
AclBuilder setAclGroup(String name)
AclBuilder setRowGroup(String name)
AclBuilder startGroup(String name)
AclBuilder endGroup()
AclBuilder group(String name)

// Visibility — §26
AclBuilder setGroupVisibilityController(String groupName, AclGroupVisibilityController controller)
```

### Authorization-driven hiding

Drops a component whose child evaluates to `TomAuthState.none` from the row at
build time, rather than rendering it disabled. See §26b.

```dart
AclBuilder setAclDefaultHideUnauthorized(bool value)
AclBuilder setHideUnauthorized(bool? value)   // null = fall back to the default
```

### Responsive layout

Covered in depth by §27 (variants), §28 (row breakpoints), §29 (inline
component variants) and §30 (layout direction).

```dart
AclBuilder addVariant(String name, {required double atWidth, required void Function(AclBuilder) builder})
AclBuilder addRowBreakpoint({required double atWidth, double splitRowDist = 0})
AclBuilder startVariant({
  double? width,
  double? height,
  AclInputMode? input,
  AclFormFactor? formFactor,
  Orientation? orientation,
  Set<TargetPlatform>? platforms,
  bool? isWeb,
  AclDensity? density,
  TextDirection? textDirection,
  double? minAccessibilityScale,
  AclVariantDetector? detector,
})
AclBuilder endVariant()
AclBuilder setAclDirection(AclDirection direction)
```

### Build

```dart
Acl build()
```

---

## 18. Enumerations and Value Types

```dart
enum RowAlignment            { left, center, right }
enum AclTitlePosition        { topLeft, topCenter, topRight }
enum AclBorderKind           { none, solid, solidDouble,
                               top, bottom, left, right,
                               horizontal, vertical }
enum AclAxisPointX           { left, center, right }
enum AclAxisPointY           { top, center, bottom }      // "center" = "middle" in methods
enum AclRowCrossAlignment    { top, center, bottom }      // "center" = "middle" in methods
enum AclSeparatorStyle       { single, doubleLine }
enum AclSeparatorAlignment   { top, middle, bottom }

class AclBorderStyle {
  final AclBorderKind kind;
  final Color color;
  final double lineWidth;
  final bool rounded;
  final double borderRadius;
  final EdgeInsetsGeometry borderInsets;
  // constructors: AclBorderStyle.none(), AclBorderStyle.solid(...)
}

class AclSeparator {
  final AclSeparatorStyle style;
  final Color? color;           // defaults to theme divider colour
  final double lineWidth;
  final AclSeparatorAlignment alignment;
}
```

---

## 20. Layout Architecture Diagram

```
AclBuilder.build()  →  Acl (StatefulWidget)
                            │
                            ▼
                     LayoutBuilder  ←── availableWidth, availableHeight
                            │
              Step 0: read natural-size cache
                (GlobalKey render-tree measurements from last frame;
                 remapped from old keys by structural position)
                            │
              Steps 1..N: pre-calculation loop  (pure Dart)
               ├ 3-step row fitting (shrink → grow → fill)
               ├ gap slot widths / gapRow heights
               ├ sameWidthAs / sameHeightAs resolution
               ├ alignXxx horizontal deltas (cross-row)
               ├ alignYxx vertical deltas   (same-row)
               └ converged (ε=0.5) or max-iterations hit?
                            │
              Final step: single Flutter layout pass
               ├── content row (all sizes fixed)
               │    └ Row([ConstrainedBox(child), SizedBox(gap), ...])
               │         sizes and Transform.translate from pre-calc
               ├── gapRow slot  SizedBox(h: gapH)
               └── content row (all sizes fixed)
                            │
               addPostFrameCallback: re-measure natural-sized GlobalKeys
                └ any measurement changed? → setState() → one rebuild
                  (never shows a partially-laid-out frame)
```

---

## 21. Nested Acl Usage

An `Acl` can be nested inside another `Acl` (or any Flutter widget) like any other widget. When embedded via `append()`, the outer container treats it as an ordinary component using its `setAclPSize`/`setAclMSize`/`setAclXSize` values for fitting. The inner `Acl` layout runs independently.

```
Outer Acl
  Row 0: [ Sidebar Acl (setAclPSize(200, double.infinity)) ]
         [ Content Acl (expandX) ]
```

---

## 23. Demo Requirements

Since `Acl` fills available space by default, demos work correctly in a `Scaffold` body without extra wrapping:

```dart
Scaffold(
  body: AclBuilder(
    borderStyle: AclBorderStyle.solid(color: Colors.grey),
  )
    .append(const Text('Hello'))
    .gap()
    .append(const Text('World'))
    .newRow()
    .gapRow()
    .append(const Text('Footer'))
    .build(),
)
```

For demos inside a widget that does not offer unbounded space (e.g. nested inside a `Column` without `Expanded`), wrap with `Expanded`.

---

## 24. Container IDs

Every `Acl` container, row, and component can carry a string identifier. IDs enable external lookup, debugging, and scoping for groups and visibility.

### Setting IDs

| Level | Builder method | Data class field |
|---|---|---|
| Container | `setAclId(String id)` | `Acl.aclId` / `AclContainer.aclId` |
| Row | `setRowId(String id)` | `AclRow.id` |
| Component | `setId(String id)` | `AclComponent.id` |

```dart
AclBuilder(title: 'Address')
  ..setAclId('addressPanel')
  ..append(nameField)..setId('name')
  ..newRow()..setRowId('cityRow')
  ..append(cityField)..setId('city')
  ..append(zipField)..setId('zip')
  ..build()
```

### Full Tree ID Path

When containers are nested, the runtime ID is the dot-separated path from root to leaf:

```
addressPanel.name
addressPanel.cityRow
addressPanel.cityRow.city
addressPanel.cityRow.zip
```

### Scoping Rules

1. An `Acl` with `aclId` set creates a new **ID scope**. All child IDs must be unique within that scope.
2. An `Acl` without `aclId` propagates the parent scope — its children are addressed as if flattened into the parent's namespace.
3. Duplicate IDs within the same scope throw an `UnsupportedError` at build time.

### Accessing IDs from Widgets

Widgets inside an ACL layout can access their own ID and the container's ID via `AclScope.of(context)`:

```dart
final scope = AclScope.of(context);
final myId       = scope?.componentId;   // e.g. 'city'
final fullPath   = scope?.fullIdPath;    // e.g. 'addressPanel.cityRow.city'
final containerId = scope?.containerId;   // e.g. 'addressPanel'
```

`AclScope` is an `InheritedWidget` injected by `AclContainer` around each component. When no ID is set, the corresponding field is `null`.

---

## 25. Groups

Groups partition components, rows, and entire containers into named sets that can be shown, hidden, or disabled together.

### Defining Groups

| Scope | Method | Effect |
|---|---|---|
| Component range | `startGroup(String name)` / `endGroup()` | All components `append()`-ed between the calls belong to the group |
| Single component | `group(String name)` | Assigns the current component to the group |
| Entire container | `setAclGroup(String name)` | Every row and component of the `Acl` that names no group of its own belongs to the group |
| Entire row | `setRowGroup(String name)` | The current row belongs to the group |

```dart
AclBuilder()
  ..startGroup('premium')
  ..append(premiumField1)
  ..append(premiumField2)
  ..endGroup()
  ..newRow()
  ..append(basicField)..group('basic')
  ..build()
```

### Rules

1. Each component belongs to **at most one group**. Calling `group()` on a component that is already inside a `startGroup`/`endGroup` range overrides the range assignment.
2. `startGroup`/`endGroup` can span rows — the group assignment persists across `newRow()` calls.
3. `endGroup()` without a matching `startGroup()` throws.
4. Nested `startGroup()`/`startGroup()` without an intermediate `endGroup()` throws.
5. `setRowGroup()` assigns every component in the current row to the group (unless individually overridden by `group()`).
6. `setAclGroup()` is the outermost default: a component belongs to its own group, else its row's, else the container's. One call groups a whole container, and anything named more narrowly keeps its own group — for visibility, for the policy path, and for the group `AclScope` reports.

### Groups and Nested Containers

Groups do **not** cross container boundaries. Each `Acl` resolves its groups against its own `groupVisibilityControllers`: a nested `Acl`'s `setAclGroup('premium')` groups the components inside it, and only the nested container's own controllers act on them. To toggle a nested `Acl` as a unit from its parent, append it to the parent with `.group('premium')` and register the controller on the parent — to the parent it is one component like any other.

### Accessing Groups from Widgets

```dart
final scope = AclScope.of(context);
final myGroup = scope?.groupName;  // e.g. 'premium'
```

---

## 26. Group Visibility Control

Group visibility is controlled at the **root container** (or any container that owns the components). Each group name maps to a visibility controller that determines whether group members are shown, hidden, or disabled.

### Setting Controllers

```dart
AclBuilder()
  ..setGroupVisibilityController('premium', premiumController)
  ..setGroupVisibilityController('admin', adminController)
```

Builder method: `setGroupVisibilityController(String groupName, AclGroupVisibilityController controller)`

### AclGroupVisibilityController

```dart
abstract class AclGroupVisibilityController {
  /// Returns the current visibility mode for the group.
  AclGroupVisibilityMode get mode;

  /// Notifier that the layout listens to for reactive updates.
  ValueNotifier<AclGroupVisibilityMode> get modeNotifier;

  /// Dispose resources when the container is disposed.
  void dispose();
}

enum AclGroupVisibilityMode {
  /// Group is visible and interactive (default).
  visible,

  /// Group is hidden — components removed from layout (zero size, no paint).
  hidden,

  /// Group is disabled — components are visible but non-interactive
  /// (greyed out, ignores pointer events).
  disabled,
}
```

### Built-in Implementations

#### 1. Binary Controller (direct toggle)

For simple on/off visibility:

```dart
final premiumController = AclBinaryVisibilityController(
  initialMode: AclGroupVisibilityMode.hidden,
);

// Toggle later:
premiumController.mode = AclGroupVisibilityMode.visible;
```

#### 2. Callback Controller (computed from external state)

For visibility that depends on other values (e.g. a form field's content):

```dart
final showExtras = AclCallbackVisibilityController(
  valueListenable: countryController,   // ValueNotifier<String>
  modeBuilder: (country) => country == 'US'
      ? AclGroupVisibilityMode.visible
      : AclGroupVisibilityMode.hidden,
);
```

The `modeBuilder` callback receives the current value from the `ValueListenable<T>` and returns the appropriate mode. The controller automatically listens and rebuilds.

### Layout Behaviour

- **hidden**: Components are wrapped in `SizedBox.shrink()` — they occupy zero space. Gap rows before/after hidden content rows collapse. Row sizing recalculates as if the components don't exist.
- **disabled**: Components are wrapped in `IgnorePointer` + `Opacity(opacity: 0.4)`. They remain in the layout at full size but cannot receive focus or input.

---

## 26b. Hide on Authorization (`TomAuthState.none`)

Separate from group visibility, ACL supports **true removal** of components whose authorization state resolves to [TomAuthState.none](tom_ui_widgets_forms.md). The component is excluded from the row at build time and the layout re-computes without it — no zero-sized placeholder, no preserved gap slot.

The widget itself is **already** responsible for self-shrinking when it resolves to `none` (via `TomNodeBase`, `TomWidgetMixin`, `TomField`, `TomAclBuilder`, etc.). ACL's extension on top of that is to remove the component from the row's component list so the row re-flows.

### Opting in

| Scope | API | Default |
| --- | --- | --- |
| Container-wide | `AclBuilder.setAclDefaultHideUnauthorized(bool)` (and `TomAclBuilder.setAclDefaultHideUnauthorized`) | `false` |
| Per-component | `AclBuilder.setHideUnauthorized(bool?)` (chained after `append(...)`) | `null` → inherits container default |

When the effective flag is `true` **and** the appended widget is a [`TomAuthorizable`](tom_ui_widgets_forms.md) whose `effectiveAuthState` is `TomAuthState.none`, the component is dropped from the row.

### Gap semantics

The rule: a hidden component's **following** gap is the one that disappears — the gap handed to `append(next, dist:)` on the component *after* the hidden one.

Concretely, for a row `[a, b(hidden), c]`:

- `b` itself is removed.
- `b`'s own `gapBefore` (the gap between `a` and `b`) **is preserved** and is handed to `c`. `c` now sits in the exact horizontal slot `b` used to occupy.
- `c`'s own `gapBefore` (the gap between `b` and `c`, i.e. "the gap after `b`") is **dropped**.

For chains of hidden components `[a, h1, h2, c]`, only the first hidden component's `gapBefore` is carried forward. Intermediate hidden components' `gapBefore` is already "the gap after a previous hidden component" and gets dropped.

### Row elision

When every content component in a row gets dropped, the row is **elided** as if it never existed. The row-level rule mirrors the component-level rule:

- The elided row's own `gapBefore` (the gap between the previous content row and the elided one) is **preserved** and handed to the next content row.
- The next content row's own `gapBefore` ("the gap after the elided row") is **dropped**.

So a middle row being elided leaves the subsequent row positioned where the elided row would have started, not where the elided row would have ended.

### What's never touched

- **Gap rows** — always preserved.
- **Components whose child is not `TomAuthorizable`** — `hideUnauthorized` has no effect; the component is kept regardless.
- **Components whose effective auth is `full` / `read` / `disabled`** — hiding only applies to `none`.

### Not this mechanism: the id-based policy gates

A second, independent mechanism also removes elements, and conflating the two produces wrong predictions about the geometry. Rows and components carrying an `id` are resolved by path through `TomAuthorization.resolveAuth(...)` while the container builds its widgets — the row gate fires *before* the row's `gapBefore` is emitted, the component gate *after* its own gap has been. Those gates:

- are **not** governed by `hideUnauthorized` — that flag belongs to the pass described above and has no effect on them;
- fire for **any** child, `TomAuthorizable` or not, provided the element carries an `id` whose path resolves to `none`;
- run too late to rebuild a row, so they cannot forward a gap the way this pass does.

Their gap arithmetic is consequently the mirror image:

| Denied element | Reclaimed | Left behind |
| --- | --- | --- |
| Component | Its width only — `SizedBox.shrink()` takes its place. | **Both** adjacent gaps: its own, already emitted, and the next component's. |
| Row | The row height **and** the row's own `gapBefore`. | The next row's own `gapBefore`. |

Neither mechanism reserves space. There is no placeholder of the removed element's size in either case, so a layout whose geometry must survive a grant change cannot be built on either. `test/advanced_container_layout/acl_auth_visibility_test.dart` measures all four cases against a single fixture.

### Usage

```dart
TomAclBuilder(id: 'checkoutForm', elementProvider: form)
    .setAclDefaultHideUnauthorized(true)           // container default: hide any `none`
    .append((p) => p.fullName.widget)
    .newRow()
    .append((p) => p.email.widget)
    .append((p) => p.phone.widget, dist: 16)
    .setHideUnauthorized(false)                    // phone always stays, even if `none`
    .newRow()
    .append((p) => p.internalNotes.widget)         // `none` → whole row elided
    .build(context);
```

If `internalNotes` resolves to `none`, the row it sits in disappears entirely, and the subsequent row (if any) inherits its `gapBefore` to land where the hidden row would have started.

### Implementation notes

- Flag storage: `AclComponent.hideUnauthorized` (nullable), `AclContainer.defaultHideUnauthorized` (non-null).
- Filter pass: `_AclContainerState._applyAuthHiding` — runs after `_applyRowBreakpoints` and before `_runPreCalcLoop`, so every downstream computation (sizes, alignments, widget emission) sees the already-filtered rows.

### Coverage in the Tom widget catalogue

Every widget shipped from `tom_flutter_ui` already implements `TomAuthorizable` via one of:

- `TomNodeBase` → `TomPolicyNodeBase` → `TomFamilyBase` (buttons, inputs, selects, toggles, sliders, containers, dialogs, tables, labels, etc.).
- `TomWidgetMixin` (for widgets that extend Flutter types directly, e.g. `TomAppBar`).
- `TomField<T>` (form fields), wrapped by the internal `TomFieldWidgetAdapter` so that the widget returned by `field.widget` surfaces the field's own `effectiveAuthState` to ACL.

That means `setAclDefaultHideUnauthorized(true)` works uniformly whether the appended child is a regular Tom widget, a form field, or a Classic-era field — all route through the same ACL filter.

---

## 27. Responsive Variants (B3)

Responsive variants allow a container to switch between completely different row trees based on available width. Unlike per-component breakpoints, B3 replaces the **entire layout** at the container level — rows, ordering, sizing, everything.

### Definition

```dart
AclBuilder()
  ..setAclId('userForm')
  // Default layout (widest)
  ..append(nameField)..append(emailField)..append(phoneField)
  ..newRow()
  ..append(saveButton)

  // Tablet variant: 2 fields per row
  ..addVariant('tablet', atWidth: 600, (b) => b
    ..append(nameField)..append(emailField)
    ..newRow()
    ..append(phoneField)
    ..newRow()
    ..append(saveButton)
  )

  // Mobile variant: 1 field per row
  ..addVariant('mobile', atWidth: 400, (b) => b
    ..append(nameField)
    ..newRow()
    ..append(emailField)
    ..newRow()
    ..append(phoneField)
    ..newRow()
    ..append(saveButton)
  )
  ..build()
```

### Variant Selection

At layout time, the container checks `availableWidth` against variant thresholds (sorted descending). The first variant whose `atWidth` is ≥ `availableWidth` is selected. If none match, the default layout is used.

```
availableWidth = 450  →  tablet (600 > 450, but mobile 400 ≤ 450) →
                         actually: variants sorted desc by atWidth → 
                         check 600: 450 < 600 → tablet applies
```

More precisely: variants are checked from **largest `atWidth` to smallest**. The first variant whose `atWidth > availableWidth` is selected. If no variant's threshold exceeds `availableWidth`, the default layout is used.

### Builder method

```dart
AclBuilder addVariant(String name, {required double atWidth, required void Function(AclBuilder) builder})
```

The callback receives a **fresh** `AclBuilder`, and *fresh* is literal: it inherits nothing from the parent builder. Every `setAclDefault*` value — append gap, row gap, row height, both row alignments, flags, unknown preferred size, unknown minimum size — starts at its framework default inside the callback and must be restated if the variant needs it.

Container-level settings (border, padding, background, title) are unaffected by which variant is active, but not because the variant builder inherits them: they belong to the container, and a variant supplies only rows. Setting them inside the callback therefore does nothing.

```dart
..addVariant('narrow', atWidth: 480, builder: (b) => b
    ..setAclDefaultAppendGap(16)   // restate — not inherited
    ..append(street)
    ..newRow()
    ..append(number))
```

`test/advanced_container_layout/acl_variant_inheritance_test.dart` pins what is inherited and what is dropped.

### Nesting

Variants can be defined on nested `Acl` containers independently. The outer container and inner container each select their variant based on their own `availableWidth`. This means a sidebar may keep its layout while the main content area switches variants.

---

## 28. Row Breakpoints

Row breakpoints provide a lighter-weight responsive mechanism than full variants: a single row can split into multiple rows when the container width drops below a threshold.

### Definition

Breakpoints are **positional** — call `addRowBreakpoint()` between `append()` calls to indicate where the row should break. The split index is calculated automatically from the number of components appended so far.

```dart
AclBuilder()
  ..append(field1, dist: 8)..append(field2, dist: 8)
  ..addRowBreakpoint(atWidth: 600)  // split here when width < 600
  ..append(field3, dist: 8)..append(field4, dist: 8)
  ..build()
```

At runtime:
- `availableWidth ≥ 600`: one row `[field1][field2][field3][field4]`
- `availableWidth < 600`: two rows `[field1][field2]` / `[field3][field4]`

### Builder method

```dart
AclBuilder addRowBreakpoint({required double atWidth, double splitRowDist = 0})
```

| Parameter | Meaning |
|---|---|
| `atWidth` | Width threshold in pixels. Below this, the split activates. |
| `splitRowDist` | Vertical gap before the new split row (default 0). |

The split position is determined by the number of components already appended when the method is called. Use `dist:` on the **first** component as well so that spacing remains consistent when a row is split.

### Multiple Breakpoints

Multiple breakpoints can be placed at different positions in the builder chain:

```dart
..append(a, dist: 8)
..addRowBreakpoint(atWidth: 400)          // below 400: [a] / [b c d]
..append(b, dist: 8)
..addRowBreakpoint(atWidth: 800)          // below 800: [a b] / [c d]
..append(c, dist: 8)..append(d, dist: 8)
```

Breakpoints are evaluated from **smallest `atWidth` to largest**. Each active breakpoint inserts an additional row break. The result is cumulative.

### Interaction with Groups and Visibility

Row breakpoints operate on the **visible** component list. Hidden group members are removed before breakpoint logic runs. This ensures split indices remain stable regardless of visibility state.

---

## 29. Inline Component Variants

Inline component variants allow **different components within the same row** to appear based on device context (width, platform, input mode, etc.). Unlike `addVariant` (§27) which replaces the entire row tree, and `addRowBreakpoint` (§28) which splits rows, inline variants tag individual components so only the matching set is included at layout time.

### AclDeviceContext

A snapshot of the current device and layout environment, resolved from Flutter's `BuildContext` at layout time:

| Field | Type | Source |
|---|---|---|
| `width` | `double` | Available container width from `LayoutBuilder` |
| `height` | `double?` | Available container height (null if unbounded) |
| `inputMode` | `AclInputMode` | Derived from platform alone: iOS/Android → touch; macOS/Windows/Linux/Fuchsia → pointer. A web target reports the platform it runs on, so a phone browser resolves to touch |
| `formFactor` | `AclFormFactor` | Derived from width: < 600 → phone; < 1024 → tablet; ≥ 1024 → desktop |
| `orientation` | `Orientation` | From `MediaQuery.of(context).orientation` |
| `platform` | `TargetPlatform` | From `Theme.of(context).platform` |
| `isWeb` | `bool` | From `kIsWeb` |
| `density` | `AclDensity` | From `Theme.of(context).visualDensity`: avg ≤ −1.5 → compact; ≤ −0.5 → comfortable; else standard |
| `textDirection` | `TextDirection` | From `Directionality.of(context)` |
| `accessibilityScale` | `double` | From `MediaQuery.of(context).textScaler.scale(1.0)` |

```dart
factory AclDeviceContext.of(BuildContext context, {required double width, double? height})
```

### AclVariantDetector

A function that determines whether an inline variant block should be active:

```dart
typedef AclVariantDetector = bool Function(
  AclDeviceContext deviceContext,
  Acl? acl,            // nearest ancestor Acl, or null if using AclLayout directly
  BuildContext context,
);
```

When provided via the `detector` parameter on `startVariant()`, it **fully overrides** all convenience parameters. The `Acl?` parameter gives access to the container widget for advanced scenarios; it is `null` when the layout is built via `AclLayout` without an `Acl` wrapper.

### API

```dart
AclBuilder startVariant({
  // Convenience parameters (combined with AND logic):
  double? width,
  double? height,
  AclInputMode? input,
  AclFormFactor? formFactor,
  Orientation? orientation,
  Set<TargetPlatform>? platforms,
  bool? isWeb,
  AclDensity? density,
  TextDirection? textDirection,
  double? minAccessibilityScale,
  // Custom detector (overrides all convenience parameters):
  AclVariantDetector? detector,
})

AclBuilder endVariant()
```

When **no parameters** are specified, the variant is the **default** — shown when no other detector matches.

### Convenience Parameters — Complete Reference

| # | Parameter | Type | Matching Logic |
|---|---|---|---|
| 1 | `width` | `double?` | Active when `deviceContext.width < width` |
| 2 | `height` | `double?` | Active when `deviceContext.height != null && deviceContext.height < height` |
| 3 | `input` | `AclInputMode?` | Active when `deviceContext.inputMode == input` |
| 4 | `formFactor` | `AclFormFactor?` | Active when `deviceContext.formFactor == formFactor` |
| 5 | `orientation` | `Orientation?` | Active when `deviceContext.orientation == orientation` |
| 6 | `platforms` | `Set<TargetPlatform>?` | Active when `platforms.contains(deviceContext.platform)` |
| 7 | `isWeb` | `bool?` | Active when `deviceContext.isWeb == isWeb` |
| 8 | `density` | `AclDensity?` | Active when `deviceContext.density == density` |
| 9 | `textDirection` | `TextDirection?` | Active when `deviceContext.textDirection == textDirection` |
| 10 | `minAccessibilityScale` | `double?` | Active when `deviceContext.accessibilityScale >= minAccessibilityScale` |

Note that `width` and `height` are **exclusive upper** bounds while
`minAccessibilityScale` is an **inclusive lower** one — the two numeric facets
point in opposite directions, and nothing in the parameter list says so.

#### The consequence of an unknown height

Row 2 is the only facet whose input can be absent, and its `!= null` clause has
a reach that the row alone does not convey. `AclDeviceContext.height` is `null`
whenever the container's incoming constraints have unbounded height — that is,
whenever it shrink-wraps, which is the ordinary case inside a `Column`, a
`ListView`, or any scrollable. An absent height does not mean "no constraint on
this axis" and does not fall back to a default: it **fails** the facet, and
because the facets are ANDed it vetoes the whole variant however well every
other facet fits.

So **a variant gated on `height` never activates in a shrink-wrapping
container**, and the row silently falls back to its default variant. That is the
intended degradation — an unbounded height is not a *short* one — but an author
who has not been told will read the missing variant as a bug in their own
layout. Give the container a bounded height (`SizedBox`, `Expanded`,
`Flexible`) when a height-gated variant is meant to fire.

`width` carries no equivalent hazard: it is non-nullable, and the container
builds no device context at all when the *horizontal* axis is unbounded — in
which case no detector is evaluated and the default variant shows.

### Combination Rules

When multiple convenience parameters are specified, they combine with **AND** logic — **every** condition must be true for the variant to be active.

```dart
// Active when width < 500 AND touch input AND on iOS or Android
.startVariant(width: 500, input: AclInputMode.touch, platforms: {TargetPlatform.iOS, TargetPlatform.android})
```

Any subset of the 10 parameters can be combined. The `detector` parameter, when provided, replaces all convenience logic entirely.

### Common Multi-Dimension Patterns

#### Width + Device Characteristic

| Pattern | Parameters | Use Case |
|---|---|---|
| Narrow touch | `width: 500, input: AclInputMode.touch` | Simplified touch layout below 500px |
| Narrow phone | `width: 500, formFactor: AclFormFactor.phone` | Phone-specific narrow layout |
| Mobile narrow | `width: 400, platforms: {TargetPlatform.iOS, TargetPlatform.android}` | Native mobile narrow layout |
| Web narrow | `width: 600, isWeb: true` | Web-specific responsive breakpoint |

#### Platform + Input

| Pattern | Parameters | Use Case |
|---|---|---|
| Touch mobile | `input: AclInputMode.touch, platforms: {TargetPlatform.iOS, TargetPlatform.android}` | Native touch apps |
| Desktop pointer | `input: AclInputMode.pointer, isWeb: false` | Native desktop apps |
| Desktop browser | `input: AclInputMode.pointer, isWeb: true` | A browser on a pointer device. `isWeb` alone no longer implies a pointer, so the pair is what names it |

#### Form Factor + Orientation

| Pattern | Parameters | Use Case |
|---|---|---|
| Tablet portrait | `formFactor: AclFormFactor.tablet, orientation: Orientation.portrait` | iPad/tablet portrait layout |
| Phone landscape | `formFactor: AclFormFactor.phone, orientation: Orientation.landscape` | Phone landscape layout |

#### Density + Size

| Pattern | Parameters | Use Case |
|---|---|---|
| Compact narrow | `width: 400, density: AclDensity.compact` | Space-constrained compact layout |
| Standard wide | `density: AclDensity.standard, formFactor: AclFormFactor.desktop` | Spacious desktop layout |

#### Accessibility

| Pattern | Parameters | Use Case |
|---|---|---|
| Large text narrow | `width: 600, minAccessibilityScale: 1.5` | Simplified layout for large text at narrow widths |
| Large text | `minAccessibilityScale: 2.0` | Drastically simplified layout for very large text |

#### Text Direction

| Pattern | Parameters | Use Case |
|---|---|---|
| RTL narrow | `textDirection: TextDirection.rtl, width: 500` | RTL-specific narrow layout |
| RTL phone | `textDirection: TextDirection.rtl, formFactor: AclFormFactor.phone` | RTL phone layout |

### Parameter Overlaps and Redundancies

| Overlap | Explanation |
|---|---|
| `width` + `formFactor` | `formFactor` is derived from width (< 600 = phone, < 1024 = tablet). Combining them narrows the match further — e.g., `width: 400, formFactor: AclFormFactor.phone` matches only phone-width containers below 400px. |
| `input` + `platforms` | `inputMode` is derived from platform by default. Combining them is redundant for native apps but useful for web where input mode doesn't follow platform. |
| `platforms` + `isWeb` | `isWeb: true` with a specific platform set matches web apps detected as that platform (e.g., web on iOS Safari reports `TargetPlatform.iOS`). `isWeb: false` with platforms restricts to native apps. |

### Contradictory Combinations (valid but may never match)

| Pattern | Why |
|---|---|
| `formFactor: AclFormFactor.phone, width: 800` | Phone form factor requires width < 600, but the variant requires width < 800 — the `formFactor` constraint is always the limiting factor. |
| `input: AclInputMode.touch, platforms: {TargetPlatform.macOS}` | macOS defaults to pointer input. Matches only if a custom `AclDeviceContext` overrides input mode. |

### Rules

1. **No nesting.** Calling `startVariant()` while already inside a variant block throws.
2. **`endVariant()` required.** Every `startVariant()` must be closed before `newRow()` or `build()`.
3. **Components outside any variant block are always visible** regardless of context.
4. **Multiple variants per row.** A single row can contain any number of `startVariant/endVariant` blocks with different detectors.
5. **First-match selection.** Detectors are evaluated in **declaration order** (order of `startVariant()` calls). The first detector returning `true` wins. If no detector matches, the default variant (no parameters) is used.

### Selection Algorithm

For each row containing inline variant components:

1. Collect unique variant detectors in declaration order (by identity).
2. Evaluate non-default detectors (non-null) in order against the current `AclDeviceContext`.
3. **First detector returning `true`** → active variant; show those components.
4. If **no detector matches** → show default variant components (those with no detector / no parameters).
5. Components **not** in any variant block are **always** included regardless of selection.

### Example: Width-Based Variants

```dart
AclBuilder()
  .append(const SizedBox(width: 80, child: Text('Name:')))
  // Wide: two fields side by side
  .startVariant()
  .append(firstNameField, dist: 8).expandX()
  .append(lastNameField, dist: 8).expandX()
  .endVariant()
  // Narrow: single combined field
  .startVariant(width: 500)
  .append(fullNameField, dist: 8).expandX()
  .endVariant()
  .newRow(dist: 8)
  .append(const SizedBox(width: 80, child: Text('Email:')))
  .append(emailField, dist: 8).expandX()
  .build()
```

At `availableWidth = 700`: label + firstName + lastName.
At `availableWidth = 400`: label + fullName.
The second row (Email) has no inline variants and is always shown.

### Example: Form-Factor Variants

```dart
AclBuilder()
  .append(const Text('Device:'))
  .startVariant(formFactor: AclFormFactor.phone)
  .append(phoneWidget, dist: 8).expandX()
  .endVariant()
  .startVariant(formFactor: AclFormFactor.tablet)
  .append(tabletWidget, dist: 8).expandX()
  .endVariant()
  .startVariant()
  .append(desktopWidget, dist: 8).expandX()
  .endVariant()
  .build()
```

### Example: Custom Detector

```dart
AclBuilder()
  .startVariant(detector: (dc, acl, ctx) => dc.width < 600 && dc.inputMode == AclInputMode.touch)
  .append(touchNarrowWidget)
  .endVariant()
  .startVariant()
  .append(defaultWidget)
  .endVariant()
  .build()
```

### Interaction with Other Features

- **Groups/Visibility**: Components inside a variant block can also belong to groups. Group visibility is applied **after** variant filtering.
- **addVariant (§27)**: Full-layout variants take precedence — inline variants only apply within the rows currently selected by `addVariant` (or the default rows).
- **Row Breakpoints (§28)**: Breakpoints apply to the **post-variant-filtered** component list. Split positions refer to visible component positions.

### Data Model

Each `AclComponent` carries two fields:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `inlineVariant` | `bool` | `false` | Whether this component is inside a variant block |
| `variantDetector` | `AclVariantDetector?` | `null` | Detector function; null = default variant |

Components with `inlineVariant == false` are always included. Components with `inlineVariant == true` are included only when their detector is the active one for that row.

---

## 30. Layout Direction (RTL/LTR)

By default, ACL lays out components left-to-right. Setting the layout direction to RTL mirrors the entire layout: components flow right-to-left, alignment semantics flip, and horizontal offsets are negated.

### API

```dart
AclBuilder setAclDirection(AclDirection direction)
```

```dart
enum AclDirection { ltr, rtl }
```

The default is `AclDirection.ltr`. Setting `AclDirection.rtl` causes:

1. **Component order within rows** — rendered right-to-left (first component on the right).
2. **Row alignment** — `RowAlignment.left` starts from the right; `RowAlignment.right` starts from the left.
3. **Horizontal alignment offsets** — `alignX*` cross-row deltas and `Transform.translate` horizontal offsets are negated.
4. **Padding** — `left`/`right` extra padding swaps sides.
5. **Border kinds** — `AclBorderKind.left` and `AclBorderKind.right` are visual (do **not** flip); the developer chooses the physical side.

### Implementation

The layout engine wraps each row's `Row` widget inside a `Directionality(textDirection: TextDirection.rtl, ...)` widget. Flutter's `Row` natively reverses child order and alignment mapping under RTL directionality:

- `MainAxisAlignment.start` → right-aligned
- `MainAxisAlignment.end` → left-aligned
- Children render from right to left

Horizontal `Transform.translate` offsets and alignment deltas are negated so cross-row references continue to point to the correct visual positions.

### Example

```dart
AclBuilder()
  .setAclDirection(AclDirection.rtl)
  .append(const Text('Name:'))
  .append(nameField, dist: 8).expandX()
  .newRow(dist: 8)
  .append(const Text('Email:'))
  .append(emailField, dist: 8).expandX()
  .build()
```

The label "Name:" appears on the right; the field expands to the left.

### Data Model

| Field | Type | Default | Location |
|---|---|---|---|
| `direction` | `AclDirection` | `AclDirection.ltr` | `AclContainer`, `AclLayout`, `Acl` |

---

## 31. TomAclBuilder — Element Provider, Authorization, Resources, and Form Layout

### Motivation

The base `AclBuilder` is a pure layout engine — it arranges arbitrary Flutter widgets in rows and columns. It has no concept of authorization, text resources, or typed screen elements.

`TomAclBuilder<T>` is a **delegating wrapper** around `AclBuilder` that adds:

- **Typed element access** — `(T p) => p.someField` against a `TomScreenElementsProvider`.
- **Container-level authorization** — on `build(context)` the container is hidden when `TomAuthorization.resolveAuth(containerPath)` evaluates to `TomAuthState.none`, and wrapped in the theme's read-only style for `TomAuthState.read`.
- **Resource-driven container chrome** — title, padding, background, title style, border style, focused border style, title position / border alignment / vertical offset all fall back to `TomCtr.*` lookups at `containerPath` when no explicit constructor value was provided.

The wrapper is in `tom_flutter_ui/lib/src/widgets/containers/acl/tom_acl.dart`.

### Design: Delegation, Not Inheritance

`TomAclBuilder<T>` holds a private `AclBuilder _builder` and forwards every layout call to it — it does **not** subclass `AclBuilder`. That keeps:

- `AclBuilder` unchanged and independently usable in non-Tom code paths.
- All layout logic in one place.
- Tom-specific concerns (auth, resources, element provider, readonly style) strictly layered on top.

### TomScreenElementsProvider

Marker interface that restricts the generic type `T` on `TomAclBuilder<T>`:

```dart
abstract interface class TomScreenElementsProvider {}
```

Any `TomClass` or `TomForm` that implements `TomScreenElementsProvider` (or inherits the implementation) can be the element provider. A form like `CustomerForm` qualifies, so the typed lambda lets you reach into its fields directly.

### TomAclBuilder Constructor

```dart
TomAclBuilder({
  required String id,
  bool idScope = false,                     // true → container contributes
                                            //   its ID to descendant paths.
  required T elementProvider,
  String? title,                            // any of these, when null,
  Widget? titleWidget,                      //   fall back to TomCtr.* at
  AclBorderStyle? borderStyle,              //   <scopePath>.<id>.<suffix>.
  AclBorderStyle? focusedBorderStyle,
  EdgeInsetsGeometry? padding,
  Color? backgroundColor,
  TextStyle? titleStyle,
  AclTitlePosition? titlePosition,
  AclTitleBorderAlign? titleBorderAlign,
  double? titleVerticalOffset,
});
```

### Element Placement

```dart
TomAclBuilder<T> append     (Widget Function(T p) selector, {double dist = 0});
TomAclBuilder<T> appendForm (Widget Function(T p) selector, {double dist = 0});
TomAclBuilder<T> appendMasterDetail({
  required Widget Function(T p) master,
  required Widget Function(T p) detail,
});
```

### Delegated AclBuilder surface

Row + flow: `newRow`, `setRowHeight`, `gap`, `gapRow`.
Expand / alignment: `expandX`, `expandY`, `expand`, `setRowHorizontalAlignment`, `setRowVerticalAlignment`, plus all per-component alignment helpers (`alignTopInRow` / `alignBottomInRow` / `setVerticalAlignment`, cross-row `alignXxx` / same-row `alignYxx`).
Sizing: `setPSize` / `setMSize` / `setXSize`, `setPWidthInChars` / `setMWidthInChars` / `setXWidthInChars`, `sameWidthAs` / `sameHeightAs` / `sameSize`, `setComp` / `setAttr` / `clearAttr`.
Defaults on the container: `setAclExpandXDefault`, `setAclDefaultRowAlignment`, `setAclDefaultAppendGap`, `setAclDefaultRowGap`, etc.
Groups / variants / responsive: `setGroup`, `onlyVisibleWhen`, `variant`, `rowBreakpoint`, direction scopes.

### Container-Level Authorization

`build(BuildContext context)` runs this sequence:

```dart
final scopePath = TomScope.current.getScopePath();
final containerPath = scopePath.isNotEmpty ? '$scopePath.$id' : id;

final auth = TomAuthorization.resolveAuth(containerPath);
if (!auth.isVisible) return const SizedBox.shrink();   // TomAuthState.none
// … resource-driven chrome fallbacks …
return TomThemeScope.applyAuthState(context, auth, _builder.build);
```

The early return for `none` is redundant with `applyAuthState`'s own `none`
branch and is kept anyway, because it also skips the resource resolution above
— there is no point reading a title for a container that will not be painted.

So a `TomAclBuilder`:

- **`none`** on its path → the whole container (rows, fields, title) disappears without a layout slot.
- **`read`** / **`disabled`** → the children render, but the theme's `TomStateStyle` for that state (default `AbsorbPointer` + `Opacity(0.6)` / `Opacity(0.38)`) dims and blocks interaction at the container boundary. Routing through `applyAuthState` rather than a per-state branch is what keeps `disabled` enforced: it is `isVisible`, so a gate that only reacts to `read` would hand a withheld container to the user fully live.
- **`full`** → delegated to each child. `TomField`'s own `resolveEffectiveAuth` does the per-field narrowing via resource path + group + form + authorizer + UI-state controller (see [tom_ui_widgets_forms.md §19](tom_ui_widgets_forms.md)).

Because the container check uses `<scopePath>.<id>`, you drive it by setting a rule in whatever `TomAuthorizationAdapter` the app installs — e.g. Demo B's `_DemoBAdapter` flips the form-level `demoB.customer` entry to narrow every descendant at once.

### Resource Fallbacks

Any chrome argument left `null` on the constructor is looked up at build time:

| Property | Resource key (suffix) |
| --- | --- |
| `title` | `title` (string; a resource that still echoes the missing-key fallback is ignored) |
| `padding` | `padding` (`EdgeInsets`) |
| `backgroundColor` | `backgroundColor` (`Color`) |
| `titleStyle` | `titleStyle` (`TextStyle`) |
| `borderStyle` / `focusedBorderStyle` | `borderStyle` / `focusedBorderStyle` maps with `kind`, `color`, `lineWidth`, `rounded` |
| `titlePosition` | `titlePosition` |
| `titleBorderAlign` | `titleBorderAlign` |
| `titleVerticalOffset` | `titleVerticalOffset` (`double`) |

All lookups happen against `<scopePath>.<id>.<suffix>` via `TomCtr`.

### Laying out a form so fields stay aligned

The Tom Forms Framework renders each field as a vertical anatomy column (label → input → error → description, with optional swap-placement). When a field goes into error its column grows; a multi-row form should handle that growth gracefully.

Rules of thumb:

1. **Pick a sensible row alignment.** The current default for every new `AclBuilder` / `TomAclBuilder` is `AclRowCrossAlignment.top` (§11). That keeps every field anchored to the row's top edge, so a tall field with an error does **not** pull its neighbours down. Setting `setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)` is specifically the case that "breaks" — neighbours drift when the row grows. Leave the default unless you really want every field centred on the row's vertical middle.
2. **Expand one column or all of them — don't mix.** `setAclExpandXDefault(true)` makes every appended field grow to share the available width. Two-per-row layouts (`email + phone`) want this so both fields have the same width; otherwise use explicit `setPSize` / `setPWidthInChars` and keep widths consistent per semantic column.
3. **Lock widths across rows with `sameWidthAs`.** When you need a "dropdown column" and a "text column" to line up across rows, drop an anchor component on the first row and reference it from subsequent rows — e.g. `.append(firstField).setAclId('nameCol')` then later `.append(other).sameWidthAs('nameCol')`.
4. **Use `appendForm` / `append` uniformly.** Both delegate to the same `AclBuilder.append`. Pick one for legibility; mixing them in the same layout hides intent.
5. **Nest forms via nested TomAclBuilders, not ad-hoc Columns.** For a `CustomerForm` with nested `AddressForm`s (Demos B and C), one `TomAclBuilder` per form keeps each section's IDs, auth, and resources independent. The sections can still share `sameWidthAs` references when alignment across sections matters.

A typical layout looks like:

```dart
TomAclBuilder(
  id: 'customerForm',
  elementProvider: form,
)
  .setAclDefaultRowAlignment(AclRowCrossAlignment.top)  // redundant — matches default
  .setAclExpandXDefault(true)
  .append((p) => p.fullName.widget)
  .newRow()
  .append((p) => p.email.widget)
  .append((p) => p.phone.widget, dist: 16)               // two on one row
  .newRow()
  .append((p) => p.customerTier.widget)
  .newRow()
  .append((p) => p.notes.widget)
  .build(context);
```

### JSON-ACL Support (future)

`TomAclBuilder` is designed to support building from JSON layout definitions. Element references in JSON correspond to field names on the `@tomReflector`-annotated provider class. The API below is aspirational; the runtime is not yet in tom_flutter_ui.

```dart
return TomAclBuilder<LoginScreenElements>(
  id: 'loginScreen',
  elementProvider: LoginScreenElements(),
).buildFromJson(layoutJson);
```

```json
{
  "containerId": "loginScreen",
  "rows": [
    { "elements": [{ "ref": "greeting" }] },
    { "elements": [{ "ref": "loginForm", "type": "form" }], "dist": 24 },
    {
      "elements": [
        { "ref": "cancelButton", "style": "secondary" },
        { "ref": "loginButton", "style": "primary" }
      ],
      "dist": 16
    }
  ]
}
```

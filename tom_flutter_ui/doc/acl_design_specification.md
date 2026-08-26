# Advanced Container Layout (ACL) — Design Specification

*Part of the [Tom Flutter UI documentation set](README.md).*

**Package:** `tom_flutter_ui`  
**Class:** `Acl` (widget) / `AclBuilder` (fluent builder)  
**Last updated:** 2026-03-14

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
- On a **scrollable axis**, `gap()` slots (horizontal) and `gapRow()` slots (vertical) receive **zero size** — they collapse. Elastic distribution is meaningless when content can overflow.
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

### `setAclDefaultAppendGap(int pixels)`

Sets a fixed horizontal gap (in pixels) inserted before each appended component. This is a convenience for the common pattern of calling `.append(widget, dist: 16)` on every field. The default applies to **all** components in the row, including the first. The default only takes effect when the individual `append()` call specifies `dist: 0` (the default). An explicit `dist` always wins. The built-in gap is **8**; pass 0 to disable it.

### `setAclDefaultRowGap(int pixels)`

Sets a fixed vertical gap (in pixels) inserted before each new content row started with `newRow()`. Only applies when the individual `newRow()` call specifies `dist: 0` (the default). An explicit `dist` always wins. The built-in gap is **8**; pass 0 to disable it.

### `setAclDefaultUnknownMinimumSize(double width, [double height = 0])`

Sets a default minimum size for components that lack an explicit `setMSize` / `setMWidthInChars` call. Pass `0` for width or height to leave that dimension untouched (no default minimum on that axis).

**Minimum ≤ preferred invariant:** The minimum size can never exceed the preferred size. If a minimum is set that is larger than the current preferred size, the preferred size is automatically raised to match the minimum.

**Interaction with the sizing phases:** When minimum < preferred (the normal case), space is distributed to **all** components proportionally based on the ratio `(preferred / minimum) − 1` until every non-expandX component has reached its preferred size. After that, remaining space goes **exclusively** to expandX components, again distributed by their `(preferred / minimum) − 1` ratio. If no expandX components exist in the row, all components keep growing proportionally (bounded by their maximum size, if set).

### `setAclDefaultUnknownPreferredSize(double width, [double height = 0])`

Replaces the built-in 150 × 0 default preferred size for components without an explicit `setPSize` / `setPWidthInChars`. Pass `0` for width to keep the built-in 150 px default; pass `0` for height to keep height unconstrained.

### Zero-means-untouched convention

The two **size** setters above (and the per-component size methods) follow the convention that **width = 0** or **height = 0** means "don't touch this dimension — use whatever default or previous value applies."

The two **gap** setters do not, and the difference is deliberate: a gap of 0 is a meaningful value, so `setAclDefaultAppendGap(0)` and `setAclDefaultRowGap(0)` take it literally and switch the gap off rather than falling back to the built-in 8. `test/advanced_container_layout/acl_builder_defaults_test.dart` pins both conventions against each other.

### Example

```dart
final acl = AclBuilder()
  ..setAclExpandXDefault(true)              // all fields expand
  ..setAclDefaultAppendGap(16)              // 16 px before each field
  ..setAclDefaultRowGap(12)                 // 12 px between rows
  ..setAclDefaultUnknownPreferredSize(200)  // wider default than 150
  ..append(nameField)                       // expandX, 16 px gap (auto)
  ..append(industryField)                   // expandX, 16 px gap (auto)
  ..newRow()                                // 12 px gap (auto)
  ..append(emailField)
  ..append(phoneField, dist: 24)            // explicit 24 px overrides default 16
  ..build();
```

---

## 6. Row Sizing — Three Phases

Each content row is sized independently before cross-row constraints are applied.

```
Phase 1 — Shrink to preferred
─────────────────────────────
If Σ preferred > availableWidth:

  shrinkable = components without alignXToKey, Flexible, or Expanded
  shrinkCap  = Σ (preferred[i] − minimum[i])  [default min = preferred]
  ratio      = (Σ preferred − availableWidth) / shrinkCap
  fitted[i]  = preferred[i] − (preferred[i] − minimum[i]) * ratio

Phase 2 — Grow to preferred
────────────────────────────
If Σ fitted < availableWidth and any fitted[i] < preferred[i]:

  Grow under-preferred components toward preferred
  (pro-rata on the deficit)

Phase 3 — Fill remaining space beyond preferred
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

  Phase 1/2: Label=90, Field=96
  Phase 3 Option B: surplus=314 → all given to Field (expandX)
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

When no `gap()` slots are present, `setRowAlignment` / `setRowAlignLeft()` / `setRowAlignCenter()` / `setRowAlignRight()` controls row justification as before.

---

## 8. Vertical Gap Rows — `gapRow({double weight = 1, AclSeparator? separator})`

`gapRow()` inserts an elastic vertical spacer between content rows. It cannot contain components. Calling it implicitly starts a new content row, so no `newRow()` call is needed afterwards.

```
Remaining vertical = containerHeight − Σ content_row_heights
gapRow[i] height   = remaining × weight[i] / Σ weights
```

In scrollable-Y mode, all gap rows collapse to 0.

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

## 11. Row Cross-Alignment (per-component vertical baseline)

When `alignYToKey` is **not** set, a component's vertical position within the row is controlled by its `rowCrossAlignment`:

| Method | Alignment |
|---|---|
| `alignTopInRow()` | top edge of row |
| `alignMiddleInRow()` | vertically centred (default) |
| `alignBottomInRow()` | bottom edge of row |

This is the standard Flutter Row cross-axis alignment applied per component.

---

## 12. Size Reference Constraints

These make one component adopt the **rendered** size of another. They are dynamic: if the referenced component's size changes during iterative settling, the constrained component updates in the next pass.

| Method | Effect |
|---|---|
| `sameWidthAs(ref)` | width = ref's rendered width |
| `sameHeightAs(ref)` | height = ref's rendered height |
| `sameSize(ref)` | both dimensions |

**Rule:** `ref` must have been declared earlier in the builder — forward references throw.

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
proportionally to fill any available surplus (Phase 3 Option C above).
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
Phase 0 — Collect natural sizes  (render tree, once per build)
  ∙ For every natural-sized component, read its cached measured size
    from the GlobalKey render tree (cached from the previous frame).
  ∙ If not yet measured (first frame), use 0×0 as initial estimate.
  ∙ This is the ONLY point where the Flutter render tree is consulted
    for sizing; all subsequent work is pure Dart.

Phase 1..N — Iterative pre-calculation loop  (pure Dart, no Flutter paint)
  For each iteration:
    1. Compute fitted widths for each row (3-phase algorithm, Section 6)
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

Phase 2 — Single Flutter layout pass
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

## 15. Back-Reference Rule

Any reference passed to `alignXxx`, `alignYxx`, `sameWidthAs`, `sameHeightAs`, or `sameSize` must refer to a widget that was `append()`-ed **earlier** in the same `AclBuilder` call chain. The builder tracks declarations in order; a forward reference (the referenced widget has not been appended yet) throws an `UnsupportedError` with a descriptive message at build time.

References are passed as the **`Widget` instance directly** — the builder maps each appended widget to an auto-generated `GlobalKey` via an identity map. Passing a raw `Key` object is not supported.

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

### Constructor

```dart
AclBuilder({
  String? title,
  AclBorderStyle borderStyle = const AclBorderStyle.none(),
  AclBorderStyle? focusedBorderStyle,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  Color? backgroundColor,
  TextStyle? titleStyle,
  AclTitlePosition titlePosition = AclTitlePosition.topLeft,
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

```dart
// Start a new content row
AclBuilder newRow({double dist = 0})

// Insert an elastic vertical gap row; implicitly starts a new content row
AclBuilder gapRow({double weight = 1})
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

```dart
AclBuilder setPSize(double width, double height)          // preferred
AclBuilder setMSize(double width, double height)          // minimum
AclBuilder setXSize(double width, double height)          // maximum
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

```dart
AclBuilder sameWidthAs(Object reference)
AclBuilder sameHeightAs(Object reference)
AclBuilder sameSize(Object reference)
```

### Per-component row cross-alignment (mutually exclusive with alignYxx)

```dart
AclBuilder alignTopInRow()
AclBuilder alignMiddleInRow()
AclBuilder alignBottomInRow()
```

### Cross-row horizontal alignment (reference must be in a different row)

```dart
AclBuilder alignLeftToLeft(Object reference,   {double gap = 0})
AclBuilder alignLeftToCenter(Object reference, {double gap = 0})
AclBuilder alignLeftToRight(Object reference,  {double gap = 0})
AclBuilder alignCenterToLeft(Object reference,   {double gap = 0})
AclBuilder alignCenterToCenter(Object reference, {double gap = 0})
AclBuilder alignCenterToRight(Object reference,  {double gap = 0})
AclBuilder alignRightToLeft(Object reference,   {double gap = 0})
AclBuilder alignRightToCenter(Object reference, {double gap = 0})
AclBuilder alignRightToRight(Object reference,  {double gap = 0})
```

### Same-row vertical alignment (reference must be in same row; mutually exclusive with alignTopInRow etc.)

```dart
AclBuilder alignTopToTop(Object reference,      {double gap = 0})
AclBuilder alignTopToMiddle(Object reference,   {double gap = 0})
AclBuilder alignTopToBottom(Object reference,   {double gap = 0})
AclBuilder alignMiddleToTop(Object reference,   {double gap = 0})
AclBuilder alignMiddleToMiddle(Object reference,{double gap = 0})
AclBuilder alignMiddleToBottom(Object reference,{double gap = 0})
AclBuilder alignBottomToTop(Object reference,   {double gap = 0})
AclBuilder alignBottomToMiddle(Object reference,{double gap = 0})
AclBuilder alignBottomToBottom(Object reference,{double gap = 0})
```

### Row-level

```dart
AclBuilder setRowAlignment(RowAlignment align)  // left | center | right
// via AclBuilderExtensions:
AclBuilder setRowAlignLeft()
AclBuilder setRowAlignCenter()
AclBuilder setRowAlignRight()
```

*(Ignored for a row that contains any `gap()` slots.)*

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
AclBuilder setAclTitleStyle(TextStyle style)
AclBuilder setAclTitlePosition(AclTitlePosition position)
```

### Container-level component defaults

```dart
// Enable/disable expandX for all subsequently appended components
AclBuilder setAclExpandXDefault(bool enabled)

// Default horizontal gap (pixels) before each appended component
AclBuilder setAclDefaultAppendGap(int pixels)

// Default vertical gap (pixels) before each new content row
AclBuilder setAclDefaultRowGap(int pixels)

// Default minimum size for components without explicit setMSize/setMWidthInChars
// Width = 0 or height = 0 means: leave that dimension untouched
AclBuilder setAclDefaultUnknownMinimumSize(double width, [double height = 0])

// Default preferred size for components without explicit setPSize/setPWidthInChars
// Width = 0 keeps the built-in default (150); height = 0 leaves height unconstrained
AclBuilder setAclDefaultUnknownPreferredSize(double width, [double height = 0])
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

## 19. Removed API (this redesign)

| Removed | Was |
|---|---|
| `addBelow(child, {vGap, hOffset})` | Place child overlaid below anchor via Transform |
| `addAbove(child, {vGap, hOffset})` | Place child overlaid above anchor via Transform |
| `addLeft(child, {hGap, vOffset})` | Place child overlaid left of anchor via Transform |
| `addRight(child, {hGap, vOffset})` | Place child overlaid right of anchor via Transform |
| `AclBuild(builder)` top-level function | Shorthand wrapper — use `AclBuilder().build()` directly |
| `AclColumn(rowDefs)` top-level function | Quick-column helper — superseded by the fluent builder |
| `AclRowDef` class | Data class used only by removed `AclColumn` |
| `with3dEffect` on `AclBorderStyle` | Inset bevel painting |
| `withShadow` on `AclBorderStyle` | Drop shadow |
| `secondaryColor` on `AclBorderStyle` | Accent colour for removed effects |
| `shadowColor` on `AclBorderStyle` | Shadow colour |

The `addXxx` methods caused the "Sub leftward drift" class of bugs and are superseded by explicit cross-row `alignXxx` methods. The top-level `AclBuild`/`AclColumn` functions are unnecessary because `AclBuilder(...).build()` already returns the `Acl` widget directly.

---

## 20. Layout Architecture Diagram

```
AclBuilder.build()  →  Acl (StatefulWidget)
                            │
                            ▼
                     LayoutBuilder  ←── availableWidth, availableHeight
                            │
              Phase 0: read natural-size cache
                (GlobalKey render-tree measurements from last frame;
                 remapped from old keys by structural position)
                            │
              Phase 1..N: pre-calculation loop  (pure Dart)
               ├ 3-phase row fitting (shrink → grow → fill)
               ├ gap slot widths / gapRow heights
               ├ sameWidthAs / sameHeightAs resolution
               ├ alignXxx horizontal deltas (cross-row)
               ├ alignYxx vertical deltas   (same-row)
               └ converged (ε=0.5) or max-iterations hit?
                            │
              Phase 2: single Flutter layout pass
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


---

## 21. Nested Acl Usage

An `Acl` can be nested inside another `Acl` (or any Flutter widget) like any other widget. When embedded via `append()`, the outer container treats it as an ordinary component using its `setAclPSize`/`setAclMSize`/`setAclXSize` values for fitting. The inner `Acl` layout runs independently.

```
Outer Acl
  Row 0: [ Sidebar Acl (setAclPSize(200, double.infinity)) ]
         [ Content Acl (expandX) ]
```

---

## 22. AclWidget — Built-in Form Components (superseded — see Tom Forms Framework)

> **Status (2026-04-18):** The form system described below is **superseded** by the **Tom Forms Framework** in `tom_flutter_ui/lib/src/forms/`. Actual form widgets are `TomField<T>` subclasses (`TomFormStringInput`, `TomFormStringDropdown`, …) that ship from that framework — see [tom_ui_widgets_forms.md](tom_ui_widgets_forms.md) for the complete specification. `TomAclBuilder` (§31) is the ACL integration point: it hosts those widgets, drives container-level authorization and resource resolution, and is what every Phase 1 demo uses. The `AclWidget`/`AclTextField`/`AclDatePicker` catalogue below is **not implemented** and is retained only as historical design context for the ACL + form-widget split.

### Overview

`AclWidget` is the base class for a set of pre-built form components that ship as a separate layer on top of `AclBuilder`. They have built-in `PSize`/`MSize`/`XSize` defaults tuned for typical form use, removing the need for manual sizing calls, and they support all standard sizing and alignment methods.

### TomClass Binding and Reactive State

Each `AclWidget` subtype binds to a **TomClass subtype** field, connecting the component directly to the application's domain model. State changes propagate via the Tom reactive state system (observable fields). A shared **form buffer** sits between the component and the model: raw user input is held in the buffer until validation passes, after which it is committed to the model field. This ensures:

- **No partial writes** to the model while the user is mid-edit
- **Per-field validation** with immediate feedback (error text, border highlight)
- **Cross-field validation** triggered on buffer commit
- **Rollback** to the last committed value on cancel

```dart
// Conceptual binding
AclTextField(
  binding: vm.user.email,        // TomClass field (String)
  validator: Validators.email,
)
AclDatePicker(
  binding: vm.booking.startDate, // TomClass field (DateTime)
  firstDate: DateTime.now(),
)
```

### Component Catalogue

| Component | TomClass type | Default PSize | Notes |
|---|---|---|---|
| `AclLabel(text)` | `String` (read-only) | intrinsic × 28 | Static or bound label |
| `AclTextField(hint)` | `String` | 200 × 40, min w=80 | Single-line text input |
| `AclButton(label)` | — (action) | 100 × 36, min w=60 | Triggers callback or command |
| `AclCheckbox(label)` | `bool` | 28 × 28 | Toggle binding |
| `AclDropdown(items)` | `T extends Enum\|Object` | 180 × 40, min w=80 | Typed selection list |
| `AclDatePicker` | `DateTime` | 180 × 40 | Date-only picker |
| `AclTimePicker` | `TimeOfDay` | 140 × 40 | Time-only picker |
| `AclDateTimePicker` | `DateTime` | 220 × 40 | Combined date + time picker |
| `AclDateRangePicker` | `DateTimeRange` | 280 × 40 | From-date / to-date pair |
| `AclTimeRangePicker` | `TimeOfDayRange` | 220 × 40 | From-time / to-time pair |
| `AclDateTimeRangePicker` | `DateTimeRange` | 320 × 40 | From-datetime / to-datetime pair |

`TimeOfDayRange` and `DateTimeRange` are value types carrying `start` and `end` fields.

### Usage Pattern

```dart
AclBuilder()
  .append(AclLabel('Email'))
  .append(AclTextField(hint: 'you@example.com', binding: vm.email))
  .newRow()
  .append(AclLabel('Start date'))
  .append(AclDatePicker(binding: vm.startDate, firstDate: DateTime.now()))
  .newRow()
  .append(AclLabel('Window'))
  .append(AclDateTimeRangePicker(binding: vm.window))
  .newRow()
  .gap()
  .append(AclButton('Save', onTap: vm.save))
  .build()
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
| Entire container | `setAclGroup(String name)` | The whole `Acl` belongs to the group |
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
6. `setAclGroup()` marks the entire container — used when a nested `Acl` itself should be toggled as a unit.

### Group Propagation

Groups propagate **upward** from nested containers. When a nested `Acl` has `setAclGroup('premium')`, the parent layout knows that the nested container is part of the `premium` group. The parent's visibility controllers affect it accordingly.

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

The callback receives a **fresh** `AclBuilder` that inherits container-level settings (border, padding, background, title) from the parent but has its own row tree.

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
| `inputMode` | `AclInputMode` | Derived from platform: iOS/Android → touch; macOS/Windows/Linux → pointer; web → pointer |
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
| Web pointer | `input: AclInputMode.pointer, isWeb: true` | Web desktop experience |

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

Any `TomClass` or `TomForm` that implements `TomScreenElementsProvider` (or inherits the implementation) can be the element provider. A Phase 1 form like `CustomerForm` qualifies, so the typed lambda lets you reach into its fields directly.

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
final acl = _builder.build();
if (auth == TomAuthState.read) {
  final style = TomThemeScope.readonlyStyleOf(context);
  result = style.apply(acl);            // read-only visual wrapper
}
```

So a `TomAclBuilder`:

- **`none`** on its path → the whole container (rows, fields, title) disappears without a layout slot.
- **`read`** → the children render, but the theme's `TomReadonlyStyle` (reached via `TomThemeScope.readonlyStyleOf`; default `AbsorbPointer` + `Opacity(0.6)`) dims / blocks interaction at the container boundary.
- **`full` / `disabled`** → delegated to each child. `TomField`'s own `resolveEffectiveAuth` does the per-field narrowing via resource path + group + form + authorizer + UI-state controller (see [tom_ui_widgets_forms.md §19](tom_ui_widgets_forms.md)).

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

1. **Pick a sensible row alignment.** The current default for every new `AclBuilder` / `TomAclBuilder` is `AclRowCrossAlignment.top` (§11). That keeps every field anchored to the row's top edge, so a tall field with an error does **not** pull its neighbours down. Setting `setAclDefaultRowAlignment(AclRowCrossAlignment.center)` is specifically the case that "breaks" — neighbours drift when the row grows. Leave the default unless you really want a centred baseline.
2. **Expand one column or all of them — don't mix.** `setAclExpandXDefault(true)` makes every appended field grow to share the available width. Two-per-row layouts (`email + phone`) want this so both fields have the same width; otherwise use explicit `setPSize` / `setPWidthInChars` and keep widths consistent per semantic column.
3. **Lock widths across rows with `sameWidthAs`.** When you need a "dropdown column" and a "text column" to line up across rows, drop an anchor component on the first row and reference it from subsequent rows — e.g. `.append(firstField).setAclId('nameCol')` then later `.append(other).sameWidthAs('nameCol')`.
4. **Use `appendForm` / `append` uniformly.** Both delegate to the same `AclBuilder.append`. Pick one for legibility; mixing them in the same layout hides intent.
5. **Nest forms via nested TomAclBuilders, not ad-hoc Columns.** For a `CustomerForm` with nested `AddressForm`s (Demos B and C), one `TomAclBuilder` per form keeps each section's IDs, auth, and resources independent. The sections can still share `sameWidthAs` references when alignment across sections matters.

A typical Phase 1 layout looks like:

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

---

## 25–31 Updated API Summary

### New on `AclBuilder`

```dart
// IDs (§24)
AclBuilder setAclId(String id)
AclBuilder setRowId(String id)
AclBuilder setId(String id)

// Groups (§25)
AclBuilder startGroup(String name)
AclBuilder endGroup()
AclBuilder group(String name)
AclBuilder setAclGroup(String name)
AclBuilder setRowGroup(String name)

// Visibility (§26)
AclBuilder setGroupVisibilityController(String groupName, AclGroupVisibilityController controller)

// Responsive Variants (§27)
AclBuilder addVariant(String name, {required double atWidth, required void Function(AclBuilder) builder})

// Row Breakpoints (§28)
AclBuilder addRowBreakpoint({required double atWidth, double splitRowDist = 0})

// Inline Component Variants (§29)
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

// Layout Direction (§30)
AclBuilder setAclDirection(AclDirection direction)
```

### New Data Types

```dart
// §24 — Scope access
class AclScope extends InheritedWidget {
  final String? containerId;
  final String? componentId;
  final String? rowId;
  final String? groupName;
  final String? fullIdPath;
  static AclScope? of(BuildContext context);
}

// §25 — Group membership
// (stored as String? fields on AclComponent, AclRow, AclContainer)

// §26 — Visibility
enum AclGroupVisibilityMode { visible, hidden, disabled }
abstract class AclGroupVisibilityController { ... }
class AclBinaryVisibilityController extends AclGroupVisibilityController { ... }
class AclCallbackVisibilityController<T> extends AclGroupVisibilityController { ... }

// §27 — Variants
class AclVariant {
  final String name;
  final double atWidth;
  final List<AclRow> rows;
}

// §28 — Row Breakpoints
class AclRowBreakpoint {
  final double atWidth;
  final int splitAfter;    // computed by builder from append position
  final double splitRowDist;
}

// §29 — Device Context and Variant Detection
enum AclInputMode { touch, pointer }
enum AclFormFactor { phone, tablet, desktop }
enum AclDensity { compact, comfortable, standard }

typedef AclVariantDetector = bool Function(AclDeviceContext deviceContext, Acl? acl, BuildContext context);

class AclDeviceContext {
  final double width;
  final double? height;
  final AclInputMode inputMode;
  final AclFormFactor formFactor;
  final Orientation orientation;
  final TargetPlatform platform;
  final bool isWeb;
  final AclDensity density;
  final TextDirection textDirection;
  final double accessibilityScale;
  factory AclDeviceContext.of(BuildContext context, {required double width, double? height});
}

// §30 — Layout Direction
enum AclDirection { ltr, rtl }

// §31 — TomAclBuilder and Screen Element Provider
abstract interface class TomScreenElementsProvider {}

class TomAclBuilder<T extends TomScreenElementsProvider> {
  final String id;
  final T elementProvider;
  TomAclBuilder({required this.id, required this.elementProvider, ...});
  TomAclBuilder<T> append(Widget Function(T) selector, {double dist});
  TomAclBuilder<T> appendForm(Widget Function(T) selector, {double dist});
  TomAclBuilder<T> appendMasterDetail({required Widget Function(T) master, required Widget Function(T) detail});
  TomAclBuilder<T> newRow({double dist});
  TomAclBuilder<T> gap({double weight});
  TomAclBuilder<T> gapRow({double weight});
  // ... all AclBuilder methods delegated
  Widget build();
  Widget buildFromJson(Map<String, Object?> layoutJson);
}
```

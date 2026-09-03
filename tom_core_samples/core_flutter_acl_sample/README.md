# Tom Core — ACL Feature Tour

An **article-grade** tour of the **ACL (Advanced Container Layout)** engine in
[`tom_flutter_ui`](../../tom_flutter_ui). Where
[`tom_flutter_ui_test/lib/acl_demos/`](../../tom_flutter_ui_test) renders the ACL
layouts as a smoke-test harness, this sample is built to be *read*: every
capability appears as a **code → rendered** pair, so the `AclBuilder` chain that
produced a layout sits right beside the layout it produces.

It is a runnable Flutter app and the prose backbone of a published walkthrough of
the ACL engine. There is **no code-generation step** — an ACL layout binds no
reflected entities, so you instantiate `AclBuilder` directly.

```bash
cd tom_core_samples/core_flutter_acl_sample
flutter pub get
flutter run        # the app: a home index → one screen per ACL capability
flutter test --concurrency=1   # smoke + cell-contract + authorization states
```

> **Run tests serially.** `flutter test` runs several suites at once unless you
> pass `--concurrency=1`. This is the workspace convention, not a requirement of
> these suites: each test file gets its own `flutter_tester` process at any
> concurrency, so the process-global state each file installs is never shared
> with another file.

---

## Why an ACL engine?

Flutter lays widgets out with nested `Row`/`Column`/`Expanded`/`Flexible`. That
works, but a real form — labels and fields that line up across rows, a group that
shows or hides, a column that reflows on a phone — turns into a deep, brittle tree
where a sizing tweak in one place ripples everywhere.

The ACL engine replaces that tree with a **fluent builder**. You `append`
components, size them by *preferred / minimum / maximum* width, flag the ones that
should grow, start a new row when you want one, and frame the whole thing with a
titled border — all as a flat method chain that reads top-to-bottom like the
layout itself:

```dart
AclBuilder()
    .append(nameLabel).setPSize(120)
    .append(nameField).expandX()
    .newRow(dist: 8)
    .append(emailLabel).setPSize(120)
    .append(emailField).expandX()
    .setAclBorderStyle(const AclBorderStyle.solid())
    .setAclTitle('Contact')
    .build();   // returns a plain Widget
```

`build()` returns a normal `Widget`, so an ACL layout drops into any Flutter tree
— and, because it is just a widget, a whole layout can be `append`ed as one cell
of another (see [Nesting](#5-nesting)).

Everything the tour shows is exported from the single barrel:

```dart
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
```

---

## How it is organised

| Piece | File | Role |
| --- | --- | --- |
| Entry point | `lib/main.dart` | Installs the `chromeTexts` resource bundle then `runApp` |
| Chrome bundle | `lib/common/chrome_texts.dart` | The tour's own interactive-chrome strings |
| App shell | `lib/acl_app.dart` | `MaterialApp` + a home index listing every capability group |
| The teaching cell | `lib/common/showcase_cell.dart` | A `ShowcaseCell` shows a curated snippet beside the live layout |
| Code block | `lib/common/code_block.dart` | Monospace, copy-to-clipboard source rendering |
| Group model | `lib/common/showcase_section.dart` | `ShowcaseGroup` + `GroupScreen` |
| Demo box | `lib/common/demo_box.dart` | The generic coloured box arranged by every layout |
| Capability groups | `lib/groups/*.dart` | One file per ACL capability |

The one idea this sample adds over the `acl_demos/` harness is `ShowcaseCell`: it
pairs a **hand-curated instantiation snippet** with the rendered layout, so the
chain and the arrangement it produces are read together.

### The snippet contract

A cell's `code` is a **curated snippet of the API the cell teaches**, not a
transcript of the live `child`. Transcribing would defeat the purpose: the child
is wrapped in gallery harness — width pins, toggles and badge rows that exist to
make the behaviour observable and testable — which would bury the one chain the
cell is about.

So a snippet **may**:

- drop the harness and show only the chain under discussion;
- write a `demoBox` tint bare (`green`, `teal`, `purple`) where the `child` says
  `Colors.green` — a shorthand used uniformly across every group, which elides
  nothing a reader needs because the qualifier restores itself;
- elide repetition behind a `// …` comment, so the reader can see that something
  was left out.

A snippet **may not name an API that does not exist**. That is the line between
an abridgement and a lie, and it is the half a reader actually leans on when they
lift a line into their own project. `showcase_cell_test.dart` enforces it: every
`name(` a snippet contains must also be called by the *live* code in
`lib/groups/<group id>_group.dart`, which is where the `child` is built — so the
file name must match the group id. The test strips comments and string literals
from that file before looking, otherwise it would find each name inside the
snippet's own literal and pass unconditionally; it strips string literals from
the *snippet* too, because a label like `demoBox('Anchor field (wide)', …)` is
data, not a call to a non-existent `field(...)`. A snippet that invents a
convenient `ctrl.buildInventedThing()` fails the suite; so does one that names
something the file merely mentions in a comment.

The related rule the test cannot gate is **eliding a chain behind a name the
snippet does not define**. A cell that composes sub-layouts spells them out as
locals the snippet itself declares (`nesting_group.dart`,
`reference_group.dart`), because a name like `leftPanel` would hide precisely the
construction — the border and title calls — the cell exists to teach. That one
stays a review obligation.

> The `common/` framework (`ShowcaseCell` / `CodeBlock` / `ShowcaseGroup`) is the
> same one used by [`core_flutter_ui_showcase`](../core_flutter_ui_showcase); this
> sample is its ACL counterpart.

> **The chrome conforms to G-UI-1/G-UI-2 too.** The teaching widgets are not raw
> Flutter: `ShowcaseCell`, `_PreviewSurface`, `CodeBlock` and `GroupScreen` derive
> from `TomStatelessWidget` and lay out with `TomColumn` / `TomPadding` /
> `TomContainer` / `TomAlign` / `TomListView` / `TomSizedBox` / `TomDecoratedBox`
> / `TomStack` / `TomPositioned`; `demoBox` returns a `TomContainer`. They own no
> `tomId`/resources and no family identity, so `TomStatelessWidget` (not a family
> base) is the sanctioned base — see the G-UI-2 clarification in
> [`README_tom_core_guidelines.md`](../README_tom_core_guidelines.md). Because that
> base captures `TomScope.current` at construction, these widgets cannot be `const`.

> **Which strings are hardcoded vs resources (G-RES-1).** The ACL snippets are a
> deliberate copy-paste exemption: group titles/summaries and the `code:` bodies
> (plus the direct-parameter widgets they render) stay hardcoded so a reader can
> lift them verbatim. The showcase's own **application chrome** is not exempt —
> the home screen's app-bar title (`showcase.app.title`), the code panel's
> copy-button tooltip (`showcase.codeBlock.copyTooltip`) and the group-visibility
> demo's toggle label (`showcase.visibility.showDetails`) are real on-screen text,
> so G-RES-1 applies and they resolve through the `chromeTexts` bundle that `main`
> installs (the widget tests install it in their `setUp`). The only string kept
> hardcoded outside the bundle is `MaterialApp.title` — OS-level app identity, not
> on-screen copy. See `lib/common/chrome_texts.dart`.

---

## The capabilities

Each section below is one `lib/groups/*.dart` file and one screen in the app. The
snippets are the exact code rendered in the corresponding cell. Sections 1–9 are
the ACL capabilities, and each maps 1:1 onto a verified
`tom_flutter_ui_test/lib/acl_demos/` source, listed at the end of the section.

Section 10, authorization, is the deliberate exception: it is a widget-base
capability that composes with the layout engine rather than a capability of the
engine, so `acl_demos/` holds nothing for it and its sources are
`widget_demos/demo_28_authorization` plus `tom_policy_node_base.dart`. It is in
an ACL sample because only a cell combining the two shows what an auth state
does to the row around it.

### 1. Sizing — preferred / minimum / maximum

`lib/groups/sizing_group.dart`

The ACL engine sizes each component by three independent dimensions. A component
starts at its **preferred** width, never shrinks below its **minimum**, and never
grows past its **maximum** as the row reflows.

```dart
// Preferred — the first cell asks for 200px; the rest share the remainder.
AclBuilder()
    .append(demoBox('200px preferred', teal)).setPSize(200)
    .append(demoBox('rest', orange))
    .append(demoBox('rest', purple))
    .build();

// Minimum — never narrower than 120px, even as the row tightens.
AclBuilder()
    .append(demoBox('min 120', indigo)).setMSize(120)
    .append(demoBox('flex', cyan))
    .append(demoBox('flex', green))
    .build();

// Maximum — stops widening at 160px; the surplus flows to neighbours.
AclBuilder()
    .append(demoBox('max 160', deepPurple)).setXSize(160)
    .append(demoBox('grows', red)).expandX()
    .build();
```

`setPSize`/`setMSize`/`setXSize` each take `(width, [height])`, so you can pin a
height too (`setPSize(180, 96)`). Use all three on one cell to define the exact
band it may occupy. *Source: `all_dimensions_demo`, `size_constraints_demo`.*

### 2. Growth — expand to fill the row

`lib/groups/growth_group.dart`

`expandX()`, `expandY()` and `expand()` let a component soak up whatever space the
sized cells leave behind — the ACL counterpart of Flutter's `Expanded`.

```dart
AclBuilder()
    .append(demoBox('fixed 120', indigo)).setPSize(120)
    .append(demoBox('expandX', teal)).expandX()
    .build();
```

When several cells expand, they split the surplus evenly. `expandY()` stretches a
cell to the tallest component in the row. *Source: `expand_demo`,
`dynamic_resize_demo`.*

### 3. Alignment — main and cross axis

`lib/groups/alignment_group.dart`

`setRowAlignLeft/Center/Right` place a row's components along its main axis when
there is slack to spare; `setRowAlignTop/Middle/Bottom` align components of
differing heights on the cross axis.

```dart
AclBuilder()
    .append(demoBox('A', teal))
    .append(demoBox('B', orange))
    .setRowAlignCenter()
    .build();
```

*Source: `alignment_demo`, `convenience_placement_demo`.*

### 4. Rows & spacing

`lib/groups/rows_spacing_group.dart`

`newRow()` starts a fresh row; the `dist:` argument on `append`/`newRow` inserts a
gap before the component/row. Together they build grid-like forms without nested
`Column`s.

```dart
AclBuilder()
    .append(demoBox('Row 1 · A', teal))
    .append(demoBox('Row 1 · B', teal))
    .newRow(dist: 8)
    .append(demoBox('Row 2 · C', orange))
    .append(demoBox('Row 2 · D', orange))
    .build();
```

`dist` on `append` gives per-component leading gaps, so spacing is local rather
than a single row-wide value. *Source: `basic_row_demo`, `multi_row_demo`,
`spacing_demo`.*

### 5. Nesting

`lib/groups/nesting_group.dart`

Because `AclBuilder.build()` returns a `Widget`, an entire ACL layout can be
`append`ed into another ACL as a single cell — the basis of panel-within-panel
forms.

```dart
final inner = AclBuilder()
    .append(demoBox('Item 1', green))
    .newRow(dist: 4)
    .append(demoBox('Item 2', green))
    .build();

AclBuilder()
    .append(inner).setPSize(160)
    .append(demoBox('sibling', orange)).expandX()
    .build();
```

*Source: `nested_containers_demo`, `complex_layout_demo`.*

### 6. Borders & titles

`lib/groups/borders_titles_group.dart`

`setAclBorderStyle(AclBorderStyle.solid(...))` frames the whole container;
`setAclTitle` adds a caption and `setAclTitlePosition` places it (`topLeft` /
`topCenter` / `topRight`).

```dart
AclBuilder()
    .append(demoBox('Street', teal))
    .append(demoBox('City', teal))
    .setAclBorderStyle(
      const AclBorderStyle.solid(rounded: true, borderRadius: 12),
    )
    .setAclTitle('Address')
    .setAclTitlePosition(AclTitlePosition.topCenter)
    .build();
```

`AclBorderStyle.solid` also takes `color` and `lineWidth`. *Source:
`bordered_groups_demo`, `border_styles_demo`, `groups_demo`.*

### 7. Reference constraints

`lib/groups/reference_group.dart`

A component in a later row can borrow its geometry from an **anchor** in an
earlier row: `sameWidthAs(anchor)` matches its width, `alignLeftToLeft(anchor)`
lines up their left edges, and `alignRightToRight(anchor)` their right edges. This
is how a label/field column stays aligned without a fixed pixel grid.

```dart
final anchorLabel = demoBox('Anchor label', deepOrange);
final anchorField = demoBox('Anchor field (wide)', blueGrey);

AclBuilder()
    .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
    .append(anchorLabel)
    .append(anchorField, dist: 12)
    .newRow(dist: 10)
    .append(demoBox('Linked label', teal))
    .sameWidthAs(anchorLabel)
    .alignLeftToLeft(anchorLabel)
    .append(demoBox('Linked field', orange), dist: 12)
    .sameWidthAs(anchorField)
    .alignRightToRight(anchorField)
    .build();
```

> The anchor must live in a **different row** from the component that references
> it for horizontal constraints. *Source: `reference_constraints_demo`.*

### 8. Variants & breakpoints

`lib/groups/variants_breakpoints_group.dart`

`addRowBreakpoint(atWidth: …)` lets a row split onto two lines once the container
narrows past a width; `addVariant(name, atWidth: …, builder: …)` swaps in an
alternative row layout below a width.

```dart
AclBuilder()
    .append(demoBox('First', teal))
    .append(demoBox('Second', teal))
    .addRowBreakpoint(atWidth: 480, splitRowDist: 8)
    .append(demoBox('Third', orange))
    .append(demoBox('Fourth', orange))
    .build();
```

These are shown here as **static snapshots** — the same chain a responsive layout
uses, rendered at whatever width the preview happens to have. The **live**
width-reactive reflow (family swap, adaptive layouts across phone/tablet/desktop)
is the subject of the sibling **`core_flutter_acl_responsive`** sample. *Source:
`row_breakpoints_demo`, `inline_variants_demo`, `responsive_variants_demo`.*

### 9. Group visibility

`lib/groups/visibility_group.dart`

Components between `startGroup(name)` and `endGroup()` form a named group whose
visibility is driven by an `AclGroupVisibilityController` bound with
`setGroupVisibilityController`. An `AclBinaryVisibilityController` flips a group
between `visible`, `hidden` and `disabled` at runtime.

```dart
final ctrl = AclBinaryVisibilityController();

AclBuilder()
    .setGroupVisibilityController('details', ctrl)
    .append(demoBox('Summary (always shown)', teal))
    .newRow(dist: 8)
    .startGroup('details')
    .append(demoBox('Detail A', orange))
    .append(demoBox('Detail B', orange))
    .endGroup()
    .build();

// later: ctrl.mode = AclGroupVisibilityMode.hidden;
```

The visibility cell in the app is interactive — a `TomSwitch` drives the
controller live. *Source: `group_visibility_demo`.*

### 10. Four-state authorization

`lib/groups/authorization_group.dart`

Every Tom widget carries an `authorizer`; the resolved `TomAuthState` decides how
it renders, independent of business logic — and that gating composes with the ACL
engine. Each cell pins a button to one state with `TomAuthorizer.fixed` inside an
ACL row:

| State | Renders as |
| --- | --- |
| `TomAuthState.full` | Fully interactive and editable |
| `TomAuthState.read` | Visible, shows its value, cannot be activated |
| `TomAuthState.disabled` | Greyed out and non-interactive — **distinct** from read-only |
| `TomAuthState.none` | Hidden entirely; the widget collapses to nothing |

```dart
AclBuilder()
    .append(demoBox('disabled', orange)).setPSize(120)
    .append(
      TomElevatedButton(
        authorizer: TomAuthorizer.fixed(TomAuthState.disabled),
        label: 'Approve',
        onPressed: () {},
      ),
      dist: 12,
    )
    .build();
```

All four states render distinctly: `disabled` and `read` are separate renderings,
not two names for the same greying. `test/authorization_states_test.dart` asserts
the `none` state collapses while the three visible states keep the button on
screen. *Source: `widget_demos/demo_28_authorization` +
`tom_policy_node_base.dart`.*

---

## Tests

| File | Asserts |
| --- | --- |
| `test/acl_smoke_test.dart` | Every capability group builds and pumps without throwing; the home index lists every group |
| `test/showcase_cell_test.dart` | A `ShowcaseCell` shows both the code text and the rendered child; no cell has an empty snippet; no snippet names an API its group's live code never calls |
| `test/authorization_states_test.dart` | The four state cells render; `none` collapses the gated button while `full`/`read`/`disabled` keep it |

All green serial: `flutter test --concurrency=1`.

---

## Where this sits

- **Repo map:** [`tom_ai/core/README.md`](../../README.md)
- **The kit on display:** [`tom_flutter_ui`](../../tom_flutter_ui/README.md)
- **Sample suite index:** [`tom_core_samples/README.md`](../README.md)
- **Sibling samples:**
  [`core_flutter_ui_showcase`](../core_flutter_ui_showcase/README.md) (the widget
  catalogue) and
  [`core_flutter_acl_responsive`](../core_flutter_acl_responsive/README.md) (the
  width-reactive ACL story)

No reflection, no backend, no Docker — a pure, self-contained Flutter app you can
run and read end to end.

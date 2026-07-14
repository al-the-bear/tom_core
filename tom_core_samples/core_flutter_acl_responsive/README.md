# Tom Flutter UI — Responsive Showcase

A **code-beside-layout** tour of the responsive machinery in `tom_flutter_ui`:
the ways a Tom form or an ACL layout **reshapes and re-styles itself as the
viewport changes**, with no width branching in application code. Every cell
renders a live, width-reactive layout **next to the verbatim Dart that produced
it**, so you read the API and watch its effect at the same time.

Where the sibling [`core_flutter_form_showcase`](../core_flutter_form_showcase)
tours the forms framework as a whole (binding, validation, theming, lists) and
[`core_flutter_acl_sample`](../core_flutter_acl_sample) tours the raw ACL builder
chain, this sample isolates a single concern — **responsiveness** — and shows
each mechanism that drives it on its own page. It is re-cast from the verified
`tom_flutter_form_test` breakpoint demos and the `core_flutter_form_showcase`
responsive group.

> **TL;DR** — Run `flutter run`. The home screen lists six responsive
> mechanisms; each opens a scrolling page of `code | rendered` cells. The left
> half of every cell is the exact instantiation snippet; the right half is the
> running layout, pinned at the width that makes the mechanism visible.

---

## Table of contents

1. [What you are looking at](#1-what-you-are-looking-at)
2. [Running the sample](#2-running-the-sample)
3. [The mental model: two independent responsive axes](#3-the-mental-model-two-independent-responsive-axes)
4. [Bootstrap: reflection must come first](#4-bootstrap-reflection-must-come-first)
5. [The showcase scaffold (`ShowcaseCell` / `ShowcaseGroup`)](#5-the-showcase-scaffold)
6. [Mechanism 1 — Breakpoint field style](#6-mechanism-1--breakpoint-field-style)
7. [Mechanism 2 — Family swap](#7-mechanism-2--family-swap)
8. [Mechanism 3 — Row breakpoints](#8-mechanism-3--row-breakpoints)
9. [Mechanism 4 — Form-factor variants](#9-mechanism-4--form-factor-variants)
10. [Mechanism 5 — Adaptive sizing](#10-mechanism-5--adaptive-sizing)
11. [Mechanism 6 — Responsive ACL form (the capstone)](#11-mechanism-6--responsive-acl-form-the-capstone)
12. [Project layout](#12-project-layout)
13. [Reflection regeneration](#13-reflection-regeneration)
14. [Tests](#14-tests)
15. [Extending the showcase](#15-extending-the-showcase)

---

## 1. What you are looking at

The sample teaches **six responsive mechanisms**, each its own group on the home
screen, ordered from single-axis primitives to the combined capstone:

| # | Group | Teaches | Backing |
| - | ----- | ------- | ------- |
| 1 | **Breakpoint field style** | `TomFieldStyle.*BpOverrides` re-resolve a form's field anatomy per width tier | `CompanyForm` |
| 2 | **Family swap** | `FormFieldFamily` Material↔Cupertino swap at a breakpoint, shared entity | `FamilyForm` ×2 |
| 3 | **Row breakpoints** | `AclBuilder.addRowBreakpoint` reflows a form row to a stack | `CompanyForm` |
| 4 | **Form-factor variants** | `resolveFormFactor` + `addVariant` swap a whole-row layout below a width | raw `AclBuilder` |
| 5 | **Adaptive sizing** | `setMSize` / `setPSize` / `setXSize` / `expandX` give a cell an elastic range | raw `AclBuilder` |
| 6 | **Responsive ACL form** | the capstone: reflow **and** re-style from one builder chain | `CompanyForm` |

Each cell pins its preview to one or two **fixed widths** so the two regimes of
a mechanism sit side by side in a single page — you do not need to resize the
window to see the before/after (though the running app reacts live if you do).

---

## 2. Running the sample

```bash
flutter pub get
flutter run            # any device; desktop/web make resizing easiest
flutter test           # 28 widget tests, all green
```

The home screen is a list of the six mechanisms. Tap one to open its
`GroupScreen`, a scroll of `code | rendered` cells. On a wide window each cell
puts the snippet and the live layout side by side; on a phone-width window it
stacks them — the cell **dogfoods the very engine the sample teaches** to decide
which (see §5).

---

## 3. The mental model: two independent responsive axes

Tom responsiveness moves on **two axes that are wired separately**, and the
whole sample is organised around keeping them distinct in your head:

- **The layout axis — *where widgets go*.** The ACL builder reflows rows: a row
  shared above a width becomes a stack below it (`addRowBreakpoint`), or a whole
  alternative row layout is swapped in below a threshold (`addVariant`), or a
  cell elastically shrinks toward a floor and grows toward a ceiling
  (`setMSize` / `setPSize` / `setXSize` / `expandX`). This axis is a property of
  the **builder chain**.

- **The style axis — *how each field looks*.** A `TomFormStyleScope` publishes
  the available width to the fields beneath it; every layout property on
  `TomFieldStyle` has a `*BpOverrides` twin — a `(minWidth, value)` list — so
  label placement, fonts, gaps and error chrome **re-resolve** against the live
  width. This axis is a property of the **style**, not the builder.

The two are orthogonal: you can reflow without re-styling (mechanism 3), or
re-style without reflowing (mechanism 1), or — as the capstone shows — do both
from one chain (mechanism 6). The **form-factor tiers** that name the width
bands are shared vocabulary:

```dart
// phone < 600 ≤ tablet < 1024 ≤ desktop
final factor = AclDeviceContext.resolveFormFactor(width); // AclFormFactor
```

---

## 4. Bootstrap: reflection must come first

The forms bind reflected `@tomReflector` entities (`CompanyProfile`,
`ResponsiveProfile`). A `TomForm` is itself a `TomClass`, and `bind` enumerates
a form's fields through kernel reflection — so reflection has to be registered
**before any form is constructed**:

```dart
void main() {
  initializeReflection();                       // from reflection_seed.dart
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(chromeTexts),  // interactive-chrome bundle
  );
  runApp(const ResponsiveApp());
}
```

`reflection_seed.dart` is the single entry point the generator reads. It imports
exactly the entities and forms this sample teaches and re-exports the generated
`reflection_seed.reflection.dart`, so `main.dart` and every test get
`initializeReflection()` from one place. See §13 for regeneration.

---

## 5. The showcase scaffold (`ShowcaseCell` / `ShowcaseGroup`)

Two small types under `lib/common/` carry every page:

- **`ShowcaseGroup`** — one responsive mechanism: an `id`, a `title`, a
  one-line `summary`, an `icon`, and a `cells(context)` builder. The home screen
  lists every group; `GroupScreen` scrolls its cells.
- **`ShowcaseCell`** — one `code | rendered` entry: a `title`, the verbatim
  `code` snippet, the live `child`, and an optional `note` naming the width
  threshold the mechanism reacts at.

`ShowcaseCell` **dogfoods the engine the sample is about** to lay *itself* out —
side by side on tablet/desktop widths, stacked on phone widths — using the same
form-factor tiers it teaches rather than a bare numeric `MediaQuery` compare:

```dart
final width = MediaQuery.sizeOf(context).width;
final wide = AclDeviceContext.resolveFormFactor(width) != AclFormFactor.phone;
```

Live forms are owned by **`FormHost<F>`**, which creates the form inside a
`TomScope`, binds it to a fresh entity, and disposes it on teardown — so each
group file states *what* to render, never the binding ceremony.

**The scaffold conforms to G-UI-1/G-UI-2.** `ShowcaseCell`, `_PreviewSurface`,
`CodeBlock` and `GroupScreen` derive from `TomStatelessWidget`, and `FormHost`
from `TomStatefulWidget` + `TomState`; layout uses `TomColumn` / `TomPadding` /
`TomContainer` / `TomAlign` / `TomListView` / `TomSizedBox` / `TomDecoratedBox` /
`TomStack` / `TomPositioned` and `demoBox` returns a `TomContainer` — no raw
Flutter widgets. These wrappers own no `tomId`/resources and no family identity,
so `TomStatelessWidget`/`TomStatefulWidget` (not a family base) is the sanctioned
base; because that base captures `TomScope.current` at construction, the widgets
are non-const. See the G-UI-2 clarification in
[`README_tom_core_guidelines.md`](../README_tom_core_guidelines.md).

**Which strings are hardcoded vs resources (G-RES-1).** The teaching content is a
deliberate copy-paste exemption: group titles/summaries, the `code:` bodies, and
the form field labels (resolved through `labelTextOverride`) stay inline so a
reader can lift a snippet verbatim. The showcase's own **application chrome** is
not exempt — the home screen's app-bar title (`showcase.app.title`) and the code
panel's copy-button tooltip (`showcase.codeBlock.copyTooltip`) are real on-screen
text, so G-RES-1 applies and they resolve through the `chromeTexts` bundle that
`main` installs (the widget tests install it in their `setUp`). The only string
kept hardcoded outside the bundle is `MaterialApp.title` — OS-level app identity,
not on-screen copy. See `lib/common/chrome_texts.dart`.

---

## 6. Mechanism 1 — Breakpoint field style

> File: `lib/groups/breakpoint_field_style_group.dart` · backing: `CompanyForm`

The **style axis** in isolation. A single `TomFormStyleScope` wraps the form and
publishes the available width via its internal `LayoutBuilder`. Every layout
property on `TomFieldStyle` carries a `*BpOverrides` twin, so the field anatomy
re-resolves per tier with no rebuild branching:

```dart
TomFormStyleScope(
  style: TomFormStyle(
    defaults: TomFieldStyle(
      labelPlacement: LabelPlacement.floating,
      labelPlacementBpOverrides: [(400, LabelPlacement.above),
                                  (700, LabelPlacement.inline)],
      labelStyleBpOverrides:  [(400, TextStyle(fontSize: 13)),
                               (700, TextStyle(fontSize: 15))],
      labelFieldGapBpOverrides: [(400, 4.0), (700, 8.0)],
      errorBorderEnabledBpOverrides: [(400, true)],
      errorIconEnabledBpOverrides:   [(500, true)],
    ),
  ),
  child: TomAclBuilder(id: 'bp', elementProvider: form)
      .append((p) => p.name.widget).build(context),
)
```

A badge row echoes the resolved tier (label placement, fonts, gaps, error
chrome) so the behaviour is observable — and testable. Crossing 400px turns the
error border on and lifts the label out of the field; 500px adds the error icon;
700px goes inline and bumps fonts/gaps again.

---

## 7. Mechanism 2 — Family swap

> File: `lib/groups/family_swap_group.dart` · backing: `FamilyForm` (×2)

A whole-form **family swap** at a width threshold, over a **shared entity**. One
form *declaration* (`FamilyForm`) resolves Material vs Cupertino field concretes
at construction time via `FormFieldFamily`. The screen pre-builds one instance
per family, binds **both to the same `ResponsiveProfile`**, and renders whichever
matches the 700px breakpoint:

```dart
final material  = FamilyForm(family: FormFieldFamily.material);
final cupertino = FamilyForm(family: FormFieldFamily.cupertino);
material.bind(shared); cupertino.bind(shared);   // ONE entity

TomFormStyleScope(
  style: const TomFormStyle(),
  styleBpOverrides: [(700, TomCupertinoFormStyle.cupertino)],
  child: LayoutBuilder(builder: (ctx, c) {
    final wide = c.maxWidth >= 700;
    return (wide ? material : cupertino).buildColumn();
  }),
)
```

Because both forms bind the same `TomObject`s, **edits survive the swap** — type
a name at desktop width, resize to phone, and the Cupertino form shows it. A
shared-state panel (driven by `TomMultiObservableBuilder`) proves the single
source of truth. `styleBpOverrides` flips the *form style* to Cupertino at the
same threshold so the swap is visually coherent.

---

## 8. Mechanism 3 — Row breakpoints

> File: `lib/groups/row_breakpoint_group.dart` · backing: `CompanyForm`

The **layout axis** in its simplest form. `addRowBreakpoint(atWidth:)` keeps two
fields side by side only while there is at least that much width; below it the
row reflows to a stack — same builder chain, no app-code branching:

```dart
TomAclBuilder(id: 'bp', elementProvider: form)
    .append((p) => p.industry.widget)
    .addRowBreakpoint(atWidth: 400)
    .append((p) => p.taxId.widget, dist: 16)
    .build(context)
```

The two cells pin 520px (side by side) and 320px (stacked) so both regimes show
at once.

---

## 9. Mechanism 4 — Form-factor variants

> File: `lib/groups/form_factor_group.dart` · backing: raw `AclBuilder`

`addVariant(name, atWidth:, builder:)` registers an **alternative whole-row
layout** that the ACL engine selects below a width — so one builder chain carries
a desktop default plus a stacked phone variant. The cells also read back
`resolveFormFactor` so the canonical tiers are visible:

```dart
AclBuilder()
    .append(demoBox('Label', indigo))
    .append(demoBox('Value', cyan), dist: 12)
    .addVariant('phone', atWidth: 600, builder: (b) {
      b.append(demoBox('Label', indigo))
          .newRow(dist: 6)
          .append(demoBox('Value', cyan));
    })
    .build()
```

Above 600px the default side-by-side row applies; below it the registered phone
variant replaces it with a stacked layout.

---

## 10. Mechanism 5 — Adaptive sizing

> File: `lib/groups/adaptive_sizing_group.dart` · backing: raw `AclBuilder`

Per-component sizing pins each cell's elastic range: `setMSize` is the floor it
shrinks to, `setPSize` the preferred width it targets, `setXSize` the ceiling it
grows to, and `expandX()` lets a cell soak up the leftover row space:

```dart
AclBuilder()
    .append(demoBox('sized', teal))
    .setMSize(80).setPSize(160).setXSize(240)
    .append(demoBox('expandX', orange), dist: 12)
    .expandX()
    .build()
```

At 600px the first cell sits near its 160px preferred width and the second fills
the rest; at 320px the first shrinks toward its 80px floor before the row would
reflow, and `expandX` still claims the remainder.

---

## 11. Mechanism 6 — Responsive ACL form (the capstone)

> File: `lib/groups/responsive_acl_form_group.dart` · backing: `CompanyForm`

Both axes, from **one builder chain**. The builder's `addRowBreakpoint` reflows
a shared row to a stack (layout axis) while the enclosing `TomFormStyleScope`
re-resolves every field's anatomy per tier (style axis) — both reacting to the
same width:

```dart
TomFormStyleScope(
  style: TomFormStyle(defaults: TomFieldStyle(
    labelPlacement: LabelPlacement.floating,
    labelPlacementBpOverrides: [(400, above), (700, inline)],
    // …labelStyle / labelFieldGap overrides…
  )),
  child: TomAclBuilder(id: 'cap', elementProvider: form)
      .append((p) => p.name.widget)
      .newRow()
      .append((p) => p.industry.widget)
      .addRowBreakpoint(atWidth: 480)
      .append((p) => p.taxId.widget, dist: 16)
      .build(context),
)
```

At 640px the industry/taxId fields share a row with the larger label anatomy; at
360px the row stacks **and** the fields drop to the compact floating-label
anatomy. One chain, two axes, one width.

---

## 12. Project layout

```
core_flutter_acl_responsive/
├─ lib/
│  ├─ main.dart                     # initializeReflection → runApp(ResponsiveApp)
│  ├─ showcase_app.dart             # MaterialApp shell + group index
│  ├─ reflection_seed.dart          # the one seed the generator reads
│  ├─ reflection_seed.reflection.dart  # GENERATED — do not edit
│  ├─ common/
│  │  ├─ showcase_cell.dart         # the code|rendered cell (dogfoods the engine)
│  │  ├─ showcase_section.dart      # ShowcaseGroup + GroupScreen
│  │  ├─ code_block.dart            # monospace snippet panel
│  │  ├─ form_host.dart             # FormHost<F>: create/bind/dispose a form
│  │  └─ demo_box.dart              # generic coloured box for raw-ACL cells
│  ├─ domain/
│  │  └─ responsive_entities.dart   # @tomReflector CompanyProfile / ResponsiveProfile
│  ├─ forms/
│  │  ├─ company_form.dart          # @tomReflector flat CompanyForm
│  │  └─ family_form.dart           # @tomReflector family-swappable FamilyForm
│  └─ groups/                       # one file per mechanism (§6–§11)
└─ test/                            # see §14
```

---

## 13. Reflection regeneration

`reflection_seed.reflection.dart` is generated and **must not be hand-edited**.
Regenerate it only when a reflected **signature changes** (a field added/removed
on an entity or form, or a new `@tomReflector` type seeded):

```bash
./reflection_generation.sh          # dart run tom_reflection_generator (flag-free)
```

The seed file (`reflection_seed.dart`) is the single source of truth for *what*
gets reflected; add new entities/forms to its imports and exports before
regenerating.

---

## 14. Tests

Twenty-eight widget tests under `test/`, all green, runnable with `flutter test`
(run serially — `--concurrency=1` — per the workspace convention):

| File | Covers |
| ---- | ------ |
| `responsive_smoke_test.dart` | Every group builds at phone/tablet/desktop widths; only benign preview overflows are tolerated, any other exception fails. Home screen lists every group. |
| `breakpoint_field_style_test.dart` | The badge row reports the exact tier values at 800 / 450 / 360 px (label placement, fonts, gaps, border, icon). |
| `family_swap_test.dart` | Active family flips at 700px; seeds echo in the shared panel; an edit propagates; **state survives the swap**. |
| `showcase_cell_test.dart` | The cell contract — both the snippet and the live child render, and no group ships an empty snippet. |

The width-reactive demos are pumped inside a fixed-width `SizedBox` so the
published width is pinned exactly, making the per-tier assertions deterministic —
the same technique the verified `tom_flutter_form_test` breakpoint demos use.

---

## 15. Extending the showcase

To add a mechanism:

1. Add a `lib/groups/<mechanism>_group.dart` exporting a `ShowcaseGroup` (follow
   the existing files — pin each cell to the width that makes the behaviour
   visible, and keep the `code` snippet byte-aligned with the live `child`).
2. Register it in `responsiveGroups` in `lib/showcase_app.dart`.
3. If it binds a new entity or form, seed it in `reflection_seed.dart` and
   regenerate (§13).
4. Add a deterministic test that pumps the demo at fixed widths and asserts a
   badge/state value per tier; keep the smoke test's overflow tolerance in mind.

---

### See also

- **Repo map:** [`tom_ai/core/README.md`](../../README.md)
- **Sample suite index:** [`tom_core_samples/README.md`](../README.md)
- **The kit on display:** [`tom_flutter_ui`](../../tom_flutter_ui/README.md) — the
  `TomAclBuilder`, `TomFormStyle` and `FormFieldFamily` API reference.
- **Sibling samples:**
  [`core_flutter_form_showcase`](../core_flutter_form_showcase/README.md) (the
  full forms framework tour) and
  [`core_flutter_acl_sample`](../core_flutter_acl_sample/README.md) (the raw ACL
  builder chain in depth).

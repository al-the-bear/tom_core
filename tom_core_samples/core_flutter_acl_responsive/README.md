# Tom Flutter UI — Responsive Showcase

A **code-beside-layout** tour of the responsive machinery in `tom_flutter_ui`:
the ways a Tom form or an ACL layout **reshapes and re-styles itself as the
viewport changes**, with no width branching in application code. Every cell
renders a live, width-reactive layout **next to a curated snippet of the Dart
that drives it**, so you read the API and watch its effect at the same time.

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
5. [The showcase scaffold (`ShowcaseCell` / `ShowcaseGroup`)](#5-the-showcase-scaffold-showcasecell--showcasegroup)
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
flutter create --empty --platforms=macos .   # once per machine; or linux, windows, web
flutter run            # any device; desktop/web make resizing easiest
flutter test       # widget tests, all green (§14)
```

The sample ships no platform folders, and Flutter will not run a project on a
platform it has no folder for — so the first run on a machine starts with the
`flutter create` line, once. `--empty` matters: without it the command also
writes a counter-app `test/widget_test.dart` pumping a `MyApp` this package does
not have, and the suite stops compiling. It leaves `lib/`, `pubspec.yaml` and
this README alone, and what it adds is gitignored.

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
    TomTextResourceProvider.from(showcaseTexts),  // chrome + validator messages
  );
  runApp(ResponsiveApp());
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
- **`ShowcaseCell`** — one `code | rendered` entry: a `title`, a curated
  `code` snippet, the live `child`, and an optional `note` naming the width
  threshold the mechanism reacts at. What the snippet may abridge — and the one
  thing it may not — is §15. A cell whose subject is a width threshold also
  declares `childMinWidth`, the width its child needs to show both sides of it.

`ShowcaseCell` **dogfoods the engine the sample is about** to lay *itself* out —
snippet and preview share one row while the cell is at least 720px wide, and
reflow to a stack below it. It reaches for a row breakpoint on the engine's own
builder rather than a hand-rolled `MediaQuery` compare (G-UI-4):

```dart
AclBuilder()
    .setAclExpandXDefault(true)
    .append(codeView)
    .addRowBreakpoint(atWidth: 720, splitRowDist: 12)
    .append(preview, dist: 16)
    .build()
```

Side by side, the two columns share the row in proportion to their preferred
widths, and a snippet's long lines prefer a wide box: left alone, the preview
gets about a fifth of the row. That is fine for an elastic preview and fatal for
one that teaches a threshold — the family-swap demo (§7) needs 700px to show its
Material side, and a fifth of a 1200px screen is under 240px. So a cell that
declares `childMinWidth` gives the snippet the readable minimum (280px) as its
preferred width and the preview the declared width plus its frame, and splits
only when the row can grant both; below that it stacks, and each half fills the
row.

**`FormHost<F>`** carries the form lifecycle for the groups that only need to
render one: it creates the form inside a `TomScope`, runs the caller's optional
`bind` callback, and disposes the form on teardown, so those group files state
*what* to render and never the ceremony.

Binding is the **caller's** step, not the host's. `bind` is nullable and
`FormHost` constructs no entity of its own; omit it and the form renders against
the defaults its fields declare — empty, for `CompanyForm`. Both cells that use
the host do pass one, since the reflection round-trip is what they exist to show,
so the unbound path is pinned by `form_host_test.dart` rather than by a group.

The host is a convenience, not a rule: `breakpoint_field_style` and
`family_swap` run the same three steps in their own `TomState`, because both need
the form as a field between builds — one reads the resolved style off it per
width, the other holds two forms over one shared entity.

**The scaffold conforms to G-UI-1/G-UI-2.** Stated as the rule rather than as an
inventory — the roster of widget types runs past twenty across 18 files, and a
hand-maintained list of it is stale the week after it is written: *every* widget
class the package declares extends `TomStatelessWidget` or `TomStatefulWidget` +
`TomState`, and what they build composes Tom widgets (`TomColumn`, `TomText`,
`TomAclBuilder`, `TomFormStyleScope`, …) with exactly **two deliberate
raw-Flutter exceptions**:

- `MaterialApp` in `ResponsiveApp.buildContent` — the app root, which has no Tom
  counterpart;
- four raw `SizedBox(width: …)` **width pins**, one per group that renders the
  same layout at two widths side by side (`row_breakpoint`, `form_factor`,
  `adaptive_sizing`, `responsive_acl_form`). The pin is the gallery harness
  imposing the constraint the cell exists to demonstrate, not chrome.

Each exception is called out in a `// Why:` comment directly above the
constructor it excuses, and the four width pins carry the *identical* note, so
the reason reads the same wherever a reader lands instead of being re-argued per
file.

That makes the rule checkable rather than merely asserted. Across the
hand-written sources — everything under `lib/` except the generated
`reflection_seed.reflection.dart` — the only raw Flutter **widget** constructors
are `MaterialApp` once and `SizedBox` four times, and each of those five sites
carries its note:

```bash
grep -rn --exclude='*.reflection.dart' -E '\b(MaterialApp|SizedBox)\(' lib/
```

Six `SizedBox` hits come back: the four pins, plus two inside the `code:` strings
the gallery prints on screen. Raw Flutter *value* types (`TextStyle`,
`BoxDecoration`, `ThemeData`, `BoxConstraints`, …) are not widgets, so G-UI-2
does not cover them and they carry no note.

These wrappers own no `tomId`/resources and no family identity, so
`TomStatelessWidget`/`TomStatefulWidget` (not a family base) is the sanctioned
base; because that base captures `TomScope.current` at construction, the widgets
are non-const. See the G-UI-2 clarification in
[`README_tom_core_guidelines.md`](../README_tom_core_guidelines.md).

**Which strings are hardcoded vs resources (G-RES-1).** The teaching content is a
deliberate copy-paste exemption: group titles/summaries, the `code:` bodies, and
the form field labels (resolved through `labelTextOverride`) stay inline so a
reader can lift a snippet and run it. Two categories are *not* exempt, and
`lib/common/chrome_texts.dart` holds one map for each:

- **Application chrome** (`chromeTexts`) — the home screen's app-bar title
  (`showcase.app.title`) and the code panel's copy-button tooltip
  (`showcase.codeBlock.copyTooltip`). These are the showcase's own affordances,
  not snippets, so G-RES-1 applies.
- **Validator messages** (`companyValidationTexts`) — `error.required`,
  `error.minLength`, `error.taxIdFormat`, `error.invalidUrl`.

`showcaseTexts` is the union, and it is what `main` installs and what every
widget test installs in its `setUp`. The only string kept hardcoded outside it is
`MaterialApp.title` — OS-level app identity, not on-screen copy.

**Validator messages are the category with teeth.** A validator never carries a
sentence; it emits a key (`Validators.minLength(2)` emits `error.minLength` with
`params: {'min': 2}`, and a `Validators.pattern` emits whatever `errorKey:` it
was given — see `lib/forms/company_form.dart`). The field resolves that key
through `<basePath>.<key>` → `<key>` → **the key itself**, that last step being a
development indicator. So a key no bundle defines does not throw, log, or render
blank: it paints as `error.invalidUrl`, which reads enough like a message to
survive review, and passes any test that merely asserts an error appeared.
`test/validation_message_test.dart` is what makes the claim falsifiable — it
drives each validator to failure through the widget, asserts the *human sentence*
by name, and sweeps the tree for any `Text` still starting with `error.`. Adding
a validator whose `errorKey` is undefined is therefore a failing build rather
than a silently ugly screen.

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

// (minWidth, style): highest minWidth <= width wins, so the override
// applies at/above 700 where the Material family renders.
TomFormStyleScope(
  style: TomCupertinoFormStyle.cupertino,
  styleBpOverrides: [(700, TomFormStyle.material3)],
  child: TomLayoutBuilder(builder: (ctx, c) {
    final wide = c.maxWidth >= 700;
    final form = wide ? material : cupertino;
    return TomColumn(children: [
      form.fullName.widget,
      form.quantity.widget,
      form.ratio.widget,
      form.notifyMe.widget,
      form.eventDate.widget,
    ]);
  }),
)
```

Because both forms bind the same `TomObject`s, **edits survive the swap** — type
a name at desktop width, resize to phone, and the Cupertino form shows it. A
shared-state panel (driven by `TomMultiObservableBuilder`) proves the single
source of truth.

`styleBpOverrides` flips the *form style* at the same threshold, so a form is
never dressed in the other family's chrome. Note which side each style goes on:
entries are `(minWidth, style)` and the highest `minWidth <= width` wins, so an
entry keyed at 700 applies **at and above** it — the Material side. Cupertino is
therefore the scope's *base* style, which covers everything below the lowest
override. Keying Cupertino at 700 instead reads naturally and does the exact
opposite; `test/family_swap_test.dart` pins the resolved style on both sides of
the threshold so that reading cannot creep back in.

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
    .append(demoBox('Label', Colors.indigo))
    .append(demoBox('Value', Colors.cyan), dist: 12)
    .addVariant('phone', atWidth: 600, builder: (b) {
      b.append(demoBox('Label', Colors.indigo))
          .newRow(dist: 6)
          .append(demoBox('Value', Colors.cyan));
    })
    .build()
```

Above 600px the default side-by-side row applies; below it the registered phone
variant replaces it with a stacked layout.

The group carries **one cell per tier** — 1200px, 900px and 400px — because the
two numbers involved are independent. `resolveFormFactor` maps `< 600` to phone,
`< 1024` to tablet and the rest to desktop; `addVariant(atWidth: 600)` swaps the
shape. So the desktop and tablet cells render the *same* row while reporting
different tiers, and only the 400px cell stacks. `test/form_factor_test.dart`
pins one badge per tier and additionally requires every cell's title to name the
tier its own badge reports, so a cell cannot drift away from the resolver.

---

## 10. Mechanism 5 — Adaptive sizing

> File: `lib/groups/adaptive_sizing_group.dart` · backing: raw `AclBuilder`

Per-component sizing pins each cell's elastic range: `setMSize` is the floor it
shrinks to, `setPSize` the preferred width it targets, `setXSize` the ceiling it
grows to, and `expandX()` lets a cell soak up the leftover row space:

```dart
AclBuilder()
    .append(demoBox('sized', Colors.teal))
    .setMSize(80).setPSize(160).setXSize(240)
    .append(demoBox('expandX', Colors.orange), dist: 12)
    .expandX()
    .build()
```

At 600px the first cell sits at its 160px preferred width and the second fills
the rest. At 320px the row can no longer give it 160px: it gives up a little —
never below its 80px minimum — and `expandX` absorbs most of the shortfall
(`test/adaptive_sizing_test.dart` measures both).

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
    labelPlacementBpOverrides: [
      (400, LabelPlacement.above),
      (700, LabelPlacement.inline),
    ],
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
├─ README.md · pubspec.yaml · analysis_options.yaml · build.yaml · .gitignore
├─ reflection_generation.sh         # regenerates the reflection seed (§13)
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
│  │  ├─ demo_box.dart              # generic coloured box for raw-ACL cells
│  │  └─ chrome_texts.dart          # the resource bundles for interactive chrome (G-RES-1)
│  ├─ domain/
│  │  └─ responsive_entities.dart   # @tomReflector CompanyProfile / ResponsiveProfile
│  ├─ forms/
│  │  ├─ company_form.dart          # @tomReflector flat CompanyForm
│  │  └─ family_form.dart           # @tomReflector family-swappable FamilyForm
│  └─ groups/                       # one file per mechanism
│     ├─ breakpoint_field_style_group.dart  # §6
│     ├─ family_swap_group.dart             # §7
│     ├─ row_breakpoint_group.dart          # §8
│     ├─ form_factor_group.dart             # §9
│     ├─ adaptive_sizing_group.dart         # §10
│     └─ responsive_acl_form_group.dart     # §11, the capstone
└─ test/                            # §14
   ├─ responsive_smoke_test.dart · showcase_cell_test.dart · form_host_test.dart
   ├─ breakpoint_field_style_test.dart · family_swap_test.dart · form_factor_test.dart
   ├─ validation_message_test.dart · chrome_test.dart
   ├─ row_breakpoint_test.dart · adaptive_sizing_test.dart · responsive_acl_form_test.dart
   ├─ group_harness.dart            # shared helper, not a suite
   ├─ visible_demos.dart            # shared helper: does every demo occupy area?
   └─ overflow_tolerance.dart       # shared helper, not a suite
```

**There is no `example/` folder, deliberately: the package is itself the
example.** It is a runnable Flutter app, and each showcase cell pairs its code
snippet with the widget that snippet renders, so the snippets are already the
copy-paste examples — an `example/` inside an example would repeat them.
`flutter run` (§2) is the way in.

There is no `doc/` folder and no API reference mirror, deliberately: this is a
showcase application, not a library — `publish_to: 'none'`, no package depends
on it, and its showcase groups are consumed only by its own `main.dart`, so its
surface is read as the worked example this README and the code already are. The
decision is taken once for all fifteen samples in [the suite map](../README.md).

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

Fifty-five tests under `test/`, all green:

```bash
flutter test
```

**No concurrency flag.** `flutter test` gives every test file its own
`flutter_tester` process, so the process-global state these files install — the
app text resource provider, the `FlutterError.onError` overflow filter, the
viewport size — is per-file already and there is nothing across files to race
over.

| File | Covers |
| ---- | ------ |
| `responsive_smoke_test.dart` | Every group builds at phone/tablet/desktop widths; any exception other than a preview overflow fails the pump; and every cell's demo — and every label inside it — occupies area at each width (`visible_demos.dart`). Home screen lists every group. |
| `breakpoint_field_style_test.dart` | The badge row reports the exact tier values at 800 / 450 / 360 px (label placement, fonts, gaps, border, icon). |
| `family_swap_test.dart` | Active family flips at 700px; seeds echo in the shared panel; an edit propagates; **state survives the swap**; and in the real group screen a desktop width shows the Material side and a phone width the Cupertino one. |
| `form_factor_test.dart` | One badge per tier at 1200 / 900 / 400 px, and — the drift guard — every cell title names the tier that cell's own badge reports (§9). |
| `showcase_cell_test.dart` | The cell contract — both the snippet and the live child render, no group ships an empty snippet, and no snippet names an API the group's live code never calls (§15); and a declared `childMinWidth` is granted side by side, or the cell stacks. |
| `validation_message_test.dart` | Every `error.*` key `CompanyForm` can emit resolves to its human sentence, `{min}` is interpolated, and no `Text` in the form renders a raw resource key (§5). |
| `form_host_test.dart` | The shared form lifecycle (§5): an unbound host renders the field defaults and constructs no entity, a supplied `bind` seeds every field, and teardown disposes the form so a later mutation of the entity no longer reaches it. A parent rebuild keeps the same form: `create` and `bind` run once and a user edit survives. |
| `chrome_test.dart` | The copy button puts the trimmed snippet on the clipboard; `showcase.app.title` and `showcase.codeBlock.copyTooltip` resolve to their declared strings, and the app bar shows the title. |
| `row_breakpoint_test.dart` | §8 — at 520 px `Industry` and `Tax ID` share a row (same top, side by side); at 320 px `Tax ID` sits below. |
| `adaptive_sizing_test.dart` | §10 — at 600 px the sized cell is exactly its preferred 160 px and `expandX` is wider; at 320 px the sized cell gives up width but stays ≥ its 80 px minimum, and `expandX` absorbs more of the shortfall. |
| `responsive_acl_form_test.dart` | §11, both axes of the capstone — at 640 px the row is shared and labels are the `above` tier (outside the decorator, 13 px, not `inline`, which needs 700); at 360 px the row stacks and labels float inside the field. |
| `group_harness.dart` | Not a test — pumps one group and reads a cell's text rects and box widths for the three suites above. |
| `overflow_tolerance.dart` | Not a test — the single filter through which the suite tolerates a preview overflow (see below). |

The width-reactive demos are pumped inside a fixed-width `SizedBox` so the
published width is pinned exactly, making the per-tier assertions deterministic —
the same technique the verified `tom_flutter_form_test` breakpoint demos use.

Pinning a preview narrower than its content makes it overflow inside the harness
column. That is an artifact of the harness, not a defect, so the suite tolerates
it — in exactly one place. `tolerateOverflowErrors()` in
`test/overflow_tolerance.dart` drops reports whose text `contains('overflowed')`,
**forwards every other error** to `flutter_test`'s own handler, and restores that
handler via `addTearDown`. No test file installs `FlutterError.onError` itself.

The forwarding is the point. The tempting local form, `FlutterError.onError =
(_) {}`, reads like "ignore the overflow" and means "ignore everything" — a
failed assertion in a build method, a bad state, a `RenderBox` layout error all
vanish and the test passes on whatever is left in the tree. Three files here did
that and stayed green while every build under them reported a `StateError`.

---

## 15. Extending the showcase

To add a mechanism:

1. Add a `lib/groups/<mechanism>_group.dart` exporting a `ShowcaseGroup` (follow
   the existing files — pin each cell to the width that makes the behaviour
   visible, and write the `code` snippet under the contract below). The file name
   must be `<group id>_group.dart`; the snippet test relies on that mapping.
2. Register it in `responsiveGroups` in `lib/showcase_app.dart`.
3. If it binds a new entity or form, seed it in `reflection_seed.dart` and
   regenerate (§13).
4. Add a deterministic test that pumps the demo at fixed widths and asserts a
   badge/state value per tier. If the pinned preview overflows the harness
   column, call `tolerateOverflowErrors()` — do not install a handler of your
   own (§14).

### The snippet contract

A cell's `code` is a **curated snippet of the API the cell teaches**, not a
transcript of the live `child`. Transcribing would defeat the purpose: the child
is wrapped in gallery harness — `SizedBox` width pins, `FormHost` scaffolding,
badge rows that exist to make the behaviour observable and testable — and paired
wide/narrow cells deliberately carry nothing but `// same chain, the width
differs`, because repeating the chain is precisely what would hide their point.

So a snippet **may**:

- drop the harness and show only the chain under discussion;
- elide repetition behind a `// …labelStyle / gaps / errorIcon overrides…`
  comment, so the reader can see that something was left out;
- use a short stand-in — `id: 'bp'`, a bare `form` — where the live code threads
  a gallery-specific id or a private widget.

A snippet **may not name an API that does not exist**. That is the line between
an abridgement and a lie, and it is the half a reader actually leans on when
they lift a line into their own project. `showcase_cell_test.dart` enforces it:
every `name(` a snippet contains must also be called by the *live* code in
`lib/groups/<group id>_group.dart`, which is where the `child` is built. The
test strips comments and string literals from that file before looking —
otherwise it would find each name inside the snippet's own literal and pass
unconditionally. A snippet that invents a convenient `form.buildColumn()` fails
the suite; so does one that names something the file merely mentions in a
comment.

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

# Tom Flutter UI — Forms Showcase

A **code-beside-form** tour of the `tom_flutter_ui` forms framework. Every cell
in this sample renders a live, bound `TomForm` field **next to the verbatim Dart
that declared it** — so you read the API and see its result at the same time,
feature by feature.

Where the sibling [`core_flutter_ui_showcase`](../core_flutter_ui_showcase) is a
pure *widget* gallery, this one is about the thing that makes Tom forms a
framework rather than a widget set: **binding a reflected domain object into an
editable form** and getting validation, layout, theming, authorization,
breakpoints, lists and master-detail for free. It is the verified
`tom_flutter_form_test` harness re-cast as a teaching artifact.

> **TL;DR** — Run `flutter run`. The home screen lists eight feature groups;
> each opens a scrolling page of `code | rendered` cells. The left half of every
> cell is the exact instantiation snippet; the right half is the running widget.

---

## Table of contents

1. [What you are looking at](#1-what-you-are-looking-at)
2. [Running the sample](#2-running-the-sample)
3. [The mental model: forms bind reflected entities](#3-the-mental-model-forms-bind-reflected-entities)
4. [Bootstrap: reflection must come first](#4-bootstrap-reflection-must-come-first)
5. [The showcase scaffold (`ShowcaseCell` / `ShowcaseGroup`)](#5-the-showcase-scaffold)
6. [Lifecycle ownership: `FormHost` and `ListFormHost`](#6-lifecycle-ownership-formhost-and-listformhost)
7. [Feature group 1 — Field types](#7-feature-group-1--field-types)
8. [Feature group 2 — Validation](#8-feature-group-2--validation)
9. [Feature group 3 — Layout (`TomAclBuilder`)](#9-feature-group-3--layout-tomaclbuilder)
10. [Feature group 4 — Theming (`TomFormStyle`)](#10-feature-group-4--theming-tomformstyle)
11. [Feature group 5 — Responsive breakpoints](#11-feature-group-5--responsive-breakpoints)
12. [Feature group 6 — Four-state authorization](#12-feature-group-6--four-state-authorization)
13. [Feature group 7 — Editable lists](#13-feature-group-7--editable-lists)
14. [Feature group 8 — Master-detail](#14-feature-group-8--master-detail)
15. [Project layout](#15-project-layout)
16. [Reflection regeneration](#16-reflection-regeneration)
17. [Tests](#17-tests)
18. [Extending the showcase](#18-extending-the-showcase)

---

## 1. What you are looking at

The sample teaches **eight forms features**, each its own group on the home
screen, in deliberate order — building blocks first, composition next, advanced
patterns last:

| # | Group | Teaches | Backing form |
| - | ----- | ------- | ------------ |
| 1 | **Field types** | The four string-backed field widgets | `CompanyForm`, `OrderItemForm` |
| 2 | **Validation** | sync / async validators, `autoValidate`, `TomErrorView` | `CompanyForm`, `OrderItemForm` |
| 3 | **Layout** | `TomAclBuilder` fluent field layout | `CompanyForm` |
| 4 | **Theming** | `TomFormStyle` presets via `TomFormStyleScope` | `CompanyForm` |
| 5 | **Responsive** | `addRowBreakpoint` row reflow | `CompanyForm` |
| 6 | **Authorization** | the four `TomAuthState` field states | `AuthShowcaseForm` |
| 7 | **Lists** | `TomListForm` + `TomInlineListForm` + toolbar | `OrderItemListForm` |
| 8 | **Master-detail** | `TomMasterDetailListForm` | `OrderItemListForm` |

Every rendered widget is the **real form machinery**, not a mock: the field
reads and writes the reflected entity it was bound to.

---

## 2. Running the sample

```bash
cd tom_core_samples/core_flutter_form_showcase
flutter pub get
flutter run            # any device / chrome / macos / linux
```

There is nothing to configure. Labels are supplied inline via
`labelTextOverride`, so the sample needs **no resource bundle** — any
unresolved error key falls through to its raw key, which is intentionally
instructive when you see it in a validation message.

---

## 3. The mental model: forms bind reflected entities

A `TomForm<T extends TomClass>` is an editor over a **reflected domain object**.
The two entities behind this sample are flat, kernel-only `TomClass`es:

```dart
@tomReflector
class CompanyProfile extends TomClass {
  late final name        = TomString('');
  late final industry     = TomString('');
  late final taxId        = TomString('');
  late final website      = TomString('');
  late final description   = TomString('');
}

@tomReflector
class OrderItem extends TomClass {
  late final productName = TomString('');
  late final quantity     = TomString('1');
  late final unitPrice    = TomString('0.00');
  late final notes        = TomString('');
}
```

A form declares one field widget per entity property and is bound at runtime:

```dart
@tomReflector
class CompanyForm extends TomForm<CompanyProfile> {
  CompanyForm() : super(formId: 'company');

  late final name = TomFormStringInput(
    'name', '',
    form: this,
    labelTextOverride: 'Company name',
    validators: [Validators.required(), Validators.minLength(2)],
  );
  // … industry, taxId, website, description …
}

final form = CompanyForm();
form.bind(CompanyProfile());   // reads/writes entity fields through reflection
```

**Why the form class itself is `@tomReflector`.** `bind(target)` calls
`setValues(target.getValues())`, and both sides **enumerate the form's fields
through kernel reflection**. So it is not enough to reflect the *entities* — the
**form classes must be reflected too**, or binding throws
`_NoSuchCapabilityError: Reflecting on type CompanyForm without capability`.
This is the single most important thing to understand about a Tom forms project,
and the reason this sample carries a codegen step that the pure widget gallery
does not.

---

## 4. Bootstrap: reflection must come first

Two things happen before the first frame ([`lib/main.dart`](lib/main.dart)):

```dart
void main() {
  initializeReflection();                       // 1. register reflected types
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const <String, dynamic>{}),  // 2. empty provider
  );
  runApp(const ShowcaseApp());
}
```

1. **`initializeReflection()`** (from the generated
   `reflection_seed.reflection.dart`) registers every reflected type. It **must**
   run before any form is constructed.
2. An **empty resource provider** is installed so any widget that probes the
   singleton finds a valid scope. The showcase resolves labels through
   `labelTextOverride`, so the empty map is deliberate.

`TomTextResourceProvider` is not re-exported by the `tom_flutter_ui` barrel — it
is imported from `package:tom_core_kernel/tom_core_kernel.dart`.

The **reflection seed** ([`lib/reflection_seed.dart`](lib/reflection_seed.dart))
is the single file the generator reads. It imports and re-exports exactly the
entities **and the forms** that must be in the graph, plus the generated output.
Because reflecting a form necessarily reflects its `@tomReflector` field-widget
types from `tom_flutter_ui`, the generated file is large (~300k lines) — the
same trade-off the verified `tom_flutter_form_test` accepts. Correctness over
file size: a form that cannot bind is not a form.

---

## 5. The showcase scaffold

Two small types under [`lib/common/`](lib/common) carry the whole presentation:

- **`ShowcaseCell`** — one teaching entry: a `title`, the verbatim `code`
  snippet, the live `child` widget, and an optional `note`. It renders
  `code | rendered` side-by-side on wide viewports and stacked on narrow ones.
  Both halves are asserted present by the cell test, so an empty snippet can
  never slip through.
- **`ShowcaseGroup`** — a feature family: an `id`, `title`, one-line `summary`,
  an `icon`, and a `cells(context)` builder. The home screen lists every group;
  tapping one opens a `GroupScreen` that scrolls its cells.

```dart
ShowcaseCell(
  title: 'TomFormStringInput',
  note: 'A plain text field. Bound to CompanyProfile.name via the form.',
  code: "TomFormStringInput('name', '', form: this, ...)",
  child: /* the live, bound field */,
)
```

Adding the entire app together is just a list:
[`lib/showcase_app.dart`](lib/showcase_app.dart) declares
`showcaseGroups = [fieldTypes, validation, layout, theming, responsive,
authorization, lists, masterDetail]`.

---

## 6. Lifecycle ownership: `FormHost` and `ListFormHost`

A form is stateful — it must be **created inside a `TomScope`**, **bound** to a
fresh entity, and **disposed** when its cell leaves the tree. Repeating that
ceremony in every cell is exactly the copy-paste this sample exists to
discourage, so it lives once in [`lib/common/form_host.dart`](lib/common/form_host.dart):

```dart
FormHost<CompanyForm>(
  scopeId: 'ft_text',
  create: CompanyForm.new,
  bind: (form) => form.bind(CompanyProfile()),
  builder: (context, form) => form.name.widget,
)
```

`FormHost<F extends TomForm<TomClass>>` works for any concrete form because Dart
class generics are covariant: `CompanyForm extends TomForm<CompanyProfile>` is a
valid `F`, and the concrete type is preserved inside `builder`.

`TomListForm` extends `TomObservable` (not `TomForm`), so it gets its own owner,
**`ListFormHost`**, which binds the list form to a `TomList<TItem>`. The list and
master-detail groups use a small stateful widget built on the same pattern.

---

## 7. Feature group 1 — Field types

The four string-backed field widgets, each bound to a reflected entity and
rendered straight from its form. A field is rendered through its `.widget`
getter.

**`TomFormStringInput`** — a plain text field:

```dart
TomFormStringInput(
  'name', '',
  form: this,
  labelTextOverride: 'Company name',
  validators: [Validators.required(), Validators.minLength(2)],
)
```

**`TomFormStringDropdown`** — a dropdown over a `StaticSelectableSource` of
labelled values:

```dart
TomFormStringDropdown(
  'industry', '',
  form: this,
  labelTextOverride: 'Industry',
  source: industrySource,
  validators: [Validators.required()],
)
```

**`TomFormSearchInput<String>`** — a type-ahead picker. In `OrderItemForm`,
selecting a catalogue entry auto-fills the sibling unit-price field (via a
`>>` observer):

```dart
TomFormSearchInput<String>(
  'productName', '',
  form: this,
  source: productSource(),
  labelTextOverride: 'Product',
  validators: [Validators.required()],
)
```

**Multi-line input** — the same `TomFormStringInput` with `maxLines`/`maxLength`:

```dart
TomFormStringInput(
  'description', '',
  form: this,
  labelTextOverride: 'Description',
  maxLength: 500,
  maxLines: 4,
)
```

---

## 8. Feature group 2 — Validation

Validators attach per field. Synchronous ones resolve instantly; an async
`SlowValidator` resolves through a pending → resolved lifecycle; `autoValidate`
revalidates as the user types; a `TomErrorView` aggregates a form's errors.

**Required + minLength** (sync, validates on focus-out):

```dart
validators: [Validators.required(), Validators.minLength(2)]
```

**Pattern** — a `RegExp` validator with a named `errorKey`:

```dart
validators: [
  Validators.pattern(RegExp(r'^https?:\/\/...'), errorKey: 'invalidUrl'),
]
```

**Async (`SlowValidator`)** — a simulated 600 ms server round-trip; tax IDs
starting with `X` resolve to *taken*, and a pending spinner shows while it runs:

```dart
final taxIdUniquenessValidator = SlowValidator<String>((value) async {
  await Future.delayed(const Duration(milliseconds: 600));
  if (value.startsWith('X')) return const ValidationError('taxIdTaken');
  return const ValidationSuccess();
});
```

**Live `autoValidate`** — revalidates on every keystroke:

```dart
TomFormStringInput(
  'quantity', '1',
  form: this,
  autoValidate: true,
  validators: [Validators.required(), positiveInteger],
)
```

**`TomErrorView` summary** — aggregates every field error on a form:

```dart
TomErrorView(form: form, title: 'Please fix the following')
```

---

## 9. Feature group 3 — Layout (`TomAclBuilder`)

Rather than hand-nesting `Row`s and `Column`s, a form lays its fields out with
the fluent ACL builder. `append` adds a field to the current row, `newRow`
starts the next, and the builder reads fields straight off the bound form via
its `elementProvider`:

```dart
TomAclBuilder(id: 'company', elementProvider: form)
    .setAclExpandXDefault(true)
    .append((p) => p.name.widget)
    .newRow()
    .append((p) => p.industry.widget)
    .append((p) => p.taxId.widget, dist: 16)   // two fields share a row
    .newRow()
    .append((p) => p.website.widget)
    .newRow()
    .append((p) => p.description.widget)
    .build(context)
```

The group shows three regimes built from the same `CompanyForm`: a single-column
stack, two fields per row, and the full composed form.

---

## 10. Feature group 4 — Theming (`TomFormStyle`)

A `TomFormStyleScope` pushes a style onto everything beneath it. The three
shipped presets change label placement, gaps and borders **without touching the
form definition** — the identical `CompanyForm` renders three ways purely by
swapping the scope's `style`:

```dart
TomFormStyleScope(
  style: TomFormStyle.material3,   // or .compact, or .bordered
  child: formLayout,
)
```

- **`material3`** — the default: standard label placement and gaps.
- **`compact`** — floating labels and reduced gaps for dense forms.
- **`bordered`** — outlined borders with floating labels and error-border visuals.

---

## 11. Feature group 5 — Responsive breakpoints

`addRowBreakpoint(atWidth:)` keeps a row's fields side by side only while there
is at least that much width; below it the row reflows to a stack. The same form
definition adapts to the viewport — each cell pins a width so both regimes show
side by side:

```dart
TomAclBuilder(id: 'bp', elementProvider: form)
    .setAclExpandXDefault(true)
    .append((p) => p.industry.widget)
    .addRowBreakpoint(atWidth: 400)
    .append((p) => p.taxId.widget, dist: 16)
    .build(context)
```

At 520 px the two fields share a row; at 320 px the identical layout stacks them.

---

## 12. Feature group 6 — Four-state authorization

Every Tom field carries an `authorizer`; the resolved `TomAuthState` decides how
it renders, **independent of business logic**:

| State | Rendering |
| ----- | --------- |
| `TomAuthState.none` | hidden — the field does not exist for the user |
| `TomAuthState.disabled` | visible but greyed out and non-interactive |
| `TomAuthState.read` | shows its value but cannot be edited |
| `TomAuthState.full` | fully interactive and editable (the default) |

Each cell pins one state with `TomAuthorizer.fixed`, so the four renderings of
the same field can be compared:

```dart
TomFormStringInput(
  'full', 'Analytical Engines Ltd.',
  form: this,
  labelTextOverride: 'Company name',
  authorizer: TomAuthorizer.fixed(TomAuthState.full),
)
```

In real apps the state flows from a resource provider or an action controller
instead of being hard-pinned — see `four_state_authorization_design.md` /
`uam_four_state_migration.md` for the migration path. The `none` cell renders an
empty preview surface on purpose: the field collapses to nothing.

---

## 13. Feature group 7 — Editable lists

A `TomListForm` wraps a `TomList<OrderItem>`; `TomInlineListForm` renders one row
sub-form per item, and `TomListFormToolbar` adds, removes and reorders rows.
Structural mutations flow straight back into the bound list:

```dart
TomInlineListForm<OrderItem, OrderItemForm>(
  listForm: listForm,
  reorderable: true,
  rowBuilder: (context, index, rowForm) => Row(children: [
    TomReorderHandle(index: index),
    Expanded(flex: 3, child: rowForm.productName.widget),
    Expanded(child: rowForm.quantity.widget),
  ]),
)
// …
TomListFormToolbar<OrderItem, OrderItemForm>(
  listForm: listForm,
  selectedIndex: selectedIndex,
  onSelectionChanged: select,
)
```

`OrderItemListForm extends TomListForm<OrderItem, OrderItemForm>` supplies
`createItem()` (a seeded fresh row for *add*) and a `formFactory` (the per-row
editor). The cell owns the list form's lifecycle in a `TomScope` and tracks the
selected row so the toolbar acts on it.

---

## 14. Feature group 8 — Master-detail

`TomMasterDetailListForm` pairs a list pane with a per-row editor: pick an item
on the left to edit its **own sub-form** on the right, with an unsaved-changes
guard intercepting a switch away from a dirty row:

```dart
TomMasterDetailListForm<OrderItem, OrderItemForm>(
  listForm: listForm,
  masterPaneWidth: 220,
  initialSelectedIndex: 0,
  masterBuilder: (context, listForm, selected, selectIndex) => MasterPane(...),
  detailBuilder: (context, _, rowForm) => DetailPane(form: rowForm),
)
```

The detail pane stacks the row form's field widgets, surfaces a `Dirty` chip
from `rowForm.isDirty`, shows a `TomErrorView`, and offers `form.save()` /
`form.discard()`. The master pane lists items reactively with
`TomMultiObservableBuilder` so titles update as the bound entity changes.

---

## 15. Project layout

```
lib/
  main.dart                     # initializeReflection() → resource provider → runApp
  showcase_app.dart             # MaterialApp shell + the showcaseGroups list
  reflection_seed.dart          # the one file the reflection generator reads
  reflection_seed.reflection.dart   # GENERATED — do not edit; regenerate only
  common/
    showcase_cell.dart          # the code | rendered cell
    showcase_section.dart       # ShowcaseGroup + GroupScreen
    code_block.dart             # monospace snippet renderer
    form_host.dart              # FormHost / ListFormHost lifecycle owners
  domain/
    showcase_entities.dart      # @tomReflector CompanyProfile / OrderItem
  forms/
    company_form.dart           # @tomReflector CompanyForm
    order_item_form.dart        # @tomReflector OrderItemForm + OrderItemListForm
    auth_showcase_form.dart     # @tomReflector AuthShowcaseForm (four states)
  groups/
    field_types_group.dart      validation_group.dart   layout_group.dart
    theming_group.dart          responsive_group.dart   authorization_group.dart
    lists_group.dart            master_detail_group.dart
test/
  showcase_smoke_test.dart      # every group builds without exceptions
  showcase_cell_test.dart       # every cell shows both code and child
```

---

## 16. Reflection regeneration

The generated `lib/reflection_seed.reflection.dart` is checked in. **Regenerate
it only when a reflected signature changes** — that is, when you add or remove a
field on `CompanyProfile`/`OrderItem`, or add/remove a `@tomReflector` form in
the seed:

```bash
./reflection_generation.sh
```

The script runs `dart run tom_reflection_generator --nested`, which reads
`build.yaml`'s `generate_for` and emits the seed. (Passing a `build` positional
argument is wrong — the generator reports "Target not found".)

---

## 17. Tests

Run serially — never in parallel (parallel Flutter test invocations corrupt
results):

```bash
flutter test --concurrency=1
```

Both suites call `initializeReflection()` in `setUpAll`:

- **`showcase_smoke_test.dart`** — pumps each group and the home screen at a
  large size, asserting the group title renders and `takeException` is null.
- **`showcase_cell_test.dart`** — asserts every cell shows both its code snippet
  and its live child, and that no cell's snippet is empty.

Current status: `dart analyze` → *No issues found!*; `flutter test` → **11/11
green** (serial).

---

## 18. Extending the showcase

Adding a feature group is mechanical:

1. Create `lib/groups/<feature>_group.dart` exposing a `ShowcaseGroup` with its
   cells.
2. Add it to `showcaseGroups` in `lib/showcase_app.dart`.

The smoke test picks it up automatically. If the new group needs a new reflected
form, annotate it `@tomReflector`, add it to `reflection_seed.dart`, and run
`./reflection_generation.sh`. Keep each cell's `code` snippet in lock-step with
its `child` by hand — the article wants curated snippets, and the cell test
guarantees neither half is empty.
```

---

## Where this sits

- **Repo map:** [`tom_ai/core/README.md`](../../README.md)
- **Sample suite index:** [`tom_core_samples/README.md`](../README.md)
- **The kit on display:** [`tom_flutter_ui`](../../tom_flutter_ui/README.md) — the
  forms framework (fields, validation, layout, theming, lists, master-detail)
- **Shared model:** [`todo_domain`](../todo_domain/readme.md) — the reflected
  entities the demo forms bind
- **Sibling samples:**
  [`core_flutter_ui_showcase`](../core_flutter_ui_showcase/README.md) (the widget
  catalogue),
  [`core_flutter_acl_sample`](../core_flutter_acl_sample/README.md) (the ACL
  engine), and
  [`core_flutter_acl_responsive`](../core_flutter_acl_responsive/README.md)
  (responsive layouts)

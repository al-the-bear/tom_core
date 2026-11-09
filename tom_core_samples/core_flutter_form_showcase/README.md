# Tom Flutter UI — Forms Showcase

A **code-beside-form** tour of the `tom_flutter_ui` forms framework. Every cell
in this sample renders a live, bound `TomForm` field **next to a curated snippet
of the Dart that declared it** — so you read the API and see its result at the
same time, feature by feature.

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

- [Where this sits](#where-this-sits)

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
flutter create --empty --platforms=macos .   # once per machine; or linux, windows, web
flutter run            # any device / chrome / macos / linux
```

The sample ships no platform folders, and Flutter will not run a project on a
platform it has no folder for — so the first run on a machine starts with the
`flutter create` line, once. `--empty` matters: without it the command also
writes a counter-app `test/widget_test.dart` pumping a `MyApp` this package does
not have, and the suite stops compiling. It leaves `lib/`, `pubspec.yaml` and
this README alone, and what it adds is gitignored.

There is nothing to configure. The **teaching** text is supplied inline: form
labels via `labelTextOverride`, and any unresolved error key falls through to its
raw key, which is intentionally instructive when you see it in a validation
message. The only resources the sample installs are its own **application
chrome** (the home screen's app-bar title and the code panel's copy-button
tooltip) — see §5.

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
    validators: [TomValidators.required(), TomValidators.minLength(2)],
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
    TomTextResourceProvider.from(showcaseTexts),  // 2. chrome + validator text
  );
  runApp(ShowcaseApp());
}
```

1. **`initializeReflection()`** (from the generated
   `reflection_seed.reflection.dart`) registers every reflected type. It **must**
   run before any form is constructed.
2. The **`showcaseTexts` bundle** is installed. The showcase resolves its
   teaching labels through `labelTextOverride` (nothing to wire up), but two
   categories are real application text and so fall under G-RES-1: the
   scaffold's own interactive chrome (`chromeTexts`) and the **validator
   messages** (`showcaseValidationTexts`). Installing the union before the first
   frame is what stops a validator's `error.*` key rendering as its own name
   (see §5 for the boundary, and `lib/common/chrome_texts.dart` for what each
   bundle carries).

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

- **`ShowcaseCell`** — one teaching entry: a `title`, a curated `code`
  snippet, the live `child` widget, an optional `note`, and an optional
  `previewMinWidth`. It renders `code | rendered` side-by-side on wide viewports
  and stacked on narrow ones. Both halves are asserted present by the cell test,
  so an empty snippet can never slip through.
  A preview that stops rendering below a width declares `previewMinWidth`; the
  cell then raises its split threshold to leave room for both halves *and* gives
  the preview column that preferred width, so the split actually grants it. Only
  the master-detail cell needs one, at 560 px.
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

**The scaffold conforms to G-UI-1/G-UI-2.** `ShowcaseCell`, `_PreviewSurface`,
`CodeBlock` and `GroupScreen` derive from `TomStatelessWidget`, and `FormHost` /
`ListFormHost` from `TomStatefulWidget` + `TomState`; layout uses `TomColumn` /
`TomPadding` / `TomContainer` / `TomAlign` / `TomListView` / `TomSizedBox` /
`TomDecoratedBox` / `TomStack` / `TomPositioned` — no raw `StatelessWidget`,
`StatefulWidget` or `Column`/`Container`. These wrappers own no `tomId`/resources
and no family identity, so `TomStatelessWidget`/`TomStatefulWidget` (not a family
base) is the sanctioned base; because that base captures `TomScope.current` at
construction, the widgets are non-const. See the G-UI-2 clarification in
[`README_tom_core_guidelines.md`](../README_tom_core_guidelines.md).

**Which strings are hardcoded vs resources (G-RES-1).** The teaching content is a
deliberate copy-paste exemption: group titles/summaries, the `code:` bodies, and
the form field labels (via `labelTextOverride`) stay inline so a reader can lift a
snippet verbatim. Everything else is a resource, in two bundles:

- **Interactive chrome** (`chromeTexts`) — the home screen's app-bar title
  (`showcase.app.title`) and the code panel's copy-button tooltip
  (`showcase.codeBlock.copyTooltip`). Real on-screen text, so G-RES-1 applies.
- **Validator messages** (`showcaseValidationTexts`) — `error.required`,
  `error.minLength`, `error.maxLength`, `error.taxIdFormat`, `error.taxIdTaken`,
  `error.invalidUrl`, `error.invalidInteger`, `error.mustBePositive`,
  `error.invalidDecimal`, `error.mustBeNonNegative`. See §8 for why this is the
  category with teeth.

`showcaseTexts` is the union, and it is what `main` installs and what every test
installs in its `setUp`. The only string kept hardcoded outside the bundles is
`MaterialApp.title` — OS-level app identity, not on-screen copy. See
`lib/common/chrome_texts.dart`.

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
master-detail groups both use it:

```dart
ListFormHost<OrderItem, OrderItemForm>(
  scopeId: 'lists_inline',
  create: OrderItemListForm.new,
  items: seededOrderItems,
  builder: (context, listForm) => _InlineOrderList(listForm: listForm),
)
```

Master-detail passes the bound list straight to `TomMasterDetailListForm` and so
needs no widget of its own. The lists group still has one, but the host having
taken creation, binding and disposal off it leaves it holding only the selected
row index — one reason to change instead of two.

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
  validators: [TomValidators.required(), TomValidators.minLength(2)],
)
```

**`TomFormStringDropdown`** — a dropdown over a `TomStaticSelectableSource` of
labelled values:

```dart
TomFormStringDropdown(
  'industry', '',
  form: this,
  labelTextOverride: 'Industry',
  source: industrySource,
  validators: [TomValidators.required()],
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
  validators: [TomValidators.required()],
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
`TomSlowValidator` resolves through a pending → resolved lifecycle; `autoValidate`
revalidates as the user types; a `TomErrorView` aggregates a form's errors.

**Required + minLength** (sync, validates on focus-out):

```dart
validators: [TomValidators.required(), TomValidators.minLength(2)]
```

**Pattern** — a `RegExp` validator with a named `errorKey`:

```dart
validators: [
  TomValidators.pattern(RegExp(r'^https?:\/\/...'), errorKey: 'error.invalidUrl'),
]
```

**Async (`TomSlowValidator`)** — a simulated 600 ms server round-trip; tax IDs
starting with `X` resolve to *taken*, and a pending spinner shows while it runs:

```dart
final taxIdUniquenessValidator = TomSlowValidator<String>((value) async {
  await Future.delayed(const Duration(milliseconds: 600));
  if (value.startsWith('X')) return const TomValidationError('error.taxIdTaken');
  return const TomValidationSuccess();
});
```

**Live `autoValidate`** — revalidates on every keystroke:

```dart
TomFormStringInput(
  'quantity', '1',
  form: this,
  autoValidate: true,
  validators: [TomValidators.required(), positiveInteger],
)
```

**`TomErrorView` summary** — aggregates every field error on a form. It is
empty until validation runs, so its cell carries the company-name field and a
**Validate** button that calls `form.validate()`:

```dart
TomErrorView(form: form, title: 'Please fix the following')
```

**A validator carries a key, never a sentence — and an undefined key does not
fail.** Every rule above emits an `error.*` key, which the field resolves through
`<basePath>.<key>` → `<key>` → **the raw key itself** as a development indicator.
That last step is a trap worth naming: a key no bundle defines does not throw,
log, or render blank — it renders as `error.invalidUrl`, which reads enough like
a message to survive review and any test that merely asserts an error appeared.
So custom keys take the framework's `error.` prefix, sit in
`showcaseValidationTexts` beside the `TomValidators` built-ins (§5), and
`validation_message_test.dart` asserts the human sentences *by name*, sweeps the
rendered form for anything still starting with `error.`, and scans `lib/` so that
even a rule no interaction can provoke must still have a sentence behind it.
Parameters are interpolated from the validator: `minLength(2)` passes
`{min: 2}` into `'Use at least {min} characters.'`, so the bound is stated once
— in the form — and never duplicated in the bundle.

---

## 9. Feature group 3 — Layout (`TomAclBuilder`)

Rather than hand-nesting `Row`s and `Column`s, a form lays its fields out with
the fluent ACL builder. `append` adds a field to the current row, `newRow`
starts the next, and the builder reads fields straight off the bound form via
its `elementProvider`:

```dart
TomAclBuilder(id: 'company', elementProvider: form)
    .setAclExpandXDefault(true)
    .setAclDefaultAppendGap(0)                 // default is 8; gaps stay explicit
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
    .setAclDefaultAppendGap(0)
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

In real apps the state is not hard-pinned. Resource-level state comes from
`TomAuthorization.resolveAuth(resourceKeyPath)`, backed by whatever
`TomAuthorizationAdapter` the application installs; with none installed it
resolves to `full` — which is why this sample, installing none, can demonstrate
all four states through `TomAuthorizer.fixed` alone. An authorizer's `strategy`
decides how it combines with that resource state: `authorizerNarrowsOnly` (the
default) may only restrict it, while `authorizerDecides` overrides it outright,
and `.fixed` uses the latter. `TomAuthorizer.fromAction` derives the state from a
`TomAction`'s own authorization instead. See
[`form_authorizers.md`](../../tom_flutter_ui/doc/form_authorizers.md) for the
evaluation pipeline and the cross-field cases.

That resource key path is prefixed by the form's `formId`, which is why
`AuthShowcaseForm` carries its own — `authShowcase` — rather than reusing
`CompanyForm`'s `company`. The two bind the same entity, but an id names a
resource namespace, not an entity: the `TomAclBuilder(id: 'company', …)` of §9
is meant to reach the real company form and not these four pinned demo fields.
Two forms share an id only where their resources should resolve together, which
is what `OrderItemForm` and `OrderItemListForm` do with `items` (§13).

The `none` cell puts the field between two labels on purpose: it collapses to
nothing, so the labels close up around the place it would have taken.

---

## 13. Feature group 7 — Editable lists

A `TomListForm` wraps a `TomList<OrderItem>`; `TomInlineListForm` renders one row
sub-form per item, and `TomListFormToolbar` adds, removes and reorders rows.
Structural mutations flow straight back into the bound list:

```dart
// The inline list shrink-wraps and never scrolls itself, so the
// bounded pane above the toolbar supplies the scrolling.
TomColumn(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    TomExpanded(
      child: TomSingleChildScrollView(
        child: TomInlineListForm<OrderItem, OrderItemForm>(
          listForm: listForm,
          reorderable: true,
          rowBuilder: (context, index, rowForm) => TomCard(
            key: ValueKey('order-row-${rowForm.hashCode}'),
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: index == selectedIndex
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : null,
            child: TomInkWell(
              onTap: () => select(index),
              child: TomPadding(
                padding: const EdgeInsets.all(8),
                child: TomRow(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TomReorderHandle(index: index),
                    TomSizedBox(width: 8),
                    TomExpanded(
                        flex: 3, child: rowForm.productName.widget),
                    TomSizedBox(width: 8),
                    TomExpanded(child: rowForm.quantity.widget),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    TomDivider(height: 8),
    TomListFormToolbar<OrderItem, OrderItemForm>(
      listForm: listForm,
      selectedIndex: selectedIndex,
      onSelectionChanged: (i) async => select(i),
    ),
  ],
)
```

Every layout primitive above is the Tom one, because that is the rule the sample
follows everywhere (G-UI-1) — and naming `Row` or `Expanded` here would both
misdescribe the child and teach the opposite of what the code does. `widget_convention_test.dart` enforces this in
every library file and across every cell in every group.

The scroll view is part of the pattern: `TomInlineListForm` shrink-wraps its
rows and gives them `NeverScrollableScrollPhysics`, so it always renders at its
natural height and never scrolls itself — which is what lets it sit inside a
longer page. In a bounded pane the pane supplies the scrolling instead.

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
  draggableSplitter: true,          // default is false: a fixed divider
  initialSelectedIndex: 0,
  masterBuilder: (context, listForm, selected, selectIndex) => MasterPane(...),
  detailBuilder: (context, _, rowForm) => DetailPane(form: rowForm),
)
```

`masterPaneWidth` is the *initial* width; with `draggableSplitter: true` the
divider becomes a drag handle, so the reader can rebalance the two panes. It
defaults to `false`, which is why the sample passes it explicitly.

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
  showcase_smoke_test.dart      # every group builds, every demo is visible
  error_view_cell_test.dart     # Validate fills the TomErrorView summary
  visible_demos.dart            # shared helper: does every demo occupy area?
  showcase_cell_test.dart       # every cell shows both code and child
  widget_convention_test.dart   # G-UI-1 holds in the source AND in the snippets
  list_form_host_test.dart      # the list-bearing groups really bind their items
  list_interaction_test.dart    # select, move and remove; master-detail selection
  validation_message_test.dart  # every error key resolves to its sentence
  chrome_test.dart              # the copy button and the chrome resource keys
```

There is no `example/` folder, deliberately: the package is itself the example —
a runnable app whose every cell pairs a snippet with the live form it produces —
so an `example/` would only repeat the cells. `flutter run` (§2) is the way in.
The suite map's [Examples](../README.md#examples) table records the same for
every showcase.

There is no `doc/` folder and no API reference mirror, deliberately: this is a
showcase application, not a library — `publish_to: 'none'`, no package depends
on it, and its only public surface is the app shell and its group list. The API
it demonstrates is `tom_flutter_ui`'s, which carries its own reference — for the
forms framework,
[`api_summary_forms.md`](../../tom_flutter_ui/doc/api/api_summary_forms.md). The
decision is taken once for all eighteen samples in [the suite map](../README.md).

---

## 16. Reflection regeneration

The generated `lib/reflection_seed.reflection.dart` is checked in. **Regenerate
it only when a reflected signature changes** — that is, when you add or remove a
field on `CompanyProfile`/`OrderItem`, or add/remove a `@tomReflector` form in
the seed:

```bash
./reflection_generation.sh
```

The script runs `dart run tom_reflection_generator` flag-free — the generator
scans the current project only (framework default scan `.`, non-recursive) and
reads `build.yaml`'s `generate_for` to emit the seed. (Passing a `build`
positional argument is wrong — it is treated as a target filter and matches
nothing.)

---

## 17. Tests

```bash
flutter test
```

No concurrency flag: `flutter test` gives each test file its own
`flutter_tester` process, so the process-global state a file installs is never
shared with another file.

All the suites that bind a form call `initializeReflection()` in `setUpAll`:

- **`showcase_smoke_test.dart`** — pumps each group and the home screen at a
  large size, asserting the group title renders, `takeException` is null, and
  every cell's demo — and every label inside it — occupies area, so a demo that
  renders nothing fails rather than passing as an empty preview
  (`visible_demos.dart`).
- **`error_view_cell_test.dart`** — the `TomErrorView` cell does what its note
  says: pressing **Validate** fills the summary.
- **`showcase_cell_test.dart`** — asserts every cell shows both its code snippet
  and its live child, that no cell's snippet is empty, that no snippet names an
  API the sample never calls, and that a snippet quoting a configurable
  construct shows its whole configuration. The last two are the machine-checkable
  parts of the snippet contract (§18): a snippet that invents
  `form.buildColumn()` names something a reader cannot use, and one that quotes
  `TomAclBuilder` or a list scaffold but drops a call the child makes would
  render differently if copied.
- **`widget_convention_test.dart`** — enforces G-UI-1 on both surfaces a reader
  learns from. No library file may build a raw Flutter widget that has a Tom
  counterpart (`MaterialApp` is the sole exemption — there is no
  `TomMaterialApp`, because Tom widgets live inside an app rather than replacing
  its root), and no snippet may name one either. That second rule is the third
  machine-checkable part of the contract: a snippet saying `Row` cannot be
  illustrating a child built from `TomRow`. Both rules read one shared list of
  widget names, which is what stops the two halves drifting apart.
- **`list_form_host_test.dart`** — asserts the two list-bearing groups really
  bind their seeded items, which the smoke test cannot see (an unbound list form
  renders zero rows without throwing).
- **`validation_message_test.dart`** — every `error.*` key the sample can emit
  resolves to its human sentence, `{min}` is interpolated, no `Text` in a
  rendered form shows a raw resource key, and a source scan of `lib/` catches the
  keys no interaction can paint (§8). Without it the silent key-as-message
  fallback is invisible to the rest of the suite.
- **`list_interaction_test.dart`** — drives the two interactive cells the way a
  reader would. In the inline list, *Move up* is disabled until a row is
  selected; selecting a row and moving it up reorders the list, and *Remove*
  deletes the selected row and only it. In master-detail, the first item starts
  selected, and choosing another loads it into the detail form and flips which
  moves the toolbar allows.
- **`chrome_test.dart`** — `CodeBlock`'s copy button puts the trimmed snippet on
  the clipboard, and both chrome keys resolve to their declared strings rather
  than echoing back (the app bar shows the title). Shared in shape with the two
  ACL samples' `chrome_test.dart`, which test the same `CodeBlock`.

Current status: `dart analyze` → *No issues found!*; `flutter test` → **30/30
green**.

---

## 18. Extending the showcase

Adding a feature group is mechanical:

1. Create `lib/groups/<feature>_group.dart` exposing a `ShowcaseGroup` with its
   cells.
2. Add it to `showcaseGroups` in `lib/showcase_app.dart`.

The smoke test picks it up automatically. If the new group needs a new reflected
form, annotate it `@tomReflector`, add it to `reflection_seed.dart`, and run
Lay the group out with Tom widgets, not raw Flutter ones — `widget_convention_test.dart`
will fail the build otherwise, and it reads your snippets too.

### The snippet contract

A cell's `code` is a **curated snippet of the API the cell teaches**, not a
transcript of the live `child`. In this sample it usually cannot be a transcript:
what a cell teaches is a field *declaration* — `TomFormStringInput('name', …,
validators: [...])` — which lives in `lib/forms/`, while the group file beside it
holds only the `FormHost` scaffolding and width pins that make the bound field
observable and testable.

So a snippet **may**:

- drop the harness and show only the declaration under discussion;
- *abstract* — the theming cells stand in for a whole layout with `formLayout`;
- elide repetition behind a `// …` comment, so the reader can see that something
  was left out;
- use a short stand-in where the live code threads a gallery-specific id.

Three rules bound that freedom, and each is gated:

1. **A snippet may not name an API that does not exist.** That is the line
   between an abridgement and a lie, and it is the half a reader leans on when
   they lift a line into their own project. `showcase_cell_test.dart` requires
   every `name(` in a snippet to be called somewhere in the sample's own `lib/`
   — the whole package rather than one file, because the declaration a snippet
   quotes lives in `lib/forms/` while the snippet itself sits in `lib/groups/`.
   The test strips comments and string literals from both sides first, otherwise
   it would find each name inside the snippet's own literal and pass
   unconditionally. If the name is a **private** helper of the sample, spell it
   with its underscore — `_MasterPane`, not `MasterPane` — so a reader does not
   go looking for it in `tom_flutter_ui`.
2. **Naming a construct owes that construct's full configuration.** A snippet
   quoting `TomAclBuilder` or a list scaffold but dropping a call the child makes
   would render differently if copied.
3. **No raw Flutter widget that has a Tom counterpart**, in the source or in a
   snippet (`widget_convention_test.dart`).

Everything the gates cannot see — whether an abridgement is *honest* — is still
a review obligation.

---

## Where this sits

- **Repo map:** [`tom_ai/core/README.md`](../../README.md)
- **Sample suite index:** [`tom_core_samples/README.md`](../README.md)
- **The kit on display:** [`tom_flutter_ui`](../../tom_flutter_ui/README.md) — the
  forms framework (fields, validation, layout, theming, lists, master-detail)
- **Model:** local to this package — the reflected entities the demo forms bind,
  `CompanyProfile` and `OrderItem`, are declared in
  [`lib/domain/showcase_entities.dart`](lib/domain/showcase_entities.dart); there
  is no shared-model dependency
- **Sibling samples:**
  [`core_flutter_ui_showcase`](../core_flutter_ui_showcase/README.md) (the widget
  catalogue),
  [`core_flutter_acl_sample`](../core_flutter_acl_sample/README.md) (the ACL
  engine), and
  [`core_flutter_acl_responsive`](../core_flutter_acl_responsive/README.md)
  (responsive layouts)

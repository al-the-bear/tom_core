# Tom Flutter UI — Component Showcase

An **article-grade** showcase of [`tom_flutter_ui`](../../tom_flutter_ui). Where
`tom_flutter_ui_test` renders the widgets as a smoke-test harness, this sample
is built to be *read*: every component appears as a **code → rendered** pair, so
the source that produced a widget sits right beside the widget it produces.

It is a runnable Flutter app and the prose backbone of a published walkthrough
of the Tom widget set. There is **no code-generation step** — Tom widgets are
plain Flutter widgets; you instantiate them directly.

```bash
cd tom_core_samples/core_flutter_ui_showcase
flutter pub get
flutter create --empty --platforms=macos .   # once per machine; or linux, windows, web
flutter run        # the app: a home index → one screen per component group
flutter test       # smoke + cell-contract tests
```

The sample ships no platform folders, and Flutter will not run a project on a
platform it has no folder for — so the first run on a machine starts with the
`flutter create` line, once. `--empty` matters: without it the command also
writes a counter-app `test/widget_test.dart` pumping a `MyApp` this package does
not have, and the suite stops compiling. It leaves `lib/`, `pubspec.yaml` and
this README alone, and what it adds is gitignored.

## How it is organised

| Piece | File | Role |
| --- | --- | --- |
| Entry point | `lib/main.dart` | Installs the `chromeTexts` resource bundle then `runApp` |
| Chrome bundle | `lib/common/chrome_texts.dart` | The showcase's own interactive-chrome strings |
| App shell | `lib/showcase_app.dart` | `MaterialApp` + a home index listing every group |
| The teaching cell | `lib/common/showcase_cell.dart` | A `ShowcaseCell` shows a curated snippet beside the live widget |
| Code block | `lib/common/code_block.dart` | Monospace, copy-to-clipboard source rendering |
| Group model | `lib/common/showcase_section.dart` | `ShowcaseGroup` + `GroupScreen` |
| Demo filler | `lib/common/demo_box.dart` | `demoBox(label, color)` — the generic box the layouts arrange |
| Component groups | `lib/groups/*.dart` | One file per component family |

The single new idea over `tom_flutter_ui_test` is `ShowcaseCell`: it pairs a
**hand-curated instantiation snippet** with the rendered widget, so the API and
its result are read together.

### The snippet contract

A cell's `code` is a **curated snippet of the API the cell teaches**, not a
transcript of the live `child`. Transcribing would defeat the purpose: the child
is wrapped in gallery harness — width pins, stateful demo wrappers, badge rows
that exist to make the behaviour observable and testable — which would bury the
one widget the cell is about.

So a snippet **may** drop the harness, elide repetition behind a `// …` comment,
and abstract: standing in for a whole `StatefulWidget` with `_value` and
`setState` is fair.

Trimming has a floor, and it is two rules the suite gates rather than a review
obligation.

**A snippet may only name identifiers that exist.** It may leave out detail the
reader does not need, but it may not stand in a placeholder (`boxA`) or borrow a
local from another file (`scheme`) — both read as real code and neither compiles
when copied. `showcase_cell_test.dart` checks that every identifier a snippet
names also appears in the *live, non-snippet* source of the file that renders it
— it strips the snippets and comments from that file first, otherwise it would
find each name inside the snippet's own literal and pass unconditionally. That
is why the layout and ACL cells build their filler with the public
`demoBox(label, color)` rather than a private helper: the snippet and the child
then say exactly the same thing, and a reader can look up what they say.

(This is a stricter form of the rule the sibling samples state as "a snippet may
not name an API that does not exist". They check the names a snippet *calls*;
this one checks every identifier it mentions, which the gallery's placeholder
history made necessary.)

**A snippet may abstract, but it may not quote a construct and then
under-configure it.** Abstracting away a stateful wrapper is fair; a `TomColumn`
shown without the `mainAxisSize: MainAxisSize.min` the child passes is not,
because the copy then takes the full height while the preview beside it does
not. The same goes for
what a snippet drops *around* a widget: `TomSlider` and
`TomLinearProgressIndicator` have no intrinsic width, so the `TomSizedBox` that
constrains them is part of the lesson and appears in the snippet.
`showcase_cell_test.dart` enforces both halves.

### A note on resources and `const`

The showcase uses the **direct-parameter** form of every widget — `label:`,
`text:`, `value:`, `icon:` — rather than resource keys, so each **teaching
snippet** compiles and runs on its own with nothing to wire up first. That
hardcoding is a deliberate copy-paste exemption for the snippets only.

**Which strings are hardcoded vs resources (G-RES-1).** The exemption stops at
the teaching content. The group titles/summaries and the `code:` snippet bodies
(plus the direct-parameter demo widgets they render, e.g.
`TomIconButton(tooltip: 'Favorite')`) stay hardcoded — a reader must be able to
lift them verbatim. But the showcase's own **application chrome** — the home
screen's app-bar title (`showcase.app.title`) and the code panel's copy-button
tooltip (`showcase.codeBlock.copyTooltip`) — is real on-screen text, not a
snippet, so G-RES-1 applies: each is a resource key resolved through the
`chromeTexts` bundle that `main` installs (and the widget tests install in their
`setUp`). The only string kept hardcoded outside the bundle is
`MaterialApp.title` — OS-level app identity, not on-screen copy. See
`lib/common/chrome_texts.dart`.

Tom widgets resolve their inputs in the constructor body (`late final` fields),
so they are **not** `const`-constructible. None of the snippets wrap a Tom
widget in `const`; copy them as-is.

**G-UI-1/G-UI-2 holds throughout — in the teaching cells as well as the
chrome.** The cells matter most: they are the part a reader copies, so a snippet
that began `Column(` or `Padding(` would teach the raw widget in a package whose
purpose is to teach the Tom kit. The group files therefore use `TomColumn`,
`TomPadding`, `TomCenter`, `TomSizedBox` and `TomContainer` (including inside
`demoBox`) in both halves of every cell. The only raw Flutter widgets left are
the `Icon`s that `TomIconButton(icon:)` and `TomFloatingActionButton(child:)`
require by signature.

The **chrome follows the same rule**: `ShowcaseCell`, `_PreviewSurface`,
`CodeBlock`, `GroupScreen`, `ShowcaseApp` and `_ShowcaseHome` derive from
`TomStatelessWidget` (the sanctioned base for a scope-participating layout
wrapper that owns no `tomId`/resources and no family identity) and lay out with
`TomColumn` / `TomPadding` / `TomContainer` / `TomAlign` / `TomListView` /
`TomSizedBox` / `TomDecoratedBox` / `TomStack` / `TomPositioned` — no raw
`StatelessWidget` or `Column`/`Container`. That base captures `TomScope.current`
at construction, so these widgets are non-const too. See the G-UI-2 clarification
in [`README_tom_core_guidelines.md`](../README_tom_core_guidelines.md).

The last two names are the ones worth checking. `ShowcaseApp` and `_ShowcaseHome`
are the app shell — where a reader would most expect raw Flutter to have
survived, since something has to build the `MaterialApp`. It does not: the shell
sits on the same base as the rest, and `MaterialApp` is the single raw widget
constructed anywhere in the chrome, because the kit offers nothing to replace it.
`_ShowcaseHome` already returns `TomScaffold`/`TomAppBar`/`TomListView`. The list
above is checked against `lib/` by `showcase_smoke_test.dart`, so it cannot fall
behind the source.

There is no `example/` folder, deliberately: the package is itself the example —
a runnable gallery whose every cell pairs a widget's instantiation code with the
widget it renders — so an `example/` would only repeat the cells. `flutter run`
is the way in. The suite map's [Examples](../README.md#examples) table records
the same for every showcase.

There is no `doc/` folder and no API reference mirror, deliberately: this is a
showcase application, not a library — `publish_to: 'none'`, no package depends
on it, and its only public surface is the app shell and its group list. The API
it demonstrates is `tom_flutter_ui`'s, which documents its widget catalogue in
[`doc/widgets.md`](../../tom_flutter_ui/doc/widgets.md) and indexes its API
summaries in
[`doc/api/api_summary_index.md`](../../tom_flutter_ui/doc/api/api_summary_index.md).
The decision is taken once for all sixteen samples in [the suite map](../README.md).

## Component groups

Each group below maps to one file in `lib/groups/` and one screen in the app.

The code under each heading is an **abridged illustration**, not the group's
full set of cells: it shows a representative two or three, and often compresses
a cell's five-line snippet onto one line. What it does not do is drift — the
same floor that binds the cells binds these fences, so every value one shows
(every literal, every identifier, every number) exists in the file it cites.
Read them as a faithful excerpt; read `lib/groups/` for the whole. The fences
are checked against the source by `showcase_cell_test.dart`.

### Buttons — `groups/buttons_group.dart`

The Tom button family: elevated, filled (and tonal), text, outlined, icon and
floating-action buttons, plus the disabled state (`onPressed: null`).

```dart
TomElevatedButton(label: 'Save', onPressed: () {})
TomFilledButton(tonal: true, label: 'Continue', onPressed: () {})
TomIconButton(icon: const Icon(Icons.favorite), tooltip: 'Favorite', onPressed: () {})
```

### Labels & images — `groups/labels_group.dart`

`TomText`, `TomSelectableText`, `TomIcon`, `TomChip` and `TomBadge` — the
read-only display widgets. The name spans two kit families on purpose:
`TomText`, `TomSelectableText`, `TomChip` and `TomBadge` derive from
`TomLabelBase` in `widgets/labels/`, while `TomIcon` derives from
`TomImageBase` in `widgets/images/`. Its sibling there, `TomImage`, needs an
asset to show anything and is left to the coverage note below.

```dart
TomText(text: 'Headline text', style: Theme.of(context).textTheme.headlineSmall)
TomChip(labelText: 'Flutter')
TomBadge(labelText: '5', child: TomIcon(icon: Icons.notifications_outlined))
```

### Cards & surfaces — `groups/cards_group.dart`

`TomCard`, `TomContainer` and `TomDivider` — the surfaces that group and
separate content.

```dart
TomCard(elevation: 2, child: TomPadding(
  padding: const EdgeInsets.all(16),
  child: TomText(text: 'Card content'),
))
```

### Toggles & sliders — `groups/toggles_sliders_group.dart`

`TomSwitch`, `TomCheckbox` and `TomSlider` — the interactive value widgets that
report through `onChanged`. Each cell wraps its widget in a small stateful demo
that owns its own value.

```dart
TomSwitch(value: _on, onChanged: (v) => setState(() => _on = v))
TomSizedBox(
  width: 240,
  child: TomSlider(value: _value, min: 0, max: 100,
      onChanged: (v) => setState(() => _value = v)),
)
```

### Progress — `groups/progress_group.dart`

`TomCircularProgressIndicator` and `TomLinearProgressIndicator`, determinate and
indeterminate.

A circular indicator sizes itself; a linear one does not, so the linear cell
shows the width constraint rather than leaving the reader to discover it.

```dart
TomCircularProgressIndicator()              // indeterminate
TomCircularProgressIndicator(value: 0.65)   // determinate
TomSizedBox(width: 240, child: TomLinearProgressIndicator(value: 0.4))
```

### Layout — `groups/layout_group.dart`

`TomRow`, `TomColumn`, `TomExpanded` and `TomWrap` — the Tom mirrors of
Flutter's flex and spacing primitives.

```dart
TomRow(children: [
  TomExpanded(flex: 2, child: demoBox('flex 2', Colors.teal)),
  TomExpanded(flex: 1, child: demoBox('flex 1', Colors.amber)),
])
```

### Advanced container layout — `groups/acl_group.dart`

The fluent `AclBuilder` engine: compose components with preferred sizing,
borders and titles without nesting `Row`/`Column`.

```dart
AclBuilder()
    .append(demoBox('Name', Colors.indigo))
    .append(demoBox('Email', Colors.cyan))
    .setAclBorderStyle(const AclBorderStyle.solid())
    .setAclTitle('Contact')
    .build()
```

### Four-state authorization — `groups/authorization_group.dart`

Every Tom widget carries an `authorizer`. The resolved `TomAuthState` drives how
the widget renders, independent of business logic:

| State | Rendering |
| --- | --- |
| `none` | Hidden — the element does not exist for the user |
| `disabled` | Visible but greyed out, non-interactive |
| `read` | Shows its value, cannot be modified |
| `full` | Fully interactive and editable |

```dart
TomElevatedButton(
  authorizer: TomAuthorizer.fixed(TomAuthState.read),
  label: 'Approve',
  onPressed: () {},
)
```

In real applications the state flows from a resource provider or an action
controller; here each cell pins one state with `TomAuthorizer.fixed` so the four
renderings can be compared side by side.

## Coverage and extending the showcase

This first cut covers eight component families that exercise the breadth of the
library — display, input, layout, the ACL engine, and the authorization model.
`tom_flutter_ui` ships more (forms, tables, trees, navigation, dialogs,
selects). Adding a group is mechanical:

1. Create `lib/groups/<family>_group.dart` exposing a `final ShowcaseGroup`.
2. Give each component a `ShowcaseCell(title:, code:, child:)` under the snippet
   contract above: name only identifiers the file defines or imports, and pass
   through every argument and constraint the child carries
   (`showcase_cell_test.dart` rejects the rest).
3. Add the group to `showcaseGroups` in `lib/showcase_app.dart`.

The smoke test picks it up automatically (it iterates `showcaseGroups`), so a
new group that throws at build time fails CI without any extra test wiring.

## Tests

| File | Guards |
| --- | --- |
| `test/showcase_smoke_test.dart` | Every group screen builds without throwing, and every cell's demo — and every label inside it — occupies area (`visible_demos.dart`); the home screen lists every group; every "### \<title\> — `groups/<file>.dart`" section above names a file that exists and declares that exact title; the chrome paragraph above names every class in `lib/` that extends `TomStatelessWidget`, and no class in `lib/` extends a raw `StatelessWidget`/`StatefulWidget` |
| `test/showcase_cell_test.dart` | A cell always renders **both** the snippet and the child; no cell has an empty snippet; no snippet names an identifier that exists nowhere in the file that renders it; each cell's child builds the widget its snippet leads with (following a private demo widget into its `State`); no snippet quotes a construct and then omits what the child passes to it (arguments, ACL builder calls, or a `TomSizedBox` constraint); no illustration in this README shows a literal, identifier or number its group file does not have |

---

## Where this sits

- **Repo map:** [`tom_ai/core/README.md`](../../README.md)
- **Sample suite index:** [`tom_core_samples/README.md`](../README.md)
- **The kit on display:** [`tom_flutter_ui`](../../tom_flutter_ui/README.md) — the
  widget library this gallery renders surface by surface
- **Sibling samples:**
  [`core_flutter_form_showcase`](../core_flutter_form_showcase/README.md) (the
  forms framework in depth),
  [`core_flutter_acl_sample`](../core_flutter_acl_sample/README.md) (the ACL
  engine), and
  [`core_flutter_acl_responsive`](../core_flutter_acl_responsive/README.md)
  (responsive layouts)

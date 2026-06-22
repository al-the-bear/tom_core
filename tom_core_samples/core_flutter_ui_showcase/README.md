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
flutter run        # the app: a home index → one screen per component group
flutter test       # smoke + cell-contract tests
```

## How it is organised

| Piece | File | Role |
| --- | --- | --- |
| Entry point | `lib/main.dart` | Installs an empty `TomTextResourceProvider` then `runApp` |
| App shell | `lib/showcase_app.dart` | `MaterialApp` + a home index listing every group |
| The teaching cell | `lib/common/showcase_cell.dart` | A `ShowcaseCell` shows a verbatim snippet beside the live widget |
| Code block | `lib/common/code_block.dart` | Monospace, copy-to-clipboard source rendering |
| Group model | `lib/common/showcase_section.dart` | `ShowcaseGroup` + `GroupScreen` |
| Component groups | `lib/groups/*.dart` | One file per component family |

The single new idea over `tom_flutter_ui_test` is `ShowcaseCell`: it pairs a
**hand-curated, verbatim instantiation snippet** with the rendered widget. The
snippets are kept in lock-step with the live `child` by hand (an article wants
trimmed, copy-paste-ready code), and `test/showcase_cell_test.dart` asserts both
halves are always present so an empty snippet can never slip through.

### A note on resources and `const`

The showcase uses the **direct-parameter** form of every widget — `label:`,
`text:`, `value:`, `icon:` — rather than resource keys. That means no
`TomTextResourceProvider` lookup is triggered, so each snippet compiles and runs
on its own with nothing to wire up first.

Tom widgets resolve their inputs in the constructor body (`late final` fields),
so they are **not** `const`-constructible. None of the snippets wrap a Tom
widget in `const`; copy them as-is.

## Component groups

Each group below maps to one file in `lib/groups/` and one screen in the app.

### Buttons — `groups/buttons_group.dart`

The Tom button family: elevated, filled (and tonal), text, outlined, icon and
floating-action buttons, plus the disabled state (`onPressed: null`).

```dart
TomElevatedButton(label: 'Save', onPressed: () {})
TomFilledButton(tonal: true, label: 'Continue', onPressed: () {})
TomIconButton(icon: const Icon(Icons.favorite), tooltip: 'Favorite', onPressed: () {})
```

### Labels & text — `groups/labels_group.dart`

`TomText`, `TomSelectableText`, `TomIcon`, `TomChip` and `TomBadge` — the
read-only display widgets.

```dart
TomText(text: 'Heading', style: Theme.of(context).textTheme.titleLarge)
TomChip(labelText: 'Flutter')
TomBadge(labelText: '5', child: TomIcon(icon: Icons.notifications))
```

### Cards & surfaces — `groups/cards_group.dart`

`TomCard`, `TomContainer` and `TomDivider` — the surfaces that group and
separate content.

```dart
TomCard(elevation: 2, child: Padding(
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
TomSlider(value: _value, min: 0, max: 100,
    onChanged: (v) => setState(() => _value = v))
```

### Progress — `groups/progress_group.dart`

`TomCircularProgressIndicator` and `TomLinearProgressIndicator`, determinate and
indeterminate.

```dart
TomCircularProgressIndicator()              // indeterminate
TomCircularProgressIndicator(value: 0.65)   // determinate
TomLinearProgressIndicator(value: 0.4)
```

### Layout — `groups/layout_group.dart`

`TomRow`, `TomColumn`, `TomExpanded` and `TomWrap` — the Tom mirrors of
Flutter's flex and spacing primitives.

```dart
TomRow(children: [
  TomExpanded(flex: 2, child: boxA),
  TomExpanded(flex: 1, child: boxB),
])
```

### Advanced container layout — `groups/acl_group.dart`

The fluent `AclBuilder` engine: compose components with preferred sizing,
borders and titles without nesting `Row`/`Column`.

```dart
AclBuilder()
    .append(name)
    .append(email)
    .setAclBorderStyle(AclBorderStyle.solid)
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
2. Give each component a `ShowcaseCell(title:, code:, child:)` — keep `code`
   verbatim with `child`.
3. Add the group to `showcaseGroups` in `lib/showcase_app.dart`.

The smoke test picks it up automatically (it iterates `showcaseGroups`), so a
new group that throws at build time fails CI without any extra test wiring.

## Tests

| File | Guards |
| --- | --- |
| `test/showcase_smoke_test.dart` | Every group screen builds and pumps without throwing; the home screen lists every group |
| `test/showcase_cell_test.dart` | A cell always renders **both** the snippet and the child; no cell has an empty snippet |

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

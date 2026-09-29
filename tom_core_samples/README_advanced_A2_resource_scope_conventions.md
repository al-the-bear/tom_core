# Appendix A2 · Scope, `basePath` & resource-key conventions

<!-- doc-samples: packages tom_core_kernel, tom_flutter_ui, tom_core_samples/advanced_app_client -->

*Appendix A2 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

Parts [07](README_advanced_07_authorization.md), [08](README_advanced_08_resources_texts.md)
and [09](README_advanced_09_forms_ui.md) each lean on one structural fact: a
field's **`basePath`** is the single name it uses to look up *both* its grade
*and* its text, and that name is `<scopePath>.<formId>.<tomId>`. This appendix is
the consolidated reference for that convention — how `basePath` is derived, how
one path serves two subsystems, the one deliberate member-name divergence
(`estimate`/`estimateHours`), how scoping is decided at construction (and how it
can silently break), and how the server's nested JSON resource tree is the same
information as the flat wire keys. It is the convention the whole "one name, two
uses" rule rests on, written down once.

## `basePath` = `<scopePath>.<formId>.<tomId>`

`basePath` is built in two hops, each a single line in the Tom Flutter UI form
layer:

1. **The form's `basePath`** = enclosing scope path + `formId`
   (`TomForm.prepareForSelfObservation` in
   `tom_flutter_ui/lib/src/forms/tom_form.dart`):
   ```dart
   scope    = TomScope.current;
   basePath = TomScopePath.qualify(formId, scope);
   ```
2. **The field's `basePath`** = the form's `basePath` + the field's `tomId`
   (the `TomField` constructor in `tom_form.dart`):
   ```dart
   scope    = form != null ? form!.basePath : TomScope.current.getScopePath();
   basePath = TomScopePath.join(scope, tomId);
   ```

Both hops go through `TomScopePath` (`tom_flutter_ui/lib/src/widget_base/tom_scope_path.dart`),
whose `join` is the one place the dot is inserted and the empty-parent case
handled — `qualify` is `join` applied to a scope's resolved path.

So a field's full path is `<enclosing-scope>.<formId>.<tomId>`. The `title` field
of an item form run under scope `todo` with `formId: 'item'` self-addresses as
`todo.item.title`; the `username` field of an unscoped `LoginForm` self-addresses
as `login.username`. The derivation is **structural**, computed once at field
construction from `form: this` — not a string the field carries — which is why a
field "cannot drift" from its own key.

Per **G-RES-6** there is no catalogue class; the three segments are named by the
convention, and the form, the server grade matrix, and the JSON texts all address
the same `todo.item.<field>` keys:

```
scope  = 'todo'   // the TomScope the item form runs under
formId = 'item'   // the form's formId
key    = '<scope>.<formId>.<field>'   // e.g. 'todo.item.title'
```

`todo.item.title` is *derived* structurally (`scopePath.formId.tomId`) rather than
written as a free string — so the wire key, the grade key, and the field's
`basePath` are the same token by construction, not by coincidence.

## One path, two uses

The single `basePath` is consumed by **two** subsystems, and the suffix is the
only thing that distinguishes them:

| Use | Key form | Lookup | Cited at |
| --- | --- | --- | --- |
| **Authorization** | `basePath` (**no suffix**) | `TomAuthorization.resolveAuth(basePath)` | layer 1 of `TomField.resolveEffectiveAuth` (`tom_form.dart`) |
| **Text resources** | `basePath.<suffix>` | `TomCtr.textOrNull(basePath, 'label')` → `<basePath>.<suffix>` | `TomField.resolvedLabel` (`tom_form.dart`) |

The suffix-join is one helper (`TomCtr._key`,
`tom_flutter_ui/lib/src/widget_base/tom_construction_helpers.dart`): an empty
suffix returns `basePath` verbatim, a non-empty suffix returns
`'$basePath.$suffix'`. So `todo.item.title` is *both* the grade key (no suffix)
*and* the stem of `todo.item.title.label`, `.hint`, `.error.required`. Granting a
role `read` on `todo.item.title` and installing a text for
`todo.item.title.label` therefore configure the *same field* from two servers,
keyed by one name with no translation layer. This symmetry is the headline rule;
A2 is just its specification.

The common suffixes:

| Suffix | Addresses | Example |
| --- | --- | --- |
| *(none)* | the field's authorization grade | `todo.item.title` |
| `label` | the display label | `todo.item.title.label` |
| `hint` | the input hint / placeholder | `login.username.hint` |
| `error.<code>` | a scoped validation message (falls back to a global key, then the raw key) | `todo.item.title.error.required` |

Screen chrome that is not a field uses the same flat-dotted shape with no field
segment — `login.title`, `board.empty`, `grants.title` — resolved through the
same provider.

## The `estimate` / `estimateHours` mismatch

There is exactly **one** deliberate divergence between a field's `tomId` and the
entity member it binds, and it exists to demonstrate that the two are
independent. The effort-estimate field:

- binds the reflected entity member **`estimateHours`** — `bind`/`save`
  round-trips on the *member name*, so the value lands in `TodoItem.estimateHours`
  (`TodoItemForm.createFormElements` in
  `advanced_app_client/lib/forms/todo_item_form.dart`,
  `TomFormNDoubleInput('estimate', …)`);
- carries `tomId` = **`estimate`**, so it self-addresses as `todo.item.estimate`
  — the graded/resourced key.

The resource key names the **concept** (`estimate`), not the **storage field**
(`estimateHours`). This works because the two keying systems read different
names:

| Mechanism | Keys on | Value for the estimate field |
| --- | --- | --- |
| grade / text lookup | `tomId` → `basePath` | `todo.item.estimate` |
| `bind` / `save` round-trip | reflected **member** name | `estimateHours` |

`TomField.tomId` and the Dart member name are free to differ precisely because
the round-trip keys on the member while authorization/text key on the `tomId`.
Every *other* item field keeps `tomId` == member name for simplicity; `estimate`
is the worked counter-example that proves the decoupling is real (the field's
`tomId` `estimate` and its member `estimateHours` deliberately differ).

## Scoped vs unscoped construction

Whether a form's fields land under a scope is decided **at construction**, by
whether a `TomScope` is pushed around the constructor call — not by anything the
form declares:

- **Unscoped.** The login form and the three admin editors are constructed
  plainly, so the form's `parentPath` is empty and its `basePath` *is* its
  `formId`. `UserForm` (`formId: 'user'`) gives `user.username`, `user.email`, …;
  `LoginForm` gives `login.username`, `login.password`.
- **Scoped.** The item editor **must** run under scope `todo` so its field paths
  equal the server's grade keys. The screen pushes the scope around the
  constructor (`_ItemDetailScreenState._resolveForm` in
  `advanced_app_client/lib/screens/item_detail_screen.dart`):
  ```dart
  final form = TomScope.withScope('todo', TodoItemForm.new);
  ```
  `TodoItemForm` itself only declares `super(formId: 'item')` (the
  `TodoItemForm` constructor in
  `advanced_app_client/lib/forms/todo_item_form.dart`); the `todo` scope comes
  from the **call site**, so the field at `tomId: 'title'` lands at
  `todo.item.title`.

> **This is the one place the "one name, two uses" rule can silently break.** If
> the item form were constructed *unscoped*, its fields would self-address as
> `item.title` (not `todo.item.title`); every grade lookup would miss and degrade
> closed-safe to `none`/hidden ([A1](README_advanced_A1_authorization_state_machine.md)),
> and every label would fall back to the raw `tomId`. Nothing throws — the screen
> just renders empty. The guard is that `scope`/`formId` are domain constants
> shared by the form, the seeded grant matrix, and the JSON texts, so the three
> cannot drift apart, and the scoped-construction widget tests (TC-30-*) assert
> the scoped paths resolve.

## How the JSON resource tree mirrors scope/form/field

The server's text assets are **nested JSON** structured exactly along
`scope → form → field → suffix`, so a resource file mirrors the screen it
describes (`advanced_app_server/assets/resources_app.json`):

```jsonc
{
  "todo":  { "item": { "title": { "label": "Title" }, "estimate": { "label": "Estimate (h)" }, … } },
  "board": { "title": "My Board", "empty": "No items yet", "item": { "save": "Save" } }
}
```

The nesting **is** the dotted key: `todo → item → title → label` *is*
`todo.item.title.label`. The server loads the asset once and **flattens** it to
the flat `<basePath>.<suffix>` map the wire bundle carries —
`flattenResourceTree` (`advanced_todo_contracts/lib/src/resource_bundle_dto.dart`)
walks the tree, joining each segment with `.`, descending only *map* nodes and
terminating a key at the first non-map value (so a scalar leaf like
`"board.title": "My Board"` flattens as written). The flattened
bundle is exactly the flat `<basePath>.<suffix>` map the wire contract
specifies, so the resource-endpoint and sentinel tests assert against it
directly (part [08](README_advanced_08_resources_texts.md)).

Note the JSON tree keys the estimate field under **`estimate`** (the resource-key
segment), not `estimateHours` (the member) — the asset mirrors the *`tomId`*
path, consistent with the mismatch above. The auth server follows the identical
shape with `resources_login.json` and `resources_admin.json`.

Two placement rules keep the flatten/load split web-safe (part 08):
`flattenResourceTree` is a **pure** function in the web-targetable `contracts`
package (no `dart:io`); the `File` read (`loadFlatResourceAsset`) lives in each
**server** package, which never targets web. The nested tree could be installed
directly (the `TomTextResourceProvider` supports nested dot-notation lookup), but
the servers flatten first so the served bundle stays the flat shape the wire
contract pins.

## Primary sources

- The `scope`/`formId`/`tomId` convention: segments are plain string literals declared at use — `formId` in `super(formId: 'item')`, scope in `TomScope.withScope('todo', …)` — resolved by naming, not catalogued as constants (G-RES-2/6)
- `tom_flutter_ui/lib/src/forms/tom_form.dart` — `TomForm.prepareForSelfObservation` (form `basePath`), the `TomField` constructor (field `basePath`), `TomField.resolveEffectiveAuth` (auth lookup), `TomField.resolvedLabel`
- `tom_flutter_ui/lib/src/widget_base/tom_construction_helpers.dart` (`TomCtr._key`/`textOrNull`)
- `advanced_app_client/lib/forms/todo_item_form.dart` — the `TodoItemForm` constructor (`formId: 'item'`), `TodoItemForm.createFormElements`; `advanced_app_client/lib/screens/item_detail_screen.dart` — `_ItemDetailScreenState._resolveForm`
- `advanced_todo_contracts/lib/src/resource_bundle_dto.dart` (`flattenResourceTree`); `advanced_app_server/assets/resources_app.json`
- Companions [08](README_advanced_08_resources_texts.md) / [09](README_advanced_09_forms_ui.md)

---

← Prev: [A1 · Four-state authorization deep dive](README_advanced_A1_authorization_state_machine.md) · Next: [A3 · A secured request, end to end](README_advanced_A3_request_lifecycle.md) →

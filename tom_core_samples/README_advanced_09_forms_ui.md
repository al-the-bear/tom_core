# Forms & UI

*Part 09 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

Parts [07](README_advanced_07_authorization.md) and
[08](README_advanced_08_resources_texts.md) established what a field's `basePath`
*means* — it is the one name a field uses to look up both its grade and its text.
This part shows where that `basePath` comes from: the `TomForm` / `TomField`
classes the sample's screens are built from, how a field derives its path from
its enclosing form and scope, how a bound form round-trips a reflected entity,
and how the two clients assemble those forms into screens. The convention deep
dive (why the JSON tree mirrors the form hierarchy, the `estimate` divergence) is
appendix [A2](README_advanced_A2_resource_scope_conventions.md).

## `TomForm` and `TomField`

A screen's editable surface is a `TomForm<T>` — a reflected container
(`T extends TomClass`) whose fields are declared as `late final` members:

```dart
@tomReflector
class LoginForm extends TomForm<LoginCredentials> {
  LoginForm() : super(formId: 'login');

  late final username = TomFormStringInput('username', '', form: this,
      validators: [Validators.required()]);
  late final password = TomFormStringInput('password', '', form: this,
      obscureText: true, validators: [Validators.required()]);

  @override
  void createFormElements() {}
}
```

Two things are doing the work here:

- **Each field is itself observable.** `TomField<T>` extends `TomObject<T>`
  (`tom_flutter_ui/.../tom_form.dart:592`), so a field *holds* its value, its
  validation state, and — via the authorization layer of part 07 — its resolved
  grade. A field renders itself: `field.widget` is a self-rebuilding widget
  (a `ValueListenableBuilder` wrapped in a `TomFieldWidgetAdapter`,
  `tom_form.dart:1163`) that the screen drops straight into its layout. The
  screen never builds a `TextField` for the form's fields by hand.
- **`createFormElements()` is empty on purpose.** The fields are declared as
  `late final` initializers rather than created inside that hook, so each field
  can capture `form: this` at its declaration site and derive its path from the
  form — independent of whatever scope happens to be current when reflection
  enumerates the members (see the next section).

The form's lifecycle — `bind`, `save`, `validate`, `discard` — fans out across
its fields (and any nested forms) through reflection; the screens drive only
those high-level verbs.

## `basePath` derivation

A field's `basePath` is built in two hops, each a single line in `tom_form.dart`:

1. **The form's `basePath`** = enclosing scope path + `formId`
   (`tom_form.dart:146`):
   ```dart
   basePath = parentPath.isNotEmpty ? '$parentPath.$formId' : formId;
   ```
2. **The field's `basePath`** = the form's `basePath` + the field's `tomId`
   (`tom_form.dart:614-617`):
   ```dart
   scope    = form != null ? form!.basePath : TomScope.current.getScopePath();
   basePath = scope.isNotEmpty ? '$scope.$tomId' : tomId;
   ```

So a field's full path is `<enclosing-scope>.<formId>.<tomId>` — exactly the
`basePath` parts 07 and 08 key resources and grades on. For `LoginForm` (no
enclosing scope) the `username` field self-addresses as `login.username`; for the
item editor (run under scope `todo`, below) the `title` field self-addresses as
`todo.item.title`, the wire grade key. The whole authorization/text contract
rests on this derivation — cross-link [A2](README_advanced_A2_resource_scope_conventions.md).

## Scoped vs unscoped construction

Whether a form is "scoped" is decided **at construction**, by whether a
`TomScope` is pushed around the constructor call:

- **Unscoped** — the login form and the three admin editors are constructed
  plainly, so their `parentPath` is empty and the form's `basePath` *is* its
  `formId`. `UserForm` (`formId: 'user'`) gives fields `user.username`,
  `user.email`, …; `LoginForm` gives `login.username`, `login.password`.
- **Scoped** — the item editor *must* run under scope `todo` so its field paths
  equal the server's grade keys (`todo.item.<field>`). The screen constructs it
  inside a pushed scope (`item_detail_screen.dart:88`):
  ```dart
  final form = TomScope.withScope(TodoItemResourceKeys.scope, TodoItemForm.new);
  ```
  `TodoItemForm` only declares `super(formId: 'item')`; the `todo` scope comes
  from the call site, so the field at `tomId: 'title'` lands at `todo.item.title`.

This is the one place the sample's "one name, two uses" rule could silently break
— if the item form were constructed unscoped, its fields would self-address as
`item.title` and every grade lookup would miss (degrading closed-safe to
`none`/hidden). The scope keys (`scope = 'todo'`, `formId = 'item'`) live as
constants in the shared domain's `resource_keys.dart`, so the form, the server
grade matrix, and the JSON texts cannot drift apart.

## Bound reflected forms

A bound form is the bridge between a typed entity and its editable widgets, both
ways, driven by reflection over **member names** (not `tomId`s):

- **`bind(target)`** snapshots the entity into the form:
  `setValues(target.getValues())` copies each entity member's value into the
  form's matching member, then runs the bind lifecycle (`tom_form.dart:196`).
- **`save()`** validates, then writes back: `_binding?.setValues(getValues())`
  copies the form members' values into the bound entity by member name
  (`tom_form.dart:315`/`:335`). Validation failures short-circuit the write and
  surface inline.

Because the round-trip keys on the **member** name, a field's `tomId` (which
drives its `basePath`/grade/text) is free to differ from the entity member it
binds. The item editor uses exactly this freedom: the effort field is the entity
member `estimateHours` (so `bind`/`save` round-trips into `TodoItem.estimateHours`)
but carries `tomId: 'estimate'`, so it self-addresses as the graded key
`todo.item.estimate` (D-A2). The sample's three bound-form families:

| Form | Binds | Scope · formId | Path shape |
| --- | --- | --- | --- |
| `LoginForm` | `LoginCredentials` | — · `login` | `login.<field>` |
| `AdminLoginForm` | `AdminLoginCredentials` | — · `adminLogin` | `adminLogin.<field>` |
| `TodoItemForm` | `TodoItem` | `todo` · `item` | `todo.item.<field>` |
| `UserForm` / `RoleForm` / `GroupForm` | `UserDraft` / `RoleDraft` / `GroupDraft` | — · `user`/`role`/`group` | `user.<field>`, … |

The app and admin login screens both bind a reflected `TomForm` and render
`field.widget`; their distinct `formId`s (`login` vs `adminLogin`) give them the
distinct public-bundle keys the auth server serves (part
[08](README_advanced_08_resources_texts.md)). All bound forms are `@tomReflector`
and captured in each client's `reflection_seed.dart`; regenerate only on a
reflected-signature change (part
[03](README_advanced_03_domain_reflection.md)).

## The `tom_flutter_ui` components

The forms are assembled from `tom_flutter_ui`'s field and source primitives —
the client packages add no field widgets of their own:

| Component | Used for |
| --- | --- |
| `TomFormStringInput` | free text (title, username, description; `obscureText` for passwords; `maxLines` for multi-line) |
| `TomFormStringDropdown` | enum-valued pickers (status, priority) over a `TomSelectableSource` |
| `TomFormNDateInput` | nullable dates (the item's due date) |
| `TomFormNDoubleInput` | nullable numbers (the estimate, `decimals: 1`) |
| `StaticSelectableSource` / `SelectableItem` | a fixed option list, *valued by the wire/enum token, labelled by `enum.label`* |
| `Validators.required()` | declarative per-field validation |
| `TomAuthorizer.fixed(state)` | a per-field grade override (the admin forms' stable-key fields — part 07) |

Each component derives its `basePath` from the form (above) and resolves its
label/hint/options from the installed resource bundle (part 08) and its grade
from the installed adapter (part 07). The dropdowns illustrate the
stored-name-vs-label split from part
[03](README_advanced_03_domain_reflection.md): the `SelectableItem` `value` is
the enum `name` the entity stores, the `label` is `enum.label`.

## The screens

The two clients layer screens over these forms. The **app client**
(`advanced_app_client`):

- **Login** (`login_screen.dart`) — the bound `LoginForm`; on submit `save()`s
  into `LoginCredentials`, folds them into a wire `LoginRequest`, and calls
  `AppSession.login`. A rejection surfaces inline without leaving the page.
- **Board** (`board_screen.dart`) — the signed-in home; cascades
  workspace→project→list→item reads and groups items into one column per
  `TodoStatus`. Its app-bar carries the **Share** action.
- **Item detail** (`item_detail_screen.dart`) — the bound `TodoItemForm`. It
  lays out the fields by rendering each `field.widget` and offers **Save** only
  when at least one field is editable (`item_detail_screen.dart:181`):
  ```dart
  final canSave = form.gradableFields.any((f) => f.isEditable);
  // …
  for (final field in form.gradableFields) ...[ field.widget, … ],
  ```
  `isEditable` is `effectiveAuthState == TomAuthState.full` (`tom_form.dart:838`),
  so the *same* form renders four ways by role with no per-screen branching —
  the authorization mechanism of part 07 doing the gating, not the screen.
- **Share dialog** (`share_dialog.dart`) — the cross-user half of the model;
  grants another user a `ProjectRole` on the selected project.

The **admin console** (`advanced_authadmin_client`):

- **Admin login + shell** — a bound `AdminLoginForm` (formId `adminLogin`) whose
  login is **two-phase** (authenticate, then *probe* an admin call, since
  `/admin/*` is gated by `@TomRoleAccess(['admin'])` not the login itself), then a
  `NavigationRail` over an `IndexedStack` of five destinations.
- **Users / Roles / Groups** — three thin configurations of the **generic**
  `AdminCrudScreen<T>` (one list/dialog/confirm skeleton, not three), opening a
  reflected editor (`UserForm`/`RoleForm`/`GroupForm`) bound to a client-local
  draft.
- **Grants** (`grants_screen.dart`) — the four-state matrix editor: a `DataTable`
  of `projectRole` × field-resource-key whose cells cycle
  `none → disabled → read → full`; **Save** `PUT`s the whole `GrantMatrixDto` and
  re-reads it. This is the screen that *writes* the matrix part 07 reads.
- **Assignments** (`assignments_screen.dart`) — grants an account a role and/or
  group via a single `AssignmentRequest`.

Both clients are covered in depth in part
[11](README_advanced_11_clients_app_admin.md); the secured endpoints they call
in part [10](README_advanced_10_servers_endpoints.md).

## Observing widgets

The sample's reactivity has two layers, both pull-based:

- **Session → shell.** Each client's `AppSession` / `AdminSession` is a
  `ChangeNotifier`; the app root wraps its home in a Flutter `ListenableBuilder`
  (`app_root.dart:28`, `admin_root.dart:31`), so the login↔home swap is a pure
  function of `session.isLoggedIn` — login, logout, and a guarded `401` all
  rebuild the shell by calling `notifyListeners()`.
- **Field → widget.** Because `TomField` is a `TomObject` observable, its
  `field.widget` self-rebuilds on value, validation, or grade change without the
  screen re-laying-out the form. The `TomFieldWidgetAdapter` wrapper additionally
  exposes the field's `TomAuthorizable` state to an enclosing `AclContainer`'s
  hide-unauthorized pass, which is how a `none`-graded field disappears from the
  layout entirely (part 07's closed-safe default).

## Primary sources

- [`advanced_app_client/README.md`](advanced_app_client/README.md), [`advanced_authadmin_client/README.md`](advanced_authadmin_client/README.md)
- `advanced_app_client/lib/forms/{login_form,todo_item_form}.dart`; `advanced_authadmin_client/lib/forms/{user_form,role_form,group_form}.dart`
- `advanced_app_client/lib/screens/item_detail_screen.dart:88` (`TomScope.withScope`), `:181-188` (`field.widget` / `isEditable` gate)
- `tom_flutter_ui/.../tom_form.dart:24` (`TomForm`), `:146` (form `basePath`), `:592`/`:614-617` (`TomField` / field `basePath`), `:196` (`bind`), `:315`/`:335` (`save`), `:838` (`isEditable`), `:1163` (`field.widget`)
- `advanced_todo_domain/lib/src/resource_keys.dart` (`scope`/`formId` constants)
- `advanced_example_specification_plan.md` — A.8, A.9, Phases 5 & 6; appendix [A2](README_advanced_A2_resource_scope_conventions.md)

---

← Prev: [08 · Resources & text externalization](README_advanced_08_resources_texts.md) · Next: [10 · Servers & the secured endpoint pipeline](README_advanced_10_servers_endpoints.md) →

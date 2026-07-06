# Domain model & reflection

*Part 03 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

The domain is the **one source of truth the whole stack agrees on**: the app
server persists these entities, the clients edit them, the wire contract carries
them, and the authorization layer grades their fields. This part covers the
reflected `TomClass` entities and how `@tomReflector` makes them observable and
persistable; the **single reflection seed** that wires them into a running
program; the enums and their stored-name/label contract; and
`resource_keys.dart` — the **scope/form/field source of truth** that the
authorization (part [07](README_advanced_07_authorization.md)) and resource (part
[08](README_advanced_08_resources_texts.md)) stories both build on.

## The reflected entities

Eight entities live in [`advanced_todo_domain`](advanced_todo_domain/README.md),
each a `@tomReflector class … extends TomClass`. They form a strict **ownership
chain** plus two satellites:

```
Workspace → Project → TodoList → TodoItem
                                    ├── Subtask
                                    └── TodoComment
User                Share (User × Project → ProjectRole)
```

| Entity | Role |
| --- | --- |
| `Workspace` | Root of the ownership chain; an owner's top-level container. |
| `Project` | A project inside a workspace; relations are flat foreign keys (`workspaceId`), not nested lists, so each entity persists as one row. |
| `TodoList` | Middle of the hierarchy; `position` orders lists within a project. |
| `TodoItem` | The core record — a single task; **its fields are the subject of four-state field authorization**. |
| `Subtask` | Lightweight sub-step of an item (`done` toggles, `position` orders). |
| `TodoComment` | A comment in the item-detail thread; `authorId` points at a `User`. |
| `User` | An account; `status` stored as a `UserStatus` name. |
| `Share` | Grants a `User` a `ProjectRole` on a `Project` — the row the app server reads to resolve access and field grades. |

`TodoItem` is the centre of gravity: its gradable fields (`title`, `status`,
`priority`, `assigneeId`, `dueDate`, `estimateHours`/`estimate`, `description`)
are exactly the fields the grant matrix grades per principal.

## `@tomReflector` and observable `TomClass`

Every entity extends `TomClass` and holds its state in **`Tom*` observable
fields** rather than plain Dart fields:

```dart
@tomReflector
class TodoItem extends TomClass {
  late final id = TomString('');
  late final title = TomString('');
  late final status = TomString(TodoStatus.backlog.name);
  late final dueDate = TomNDateTime(null);
  late final estimateHours = TomNDouble(null);
  late final tags = TomList<TomString>();
  // …
}
```

The `@tomReflector` annotation marks the class for the reflection generator;
`TomString` / `TomNDateTime` / `TomNDouble` / `TomList` are observable cells with
`get()`/`set()` that the kernel reads and writes **by reflection**. That single
mechanism is what lets the same entity be persisted by the server's repositories,
serialized to a DTO, bound into a `TomForm`, and observed by a Flutter widget —
without any per-entity boilerplate. Forms in particular lean on it: a `TomForm`
is itself a reflected `TomClass`, and `bind`/`save` enumerate a form's fields
through kernel reflection (part [09](README_advanced_09_forms_ui.md)).

## The single reflection seed

The generator only processes files that expose a `main()` and follows the import
graph from there. The domain's seed is `lib/src/reflection_entry.dart` — a file
that exists **solely to root the generator**, never run in production. Its
`main()` simply *touches* each reflected type so the imports are retained and the
generator can reach every entity:

```dart
void main() {
  User(); Workspace(); Project(); TodoList(); TodoItem();
  TodoComment(); Subtask(); Share();
  TodoStatus.values; TodoPriority.values; TodoLabel.values;
  UserStatus.values; ProjectRole.values;
}
```

The generator emits `reflection_entry.reflection.dart`, and the barrel
(`advanced_todo_domain.dart`) re-exports its `initializeReflection`. Consumers
call `initializeReflection()` **once at startup, before constructing any
reflected entity**.

> **Last-writer-wins — one seed per program.** The generated
> `initializeReflection()` *assigns* the reflection data, so exactly one seed may
> run per program. The domain library carries its own; the clients carry their
> own seed that covers the domain entities **plus** the client-local forms (which
> is why those seeds import the domain but do not re-export it — that would
> collide with the form seed's `initializeReflection`). This build-time
> constraint is laid out in part [02](README_advanced_02_project_layout_build.md#reflection-generation).

## Enums: stored-name vs label contract

Five closed-set enums live in `enums.dart`: `TodoStatus`, `TodoPriority`,
`TodoLabel`, `UserStatus`, and `ProjectRole`. Each follows the same two-part
contract:

- **Stored as `Enum.name`.** On its owning entity the enum is held as its
  `.name` in a `TomString` (e.g. `status = TomString(TodoStatus.backlog.name)`),
  so it round-trips to SQL and JSON **without a custom codec**. Typed accessors
  (`statusValue`, `priorityValue`, `labelValue`, …) convert the stored name back
  to the enum and fall back to a sensible default for an unknown stored value.
- **Labelled by an extension.** A `…Text` extension gives each value a
  human-facing `label` (`TodoStatus.inReview.label == 'In review'`). These are
  the in-code display strings; the *server-delivered* UI texts are a separate,
  externalized concern (part [08](README_advanced_08_resources_texts.md)).

`ProjectRole { owner, editor, commenter, viewer }` is special: the effective role
(from ownership or a `Share`) is exactly what the auth server's grant matrix keys
field grades on — `(ProjectRole, resourceKey) → TomAuthState`.

## Scope + `tomId` addressing (no key catalogue)

Per **G-RES-6**, resource keys are **addressed by scope + `tomId`, resolved at
the point of use** — there is *no* class cataloguing them as constants. The
gradable `TodoItem` fields are named by the convention

```
<scope>.<formId>.<field>   ==   todo.item.<field>
```

so the same key means the same field on the server, over the wire, and in the
client without any shared symbol to import. This is the **one-path-two-uses**
convention made concrete. The Flutter UI form layer derives each field's
`basePath` as `<scopePath>.<formId>.<tomId>` and uses that single path two ways —
as the **authorization** key (no suffix), and as the base for the field's
**resource** keys (`<basePath>.label`, `.hint`, `.<errorKey>`, …). The keys are
therefore **derived** from `scope` / `formId` / the field's `tomId` at
construction, and the form must run under `scope = 'todo'` with `formId = 'item'`
for each field to self-address as the key the server graded:

```dart
// TodoItemForm declares scope-relative tomIds; the 'todo' scope is pushed at the
// call site (item_detail_screen.dart), so `title` self-addresses as
// `todo.item.title`.
TomScope.withScope('todo', TodoItemForm.new); // form basePath == 'todo.item'
// field tomId 'title'    -> basePath 'todo.item.title'
// field tomId 'estimate' -> basePath 'todo.item.estimate' (member: estimateHours)
```

One deliberate mismatch is worth flagging: the estimate key is `todo.item.estimate`
even though the entity member is `estimateHours` — **the resource key names the
*concept*, not the storage field**, so the gradable form field carries
`tomId: 'estimate'` while its reflected member stays
`estimateHours`. Appendix [A2](README_advanced_A2_resource_scope_conventions.md)
unpacks the full `basePath` convention and this mismatch; part
[07](README_advanced_07_authorization.md) shows the grant matrix that keys on
these strings, and part [08](README_advanced_08_resources_texts.md) shows the
resource bundles keyed on `<basePath>.<suffix>`.

## Primary sources

- [`advanced_todo_domain/README.md`](advanced_todo_domain/README.md) — per-entity detail.
- `advanced_todo_domain/lib/src/` — the entities, `enums.dart`, and the `reflection_entry.dart` seed.
- `advanced_example_specification_plan.md` — A.3 Extended domain model, Phase 1 steps 1–4.

---

← Prev: [02 · Project layout, packages & build](README_advanced_02_project_layout_build.md) · Next: [04 · Wire contracts & DTOs](README_advanced_04_wire_contracts_dtos.md) →

# Tom Core — Client Sample (Todo)

A small but **complete Flutter application** built on the Tom Core client stack:
`tom_core_kernel` for the observable/reflection/authorization model,
`tom_core_flutter` for the client runtime, and `tom_flutter_ui` for bound forms.
It is the *consumer* counterpart to [`core_server_sample`](../core_server_sample)
— it shares the same domain ([`todo_domain`](../todo_domain)) and the **same
four-state authorization matrix**, so the two tiers tell one consistent story.

Where the sibling [`core_flutter_form_showcase`](../core_flutter_form_showcase)
is a feature *tour* — one cell per API — this sample is the opposite: a single,
ordinary app (sign in, browse a list, edit a record) that wires those features
together the way a real screen does. The interesting parts are not the widgets;
they are the **seams**: how a form binds a reflected entity, how a role's
authorization matrix turns into per-field render states, and how the backend is
kept behind one interface so the app runs identically offline or against the
live server.

> **TL;DR** — Run `flutter run`. Sign in as `alice`, `bob` or `val` (any
> non-empty password). Browse the todo list, tap an item to edit it, and notice
> how the *same* editor screen renders differently depending on who you are.

---

## Table of contents

1. [What you are looking at](#1-what-you-are-looking-at)
2. [Running the sample](#2-running-the-sample)
3. [Architecture at a glance](#3-architecture-at-a-glance)
4. [The backend seam: one interface, two implementations](#4-the-backend-seam-one-interface-two-implementations)
5. [The mental model: forms bind reflected entities](#5-the-mental-model-forms-bind-reflected-entities)
6. [Bootstrap: reflection must come first](#6-bootstrap-reflection-must-come-first)
7. [Four-state authorization, end to end](#7-four-state-authorization-end-to-end)
8. [The login flow](#8-the-login-flow)
9. [The list and detail screens](#9-the-list-and-detail-screens)
10. [The live read path](#10-the-live-read-path)
11. [Project layout](#11-project-layout)
12. [Reflection regeneration](#12-reflection-regeneration)
13. [Tests](#13-tests)
14. [Known limitations and the cross-tier work](#14-known-limitations-and-the-cross-tier-work)

---

## 1. What you are looking at

The app has three screens and one job: edit todos under role-based field
authorization.

| Screen | File | Teaches |
| ------ | ---- | ------- |
| **Login** | `lib/screens/login_screen.dart` | A bound `TomForm<LoginCredentials>` driving an authentication call |
| **List** | `lib/screens/todo_lists_screen.dart` | Listing entities, navigation, the live-refresh action, logout |
| **Detail** | `lib/screens/todo_detail_screen.dart` | A bound `TomForm<TodoItem>` whose fields are gated by the session's `TomAuthState` matrix |

The three demo accounts map onto the three roles the matrix grades:

| Account | Role | What they can do |
| ------- | ---- | ---------------- |
| `alice` | `owner` | Edit every field |
| `bob` | `member` | Cannot *see* `priority`; cannot change the assignee |
| `val` | `viewer` | Read-only everywhere; the `done` toggle renders disabled |

That matrix is not invented here — it is the **client-side twin of the grants
`core_server_sample` seeds into `tom_resource_grant`** via its
`[001]-todo_authz_grants.sql` migration. Keeping the two in lock-step is what
makes the four states render identically whether the app runs offline or talks
to the server.

---

## 2. Running the sample

```bash
flutter run
```

The app starts on the login screen against the in-memory backend (no server
required). To exercise the live read path against a running `core_server_sample`:

```bash
# 1. start the server sample (in its own folder)
dart run bin/server_start.dart        # serves http://localhost:8080

# 2. run the client with the live URL wired in
flutter run --dart-define=LIVE_SERVER_URL=http://localhost:8080
```

With `LIVE_SERVER_URL` set, the list screen gains a **cloud-download** action
that pulls todos straight from the server's `GET /todos`. Without it, that
action is hidden and everything runs in memory.

---

## 3. Architecture at a glance

```
                       ┌──────────────────────────┐
   main.dart  ─────────►  initializeReflection()   │  (reflection first!)
                       │  setCurrentPlatform(...)   │
                       │  setAppResourceProvider()  │
                       └────────────┬───────────────┘
                                    │
                          TodoApp (MaterialApp)
                                    │  ListenableBuilder(session)
                    ┌───────────────┴────────────────┐
              not logged in                       logged in
                    │                                  │
              LoginScreen                       TodoListsScreen ──► TodoDetailScreen
                    │                                  │                    │
              LoginForm                          AppSession            TodoItemForm
            (TomForm<LoginCredentials>)        (ChangeNotifier)   (TomForm<TodoItem> + authz)
                    │                                  │                    │
                    └──────────────► TodoApi ◄─────────┴────────────────────┘
                                       │
                    ┌──────────────────┴───────────────────┐
            InMemoryTodoApi                    (HTTP write/login — cross-tier)
          (default; tests)                   LiveTodoReadClient (live reads only)
```

Layers point downward only: screens depend on `AppSession` and the form classes;
those depend on `TodoApi`; `TodoApi` depends on the domain. Nothing reaches back
up.

---

## 4. The backend seam: one interface, two implementations

The app is written against an **abstract** `TodoApi` (`lib/api/todo_api.dart`),
never a concrete backend:

```dart
abstract class TodoApi {
  Future<LoginResult> login(String username, String password);
  Future<List<TodoItem>> listItems();
  Future<TodoItem> saveItem(TodoItem item);
  Future<void> deleteItem(String id);
  Future<Map<String, TomAuthState>> fieldStates(String role);
}
```

Two things implement (or partially implement) the read side of that contract:

- **`InMemoryTodoApi`** — the default. A fully working, seeded backend: three
  users, three todos, and the grant matrix copied verbatim from the server's
  migration. It powers the offline app *and* every widget test, so the tests
  never touch a socket.
- **`LiveTodoReadClient`** — an honest thin HTTP client over the server's three
  read-only endpoints (`GET /health`, `GET /todos`, `GET /todos/field-states`).
  Its JSON→entity mapping is factored into the pure functions `parseTodos` /
  `parseFieldStates` / `parseAuthState`, which are unit-tested against captured
  server responses.

**Why two, rather than one HTTP backend?** Because `core_server_sample` today
exposes a *read-only* surface — it has no login or write endpoints. Pretending it
did (by throwing `UnimplementedError` from a half-written HTTP `TodoApi`) would
be dishonest and untestable. Instead the writes and login run in memory, the
live reads run over the wire, and the gap between them is documented as the
[cross-tier work](#14-known-limitations-and-the-cross-tier-work). Swap
the backend in exactly one place — `main.dart` — and the whole app follows.

---

## 5. The mental model: forms bind reflected entities

A Tom form is not a bag of controllers. It is a `TomForm<T extends TomClass>`
whose field **member names match the bound entity's field names**, so binding is
a reflection round-trip rather than hand-written copy code:

```dart
@tomReflector
class TodoItemForm extends TomForm<TodoItem> {
  late final title = TomFormStringInput('title', '', form: this, /* … */);
  late final done  = TomFormBoolSwitch('done', false, form: this, /* … */);
  // …priority, assigneeId, description — each id matches a TodoItem field.
}
```

`form.bind(todoItem)` reads the entity's values into the fields through kernel
reflection; `form.save()` writes them back the same way. No field-by-field
plumbing, and adding a field to the entity is a one-line change to the form. The
price is that **both the entity and the form must be in the reflected graph** —
see the next section.

### Validators are resources, not per-field closures (G-UI-7)

A field's validators are declared **by name in the resource bundle**, not
hand-coded as one-off closures. Each validated field carries a
`<basePath>.validators` entry — a comma-separated spec — that `TomField`
resolves through the DI-swappable `TomValidatorRegistry` (built-ins
`required`/`email`/`minLength`/`maxLength`/`pattern`/`min`/`max`, plus any the
app registers). The login fields take the pure resource path:

```dart
// app_texts.dart
'login.username.validators': 'required',
'login.password.validators': 'required',

// login_form.dart — no `validators:` argument at all
late final username = TomFormStringInput('username', '', form: this);
```

`TomField` **merges** code-supplied and resource-declared validators, so a field
can have both. `TodoItemForm.title` is the illustration: `required` is declared
as a resource (the framework built-in, naturally a resource), while an
app-specific "no leading/trailing whitespace" rule — orthogonal to any built-in —
stays in code, which is exactly when a code validator is the right tool:

```dart
// app_texts.dart
'todo.item.title.validators': 'required',

// todo_item_form.dart
late final title = TomFormStringInput('title', '', form: this,
    authorizer: _authFor('title'), validators: [_noSurroundingSpace]);
// effective validators = [_noSurroundingSpace] (code) + [required] (resource)
```

**Validation messages are resources too (G-RES-1).** A failed validator emits an
`error.<name>` key (`error.required`, and the code rule's `error.titleWhitespace`)
that resolves from the same bundle — scoped `<basePath>.error.<name>` first, then
global `error.<name>` — so no message string is ever hardcoded. `test/
validator_resolution_test.dart` (CCS-VAL-01…05) pins the resource-only path, the
merge, and both resolved messages.

---

## 6. Bootstrap: reflection must come first

Three things happen in `main.dart` before `runApp`, in order:

```dart
void main() {
  initializeReflection();                                   // 1
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils); // 2
  TomTextResourceProvider.setAppResourceProvider(           // 3
    TomTextResourceProvider.from(appTexts),
  );
  runApp(TodoApp(session: AppSession(InMemoryTodoApi())));
}
```

1. **Reflection.** The forms bind reflected `@tomReflector` entities, so the
   field metadata must be registered before any form is constructed.
2. **Platform.** `clientPlatformUtils` (from `tom_core_flutter`) selects the
   Flutter platform implementation for kernel code that probes the runtime.
3. **Resource provider.** The `appTexts` bundle (`lib/resources/app_texts.dart`)
   is installed so every visible string — form-field labels/hints, screen copy,
   tooltips, errors, and enum display text — resolves through the singleton
   provider (G-RES-1). No widget carries hardcoded text.

**Why one reflection seed for everything.** The generated
`initializeReflection()` *assigns* the reflection data (last writer wins), so
exactly one seed's `initializeReflection()` may run per program. This app's seed
(`lib/reflection_seed.dart`) is that one — and because the forms bind
**cross-package** `todo_domain` entities (`TodoItem`, `User`) alongside the
client-local `LoginCredentials`, the seed imports all of them so the generator
emits one graph covering the lot. (`todo_domain` is imported for discovery but
deliberately *not* re-exported, to avoid colliding with its own
`initializeReflection`.)

---

## 7. Four-state authorization, end to end

`TomAuthState` has four values, and each renders distinctly on a form field:

| State | Render |
| ----- | ------ |
| `full` | Fully interactive and editable |
| `read` | Shows its value but cannot be edited |
| `disabled` | Visible but greyed out and non-interactive |
| `none` | Hidden entirely — the field collapses to nothing |

The flow is: **role → matrix → per-field authorizer → render**.

1. On login, `AppSession.login` calls `api.fieldStates(role)` and stores the
   resulting `Map<String, TomAuthState>` (keyed by the plain gradable-field
   resource keys — `todo.item.title`, `todo.item.done`, … — there is no
   `*ResourceKeys` catalogue class, G-RES-6).
2. The detail screen constructs `TodoItemForm(session.fieldStates)`.
3. The form turns each entry into a `TomAuthorizer.fixed(state)` on the matching
   field:

   ```dart
   TomAuthorizer _authFor(String key) =>
       TomAuthorizer.fixed(fieldStates[key] ?? TomAuthState.none);

   late final priority = TomFormStringDropdown(
     'priority', TodoPriority.medium.name,
     form: this, source: _prioritySource,
     authorizer: _authFor('todo.item.priority'),
   );
   ```

4. `tom_flutter_ui` resolves the authorizer at build time and renders the field
   accordingly.

The payoff is in `todo_detail_screen.dart`: **the same screen, with no
conditionals**, shows `owner` a full editor, hides `priority` from `member`
(because their grant is `none`), and gives `viewer` a read-only form with a
disabled `done` toggle. A field absent from the matrix degrades to `none` — the
closed-safe default, matching the server's resolver — so an unconfigured field
hides rather than leaking an editable control.

---

## 8. The login flow

`LoginScreen` owns a `LoginForm` bound to a fresh `LoginCredentials`. On submit:

```dart
if (!await _form.save()) return;   // validation failed; fields show errors
await session.login(
  _credentials.username.get(),
  _credentials.password.get(),
);
```

`save()` writes the typed form fields back into the bound credentials through the
reflection round-trip, then the values are handed to the session. A rejected
login throws a `TodoApiException`, which the screen catches and shows inline
without leaving the page. A successful login flips `AppSession.isLoggedIn`, and
the app shell's `ListenableBuilder` swaps in the list screen.

---

## 9. The list and detail screens

`TodoListsScreen` loads items from `session.api.listItems()`, shows the role
badge and logout, and opens the detail screen on tap (or via the **+** FAB for a
new item). When it returns from a save it reloads.

`TodoDetailScreen` is where the authorization model is visible. It builds the
gated `TodoItemForm`, renders the field widgets (`_form.title.widget`, …), and on
Save calls `_form.save()` then `session.api.saveItem(item)`. Because the form is
constructed with the session's matrix, the screen needs **no role logic of its
own** — the four states do the work.

**Notifications and navigation: Tom presenter + Tom route (G-UI-1).**
Two touchpoints on `TodoListsScreen` go through Tom primitives rather than the
raw Flutter mechanisms. The snackbar is shown with
`TomMessenger.showSnackBar(context, TomSnackBar(...))`: `TomMessenger` is
tom_flutter_ui's Tom-owned presenter, wrapping `ScaffoldMessenger` the same way
the Tom widgets wrap their Flutter counterparts. The detail screen is opened
with `Navigator.of(context).push(TomPageRoute(...))`: `TomPageRoute` captures
the active `TomScope` at push time and re-enters it around the pushed screen's
builder, so the screen constructs in the pushing scope rather than the
Navigator's zone — closing the scope-propagation gap G-UI-6 warns about (a
form's scope "is usually a Flutter route"). Both primitives were added by quest
todo **RCD2**.

---

## 10. The live read path

`LiveTodoReadClient` is a deliberately small `dart:io HttpClient` over the
server's read endpoints. The networking is trivial; the value is in keeping the
**mapping pure**:

```dart
List<TodoItem> parseTodos(Map<String, dynamic> body) { … }
Map<String, Map<String, TomAuthState>> parseFieldStates(Map<String, dynamic> body) { … }
TomAuthState parseAuthState(String? token) =>
    TomAuthState.values.asNameMap()[token] ?? TomAuthState.none;
```

Those functions are unit-tested against captured JSON with no socket in the
test, which is why the live path is verifiable even though the server must be
running to exercise it for real. The list screen's cloud-download action calls
`fetchTodos()` and swaps the view to live data behind a "showing live server
data (read-only)" banner — an honest demonstration of a real wire round-trip
that never pretends the in-memory edits reach the server.

---

## 11. Project layout

```
core_client_sample/
├── lib/
│   ├── main.dart                       # bootstrap: reflection → platform → provider → runApp
│   ├── reflection_seed.dart            # the one seed reflecting entities + forms
│   ├── reflection_seed.reflection.dart # GENERATED — do not edit
│   ├── api/
│   │   ├── todo_api.dart               # abstract backend contract + LoginResult / TodoApiException
│   │   ├── in_memory_todo_api.dart     # seeded offline backend + grant matrix
│   │   └── live_todo_read_client.dart  # HTTP read client + pure parsers
│   ├── domain/
│   │   ├── login_credentials.dart      # client-local @tomReflector entity
│   │   └── enum_text.dart              # resolves a domain enum's display text (G-RES-5)
│   ├── resources/
│   │   └── app_texts.dart              # the installed user-facing text bundle (G-RES-1)
│   ├── forms/
│   │   ├── login_form.dart             # TomForm<LoginCredentials>
│   │   └── todo_item_form.dart         # TomForm<TodoItem> with per-field authorizers
│   ├── app/
│   │   ├── app_session.dart            # ChangeNotifier: user, token, field matrix
│   │   └── todo_app.dart               # MaterialApp shell, login↔list switch
│   └── screens/
│       ├── login_screen.dart
│       ├── todo_lists_screen.dart
│       └── todo_detail_screen.dart
└── test/
    ├── in_memory_api_test.dart         # backend contract: login / CRUD / matrix
    ├── live_read_client_test.dart      # pure JSON parsers
    ├── login_flow_test.dart            # widget: sign in / out, inline error
    └── todo_crud_test.dart             # widget: CRUD + per-role field states
```

---

## 12. Reflection regeneration

`reflection_seed.reflection.dart` is generated and **must not be hand-edited**.
Regenerate it only when a reflected **signature changes** (a form field added or
renamed, or a bound entity's shape changes):

```bash
./reflection_generation.sh
```

The script runs `dart run tom_reflection_generator` flag-free over
`lib/reflection_seed.dart` (configured in `build.yaml`); the generator scans the
current project only (framework default scan `.`, non-recursive). The generated file is
large because reflecting a form necessarily reflects its field types — the same
trade-off the verified `tom_flutter_form_test` accepts.

---

## 13. Tests

```bash
flutter test --concurrency=1
```

Flutter tests in this workspace are run **serially** (`--concurrency=1`).
Thirty-five tests cover the seams:

| File | Covers |
| ---- | ------ |
| `in_memory_api_test.dart` | login validation, CRUD, the four-state matrix per role (CCS-API-01…13) |
| `live_read_client_test.dart` | the pure `parse*` functions against captured JSON (CCS-LIVE-01…05) |
| `login_flow_test.dart` | sign in / out, inline error, screen switching (CCS-LOGIN-01…04) |
| `todo_crud_test.dart` | per-role field rendering + create/validate (CCS-CRUD-01…04) |
| `todo_item_form_test.dart` | the single field identity: basePath = wire/authz key (CCS-FORM-01…04) |
| `validator_resolution_test.dart` | resource-declared validators, code+resource merge, resolved messages (CCS-VAL-01…05) |

The widget tests drive `InMemoryTodoApi`, so they are deterministic and
socket-free.

Being a Flutter GUI app, this sample has no headless `example/` folder or
`run_all_examples.dart` aggregator (those apply to pure-Dart samples like
`todo_domain` and `core_server_sample`). The runnable entry point is the app
itself — `lib/main.dart` — and this serial widget-test suite is its smoke
test: it exercises every screen, form, and the four-state matrix end to end.

---

## 14. Known limitations and the cross-tier work

This sample is honest about the seam it cannot yet cross:

- **Login and writes are in-memory.** `core_server_sample` exposes only read
  endpoints today, so there is no live login or persistence over the wire. The
  client models them with `InMemoryTodoApi` and isolates them behind `TodoApi`.
- **The live path is read-only.** `LiveTodoReadClient` covers `GET /health`,
  `GET /todos` and `GET /todos/field-states` — a genuine round-trip, but a read.

Closing that gap — server-side login + write endpoints and a full HTTP
`TodoApi` — is the **cross-tier work**. When it lands, the single
backend swap in `main.dart` is the only client change required: the screens,
forms, session and authorization model are already written against the
interface, not the transport.

> **The cross-tier work is now realized — in a dedicated suite.** Rather than retrofit live
> login and writes onto this read-only pair, the secured, full-stack version is
> built as its own series: the
> [**Advanced Tom Core Full-Stack Sample**](../README_advanced_sample.md) — two
> servers (JWT auth/admin + secured app), two databases, and two Flutter clients,
> with live login, write endpoints, an authenticated HTTP client that presents
> and refreshes a bearer token, per-principal four-state field grading over the
> wire, and cross-user sharing. This sample stays intentionally read-only and
> in-memory for teaching; the advanced suite is where the full cross-tier loop
> runs end-to-end (verified by its `run_cross_tier_integration.sh`).

---

## Where this sits

- **Repo map:** [`tom_ai/core/README.md`](../../README.md)
- **Sample suite index:** [`tom_core_samples/README.md`](../README.md)
- **The kits on display:** [`tom_core_flutter`](../../tom_core_flutter/README.md)
  (platform + runtime) and [`tom_flutter_ui`](../../tom_flutter_ui/README.md)
  (the bound `TomForm`s and four-state field rendering), on
  [`tom_core_kernel`](../../tom_core_kernel/README.md) (reflection, `TomAuthState`)
- **Shared model:** [`todo_domain`](../todo_domain/readme.md) — the reflected
  `TodoItem`/`User` entities the forms bind
- **Sibling sample:** [`core_server_sample`](../core_server_sample/README.md) —
  the backend whose grant matrix this client mirrors and whose read endpoints the
  live path consumes
- **Secured, full-stack successor:**
  [`README_advanced_sample.md`](../README_advanced_sample.md) — the advanced
  suite that closes the [cross-tier gap](#14-known-limitations-and-the-cross-tier-work)
  with live login, writes, bearer auth, and cross-user sharing

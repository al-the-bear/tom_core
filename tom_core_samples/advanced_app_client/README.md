# advanced_app_client

End-user Flutter app for the **advanced Tom Core full-stack sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Logs in against `advanced_auth_server`, presents the bearer token on every call
to `advanced_app_server`, and renders a status-column task board with per-field
four-state authorization driven live over the wire, plus cross-user sharing.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[09 · Forms & UI](../README_advanced_09_forms_ui.md)** and
> [11 · The two Flutter clients](../README_advanced_11_clients_app_admin.md).

## Status

Cross-user sharing landed (step 31) — the app is feature-complete. On top of the
login screen, session, board, and bound item-detail editor, the board's app-bar
now carries a **Share** action: the owner of the selected project grants another
user a `ProjectRole`, and the grantee's next read sees the project. A non-owner's
share is refused inline (only the owner may share). The app boots on its own
generated `reflection_seed.dart` (capturing the shared domain entities + the
client-local credentials/forms in one init). The full run instructions — both
servers plus this client — are in the [Running the full stack](#running-the-full-stack)
guided tour below.

## AppBackend seam

`lib/backend/backend.dart` is the barrel. Bind every screen against the
transport-independent `AppBackend` (`app_backend.dart`), never a concrete
backend, so the same widgets drive either implementation:

- **`InMemoryAppBackend`** — a seeded, socket-free fake the widget and contract
  tests bind. It constructs the reflected domain entities in-process and mirrors
  the server's ownership + sharing model and per-role four-state field matrix, so
  it is the contract any live backend must honour.
- **`LiveAppBackend`** — the production wiring: a thin adapter over an
  `AuthClient` (login/token storage against `advanced_auth_server`) and an
  `AppApiClient` (the board API against `advanced_app_server`) sharing one
  `JsonTransport`. It folds the server's per-field grade list into the UI-shaped
  `resourceKey → TomAuthState` map and normalises the client core's transport
  exceptions into the single `AppBackendException` the screens catch.

```dart
final AppBackend backend = InMemoryAppBackend(); // or LiveAppBackend(auth, api)
await backend.login(LoginRequest(username: 'alice', password: 'pw'));
final workspaces = await backend.listWorkspaces();
final states = await backend.itemFieldStates('i-1'); // resourceKey → TomAuthState
```

## App shell (bootstrap + session)

`lib/main.dart` performs the four bootstrap steps — reflection → platform →
resource provider → `runApp` — and injects an `AppSession` over the chosen
backend (the seeded `InMemoryAppBackend` by default; pass
`--dart-define=AUTH_SERVER_URL=… --dart-define=APP_SERVER_URL=…` to drive the
live stack through `LiveAppBackend`).

`AppSession` (`lib/app/app_session.dart`) is a `ChangeNotifier` holding the
signed-in principal, the token pair, and the four-state matrix for the item in
view. `AdvancedTodoApp` (`lib/app/app_root.dart`) rebuilds its home from
`session.isLoggedIn`, so the login↔board switch is state-driven. Every screen
reaches the backend through `AppSession.guard`, so a dropped session (the live
stack's post-refresh `401`, keyed `auth.session_expired`) clears the principal
and routes straight back to login.

## Login screen

`lib/screens/login_screen.dart` is a bound `TomForm` (`lib/forms/login_form.dart`)
over the client-local reflected `LoginCredentials` (`lib/domain/`). On submit it
`save()`s the form (the reflection round-trip writes the typed fields back into
the credentials), folds them into a wire `LoginRequest`, and calls
`AppSession.login`. A rejected login surfaces its `AppBackendException` message
inline (keyed `login-error`) without leaving the page; success lets the shell
swap to the board. The app's reflected graph (domain entities + the
credentials/form) is captured by `lib/reflection_seed.dart` — regenerate with
`./reflection_generation.sh` only when a reflected signature changes.

## Board screen

`lib/screens/board_screen.dart` is the signed-in home. It cascades the reads in
`initState` — workspaces → projects → lists → items — each hop guarded through
`AppSession.guard`, and re-runs from the picker level when the
workspace/project `DropdownButtonFormField` changes. Items group into one column
per `TodoStatus` (keyed `status-column-<name>`, with a `(count)` header),
rendered in a horizontally scrollable board. Tapping a card pushes the
item-detail editor.

## Item-detail screen

`lib/screens/item_detail_screen.dart` is the bound editor (keyed
`item-detail-screen`). On open it loads the item's `resourceKey → TomAuthState`
matrix (`AppSession.loadFieldStates`) and builds a `TodoItemForm`
(`lib/forms/todo_item_form.dart`) with it, so the four ACL states render
distinctly per role: `owner` edits every field; `editor` sees the assignee and
estimate read-only; `commenter` loses priority/estimate entirely; `viewer`
toggles nothing — the status control renders disabled while the rest are
read-only. A field absent from the matrix degrades to `TomAuthState.none`
(hidden — the closed-safe default).

Save (keyed `item-save-button`) is offered only when at least one gradable field
is editable; it runs the form's reflection round-trip (`save()` writes the typed
fields back into the bound `TodoItem`) and persists via `AppSession.guard`.
Because non-`full` fields render non-editable, a write-back carries exactly the
permitted fields — the server re-checks the same grade. A minimal add-only
comment composer (keyed `comment-input` / `comment-submit-button`) posts through
the `AppBackend.addComment` seam; the comment thread and subtasks are deferred
until the backend seam exposes a comment-list read and subtask operations.

`TodoItemForm` is a reflected `TomClass`, so it is captured by
`lib/reflection_seed.dart` — regenerate with `./reflection_generation.sh` only
when a reflected signature changes.

## Share dialog

`lib/screens/share_dialog.dart` is the cross-user half of the four-state model:
it grants another user a `ProjectRole` on the board's selected project. The
board's app-bar **Share** action (keyed `share-button`, enabled once a project is
selected) opens it; on a granted share a snackbar confirms it and the grantee's
next read sees the project.

The grantee is entered as a **user id** (keyed `share-grantee-input`, e.g.
`u-carol`), not picked from a list — the frozen step-26 `AppBackend` seam has no
"list users" operation and `share` speaks `granteeUserId`, matching the live
wire. A role drop-down (keyed `share-role-picker`, default `viewer`) and a
**Share** button (keyed `share-submit-button`) submit a `ShareRequest` through
`AppSession.guard`. Only the project owner may share: a denied share surfaces its
`AppBackendException` message inline (keyed `share-error`) and keeps the dialog
open rather than closing it; an empty grantee is blocked client-side before any
backend call. The demo ids are `u-alice` / `u-bob` / `u-carol`.

## Running the full stack

The app drives the seeded `InMemoryAppBackend` out of the box (no servers
needed), which is how the widget and contract tests run. To exercise it live over
the wire, start both servers first, then launch the client with their URLs:

```sh
# 1. Auth server (issues bearer tokens) — from advanced_auth_server/
dart run bin/auth_server_start.dart      # binds http://localhost:8081

# 2. App server (the board API; needs its MariaDB) — from advanced_app_server/
docker compose up -d app-db              # MariaDB on host port 3308
dart run bin/app_server_start.dart       # binds http://localhost:8080

# 3. This client, pointed at both — from advanced_app_client/
flutter run \
  --dart-define=AUTH_SERVER_URL=http://localhost:8081 \
  --dart-define=APP_SERVER_URL=http://localhost:8080
```

Without the `--dart-define`s the client boots on the in-memory backend. Sign in
with a demo account (`alice` / `bob` / `carol`, password `pw`): `alice` owns the
seeded project and can share it; `bob` is a seeded editor; `carol` starts with no
access until `alice` shares the project. Each principal's board, item-detail
field grades, and share rights follow the same ownership + four-state model the
in-memory fake mirrors.

## Tests

Run the suite serially (the fakes build reflected entities):

```sh
flutter test --concurrency=1
```

- `test/in_memory_app_backend_test.dart` — the `InMemoryAppBackend` contract
  (TC-26-01..15): login, the workspace→project→list→item reads, item save, the
  per-principal four-state field matrix, and cross-user sharing.
- `test/app_bootstrap_test.dart` — the app shell (TC-27-01..04): boots to login
  when logged out, a successful login flips onto the board (carrying principal +
  tokens), a guarded `401` and a logout each route back to login.
- `test/login_screen_test.dart` — the bound login screen (TC-28-01..04): starts
  on sign-in, a valid login proceeds to the board, a rejected login shows an
  inline error without leaving the page, and empty credentials fail validation
  without a backend call.
- `test/board_screen_test.dart` — the status-column board (TC-29-01..03): items
  render grouped by `status` (asserted per column with `find.descendant`),
  tapping a card opens its detail, and the picker shows the seeded workspace +
  project.
- `test/item_detail_screen_test.dart` — the bound item-detail editor
  (TC-30-01..03): `owner` sees a full editor with every gradable field, `viewer`
  is read-only with disabled dropdowns and the ungranted estimate hidden (and no
  Save), and an `editor` save persists the edited title while the read-only
  assignee stays put.
- `test/share_dialog_test.dart` — the cross-user share dialog (TC-31-01..03): an
  owner shares the project and the grantee (`carol`, with no access before) then
  sees it, a non-owner's share is rejected inline with the owner-only error, and
  an empty grantee is blocked before any backend call.

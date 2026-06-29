# advanced_app_client

End-user Flutter app for the **advanced Tom Core full-stack sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Logs in against `advanced_auth_server`, presents the bearer token on every call
to `advanced_app_server`, and renders a status-column task board with per-field
four-state authorization driven live over the wire, plus cross-user sharing.

## Status

Login screen landed (step 28). On top of the bootstrap + session, the real
sign-in screen is a bound `TomForm` over client-local `LoginCredentials` that
drives `AppSession.login` and shows a rejected login inline. The app now boots on
its own generated `reflection_seed.dart` (capturing the shared domain entities +
the client-local credentials/form in one init). The board/detail screens and the
share dialog are filled in over steps 29–31.

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

## Planned contents (steps 29–31)

- Screens: Workspace/Project picker, Board, Item detail (bound
  `TomForm<TodoItem>` with per-field `TomAuthorizer.fixed(state)`), Share dialog.

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

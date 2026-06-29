# advanced_app_client

End-user Flutter app for the **advanced Tom Core full-stack sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Logs in against `advanced_auth_server`, presents the bearer token on every call
to `advanced_app_server`, and renders a status-column task board with per-field
four-state authorization driven live over the wire, plus cross-user sharing.

## Status

Bootstrap + session landed (step 27). On top of the `lib/backend/` seam, the app
shell now boots (`lib/main.dart`) and swaps between the login and board screens
on session state; the login/board/detail screens are filled in over steps 28–31.
`lib/reflection_seed.dart` is still a placeholder — the app currently boots on
`advanced_todo_domain`'s `initializeReflection()`; it switches to the app's own
generated seed once the bound `TomForm` subclasses arrive with the screens.

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

## Planned contents (steps 28–31)

- Screens: Login (bound `TomForm` over credentials), Workspace/Project picker,
  Board, Item detail (bound `TomForm<TodoItem>` with per-field
  `TomAuthorizer.fixed(state)`), Share dialog.

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

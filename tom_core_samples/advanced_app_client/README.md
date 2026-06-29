# advanced_app_client

End-user Flutter app for the **advanced Tom Core full-stack sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Logs in against `advanced_auth_server`, presents the bearer token on every call
to `advanced_app_server`, and renders a status-column task board with per-field
four-state authorization driven live over the wire, plus cross-user sharing.

## Status

Backend seam landed (step 26). The transport-independent `AppBackend` and its
two implementations are in `lib/backend/`; the session, bootstrap, and screens
follow in steps 27–31. `lib/reflection_seed.dart` is still a placeholder (the
`TomForm` subclasses it captures arrive with the screens).

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

## Planned contents (steps 27–31)

- Bootstrap + `AppSession` (user + tokens + current field matrix).
- Screens: Login, Workspace/Project picker, Board, Item detail (bound
  `TomForm<TodoItem>` with per-field `TomAuthorizer.fixed(state)`), Share dialog.

## Tests

`test/in_memory_app_backend_test.dart` — the `InMemoryAppBackend` contract
(TC-26-01..15): login, the workspace→project→list→item reads, item save, the
per-principal four-state field matrix, and cross-user sharing. The fake builds
reflected entities, so run the suite serially:

```sh
flutter test --concurrency=1
```

# advanced_app_client

End-user Flutter app for the **advanced Tom Core full-stack sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Logs in against `advanced_auth_server`, presents the bearer token on every call
to `advanced_app_server`, and renders a status-column task board with per-field
four-state authorization driven live over the wire, plus cross-user sharing.

## Status

Scaffold (step 1). Compiles and analyzes clean; `lib/reflection_seed.dart` is a
placeholder. The backend seam, session, and screens are implemented in
steps 26–31.

## Planned contents

- An `AppBackend` seam with a seeded in-memory fake (socket-free widget tests)
  and a live implementation delegating to `advanced_client_core`.
- Bootstrap + `AppSession` (user + tokens + current field matrix).
- Screens: Login, Workspace/Project picker, Board, Item detail (bound
  `TomForm<TodoItem>` with per-field `TomAuthorizer.fixed(state)`), Share dialog.

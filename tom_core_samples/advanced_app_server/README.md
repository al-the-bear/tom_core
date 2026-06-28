# advanced_app_server

App server for the **advanced Tom Core full-stack sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

A secured task-manager API on `tom_core_server`. It trusts the JWT signing key
shared with `advanced_auth_server`, validates the bearer token on every request,
resolves the principal's resource access (ownership + shares) and four-state
field grades, and persists the `app_db`.

## Status

Scaffold (step 1). Compiles and analyzes clean; `bin/app_server_start.dart` is a
placeholder. The persistence, resolvers, endpoints, migrations, and live boot
are implemented in steps 14–21.

## Planned contents

- Persistence records + repositories for `app_db`
  (workspaces/projects/lists/items/comments/subtasks/shares) and a pure
  domain↔record mapping layer.
- Resource-access resolver (ownership-or-share → effective `projectRole`) and a
  field-grade resolver (`projectRole` → per-field `TomAuthState`).
- `AppApiService` implementation: read + write endpoints with server-side
  field-grade enforcement, plus the share endpoints.
- `bin/app_server_start.dart` boot trusting the auth server's JWT key.

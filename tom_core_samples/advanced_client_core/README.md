# advanced_client_core

Flutter-free `dart:io` client core for the **advanced Tom Core full-stack
sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

The authenticated HTTP layer shared by `advanced_app_client` and
`advanced_authadmin_client`. Nothing here imports Flutter, so the JSON↔DTO
parsers are unit-testable headless (no sockets in tests).

## Status

Scaffold (step 1). Compiles and analyzes clean; the client classes are added in
steps 22–25.

## Planned contents

- `AuthClient` — `login` / `refresh` / `logout` against the auth server, token
  storage via `TomBearerAuthentication.setTokens`.
- `AuthorizedHttp` — wraps `HttpClient`, injects `Authorization: Bearer`,
  refreshes once on a 401, surfaces typed errors.
- `AppApiClient` — typed methods over the app server, pure JSON↔DTO parsers.
- `AdminApiClient` — typed methods over `/admin/*`.

# advanced_todo_contracts

Shared wire contracts for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

The single definition of the over-the-wire surface, depended on by both servers
(which implement it) and the shared client core (which calls it).

## Status

Scaffold (step 1). Compiles and analyzes clean; the interfaces and DTOs are
added in steps 4–5, and the authorization-model contract is documented in
step 6.

## Planned contents

- DTOs: `LoginRequest`, `LoginResult`, `GradedFieldDto`, `ShareRequest`,
  `GrantMatrixDto`, and the admin CRUD DTOs.
- `@tomService` endpoint interfaces: `AuthApiService`, `AdminApiService`,
  `AppApiService` — with `@TomEndpoint` + access annotations
  (`@TomPublicAccess`, `@TomAuthenticatedAccess`, `@TomRoleAccess(['admin'])`).
- A written description of the two-layer authorization model (resource-level
  shares + four-state field grants) the servers implement against.

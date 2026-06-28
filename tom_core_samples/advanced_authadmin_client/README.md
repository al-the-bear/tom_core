# advanced_authadmin_client

Administrator Flutter console for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Logs in with the `admin` role and manages users, roles, groups, role
assignments, and the `projectRole` × field grant matrix via the auth server's
`/admin/*` API (through `advanced_client_core`).

## Status

Scaffold (step 1). Compiles and analyzes clean; `lib/reflection_seed.dart` is a
placeholder. The admin backend seam and screens are implemented in steps 32–36.

## Planned contents

- An admin backend seam over `AdminApiClient` with an in-memory fake.
- Admin login + shell (requires the `admin` role).
- Users / Roles / Groups screens (CRUD + membership/assignment).
- Grant-matrix editor: a `projectRole` × fieldResourceKey grid whose cells cycle
  `none→disabled→read→full`, saved via `PUT /admin/grants`, reusing the
  `tom_flutter_ui` table/ACL widgets.
- Assignments screen.

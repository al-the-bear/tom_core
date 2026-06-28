# advanced_auth_server

Auth server for the **advanced Tom Core full-stack sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Two surfaces in one boot on `tom_core_server`: a JWT **authentication** issuer
(`/auth/login`, `/auth/refresh`, `/auth/me`, `/auth/logout`) and a role-gated
**administration** API (`/admin/users|roles|groups|grants|assignments`). The
admin endpoints that *mutate* roles and the grant matrix are a primary
deliverable — they do not exist elsewhere in the framework yet.

## Status

Scaffold (step 1). Compiles and analyzes clean; `bin/auth_server_start.dart` is
a placeholder. The records, password helper, authentication service, endpoints,
admin API, and live boot are implemented in steps 7–13.

## Planned contents

- `auth_db` records + repositories (users with password hash, roles, groups,
  membership, user-roles) and the framework `TomResourceGrant` for the grant
  table; migrations + Docker compose with a seeded admin + demo users + grants.
- A password hashing helper over the kernel crypto.
- `AuthenticationService` (verify credentials → `TomPrincipal` + ACI).
- `AuthApiService` (JWT issuance) and `AdminApiService` (role-gated CRUD +
  `GET/PUT /admin/grants`).

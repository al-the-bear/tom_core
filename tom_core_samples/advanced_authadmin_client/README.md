# advanced_authadmin_client

Administrator Flutter console for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Logs in with the `admin` role and manages users, roles, groups, role
assignments, and the `projectRole` × field grant matrix via the auth server's
`/admin/*` API (through `advanced_client_core`).

## Status

Admin backend seam landed (step 32). `lib/backend/` defines the
transport-independent `AdminBackend` and its two implementations — the seeded
`InMemoryAdminBackend` (the offline teaching default the widget tests bind) and
the `LiveAdminBackend` over `advanced_client_core`. The screens (login + shell,
Users/Roles/Groups, grant-matrix editor, assignments) are built in steps 33–36;
`lib/reflection_seed.dart` stays a placeholder until those forms bind reflected
DTOs.

## AdminBackend seam

`lib/backend/backend.dart` is the barrel. Bind every screen against the
transport-independent `AdminBackend` (`admin_backend.dart`), never a concrete
backend, so the same widgets drive either implementation. The seam mirrors the
auth server's `AdminApiService` (`advanced_todo_contracts`) one-to-one — the
Users/Roles/Groups CRUD, the `(role, fieldResourceKey) → TomAuthState` grant
matrix, and role/group assignments — plus the two session operations
(`login`/`logout`) the admin API client does not own.

- **`InMemoryAdminBackend`** — a seeded, socket-free fake the contract and widget
  tests bind. It seeds the same demo accounts as the app client (`admin` plus
  `alice`/`bob`/`val`), the five application roles, an `Engineering` group, and
  the same four-state grant matrix the auth server seeds. Every administrative
  call requires the `admin` role: a signed-in non-admin is refused with
  `admin.access.forbidden`, mirroring the server's `@TomRoleAccess(['admin'])`
  gate. Reflection-free — the admin DTOs are plain value records.
- **`LiveAdminBackend`** — the production wiring: a thin adapter over an
  `AuthClient` (login/token storage) and an `AdminApiClient` (the `/admin/*` API)
  sharing one `JsonTransport`, normalising the client core's transport exceptions
  into the single `AdminBackendException` the screens catch.

```dart
final AdminBackend backend = InMemoryAdminBackend(); // or LiveAdminBackend(auth, api)
await backend.login(LoginRequest(username: 'admin', password: 'pw'));
final users = await backend.listUsers();
final grants = await backend.getGrants(); // (role, resourceKey) → TomAuthState
```

## Planned contents (steps 33–36)

- Admin login + shell (requires the `admin` role; a non-admin is rejected at
  login by keying on the seam's `admin.access.forbidden`).
- Users / Roles / Groups screens (CRUD + membership/assignment).
- Grant-matrix editor: a `projectRole` × fieldResourceKey grid whose cells cycle
  `none→disabled→read→full`, saved via `PUT /admin/grants`, reusing the
  `tom_flutter_ui` table/ACL widgets.
- Assignments screen.

## Tests

Run the suite serially:

```sh
flutter test --concurrency=1
```

- `test/in_memory_admin_backend_test.dart` — the `InMemoryAdminBackend` contract
  (TC-32-01..18): the login + `admin`-role gate (admin proceeds, a non-admin is
  forbidden, a call before login fails), Users/Roles/Groups CRUD, the four-state
  grant-matrix round-trip, and role/group assignments.

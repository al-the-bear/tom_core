# advanced_authadmin_client

Administrator Flutter console for the **advanced Tom Core full-stack sample**
(see `../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

Logs in with the `admin` role and manages users, roles, groups, role
assignments, and the `projectRole` × field grant matrix via the auth server's
`/admin/*` API (through `advanced_client_core`).

## Status

Admin login + shell landed (step 33), over the step-32 backend seam.
`lib/app/` defines the `AdminSession` (`ChangeNotifier`) and the
`AdminConsoleApp` shell that swaps between the login screen and the console as a
pure function of `session.isLoggedIn`; `lib/screens/` holds the login screen and
the (placeholder) console shell; `lib/main.dart` bootstraps the console over the
in-memory fake by default or the live stack when both server URLs are supplied.
The Users/Roles/Groups, grant-matrix editor, and assignments screens are built
in steps 34–36; `lib/reflection_seed.dart` stays a placeholder until those forms
bind reflected DTOs (step 34).

## Admin login + shell

The console is a state-driven shell, mirroring the app client: the
`AdminConsoleApp` renders the login screen when signed out and the console shell
when signed in, rebuilding on every `AdminSession` change.

Login is **two-phase**, because the auth server gates each `/admin/*` endpoint
with `@TomRoleAccess(['admin'])` rather than gating login itself:

1. `AdminSession.login` authenticates (a bad password raises
   `auth.login.failed`).
2. It then **probes** an admin call (`listUsers`). A signed-in non-admin
   authenticates fine but is refused here with `admin.access.forbidden`; the
   login is undone and the refusal is surfaced inline on the login screen.

Only when both phases pass is the principal stored and the shell allowed to
open. The login screen is a plain Material form (not a reflected `TomForm`) — the
admin console's reflected forms are the user/role/group editors in step 34 — so
the step-33 widget tests stay socket- and reflection-free.

```dart
final session = AdminSession(InMemoryAdminBackend()); // or LiveAdminBackend(...)
runApp(AdminConsoleApp(session: session));
// admin/pw → console shell; alice/pw → "Administrator access is required."
```

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

## Planned contents (steps 34–36)

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
- `test/admin_login_screen_test.dart` — the admin login + shell (TC-33-01..06):
  the console starts on sign-in, an admin login opens the console shell, a
  signed-in non-admin is rejected with an access error, bad credentials and
  empty fields stay on the page, and sign-out routes back to login.

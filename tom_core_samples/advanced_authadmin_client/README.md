# advanced_authadmin_client

Administrator Flutter console for the **advanced Tom Core full-stack sample**
(see [`../README_advanced_sample.md`](../README_advanced_sample.md)).

Logs in with the `admin` role and manages users, roles, groups, role
assignments, and the `projectRole` × field grant matrix via the auth server's
`/admin/*` API (through `advanced_client_core`).

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[09 · Forms & UI](../README_advanced_09_forms_ui.md)** and
> [11 · The two Flutter clients](../README_advanced_11_clients_app_admin.md).

## Status

Phase 6 is complete: the assignments editor (step 36) closes the console over
the step-35 grant matrix, the step-34 Users / Roles / Groups CRUD, the step-33
login + shell, and the step-32 backend seam. `lib/app/` defines the
`AdminSession` (`ChangeNotifier`) and the `AdminConsoleApp` shell that swaps
between the login screen and the console as a pure function of
`session.isLoggedIn`; `lib/screens/` holds the login screen plus the console
shell — a `NavigationRail` over an `IndexedStack` of the Users, Roles, Groups,
Grants, and Assignments destinations — the generic `AdminCrudScreen<T>` the
first three share, the `GrantsScreen` matrix editor, and the `AssignmentsScreen`
role/group assigner. `lib/forms/` binds reflected drafts
(`UserForm`/`RoleForm`/`GroupForm`); `lib/main.dart` calls
`initializeReflection()` (from `lib/reflection_seed.dart`) before bootstrapping
the console over the live stack by default (no dart-defines — URLs from the
`AdvancedClientConfig` config bean), or over the seeded in-memory fake under
`--dart-define=TEST_MODE=true`.

## Admin login + shell

The console is a state-driven shell, mirroring the app client: the
`AdminConsoleApp` renders the login screen when signed out and the console shell
when signed in, rebuilding on every `AdminSession` change.

Login is **two-phase**, because each `/admin/*` endpoint's contract declares
`TomRoleAccess(['admin'])` (`TomApiEndpoint.access`) rather than gating login itself:

1. `AdminSession.login` authenticates (a bad password raises
   `auth.login.failed`).
2. It then **probes** an admin call (`listUsers`). A signed-in non-admin
   authenticates fine but is refused here with `admin.access.forbidden`; the
   login is undone and the refusal is surfaced inline on the login screen.

Only when both phases pass is the principal stored and the shell allowed to
open. The login screen binds a reflected `AdminLoginForm` (`lib/forms/admin_login_form.dart`,
todo 12) over the client-local `AdminLoginCredentials` — built unscoped with
`formId: 'adminLogin'`, so its fields self-address as `adminLogin.username` /
`adminLogin.password`, the keys the auth server serves on the public
`/resources/login` bundle the console installs before sign-in. It renders the
fields' own `field.widget`s and resolves labels/hints from that installed bundle,
mirroring the app client's `LoginForm`.

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
  `alice`/`bob`/`carol`), the five application roles, an `Engineering` group, and
  the same four-state grant matrix the auth server seeds. Every administrative
  call requires the `admin` role: a signed-in non-admin is refused with
  `admin.access.forbidden`, mirroring the server's contract-declared
  `TomRoleAccess(['admin'])` (`TomApiEndpoint.access`) gate. Reflection-free — the
  admin DTOs are plain value records.
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

## Users / Roles / Groups

Each rail destination is a thin `StatelessWidget` configuring the generic
`AdminCrudScreen<T>` (`lib/screens/admin_crud_screen.dart`) — list, create,
edit, delete — so the three flows share one list/dialog/confirm skeleton rather
than triplicating it. Create and edit open a reflected editor
(`showAdminEditor`) bound to a client-local **draft** (`UserDraft`/`RoleDraft`/
`GroupDraft`, extending `TomClass`); on save the draft folds by hand into the
plain wire DTO the backend takes, mirroring the app client's
`LoginCredentials → LoginRequest` seam. The console stays domain-agnostic — it
reads the raw `status` wire token (`'active'`/`'suspended'`), never the
`UserStatus` enum.

Stable keys are read-only on edit: a user's `username` and a role's `key` are
the identifiers other tables key on, so the form renders them but disables the
field (the `password` field exists only on create — and its required validator
is conditional, because a reflected `TomForm` validates *every* declared field,
rendered or not). Group membership is a checklist over every account
(`group-member-${userId}`), pre-checked from the group's current members and
folded back into `GroupDto.memberUserIds` on save.

## Grant matrix

The Grants destination (`lib/screens/grants_screen.dart`) is the four-state
authorization editor: a `DataTable` of `projectRole` (rows) × field resource key
(columns), each cell the resolved `TomAuthState` for that pair. Tapping a cell
cycles it `none → disabled → read → full` (and wraps), building up an edited
`GrantMatrixDto` locally via `withAccess`; **Save** writes the whole matrix back
through `putGrants` (`PUT /admin/grants`) and then re-reads it, so the grid after
a save shows exactly what the backend persisted. Save is offered only while the
working copy differs from the loaded one.

Like the rest of the console it stays domain-agnostic — it renders whatever role
keys and resource keys the matrix reports (column headers show the trailing
segment, e.g. `todo.item.title → title`, while each cell is keyed by the full
resource key) and never the application's `todo.item.*` gradable keys /
`UserStatus` enums. Every read and the save route through `AdminSession.guard`.

## Assignments

The Assignments destination (`lib/screens/assignments_screen.dart`) grants an
account a role and/or a group membership via `assign` (`POST /admin/assignments`).
It lists every account; tapping a row's **Assign** button opens an editor with a
role picker and a group picker (each optional), and saving posts a single
`AssignmentRequest(userId, roleKey, groupId)`. Choosing neither is refused
inline.

The two sides read back asymmetrically, and the screen is honest about it: a
user's **group** memberships are shown in its row subtitle — the seam reads
those back through `listGroups` — so a group assignment is visible after the
post-save reload, whereas **roles** have no seam read-back (a `UserDto` carries
no roles), so a role assignment is fire-and-forget from the UI's view and is
asserted in tests through the seeded backend's `rolesOf` introspection. Every
read and the assign route through `AdminSession.guard`.

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
  the console starts on sign-in, an admin login opens the console shell (onto the
  Users destination), a signed-in non-admin is rejected with an access error, bad
  credentials and empty fields stay on the page, and sign-out routes back to
  login.
- `test/users_screen_test.dart` — the Users destination (TC-34-U01..05): lists
  the seeded accounts, creates one, blocks an empty username, edits a profile
  (username stays the read-only key), and deletes a row.
- `test/roles_screen_test.dart` — the Roles destination (TC-34-R01..05): lists
  the seeded roles, creates one, refuses a duplicate key inline, renames a role
  (its key is read-only), and deletes a row.
- `test/groups_screen_test.dart` — the Groups destination (TC-34-G01..05): lists
  the seeded group with its member count, creates a group with a member, the
  editor pre-checks current members, removing a member updates the saved
  membership, and deletes a row.
- `test/grants_screen_test.dart` — the Grants destination (TC-35-01..05): renders
  the seeded matrix, a cell cycles `none→disabled→read→full` on tap, Save is
  disabled until a cell changes, saving issues the edited `GrantMatrixDto` to the
  backend, and a reload reflects the persisted matrix.
- `test/assignments_screen_test.dart` — the Assignments destination
  (TC-36-01..05): lists the seeded users (with their group memberships in the
  subtitle), assigning a role persists into `rolesOf`, assigning a group persists
  into `listGroups` and updates the row subtitle on reload, an empty selection is
  refused inline, and a role and a group can be assigned together.

The Users/Roles/Groups suites bind reflected forms, so they share
`test/support/admin_console_harness.dart` (sign in, open a destination, save an
editor, confirm a delete) and run `initializeReflection()` once in `setUpAll`.
The Grants and Assignments suites are socket- and reflection-free (no `TomForm`),
reusing only the harness's sign-in and destination helpers.

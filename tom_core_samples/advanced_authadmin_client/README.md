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

**There is no `example/` directory and no `doc/` folder, and both absences are
deliberate: this package is itself the runnable example, and a sample has no
consumers who need its surface mirrored — see [the suite map](../README.md) for
that decision, which is the same for all sixteen sample packages.** This README
is the package's one description of its surface. It is one of the nine `advanced_*` packages that
together form the full-stack sample, and an `example/` here would either
duplicate `lib/main.dart` or isolate a fragment the console already shows in
context. What to run instead:

- **`lib/main.dart`** — the commented bootstrap: reflection, the client platform,
  the login resource bundle, then the console over the backend the launch flag
  selects.
- **`flutter run --dart-define=TEST_MODE=true`**, once a platform folder exists
  ([Before the first run](#before-the-first-run)) — the whole console offline over
  the seeded `InMemoryAdminBackend`, with no server or database behind it. With
  no dart-defines it drives the live auth server instead (see
  [Layout](#layout)).
- **The thirteen widget suites** under [Tests](#tests) — they sign in and drive
  every destination through that same offline backend, so they are the fastest
  way to watch a screen work.

[The family's index](../README_advanced_sample.md#the-nine-packages) says which of the nine carry an `example/`, and why.

## Before the first run

The package ships no platform folders: they are generated scaffolding, and the
sample carries only its own source. Flutter will not run a project on a
platform it has no folder for, so generate the one you run on, once, from this
directory:

```sh
flutter create --empty --platforms=macos .   # or linux, or windows
```

`--empty` matters. Without it `flutter create` also writes a counter-app
`test/widget_test.dart` that pumps a `MyApp` this package does not have, and the
suite stops compiling. The command leaves `lib/`, `pubspec.yaml` and this README
alone, and what it adds — the platform folder, `.metadata`, IDE files — is
gitignored. The client core it shares with the end-user app talks HTTP through
`package:http`, so nothing in it rules the web out; the end-user app is the one
built and checked in a browser (`README_advanced_sample.md`, "A real passkey
from a browser"), and this console has not been.

On macOS the app is sandboxed, and the generated
`macos/Runner/DebugProfile.entitlements` allows incoming connections only. The
offline mode needs nothing more; to reach the live servers, add
`<key>com.apple.security.network.client</key><true/>` to that file first.

## Layout

| Folder | Holds |
| ------ | ----- |
| `lib/app/` | `AdminSession` (a `ChangeNotifier`) and `AdminConsoleApp`, the shell that swaps between the login screen and the console as a pure function of `session.isLoggedIn` |
| `lib/screens/` | the login screen, the console shell (a `NavigationRail` over an `IndexedStack` of the Users, Roles, Groups, Grants and Assignments destinations), the generic `AdminCrudScreen<T>` the first three share, the shared `AdminEditorDialog`, the `GrantsScreen` matrix editor and the `AssignmentsScreen` role/group assigner |
| `lib/forms/` | the five reflected forms — `AdminLoginForm`, `AdminSecondFactorForm`, `UserForm`, `RoleForm`, `GroupForm` |
| `lib/domain/` | the client-local reflected entities those forms bind — `AdminLoginCredentials`, `AdminSecondFactorCode`, and the `UserDraft`/`RoleDraft`/`GroupDraft` trio |
| `lib/actions/` | `admin_actions.dart` — the eleven `TomSimpleAction`s every write runs through |
| `lib/backend/` | the `AdminBackend` seam and its two implementations |
| `lib/files/` | `registerSampleAvatarPicker()`, the application's one `TomFilePickerRegistry` adaptor |

`lib/main.dart` calls `initializeReflection()` (from `lib/reflection_seed.dart`)
before bootstrapping the console over the live stack by default (no
dart-defines — URLs from the `AdvancedClientConfig` config bean), or over the
seeded in-memory fake under `--dart-define=TEST_MODE=true`.

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
open. The login screen binds a reflected `AdminLoginForm`
(`lib/forms/admin_login_form.dart`) over the client-local
`AdminLoginCredentials` — built unscoped with
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

### The second factor

When the administrator's account owes a second factor, `login` returns
`requires2FA` and an *interim* token that authorizes nothing — so the session
stores only a flag, `isLoggedIn` stays false, and the login screen switches to a
code phase over `AdminSecondFactorForm`/`AdminSecondFactorCode` (`formId:
'adminTwoFactor'`, sized from the challenge's own `clientData['digits']`).

This is why the `admin` probe lives in the *shared completion tail*
(`_completeLogin`) rather than in `login`: it cannot run against an interim token
that authorizes nothing, so an enrolled non-admin is refused one pass later
rather than never. `submitSecondFactor` runs that same tail, so a two-factor
sign-in and a plain one leave exactly the same state behind. A refusal keyed
non-retryable (`AdminBackendException.canRetrySecondFactor` false) abandons the
pending login and drops the screen back to username/password.

The seeded `auth_db` enrols **no** administrator, so `InMemoryAdminBackend`
enrols none either — an offline console that demanded a code the real one does
not would teach the wrong thing. But an enrolment is an *account* property the
console does not control: the day someone enrols `admin`, a console that ignored
`requires2FA` would be unusable. So the fake takes the enrolment as a constructor
argument, `InMemoryAdminBackend(twoFactorUsernames: {'admin'})`, and
`test/admin_login_two_factor_test.dart` uses it to prove the console still works.
The fake does not fake the crypto: it verifies with the kernel's own `TomTotp`
against the same secret the auth server's `[005]` migration seeds.

## AdminBackend seam

`lib/backend/backend.dart` is the barrel. Bind every screen against the
transport-independent `AdminBackend` (`admin_backend.dart`), never a concrete
backend, so the same widgets drive either implementation. The seam carries all
sixteen operations of the auth server's `AdminApiService`
(`advanced_todo_contracts`) — the Users/Roles/Groups CRUD, the
`(role, fieldResourceKey) → TomAuthState` grant matrix, role/group assignments
and the admin resource bundle — and adds six members that API does not own:

| Added member | Why the seam needs it |
| ------------ | --------------------- |
| `login`, `submitSecondFactor`, `pendingChallenge`, `logout` | The session, including a two-pass login through a challenge. |
| `loginResources` | The pre-sign-in text bundle, fetched before any token exists. |
| `files` | The `TomFileTransferClient` for avatar bytes — a second seam beside the JSON one. |

All but `pendingChallenge` and `files` are `AuthApiService` members that
`LiveAdminBackend` routes through `AuthClient`, so what the seam genuinely
invents is one piece of challenge state and one byte transport. It also takes a
leading id where the contract folds one into the payload, so no screen builds an
`EntityIdRequest` to delete a row.

- **`InMemoryAdminBackend`** — a seeded, socket-free fake the contract and
  widget tests bind. It seeds four accounts — <!-- account-roster: admin-offline -->a dedicated `admin` plus the app
  client's three project principals, `alice`/`bob`/`carol`<!-- /account-roster --> — the five
  application roles, an `Engineering` group, and the same four-state grant
  matrix the auth server seeds. Not the app client's whole roster: that fake
  also seeds `dave` and `erin`, who carry the second-factor story, and the
  console has no screen that needs them. Every administrative call requires the
  `admin` role: a signed-in non-admin is refused with `admin.access.forbidden`,
  mirroring the server's contract-declared `TomRoleAccess(['admin'])`
  (`TomApiEndpoint.access`) gate. It holds DTO instances directly and never
  serializes one, so it is the one path through the console that needs no
  reflection.
- **`LiveAdminBackend`** — the production wiring: a thin adapter over an
  `AuthClient` (login/token storage) and an `AdminApiClient` (the `/admin/*` API)
  sharing one `JsonTransport`, normalising the client core's transport exceptions
  into the single `AdminBackendException` the screens catch. Its `files` client
  is pointed at the **auth** server, because that is where the avatar slot lives.

```dart
final AdminBackend backend = InMemoryAdminBackend(); // or LiveAdminBackend.fromConfig()
await backend.login(LoginRequest(username: 'admin', password: 'pw'));
final users = await backend.listUsers();
final grants = await backend.getGrants(); // (role, resourceKey) → TomAuthState
```

## Actions

Every write the console performs — the nine entity create/update/delete
operations, the assignment, and the grant-matrix save — runs through a
`TomSimpleAction` in `lib/actions/admin_actions.dart` rather than an inline
screen callback. Two things follow. Each action carries a canonical path
(`admin.<entity>.<verb>`) whose `TomAction.authorizer` the screens hand to the
button that triggers it, so an installed authorization adapter could disable
`admin.users.delete` fleet-wide without touching a screen; and `runAdminAction`
is the single bridge between the synchronous action lifecycle and the
`Future`-based seam. Its `Future<String?>` return (`null` saved, a message to
show inline) is exactly the editor dialog's `submit` contract, so a screen hands
one straight to the other.

```dart
return runAdminAction(
  adminActions.createUser,
  CreateUserContext(session, request),
);
```

## Users / Roles / Groups

Each rail destination is a thin `StatelessWidget` configuring the generic
`AdminCrudScreen<T>` (`lib/screens/admin_crud_screen.dart`) — list, create,
edit, delete — so the three flows share one list/dialog/confirm skeleton rather
than triplicating it. Create and edit open a reflected editor
(`showAdminEditor`) bound to a client-local **draft** (`UserDraft`/`RoleDraft`/
`GroupDraft`, extending `TomClass`); on save the draft folds by hand into the
wire DTO the backend takes, mirroring the app client's
`LoginCredentials → LoginRequest` seam. A draft exists because a bound `TomForm`
needs observable members, which the reflection-first wire DTOs deliberately do
not have. The console stays domain-agnostic — it
reads the raw `status` wire token (`'active'`/`'suspended'`), never the
`UserStatus` enum.

The user editor also carries the account's stored **language** and **country**
— the locale the servers write to that user in, as opposed to the one their
device sends. Both are edit-only (`CreateUserRequest` carries none, so an
account starts with no preference) and plain text inputs validated only for the
shape of a code: which languages have text is each server's business, and the
reader degrades a language it has none for to its default. Emptying the
language clears the pair.

Stable keys are read-only on edit: a user's `username` and a role's `key` are
the identifiers other tables key on, so the form renders them but disables the
field (the `password` field exists only on create — and its required validator
is conditional, because a reflected `TomForm` validates *every* declared field,
rendered or not). Group membership is a checklist over every account
(`group-member-${userId}`), pre-checked from the group's current members and
folded back into `GroupDto.memberUserIds` on save.

### The avatar

The user editor carries one control that is *not* a form field: the account's
avatar, a `TomFormFileUpload` over `AppFileSlots.userAvatar(id)` — the auth
server's `auth_users.avatar_ref` column. It is the same authenticated file
client the app client attaches item files with, pointed at the other server,
which is the whole reason the console has a file field at all: one client, one
bearer, two servers.

Three consequences follow from a slot not being a bound member. It is
**edit-only** — a slot is addressed by the row's id, and on create there is no
row. It **transfers on pick**, not on Save, and the field's description says so.
And its stored state is read with a single `HEAD`
(`TomFileTransferClient.describe`) when the editor opens rather than from
`UserDto`, which carries no avatar column — the descriptor *is* what a `HEAD`
returns, so asking the slot is asking the authoritative source. Because that
read happens before the dialog exists, a failure surfaces on the list rather
than inside an editor that never opened.

The platform picker is registered once at bootstrap through
`registerSampleAvatarPicker()` (`lib/files/sample_avatar_picker.dart`).
`TomFormFileField` takes no dependency on a picker package, so an application
registers exactly one adaptor with `TomFilePickerRegistry` and every file field
in it opens that one. This console's adaptor composes a real 1×1 PNG rather than
opening a gallery, because the sample's Flutter clients ship no platform folders;
everything downstream of the picker — the `TomFileRef` conversion, the streaming
upload, progress, cancel, retry — is the real code path.

## Grant matrix

The Grants destination (`lib/screens/grants_screen.dart`) is the four-state
authorization editor: a `TomDataTable` of `projectRole` (rows) × field resource
key (columns), each cell the resolved `TomAuthState` for that pair. Tapping a
cell cycles it `none → disabled → read → full` (and wraps), building up an
edited `GrantMatrixDto` locally via `withAccess`; **Save** writes the whole
matrix back through `putGrants` (`PUT /admin/grants`) and then re-reads it, so
the grid after a save shows exactly what the backend persisted. Save is offered
only while the working copy differs from the loaded one.

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

```sh
flutter test
```

No concurrency flag is needed: `flutter test` gives each suite file its own
`flutter_tester` process, so nothing is shared across files.

- `test/admin_login_form_test.dart` — the reflected `AdminLoginForm` in
  isolation: it runs unscoped so `formId` *is* its base path, each field
  self-addresses as its served bundle key, both fields are required, and
  `bind`/`save` round-trips into the bound `AdminLoginCredentials`.
- `test/login_resources_bootstrap_test.dart` (TC-8-02) — the sign-in screen
  renders the raw resource *keys* with no bundle installed, proving no chrome
  string is baked into the widget, and the server texts only after
  `loadLoginResources`.
- `test/full_resources_bootstrap_test.dart` (TC-9-02) — an admin sign-in installs
  the admin-gated console bundle merged over the login bundle, and logout
  restores exactly what was there before.
- `test/form_label_resolution_test.dart` (TC-10-U/UE/R/G) — the three CRUD
  forms resolve their field labels from the installed bundle rather than from
  overrides, including the user editor's edit-only language and country,
  asserted against a sentinel bundle so a resolved label cannot be confused
  with a hardcoded one.
- `test/user_avatar_test.dart` (TC-D12-09..15) — the avatar field: rendered from
  the bundle, edit-only, uploading without waiting for Save, a stored avatar
  found by the `HEAD` on open, progress and cancel on a transfer in flight, and
  the file chrome coming from the server bundle.
- `test/in_memory_admin_backend_test.dart` — the `InMemoryAdminBackend` contract
  (TC-32-01..18): the login + `admin`-role gate (admin proceeds, a non-admin is
  forbidden, a call before login fails), Users/Roles/Groups CRUD, the four-state
  grant-matrix round-trip, and role/group assignments.
- `test/admin_login_screen_test.dart` — the admin login + shell (TC-33-01..06):
  the console starts on sign-in, an admin login opens the console shell (onto the
  Users destination), a signed-in non-admin is rejected with an access error, bad
  credentials and empty fields stay on the page, and sign-out routes back to
  login.
- `test/admin_login_two_factor_test.dart` — the second pass (TC-33-07..11), over
  a fake with `twoFactorUsernames` injected: an enrolled admin stops at the code
  phase, a valid code opens the shell, a wrong code is retryable with the
  attempts remaining, the third returns to the password screen, and an enrolled
  non-admin is still refused — one pass later, by the probe that now runs after
  the second factor.
- `test/users_screen_test.dart` — the Users destination (TC-34-U01..07): lists
  the seeded accounts, creates one, blocks an empty username, edits a profile
  (username stays the read-only key), deletes a row, sets and clears an
  account's stored language, and refuses a language that is not a code.
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

Six suites drive the console through `test/support/admin_console_harness.dart`
(sign in, open a destination, save an editor, confirm a delete): Users, Roles,
Groups, `user_avatar_test.dart`, Grants and Assignments. The Grants and
Assignments screens carry no `TomForm` of their own, but every suite still calls
`initializeReflection()` once in `setUpAll` — reaching a destination means
signing in first, and the login screen renders the reflected `AdminLoginForm`.
All thirteen suites are socket-free: they run against `InMemoryAdminBackend`.

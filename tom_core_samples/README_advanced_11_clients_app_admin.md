# The two Flutter clients

*Part 11 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

[Part 09](README_advanced_09_forms_ui.md) covered the bound forms and
[Part 10](README_advanced_10_servers_endpoints.md) the servers behind them. This
part is the front of the house: the two Flutter apps that consume the wire. They
are deliberately built the same way — a `ChangeNotifier` session, a state-driven
shell, and a single injected backend seam that is either a socket-free in-memory
fake or a live HTTP client. Seeing them side by side is the point: almost
everything is shared, and the handful of genuine differences (the admin console's
**two-phase** login, its grant-matrix editor) are exactly the new things this
sample exists to teach.

| | `advanced_app_client` (end-user) | `advanced_authadmin_client` (admin) |
| --- | --- | --- |
| Talks to | `advanced_app_server` (board) + `advanced_auth_server` (login) | `advanced_auth_server` (`/auth/*` + `/admin/*`) |
| Session | `AppSession` | `AdminSession` |
| Shell root | `AdvancedTodoApp` | `AdminConsoleApp` |
| Login | single-phase (authenticate) | **two-phase** (authenticate + `admin` probe) |
| Home | status-column board | `NavigationRail` console shell |
| Backend seam | `AppBackend` | `AdminBackend` |
| In-memory fake | `InMemoryAppBackend` | `InMemoryAdminBackend` |
| Live wiring | `LiveAppBackend` | `LiveAdminBackend` |

## The app client (end-user)

`AdvancedTodoApp` is a `MaterialApp` whose `home` is a `ListenableBuilder` over
the session: signed out renders `LoginScreen`, signed in renders `BoardScreen`
(`app_root.dart:28`). The login↔board swap is therefore a pure function of
`session.isLoggedIn` — no imperative `Navigator.push` to enter the app, and a
dropped session routes back to login by the same mechanism.

The signed-in surface is three screens (detailed in
[Part 09](README_advanced_09_forms_ui.md)): the **board** groups items into one
column per `TodoStatus`; the **item-detail editor** builds a `TodoItemForm`
against the item's `resourceKey → TomAuthState` matrix so each field renders at
its grade (owner edits all, viewer is read-only, an ungranted field is hidden);
and the **share dialog** grants another user a `ProjectRole` on the selected
project — owner-only, a non-owner's share refused inline. The item editor's grades
come from the session's authorization adapter (below), so the four-state model is
live over the wire, not faked in the widget.

## The admin console

`AdminConsoleApp` mirrors the app shell exactly — a `MaterialApp` whose `home` is
a `ListenableBuilder` swapping `AdminLoginScreen` for `AdminShellScreen` on
`session.isLoggedIn` (`admin_root.dart:31`). The signed-in shell is a
`NavigationRail` over an `IndexedStack` of five destinations:

- **Users / Roles / Groups** — three thin `StatelessWidget`s each configuring the
  generic `AdminCrudScreen<T>` (list / create / edit / delete), so the three CRUD
  flows share one list/dialog/confirm skeleton rather than triplicating it. Create
  and edit open a reflected editor bound to a client-local **draft**
  (`UserDraft`/`RoleDraft`/`GroupDraft`) that folds into the plain wire DTO on
  save. Stable keys (a user's `username`, a role's `key`) render read-only on
  edit.
- **Grants** — the four-state grant-matrix editor (below).
- **Assignments** — grants an account a role and/or a group membership via a
  single `AssignmentRequest`.

The console is domain-agnostic: it renders whatever role and resource keys the
backend reports and never references the application's `todo.item.*` gradable
keys or `UserStatus` enums — the same "the UI ships no policy" discipline the
rest of the guide rests on.

## Sessions

Both sessions are `ChangeNotifier`s that own the single injected backend and hold
the principal + token pair; the shell rebuilds on every `notifyListeners`. They
are near-identical (`app_session.dart:25`, `admin_session.dart:26`), with two
differences worth calling out.

**Two-phase admin login.** Because each `/admin/*` endpoint's contract declares
`TomRoleAccess(['admin'])` (`TomApiEndpoint.access`) rather than gating login itself
([Part 10](README_advanced_10_servers_endpoints.md)), a signed-in non-admin
authenticates fine but is refused the moment they touch admin data. `AdminSession.login`
therefore authenticates and then **probes** an admin call (`listUsers`); only if
the probe succeeds is the principal stored and the shell allowed to open. A
non-admin is undone (`_safeLogout`) and the refusal — `AdminBackendException`
keyed `admin.access.forbidden` — is surfaced on the login screen
(`admin_session.dart:106`). `AppSession.login` has no such probe; any valid
principal may use the board (`app_session.dart:121`).

**The `guard` seam.** Every screen reaches the backend through `session.guard`,
so "the session died" is handled in exactly one place: a backend failure keyed
`auth.session_expired` (the live stack's post-refresh `401`) or
`app.no_session`/`admin.no_session` clears the principal before rethrowing, so the
next frame is the login screen (`app_session.dart:172`, `admin_session.dart:142`).

The app session additionally owns a `FieldStateAuthorizationAdapter`: on every
`loadFieldStates` it repoints the adapter's matrix, and because the bootstrap
installed that same instance on the `TomAuthorization` singleton
(`main.dart`), the live item form sees the new grades with no reinstall
(`app_session.dart:46`, `:149`). This is the bridge between "the server said
this field is `read`" and "the widget renders it read-only."

## The in-memory vs live backend seam

Each client defines a transport-independent backend interface — `AppBackend`
(`app_backend.dart:51`), `AdminBackend` — that every screen is written against,
never a concrete class. That single seam is what lets the widget tests run
**socket-free**:

- **`InMemoryAppBackend` / `InMemoryAdminBackend`** — seeded fakes that mirror the
  server's ownership + four-state model in process. They are the offline teaching
  default *and* the contract any live backend must honour, so the widget tests
  bind them and never touch a socket (deterministic by construction).
- **`LiveAppBackend` / `LiveAdminBackend`** — thin adapters over
  `advanced_client_core`: an `AuthClient` (login + token storage) and an API
  client (`AppApiClient` / `AdminApiClient`) **sharing one `IoJsonTransport`** via
  `AuthorizedHttp`, so the bearer the login stores is the one every subsequent
  call presents (`main.dart` `_buildBackend`). They normalise the client core's
  transport exceptions (`AuthClientException` / `AppApiException` /
  `TomAuthExpiredException`) into the single typed `AppBackendException` /
  `AdminBackendException` the screens catch, carrying the server's stable error
  `key` so a caller can branch without parsing the message.

Because both implementations honour the same interface and the same error keys,
the screens — and the tests — behave identically against either.

## Bootstrap

Both `main.dart` entrypoints run the same ordered bootstrap before the first
frame (`advanced_app_client/lib/main.dart`,
`advanced_authadmin_client/lib/main.dart`):

1. **`initializeReflection()`** (from the app's generated `reflection_seed.dart`)
   registers the reflected entities the backend constructs and the forms bind —
   the shared `advanced_todo_domain` entities plus the client-local
   credentials/drafts/forms, all captured by one seed. It is **first** because the
   in-memory backend seeds its reflected tree in its constructor.
2. **`setCurrentPlatform(clientPlatformUtils)`** registers the Flutter client
   platform so kernel runtime probes get the Flutter implementation.
3. *(app client only)* **`TomAuthorization.adapter = session.authorizationAdapter`**
   installs the field-state adapter once, so every gradable field resolves its
   authorization implicitly through the matrix the session feeds it.
4. **`await session.loadLoginResources()`** fetches the public login bundle
   through the backend seam and installs it as the singleton
   `TomTextResourceProvider`, so the sign-in screen renders server-delivered
   chrome rather than a hardcoded string ([Part 08](README_advanced_08_resources_texts.md)).
5. **`runApp(...)`** over the session wrapping the chosen backend.

**Backend selection** is one place: `_buildBackend()` builds the **live stack**
over a shared transport by default — this is the normal run mode, so an app
started with **no dart-defines** targets the local servers, reading their URLs
from the `AdvancedClientConfig` config bean (never `String.fromEnvironment` reads
in `main()`). The seeded in-memory fake is a testing convenience, selected only
by an explicit `--dart-define=TEST_MODE=true`; it is what the widget tests inject
directly and how the offline walk-through runs. In-memory is never a default
reached by forgetting a flag.

**Login-then-full resource staging.** The login bundle installed at startup is the
*pre-login* chrome. On a successful `login`, the session pulls the
**authenticated** full bundle and installs it merged over the current provider
(full-bundle keys win), so every post-login screen resolves server texts while the
login chrome stays valid; logout restores the captured pre-login provider exactly,
so a re-login starts clean (`app_session.dart:108`/`:192`,
`admin_session.dart:89`/`:170`). The admin console's full bundle is the
**admin-gated** console bundle, reachable only *after* the role probe passes —
the two-phase login and the staged resources reinforce each other.

## The share flow and the grant-matrix editor

These are the two cross-user, mutate-authorization flows the sample adds over the
read-only predecessor — one per client.

**Share (app client).** The board's app-bar **Share** action opens a dialog that
grants another user (entered as a user id, e.g. `u-val`, since the frozen seam has
no "list users") a `ProjectRole` on the selected project. It submits a
`ShareRequest` through `session.guard`; the server enforces owner-only, so a
non-owner's share surfaces its error inline and keeps the dialog open. A granted
share takes effect on the grantee's next read because the server's resolver reads
shares immediately ([Part 10](README_advanced_10_servers_endpoints.md)).

**Grant matrix (admin console).** The Grants destination is a `DataTable` of
`projectRole` (rows) × field resource key (columns), each cell the resolved
`TomAuthState` for that pair. Tapping a cell cycles it `none → disabled → read →
full` (wrapping), building an edited `GrantMatrixDto` locally; **Save** writes the
whole matrix back through `putGrants` (`PUT /admin/grants`) and re-reads it, so the
grid after a save shows exactly what the backend persisted. Save is offered only
while the working copy differs from the loaded one. This is the administrator's
half of the four-state model: the app client *renders* grades, the admin console
*edits* them, and the server is the single source of truth between them.

## Primary sources

- [`advanced_app_client/README.md`](advanced_app_client/README.md), [`advanced_authadmin_client/README.md`](advanced_authadmin_client/README.md)
- `advanced_app_client/lib/{main.dart, app/app_session.dart, app/app_root.dart, backend/}`
- `advanced_authadmin_client/lib/{main.dart, app/admin_session.dart, app/admin_root.dart, screens/, backend/}`

---

← Prev: [10 · Servers & the secured endpoint pipeline](README_advanced_10_servers_endpoints.md) · Next: [12 · Testing & cross-tier integration](README_advanced_12_testing_integration.md) →

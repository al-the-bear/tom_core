# advanced_app_client

End-user Flutter app for the **advanced Tom Core full-stack sample** (see
[`../README_advanced_sample.md`](../README_advanced_sample.md)).

Logs in against `advanced_auth_server`, presents the bearer token on every call
to `advanced_app_server`, and renders a status-column task board with per-field
four-state authorization driven live over the wire, plus cross-user sharing.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[09 · Forms & UI](../README_advanced_09_forms_ui.md)** and
> [11 · The two Flutter clients](../README_advanced_11_clients_app_admin.md).

## AppBackend seam

`lib/backend/backend.dart` is the barrel. Bind every screen against the
transport-independent `AppBackend` (`app_backend.dart`), never a concrete
backend, so the same widgets drive either implementation:

- **`InMemoryAppBackend`** — a seeded, socket-free fake the widget and contract
  tests bind. It constructs the reflected domain entities in-process and mirrors
  the server's ownership + sharing model, exposing the principal's per-resource
  role grants through `resourceRoles()`, so it is the contract any live backend
  must honour.
- **`LiveAppBackend`** — the production wiring: a thin adapter over an
  `AuthClient` (login/token storage against `advanced_auth_server`), an
  `AppApiClient` (the board API against `advanced_app_server`) and a file
  transfer client, all three sharing one `JsonTransport` and one
  `AuthorizedHttp` so the bearer the login stores is the one every later call
  presents — JSON and bytes alike. `LiveAppBackend.fromConfig()` is the wiring
  that guarantees it, reading both server URLs from the `AdvancedClientConfig`
  config bean. It normalises the client core's transport exceptions
  (`AuthClientException` / `AppApiException` / `TomAuthExpiredException`) into
  the single `AppBackendException` the screens catch. Its `resourceRoles()`
  fetches the principal's grant map from the app server's authenticated
  `GET /resource-roles`: this client treats the authorization token as an opaque
  bearer, so the grants come over the wire rather than out of a token claim.

```dart
// `main.dart` installs one of the two by environment; every screen binds the
// `AppBackend` seam rather than a concrete backend.
final AppBackend backend = InMemoryAppBackend();
final AppBackend liveBackend = LiveAppBackend.fromConfig();

await backend.login(LoginRequest(username: 'alice', password: 'pw'));
final workspaces = await backend.listWorkspaces();
final roles = await backend.resourceRoles(); // resourceKey → roleName ('item:i-1' → 'owner')
```

## App shell (bootstrap + session)

`lib/main.dart` performs five registrations before the first frame —
`initializeReflection()`, `registerProjectRoleVocabulary()` (the shared
`ProjectRole → TomAuthState` grades), the client platform,
`registerSampleFilePicker()` and `AdvancedClientConfig.registerDefault()` (the
server URLs) — then injects an `AppSession` over the chosen backend, fetches the
public login bundle into the resource provider, and calls `runApp`. By default
(no dart-defines) that backend is the live stack: `LiveAppBackend` over the
local servers, reading their URLs from the `AdvancedClientConfig` config bean.
Pass `--dart-define=TEST_MODE=true` to boot on the seeded `InMemoryAppBackend`
instead.

`AppSession` (`lib/app/app_session.dart`) is a `ChangeNotifier` holding the
signed-in principal, the token pair, and the principal's per-resource role
grants. On login it installs those grants as the framework `TomAuthorization`
adapter (an `AppResourceRoleAdapter`), so screens resolve resource keys through
the `TomResourceRoleRegistry`; logout resets the adapter.
`AdvancedTodoApp` (`lib/app/app_root.dart`) rebuilds its home from
`session.isLoggedIn`, so the login↔board switch is state-driven. Every screen
reaches the backend through `AppSession.guard`, so a dropped session (the live
stack's post-refresh `401`, keyed `auth.session_expired`) clears the principal
and routes straight back to login.

## Login screen

`lib/screens/login_screen.dart` is a bound `TomForm` (`lib/forms/login_form.dart`)
over the client-local reflected `LoginCredentials` (`lib/domain/`). On submit it
`save()`s the form (the reflection round-trip writes the typed fields back into
the credentials), folds them into a wire `LoginRequest`, and calls
`AppSession.login`. A rejected login surfaces its `AppBackendException` message
inline (keyed `login-error`) without leaving the page; success lets the shell
swap to the board. The app's reflected graph (domain entities + the
credentials/form) is captured by `lib/reflection_seed.dart` — regenerate with
`./reflection_generation.sh` only when a reflected signature changes.

**Two phases, one screen.** When the account owes a second factor the login
returns `requires2FA` (challenge) or `requires2FAEnrolment` (offer) with an
*interim* token that authorizes nothing, so the session stores only a flag,
`isLoggedIn` stays false, and this same screen switches to its second-factor
phase. Staying on one screen rather than pushing a route is what keeps the
shell's rule intact: the home is a pure function of `isLoggedIn`, with no
navigator state to unwind when a spent challenge drops back to credentials.

**The second-factor phase is the framework's, not this app's.** It is one
widget — `Tom2FAFlowPanel` over a `SessionTwoFactorController`
(`lib/app/session_two_factor_controller.dart`, a `Tom2FAFlowController` over
`AppSession`). The chooser, the QR code, the typable secret, the code field's
width, the attempt counter and the rule that "Not now" appears only when the
server permits it all live in `tom_core_flutter`. This screen contributes the
app-bar title and nothing else — notably it reads no `clientData['digits']`, so
a mechanism with a different code shape needs no change here. A retryable
refusal keeps the phase with the decremented attempt count; a spent challenge or
a burned offer drops back to username/password carrying
`AppSession.abandonedTwoFactorMessage`, so the user learns why.

Sign in as `dave` to be challenged and `erin` to be offered enrolment — in
either run mode, because *which* accounts owe a factor is seed data on both
sides (`twoFactorSecrets` / `twoFactorEnrolling` offline; the
`two_factor_secret` column and the `two_factor_required` / `two_factor_optional`
role rows the auth server's `[005]` migration seeds live). Codes are verified
with the kernel's own `TomTotp` offline, so a code that works here works against
the live server.

## Board screen

`lib/screens/board_screen.dart` is the signed-in home. It cascades the reads in
`initState` — workspaces → projects → lists → items — each hop guarded through
`AppSession.guard`, and re-runs from the picker level when the
workspace/project `TomDropdownButton` changes. Items group into one column
per `TodoStatus` (keyed `status-column-<name>`, with a `(count)` header),
rendered in a horizontally scrollable board. Tapping a card pushes the
item-detail editor.

Each load also fetches the visible items' file descriptors — one
`AppBackend.listAttachments` call per list, beside the item call and never one
per card. That answer is exactly what a `HEAD` on each slot returns, so it moves
no bytes: enough to paperclip the cards that carry a file (keyed
`item-<id>-attachment`, tooltipped with the size) and enough to hand the detail
screen the descriptor it needs to render the stored file on its first frame
instead of after a round-trip.

## Item-detail screen

`lib/screens/item_detail_screen.dart` is the bound editor (keyed
`item-detail-screen`). On open it resolves the item's resource-level ceiling
through the framework registry (`TomAuthorization.resolveAuth('item:<id>')`, via
the login-installed adapter) and **narrows** it by the field's per-role grade
from the shared `projectRoleFieldGrades` matrix (in `advanced_todo_domain`),
stamping the result on each gradable field of a `TodoItemForm`
(`lib/forms/todo_item_form.dart`). The composition reproduces the four ACL states
per role: `owner` edits every field; `editor` sees the assignee and estimate
read-only; `commenter` loses priority/estimate entirely; `viewer` toggles
nothing and loses the estimate — the status control renders disabled and the
remaining five are read-only. With no role the resource ceiling resolves to
`TomAuthState.none` and every field collapses (the closed-safe default — the
registry stays the load-bearing gate).

Save (keyed `item-save-button`) is offered only when at least one gradable field
is editable; it runs the form's reflection round-trip (`save()` writes the typed
fields back into the bound `TodoItem`) and persists through the `SaveItemAction`.
Because non-`full` fields render non-editable, a write-back carries exactly the
permitted fields — the server re-checks the same grade.

Below the fields sit the item's two child collections, loaded together on open
and each authorized differently from the fields above them:

- **The checklist** (keyed `subtask-section`) — the item's subtasks in
  `position` order. Rows render for anyone who can open the screen, but their
  checkboxes carry the section's own state, so a `read` grade renders them
  ticked-but-inert. Adding a step and ticking one are `editor`-and-above (one
  step stronger than commenting, because a subtask is *part of* the item rather
  than a remark about it), and for a viewer the composer is not merely disabled
  but absent.
- **The thread** (keyed `comment-thread`) — the comment history oldest first,
  read-gated by the *item's* readability alone: a viewer reads the discussion
  they may not join. The add-only composer below it (keyed `comment-input` /
  `comment-submit-button`) carries its own `todo.item.comment` action grant.

Both sections re-read from the backend after a successful write rather than
patching their lists locally, so what the screen shows is what the server
stored — including the id and ordering it assigned.

`TodoItemForm` is a reflected `TomClass`, so it is captured by
`lib/reflection_seed.dart` — regenerate with `./reflection_generation.sh` only
when a reflected signature changes.

## The attachment

The item's file lives beside the graded fields but not among them: it is a
**slot** on the server (`AppFileSlots.itemAttachment(<id>)`), moved by
`AppBackend.files` rather than by `AppBackend.saveItem`. The value types differ
(the field holds a `FileRef`, the entity holds the storage key the server
stamps) and so do the write paths — the app server keeps the file column out of
the item's writable bindings precisely so a client cannot mint a storage key by
editing an item.

The authorization, though, is the same story as every field's: the item's
resource ceiling narrowed by the role's attachment grade
(`projectRoleAttachmentGrades`, not `projectRoleFieldGrades`). A commenter or
viewer is graded `read`, so the field shows its download affordance and hides
the picker — matching what the server will actually answer, because the app
server resolves the very same grade per row at the file endpoint. As everywhere
in this sample the client-side narrowing is **cooperation, not enforcement**: it
spares the user an affordance that would be refused, and the server's answer is
the binding one.

Picking a file opens the application's registered picker.
`TomFormFileField` deliberately depends on no picker package, so an application
registers **one** adaptor with `TomFilePickerRegistry` and every file field in
the app opens it. `lib/files/sample_file_picker.dart` is that registration; it
*composes* a small text file rather than asking the platform, because this
sample's clients ship no platform folders. Everything downstream is the real
thing — the same `TomPickedFile` shape a plugin returns, the same `FileRef`
conversion, the same streaming upload, progress, cancel and retry — and that
file's dartdoc carries the six lines a real application writes instead.

## Actions

Every write the app performs — saving an item, posting a comment, adding or
ticking a checklist step, sharing a project — runs through a `TomAction` in
`lib/actions/app_actions.dart` rather than an inline screen callback. Each
action carries a canonical path (`todo.item.save`, `todo.item.comment`,
`todo.item.addSubtask`, `todo.item.toggleSubtask`, `board.share`) and its
`authorizer` resolves that path through the global `TomAuthorization`; the
screen hands its button that same authorizer, so a control's enablement is
driven by the action's grant rather than by ad-hoc screen logic.

`TomAction.execute` is synchronous while the backend seam is `Future`-based, so
each action launches its guarded async op inside `executeSimple` and completes
its context's `result` when it lands (`null` = success, a message = a surfaced
`AppBackendException`). `runAppAction(action, context)` drives one action through
a committed `TomActionTransaction` and returns that future, which is how the
screens keep their busy/error/navigation chrome.

## Server-delivered texts

The app ships no UI strings. Before the first frame the bootstrap fetches the
**public** login bundle through the backend seam and installs it as the
singleton `TomTextResourceProvider`, so the sign-in screen renders
server-delivered chrome. Right after sign-in `AppSession` fetches the
**authenticated** full bundle and installs it merged over the current provider
(full-bundle keys win on overlap), so board, item form, checklist, thread,
attachment and sharing chrome all render server texts while the login chrome
stays resolvable underneath. Logout restores exactly the provider the login
replaced.

Form fields carry no label overrides: each field's `basePath` *is* its wire
resource key, so a label resolves straight from the installed bundle
(`login.username.label`, `todo.item.title.label`, …). Enum-valued dropdowns
label their options from `global.todostatus.*` / `global.todopriority.*`.

## Share dialog

`lib/screens/share_dialog.dart` is the cross-user half of the four-state model:
it grants another user a `ProjectRole` on the board's selected project. The
board's app-bar **Share** action (keyed `share-button`, enabled once a project is
selected) opens it; on a granted share a snackbar confirms it and the grantee's
next read sees the project.

The grantee is entered as a **user id** (keyed `share-grantee-input`, e.g.
`u-carol`), not picked from a list — the frozen step-26 `AppBackend` seam has no
"list users" operation and `share` speaks `granteeUserId`, matching the live
wire. A role drop-down (keyed `share-role-picker`, default `viewer`) and a
**Share** button (keyed `share-submit-button`) submit a `ShareRequest` through
`AppSession.guard`. Only the project owner may share: a denied share surfaces its
`AppBackendException` message inline (keyed `share-error`) and keeps the dialog
open rather than closing it; an empty grantee is blocked client-side before any
backend call. Offline the demo ids are `u-alice`, `u-bob`, `u-carol`, `u-dave`
and `u-erin`; against the live servers the grantee is the numeric auth user id
(alice `2`, bob `3`, carol `4`, dave `5`, erin `6`) — `share` parses it with
`int.tryParse` and rejects anything else.

## Running the full stack

With no dart-defines the app targets the **live stack**, so both servers and
both databases have to be up first:

```sh
# 1. Auth server (issues bearer tokens) — from advanced_auth_server/
cp .env.example .env                     # compose + runtime settings
docker compose up -d auth-db             # MariaDB on host port 3307
dart run bin/auth_server_start.dart      # binds http://localhost:8081

# 2. App server (the board API) — from advanced_app_server/
cp .env.example .env                     # compose + runtime settings
docker compose up -d app-db              # MariaDB on host port 3308
dart run bin/app_server_start.dart       # binds http://localhost:8080

# 3. This client — from advanced_app_client/; no dart-defines, it targets
#    the local servers above (URLs from the AdvancedClientConfig config bean)
flutter run
```

Sign in with a seeded account — `alice` / `alice-pass`, `bob` / `bob-pass`,
`carol` / `carol-pass`, `dave` / `dave-pass`, `erin` / `erin-pass`. `alice` owns
the seeded project and can share it; `bob` is a seeded editor; `carol` starts
with no access until `alice` shares the project; `dave` is challenged for a
second factor and `erin` is offered one.

To explore offline instead, run with `--dart-define=TEST_MODE=true`: the client
boots on the seeded `InMemoryAppBackend`, whose accounts, board, item-detail
field grades, second-factor state and share rights follow the same model the
live servers enforce (offline any non-empty password is accepted). That is the
backend the whole widget suite binds, so nothing in it touches a socket.

## Tests

Run the suite serially (the fakes build reflected entities):

```sh
flutter test --concurrency=1
```

Twelve socket-free suites, all over the seeded `InMemoryAppBackend`:

| Suite | What it holds in place |
| ----- | ---------------------- |
| `in_memory_app_backend_test.dart` | The `AppBackend` contract (TC-26-01..15) any implementation must honour: login and its typed rejections, the workspace→project→list→item reads filtered per principal, item save with the write grade, the `resourceRoles` grant map, and cross-user sharing (owner-only). |
| `app_bootstrap_test.dart` | The shell (TC-27-01..04): boots to login when logged out, a successful login flips the home onto the board, and a post-refresh `401` on a guarded call — as does logout — routes back to login. |
| `login_screen_test.dart` | The bound login screen (TC-28-01..04): starts on sign-in, a valid login proceeds to the board, a rejected one shows an inline error without leaving the page, empty credentials fail validation with no backend call. |
| `login_two_factor_test.dart` | Both second-factor branches. The challenge (TC-28-05..08): a 2FA account stops at the code phase, a valid code completes the login, a wrong one is retryable with the attempts remaining, a third returns to the password screen. The enrolment (TC-2FA-E1..E6): the chooser, the QR code + typable secret + account label, confirmation, a retryable wrong code, declining a skippable offer, and the round trip — after enrolling, the *next* sign-in is challenged. Codes are derived with `TomTotp`, never hardcoded. |
| `board_screen_test.dart` | The status-column board (TC-29-01..03): items grouped by `status`, tapping a card opens its detail, the picker shows the seeded workspace and project. |
| `item_detail_screen_test.dart` | The graded editor and its child sections (TC-30-01..09): `owner` edits everything, `viewer` is read-only with a disabled status control and no `estimate` and no Save, an `editor` save persists only the permitted fields, `commenter` loses priority and estimate, labels are bundle-driven, and the thread + checklist render, accept an added step, persist a toggle, and drop the composer for a viewer. |
| `item_attachment_test.dart` | The file half (TC-D12-01..08, TC-D13-01..02), from both ends: the detail field's pick → upload → progress → cancel → download → clear against the kernel's in-memory transfer client, an editor who may replace and a viewer who may only look, the field collapsing when the resource ceiling cannot be resolved, and the board paperclipping exactly the items that carry a file. |
| `share_dialog_test.dart` | The cross-user share (TC-31-01..03): an owner shares and the grantee then sees the project, a non-owner is refused inline, an empty grantee is blocked before any backend call. |
| `todo_item_form_test.dart` | That every gradable field's `basePath` equals its wire resource key in display order — including `estimateHours`, whose `tomId` is `estimate` so the key names the concept while `bind`/`save` still round-trips into the entity member. |
| `form_label_resolution_test.dart` | Render-level proof (TC-10-01..02) that labels come from the installed bundle and not from overrides: a sentinel bundle is installed and its values are asserted on screen. |
| `login_resources_bootstrap_test.dart` | That the login screen renders server-delivered chrome (TC-8-01) — fetched through the seam, not hardcoded. |
| `full_resources_bootstrap_test.dart` | That sign-in installs the authenticated full bundle over the login bundle and logout restores it (TC-9-01), asserted through the provider's key-fallback behaviour. |

What the widget suite *cannot* show is whether the server agrees with the
client's shaping — the client-side narrowing is cooperation, and the binding
answer is the app server's. That half is asserted live by
`advanced_client_core`'s `tool/run_cross_tier_integration.sh`, which boots both
servers and both databases and drives an admin grant edit through to this app's
field matrix, a project share, and a second user seeing it.

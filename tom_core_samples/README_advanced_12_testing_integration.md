# Testing & cross-tier integration

*Part 12 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

[Part 10](README_advanced_10_servers_endpoints.md) showed the secured servers and
[Part 11](README_advanced_11_clients_app_admin.md) the two clients that consume
them. This part is how the whole sample *proves
itself*: a layered test strategy that keeps the everyday suites fast and
socket-free, plus one scripted run that boots the real stack end-to-end. The
two ideas the guide rests on — server-delivered texts and authorization-driven
field grades — are not described and trusted here, they are **asserted**: a
sentinel suffix proves a label came from the server bundle, and a four-role
matrix proves the same widget renders differently per principal.
[Part 13](README_advanced_13_file_transfer.md) then follows a single feature —
file transfer — through every layer this part tests.

## Test strategy across the seven packages

Each package carries its own suite, written against the layer it owns and
against the seam directly below it — never against a live socket:

| Package | What its suite proves |
| --- | --- |
| `advanced_todo_domain` | the reflected entities round-trip and the enums/resource-key constants hold |
| `advanced_todo_contracts` | the wire DTOs serialize/deserialize and the typed service interfaces match the registry |
| `advanced_client_core` | the Flutter-free client core: auth/token storage, the shared transport, error normalisation (+ the live cross-tier, login and file-transfer scenarios, below) |
| `advanced_auth_server` | the JWT issuer, the role gate, and the admin grant/assignment API against an in-process datasource |
| `advanced_app_server` | the secured task API: the ownership-or-share resolver, the four-state field-grade resolver, the write enforcement, and the per-row column grade + file-column declarations behind the file slots |
| `advanced_app_client` | the end-user widgets bound to the **in-memory** backend fake — the four-role render matrix, the sentinel render proof, and the graded attachment field |
| `advanced_authadmin_client` | the admin console widgets against the **in-memory** admin fake — CRUD drafts, two-phase login, the grant-matrix editor |

The discipline that makes this work is the **injected backend seam**
([Part 11](README_advanced_11_clients_app_admin.md)): every client screen is
written against an interface (`AppBackend` / `AdminBackend`), and the widget
suites bind the seeded in-memory implementation. Because the fake mirrors the
server's ownership + four-state model in process, the widget tests are
deterministic by construction and never open a socket. The only place the real
stack is exercised is `advanced_client_core`'s live suites, each of which
**skips itself** when the servers are unreachable so a plain unit run stays
green.

## Flutter tests serial only

The two client packages are Flutter packages; their suites **must run
serially** (`flutter test -j 1`). Parallel test isolates corrupt the shared
process-global state these tests deliberately install and clear — the
`TomTextResourceProvider` singleton (the resource bundle), the
`TomAuthorization` adapter (the field-grade matrix), and the
`TomBearerAuthentication` token store. Each widget test installs its bundle/
adapter in `setUp` and clears it in `tearDown` (`TomAuthorization.reset`); two
tests racing on those singletons would read each other's state and flake. The
green gate runs every Flutter suite single-threaded for this reason.

## The sentinel-`[srv]` render proof

The guide's first headline rule is that UI texts are not hardcoded — they come
from a server-delivered resource bundle keyed by `basePath`
([Part 08](README_advanced_08_resources_texts.md)). The render proof makes that
falsifiable: a test installs a bundle whose every value carries a distinctive
`[srv]` suffix, pumps the widget, and asserts the suffixed strings appear. A
hardcoded label would render its own text and the `find.textContaining('… [srv]')`
expectation would fail — so a green test *is* the proof the label resolved
through the bundle.

It is applied at both the login and the bound-form layer, in both clients:

- `advanced_app_client/test/form_label_resolution_test.dart` installs
  `'login.username.label': 'Username [srv]'` (and the password/hint keys), pumps
  the login screen, and asserts the sentinels render (`:65`, `:78`); a second
  group does the same for all seven `todo.item.*` field labels (`:91`,
  `:107`).
- `advanced_app_client/test/item_detail_screen_test.dart` folds the same proof
  into the bound detail form as **TC-30-05** (`:233`): the owner opens the
  editor against a `[srv]`-suffixed field bundle and every field label resolves
  from it (`:241`, `:250`).
- The admin console mirrors it — `admin_login_form_test.dart:111` for the
  `adminLogin.*` keys and `advanced_authadmin_client/test/form_label_resolution_test.dart`
  for the user/role/group draft forms (`:64`, `:89`, `:108`).

## The four-role render matrix

The guide's second headline rule is that UI authorization is driven by the
server's per-field grades, not by client policy
([Part 07](README_advanced_07_authorization.md)). The matrix proof is the
heart of the sample: `advanced_app_client/test/item_detail_screen_test.dart`
pushes the **same** `ItemDetailScreen` (the same bound `TodoItemForm`) four
times, each as a different principal, and asserts the rendering differs purely
because the session installed a different field matrix on the `TomAuthorization`
singleton — the form holds no authorization state of its own (the regression
guard for the per-field-authorizer removal, `:45`):

| Test | Principal (role) | What the matrix renders |
| --- | --- | --- |
| **TC-30-01** (`:131`) | `alice` (owner) | every gradable field is `full` — a complete editor with a Save |
| **TC-30-02** (`:158`) | `val` (viewer, shared in) | read-only fields, a *disabled* status control, `estimate` hidden (`none` → field collapses), no Save |
| **TC-30-03** (`:184`) | `bob` (editor) | can save, but `assigneeId` is `read`; editing the title and saving persists the title while the assignee stays put — the write-back carries only the editable fields |
| **TC-30-04** (`:202`) | `val` (commenter) | both `priority` and `estimate` graded `none` (hidden), the rest read, no Save — distinct from the viewer matrix where `priority` stays visible |

TC-30-03 is the one that also proves *server-side* enforcement matters: the
client only sends the fields its grade renders editable, so the read-only
`assigneeId` is never in the write-back — and the server's
`_enforceFieldWrites` ([Part 10](README_advanced_10_servers_endpoints.md)) is
the backstop for a client that ignores its grade.

## The cross-tier integration runner

Three suites in `advanced_client_core/test/` run against the real stack, all
driven by the one script `advanced_client_core/tool/run_cross_tier_integration.sh`:

| Suite | What only a live stack can show |
| --- | --- |
| `cross_tier_integration_test.dart` (**TC-37-01…09**) | the two servers' authorization agreeing across the database boundary — including at the file endpoint |
| `auth_client_integration_test.dart` (**TC-22-11/12**) | a real login, including the two-pass 2FA exchange |
| `file_transfer_integration_test.dart` (**TC-FT-01…05**) | bytes moving through both blob stores, the closed/anonymous refusals, and a read-only column grade |

The runner is one scripted command for the Phase-7 "scenario passes end-to-end"
bar:

1. **Fresh databases.** `docker compose down -v` drops the old volume so the
   `initdb` seed re-applies, then brings up `advanced-auth-db` (:3307) and
   `advanced-app-db` (:3308) and waits for each container's docker health to
   report `healthy`.
2. **Resolve dependencies** once for the auth server, app server, and client
   core.
3. **Start the servers in order** — the auth server first (it mints tokens and
   owns the grant matrix), then the app server (it reads grants from `auth_db`
   and verifies the auth tokens). Each is started with `exec dart run` so the
   recorded PID is the server itself (cleanup actually stops it instead of
   orphaning a port-holding child). The waits are generous (~6 min) because
   `dart run` cold-compiles the reflection-bootstrapping server graph on first
   boot; a `.dill` snapshot is *not* viable (detached snapshots fail to
   initialise the generated reflection).
4. **Run the three suites** against the live stack and tear everything down via
   an `EXIT` trap that dumps the server logs on any non-zero exit.

The cross-tier scenario itself walks the three cross-tier authorization
mechanisms:

- **An admin grant edit reaches the end-user's field matrix.** The `admin` edits
  the `viewer` role's `todo.item.title` grant through the auth server's
  `PUT /admin/grants`; a seeded `viewer` then re-reads the item's field states
  from the *app* server and sees the new grade — proving the app server resolves
  grades from the very rows the auth server's admin API writes (the app server's
  main datasource points at `auth_db`). The test posts the complete intended
  `viewer` row (only `title` flipped) and restores it in `finally`, so it leaves
  `auth_db` exactly as seeded and is re-runnable.
- **A share reveals a project to a second user.** `alice` creates a project,
  `bob` cannot list it, `alice` shares it as `editor`, and `bob` then lists it —
  the ownership-or-share resolver in action over the live wire.
- **An admin grant edit reaches the *file* endpoint** (**TC-37-09**). The same
  `PUT /admin/grants` narrows `owner`'s grade on the item's `attachment` column
  from `full` to `read`; alice, who owns the item, keeps the download and is
  refused the upload; restoring the cell gives it back. The beat proves the
  grade governing bytes is the grant row an administrator already edits — not a
  file-specific permission model — and it is why file transfer belongs in this
  sample rather than in a framework example
  ([Part 13](README_advanced_13_file_transfer.md)).

The **file-transfer** suite is the one that cannot be faked at all: it asserts
that a byte stream posted by a client lands in a blob store, that the row's key
column is updated, and that a later `GET` hands the same bytes back — six layers
agreeing at once (client → endpoint → repository → column grade → blob store →
database). It also makes the three negative claims the feature exists to
guarantee, one per refusal layer: a column that never said `exposed` is **not
addressable** (asserted beside a reachable neighbour on the same row, by the same
principal, so a 404 cannot be mistaken for an unreachable row); an
**unauthenticated** caller is refused by the endpoint's own gate on both servers;
and a principal whose **column grade is `read`** is served the complete bytes yet
refused both the replace and the delete (TC-FT-05). Each test restores the slot
it used, so the suite is re-runnable against the same databases.

Because the servers' host ports may be held by an unrelated service, the runner
guards 8080/8081 with a preflight (`assert_ports_free`) and refuses to start
rather than racing a stale process. When the servers are unreachable the tests
call `markTestSkipped` rather than failing; under the runner the servers are
guaranteed up, so the runner treats "All tests skipped" as a failure — only a
real PASS from each of the three suites exits 0.

## The global green gate

A change is done only when all three hold together:

1. **`dart analyze` is clean** in every package (zero errors, zero warnings).
2. **Every suite is green**, run serially (the Flutter packages with `-j 1`).
3. **The cross-tier runner exits 0** with "All tests passed!" against a freshly
   booted stack.

This gate was last re-run live on 2026-07-28. Reaching it has so far surfaced
and fixed **seven** real `tom_core_server` bugs: zone principal resolution, the
nullable surrogate-key read, the MariaDB `bool`→`1`/`0` bind, query-string
parameter binding, pipeline error logging, a streamed download that lost its
principal (a shelf response body is lazy, so the read ran outside the request
zone), and a file endpoint that declared no access policy at all — which, given
that the framework's protection default is *open*, made every exposed file
column world-readable. The suites are not decoration; they were the instrument
that found framework defects, including two security-relevant ones.

## Test counts

Current green-gate counts (runtime, the authoritative figure):

| Package | Tests |
| --- | --- |
| `advanced_todo_domain` | 24 |
| `advanced_todo_contracts` | 45 |
| `advanced_client_core` | 63 (+18 live-stack tests that skip without the servers) |
| `advanced_auth_server` | 81 |
| `advanced_app_server` | 115 |
| `advanced_app_client` | 54 |
| `advanced_authadmin_client` | 67 |

`advanced_client_core`'s 18 skips are not a shortfall — they are the suites that
only a booted stack can answer, and the runner turns each of them green:
`cross_tier` 9, `file_transfer` 5, `auth_client` 2, plus one apiece in
`admin_api_client_integration_test.dart` and `app_api_client_integration_test.dart`.

> A static grep of `app_server` finds 112 `test()`/`testWidgets()` calls against
> the runtime 115, because several suites emit tests from a loop (e.g.
> `field_grade_resolver_test.dart` over `ProjectRole.values`,
> `resource_bundle_endpoint_test.dart` over the gradable item field tokens,
> `app_share_endpoints_test.dart` over the not-found keys). The **runtime** count
> from the green gate is the one to trust. Every other package's static and
> runtime counts agree.

## Primary sources

- `advanced_app_client/test/{form_label_resolution_test.dart, item_detail_screen_test.dart}`,
  `advanced_authadmin_client/test/{admin_login_form_test.dart, form_label_resolution_test.dart}`
- `advanced_client_core/test/cross_tier_integration_test.dart`,
  `advanced_client_core/tool/run_cross_tier_integration.sh`

---

← Prev: [11 · The two Flutter clients](README_advanced_11_clients_app_admin.md) · Next: [13 · File transfer under the authorization matrix](README_advanced_13_file_transfer.md) →

# advanced_client_core

Flutter-free `dart:io` client core for the **advanced Tom Core full-stack
sample** (see [`../README_advanced_sample.md`](../README_advanced_sample.md)).

The authenticated HTTP layer shared by `advanced_app_client` and
`advanced_authadmin_client`. Nothing here imports Flutter, so the JSON↔DTO
parsers are unit-testable headless (no sockets in tests).

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[06 · Authentication (JWT)](../README_advanced_06_authentication.md)**, with
> its client-side usage in
> [11 · The two Flutter clients](../README_advanced_11_clients_app_admin.md).

## The HTTP seam

Every client talks to the servers through one seam, `JsonTransport`
(`lib/src/http/json_transport.dart`) — a request reduced to *method, URI,
headers, JSON body* → `HttpJsonResponse(statusCode, body)`. The live
`IoJsonTransport` backs it with `dart:io`; tests pass a fake, so the whole client
core unit-tests with no sockets.

## `AuthClient`

`AuthClient` (`lib/src/auth/auth_client.dart`) sequences the auth server's
`/auth/*` calls and stores the token pair:

- `login(LoginRequest)` — POSTs `/auth/login`, maps a non-success status to a
  typed `AuthClientException` (carrying the server's stable error `key` when
  present), and on success stores the returned pair via
  `TomBearerAuthentication.setTokens` so every later request can attach the
  bearer. For an account enrolled in a second factor the result carries
  `requires2FA` and the stored pair is *interim* — it authorizes nothing until
  the challenge is answered.
- `pendingChallenge` — the `Tom2FAChallenge` the stored interim token is waiting
  on (mechanism, hint, attempts remaining, expiry, the mechanism's `clientData`),
  or `null` when there is no half-finished login. Read straight out of the
  token's claims, so the client never mirrors challenge state that could drift
  from the server's.
- `submitSecondFactor(code)` — POSTs `/auth/second-factor` with the code and the
  interim token **in the body** (the endpoint is public: the interim principal is
  not authenticated, so a bearer gate would reject the very request it exists to
  serve). On success stores and returns the completed pair. A refused code throws
  with `AuthClientException.canRetrySecondFactor` set, having already stored the
  server's re-issued token — the attempt counter lives *inside* the token, so
  retrying against a stale copy would never spend an attempt.
- `pendingEnrolment` — the `Tom2FAPendingEnrolment` the stored interim token is
  offering (which mechanisms, whether declining is allowed, and — after
  `beginEnrolment` — the mechanism's `clientData` with the secret to show), read
  out of the token's claims like `pendingChallenge`.
- `beginEnrolment(type)` / `confirmEnrolment(code)` / `skipEnrolment()` — the
  three enrolment passes. Each stores whatever token comes back, which is what
  makes them chainable: `confirm` needs the token `begin` produced, not the one
  `login` did. A confirmed enrolment issues the *final* pair outright — deriving
  a code from the just-issued secret has already proved possession — and `skip`
  only works when the offer was skippable.
- `loginResources()` — GETs the public `/auth/resources/login` bundle (no bearer,
  no prior login) for the sign-in screen's texts.
- `refresh()` — POSTs `/auth/refresh` with the stored authorization token as the
  bearer and re-stores the fresh pair. Throws `auth.no_token` if no session is
  stored.
- `logout()` — best-effort `/auth/logout`, then **always** discards the local
  token pair (even if the server call fails), including a half-finished 2FA
  challenge.

```dart
final auth = AuthClient(Uri.parse('http://localhost:8081'));
final result = await auth.login(
    LoginRequest(username: 'alice', password: 'alice-pass'));
// result.user is the principal; the bearer is now stored for app/admin calls.

// A 2FA account (`dave`) stops half-way and needs the second pass:
if (result.requires2FA) {
  final digits = auth.pendingChallenge?.clientData['digits']; // 6, for TOTP
  await auth.submitSecondFactor(codeFromUser);
}
```

The client treats the authorization token as an **opaque bearer**
(`decryptTokens: false` by default): it reads identity from `LoginResult.user`
and field grades from the app API, so no RSA key is configured client-side.

## `AuthorizedHttp`

`AuthorizedHttp` (`lib/src/http/authorized_http.dart`) is the decorator the app
and admin API clients send every authenticated call through. It
supplies the two client-specific seams to the framework's pluggable refresh/retry
policy (`tom_core_kernel`'s `tomRunWithAuthRetry`, G-AUTH-3) — the `JsonTransport`
for the call and a `TomAuthRefresher` backed by `AuthClient.refresh` for recovery
— rather than hand-coding the sequence:

- Injects `Authorization: Bearer <authzToken>` from the stored session, merged
  with any caller-supplied headers, read **fresh on every attempt**.
- On a `401` the kernel policy refreshes the token pair **once** and retries the
  request **exactly once** — so a single token expiry is invisible to the caller.
- A `2xx` (or any non-401 status such as `403`/`404` the API client maps itself)
  is returned as-is. A `401` that persists *after* the refresh+retry throws the
  kernel's `TomAuthExpiredException` (the session is dead — re-authenticate); a
  refresh that itself fails surfaces its own `AuthClientException`.

```dart
final transport = IoJsonTransport();
final auth = AuthClient(Uri.parse('http://localhost:8081'), transport: transport);
final http = AuthorizedHttp(transport, auth);
// After login, every send carries the bearer and self-heals one expiry:
final response = await http.send(
    method: 'GET', uri: Uri.parse('http://localhost:8080/items'));
```

## `AppApiClient`

`AppApiClient` (`lib/src/api/app_api_client.dart`) is the typed client over
`advanced_app_server`'s todo-board endpoints (the `appApi` registry). It
implements the shared `AppApiService` interface — so it is the live seam the app
client's backend plugs in, with an in-memory fake implementing the
same interface for widget tests — and routes every call through
`AuthorizedHttp`, so the bearer is attached and a single token expiry self-heals.

The JSON↔entity mapping lives in **pure** top-level `parse*` functions
(`parseWorkspace(s)`, `parseProject(s)`, `parseList(s)`, `parseItem(s)`,
`parseComment(s)`, `parseSubtask(s)`),
unit-tested against captured server-shaped responses with no socket — mirroring
`core_client_sample`'s `LiveTodoReadClient` discipline. The principal's
authorization arrives as a flat `resourceKey → roleName` map from
`GET /resource-roles` (`AppApiClient.resourceRoles`, decoded inline), which the
app client installs in the framework registry to grade fields locally.

- **Wire shape.** The app server emits the framework serialization of each
  service result: a single entity as `entity.toJson()`, a list as a *bare* JSON
  array of those maps (no `{items:[…]}` envelope), dates as the `@!@`-prefixed
  ISO string, and the resource-role map as a plain `Map<String, String>`.
- **Errors.** A `403`/`404` (`{"error": key}` body) surfaces as a typed
  `AppApiException` carrying the server's stable key; a persistent `401` was
  already turned into an `TomAuthExpiredException` by the wrapper.
- **Reflection.** The parsers build reflected entities, so
  `initializeReflection()` (from `advanced_todo_domain`) must run first — the app
  bootstrap does it once at startup; tests do it in `setUpAll`.

```dart
final transport = IoJsonTransport();
final auth = AuthClient(Uri.parse('http://localhost:8081'), transport: transport);
final api = AppApiClient(
    Uri.parse('http://localhost:8080'), AuthorizedHttp(transport, auth));
await auth.login(const LoginRequest(username: 'alice', password: 'alice-pass'));
final items = await api.listItems('3'); // bearer attached, parsed to TodoItems
```

> **Known kernel gap (out of scope here).** The kernel's `TomList`
> (de)serialization is not round-trip-safe: `setValues` on a typed
> `TomList<TomString>` (e.g. `TodoItem.tags`) throws even for an empty array, and
> `getValues` emits its elements unconverted so the server cannot `jsonEncode` a
> non-empty one. The parsers therefore map entities field-by-field (not via
> `setValues`); the item *write* path (`createItem`/`updateItem`) is implemented
> to the intended contract but cannot round-trip a tagged item until the kernel
> gap is fixed.

## `AdminApiClient`

`AdminApiClient` (`lib/src/api/admin_api_client.dart`) is the typed client over
`advanced_auth_server`'s `/admin/*` endpoints (the `adminApi` registry — users,
roles, groups, the grant matrix and role assignments). It implements the shared
`AdminApiService` interface — so it is the live seam the authadmin client's
backend plugs in, with an in-memory fake implementing the same
interface for widget tests — and routes every call through `AuthorizedHttp`,
carrying the `admin` principal's bearer.

The JSON↔DTO mapping lives in **pure** top-level `parse*` functions
(`parseUser(s)`, `parseRole(s)`, `parseGroup(s)`, `parseGrantMatrix`), unit-tested
against captured server-shaped responses with no socket. The admin DTOs are
reflection-first, so each parser is a thin, total wrapper over `dtoFromJson<T>` —
and, exactly like the app API's reflected entities, the combined reflection seed
must be installed first (`initializeReflection` from
`package:advanced_client_core/reflection_seed.dart` in this package's tests, or
each Flutter client's own combined seed at runtime).

- **Wire shape.** A *list* result (`listUsers`/`listRoles`/`listGroups`) matches
  the pipeline's `result is List<Object>` branch and arrives as a *bare* JSON
  array of reflected DTO maps; a *single* DTO result (`createUser`/`updateUser`/
  …/`getGrants`) is serialized by the pipeline's reflection encoder into a
  correctly shaped object; a *void* result (the deletes, `putGrants`, `assign`)
  is an empty `200` body. The grant matrix is the
  `{matrix: {role: {resourceKey: accessToken}}}` object (unknown tokens degrade
  closed-safe to `none`).
- **Errors.** A denial the server maps to a non-success status (e.g. the
  `admin`-role gate's `403` with body
  `{"error": "endpoint_handler.handle_method_call.access_denied"}`) surfaces as a
  typed `AdminApiException` carrying that stable key and the status; a persistent
  `401` was already turned into an `TomAuthExpiredException` by the wrapper.

```dart
final transport = IoJsonTransport();
final authBase = Uri.parse('http://localhost:8081');
final auth = AuthClient(authBase, transport: transport);
final admin = AdminApiClient(authBase, AuthorizedHttp(transport, auth));
await auth.login(const LoginRequest(username: 'admin', password: 'admin-pass'));
final users = await admin.listUsers(); // bearer attached, parsed to UserDtos
```

## Files

Bytes travel over the kernel's `TomFileTransferClient`, not the JSON seam — a
payload worth storing is a payload not worth holding in memory as a string.
`lib/src/http/file_transfer.dart` supplies the two halves and their one correct
composition:

- `ioFileTransferClient(serverBaseUri)` — the transport: a `dart:io` client
  pointed at the server's `/files` endpoint whose `headerProvider` is
  `AuthorizedHttp.authorizationHeader`, the *same* function the JSON clients
  send. (It supplies its own `dart:io` client rather than resolving the kernel's
  platform seam, which this deliberately Flutter-free package never registers.)
- `AuthorizedFileTransferClient(delegate, refresher)` — the policy: it runs
  `upload`/`download`/`describe`/`remove` under the same
  `tomRunWithAuthRetry` recovery the JSON half uses, translating the transfer
  client's `TomFileTransferException` (which reports by *throwing*) into a status
  the kernel policy can rule on. A refusal that names no status is rethrown
  untouched; a download refused *after* the first chunk is not retried.
- `authenticatedFileTransferClient(serverBaseUri, http)` — the composition an
  application installs, passing `http.refresher` so bytes and JSON share **one**
  token path rather than two that can drift apart.

```dart
final files = authenticatedFileTransferClient(
    Uri.parse('http://localhost:8080'), authorizedHttp);
try {
  await files.upload(
    slot: AppFileSlots.itemAttachment('1'),
    source: TomFileSource.bytes('spec.pdf', bytes),
  );
} finally {
  files.close();
}
```

## `AdvancedClientConfig`

`AdvancedClientConfig` (`lib/src/config/client_config.dart`) is the config bean
holding the three server URLs both Flutter clients target — `authServerUrl`
(`:8081`), `appServerUrl` (`:8080`) and `adminServerUrl` (the auth server's
`/admin/*`, also `:8081`). URLs live in a bean resolved through the kernel
locator, not in `String.fromEnvironment` reads scattered through a client's
`main()` (G-ENV-3). Each client calls `AdvancedClientConfig.registerDefault()`
once at startup (idempotent — an already-registered config is returned
unchanged) and `AdvancedClientConfig.resolve()` wherever it needs a URL.

## Tests

Six socket-free suites always run; five live suites **skip themselves** when a
server is unreachable, so `dart test` stays green without a stack. All of them
install the combined domain+contracts reflection seed
(`package:advanced_client_core/reflection_seed.dart`) in `setUpAll`.

Socket-free:

- `test/auth_client_test.dart` — login/refresh/logout sequencing and token
  storage against a fake `JsonTransport`, plus `LoginResult` parsed from a
  captured `/auth/login` body.
- `test/auth_client_two_factor_test.dart` — the two-pass login: the interim
  token stored on pass 1, the challenge detail read from the *token* rather than
  the DTO, the code posted in the body (no bearer), a refused code storing the
  re-issued token and reporting itself retryable, and `logout` dropping a
  half-finished login.
- `test/authorized_http_test.dart` — against a path-routing fake transport:
  bearer injection/merging, and the refresh-once-on-401 recovery (exactly one
  refresh + one retry, the retry carrying the fresh token, a persistent 401
  surfacing a typed error).
- `test/authorized_file_transfer_test.dart` — all four transfer operations
  recovering from an expired token through the *same* credential and the *same*
  refresher the JSON half uses; the replayed upload re-reading its source; a
  non-expiry refusal rethrown unchanged.
- `test/app_api_client_test.dart` — the pure `parse*` functions against captured
  server-shaped responses (enum tokens, the `@!@` date prefix, tags, partial
  rows, preserved thread/checklist order) and the typed methods over a
  path-routing fake transport (query/path/bearer assertions, a `403`/`404`
  raising a typed `AppApiException`).
- `test/admin_api_client_test.dart` — the pure `parse*` functions against
  captured server-shaped responses (bare user/role/group arrays, partial rows
  keeping DTO defaults, the role×field grant matrix with unknown/unset cells
  degrading closed-safe) and the typed methods over a path-routing fake
  transport (method/path/bearer assertions, a `403` raising a typed
  `AdminApiException` carrying the server key).

Live (all guarded by a reachability check):

- `test/auth_client_integration_test.dart` — a live login against
  `advanced_auth_server` on `localhost:8081`, `dave`'s two-pass TOTP login, and
  `erin`'s enrolment (offered a factor, declining it, setting one up, then being
  challenged on the factor she just created). Codes are derived from the
  enrolment's own `clientData` with the kernel's `TomTotp`, so no authenticator
  app is needed.
- `test/app_api_client_integration_test.dart` — a live `GET /status` then an
  authenticated `listWorkspaces()` against `advanced_app_server` on
  `localhost:8080`.
- `test/admin_api_client_integration_test.dart` — an authenticated `listUsers()`
  as the seeded `admin` against `advanced_auth_server`.
- `test/cross_tier_integration_test.dart` — the scripted cross-tier scenario
  (see below).
- `test/file_transfer_integration_test.dart` — bytes moving across both servers:
  an upload landing in each server's own blob store and being served back, the
  non-exposed file column staying unaddressable, and a principal graded `read`
  on the column getting the download while the upload and the delete are
  refused.

## The cross-tier scenario

`tool/run_cross_tier_integration.sh` boots the whole stack — both MariaDB
databases from each server's `docker-compose`, then both Dart servers — runs all
five live suites against it, and tears everything down. It refuses to start if
a leftover server holds `8080`/`8081`, starts the databases from *fresh* volumes
so the seed re-applies, dumps the server logs on any non-zero exit, and treats a
whole-suite skip as a failure (under this runner the servers are guaranteed up,
so a skip means something died after the health check).

`test/cross_tier_integration_test.dart` is what it exists for: the loop that
crosses every tier at once — an **admin grant edit** through `/admin/grants`
changing what an end-user may write, a **share** revealing a project to a second
user, the same grant edit reaching the **file endpoint** (one cell deciding
whether bytes may be written), and the item's **child collections** gated one
step apart (`commenter` for a comment, `editor` for a subtask) as three
principals touch one item.

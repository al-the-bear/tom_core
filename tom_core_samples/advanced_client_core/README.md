# advanced_client_core

Flutter-free `dart:io` client core for the **advanced Tom Core full-stack
sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

The authenticated HTTP layer shared by `advanced_app_client` and
`advanced_authadmin_client`. Nothing here imports Flutter, so the JSON↔DTO
parsers are unit-testable headless (no sockets in tests).

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> This package is documented in context by
> **[06 · Authentication (JWT)](../README_advanced_06_authentication.md)**, with
> its client-side usage in
> [11 · The two Flutter clients](../README_advanced_11_clients_app_admin.md).

## Status

`AuthClient` (step 22), `AuthorizedHttp` (step 23), `AppApiClient` (step 24) and
`AdminApiClient` (step 25) implemented — the client core is **complete**.

## The HTTP seam

Every client talks to the servers through one seam, [`JsonTransport`]
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
  bearer.
- `refresh()` — POSTs `/auth/refresh` with the stored authorization token as the
  bearer and re-stores the fresh pair. Throws `auth.no_token` if no session is
  stored.
- `logout()` — best-effort `/auth/logout`, then **always** discards the local
  token pair (even if the server call fails).

```dart
final auth = AuthClient(Uri.parse('http://localhost:8081'));
final result = await auth.login(
    const LoginRequest(username: 'alice', password: 'alice-pass'));
// result.user is the principal; the bearer is now stored for app/admin calls.
```

The client treats the authorization token as an **opaque bearer**
(`decryptTokens: false` by default): it reads identity from `LoginResult.user`
and field grades from the app API, so no RSA key is configured client-side.

## `AuthorizedHttp`

`AuthorizedHttp` (`lib/src/http/authorized_http.dart`) is the decorator the app
and admin API clients (steps 24–25) send every authenticated call through. It
composes the two step-22 pieces — the `JsonTransport` for the call and
`AuthClient.refresh` for recovery:

- Injects `Authorization: Bearer <authzToken>` from the stored session, merged
  with any caller-supplied headers, read **fresh on every attempt**.
- On a `401` it refreshes the token pair **once** and retries the request
  **exactly once** — so a single token expiry is invisible to the caller.
- A `2xx` (or any non-401 status such as `403`/`404` the API client maps itself)
  is returned as-is. A `401` that persists *after* the refresh+retry throws
  `AuthorizedHttpException` (the session is dead — re-authenticate); a refresh
  that itself fails surfaces its own `AuthClientException`.

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
client's backend plugs in (step 26), with an in-memory fake implementing the
same interface for widget tests — and routes every call through
`AuthorizedHttp`, so the bearer is attached and a single token expiry self-heals.

The JSON↔entity mapping lives in **pure** top-level `parse*` functions
(`parseWorkspaces`, `parseProjects`, `parseLists`, `parseItems`, `parseComment`,
`parseFieldStates`), unit-tested against captured server-shaped responses with
no socket — mirroring `core_client_sample`'s `LiveTodoReadClient` discipline.

- **Wire shape.** The app server emits the framework serialization of each
  service result: a single entity as `entity.toJson()`, a list as a *bare* JSON
  array of those maps (no `{items:[…]}` envelope), dates as the `@!@`-prefixed
  ISO string, and the field-state matrix as a bare array of `GradedFieldDto`.
- **Errors.** A `403`/`404` (`{"error": key}` body) surfaces as a typed
  `AppApiException` carrying the server's stable key; a persistent `401` was
  already turned into an `AuthorizedHttpException` by the wrapper.
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
> gap is fixed. See `step24_app_api_client_decisions.md`.

## `AdminApiClient`

`AdminApiClient` (`lib/src/api/admin_api_client.dart`) is the typed client over
`advanced_auth_server`'s `/admin/*` endpoints (the `adminApi` registry — users,
roles, groups, the grant matrix and role assignments). It implements the shared
`AdminApiService` interface — so it is the live seam the authadmin client's
backend plugs in (step 32), with an in-memory fake implementing the same
interface for widget tests — and routes every call through `AuthorizedHttp`,
carrying the `admin` principal's bearer.

The JSON↔DTO mapping lives in **pure** top-level `parse*` functions
(`parseUser(s)`, `parseRole(s)`, `parseGroup(s)`, `parseGrantMatrix`), unit-tested
against captured server-shaped responses with no socket. The admin DTOs are
plain value records that already own a `fromJson`, so the parsers are thin, total
wrappers — and, unlike the app API's reflected entities, **no
`initializeReflection` is needed**.

- **Wire shape.** A *list* result (`listUsers`/`listRoles`/`listGroups`)
  serializes as a *bare* JSON array of `toJson()` maps; a *void* result (the
  deletes, `putGrants`, `assign`) is an empty `200` body; the grant matrix is the
  `{role: {resourceKey: accessToken}}` object (unknown tokens degrade closed-safe
  to `none`).
- **Errors.** A denial the server maps to a non-success status (e.g. the
  `admin`-role gate's `403` with body
  `{"error": "endpoint_handler.handle_method_call.access_denied"}`) surfaces as a
  typed `AdminApiException` carrying that stable key and the status; a persistent
  `401` was already turned into an `AuthorizedHttpException` by the wrapper.

```dart
final transport = IoJsonTransport();
final authBase = Uri.parse('http://localhost:8081');
final auth = AuthClient(authBase, transport: transport);
final admin = AdminApiClient(authBase, AuthorizedHttp(transport, auth));
await auth.login(const LoginRequest(username: 'admin', password: 'admin-pass'));
final users = await admin.listUsers(); // bearer attached, parsed to UserDtos
```

> **Known server gap (out of scope here).** A *single*-DTO admin result
> (`createUser`/`updateUser`/`createRole`/`updateRole`/`createGroup`/
> `updateGroup`/`getGrants`) is not a `TomClass`, `Map`, or `List`, so the
> endpoint pipeline falls through to the reflection serializer — which reads
> `getValues`, skips `final` fields and looks for a `jsonEncode` getter rather
> than `toJson`. A plain all-`final` DTO therefore serializes to `{}` over the
> live wire (the same pre-existing gap step 22 flagged for the `LoginResult`
> login response). These client methods are implemented to the *intended*
> contract — their parsers are correct against a correctly-shaped body, and the
> in-memory admin fake (step 32) round-trips — but a single-DTO response cannot
> round-trip against the live server until that kernel/server gap is fixed. The
> integration smoke therefore exercises the *list* endpoint `listUsers`, which
> serializes correctly today. See `step25_admin_api_client_decisions.md`.

## Tests

- `test/auth_client_test.dart` — socket-free unit tests against a fake
  `JsonTransport` (login/refresh/logout sequencing + token storage) plus the
  pure `LoginResult.fromJson` parser against a captured `/auth/login` body.
- `test/authorized_http_test.dart` — socket-free unit tests against a
  path-routing fake transport: bearer injection/merging, and the
  refresh-once-on-401 recovery (exactly one refresh + one retry, the retry
  carrying the fresh token, a persistent 401 surfacing a typed error).
- `test/app_api_client_test.dart` — socket-free unit tests: the pure `parse*`
  functions against captured server-shaped responses (enum tokens, the `@!@`
  date prefix, tags, partial rows) and the typed methods over a path-routing
  fake transport (query/path/bearer assertions, a `403`/`404` raising a typed
  `AppApiException`).
- `test/auth_client_integration_test.dart` — a live login against a running
  `advanced_auth_server` on `localhost:8081`; **skips itself when the server is
  unreachable**.
- `test/app_api_client_integration_test.dart` — a live `GET /status` then an
  authenticated `listWorkspaces()` against `advanced_app_server` on
  `localhost:8080`; **skips itself when a server is unreachable**.
- `test/admin_api_client_test.dart` — socket-free unit tests: the pure `parse*`
  functions against captured server-shaped responses (bare user/role/group
  arrays, partial rows keeping DTO defaults, the role×field grant matrix with
  unknown/unset cells degrading closed-safe) and the typed methods over a
  path-routing fake transport (method/path/bearer assertions, a `403` raising a
  typed `AdminApiException` carrying the server key).
- `test/admin_api_client_integration_test.dart` — an authenticated `listUsers()`
  as the seeded `admin` against `advanced_auth_server` on `localhost:8081`;
  **skips itself when the server is unreachable**.

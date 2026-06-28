# advanced_client_core

Flutter-free `dart:io` client core for the **advanced Tom Core full-stack
sample** (see
`../../../../../_ai/quests/tom_core/advanced_example_specification_plan.md`).

The authenticated HTTP layer shared by `advanced_app_client` and
`advanced_authadmin_client`. Nothing here imports Flutter, so the JSON↔DTO
parsers are unit-testable headless (no sockets in tests).

## Status

`AuthClient` (step 22) and `AuthorizedHttp` (step 23) implemented. `AppApiClient`
and `AdminApiClient` follow in steps 24–25.

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

## Tests

- `test/auth_client_test.dart` — socket-free unit tests against a fake
  `JsonTransport` (login/refresh/logout sequencing + token storage) plus the
  pure `LoginResult.fromJson` parser against a captured `/auth/login` body.
- `test/authorized_http_test.dart` — socket-free unit tests against a
  path-routing fake transport: bearer injection/merging, and the
  refresh-once-on-401 recovery (exactly one refresh + one retry, the retry
  carrying the fresh token, a persistent 401 surfacing a typed error).
- `test/auth_client_integration_test.dart` — a live login against a running
  `advanced_auth_server` on `localhost:8081`; **skips itself when the server is
  unreachable**.

## Planned contents

- `AuthorizedHttp` — wraps the transport, injects `Authorization: Bearer`,
  refreshes once on a 401, surfaces typed errors.
- `AppApiClient` — typed methods over the app server, pure JSON↔DTO parsers.
- `AdminApiClient` — typed methods over `/admin/*`.

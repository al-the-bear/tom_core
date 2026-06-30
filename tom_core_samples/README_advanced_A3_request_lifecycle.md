# Appendix A3 · A secured request, end to end

*Appendix A3 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

The spine parts each describe one tier in isolation:
[06](README_advanced_06_authentication.md) issues the token,
[07](README_advanced_07_authorization.md) defines the four-state grade,
[10](README_advanced_10_servers_endpoints.md) lists the endpoints, and
[11](README_advanced_11_clients_app_admin.md) wires the client. This appendix
threads them onto **one principal opening one item** and follows the bytes the
whole way: from the keystroke that mints a token, across the second server's
bearer check, through the two authorization layers, back over the wire as a
graded matrix, into the installed adapter, and finally onto the field the user
sees. It is *synthesized* from the endpoint, access, and client-http sources —
a single trace, not a transcription of any one file — so the two headline rules
([server-delivered texts](README_advanced_08_resources_texts.md),
[name-driven authorization](README_advanced_07_authorization.md)) can be watched
acting together on a real request.

The worked request: **`val` (a viewer shared into Alice's board) opens an item
and sees the field grid.** `val` can read most fields, has a *disabled* status
control, and `estimate` is hidden — exactly the TC-30-02 matrix
([Part 12](README_advanced_12_testing_integration.md)). A3 explains *why* the
client renders that, byte by byte.

## The two round-trips at a glance

A secured read is really **two** requests against **two** servers, the first
producing the credential the second consumes:

```
        ┌────────────────────── advanced_auth_server (:8081) ──────────────────────┐
  ①     │  POST /auth/login  (PUBLIC)                                                │
 user ──┼─▶ AuthClient.login ─▶ AuthTokenService.login ─▶ authenticateUser           │
        │      └─ verify password ─▶ issue JWT pair (auth + authz, 2h) ──────────────┼─▶ LoginResult
        └───────────────────────────────────────────────────────────────────────────┘     │
                                                                            ② store token pair
                                                                       (TomBearerAuthentication)
        ┌────────────────────── advanced_app_server (:8080) ───────────────────────┐  │
  ③     │  GET /items/{id}/field-states  (AUTHENTICATED)   Authorization: Bearer ◀──┼──┘
 user ──┼─▶ pipeline verifies JWT ─▶ principal into the request zone                 │
        │   ④ ResourceAccessResolver.resolveRole  (ownership-or-share → ProjectRole) │
        │   ⑤ FieldGradeResolver.resolveItemFieldStates  (role → per-field grade)    │
        │      grants read from `main` datasource ── bound to auth_db ───────────────┼─▶ [GradedFieldDto]
        └───────────────────────────────────────────────────────────────────────────┘     │
                                                                       ⑥ install on adapter,
                                                                          field renders by grade
```

The hinge between the two servers is the **shared JWT signing key**
([Part 06](README_advanced_06_authentication.md)): the app server validates a
token the auth server minted, *offline*, with no callback. The hinge between the
two layers inside the app server is that the grant matrix lives in `auth_db` but
is read by the app server through the framework's `main` datasource
([Part 05](README_advanced_05_persistence_database.md)).

## 1. Login at the auth server → token

The user submits credentials; `AuthClient.login` POSTs them to the **public**
`/auth/login` and, on success, stores the returned token pair
(`advanced_client_core/lib/src/auth/auth_client.dart:68`):

```dart
final response = await _transport.send(
  method: 'POST', uri: _uri('/auth/login'), body: jsonEncode(request.toJson()));
final result = _requireLogin(response, 'auth.login.failed');
_store(result);   // → TomBearerAuthentication.setTokens(authToken, authzToken, …)
```

On the server, `login` is the one app/auth endpoint marked `@TomPublicAccess()` —
it *must* be reachable without a bearer, because it is how a bearer is obtained
(`advanced_auth_server/lib/src/endpoints/auth_endpoints.dart:193-200`). It
delegates to `AuthTokenService.login` (`:59`), which verifies the password
through `AdvancedAuthenticationService.authenticateUser` and then issues the
**pair** of JWTs in `_issueFor` (`:95-121`): a public *authentication* token and
an *authorization* token carrying the encrypted access-control payload, both with
the 2-hour `tokenLifetime` (`:45`). A rejected login throws `LoginException`,
which `LoginUnauthorizedErrorHandler` (`:148`) maps to a bare **401** carrying
only the opaque key — never *which* of username/password was wrong (no
account-existence leak).

The client stores the pair via `_store` → `TomBearerAuthentication.setTokens`
(`auth_client.dart:145`). `decryptTokens` is `false` for this Flutter-free
sample (`:62`): the authorization token is held as an **opaque bearer**, identity
is read from `LoginResult.user`, and field grades come from the app API — so no
RSA key is configured client-side. The bytes that matter downstream are now in
the singleton token store.

> **The two stores are not the same store.** `TomBearerAuthentication` here is
> the **client-side** token holder. The server never populates it; it recovers
> the principal from the request *zone* (§2). Conflating the two is the bug the
> RC-15 green gate caught (zone principal resolution) — see
> [A1](README_advanced_A1_authorization_state_machine.md) and the five-fix note
> in [Part 12](README_advanced_12_testing_integration.md).

## 2. App-server bearer validation

The client now reads an item's field grades. Every app call goes through
`AuthorizedHttp.send`, which injects the stored bearer **fresh on each attempt**
and self-heals a single expiry (`advanced_client_core/lib/src/http/authorized_http.dart:56`):

```dart
final first = await _sendWithBearer(method, uri, headers, body);
if (first.statusCode != 401) return first;
await _authClient.refresh();                    // refresh ONCE
final retry = await _sendWithBearer(method, uri, headers, body);
if (retry.statusCode == 401) throw AuthorizedHttpException(…);   // genuinely dead
```

`_sendWithBearer` re-reads `TomBearerAuthentication.authorizationToken` on every
call (`:82-99`), so the post-refresh retry automatically picks up the freshly
minted token. A single token expiry is therefore invisible to the caller; a
genuinely dead session surfaces as a typed `AuthorizedHttpException` rather than
an infinite loop.

On the server, the target endpoint carries `@TomAuthenticatedAccess()`
(`advanced_app_server/lib/src/endpoints/app_endpoints.dart:1017-1021`). The
pipeline ([Part 10](README_advanced_10_servers_endpoints.md)) validates the JWT
signature against the shared key, decodes the principal, and places it in the
**Dart request zone** *before* the handler runs. The component reads it from
there — never from the client singleton:

```dart
int get _principalId =>
    int.tryParse('${getFromCurrentZone<TomPrincipal>()?.user.id}') ?? -1;   // :981
```

The library doc at `:973-979` is explicit about *why*: the zone value is
request-scoped (safe under concurrency), whereas `TomBearerAuthentication`'s
static singleton is a client-side store the server middleware never fills. If
the bearer is missing or invalid, the pipeline rejects the request *before*
invocation with `endpoint_handler.handle_method_call.access_denied`
(`app_endpoints.dart:904`), which the server-level `appForbiddenOrNotFound`
handler maps to **403** (`:935-939`). Past this point the principal id — `val`'s
auth-user surrogate key — is the only identity the rest of the trace uses.

## 3. Ownership / share resolution

The endpoint delegates to `AppReadService.itemFieldStates(userId, itemId)`
(`app_endpoints.dart:226`), whose **first** act is to resolve *whether `val` may
touch this item at all, and as what role* — the app server's first authorization
layer, `ResourceAccessResolver.resolveRole`
(`advanced_app_server/lib/src/access/resource_access_resolver.dart:115`):

1. **Build the containment chain.** `_ancestry` walks parent foreign keys
   `item → list → project → workspace`, with the target itself always first so a
   direct share still matches even if a parent link is broken (`:147-157`).
2. **Ownership short-circuits.** If the chain reaches a workspace and its
   `ownerId == userId`, the principal is `ProjectRole.owner` — the strongest
   role, done (`:125-128`). `val` does **not** own Alice's workspace, so this
   misses.
3. **Strongest share wins.** Otherwise the resolver scans `val`'s shares and
   keeps the **strongest** whose `(resourceType, resourceId)` covers the target
   *or any ancestor* — a share on the project covers its lists and items
   (`:131-139`; `ProjectRole` is declared strongest-first, so the lowest index
   wins). `val` was shared in as `viewer`, so `best == ProjectRole.viewer`.
4. **No match → `null`.** With neither ownership nor a covering share the result
   is `null` = **no access**.

For our request the resolver returns `ProjectRole.viewer`. Had it returned
`null`, `itemFieldStates` throws `app.item.not_found` (`:232-237`) — **404**, not
403: a resource the caller cannot reach is reported *missing*, never leaking that
it exists ([A1](README_advanced_A1_authorization_state_machine.md), closed-safe).

## 4. Field-grade computation

The resolved **role** is now mapped to a **per-field grade** — the second
authorization layer, `FieldGradeResolver.resolveItemFieldStates(role)`
(`advanced_app_server/lib/src/access/field_grade_resolver.dart:73`):

```dart
final graded = await gradesForRole(role);    // load the role's grant rows, fold them
return {
  for (final key in TodoItemResourceKeys.all) key: graded.resolveState(key),
};
```

Three facts make this layer the load-bearing one:

- **The grants are data in `auth_db`.** The grade matrix is the
  `tom_resource_grant` table owned by the auth server; the app server reaches it
  through the framework's `main` datasource, which the app boot binds to the
  shared `auth_db` connection (`:30-39`,
  [Part 05](README_advanced_05_persistence_database.md)). This is why an admin's
  grant edit on the auth server is visible to the app server with no extra wiring
  — the cross-tier scenario in [Part 12](README_advanced_12_testing_integration.md)
  asserts exactly this.
- **Folding reuses the framework verbatim.** `gradesForRole` defers to
  `TomGradedAccessControlInformation.fromGrants` (`:65`) — the *same* projection
  the auth server's admin API uses — so the two tiers agree on grade semantics
  (a key granted twice widens to the most permissive,
  [A1](README_advanced_A1_authorization_state_machine.md)).
- **Absence is `none`.** Every key in `TodoItemResourceKeys.all` is resolved; a
  field with **no** grant row degrades to `TomAuthState.none` (hidden) — the
  closed-safe default (`:73-80`).

For the `viewer` role the seeded matrix yields: `title`/`description`/`priority`/
`assigneeId`/`dueDate` → `read`, `status` → `disabled`, `estimate` → `none`. That
map — keyed by `todo.item.<field>`
([A2](README_advanced_A2_resource_scope_conventions.md)) — is the entire payload.

## 5. Graded DTO over the wire

`itemFieldStates` projects the grade map into the wire shape, one
`GradedFieldDto` per gradable field in display order
(`app_endpoints.dart:239-242`):

```dart
return [
  for (final entry in states.entries)
    GradedFieldDto(resourceKey: entry.key, access: entry.value),
];
```

The endpoint pipeline serializes that as a **bare JSON array** of
`{resourceKey, access}` maps (no envelope) — `appItemFieldStates`,
`GET /items/{id}/field-states` (`:1017-1021`). On the client, `AppApiClient.itemFieldStates`
re-reads it with the pure `parseFieldStates` parser
(`advanced_client_core/lib/src/api/app_api_client.dart:246`,`:145`):

```dart
List<GradedFieldDto> parseFieldStates(List<Object?> body) =>
    [for (final e in body) GradedFieldDto.fromJson(_asObjectMap(e))];
```

The wire codec carries the **same closed-safe default** the server resolver and
the client adapter use: an unrecognised `access` token decodes to
`TomAuthState.none` via `GradedFieldDto.fromJson` (`app_api_client.dart:142-146`).
So a corrupt or unknown grade fails *hidden*, not *open* — the third independent
`none`-defaulting point [A1](README_advanced_A1_authorization_state_machine.md)
enumerates.

## 6. Client field rendering

The parsed matrix flows up through the backend seam and into the installed
adapter. `LiveAppBackend.itemFieldStates`
(`advanced_app_client/lib/backend/live_app_backend.dart:84`) returns it to
`AppSession.loadFieldStates`
(`advanced_app_client/lib/app/app_session.dart:149`), which stores it as the
current matrix **and pushes it into the adapter** the form resolves against
(`:160-163`):

```dart
void _setFieldStates(Map<String, TomAuthState> states) {
  _currentFieldStates = states;
  authorizationAdapter.states = states;   // the form now resolves grades for THIS item
}
```

That adapter was installed **once** at startup —
`TomAuthorization.adapter = session.authorizationAdapter`
(`advanced_app_client/lib/main.dart:42`). From here the form takes over: each
`TodoItemForm` field self-addresses as `todo.item.<field>`
([A2](README_advanced_A2_resource_scope_conventions.md)) and runs
`resolveEffectiveAuth`, whose layer-1 lookup is
`TomAuthorization.resolveAuth(basePath)` — answered by the adapter we just fed
([A1](README_advanced_A1_authorization_state_machine.md)). The four states paint
the widget:

| Field | `val`'s grade | Renders as |
| --- | --- | --- |
| `title`, `description`, `priority`, `assigneeId`, `dueDate` | `read` | visible, read-only |
| `status` | `disabled` | visible, greyed, non-interactive |
| `estimate` | `none` | absent — the field collapses |

No Save button (a viewer is below `editor`), and every label resolved from the
server bundle keyed by the *same* `basePath`
([Part 08](README_advanced_08_resources_texts.md)) — the two headline rules
acting on one screen. The form holds **no** authorization state of its own; swap
the principal and the *same* widget renders Alice's full editor purely because a
different matrix was installed (the TC-30 matrix proof,
[Part 12](README_advanced_12_testing_integration.md)).

## The write path: the server is the backstop

The read trace ends at a rendered grid; a **write** adds one more enforcement
point that proves the grades are not merely cosmetic. When `val` (or a more
privileged `bob`) saves, `AppApiClient.updateItem` PUTs the item
(`app_api_client.dart:229`) and the server re-runs *both* layers, then enforces
the grade a second time in `AppWriteService.updateItem`
(`app_endpoints.dart:564`) via `_enforceFieldWrites` (`:663`):

```dart
for (final field in _gradableItemFields) {
  final changed = field.read(incoming) != field.read(baseline);
  if (changed && grades[field.resourceKey] != TomAuthState.full) {
    throw TomEndpointHandlerException('app.item.field_forbidden', …);   // → 403
  }
}
```

A change to any field the caller is not `full` on rejects the **whole** write,
and the persisted row overlays *only* the `full`-graded fields (`:677-683`). A
well-behaved client never sends a field its grade hides, so this never fires for
the app client — but it is the backstop for a client that ignores its grade.
**Authorization is enforced where the data lives, not only where it is drawn**
— the client grade is a UX convenience; the server grade is the guarantee
([A1](README_advanced_A1_authorization_state_machine.md), TC-30-03).

## The same loop, executed live

This whole trace is exactly what the cross-tier integration runner drives
end-to-end against a freshly booted stack — `advanced_client_core/tool/run_cross_tier_integration.sh`
+ `cross_tier_integration_test.dart` (TC-37-01,
[Part 12](README_advanced_12_testing_integration.md)). Its first scenario walks
§1–§6 with a real grade edit in between: the `admin` edits the `viewer` role's
`todo.item.title` grant through the auth server (§4's grant rows), and a seeded
`viewer` then re-reads the item's field states from the *app* server and sees the
new grade — proving the `main`→`auth_db` binding of §4 carries an admin write all
the way to a rendered field. The runner exiting `0` ("All tests passed!") is the
live proof that this appendix's six steps hold against sockets, not just on paper.

## Primary sources

- `advanced_client_core/lib/src/auth/auth_client.dart:68`,`:145`;
  `advanced_client_core/lib/src/http/authorized_http.dart:56`,`:82-99`
- `advanced_auth_server/lib/src/endpoints/auth_endpoints.dart:59`,`:95-121`,`:193-200`,`:148`
- `advanced_app_server/lib/src/endpoints/app_endpoints.dart:226`,`:564`,`:663`,`:904`,`:981`,`:1017-1021`
- `advanced_app_server/lib/src/access/resource_access_resolver.dart:115`,`:147`;
  `advanced_app_server/lib/src/access/field_grade_resolver.dart:65`,`:73`
- `advanced_client_core/lib/src/api/app_api_client.dart:145`,`:229`,`:246`;
  `advanced_app_client/lib/app/app_session.dart:149`,`:160`; `advanced_app_client/lib/main.dart:42`
- `advanced_example_specification_plan.md` — A.5, A.6, Phase 7;
  `run_cross_tier_integration.sh` (the same loop, executed live)
- Companions: [06](README_advanced_06_authentication.md) ·
  [07](README_advanced_07_authorization.md) ·
  [10](README_advanced_10_servers_endpoints.md) ·
  [A1](README_advanced_A1_authorization_state_machine.md) ·
  [A2](README_advanced_A2_resource_scope_conventions.md)

---

← Prev: [A2 · Scope, basePath & resource-key conventions](README_advanced_A2_resource_scope_conventions.md) · Next: [A4 · Implementation-rules cheat-sheet](README_advanced_A4_implementation_rules_checklist.md) →

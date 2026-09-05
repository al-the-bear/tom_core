# Servers & the secured endpoint pipeline

*Part 10 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

[Part 06](README_advanced_06_authentication.md) showed how a login mints a signed
token pair and [Part 07](README_advanced_07_authorization.md) how the four-state
grade matrix is computed. This part is where those two meet the wire: how the two
servers turn an HTTP request into an authenticated, authorized method call. We
look at the endpoint pipeline and its access annotations, the bearer check that
runs on every request, the resource/field authorization the handlers add on top,
the framework file endpoint both servers mount, the health probe, and the boot
order that has to be right for any of it to work.
The blow-by-blow trace of a single request is deferred to
[Appendix A3](README_advanced_A3_request_lifecycle.md); here we map the moving
parts.

Two servers, one model. `advanced_auth_server` (port **8081**, `auth_db` on
3307) serves `/auth/*` and `/admin/*`; `advanced_app_server` (port **8080**,
`app_db` on 3308) serves the todo board. They are separate `TomServer` boots that
trust each other only through a **shared JWT signing configuration** — neither
calls the other, but a token minted by one verifies in the other because both
install the identical keys (see [Boot order](#server-boot-order) below).

## The endpoint pipeline and annotations

The wire contract is declared once, in `advanced_todo_contracts`, as plain
`TomApi`/`TomApiEndpoint` values — URI, HTTP method, request/response types — so
it stays Flutter- and server-free and the client core can consume the very same
definitions (`api_registry.dart` — `authApi`, `adminApi`, `appApi`). Because
`TomApiEndpoint`
carries no server annotations, each server **re-declares** an implementing class
against that registry. The implementation is a `@tomComponent` the bean container
instantiates, and each method is bound to its registry endpoint by
`@TomApiEndpointImplementation(apiId:, endpointId:)`:

```dart
@tomReflector
@tomComponent
@TomApiImplementation(apiId: 'app')
class AdvancedAppApiService implements AppApiService {
  // No inline access annotation: the endpoint's access policy is declared on
  // the contract (`appApi['appListItems'].access`) and extracted by the pipeline.
  @TomApiEndpointImplementation(apiId: 'app', endpointId: 'appListItems')
  @override
  Future<List<TodoItem>> listItems(String listId) =>
      _reads.listItems(_principalId, int.tryParse(listId) ?? -1);
}
```
*(`app_endpoints.dart`)*

The pipeline routes an incoming URI to the endpoint, deserializes the request
body/path parameters into the declared types, invokes the bound method, and
serializes the result. The endpoint's **contract-declared** access policy
(`TomApiEndpoint.access`, extracted by the pipeline on first call) is the gate it
enforces **before** the method runs; a handler-side `TomAccessControl` annotation
would be a local override, but the advanced servers declare none.

The three access policies the sample uses, all from the kernel's
`TomAccessControl` family:

| Access policy | Meaning | Where declared |
| ------------- | ------- | -------------- |
| `TomPublicAccess()` | No token required | the six pre-session `/auth/*` endpoints — `authLogin`, `authSecondFactor`, `authBeginEnrolment`, `authConfirmEnrolment`, `authSkipEnrolment`, `authLoginResources` — and `appHealth` |
| `TomAuthenticatedAccess()` | Any valid bearer principal | every other `/auth/*` and every `/app` endpoint |
| `TomRoleAccess(['admin'])` | A principal carrying the `admin` role | every `/admin/*` endpoint |

## Per-endpoint access policies

The access policy is **declared on the contract**, directly on each endpoint's
`TomApiEndpoint.access` value (G-API-3). There is no separate policy source and
no companion `*ApiAccess` map: each `TomApiEndpoint` in the registry names its
own four-state access (`api_registry.dart`), the server pipeline **extracts that
declaration on first call** and gates against it, and the client core reads the
same `endpoint.access` to decide whether to attach a token. A handler *may*
still carry an inline `TomAccessControl` annotation as a **local override**
(`tea ?? ae.access` in the pipeline), but the advanced servers declare nothing
inline — the contract is the single source of truth (C-12, the full form of
G-API-3).

The three surfaces gate at different granularities:

- **`/auth/*` — mostly public-then-authenticated.** `authLogin`,
  `authSecondFactor`, the three enrolment passes (`authBeginEnrolment`,
  `authConfirmEnrolment`, `authSkipEnrolment`) and `authLoginResources` declare
  `TomPublicAccess()` (you cannot require a token to log in, to settle a factor
  the login is still offering, or to fetch the pre-login screen texts);
  `authRefresh`, `authLogout`, `authMe` declare `TomAuthenticatedAccess()`
  (`api_registry.dart`, `authApi`). `authSecondFactor` additionally sets
  `includeBearerAuthentication: false`: it completes a login whose interim
  principal is by construction *not* authenticated, so it takes the challenge
  token in its body — see part
  [06](README_advanced_06_authentication.md#two-factor-login-the-second-pass).
- **`/admin/*` — uniformly role-gated.** Every one of the sixteen admin endpoints
  declares the shared `adminAccess` (`TomRoleAccess(['admin'])`) constant
  (`api_registry.dart`, `adminApi`). A
  signed-in **non-admin** authenticates fine but is refused here — the pipeline
  throws the access-denied exception before the method body runs. This is exactly
  what the admin client's two-phase login probes against (see
  [Part 11](README_advanced_11_clients_app_admin.md)).
- **`/app` — authenticated blanket, then in-handler authorization.** Every board
  endpoint but `appHealth` declares `TomAuthenticatedAccess()`. The blanket level
  only proves *who* you are; **what** you may see and write is decided inside the
  handler by the resource- and field-level checks below
  (`api_registry.dart`, `appApi`).

When the pre-invocation check denies, the pipeline throws a
`TomEndpointHandlerException` keyed
`endpoint_handler.handle_method_call.access_denied` — and it throws it **outside**
the per-endpoint `try/catch`, so only a *server-level* error handler can see it.
Both servers install one that maps exactly that key to **403 Forbidden** and
returns `null` for everything else, composing it over the framework default so
genuine faults still get the standard JSON error (`forbiddenOnAccessDenied`,
`admin_endpoints.dart`; `authServerErrorHandler`, `auth_server_start.dart`;
`appForbiddenOrNotFound`, `app_endpoints.dart`).

A throw raised *inside* a handler goes somewhere else entirely, and the two are
not interchangeable. The pipeline catches it in the per-endpoint `try/catch` and
hands it to the endpoint's **own** error handler — which defaults to
`TomDefaultErrorHandler`, an opaque 500 — so the server-level handler never sees
it. Both servers therefore declare a per-endpoint handler on their
`@TomApiImplementation` (`AdminEndpointErrorHandler`, `AppEndpointErrorHandler`)
for the in-method rejections, alongside the server-level one for the
pre-invocation check.

The clearest case is a **malformed id**. Both persistence mappings reject a
display-id that is neither empty nor an integer with a `MalformedIdException`
(declared in `advanced_todo_contracts`, beside the `malformedIdKey` it is
reported under). That is the caller's mistake, so the per-endpoint handler maps
it to **400** with body `{"error": "request.id.malformed"}` rather than letting
it become a 500 — for instance a group create whose `memberUserIds` names
something that is not a persisted user key. It is matched as that *subtype*, not
as a bare `FormatException`: a malformed resource-bundle asset raises one of
those too, and that one really is a 500. Because this only holds if the handler
survives reflection generation, the live suite asserts it over a real socket
(`TC-25-15` in `admin_api_client_integration_test.dart`).

## Bearer validation on every request

Neither server sets `authenticationMiddleware` on its configuration, so
`TomServer.start()` installs the framework default,
`tomDefaultAuthenticationMiddleware`. It reads the request's bearer token, builds
the `TomPrincipal`, and places it in the per-request **Dart zone** — which is what
both the contract-declared `TomAuthenticatedAccess`/`TomRoleAccess` checks and
the handlers read from (the library doc comment on `auth_server_start.dart`).

A handler that needs the caller's id reads it from the zone, **not** from the
`TomBearerAuthentication` static singleton:

```dart
int get _principalId =>
    int.tryParse('${getFromCurrentZone<TomPrincipal>()?.user.id}') ?? -1;
```
*(`AdvancedAppApiService._principalId`, `app_endpoints.dart`)*

The comment there is load-bearing and worth repeating: `TomBearerAuthentication`'s
static singleton is a **client-side** token store the server middleware never
populates, and it is not request-scoped — using it on a server handling
concurrent requests would be unsafe. The zone value is the correct, per-request
source.

## Ownership + share resolution

The `/app` blanket `TomAuthenticatedAccess` proves identity; the board's real
authorization is two resolvers the handlers consult per call (introduced in
[Part 07](README_advanced_07_authorization.md), here seen at the wire):

- **`ResourceRoleResolver`** — maps `(userId, resourceType, resourceId)` to an
  *effective* `ProjectRole`, or `null` for no access. It resolves the principal's
  flat effective-role map through the framework `TomDelegationResolver` — the C-5
  ownership grants and C-6 `share`-mode `TomPrincipalDelegation` rows
 , strongest role wins — then keeps the strongest role over the target's
  containment chain, climbing item → list → project → workspace. Every list
  endpoint filters each candidate row through it and drops the invisible ones
  (`AppReadService._filterByVisibility`, `app_endpoints.dart`); `null` means the
  resource is simply not in the response.
- **`FieldGradeResolver`** — maps a resolved `ProjectRole` to the per-field
  `TomAuthState` matrix from the `tom_resource_grant` table (in `auth_db`, via the
  `main` datasource). It is used on the **WRITE path** to enforce per-field grades
  (`_enforceFieldWrites`, below); it no longer serves any read. The app read
  endpoints hand the client a flat `resourceRoles` map (`GET /resource-roles`),
  from which the client grades fields locally.

Writes enforce both layers. Six mutations require a **minimum role**
(`createProject`/`createItem` need `editor` on the parent, `deleteItem` `editor`
on the item, `addSubtask`/`updateSubtask` `editor` on the parent item, and
`addComment` `commenter`), and item writes enforce the **field grade**: every
gradable field
the payload *changes* must be graded `full` for the caller, or the whole write is
rejected with `app.item.field_forbidden`; the persisted row overlays only the
permitted fields, so server-owned columns and non-`full` fields keep their stored
value (`AppWriteService._enforceFieldWrites`, `app_endpoints.dart`). Sharing is
**owner-only** — only an `owner` of the target may create or revoke a
`share`-mode `TomPrincipalDelegation`, and a new share takes effect immediately
because the resolver reads the delegation rows on the grantee's next request
(`AppShareService`, `app_endpoints.dart`).

The denials are **closed/safe**: a resource the caller cannot reach is reported as
*not found* (404, `app.item.not_found` / `app.share.not_found`), never as
forbidden — so existence is not leaked — while a genuine permission refusal is
403 (`app.access.forbidden` / `app.item.field_forbidden`). The server-level
`appForbiddenOrNotFound` maps those keys.

## The file endpoint

File transfer does not go through the contract registry at all. Both servers
mount the framework's own `TomFileService`, whose single method answers
`POST`/`PUT`/`GET`/`HEAD`/`DELETE` on **`/files/{entity}/{id}/{column}`** — one
handler for all five verbs, because the wire contract addresses one resource and
varies only the method. Each server publishes its slots with **one line** at boot:

```dart
TomFileSlots.register(itemRepository);   // app server  → app_items
TomFileSlots.register(userRepository);   // auth server → auth_users
```

Everything else is read off the entity's own annotations: the table name from
`@TomDbTable`, the column name from `@TomDbColumn`, the store and lifecycle from
`@TomFileReference`. There is no second copy of those facts to drift, and a
renamed column moves its slot rather than breaking one. `TomFileService` needs
**no bean** — it is a `@tomService` like any other and the router constructs its
`@tomComponent` implementation (`TomFileServer`) when it mounts the pipeline.

The published slots are exactly the **exposed** file columns (part
[05](README_advanced_05_persistence_database.md#file-columns--the-blob-stores)):

| Slot | Verbs | Backed by |
| --- | --- | --- |
| `app_items/{id}/attachment` | POST · PUT · GET · HEAD · DELETE | `app_db`, the app server's `files` store |
| `auth_users/{id}/avatar_ref` | POST · PUT · GET · HEAD · DELETE | `auth_db`, the auth server's `files` store |

`app_items/{id}/internal_note` is **not** in that table: it is a
`@TomFileReference` column of the same row that never said `exposed: true`, so no
slot is published for it. A request naming it is a plain **404** — the same answer
a column that does not exist gets. That is deliberate: a 403 would confirm the
column is there, exactly as the app services report an out-of-scope row as *not
found* rather than *forbidden*.

**Four checks, in order, and each answers a different question.** A file is not a
side door into the C-grade model:

1. **The gate** — `TomFileService.file` declares `TomAuthenticatedAccess()`, so an
   anonymous caller never reaches a slot. This one has to be the endpoint's own:
   the three below are all principal-*relative*, and a request with no principal
   gives them nothing to decide. `auth_users` declares no `@TomDbScope`, so
   without the gate its avatar column would be readable by anyone who guessed the
   URL. (An application that genuinely wants anonymous files declares its own
   `TomFileService` component with a different policy — a handler-side annotation
   is a local override, G-API-3.)
2. **Exposure** — is this column published at all? Default-closed, per column.
3. **Row scope (C-3)** — may *this* principal have this row? The app's
   `@TomDbScope`d entities filter the row away, and an unreachable row is a 404.
4. **Column grade (C-4)** — may this principal read/write *this field*? A column
   graded below `full` answers **403**
   (`column_authorization.{read,write}.field_forbidden`), because here the
   caller's right to the row is not in question.

Check 4 is where the app server's attachment stops being merely authenticated and
becomes **authorized**. `@TomDbColumn(authKey: itemAttachmentGradeKey)` names the
grade, and boot registers a *per-row* resolver for that key
(`registerAppColumnGrades` → `TomRowColumnAuthorization`), because the grade is
both per request and per row: alice may replace the attachment on an item she owns
and only download the one in a project shared with her as a viewer. The resolver
is the app server's existing two layers composed — the caller's `ProjectRole` on
`item:<id>`, then that role's grade for `todo.item.attachment` in the seeded
`tom_resource_grant` matrix — so an administrator narrowing that one cell changes
what an owner may do with a *file*, through the same console and API that already
govern the item's form fields. Without the `authKey` the column would fall back to
the process-global `TomAuthorization`, which answers `full` for everyone when no
adapter is installed. Part [13](README_advanced_13_file_transfer.md) follows the
whole path.

Uploads stream. The endpoint declares `consumes: octet-stream` precisely so the
pipeline does **not** materialise the body — it reads a request into a string only
for a JSON endpoint — and downloads stream back the same way, so a large file
never sits whole in server memory.

## Health check

Two distinct probes, deliberately on different paths:

- **`GET /health`** — the framework's `TomHealthService` auto-mounts a plain-text
  liveness probe in *every* server. Nothing in the sample declares it; it is
  there for free.
- **`GET /status`** — the app's own typed JSON status (`{status, service}`),
  declared `appHealth` with contract-declared `TomPublicAccess()`
  (`TomApiEndpoint.access`) so an unauthenticated
  load balancer can poll it (`api_registry.dart`, `appApi`).

`appHealth` uses `/status` rather than `/health` *because* the framework already
owns `/health` — an app `/health` would be shadowed by the auto-mounted probe.
The registry comment records exactly this (`api_registry.dart`, the `appHealth`
endpoint).

## Server boot order

Both `bin/*_server_start.dart` follow the same sequence, and the order is not
incidental — each step depends on the prior ones being in place:

```
platform → registry → reflection → runtime → config → JWT signing → datasource →
blob stores → bean context → migrations → [seed] → file slots → TomServer.start()
```

Reading `main` in `auth_server_start.dart` (the app server's `main` is identical
bar the demo-password seed):

| Step | Call | Why here |
| ---- | ---- | -------- |
| platform | `setCurrentPlatform(standalonePlatformUtils)` | establishes the standalone runtime before anything reads it |
| registry | `registerAdvancedTodoApis()` | the endpoint router needs the API definitions to resolve URIs |
| issuer | `globalSettingJwtOrganization = 'tom'` | the issuer the token is signed with; **the app server must set the same value** |
| reflection | `initializeReflection()` | populates the reflected shapes the config, records and components use |
| runtime | `initializeRuntime(args)` | resolves the active environment (`prod`/`dev`) from `selectedRuntimeEnvironmentName` — command line, then `.env`, then the OS environment, the same three sources the configuration merge reads |
| config | `AuthServerConfiguration(args)` | merges YAML/env/args; sets port, error handler |
| JWT signing | `installJwtSigning(configuration)` | builds the signing configuration from the three `jwt*` configuration fields — **identical on both servers**, which is what lets the app server verify a token the auth server minted. It sits **immediately after the config and before any datasource**, because outside a development environment it *refuses* the bundled keys: a refusal is only useful if it arrives before the boot has opened database connections and run their migrations |
| datasource | `initializeDatasourceInfo(...)` | opens the DB connections the repositories and migrations use |
| blob stores | `initializeBlobStores(...)` | **must follow the datasource init** — a `type: database` store resolves its named data source eagerly, so a store pointing at an unregistered name fails at start-up rather than at the first upload |
| bean context | `initializeBeanContext()` | instantiates the `@tomComponent` services |
| migrations | `migrateDatabases(...)` | brings the schema + seed data up before serving |
| seed | `seedDemoPasswords()` *(auth only)* | fills demo passwords onto the password-less seed rows so the README `curl`s can log in |
| access registries *(app only)* | `registerAppDataScopes()`, `registerAppColumnGrades()` | installs the C-3 row scopes and the per-row C-4 column grades; both eagerly build their production resolvers, so both **must follow reflection and the datasource init** |
| file slots | `TomFileSlots.register(...)` | publishes the exposed file columns; needs reflection and the store registry in place, and must precede serving |
| serve | `TomServer.start()` | binds the socket; installs the default auth middleware |

The cross-server trust hinges on two of these matching exactly: the **issuer**
(`globalSettingJwtOrganization = 'tom'`) and the **JWT signing configuration**.
Both boots call the framework's `installJwtSigning(configuration)`, which reads
`jwtSharedSecretKey`, `jwtRsaPrivKey` and `jwtRsaPubKey` off the merged
configuration. Neither sample sets them, so both fall back to the framework's
bundled sample keys — and *that* is what makes a token issued at 8081 verify at
8080. Set `JWT_SHARED_SECRET_KEY` in both servers' `.env` and the same trust
rests on a secret you chose; set it in one only and the app server rejects the
auth server's tokens. The fallback is refused outright outside a development or
test environment (see part 06), which is why both boots are given `env=dev`.

## The secured request lifecycle (summary)

Putting it together, a single authenticated board request flows:

1. **Route** — the pipeline matches the URI/method to the endpoint and
   deserializes the request.
2. **Authenticate** — `tomDefaultAuthenticationMiddleware` reads the bearer token
   and places the `TomPrincipal` in the request zone.
3. **Gate** — the endpoint's contract-declared access policy
   (`TomApiEndpoint.access`, extracted by the pipeline) runs *before* the body:
   `TomAuthenticatedAccess` requires a principal, `TomRoleAccess(['admin'])`
   requires the role. A denial throws the access-denied key (→ server handler →
   403).
4. **Authorize** — inside the handler, `ResourceRoleResolver` filters
   visibility and `FieldGradeResolver` (plus `_enforceFieldWrites` on writes)
   enforce the four-state grade. Unreachable → 404; refused → 403.
5. **Respond** — the result is serialized; service-thrown
   `TomEndpointHandlerException` keys are mapped to HTTP by the server-level
   handler, everything else by the framework default.

The full step-by-step trace with the exact frames is in
[Appendix A3](README_advanced_A3_request_lifecycle.md).

## Primary sources

- [`advanced_app_server/README.md`](advanced_app_server/README.md), [`advanced_auth_server/README.md`](advanced_auth_server/README.md)
- `advanced_app_server/lib/src/endpoints/app_endpoints.dart`; `advanced_auth_server/lib/src/endpoints/{auth,admin}_endpoints.dart`
- `advanced_todo_contracts/lib/src/api_registry.dart`
- `advanced_*_server/bin/*_server_start.dart`
- `tom_core_server/doc/endpoints.md`; appendix [A3](README_advanced_A3_request_lifecycle.md)

---

← Prev: [09 · Forms & UI](README_advanced_09_forms_ui.md) · Next: [11 · The two Flutter clients](README_advanced_11_clients_app_admin.md) →

# advanced_openapi_client

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These sample projects are BSD-3-Clause licensed and internal (`publish_to: none`).

Typed Dart clients for the **advanced Tom Core full-stack sample** (see
[`../README_advanced_sample.md`](../README_advanced_sample.md)), **generated**
from the OpenAPI documents its two HTTP servers publish. `AppApi` calls
`advanced_app_server`; `AuthApi` calls `advanced_auth_server`.

The generated code depends on `package:http` and nothing else — no Tom package,
no reflection, not `advanced_todo_contracts`. That is the point of the package:
it shows the system called from code that shares nothing with it, which is the
position of every caller that is not a Tom client. The hand-written
[`advanced_client_core`](../advanced_client_core/README.md) is the other way to
call the same servers, through the shared contracts and the registry.

**There is no `example/` directory and no `doc/` folder.** Both libraries are
generated, so the runnable demonstration is the live suite,
`test/generated_client_integration_test.dart`, and a sample has no consumers
who need its surface mirrored — see [the suite map](../README.md) for that
decision, which is the same for all sixteen sample packages.
[The family's index](../README_advanced_sample.md#the-nine-packages) says which
of the nine carry an `example/`, and why.

## How the clients are made

```text
endpoint annotations + reflection seed          (each server)
        │  dart run tool/openapi.dart :document
        ▼
advanced_app_server/openapi/openapi.json        committed; served at GET /openapi.json
advanced_auth_server/openapi/openapi.json
        │  dart run tom_core_openapi:openapi :dart-client
        ▼
lib/app_api.dart, lib/auth_api.dart              committed; this package
```

Each link of the chain is held by a test. Each server's
`test/openapi_document_test.dart` requires its committed document to be what its
endpoint annotations generate today and to validate against the OpenAPI 3.1
meta-schema. This package's `test/generated_client_freshness_test.dart` requires
each committed client to be what its committed document generates. So a change
to a server's API fails a suite until the document and the client are
regenerated, and the regeneration shows up as a diff.

To regenerate, from this package's directory — the command is also in each
generated file's header:

```sh
dart run tom_core_openapi:openapi :dart-client \
    --input ../advanced_app_server/openapi/openapi.json \
    --output lib/app_api.dart --client-name AppApi
dart run tom_core_openapi:openapi :dart-client \
    --input ../advanced_auth_server/openapi/openapi.json \
    --output lib/auth_api.dart --client-name AuthApi
```

## What a generated library holds

| Part | In `app_api.dart` / `auth_api.dart` |
| ---- | ----------------------------------- |
| The client | `AppApi` / `AuthApi`: `(Uri baseUri, {http.Client? httpClient, String? bearerToken})`, a mutable `bearerToken`, `close()`, and one method per operation of the document — the server's own endpoints and the framework's (health, preferences, OAuth, SCIM, `GET /openapi.json`) |
| The models | one class per object schema — the sample's DTOs and entities (`Workspace`, `Project`, `TodoItem`, `LoginRequest`, `LoginResult`, `UserDto`, …) and the framework's (`TomAuthenticationResult`, `TomUserPreferenceDto`, `TomError`, …) — each with `fromJson` / `toJson` |
| The failure | `AppApiException` / `AuthApiException`, carrying `statusCode`, `body` and the framework envelope's `errorKey` |

Each method is named after the operation's `operationId` — the endpoint id in
the contracts registry, such as `appListWorkspaces` or `authLogin` — and takes
its path and query parameters as named arguments and its JSON body as `body`.
A typed response is decoded; an endpoint answering with no body returns
`Future<void>`; an untyped one returns the raw `http.Response`. The bearer token
is sent only to operations the document marks as secured.

```dart
import 'package:advanced_openapi_client/app_api.dart';
import 'package:advanced_openapi_client/auth_api.dart' as auth;

Future<void> main() async {
  final authApi = auth.AuthApi(Uri.parse('http://localhost:8081'));
  final login = await authApi.authLogin(
    body: auth.LoginRequest(
      username: 'alice',
      password: 'alice-pass',
      app: '',
      org: '',
    ),
  );
  authApi.close();

  final app = AppApi(
    Uri.parse('http://localhost:8080'),
    bearerToken: login.authzToken,
  );
  final workspaces = await app.appListWorkspaces();
  final projects = await app.appListProjects(workspaceId: workspaces.first.id);
  print('${workspaces.length} workspaces, ${projects.length} projects');
  app.close();
}
```

The two libraries are imported with a prefix on one side because both declare
the framework models both servers expose (`TomError`, `ResourceBundleDto`, …):
each document carries its own copy, so each client does too.

## Tests

| Suite | Needs | Pins |
| ----- | ----- | ---- |
| `test/generated_client_freshness_test.dart` | nothing | each committed client equals what the committed document generates, formatted |
| `test/generated_client_integration_test.dart` | both servers running | OC-1 a login through `AuthApi`; OC-2 health, workspaces and projects through `AppApi` with that token; OC-3 a workspace created and deleted through the generated models; OC-4 a call without a token refused with the bare `404` the document states, and no `errorKey`; OC-5 each server serving, at `GET /openapi.json`, exactly the committed document its client was generated from |

```sh
dart test test/generated_client_freshness_test.dart
```

The integration suite skips every test when no server is reachable, so on its
own it proves nothing. It runs live from the cross-tier runner, which boots both
databases and both servers, runs it with the other live suites, and counts a
skip as a failure:

```sh
../advanced_client_core/tool/run_cross_tier_integration.sh
```

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `http` | runtime | the generated clients' only dependency |
| `tom_core_openapi` | dev | regenerating the clients, and the freshness test |
| `test` | dev | the two suites |
| `lints` | dev | the analysis options |

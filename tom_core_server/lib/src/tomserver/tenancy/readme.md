# tenancy

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Multi-tenancy for a Tom server. A **tenant** is an isolation boundary — whose
data a query reads, which schema or database a connection reaches, whose cache
entries and jobs these are. It is not the **organization**, a business unit
inside a tenant; the framework never infers one from the other.

Each tenant's data lives in the shared database, in a schema of its own, or in a
database of its own, chosen **per tenant**. All three are reached through one
seam — a repository asks for its data source, and the installed tenancy answers
with the current tenant's — so application code is the same under every model.
A request's tenant comes from its token's `tenant` claim, which is
authoritative, or, before login, from its host, a segment of its path or a
header.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomTenancy` | The deployment's tenants and their routing. `install` provisions each tenant's schema or database and routes data-source lookups; `runFor` / `forEachTenant` run work inside a tenant; `resolveRequest` names a request's tenant or the rejection to answer it with; `addTenant` onboards without a restart, and `removeTenant` withdraws a tenant, closing the data sources opened for it. |
| `TomTenant` · `TomTenantIsolation` | One tenant, and where its data lives: `shared`, `schema` or `database`. |
| `TomTenantResolver` · `TomTenantHostResolver` · `TomTenantPathResolver` · `TomTenantHeaderResolver` | How a request without a token claim names its tenant: by subdomain or own host, by the path segment after a prefix (`/t/<segment>`, mapped to a tenant id when a lookup is given), or by the `X-Tenant-Id` header. |
| `TomTenantResolution` | A tenant, none, or a rejection with its HTTP status and key. |
| `TomTenancyException` | Every refusal the module raises — `tenancy.config.*` and `tenancy.tenant.unknown`. |

## Quick start

```dart
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final tenancy = TomTenancy(
    tenants: [TomTenant('acme'), TomTenant('globex')],
    resolvers: const [TomTenantHostResolver(suffix: 'app.example.com')],
  );
  await TomTenancy.install(tenancy);

  final request = Request('GET', Uri.parse('https://acme.app.example.com/'));
  print(tenancy.resolveRequest(request).tenant); // acme

  // A token for acme naming globex through the host is refused.
  final other = Request('GET', Uri.parse('https://globex.app.example.com/'));
  print(tenancy.resolveRequest(other, claim: 'acme').status); // 403

  await tenancy.runFor('globex', () async {
    print(TomTenantContext.currentId); // globex
  });

  await TomTenancy.reset();
}
```

See [`doc/tenancy.md`](../../../../doc/tenancy.md) for the isolation models, the
configuration, request resolution, what is tenant-scoped and what stays
deployment-wide, and
`example/tenancy/tenancy_example.dart` for two tenants walked through
resolution, token binding, caches, revocations, jobs and the outbox, checking
its own results. `test/tenancy_test.dart` covers the module without a database
and `test/tenancy_db_test.dart` (tagged `db`) runs it under all three isolation
models against MariaDB or PostgreSQL. `test/examples_test.dart` runs the example.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

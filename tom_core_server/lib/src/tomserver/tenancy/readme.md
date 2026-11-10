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
| `TomTenancy` | The deployment's tenants and their routing. `install` reads the tenant registry (seeding it with the configured tenants it lacks), provisions each tenant's schema or database and routes data-source lookups; `runFor` / `forEachTenant` run work inside a tenant; `resolveRequest` names a request's tenant or the rejection to answer it with; `addTenant` onboards without a restart — provisioned, migrated by its type's tree and served in one call, `migrateTenant` retrying a failed migration — `suspendTenant` / `resumeTenant` stop and restart a tenant's traffic and hold its queued runs (`servesWork`), `setStatus` records any status — the migration run moves a tenant through `migrating` to `active` or `migration-failed` with it — `removeTenant` withdraws a tenant, closing the data sources opened for it and cancelling its queued runs, `restoreTenant` brings it back, and `purgeTenant` drops its schema or database and its system-table records once `purgeAfter` has passed (`TomTenantPurgeReport`) — each recorded in the registry first; tenant pools are sized by `TomTenantPoolSettings`; `refreshFromRegistry` brings a node level with what other nodes changed; `checkSchemaVersions` judges each tenant's schema against this node's code — behind, or ahead by a migration not marked expand, the tenant is refused (`tenancy.tenant.schema_behind` / `schema_ahead`, 503) while the others are served (`schemaCheckOf`). |
| `TomTenantRegistry` · `TomMemoryTenantRegistry` · `TomSqlTenantRegistry` | The durable list of tenants — in memory, or the framework table `tom_tenant` in the system schema, declared once as `tenantTable` (default name `defaultTenantTable`) — with `TomTenantRecord` (one row), `TomTenantStatus`, `TomTenantRegistryConflict` and `TomTenantRegistryRefresh`. `withMigrationLock` keeps one migration of a target at a time — a database session lock in the SQL registry, so across every process. |
| `TomTenant` · `TomTenantIsolation` | One tenant, of a type (`default` unless it names one), and where its data lives: `shared`, `schema` or `database`. |
| `TomTenantType` | A kind of tenant (`tenancy.types`): its default model, the models it allows, the data sources it routes and its migration tree. Its shared tenants share one schema — the system schema for `default`, `<databaseName>_<type>` otherwise. Without declared types the deployment has the implicit type `default`. |
| `TomTenantResolver` · `TomTenantHostResolver` · `TomTenantPathResolver` · `TomTenantHeaderResolver` | How a request without a token claim names its tenant: by subdomain or own host, by the path segment after a prefix (`/t/<segment>`, mapped to a tenant id when a lookup is given), or by the `X-Tenant-Id` header. |
| `TomTenantResolution` | A tenant, none, or a rejection with its HTTP status and key. |
| `TomTenantData` | A store of a system table that records tenants — the job queue, the blob manifest, delivery reports, the suppression list, OAuth state, service accounts — and deletes a purged tenant's records. |
| `TomTenancyStartup` · `TomTenancyMode` · `TomTenancyStartupReport` | What the server's start makes of tenancy (`TomServer.configureTenancy`): no tenant table and no `tenancy` key — a plain application; tenant tables without the key — the implicit tenant `default`; the key — the configured tenancy installed. The contradictions between types, trees and tenant tables refuse the start (`tenancy.start.*`). |
| `TomTenancyException` | Every refusal the module raises — `tenancy.config.*`, `tenancy.tenant.*`, `tenancy.type.*`, `tenancy.registry.*`, `tenancy.purge.*` and `tenancy.pool.*`. |

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

The framework's own tables stay in the base data source. Under `schema`
isolation the job queue's write inside a transaction runs over the tenant's
connection against the base schema's table (`TomSqlDatasource.qualify`), so a
message queued on the outbox commits with the tenant's writes.

See [`doc/tenancy.md`](../../../../doc/tenancy.md) for the isolation models, the
configuration, request resolution, what is tenant-scoped and what stays
deployment-wide, and
`example/tenancy/tenancy_example.dart` for two tenants walked through
resolution, token binding, caches, revocations, jobs and the outbox, checking
its own results. `test/tenancy_test.dart`, `test/tenant_registry_test.dart`
and `test/tenant_type_test.dart` cover the module without a database; `test/tenancy_db_test.dart` (tagged `db`)
runs it under all three isolation models against MariaDB or PostgreSQL, and
`test/tenant_registry_db_test.dart` (tagged `db`) the SQL registry and two nodes
over one registry table, and `test/tenant_type_db_test.dart` (tagged `db`) one
shared schema per type. `test/tenant_lifecycle_test.dart` covers the lifecycle
without a database, `test/tenant_lifecycle_db_test.dart` (tagged `db`) against
MariaDB and PostgreSQL. `test/examples_test.dart` runs the example.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

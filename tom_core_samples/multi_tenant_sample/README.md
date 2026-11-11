# multi_tenant_sample

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Tenancy end to end, running against a live MariaDB and a live PostgreSQL: one
application whose customers are tenants of two kinds, one database, and every
step `tom_core_server` takes for them — from the server's start to a tenant
moved, backed up and found again by a restarted node.

It is a program, not a server: `bin/multi_tenant_start.dart` runs the tenancy
steps of `TomServer.start` — `configureTenancy`, `migrateOnStart`,
`guardSchemaOnStart`, the same calls in the same order — without binding a
socket, then walks through what a deployment does with its tenants and prints
what each step found. Serving requests is shown by the other samples; how a
request names its tenant is shown here through `resolveRequest`.

## The application

Customers subscribe to plans and are invoiced; enterprise customers also hold
contracts.

| Table | Entity | Kind | Lives |
| --- | --- | --- | --- |
| `mt_plan` | `MtPlan` | **system table** — the deployment's catalogue | the system schema; read the same in every tenant |
| `mt_review_report` | `MtReviewReport` | **system table**, written from inside each tenant by a job | the system schema, naming the tenant |
| `mt_invoice` | `MtInvoice` | **tenant table** (`@TomTenantTable`) | the tenant's placement |
| `mt_contract` | `MtContract` | **tenant table** | the tenant's placement |

One annotation decides it: an entity with `@TomTenantTable` is a tenant's, every
other one the system's — and a system table read or written inside a tenant
stays in the system schema.

## Two tenant types

| Type | Isolation | Tree | Tenants |
| --- | --- | --- | --- |
| `standard` | `shared`: one schema for the type (`mtapp_standard`), rows told apart by `tenant_id` | `database_migrations/tenant/standard/main/` — invoices, contracts | `acme`, `globex` |
| `enterprise` | `schema`: a schema each (`mtapp_initech`, …) | `database_migrations/tenant/enterprise/main/` — invoices, contracts and an index of their own | `initech`, and `umbrella` onboarded at runtime |

Each type's tree has its own history (`tenant_standard_versioning`,
`tenant_enterprise_versioning`). Every type's tree creates every tenant table —
the start refuses one that lacks a table the type routes — so the two differ in
isolation and in how their trees evolve, not in which tables they have.

The system schema's tree is `database_migrations/system/main/app/`: the plan
catalogue and its seed, and the review reports. The same SQL serves both
databases.

## The configuration

`assets/config.yaml` is all a deployment writes — the tenancy, its types and
seed tenants, and `migrations.onStart`. Nothing about tenancy is installed in
code: the start installs the configured tenancy (`TomServer.configureTenancy`),
migrates (`migrateOnStart`) and guards the system schema
(`guardSchemaOnStart`). The data source `main` is built from the environment
(`MT_DB_ENGINE`, `MT_DB_HOST`, `MT_DB_PORT`, `MT_DB_USER`, `MT_DB_PASSWORD`,
`MT_DB_NAME`; `MtDatabase`).

## The walk-through

| Step | What it shows |
| --- | --- |
| Start | the configured tenancy installed; the system tree, the `standard` type's shared schema and `initech`'s schema migrated, in that order; the system schema current |
| Plans | a system table: the same two plans in `acme` and in `initech` |
| Invoices and contracts | each tenant sees its own rows — `acme` and `globex` in one shared schema, `initech` in its own |
| Onboarding | `umbrella` added at runtime (`addTenant`): recorded, its schema created and migrated, served |
| The contract review | a job declared per tenant type (`TomJobTenants(types: ['enterprise'])`), run once for `initech` and once for `umbrella`, each run in its tenant, each writing the system table |
| Schema check, suspension | every tenant's schema current (`checkSchemaVersions`); `globex` suspended — a request naming it is refused with `tenancy.tenant.suspended` — and resumed |
| One transaction | an invoice and a review report in one transaction commit as one branch: the report runs on `acme`'s connection, its table qualified with the system schema — no two-phase data source needed, since the tenant's connection reaches the system schema |
| Move and backup | `globex` moved out of the shared schema into one of its own (`moveTenant`), its invoices with it; `acme`'s rows exported (`exportTenant`) |
| Restart | the tenancy reinstalled from the same configuration — whose seed does not name `umbrella` — serves `umbrella`, and `globex` in its new schema: the registry, not the configuration, is the list of tenants |

## Running it

```bash
cd tom_core_samples/multi_tenant_sample
./tool/run_integration.sh                 # both databases, fresh each, then the database-free suite
./tool/run_integration.sh postgresql      # one
```

Or by hand, against a database you bring up:

```bash
docker compose up -d --wait mariadb
dart run bin/multi_tenant_start.dart
docker compose down -v
```

The compose file publishes MariaDB on `3341` and PostgreSQL on `5441`. The
program expects a fresh database; `down -v` gives it one.

## Tests

| Suite | Needs | Covers |
| --- | --- | --- |
| `test/configuration_test.dart` | nothing | the tenant tables and system tables the entities declare; every tree converging with the entities (`TomSchemaConvergenceCheck`); the configuration's types and tenants |
| `test/live_scenario_test.dart` (tagged `live`) | a database | the walk-through, step by step (MT-1 … MT-9); skips without one unless `MT_REQUIRE_DB=1`, which the runner sets |

## Reflection

`bin/multi_tenant_start.dart` is the reflection root (`build.yaml`); its seed
`bin/multi_tenant_start.reflection.dart` is tracked. Regenerate with
`./reflection_generation.sh` after changing an entity, and check it with
`./reflection_generation.sh --check`.

## See also

- [`tom_core_server/doc/tenancy.md`](../../tom_core_server/doc/tenancy.md) — the
  tenancy module: isolation models, types, the registry, the lifecycle, moves
  and backups.
- [`tom_core_server/doc/db_migration.md`](../../tom_core_server/doc/db_migration.md)
  — the migration root, `migrateAll` and the version guard.
- [`core_server_sample`](../core_server_sample/README.md) — the plain
  application: no tenant table, no tenancy configured, nothing to do.

# Persistence & the two databases

*Part 05 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

The two servers each own a **separate MariaDB database** and persist through the
same kernel machinery: reflected **record** classes annotated with `@TomDbColumn`,
loaded and saved through a singleton `TomSqlDatasourceRepository`, with the schema
and demo data delivered as **migrations** under each package's
`database_migrations/` tree. This part covers the persistence record shape and its
mapping, the CRUD repositories, the two-database design and the cross-database
logical references, the datasources YAML, and the **schema-creation vs sample-data
migration split** — the clean separation of DDL from demo content that this
sample establishes.

## The persistence model & `@TomDbColumn` mapping

Each server has a `lib/src/persistence/<name>_persistence_model.dart` library of
plain **record** classes — the relational counterparts of the observable domain
entities. The record shape is deliberately the *opposite* of the domain shape:

| Domain entity (`advanced_todo_domain`) | Persistence record (server) |
| --- | --- |
| `TomClass` with observable `TomString` / `TomBool` / `TomList` cells | plain class with nullable typed fields (`String?`, `int?`, `DateTime?`, `double?`, `bool?`) |
| string display ids | an **integer surrogate primary key** (`int? id`) |
| nested relations conceptually | **explicit integer foreign-key columns** (`workspaceId`, `listId`, …) |
| — | no nested collections — every record is **one flat row** |

A record is marked up with two annotations and per-field column mappings:

```dart
@tomReflector
@TomDbTable(datasource: appDatasource, table: 'app_items', primaryKeyField: 'id')
class ItemRecord {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;                                   // surrogate PK, DB-assigned

  @TomDbColumn(columnName: 'list_id')
  int? listId;                               // same-db foreign key

  @TomDbColumn(columnName: 'status')
  String? status;                            // TodoStatus.name token

  @TomDbColumn(columnName: 'assignee_id')
  int? assigneeId;                           // cross-db logical ref to auth_users
  // …
}
```

`@TomDbColumn(columnName: …)` names the SQL column exactly as the migration
declares it, so records read and write the tables **with no aliasing**. The PK
field carries `@TomEntityId()` + `isReadOnly: true` — the database assigns it
(`AUTO_INCREMENT`), so the record never writes it and reads it back after an
insert. Enum-typed domain fields are stored as their `Enum.name` token in a
`VARCHAR` (`status` / `priority` / `label` / `project_role` / `status`), matching
the domain's [stored-name convention](README_advanced_03_domain_reflection.md#enums-stored-name-vs-display-text-contract);
collections that have no child table (e.g. an item's `tags`) are serialized to a
single text column by the mapping layer. Translating between the observable
domain entities and these flat records is the job of the `*_mapping.dart` pure
functions — the records never leak observability, and the entities never carry
surrogate keys.

> **A reused framework table.** The four-state grant matrix is **not** a sample
> record: `advanced_auth_server` reuses the framework's `TomResourceGrant`
> (re-exported from the `tom_core_server` barrel) for the `tom_resource_grant`
> table. Its grades drive field authorization (part
> [07](README_advanced_07_authorization.md)).

## CRUD repositories

Every record gets a one-line repository subclass and a process-wide singleton
instance:

```dart
class ItemRepository extends TomSqlDatasourceRepository<ItemRecord, int> {}
final itemRepository = ItemRepository();
```

`TomSqlDatasourceRepository<R, K>` is the kernel's generic CRUD repository over a
record type `R` with key type `K` (`int` here). It derives the table, datasource,
and column mapping from the record's `@TomDbTable` / `@TomDbColumn` reflection, so
the subclass body is empty — the repository needs no per-entity SQL. Holding each
repository as a singleton matches `core_server_sample` and the migrated `tom_uam`
persistence model: the connection and prepared-statement machinery live once per
process, and the endpoint services call `…Repository.save` / `findById` / query
methods directly.

## The two-database design

The sample runs **two physically separate databases**, one per server:

| Database | Owned by | Host port | Holds |
| --- | --- | --- | --- |
| **`auth_db`** | `advanced_auth_server` | **3307** | `auth_users`, `auth_roles`, `auth_groups`, `auth_group_members`, `auth_user_roles`, and the reused `tom_resource_grant` matrix |
| **`app_db`** | `advanced_app_server` | **3308** | `app_workspaces`, `app_projects`, `app_lists`, `app_items`, `app_comments`, `app_subtasks`, `app_shares` |

Splitting identity from application data means a user-id in `app_db` points at a
principal that lives in a *different* database. Those columns — `owner_id`,
`assignee_id`, `reporter_id`, `author_id`, `grantee_user_id`, `granted_by_id` —
are stored as the auth user's surrogate `int` id and are **logical references,
not enforced foreign keys**: no FK constraint is (or can be) declared across the
database boundary, so the value simply *mirrors* `auth_db.auth_users.id`. A token
minted by the auth server therefore resolves to the same numeric id on the app
side. Within a single database, parent links (`workspace_id`, `project_id`,
`list_id`, `item_id`) **are** real foreign keys with `ON DELETE CASCADE`. The
`app_shares.resource_id` is the one same-db exception: it is *polymorphic*
(`resource_type` names the table), so it carries no FK either.

The two databases publish **3307** and **3308** — neither is **3306** — so
`auth_db`, `app_db`, and any host-local MariaDB run side by side on one machine
without colliding.

## Datasources YAML config

Each server wires its connections in `assets/datasources_default.yaml`, with
`${VAR:default}` environment substitution. Two rules are load-bearing:

- **The map key must equal the migration folder name.** The app server's key is
  `app_db`, matching `database_migrations/app_db/` — that is how `TomDbMigrations`
  matches a schema tree to its datasource.
- **`port` is a literal int, not a substitution.** `${...}` always yields a
  string, and the MariaDB datasource binds `port` to an `int` field, so a
  substituted `"3308"` would fail reflection. Host, credentials, and database
  name are strings and substitute cleanly.

The app server wires **two** datasources, which is how the grant matrix crosses
the database boundary at read time:

```yaml
app_db:        # the app's own data, host port 3308
  type: mariadb
  port: 3308
  # …
main:          # the framework grant store, pointed at auth_db on 3307
  type: mariadb
  port: 3307
  databaseName: ${AUTH_DB_NAME:auth_db}
```

`TomResourceGrant` carries the framework default `main` datasource in its own
annotation. The grant matrix is **owned** by `auth_db` (the authadmin client edits
it there), so the app server reads it by pointing its `main` datasource at the
*same physical MariaDB the auth server runs*. The app server never writes
grants — it only resolves a principal's per-field states from the rows the auth
server seeded.

## Migrations: schema-creation vs sample-data

Each database's schema and demo data live as SQL migrations under
`database_migrations/<datasource>/<schema>/`, named `[<version>]-<desc>.sql`.
`TomDbMigrations.migrateDatabases(dir)` (called at server boot) walks the tree and
applies files in **ascending numeric version order**; the same tree is also
mounted into MariaDB's `docker-entrypoint-initdb.d` for first-boot bootstrap,
where it runs in alphabetical order — which agrees with the numeric order for
these zero-padded names. The version is digits-only and the description is
letters/underscores-only, both enforced by the runner's filename pattern.

**This sample separates DDL from demo content** — schema-creation and sample-data
are distinct migrations, so a deployment that wants an empty database can apply
the schema set alone and skip the seed:

| Database | Schema migrations (DDL only) | Sample-data migration (idempotent seed) |
| --- | --- | --- |
| `app_db` | `[000]-app_core_schema.sql` (7 `CREATE TABLE`s) | `[100]-app_sample_data.sql` |
| `auth_db` | `[000]-auth_core_schema.sql` (identity tables) · `[001]-auth_authz_grants.sql` (`tom_resource_grant`) | `[100]-auth_sample_data.sql` |

The `[1NN]` sample-data files sort after every `[0NN]` schema file, so every table
exists before it is seeded — for `auth_db` this matters because the grant rows in
`[100]` populate the `tom_resource_grant` table created back in `[001]`. The seed
data is the demo cast: in `auth_db`, one admin plus three end-users (`alice`,
`bob`, `carol`), five roles, a group, and the **28-row grant matrix** (7 gradable
`todo.item.*` fields × 4 project roles); in `app_db`, a starter workspace owned by
alice with one project, two lists, three items, a comment, two subtasks, and two
shares (alice shares the project with bob as `editor` and carol as `viewer`), so
cross-user access is visible on first run without a single write.

Every seed `INSERT` uses **`ON DUPLICATE KEY UPDATE`**, so re-applying a migration
is idempotent — the runtime migrator and the initdb hook can both run the same
file without duplicate-key failures. Password hashes are deliberately **not**
seeded in SQL: `password_hash` is left `NULL` and filled at boot by the
kernel-crypto helper, because the auth server (not the migration) owns the hash
format (part [06](README_advanced_06_authentication.md)).

> **Verified.** Booting both databases from a fresh volume applies the split
> migrations in order and lands every seed row (app: 1 workspace / 1 project / 2
> lists / 3 items / 1 comment / 2 subtasks / 2 shares; auth: 4 users / 5 roles / 1
> user-role / 1 group / 2 members / 28 grants), and the cross-tier scenario stays
> green — the split is behaviour-preserving.

## Primary sources

- [`advanced_app_server/README.md`](advanced_app_server/README.md), [`advanced_auth_server/README.md`](advanced_auth_server/README.md)
- `advanced_app_server/lib/src/persistence/app_persistence_model.dart`, `advanced_auth_server/lib/src/persistence/auth_persistence_model.dart`, and the `*_mapping.dart` converters
- `*/assets/datasources_default.yaml`, `*/database_migrations/<datasource>/<schema>/`
- `advanced_example_specification_plan.md` — A.10 Persistence & databases, Phase 3

---

← Prev: [04 · Wire contracts & DTOs](README_advanced_04_wire_contracts_dtos.md) · Next: [06 · Authentication (JWT)](README_advanced_06_authentication.md) →

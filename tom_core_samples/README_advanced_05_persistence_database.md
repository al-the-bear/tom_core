# Persistence & the two databases

*Part 05 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

The two servers each own a **separate MariaDB database** and persist through the
same kernel machinery: reflected **record** classes annotated with `@TomDbColumn`,
loaded and saved through a singleton `TomSqlDatasourceRepository`, with the schema
and demo data delivered as **migrations** under each package's
`database_migrations/` tree. This part covers the persistence record shape and its
mapping, the CRUD repositories, the two-database design and the cross-database
logical references, the datasources YAML, the **file columns and per-database blob
stores**, and the **schema-creation vs sample-data migration split** — the clean
separation of DDL from demo content that this sample establishes.

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
| **`auth_db`** | `advanced_auth_server` | **3307** | `auth_users`, `auth_roles`, `auth_groups`, `auth_group_members`, `auth_user_roles`, the reused `tom_resource_grant` matrix, and the framework authorization tables `tom_principal_resource_grant` (C-5 ownership) and `tom_principal_delegation` (C-6 shares) |
| **`app_db`** | `advanced_app_server` | **3308** | `app_workspaces`, `app_projects`, `app_lists`, `app_items`, `app_comments`, `app_subtasks` |

Splitting identity from application data means a user-id in `app_db` points at a
principal that lives in a *different* database. Those columns — `owner_id`,
`assignee_id`, `reporter_id`, `author_id` — are stored as the auth user's
surrogate `int` id and are **logical references, not enforced foreign keys**: no
FK constraint is (or can be) declared across the database boundary, so the value
simply *mirrors* `auth_db.auth_users.id`. A token minted by the auth server
therefore resolves to the same numeric id on the app side. Within a single
database, parent links (`workspace_id`, `project_id`, `list_id`, `item_id`)
**are** real foreign keys with `ON DELETE CASCADE`. Cross-user shares are **not**
an `app_db` table at all: they are `share`-mode
`tom_principal_delegation` rows in `auth_db` (the delegate/resource/role are
plain columns there, resolved by the framework `TomDelegationResolver`).

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

## File columns & the blob stores

Three columns in this sample hold **files**. None of them holds bytes: a
`@TomFileReference` column is a `VARCHAR(512)` that stores a **blob storage key**,
and the payload lives in the framework's `tom_blob` / `tom_blob_chunk` tables. The
annotation sits next to the field, in the same record class as every other column:

```dart
// advanced_app_server — ItemRecord
@TomDbColumn(
  columnName: itemAttachmentColumn,     // 'attachment'
  authKey: itemAttachmentGradeKey,      // 'todo.item.attachment'
)
@TomFileReference(
  keyPrefix: 'items/attachment',
  exposed: true,
  cascadeDelete: true,
)
String? attachment;

@TomDbColumn(columnName: 'internal_note')
@TomFileReference(keyPrefix: 'items/internal_note')
String? internalNote;   // `exposed` defaults to false — see below
```

| Column | Record | `exposed` | `cascadeDelete` | `authKey` | What it demonstrates |
| --- | --- | --- | --- | --- | --- |
| `app_items.attachment` | `ItemRecord` | **true** | **true** | `todo.item.attachment` | the full case: reachable over HTTP, graded per row, and its bytes die with the row |
| `app_items.internal_note` | `ItemRecord` | *(default false)* | true | *(none)* | **default-closed**: a file column nobody exposed has no HTTP slot at all |
| `auth_users.avatar_ref` | `UserRecord` | **true** | **false** | *(none)* | the deliberate contrast: deleting the user leaves the blob behind |

**`exposed` is the whole access decision, and it defaults to closed.** `attachment`
and `internal_note` are indistinguishable in the DDL — the migration declares two
identical `VARCHAR(512) NULL` columns — because whether a file may be fetched over
HTTP is an authorization statement, not a storage one, and it is declared beside
the field so it cannot drift away from what it governs. Nothing has to be written
to keep `internal_note` private; *not* saying `exposed: true` is what keeps it
private. Part [10](README_advanced_10_servers_endpoints.md#the-file-endpoint)
covers what that means at the HTTP boundary.

**`cascadeDelete` is a lifecycle choice, not a default to accept.** With
`cascadeDelete: true`, deleting an item deletes its attachment's bytes — the blob
was *part of* the row and outliving it would be a leak. The avatar says `false` on
purpose: an avatar is plausibly shared, re-pointed, or kept for an audit trail, so
removing a user row must not silently destroy a blob another row may name. The
pair exists so the two halves of the question are visible together; a sample where
every column took the default would teach that there is no question.

`keyPrefix` namespaces the generated keys (`items/attachment/…`) so a store's
contents remain legible, and so two columns backed by the same store cannot
collide.

### Where the bytes go: `blobstores_default.yaml`

Each server declares its stores in `assets/blobstores_default.yaml`, loaded at
boot by its own `blobStoreLoaderFunction()` and installed with
`TomBlobStoreInfo.initializeBlobStores(...)` — **after**
`TomDataSourceInfo.initializeDatasourceInfo(...)`, because a `type: database`
store resolves its named data source eagerly, turning a misnamed store into a
start-up failure rather than a failed upload hours later.

```yaml
# advanced_app_server/assets/blobstores_default.yaml
files:
  type: database
  datasource: app_db
  createSchema: false
```

Three details carry weight:

- **One store, so it is the default.** The file columns name no store, so they
  resolve to the only one configured — no `default: true` needed.
- **`datasource:` is load-bearing, not decoration.** The app server's `main`
  datasource deliberately points at *auth_db* so it can read the shared grant
  matrix (above); naming `app_db` here is what keeps an item attachment out of the
  auth database. The auth server's equivalent file names `auth_db`. Each server
  therefore writes its blobs into its own database, and **the two-database
  boundary survives the addition of file transfer** — no avatar in `app_db`, no
  attachment in `auth_db`.
- **`createSchema: false` hands schema ownership to the migration chain.** The
  blob tables are created by the migrations below and nowhere else. Left at the
  default (`true`), the store would issue its own `CREATE TABLE` at boot —
  harmless while it agrees with the migration, and a silent divergence the moment
  it does not.

`type: database` is what makes file transfer cost this sample **no new
infrastructure**: no object store, no shared mount, no extra credential.
`TomDirectoryBlobStore` (`type: directory`) and `TomS3BlobStore` (`type: s3`) are
the same four methods behind the same interface, so a real deployment swaps this
block without touching application code.

## Migrations: schema-creation vs sample-data

Each database's schema and demo data live as SQL migrations under
`database_migrations/<datasource>/<schema>/`, named
`[<version>]-<desc>[@<env>[,<env>…]].sql`. `TomDbMigrations.migrateDatabases(dir)`
(called at server boot) walks the tree and applies files in **ascending numeric
version order**, **skipping any migration tagged for an environment other than
the active one** (the `@<env>` tag, G-MIG-3 — untagged migrations apply
everywhere); the same tree is also mounted into MariaDB's
`docker-entrypoint-initdb.d` for the dev-harness first-boot bootstrap, where the
stock hook runs *every* `.sql` alphabetically (the environment filter is the
runner's, not MariaDB's) — the numeric order agrees with alphabetical for these
zero-padded names. The version is digits-only and the description is
letters/underscores-only, both enforced by the runner's filename pattern.

**This sample separates DDL, the production admin bootstrap, and demo content**
into consecutively-numbered migrations, so a production apply seeds the
administrator account while omitting every demo user. The migrations are numbered
`000, 001, 002, …`; the demo seeds carry the `@dev,test` tag so the runner skips
them outside `dev`/`test`:

| Database | Schema (DDL, untagged) | Admin seed (untagged — all envs) | Demo seeds (`@dev,test` — dev/test only) |
| --- | --- | --- | --- |
| `app_db` | `[000]-app_core_schema.sql` (7 `CREATE TABLE`s) · `[002]-app_file_columns.sql` (the two `@TomFileReference` key columns) · `[003]-app_blob_tables.sql` (`tom_blob`, `tom_blob_chunk`) · `[004]-app_thread_ordering_indexes.sql` (the comment/checklist ordering indexes) · **`[100]-ops_framework_tables.sql`** (`tom_job_run`, `tom_lease`, `tom_scheduler_node`, `tom_audit_trail` — shipped by `advanced_ops_server`, not by the app server) | — (no admin rows in `app_db`) | `[001]-app_demo_seed@dev,test.sql` |
| `auth_db` | `[000]-auth_core_schema.sql` (identity tables) · `[001]-auth_authz_grants.sql` (`tom_resource_grant`) · `[004]-auth_two_factor_columns.sql` (the two second-factor columns) · `[006]-auth_blob_tables.sql` (`tom_blob`, `tom_blob_chunk`) · `[007]-auth_two_factor_enrolments.sql` (`tom_user_two_factor_enrolment`) | `[002]-auth_admin_seed.sql` (admin user + `admin` role + assignment) | `[003]-auth_demo_seed@dev,test.sql` · `[005]-auth_two_factor_seed@dev,test.sql` |

**`app_db` is the one chain with two contributing packages, and its numbering is
banded rather than contiguous.** The engine matches a chain to a database by the
folder names `<datasource>/<schema>`, not by which package the folder sits in, so
`advanced_ops_server` can extend `app_db/app_schema` with the framework tables its
scheduler needs without the app server's package mentioning a job queue it never
runs. The cost is that two packages must not pick the same number and neither can
see the other's choice — and a collision is silent, because the engine records the
version as applied and never runs the second file, surfacing as a missing table at
the first tick of whichever deployment was provisioned last. So each package owns a
**band**: the app server `[000]`–`[099]`, the ops server `[100]` and up. The gap is
deliberate. Within its band each package numbers freely, which is why the app server
could add `[004]` without anyone consulting the ops server.
`advanced_ops_server/test/ops_migration_chain_test.dart` enforces it from the only
side that can see both directories. `auth_db` has a single contributing package and
stays contiguous — a band buys nothing where nobody else can collide with you.

Each seed sorts after the schema it depends on, so every table and column exists
before it is filled: the grant rows in `[003]` populate the `tom_resource_grant`
table created back in `[001]`, and the enrolment in `[005]` fills the columns
`[004]` adds. Note that `[004]` is schema *and* sorts after a demo seed —
migrations run in the order features were added, not in two tidy blocks, so the
dependency to check is per-file, not "all DDL first".

`[004]` is worth a second look as the shape of a **late schema change**. The same
two columns are also declared in `[000]`, which is what a fresh database gets;
`[004]` repeats them as idempotent `ADD COLUMN IF NOT EXISTS` so a database
created *before* 2FA existed — whose `[000]` is already recorded as applied and
will never run again — picks them up too. It carries **no** environment tag,
because schema must reach production even when the demo account that exercises it
must not. `app_db` `[002]` has exactly this shape for the two file-key columns,
for exactly this reason.

The two **blob-table** migrations (`app_db` `[003]`, `auth_db` `[006]`) are
byte-identical to each other and copied verbatim from the framework's canonical
reference migrations under
`tom_core_server/example/file_storage/migrations/main/tomcore/`. They are
duplicated rather than shared because each server backs its store with its *own*
database — that duplication is the two-database boundary, not an oversight. Since
the DDL now lives in two sample files and the framework separately describes the
same tables in `blobManifestTable()` / `blobChunkTable()`, each server carries a
**convergence test** (`test/app_blob_schema_test.dart`,
`test/auth_blob_schema_test.dart`) that fails if the migration and the framework
descriptors drift apart. There is no column migration alongside `auth_db` `[006]`:
`auth_users.avatar_ref` already existed from `[000]` at the right width, so the
avatar feature reuses a column rather than adding one.

The **admin seed** (`auth_db` `[002]`, untagged) is the one seed a production
apply keeps: just the administrator account, the `admin` role, and the assignment
the `/admin/*` gate resolves against. The **demo seeds** (`@dev,test`) are the
sample cast, skipped in production: in `auth_db`, three end-users (`alice`,
`bob`, `carol`), the four project roles, a group, and the **32-row grant matrix**
(8 graded `todo.item.*` keys × 4 project roles — the seven form fields plus the
item's file column `todo.item.attachment`), plus `dave` from `[005]` —
enrolled in TOTP so the two-pass login is exercised out of the box (part
[06](README_advanced_06_authentication.md#two-factor-login-the-second-pass)); in
`app_db`, a starter workspace owned by alice with one project, two lists, three
items, a comment, two subtasks, and two shares (alice shares the project with bob
as `editor` and carol as `viewer`), so cross-user access is visible on first run
without a single write.

Every seed `INSERT` uses **`ON DUPLICATE KEY UPDATE`**, so re-applying a migration
is idempotent — the runtime migrator and the initdb hook can both run the same
file without duplicate-key failures. Password hashes are deliberately **not**
seeded in SQL: `password_hash` is left `NULL` and filled at boot by the
kernel-crypto helper, because the auth server (not the migration) owns the hash
format (part [06](README_advanced_06_authentication.md)).

> **Verified.** Booting both databases from a fresh volume under `dev`/`test`
> applies every migration in order and lands every seed row (app: 1 workspace / 1
> project / 2 lists / 3 items / 1 comment / 2 subtasks / 2 shares; auth: 6 users —
> `admin`, `alice`, `bob`, `carol`, TOTP-enrolled `dave` and enrollable `erin` —
> / 7 roles / 3 user-roles / 1 group / 2 members / 32 grants), and the
> cross-tier scenario stays green. A **production** apply runs only the untagged
> migrations — the schema (including `[004]`'s second-factor columns) plus
> `auth_db` `[002]` — so it lands **1 admin user / 1 role / 1 user-role** and
> **no demo users, no grants, no app rows**.

## Primary sources

- [`advanced_app_server/README.md`](advanced_app_server/README.md), [`advanced_auth_server/README.md`](advanced_auth_server/README.md)
- `advanced_app_server/lib/src/persistence/app_persistence_model.dart`, `advanced_auth_server/lib/src/persistence/auth_persistence_model.dart`, and the `*_mapping.dart` converters
- `*/assets/datasources_default.yaml`, `*/assets/blobstores_default.yaml`, `*/database_migrations/<datasource>/<schema>/`

---

← Prev: [04 · Wire contracts & DTOs](README_advanced_04_wire_contracts_dtos.md) · Next: [06 · Authentication (JWT)](README_advanced_06_authentication.md) →

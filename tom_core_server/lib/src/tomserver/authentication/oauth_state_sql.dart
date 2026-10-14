/// The schema of the shared pending-authorization table.
///
/// Declared **once**, as a [TomFrameworkTable], for the same reason the
/// scheduling tables are: the DDL the store issues, the column lists its
/// statements interpolate and the schema model the convergence guard compares
/// are all derived from this one declaration. See
/// `datasources/framework_table.dart` for the mechanism and
/// `db_migration/framework_convergence.dart` for what the guard then proves. The
/// shipped migration file under `example/authentication/migrations/` stays
/// hand-written, because a migration is what a DBA applies and must remain
/// readable; `test/framework_schema_test.dart` fails if the two drift apart.
library;

import '../datasources/framework_table.dart';

/// The default name of the pending-authorization table.
const String defaultOAuthStateTable = 'tom_oauth_state';

/// The pending-authorization table [table], declared once.
///
/// Notes on the shape, because several columns are not obvious:
///
///  * `state` is the primary key and *is* the record's identity — the opaque
///    handle the provider echoes back. There is no surrogate key: a second row
///    for the same handle would make "which pending flow does this callback
///    complete" depend on row order, which is the one question the whole table
///    exists to answer unambiguously.
///  * `expires_at` is stored rather than derived from `created_at` plus the
///    store's time-to-live. The TTL is a property of the *node* that happened to
///    begin the flow, and in a cluster two nodes can be configured differently
///    or rolled out at different times; writing the deadline makes expiry a
///    property of the **record**, so a flow started under a ten-minute TTL is
///    not silently extended by a peer configured for thirty. It also lets the
///    completion statement carry the expiry as an ordinary `WHERE` predicate
///    instead of needing to know a TTL at all.
///  * `created_at` is kept anyway, because it is what an operator reads when
///    asking how long a flow sat unfinished — a question `expires_at` alone
///    cannot answer once the TTL has changed.
///  * `pkce_verifier` is the flow's secret and is nullable, because a provider
///    may be configured without PKCE. See `TomSqlOAuthStateStore` for why it is
///    stored as written rather than under column encryption.
///  * `nonce` is what the flow's next leg must echo: the OpenID Connect nonce,
///    or a SAML `AuthnRequest` id and then the digest of the handoff code. `''`
///    when the flow sent none, like the context columns below.
///  * `tenant` is the tenant the flow began in, `''` for none — the same
///    spelling `tom_job_run.tenant` uses. Every read and the completion carry
///    `AND tenant = :tenant` with the tenant in context, so a callback that
///    reaches another tenant finds no record and cannot spend it. The table
///    itself is deployment-wide: a short-lived record needs no schema of its
///    own, only the predicate.
///  * `asserted_identity` holds a verified SAML identity, as JSON, between the
///    identity provider's form post and the application's completion. `TEXT`
///    because a SAML assertion's attributes have no fixed size, and `NULL` on
///    every record that is not waiting to be completed.
///  * the login-context columns (`client` … `client_timezone`) exist because the
///    callback is a bare browser navigation carrying none of it. They are `NOT
///    NULL` and hold `''` for "not supplied", matching the Dart record whose
///    fields default to the empty string — a nullable column would introduce a
///    second spelling of absence that every read would have to collapse.
///  * `ix_..._expiry` is the index the sweep rides. Without it, pruning is a
///    full scan of a table whose whole point is to be swept often.
///  * instants are `DATETIME(6)` and always written in UTC — see `sqlInstant` in
///    `datasources/sql_instant.dart`.
TomFrameworkTable oauthStateTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'oauthStateTable',
  columns: const [
    TomFrameworkColumn('state', 'VARCHAR(191)'),
    TomFrameworkColumn('provider_id', 'VARCHAR(191)'),
    TomFrameworkColumn('pkce_verifier', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('pkce_challenge', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('created_at', 'DATETIME(6)'),
    TomFrameworkColumn('expires_at', 'DATETIME(6)'),
    TomFrameworkColumn('client', 'VARCHAR(191)'),
    TomFrameworkColumn('application', 'VARCHAR(191)'),
    TomFrameworkColumn('process', 'VARCHAR(191)'),
    TomFrameworkColumn('organization', 'VARCHAR(191)'),
    TomFrameworkColumn('client_language', 'VARCHAR(16)'),
    TomFrameworkColumn('client_country', 'VARCHAR(16)'),
    TomFrameworkColumn('client_timezone', 'VARCHAR(64)'),
    TomFrameworkColumn('nonce', 'VARCHAR(191)'),
    TomFrameworkColumn('asserted_identity', 'TEXT', nullable: true),
    TomFrameworkColumn('tenant', 'VARCHAR(32)'),
  ],
  primaryKey: const ['state'],
  keys: const [
    TomFrameworkKey('expiry', ['expires_at']),
  ],
);

/// The DDL for the pending-authorization table [table].
String oauthStateTableDdl(String table) =>
    oauthStateTable(table).createTableDdl;

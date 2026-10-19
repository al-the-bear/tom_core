/// The shared pending-authorization store: one row per flow in progress, in the
/// database the application already has.
///
/// ## Why the in-process store is not enough
///
/// An authorization-code flow is **two HTTP requests**, and the second one is a
/// redirect *the provider issues to the user's browser*. It lands wherever the
/// load balancer sends it. On a single node that is always the node that began
/// the flow; behind a load balancer it is a coin flip, and a callback that lands
/// on the wrong node finds no pending record and fails with
/// `oauth.flow.unknown_state` — the same key an expired handle and a replayed
/// one produce. The symptom is "external login works, but only sometimes, and
/// the log says replay attack". Restarting a node does the same thing to every
/// flow in progress.
///
/// So the record has to live somewhere both halves of the deployment can see,
/// and in practice that is the database every node is already talking to. This
/// is the same move `TomSqlJobStore` and `TomSqlLeaseLock` make for the
/// scheduler, and it is deliberately the same *shape*: one
/// [TomFrameworkTable] declaration, created on first use or by a shipped
/// migration, with the database — never the application — arbitrating the races.
///
/// ## Completing a flow is one statement
///
/// ```sql
/// DELETE FROM tom_oauth_state
///  WHERE state = :state AND expires_at > :now
/// RETURNING state, provider_id, ...
/// ```
///
/// The single-use guarantee **is** that statement. Two callbacks racing the same
/// handle both reach the `DELETE`; exactly one of them gets a row back and the
/// other gets an empty result, because the row can only be deleted once. A
/// read-then-delete would look equivalent and is not: both readers would see the
/// record, and the replay the `state` exists to defeat would succeed once for
/// each racer.
///
/// ### When the answer to the completion is lost
///
/// [TomSqlJobStore] re-reads its row when a claim's acknowledgement never
/// arrives, because the claim *mutates* the row and the truth is still there to
/// be read. Nothing analogous is possible here: if the `DELETE` committed and
/// the answer was lost, the record — including the PKCE verifier the exchange
/// needs — is gone, so there is nothing to recover and no way to complete the
/// flow. The ambiguity therefore resolves the only way it can, and fortunately
/// the conservative way: the exception propagates, the login fails, and the user
/// presses the button again. The cost of failing closed here is one retry; the
/// row is already gone, so a replay cannot succeed either.
///
/// ## Expiry
///
/// **A deletion predicate on the statements, plus a swept-on-write bound.** Of
/// the two shapes a relational store can take, this is the one that needs
/// neither a background timer (which every embedding process would then have to
/// shut down) nor a scheduled job (which makes correctness depend on a scheduler
/// being configured — and the scheduler is exactly the subsystem a deployment
/// may not be running):
///
///  * every read and the completion carry `AND expires_at > :now`, so an expired
///    record is never *selected*. It does not have to be deleted first to behave
///    like an unknown one, which is what keeps the three failure cases
///    indistinguishable to a caller;
///  * [store] deletes expired rows before writing, so a deployment that keeps
///    starting flows nobody finishes cannot grow the table without bound. The
///    sweep is throttled to [sweepInterval] because it is bookkeeping, not
///    correctness — the predicate above already makes an unswept row invisible,
///    so sweeping on *every* login would buy nothing and cost a delete per
///    login.
///
/// This mirrors [TomOAuthMemoryStateStore], which enforces its TTL on read and
/// sweeps on write for the same reasons. Two stores behind one interface should
/// not have two different theories of when a record dies.
///
/// ## The PKCE verifier is stored as written, and not encrypted
///
/// The row is a credential at rest and is treated as one, so the decision is
/// stated rather than defaulted into.
///
/// **What the verifier is.** A single-use, TTL-bounded nonce that proves the
/// party redeeming an authorization code is the party that requested it. On its
/// own it authorises nothing: without the code — which the provider delivers
/// only to the registered `redirect_uri`, over the back channel — it is a random
/// string. PKCE's threat model (RFC 7636 §1) is an attacker who intercepts the
/// *code*; the verifier is this server's answer to that attacker, not a
/// long-lived secret of its own.
///
/// **What encrypting the column would buy.** Protection against someone who can
/// read this table but not the process's key material — a stolen backup, a
/// replica, a query log. That is a real threat and the reason encryption is worth
/// asking about. It is not the threat that decides this one, because an attacker
/// with that access to *this* database also has the identity provider's client
/// secret, the JWT signing keys and every issued session — the verifier is the
/// least of what they hold, and encrypting it alone would be security theatre
/// pointed at the smallest item in the blast radius.
///
/// **What it would cost.** The framework has no column-encryption facility. One
/// would have to be invented here, in an OAuth store — the wrong place for a
/// data-source concern — and every deployment would then carry a key whose loss
/// silently breaks external login. A wrong key is indistinguishable from an
/// expired handle at the only point it is read.
///
/// **What is done instead**, which bounds the exposure to the flow's own
/// lifetime rather than merely obscuring it:
///
///  * the row is **deleted** by the completion, not marked spent, so a finished
///    flow leaves no verifier behind at all;
///  * an abandoned flow's row survives at most its TTL before the sweep removes
///    it;
///  * the column is `VARCHAR`, so it never reaches an off-page overflow segment
///    that a `DELETE` leaves readable.
///
/// A deployment whose regulator requires the value encrypted at rest has two
/// answers that do not need this class to change: encrypt the tablespace, or
/// install its own [TomOAuthStateStore]. The seam exists precisely so this
/// decision does not have to be the framework's for everyone.
///
/// ## Time
///
/// Instants are stored as `DATETIME(6)` in **UTC** and read back through `String`
/// columns — see `datasources/sql_instant.dart` for why the driver makes that
/// necessary.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'oauth_flow.dart';
import 'oauth_provider.dart';
import 'oauth_state_sql.dart';

/// A [TomOAuthStateStore] whose pending authorizations are rows in a
/// [TomDataSource].
class TomSqlOAuthStateStore implements TomOAuthStateStore {
  /// Creates a store over [datasource].
  ///
  /// [table] names the pending-authorization table. With [createSchema] left
  /// `true` the table is created on first use, which is what a test or a
  /// self-provisioning deployment wants; set it `false` when the schema is owned
  /// by the migration module and the application's database user may not run
  /// DDL.
  ///
  /// [timeToLive] is measured from [TomOAuthAuthorizationState.createdAt], the
  /// same as [TomOAuthMemoryStateStore] measures its own — the two stores
  /// implement one contract and must not disagree about when a record dies.
  ///
  /// [sweepInterval] bounds how often [store] prunes expired rows. It is a cost
  /// control and nothing else: expiry is enforced by the `expires_at` predicate
  /// on every read, so a row the sweep has not reached yet is already invisible.
  TomSqlOAuthStateStore(
    this.datasource, {
    this.table = defaultOAuthStateTable,
    this.createSchema = true,
    this.timeToLive = const Duration(minutes: 10),
    this.sweepInterval = const Duration(minutes: 1),
  });

  /// Creates a store over the registered data source named [datasourceName].
  ///
  /// Throws a [TomServerException] keyed
  /// `oauth.state_store.unknown_datasource` when no such data source is
  /// registered — a configuration error far better caught at start-up than on
  /// the first login. The base class rather than a subtype is deliberate;
  /// [TomServerException] says why.
  factory TomSqlOAuthStateStore.named(
    String datasourceName, {
    String table = defaultOAuthStateTable,
    bool createSchema = true,
    Duration timeToLive = const Duration(minutes: 10),
    Duration sweepInterval = const Duration(minutes: 1),
  }) {
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomServerException(
        'oauth.state_store.unknown_datasource',
        'The OAuth state store refers to a data source that is not registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomSqlOAuthStateStore(
      info.datasource,
      table: table,
      createSchema: createSchema,
      timeToLive: timeToLive,
      sweepInterval: sweepInterval,
    );
  }

  /// The data source the pending-authorization table lives in.
  final TomDataSource datasource;

  /// The pending-authorization table.
  final String table;

  /// Whether to create the table on first use.
  final bool createSchema;

  /// How long a pending authorization stays completable, measured from its
  /// [TomOAuthAuthorizationState.createdAt].
  ///
  /// Ten minutes by default: long enough for a user to read a consent screen and
  /// log in to the provider, short enough that an abandoned flow stops being a
  /// live credential quickly.
  final Duration timeToLive;

  /// How often [store] prunes expired rows.
  final Duration sweepInterval;

  final TomSchemaProvisioning _schema = TomSchemaProvisioning();
  DateTime? _lastSweep;

  /// The table's single column declaration — see `oauth_state_sql.dart`.
  late final TomFrameworkTable _states = oauthStateTable(table);

  /// The columns [store] writes, and the bind each takes.
  ///
  /// Keyed by column name rather than given as a list, so adding a column cannot
  /// shift every value one place along — a failure that would type-check.
  static const Map<String, String> _writeColumns = {
    'state': ':state',
    'provider_id': ':providerId',
    'pkce_verifier': ':pkceVerifier',
    'pkce_challenge': ':pkceChallenge',
    'created_at': ':createdAt',
    'expires_at': ':expiresAt',
    'client': ':client',
    'application': ':application',
    'process': ':process',
    'organization': ':organization',
    'client_language': ':clientLanguage',
    'client_country': ':clientCountry',
    'client_timezone': ':clientTimezone',
    'nonce': ':nonce',
    'asserted_identity': ':assertedIdentity',
    'tenant': ':tenant',
  };

  /// Creates the pending-authorization table if it does not exist.
  ///
  /// Idempotent and called automatically by every operation; exposed so a
  /// start-up sequence can provision the schema before serving traffic.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema) {
      await _states.create(datasource);
    }
  });

  @override
  Future<void> store(TomOAuthAuthorizationState pending) async {
    await ensureSchema();
    await _sweep();
    // INSERT rather than REPLACE, unlike the job store's enqueue. A job may
    // legitimately re-plan a window it has already enqueued; a `state` is a
    // fresh 32-byte token from `Random.secure`, so a duplicate is not a re-write
    // — it is either a collision that should never happen or a caller reusing a
    // handle, and both must fail loudly rather than silently overwrite a live
    // flow with a different one.
    await datasource.executeCommand(
      _states.insertRow(datasource.sqlDialect, _writeColumns),
      _bindOf(pending),
    );
  }

  @override
  Future<TomOAuthAuthorizationState?> peek(String state) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomOAuthStateRow>(
      'SELECT ${_states.columnList} FROM $table '
      'WHERE state = :state AND expires_at > :now AND tenant = :tenant',
      {
        'state': state,
        'now': sqlInstant(_now()),
        'tenant': TomOAuthAuthorizationState.currentTenant,
      },
    );
    return rows.isEmpty ? null : _stateOf(rows.first);
  }

  @override
  Future<TomOAuthAuthorizationState?> consume(String state) async {
    await ensureSchema();
    // The arbitration, in one statement: the row can be deleted once, so exactly
    // one of two racing callbacks is answered with it. See the library
    // documentation for why a read-then-delete is not the same thing, and for
    // why an ambiguous failure here can only resolve to a failed login.
    final rows = await datasource.executeQuery<TomOAuthStateRow>(
      'DELETE FROM $table '
      'WHERE state = :state AND expires_at > :now AND tenant = :tenant '
      'RETURNING ${_states.columnList}',
      {
        'state': state,
        'now': sqlInstant(_now()),
        'tenant': TomOAuthAuthorizationState.currentTenant,
      },
    );
    return rows.isEmpty ? null : _stateOf(rows.first);
  }

  /// Deletes every record whose deadline has passed, answering how many went.
  ///
  /// Called by [store] on the [sweepInterval] cadence, and exposed so a
  /// deployment that would rather prune from a scheduled job — or an operator
  /// cleaning up after an outage — can drive it directly. It affects no
  /// *behaviour*: an expired row is already invisible to [peek] and [consume].
  ///
  /// **This is the only place the expiry predicate is written.** The throttled
  /// sweep comes through here rather than issuing its own copy, so what the
  /// background prune deletes and what an operator's prune deletes cannot come
  /// apart. [now] exists for that caller: it prunes against the instant it
  /// stamped its throttle with, not a second reading of the clock.
  Future<int> purgeExpired([DateTime? now]) async {
    await ensureSchema();
    final affected = await datasource.executeCommand(
      'DELETE FROM $table WHERE expires_at <= :now',
      {'now': sqlInstant(now ?? _now())},
    );
    return affected.toInt();
  }

  /// Empties the table.
  ///
  /// For provisioning and for tests that need a known-empty state — the same
  /// reason [TomSqlJobStore.deleteAll] exists.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
  }

  /// Prunes expired rows through [purgeExpired], at most once per
  /// [sweepInterval].
  ///
  /// All this adds to [purgeExpired] is the throttle and a discarded row count;
  /// the statement is deliberately not repeated here. Two copies of one
  /// predicate is the duplication that drifts, and a store whose background
  /// sweep and whose explicit purge disagreed about what "expired" meant would
  /// leave rows behind that no purge removes, with nothing failing to say so.
  ///
  /// The sweep's own instant is passed on, so the deadline the delete tests
  /// against is the one the throttle was stamped with rather than a second
  /// reading of the clock. The stamp precedes the `await` for the usual reason:
  /// two [store] calls interleaving here must not both get past the throttle.
  Future<void> _sweep() async {
    final now = _now();
    final last = _lastSweep;
    if (last != null && now.difference(last) < sweepInterval) return;
    _lastSweep = now;
    await purgeExpired(now);
  }

  DateTime _now() => DateTime.now().toUtc();

  /// [pending] as the bind map [_writeColumns] names.
  Map<String, dynamic> _bindOf(TomOAuthAuthorizationState pending) => {
    'state': pending.state,
    'providerId': pending.providerId,
    'pkceVerifier': pending.pkce?.verifier,
    'pkceChallenge': pending.pkce?.challenge,
    'createdAt': sqlInstant(pending.createdAt),
    'expiresAt': sqlInstant(pending.createdAt.add(timeToLive)),
    'client': pending.client,
    'application': pending.application,
    'process': pending.process,
    'organization': pending.organization,
    'clientLanguage': pending.clientLanguage,
    'clientCountry': pending.clientCountry,
    'clientTimezone': pending.clientTimezone,
    'nonce': pending.nonce,
    'assertedIdentity': pending.assertedIdentity == null
        ? null
        : jsonEncode(pending.assertedIdentity!.toJson()),
    'tenant': pending.tenant,
  };

  /// [row] as the record the contract answers with.
  ///
  /// `expires_at` is deliberately dropped: the contract's record carries a
  /// creation instant and the *store* owns the deadline, so handing the deadline
  /// back would put a second, store-specific notion of expiry into a value that
  /// callers compare against the memory store's records too.
  static TomOAuthAuthorizationState _stateOf(TomOAuthStateRow row) =>
      TomOAuthAuthorizationState(
        state: row.state,
        providerId: row.providerId,
        createdAt: parseSqlInstant(row.createdAt),
        tenant: row.tenant,
        // A provider configured without PKCE stored neither half, and a record
        // with only one half is a bug in this file rather than a state to model
        // — so the pair is restored only when the verifier is there.
        pkce: row.pkceVerifier == null || row.pkceVerifier!.isEmpty
            ? null
            : TomOAuthPkce(row.pkceVerifier!, row.pkceChallenge ?? ''),
        client: row.client,
        application: row.application,
        process: row.process,
        organization: row.organization,
        clientLanguage: row.clientLanguage,
        clientCountry: row.clientCountry,
        clientTimezone: row.clientTimezone,
        nonce: row.nonce,
        assertedIdentity: row.assertedIdentity == null
            ? null
            : TomExternalIdentity.fromJson(
                (jsonDecode(row.assertedIdentity!) as Map)
                    .cast<String, Object?>(),
              ),
      );
}

/// One pending-authorization row, as the mapper materialises it.
///
/// The instants are `String` fields rather than `DateTime` ones on purpose: the
/// MariaDB driver builds a `DATETIME` with `DateTime.parse`, which yields a
/// *local* `DateTime` that compares unequal to the UTC value that was written.
/// Carrying the text and converting with `parseSqlInstant` makes the round trip
/// exact.
///
/// `expires_at` is mapped even though [TomSqlOAuthStateStore] does not read it
/// back, because the framework-schema guard treats an unmapped column as a
/// finding worth reporting and this one is genuinely projected by
/// `SELECT <columnList>`.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomOAuthStateRow {
  /// The opaque handle the provider echoes back.
  @TomDbColumn(columnName: "state")
  String state = "";

  /// Which provider the flow is against.
  @TomDbColumn(columnName: "provider_id")
  String providerId = "";

  /// The PKCE secret, or `null` for a provider configured without PKCE.
  @TomDbColumn(columnName: "pkce_verifier")
  String? pkceVerifier;

  /// The PKCE challenge that travelled to the provider.
  @TomDbColumn(columnName: "pkce_challenge")
  String? pkceChallenge;

  /// When the flow began, as the stored `DATETIME(6)` text.
  @TomDbColumn(columnName: "created_at")
  String createdAt = "";

  /// When the record stops being completable, as the stored text.
  @TomDbColumn(columnName: "expires_at")
  String expiresAt = "";

  /// The client the login was started from.
  @TomDbColumn(columnName: "client")
  String client = "";

  /// The application the login is for.
  @TomDbColumn(columnName: "application")
  String application = "";

  /// The process the login is for.
  @TomDbColumn(columnName: "process")
  String process = "";

  /// The organization the login is for.
  @TomDbColumn(columnName: "organization")
  String organization = "";

  /// The client's language code.
  @TomDbColumn(columnName: "client_language")
  String clientLanguage = "";

  /// The client's country code.
  @TomDbColumn(columnName: "client_country")
  String clientCountry = "";

  /// The client's IANA timezone name.
  @TomDbColumn(columnName: "client_timezone")
  String clientTimezone = "";

  /// What the flow's next leg must echo, or `''`.
  @TomDbColumn(columnName: "nonce")
  String nonce = "";

  /// A verified SAML identity as JSON, or `null`.
  @TomDbColumn(columnName: "asserted_identity")
  String? assertedIdentity;

  /// The tenant the flow began in, or `''`.
  @TomDbColumn(columnName: "tenant")
  String tenant = "";
}

/// Which pending-authorization store a deployment runs.
enum TomOAuthStateStoreType {
  /// [TomOAuthMemoryStateStore] — a map in one process. The default, and correct
  /// for every deployment that is one process.
  memory,

  /// [TomSqlOAuthStateStore] — a table every node can see. What a load-balanced
  /// deployment needs, because the provider's redirect lands on whichever node
  /// the balancer picks.
  sql;

  /// Parses a configured value (`memory`, `sql`).
  ///
  /// Case- and separator-insensitive, like [TomOAuthProvisioning.parse] and for
  /// the same reason: this is read from hand-written YAML. An unrecognised value
  /// throws rather than falling back to [memory] — a typo that quietly selected
  /// the per-process store would produce exactly the intermittent failure this
  /// whole class exists to remove, on a cluster whose operator believes it is
  /// configured for one.
  static TomOAuthStateStoreType parse(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[_\-\s]'), '').toLowerCase();
    for (final value in TomOAuthStateStoreType.values) {
      if (value.name.toLowerCase() == normalized) return value;
    }
    throw TomOAuthException(
      'oauth.config.unknown_state_store',
      "Unknown OAuth state store type '$raw'; expected one of "
          "${TomOAuthStateStoreType.values.map((v) => v.name).join(', ')}.",
    );
  }
}

/// The configured choice of pending-authorization store.
///
/// Read from the same `oauth:` block as the provider set, because the two are
/// one deployment decision: turning on external login and deciding where its
/// half-finished flows live are read together, in one place, by whoever writes
/// the configuration.
///
/// ```yaml
/// oauth:
///   stateStore:
///     type: sql          # memory (default) | sql
///     datasource: main
///     table: tom_oauth_state
///     timeToLiveSeconds: 600
///     createSchema: true
///   providers:
///     google: { ... }
/// ```
///
/// Absent, the answer is [TomOAuthStateStoreType.memory], so a single-node
/// deployment behaves exactly as it did before this store existed and nothing
/// has to be configured to keep it that way.
class TomOAuthStateStoreSettings {
  /// The configuration path the store choice is read from.
  static const String configurationKey = 'oauth.stateStore';

  /// Which store to build.
  final TomOAuthStateStoreType type;

  /// The registered data source name, for [TomOAuthStateStoreType.sql].
  final String datasourceName;

  /// The table name, for [TomOAuthStateStoreType.sql].
  final String table;

  /// How long a pending authorization stays completable.
  final Duration timeToLive;

  /// Whether the SQL store creates its table on first use.
  final bool createSchema;

  /// Creates a settings value.
  const TomOAuthStateStoreSettings({
    this.type = TomOAuthStateStoreType.memory,
    this.datasourceName = '',
    this.table = defaultOAuthStateTable,
    this.timeToLive = const Duration(minutes: 10),
    this.createSchema = true,
  });

  /// Reads the store choice from the configuration tree under
  /// [configurationKey].
  ///
  /// Answers the memory store's settings when the key is absent, so calling this
  /// unconditionally at startup is safe. A *malformed* block still throws —
  /// absent and wrong are different states, and the wrong one is a cluster whose
  /// logins fail one request in two.
  factory TomOAuthStateStoreSettings.fromConfiguration([
    TomServerConfigResourceProvider? config,
  ]) {
    final provider =
        config ?? TomServerConfigResourceProvider.getServerConfig();
    if (!provider.exists(configurationKey)) {
      return const TomOAuthStateStoreSettings();
    }
    final raw = provider.get(configurationKey);
    if (raw is! Map) {
      throw TomOAuthException(
        'oauth.config.state_store_not_a_map',
        "Configuration '$configurationKey' must be a map of settings, but was "
            'a ${raw.runtimeType}.',
      );
    }
    String? optional(String key) {
      final value = raw[key];
      if (value == null || '$value'.isEmpty) return null;
      return '$value';
    }

    final type = TomOAuthStateStoreType.parse(optional('type') ?? 'memory');
    final datasourceName = optional('datasource') ?? '';
    // Demanded rather than defaulted: there is no data source a store could
    // sensibly guess, and a deployment that asked for `sql` and named none has
    // made a mistake that must surface at startup instead of on the first login.
    if (type == TomOAuthStateStoreType.sql && datasourceName.isEmpty) {
      throw TomOAuthException(
        'oauth.config.missing_state_store_datasource',
        "Configuration '$configurationKey' selects the 'sql' state store but "
            "names no 'datasource'.",
      );
    }
    final seconds = optional('timeToLiveSeconds');
    return TomOAuthStateStoreSettings(
      type: type,
      datasourceName: datasourceName,
      table: optional('table') ?? defaultOAuthStateTable,
      timeToLive: seconds == null
          ? const Duration(minutes: 10)
          : Duration(seconds: _positiveSeconds(seconds)),
      createSchema: optional('createSchema') != 'false',
    );
  }

  /// Builds the store these settings describe.
  ///
  /// ```dart
  /// TomBean.withType<TomOAuthStateStore>(
  ///   TomOAuthStateStoreSettings.fromConfiguration().createStore(),
  /// );
  /// ```
  TomOAuthStateStore createStore() => switch (type) {
    TomOAuthStateStoreType.memory => TomOAuthMemoryStateStore(
      timeToLive: timeToLive,
    ),
    TomOAuthStateStoreType.sql => TomSqlOAuthStateStore.named(
      datasourceName,
      table: table,
      createSchema: createSchema,
      timeToLive: timeToLive,
    ),
  };

  /// [raw] as a positive whole number of seconds.
  static int _positiveSeconds(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      throw TomOAuthException(
        'oauth.config.invalid_state_store_ttl',
        "Configuration '$configurationKey.timeToLiveSeconds' must be a positive "
            "whole number of seconds, but was '$raw'.",
      );
    }
    return parsed;
  }

  @override
  String toString() => 'TomOAuthStateStoreSettings(${type.name})';
}

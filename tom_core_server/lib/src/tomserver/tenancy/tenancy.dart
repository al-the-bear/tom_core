/// Multi-tenancy: who the tenants are, where each one's data lives, and how a
/// request finds out which tenant it is for.
///
/// ## Three isolation models, one seam
///
/// | Model | Where a tenant's rows live | Isolation | Operating cost |
/// | ----- | -------------------------- | --------- | -------------- |
/// | [TomTenantIsolation.shared] | the shared schema of its type — the system schema for the type `default` — every tenant table carrying a tenant column | the row predicate | one schema per type, one migration per type |
/// | [TomTenantIsolation.schema] | a schema of its own on the shared server (on MariaDB, a database) | the schema boundary, and the predicate | one schema and one pool per tenant |
/// | [TomTenantIsolation.database] | a database of its own, configured per tenant — another server, another region | the server boundary, and the predicate | one database, one pool and one migration run per tenant |
///
/// The model is chosen **per tenant**: most tenants can share a schema while
/// the one with a data-residency requirement gets a database of its own. Every
/// model is reached through one seam — a repository asks for its data source,
/// and [TomTenancy.route] answers with the current tenant's — so application
/// code is the same under all three.
///
/// Only tenant tables (`@TomTenantTable`) are routed; a system table — every
/// other entity — is read and written in the system schema, the base data
/// source's own, also inside a tenant. The row predicate applies to every
/// tenant table in every model. Under the
/// schema and database models it is a second wall rather than the only one,
/// and it is what makes moving a tenant between models a copy of its rows
/// rather than a schema change.
///
/// ## What is tenant-scoped
///
/// | Concern | How |
/// | ------- | --- |
/// | Repositories | a tenant table (`@TomTenantTable`): the tenant predicate on every read and write, its data source routed per tenant; a system table: never routed |
/// | Caches | keys qualified by tenant (`TomCache`'s static API) |
/// | Principal revocation | per tenant: revoking `alice` in one tenant leaves another tenant's `alice` alone |
/// | Jobs | a run records its tenant and its body runs inside it, across isolates too |
/// | Messaging outbox | a queued message is delivered inside its tenant; receipts and delivery correlations name it |
///
/// Framework tables that serve the whole deployment — the job queue, the
/// leases, the OAuth state, the invalidation log — are not routed: they stay in
/// the data source they were built over, and carry the tenant as a column where
/// it matters.
library;

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import '../datasources/datasource_initialization.dart';
import '../datasources/sql_datasource.dart';
import '../db_migration/framework_convergence.dart';
import '../object_persistence/crud_repository.dart';
import '../db_migration/db_migration.dart';
import '../db_migration/migration_run.dart';
import '../db_migration/schema_versions.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/persistence_annotations.dart';
import 'tenant_data.dart';
import 'tenant_registry.dart';
import 'tenant_registry_sql.dart';
import 'tenant_resolution.dart';
import 'tenant_type.dart';

/// A tenancy configuration that cannot be used, or a tenant that does not
/// exist.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `tenancy.config.not_a_map` | `tenancy` or one of its tenants is not a map. |
/// | `tenancy.config.unknown_isolation` | An isolation model other than `shared`, `schema` or `database`. |
/// | `tenancy.config.unknown_resolver` | A tenant resolution other than `host`, `path` or `header`. |
/// | `tenancy.config.schema_unsupported` | Schema isolation over a data source whose settings name no `databaseName`. |
/// | `tenancy.config.invalid_schema` | A schema name that is not a plain identifier of at most 64 characters. |
/// | `tenancy.config.missing_datasource` | Database isolation without a data source for a routed name. |
/// | `tenancy.config.unknown_datasource` | A routed or referenced data source that is not registered. |
/// | `tenancy.config.invalid_registry` | A `registry.refreshSeconds` that is not a whole number of seconds, 0 or more. |
/// | `tenancy.tenant.unknown` | Work for a tenant the deployment does not have. |
/// | `tenancy.tenant.suspended` | A request for a suspended tenant (403). |
/// | `tenancy.tenant.unavailable` | A request for a tenant that is provisioning or migrating (503). |
/// | `tenancy.tenant.migration_failed` | A request for, or work in, a tenant whose migration failed (503) — not routed; or the migration of `addTenant` / `migrateTenant` failed. |
/// | `tenancy.tenant.not_removed` | `restoreTenant` of a tenant that is not removed. |
/// | `tenancy.purge.not_removed` | `purgeTenant` of a tenant that is not removed. |
/// | `tenancy.purge.retention` | `purgeTenant` before the tenant's retention period passed. |
/// | `tenancy.pool.cap_exceeded` | A tenant pool that would pass `tenancy.pool.maxTotal`. |
/// | `tenancy.config.invalid_number` | `purgeAfterDays` or a `pool` setting that is not a whole number in range. |
/// | `tenancy.tenant.schema_behind` | A request for a tenant whose schema is behind this server's code (503). |
/// | `tenancy.tenant.schema_ahead` | A request for a tenant whose schema is ahead of this server's code by a migration not marked expand (503). |
/// | `tenancy.config.schema_collision` | A schema-isolated tenant whose schema is a tenant type's shared schema. |
/// | `tenancy.type.invalid` | A tenant type name that is not a lowercase identifier of at most 32 characters. |
/// | `tenancy.type.unknown` | A tenant of a type the deployment does not declare. |
/// | `tenancy.type.missing_migrations` | A declared tenant type without a migration tree. |
/// | `tenancy.type.isolation_not_allowed` | A tenant whose isolation its type does not allow, or a type whose default isolation it does not allow. |
/// | `tenancy.type.change` | Adding a tenant the registry holds under another type; changing a type is a move. |
///
/// The registry's own keys are listed on [TomTenantRegistry].
class TomTenancyException extends TomServerException {
  /// Creates the exception.
  TomTenancyException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.clientThrow,
  });
}

/// Where a tenant's data lives.
enum TomTenantIsolation {
  /// In the shared database, separated by the tenant column.
  shared,

  /// In a schema of the tenant's own on the shared server.
  schema,

  /// In a database of the tenant's own.
  database;

  /// Parses a configured name; throws `tenancy.config.unknown_isolation`.
  static TomTenantIsolation parse(String raw) {
    for (final value in values) {
      if (value.name == raw.trim().toLowerCase()) return value;
    }
    throw TomTenancyException(
      'tenancy.config.unknown_isolation',
      'Unknown tenant isolation "$raw"; expected shared, schema or database.',
      parameters: {'isolation': raw},
    );
  }
}

/// One tenant of the deployment.
class TomTenant {
  /// Creates a tenant description.
  ///
  /// Throws `tenancy.id.invalid` for an [id] that is not a tenant id
  /// (`TomTenantContext.idPattern`).
  TomTenant(
    this.id, {
    this.type = defaultType,
    this.name,
    this.isolation,
    this.schema,
    this.datasources = const {},
  }) {
    TomTenantContext.validate(id);
  }

  /// The tenant's id — what the token's `tenant` claim names.
  final String id;

  /// The type of a tenant that names none.
  static const String defaultType = 'default';

  /// Its tenant type; [defaultType] unless it names one.
  final String type;

  /// A display name, or `null`.
  final String? name;

  /// Where its data lives, or `null` for the deployment's default.
  final TomTenantIsolation? isolation;

  /// Under schema isolation, the schema; `null` for `<database>_<id>`.
  final String? schema;

  /// Under database isolation, per routed data source name: the name of a
  /// registered data source (`String`) or the settings of one to open (`Map`).
  final Map<String, Object> datasources;

  /// Reads a tenant from its configuration [map].
  factory TomTenant.fromMap(String id, Map<Object?, Object?> map) {
    final rawDatasources = map['datasources'] ?? map['datasource'];
    final datasources = <String, Object>{};
    if (rawDatasources is Map) {
      rawDatasources.forEach((name, value) {
        datasources['$name'] = value is Map
            ? {for (final e in value.entries) '${e.key}': e.value}
            : '$value';
      });
    } else if (rawDatasources != null) {
      // One data source for the one routed name — the common case.
      datasources[''] = rawDatasources is Map
          ? {for (final e in rawDatasources.entries) '${e.key}': e.value}
          : '$rawDatasources';
    }
    return TomTenant(
      id,
      type: map['type'] == null ? defaultType : '${map['type']}',
      name: map['name'] == null ? null : '${map['name']}',
      isolation: map['isolation'] == null
          ? null
          : TomTenantIsolation.parse('${map['isolation']}'),
      schema: map['schema'] == null ? null : '${map['schema']}',
      datasources: datasources,
    );
  }

  @override
  String toString() => 'TomTenant($id)';
}

/// The deployment's tenants, how a request names one, and where each one's
/// data lives.
class TomTenancy {
  /// Creates the configuration.
  ///
  /// [datasources] names the data sources holding tenant data — those routed
  /// per tenant. [resolvers] read a tenant from a request that carries no
  /// token claim (see `tenant_resolution.dart`). With [createSchemas], a
  /// schema-isolated tenant's schema is created on the shared server when it
  /// is provisioned.
  ///
  /// [tenants] seed the [registry] (an in-memory one unless given): at
  /// [install] the registry's tenants are the ones served. With
  /// [refreshInterval], the installed tenancy re-reads the registry that often
  /// ([refreshFromRegistry]), so a tenant another node added or removed is
  /// served or dropped here too.
  ///
  /// [types] are the tenant types the deployment declares; without any, it
  /// has the one implicit type [TomTenant.defaultType], allowing every model
  /// and routing [datasources]. A declared type must have a migration tree
  /// ([TomTenantType.migrations]), checked by [install].
  TomTenancy({
    required Iterable<TomTenant> tenants,
    Iterable<TomTenantType> types = const [],
    this.datasources = const {'main'},
    this.resolvers = const [],
    this.defaultIsolation = TomTenantIsolation.shared,
    this.createSchemas = false,
    TomTenantRegistry? registry,
    this.refreshInterval,
    this.purgeAfter = defaultPurgeAfter,
    this.pool = const TomTenantPoolSettings(),
    DateTime Function()? clock,
  }) : types = Map.unmodifiable({
         for (final type
             in types.isEmpty ? [TomTenantType(TomTenant.defaultType)] : types)
           type.name: type,
       }),
       typesDeclared = types.isNotEmpty,
       tenants = {for (final tenant in tenants) tenant.id: tenant},
       _configured = {for (final tenant in tenants) tenant.id: tenant},
       registry = registry ?? TomMemoryTenantRegistry(),
       _clock = clock ?? DateTime.now;

  /// The configuration path of the tenancy settings.
  static const String configurationKey = 'tenancy';

  /// The tenants served, by id: the registry's tenants that are not removed,
  /// once [install] has read it; the configured ones before.
  final Map<String, TomTenant> tenants;

  /// The tenants the configuration names — the registry's seed.
  final Map<String, TomTenant> _configured;

  /// The durable list of tenants ([TomTenantRegistry]).
  final TomTenantRegistry registry;

  /// How often the installed tenancy re-reads [registry], or `null` for never.
  final Duration? refreshInterval;

  /// How long a removed tenant's data is kept before [purgeTenant] may drop
  /// it — while it is, [restoreTenant] serves the tenant again.
  final Duration purgeAfter;

  /// The default of [purgeAfter]: ninety days.
  static const Duration defaultPurgeAfter = Duration(days: 90);

  /// How the pools this tenancy opens for tenants are sized
  /// ([TomTenantPoolSettings]).
  final TomTenantPoolSettings pool;

  /// The `poolMaxSize` of each tenant pool this tenancy opened, by registry
  /// name — what [TomTenantPoolSettings.maxTotal] caps.
  final Map<String, int> _pooled = {};

  final DateTime Function() _clock;

  /// The status of each served tenant, as the registry records it.
  final Map<String, TomTenantStatus> _statuses = {};

  /// The configured tenants their registry rows contradicted at the last
  /// [install] — the rows were used.
  List<TomTenantRegistryConflict> registryConflicts = const [];

  Timer? _refreshTimer;
  bool _refreshing = false;

  /// The data sources routed for a type that names none — the implicit
  /// type's, in a deployment that declares no types.
  final Set<String> datasources;

  /// The tenant types, by name: the declared ones, or the implicit
  /// [TomTenant.defaultType] alone.
  final Map<String, TomTenantType> types;

  /// Whether [types] were declared rather than implicit.
  final bool typesDeclared;

  /// Every data source some type routes.
  Set<String> get routedDatasources => {
    for (final type in types.values) ...?type.datasources,
    if (types.values.any((type) => type.datasources == null)) ...datasources,
  };

  /// The data sources the type [type] routes.
  Set<String> datasourcesOf(TomTenantType type) =>
      type.datasources ?? datasources;

  /// How a request without a token claim names its tenant, in order.
  final List<TomTenantResolver> resolvers;

  /// The isolation of a tenant that names none.
  final TomTenantIsolation defaultIsolation;

  /// Whether schema isolation creates the tenant's schema.
  final bool createSchemas;

  /// The routed data source per (data source name, tenant id).
  final Map<(String, String), TomDataSourceInfo> _routes = {};

  /// The pool over a type's shared schema per (data source name, type name).
  final Map<(String, String), TomDataSourceInfo> _sharedPools = {};

  /// The data sources this configuration opened, closed by [reset].
  final List<TomDataSourceInfo> _opened = [];

  static TomTenancy? _installed;

  /// The installed configuration, or `null` in a deployment without tenancy.
  static TomTenancy? get current => _installed;

  /// Reads `tenancy` from the configuration tree:
  ///
  /// ```yaml
  /// tenancy:
  ///   isolation: shared              # the default model
  ///   datasources: [main]            # the data sources holding tenant data
  ///   resolution: [host, path, header]  # after the token claim, in order
  ///   hostSuffix: app.example.com    # <tenant>.app.example.com
  ///   pathPrefix: t                  # /t/<segment>/…
  ///   pathSegments: {acme-gmbh: acme}  # segment → tenant id; omit: segment = id
  ///   header: X-Tenant-Id
  ///   createSchemas: true
  ///   registry: {datasource: main, refreshSeconds: 30}  # or: memory
  ///   purgeAfterDays: 90             # how long a removed tenant's data stays
  ///   pool: {perTenant: 4, idleSeconds: 60, maxTotal: 200}  # tenant pools
  ///   migrations: migrations         # a type's tree: <root>/tenant/<type>
  ///   types:                         # none declared: the implicit type 'default'
  ///     standard: {isolation: shared, isolations: [shared, schema]}
  ///     enterprise: {isolation: database, datasources: [main, reporting]}
  ///   tenants:
  ///     acme: {}
  ///     globex: {isolation: schema}
  ///     initech:
  ///       isolation: database
  ///       datasource: {type: mariadb, host: db.eu.example.com, ...}
  /// ```
  factory TomTenancy.fromConfiguration([
    TomServerConfigResourceProvider? config,
  ]) {
    final provider =
        config ?? TomServerConfigResourceProvider.getServerConfig();
    final raw = provider.exists(configurationKey)
        ? provider.get(configurationKey)
        : const <Object?, Object?>{};
    if (raw is! Map) throw _notAMap(configurationKey);
    final rawTenants = raw['tenants'] ?? const <Object?, Object?>{};
    if (rawTenants is! Map) throw _notAMap('$configurationKey.tenants');
    final tenants = [
      for (final entry in rawTenants.entries)
        TomTenant.fromMap(
          '${entry.key}',
          entry.value == null
              ? const {}
              : entry.value is Map
              ? entry.value as Map<Object?, Object?>
              : throw _notAMap('$configurationKey.tenants.${entry.key}'),
        ),
    ];
    final routed = raw['datasources'] is List
        ? {for (final name in raw['datasources'] as List) '$name'}
        : const {'main'};
    final registry = _registryOf(raw, routed);
    final types = _typesOf(raw);
    final resolution = raw['resolution'];
    final names = resolution is List
        ? [for (final name in resolution) '$name']
        : resolution == null
        ? const <String>[]
        : ['$resolution'];
    return TomTenancy(
      tenants: tenants,
      types: types,
      datasources: routed,
      resolvers: [
        for (final name in names)
          switch (name) {
            'host' => TomTenantHostResolver(
              suffix: raw['hostSuffix'] == null ? null : '${raw['hostSuffix']}',
            ),
            'path' => _pathResolver(raw),
            'header' => TomTenantHeaderResolver(
              header: raw['header'] == null
                  ? TomTenantHeaderResolver.defaultHeader
                  : '${raw['header']}',
            ),
            _ => throw TomTenancyException(
              'tenancy.config.unknown_resolver',
              'Unknown tenant resolution "$name"; expected host, path or header.',
              parameters: {'resolver': name},
            ),
          },
      ],
      defaultIsolation: raw['isolation'] == null
          ? TomTenantIsolation.shared
          : TomTenantIsolation.parse('${raw['isolation']}'),
      createSchemas: '${raw['createSchemas']}' == 'true',
      registry: registry.$1,
      refreshInterval: registry.$2,
      purgeAfter: raw['purgeAfterDays'] == null
          ? defaultPurgeAfter
          : Duration(days: _wholeNumber(raw, 'purgeAfterDays')),
      pool: raw['pool'] == null
          ? const TomTenantPoolSettings()
          : TomTenantPoolSettings.fromMap(
              raw['pool'] is Map
                  ? raw['pool'] as Map<Object?, Object?>
                  : throw _notAMap('$configurationKey.pool'),
            ),
    );
  }

  static int _wholeNumber(Map<Object?, Object?> raw, String key) {
    final value = raw[key];
    final number = value is int ? value : int.tryParse('$value');
    if (number == null || number < 0) {
      throw TomTenancyException(
        'tenancy.config.invalid_number',
        "The tenancy setting '$key' must be a whole number, not '$value'.",
        parameters: {'key': key, 'value': '$value'},
      );
    }
    return number;
  }

  /// The registry the configuration [raw] names, and how often to refresh
  /// from it: `registry: memory` keeps the tenants in the process; otherwise
  /// (also when `registry` is absent) a [TomSqlTenantRegistry] in the system
  /// schema — the base schema of `registry.datasource`, by default the first
  /// routed data source — refreshed every `refreshSeconds` (default 30, `0`
  /// for never).
  static (TomTenantRegistry, Duration?) _registryOf(
    Map<Object?, Object?> raw,
    Set<String> routed,
  ) {
    final config = raw['registry'];
    if ('$config' == 'memory') return (TomMemoryTenantRegistry(), null);
    if (config != null && config is! Map) {
      throw _notAMap('$configurationKey.registry');
    }
    final settings = (config as Map?) ?? const <Object?, Object?>{};
    final seconds = settings['refreshSeconds'] == null
        ? defaultRefreshSeconds
        : int.tryParse('${settings['refreshSeconds']}');
    if (seconds == null || seconds < 0) {
      throw TomTenancyException(
        'tenancy.config.invalid_registry',
        "Configuration '$configurationKey.registry.refreshSeconds' must be a "
            'whole number of seconds, 0 or more.',
        parameters: {'refreshSeconds': settings['refreshSeconds']},
      );
    }
    final registry = TomSqlTenantRegistry.named(
      '${settings['datasource'] ?? routed.first}',
      table: '${settings['table'] ?? defaultTenantTable}',
      createSchema: '${settings['createSchema']}' != 'false',
    );
    return (registry, seconds == 0 ? null : Duration(seconds: seconds));
  }

  /// The types `tenancy.types` declares, each with its tree under
  /// `tenancy.migrations` unless it names its own `migrations`.
  static List<TomTenantType> _typesOf(Map<Object?, Object?> raw) {
    final rawTypes = raw['types'];
    if (rawTypes == null) return const [];
    if (rawTypes is! Map) throw _notAMap('$configurationKey.types');
    final root = raw['migrations'] == null ? null : '${raw['migrations']}';
    return [
      for (final entry in rawTypes.entries)
        TomTenantType.fromMap(
          '${entry.key}',
          entry.value == null
              ? const {}
              : entry.value is Map
              ? entry.value as Map<Object?, Object?>
              : throw _notAMap('$configurationKey.types.${entry.key}'),
          migrationsRoot: root,
        ),
    ];
  }

  /// How often a configured tenancy refreshes from its registry, in seconds.
  static const int defaultRefreshSeconds = 30;

  static TomTenancyException _notAMap(String key) => TomTenancyException(
    'tenancy.config.not_a_map',
    "Configuration '$key' must be a map.",
    parameters: {'key': key},
  );

  /// Installs [tenancy]: reads its [registry] — seeding it with the
  /// configured tenants it does not hold yet, and reporting a configured
  /// tenant its row contradicts in [registryConflicts] — provisions every
  /// tenant the registry holds and has not removed, routes data source lookups
  /// through it, and starts refreshing from the registry when
  /// [refreshInterval] is set. Replaces (and resets) any configuration
  /// installed before.
  ///
  /// Refused — before the registry is read — when a declared type has no
  /// migration tree (`tenancy.type.missing_migrations`), and when a tenant the
  /// registry serves is of an unknown type (`tenancy.type.unknown`) or uses an
  /// isolation its type does not allow (`tenancy.type.isolation_not_allowed`).
  static Future<void> install(TomTenancy tenancy) async {
    await reset();
    if (tenancy.typesDeclared) {
      for (final type in tenancy.types.values) {
        type.verifyMigrations();
      }
    }
    // The configured tenants first, so a refused one is never seeded.
    for (final tenant in tenancy._configured.values) {
      tenancy.validateTenant(tenant);
    }
    await tenancy._readRegistry();
    for (final tenant in tenancy.tenants.values) {
      tenancy.validateTenant(tenant);
    }
    for (final tenant in tenancy.tenants.values) {
      await tenancy._provision(tenant);
    }
    await tenancy.checkSchemaVersions();
    _installed = tenancy;
    TomDataSourceInfo.router = tenancy.route;
    TomScheduler.tenantGate = tenancy.servesWork;
    TomScheduler.tenantsFor = tenancy.activeTenantsOf;
    tenancy._startRefreshing();
  }

  /// Reads [registry] into [tenants]: the configured tenants it lacks are
  /// written into it as active; the configured ones it holds differently are
  /// reported, and the registry's version is used.
  Future<void> _readRegistry() async {
    final now = _clock().toUtc();
    final records = {for (final r in await registry.all()) r.id: r};
    final conflicts = <TomTenantRegistryConflict>[];
    for (final configured in _configured.values) {
      final record = records[configured.id];
      if (record == null) {
        final seeded = TomTenantRecord.of(
          configured,
          TomTenantStatus.active,
          now,
        );
        await registry.put(seeded);
        records[configured.id] = seeded;
        continue;
      }
      final differences = {
        ...record.differencesFrom(configured),
        if (record.status == TomTenantStatus.removed)
          'status': ('configured', record.status.wireName),
      };
      if (differences.isNotEmpty) {
        conflicts.add(TomTenantRegistryConflict(configured.id, differences));
        tomLog.warn(
          "Tenancy: the configuration's tenant '${configured.id}' differs "
          'from its registry row in ${differences.keys.join(', ')}; the '
          'registry row is used.',
        );
      }
    }
    registryConflicts = List.unmodifiable(conflicts);
    tenants.clear();
    _statuses.clear();
    for (final record in records.values) {
      if (record.status == TomTenantStatus.removed) continue;
      tenants[record.id] = record.toTenant(configured: _configured[record.id]);
      _statuses[record.id] = record.status;
    }
  }

  void _startRefreshing() {
    final interval = refreshInterval;
    if (interval == null) return;
    _refreshTimer = Timer.periodic(interval, (_) async {
      if (_refreshing) return;
      _refreshing = true;
      try {
        await refreshFromRegistry();
      } catch (error, stack) {
        tomLog.warn('Tenancy: refreshing from the registry failed: $error');
        tomLog.debug('$stack');
      } finally {
        _refreshing = false;
      }
    });
  }

  /// Re-reads [registry] and brings this node's routing level with it: a
  /// tenant another node added is provisioned and served, one it removed is
  /// unrouted (its pools closed), and a changed status takes effect. A tenant
  /// that cannot be provisioned here is reported in the result and tried again
  /// at the next refresh.
  Future<TomTenantRegistryRefresh> refreshFromRegistry() async {
    final added = <String>[];
    final removed = <String>[];
    final changed = <String>[];
    final failed = <String, Object>{};
    final records = {for (final r in await registry.all()) r.id: r};
    for (final record in records.values) {
      final local = tenants[record.id];
      if (record.status == TomTenantStatus.removed) {
        if (local == null) continue;
        await _unroute(record.id);
        removed.add(record.id);
      } else if (local == null) {
        final tenant = record.toTenant(configured: _configured[record.id]);
        try {
          validateTenant(tenant);
          await _provision(tenant);
        } catch (error) {
          failed[record.id] = error;
          continue;
        }
        tenants[record.id] = tenant;
        _statuses[record.id] = record.status;
        added.add(record.id);
      } else if (_statuses[record.id] != record.status) {
        _statuses[record.id] = record.status;
        changed.add(record.id);
      }
    }
    for (final id in List.of(tenants.keys)) {
      if (records.containsKey(id)) continue;
      await _unroute(id);
      removed.add(id);
    }
    await checkSchemaVersions();
    return TomTenantRegistryRefresh(
      added: added,
      removed: removed,
      changed: changed,
      failed: failed,
    );
  }

  /// Removes the installed configuration and closes the data sources it
  /// opened.
  static Future<void> reset() async {
    final previous = _installed;
    _installed = null;
    TomDataSourceInfo.router = null;
    TomScheduler.tenantGate = null;
    TomScheduler.tenantsFor = null;
    if (previous == null) return;
    previous._refreshTimer?.cancel();
    previous._refreshTimer = null;
    for (final info in previous._opened) {
      TomDataSourceInfo.datasources.remove(info.name);
      await info.datasource.close();
    }
    previous._opened.clear();
    previous._pooled.clear();
    previous._routes.clear();
    previous._sharedPools.clear();
  }

  /// Adds [tenant] to the running deployment — onboarding without a restart —
  /// and answers its migration run (`null` when its type has no tree).
  ///
  /// In order: the tenant is recorded in the [registry] as `provisioning`, its
  /// schema or database is provisioned, it is migrated by its type's tree
  /// ([migrateTenant]: `migrating`, then `active`), and it is served. Every
  /// node refreshing from the registry serves it from its next refresh.
  ///
  /// A provisioning that fails leaves it `provisioning` in the registry, with
  /// the error as its status detail, unserved, and rethrows. A migration that
  /// fails leaves it `migration-failed` — refused
  /// (`tenancy.tenant.migration_failed`, 503) and not routed — and throws
  /// `tenancy.tenant.migration_failed`; [migrateTenant] tries again.
  ///
  /// Refused before anything is recorded for a tenant of an unknown type, an
  /// isolation its type does not allow, and a tenant the registry holds — not
  /// removed — under another type (`tenancy.type.change`): a type is not
  /// changed in place. A removed tenant whose data was not purged is added
  /// back over its old schema or database ([restoreTenant]).
  Future<TomMigrationRun?> addTenant(TomTenant tenant) async {
    validateTenant(tenant);
    final now = _clock().toUtc();
    final existing = await registry.find(tenant.id);
    if (existing != null &&
        existing.status != TomTenantStatus.removed &&
        existing.type != tenant.type) {
      throw TomTenancyException(
        'tenancy.type.change',
        "Tenant '${tenant.id}' is of type '${existing.type}'; changing its "
            "type to '${tenant.type}' is a move, not an edit.",
        parameters: {
          'tenant': tenant.id,
          'type': existing.type,
          'requested': tenant.type,
        },
      );
    }
    await registry.put(
      TomTenantRecord.of(
        tenant,
        TomTenantStatus.provisioning,
        now,
      ).copyWithCreated(existing?.createdAt),
    );
    try {
      await _provision(tenant);
    } catch (error) {
      await registry.setStatus(
        tenant.id,
        TomTenantStatus.provisioning,
        detail: '$error',
        at: _clock().toUtc(),
      );
      rethrow;
    }
    tenants[tenant.id] = tenant;
    _statuses[tenant.id] = TomTenantStatus.provisioning;
    return migrateTenant(tenant.id);
  }

  /// Migrates the tenant [tenantId] by its type's tree
  /// ([TomDbMigrations.migrateTenant]): `migrating`, then `active`, or
  /// `migration-failed` with the error, which throws
  /// `tenancy.tenant.migration_failed` (a tree refused before it ran throws
  /// its own key, the tenant `migration-failed` as well). Answers the run, or
  /// `null` when the type has no tree to apply — the tenant then `active`,
  /// unless suspended. The retry of a tenant whose migration failed.
  Future<TomMigrationRun?> migrateTenant(String tenantId) async {
    if (!tenants.containsKey(tenantId)) throw unknownTenant(tenantId);
    final TomMigrationRun? run;
    try {
      run = await TomDbMigrations.migrateTenant(tenantId, tenancy: this);
    } catch (error) {
      // Refused before the target ran — a tree that does not fit the type.
      await setStatus(
        tenantId,
        TomTenantStatus.migrationFailed,
        detail: '$error',
      );
      rethrow;
    }
    if (run == null) {
      if (_statuses[tenantId] != TomTenantStatus.suspended) {
        await setStatus(tenantId, TomTenantStatus.active);
      }
      await checkSchemaVersions([tenantId]);
      return null;
    }
    if (run.state == TomMigrationRunState.failed) {
      throw TomTenancyException(
        'tenancy.tenant.migration_failed',
        "The migration of tenant '$tenantId' failed: ${run.error}",
        parameters: {'tenant': tenantId, 'error': run.error},
      );
    }
    return run;
  }

  /// Serves the removed tenant [tenantId] again, over the schema or database
  /// it left — as [addTenant] with its registry row, provisioned and migrated
  /// again. Possible until [purgeTenant] dropped its data.
  ///
  /// Throws `tenancy.tenant.unknown` for a tenant the registry does not hold
  /// and `tenancy.tenant.not_removed` for one that is not removed.
  Future<TomMigrationRun?> restoreTenant(String tenantId) async {
    final record = await registry.find(tenantId);
    if (record == null) throw unknownTenant(tenantId);
    if (record.status != TomTenantStatus.removed) {
      throw TomTenancyException(
        'tenancy.tenant.not_removed',
        "Tenant '$tenantId' is ${record.status.wireName}, not removed.",
        parameters: {'tenant': tenantId, 'status': record.status.wireName},
      );
    }
    return addTenant(record.toTenant(configured: _configured[tenantId]));
  }

  /// Suspends the tenant [tenantId]: recorded in the [registry] first, then its
  /// requests are refused as `tenancy.tenant.suspended` (403). Its data and
  /// routes stay, so [resumeTenant] serves it again at once.
  ///
  /// Throws `tenancy.tenant.unknown` for a tenant the deployment does not have.
  Future<void> suspendTenant(String tenantId) =>
      setStatus(tenantId, TomTenantStatus.suspended);

  /// Serves the suspended tenant [tenantId] again, recorded in the [registry]
  /// first.
  ///
  /// Throws `tenancy.tenant.unknown` for a tenant the deployment does not have.
  Future<void> resumeTenant(String tenantId) =>
      setStatus(tenantId, TomTenantStatus.active);

  /// Sets the served tenant [tenantId]'s status to [status], with [detail]
  /// (cleared when `null`): recorded in the [registry] first, then served
  /// accordingly on this node. The migration run moves a tenant through
  /// `migrating` to `active` or `migration-failed` this way.
  ///
  /// Throws `tenancy.tenant.unknown` for a tenant the deployment does not have.
  Future<void> setStatus(
    String tenantId,
    TomTenantStatus status, {
    String? detail,
  }) async {
    if (!tenants.containsKey(tenantId)) throw unknownTenant(tenantId);
    await registry.setStatus(
      tenantId,
      status,
      detail: detail,
      at: _clock().toUtc(),
    );
    _statuses[tenantId] = status;
  }

  /// The registry status of the served tenant [tenantId], or `null` for a
  /// tenant the deployment does not have.
  TomTenantStatus? statusOf(String tenantId) => _statuses[tenantId];

  /// Whether queued work of [tenantId] runs now on this node — the
  /// scheduler's [TomScheduler.tenantGate] while this tenancy is installed: a
  /// served, `active` tenant's runs do; a suspended one's are held, and so are
  /// a tenant's this node does not serve (yet).
  bool servesWork(String tenantId) =>
      tenants.containsKey(tenantId) &&
      (_statuses[tenantId] ?? TomTenantStatus.active) == TomTenantStatus.active;

  /// The served, `active` tenants whose type is one of [types] — of every
  /// type when [types] is empty — in id order: what a job planned per tenant
  /// ([TomJobDefinition.tenants]) is planned for, as the scheduler's
  /// [TomScheduler.tenantsFor] while this tenancy is installed.
  List<String> activeTenantsOf(List<String> types) => [
    for (final id in tenants.keys.toList()..sort())
      if (servesWork(id) &&
          (types.isEmpty || types.contains(tenants[id]!.type)))
        id,
  ];

  final Map<String, TomSchemaVersionCheck> _schemaChecks = {};
  final Map<String, Map<String, int>> _codeVersions = {};

  /// How the served tenant [tenantId]'s schema stands against this code's
  /// type tree, as last checked ([checkSchemaVersions]), or `null` for a
  /// tenant not checked.
  TomSchemaVersionCheck? schemaCheckOf(String tenantId) =>
      _schemaChecks[tenantId];

  /// Every served tenant's last schema check, by tenant id.
  Map<String, TomSchemaVersionCheck> get schemaChecks =>
      Map.unmodifiable(_schemaChecks);

  /// The highest version of each `<datasource>` chain of [type]'s tree that
  /// this code carries for the active environment
  /// ([TomDbMigrations.treeVersions]); empty for a type without a tree.
  Map<String, int> codeVersionsOf(TomTenantType type) =>
      _codeVersions[type.name] ??= type.migrations == null
      ? const {}
      : TomDbMigrations.treeVersions(
          Directory(type.migrations!),
          TomDbMigrations.resolveActiveEnvironment(),
        );

  /// Compares the schema of each served tenant — [tenantIds], or all — with
  /// this code: per data source of its type's tree, the code's highest version
  /// against the one the [registry] records (`migrated[<datasource>]`), and
  /// for a schema ahead, the lowest code version it serves
  /// (`migrated[<datasource>/requires]`, written by
  /// [TomDbMigrations.migrateAll]; a record without it serves only its own
  /// version). A tenant [TomSchemaSkew.behind] or
  /// [TomSchemaSkew.aheadIncompatible] is refused
  /// (`tenancy.tenant.schema_behind` / `tenancy.tenant.schema_ahead`, 503)
  /// while the others are served. Run at [install], on [refreshFromRegistry]
  /// and by `migrateAll` after each target.
  Future<void> checkSchemaVersions([Iterable<String>? tenantIds]) async {
    final wanted = tenantIds?.toSet();
    final records = {for (final r in await registry.all()) r.id: r};
    for (final tenant in List.of(tenants.values)) {
      if (wanted != null && !wanted.contains(tenant.id)) continue;
      final code = codeVersionsOf(typeOf(tenant));
      final migrated = records[tenant.id]?.migrated ?? const <String, int>{};
      final recorded = <String, int>{};
      final requires = <String, int>{};
      final skews = <TomSchemaSkew>[];
      for (final MapEntry(key: datasource, value: version) in code.entries) {
        final at = migrated[datasource];
        final from = migrated[TomDbMigrations.requiresKey(datasource)];
        if (at != null) recorded[datasource] = at;
        if (from != null) requires[datasource] = from;
        skews.add(TomSchemaVersionCheck.skewOf(version, at, from));
      }
      final check = TomSchemaVersionCheck(
        TomMigrationRun.tenantTarget(tenant.id),
        TomSchemaVersionCheck.worst(skews),
        code: code,
        recorded: recorded,
        requires: requires,
      );
      final before = _schemaChecks[tenant.id]?.skew;
      _schemaChecks[tenant.id] = check;
      if (before != check.skew && check.skew != TomSchemaSkew.current) {
        tomLog.warn(
          'Tenancy: the schema of ${check.target} is ${check.detail}',
        );
      }
    }
  }

  /// Removes the tenant [tenantId] from the running deployment — the
  /// counterpart of [addTenant].
  ///
  /// In order: the tenant is recorded as `removed`; it leaves [tenants], so a
  /// request naming it — by its token's claim, its host, its path or a
  /// header — is refused as `tenancy.tenant.unknown` (404) and [route]
  /// refuses it for work still in context; its routes are dropped; the data
  /// sources this tenancy opened for it are unregistered and closed, which
  /// closes their connection pools; and its queued runs are cancelled in the
  /// job stores of the started schedulers and [jobStores]
  /// ([TomJobStore.cancelTenantRuns]). A data source the tenant only named by
  /// reference is the deployment's and stays open. Other tenants are
  /// untouched.
  ///
  /// The tenant's data is left where it is for [purgeAfter]: [restoreTenant]
  /// serves it again meanwhile, and [purgeTenant] drops it afterwards. Work
  /// that is still running in the tenant when its pools close fails; a
  /// caller that needs it to finish suspends the tenant first and removes it
  /// afterwards.
  ///
  /// Throws `tenancy.tenant.unknown` for a tenant the deployment does not have.
  Future<TomTenant> removeTenant(
    String tenantId, {
    Iterable<TomJobStore> jobStores = const [],
  }) async {
    final tenant = tenants[tenantId];
    if (tenant == null) throw unknownTenant(tenantId);
    final now = _clock().toUtc();
    await registry.setStatus(tenantId, TomTenantStatus.removed, at: now);
    await _unroute(tenantId);
    for (final store in _jobStores(jobStores)) {
      final cancelled = await store.cancelTenantRuns(tenantId, now);
      if (cancelled > 0) {
        tomLog.info(
          "Tenancy: cancelled $cancelled queued run(s) of removed tenant "
          "'$tenantId'.",
        );
      }
    }
    return tenant;
  }

  /// The job stores of the started schedulers ([TomScheduler.started]) and
  /// [extra], each once.
  static Set<TomJobStore> _jobStores(Iterable<TomJobStore> extra) =>
      Set.identity()..addAll([
        for (final scheduler in TomScheduler.started) scheduler.store,
        ...extra,
      ]);

  /// Deletes the data of the removed tenant [tenantId] for good, once
  /// [purgeAfter] has passed since its removal (or at once with [force]),
  /// and answers what was done:
  ///
  /// - a `schema` tenant's schema is dropped on each data source its type
  ///   routes — `DROP DATABASE` on MariaDB, `DROP SCHEMA … CASCADE` on
  ///   PostgreSQL ([TomStandardSqlDialect.dropSchema]);
  /// - a `database` tenant's database is dropped when the tenancy opened it on
  ///   the base data source's server ([TomStandardSqlDialect.dropDatabase]);
  ///   a database named by reference, or on another server, is the
  ///   deployment's and is kept, and reported;
  /// - a `shared` tenant's rows are deleted from every tenant table of its
  ///   type's shared schema — the application's (`@TomTenantTable`, by its
  ///   tenant column) and the framework's ([frameworkTenantTables], by
  ///   `tenant`);
  /// - its records in system tables are deleted through [stores] and the job
  ///   stores — the started schedulers' and [jobStores] — each
  ///   [TomTenantData.purgeTenant];
  /// - its registry row is deleted.
  ///
  /// The audit trail is kept: its hash chain is not rewritten. The personal
  ///   values it sealed for the tenant's data subjects become unreadable,
  ///   because their subject keys were in the tenant's own tables.
  ///
  /// Throws `tenancy.tenant.unknown` for a tenant the registry does not hold,
  /// `tenancy.purge.not_removed` for one not removed, and
  /// `tenancy.purge.retention` while its retention period runs.
  Future<TomTenantPurgeReport> purgeTenant(
    String tenantId, {
    bool force = false,
    Iterable<TomTenantData> stores = const [],
    Iterable<TomJobStore> jobStores = const [],
  }) async {
    final record = await registry.find(tenantId);
    if (record == null) throw unknownTenant(tenantId);
    if (record.status != TomTenantStatus.removed) {
      throw TomTenancyException(
        'tenancy.purge.not_removed',
        "Tenant '$tenantId' is ${record.status.wireName}; only a removed "
            'tenant is purged.',
        parameters: {'tenant': tenantId, 'status': record.status.wireName},
      );
    }
    final now = _clock().toUtc();
    final due = record.updatedAt.add(purgeAfter);
    if (!force && now.isBefore(due)) {
      throw TomTenancyException(
        'tenancy.purge.retention',
        "Tenant '$tenantId' was removed at ${record.updatedAt}; its data is "
            'kept until $due.',
        parameters: {'tenant': tenantId, 'until': due.toIso8601String()},
      );
    }
    final tenant = record.toTenant(configured: _configured[tenantId]);
    final type = types[tenant.type];
    final isolation = tenant.isolation ?? type?.isolation ?? defaultIsolation;
    final dropped = <String>[];
    final kept = <String>[];
    final deleted = <String, int>{};
    for (final name in type == null ? datasources : datasourcesOf(type)) {
      final reference = tenant.datasources[name] ?? tenant.datasources[''];
      if (isolation == TomTenantIsolation.database && reference is String) {
        kept.add("$name: data source '$reference', the deployment's");
        continue;
      }
      final base = TomDataSourceInfo.getBaseDataSourceInfo(name);
      if (base == null) {
        kept.add('$name: not registered');
        continue;
      }
      final datasource = base.datasource;
      if (datasource is! TomSqlDatasource) {
        kept.add('$name: not a SQL data source');
        continue;
      }
      final dialect = datasource.sqlDialect;
      switch (isolation) {
        case TomTenantIsolation.schema:
          final schema = schemaNameOf(base, tenant);
          await datasource.executeCommand(dialect.dropSchema(schema));
          dropped.add('$name: schema $schema');
        case TomTenantIsolation.database:
          final configured = reference;
          final database = configured is Map
              ? configured['databaseName']
              : null;
          final sameServer =
              configured is Map &&
              '${configured['host'] ?? ''}' == datasource.host &&
              '${configured['port'] ?? datasource.port}' ==
                  '${datasource.port}';
          if (database == null || !sameServer) {
            kept.add('$name: database ${database ?? '?'} on another server');
            continue;
          }
          await datasource.executeCommand(dialect.dropDatabase('$database'));
          dropped.add('$name: database $database');
        case TomTenantIsolation.shared:
          final pool = type == null || type.name == TomTenant.defaultType
              ? base
              : await _sharedOf(base, type);
          deleted.addAll(await _deleteSharedRows(pool, name, tenantId));
      }
    }
    for (final store in <Object>{...stores, ..._jobStores(jobStores)}) {
      final count = store is TomTenantData
          ? await store.purgeTenant(tenantId)
          : await (store as TomJobStore).purgeTenant(tenantId);
      deleted['${store.runtimeType}'] =
          (deleted['${store.runtimeType}'] ?? 0) + count;
    }
    await registry.delete(tenantId);
    final report = TomTenantPurgeReport(
      tenantId,
      dropped: dropped,
      kept: kept,
      deleted: deleted,
    );
    tomLog.info('Tenancy: purged $report');
    return report;
  }

  /// Deletes [tenantId]'s rows from every tenant table of the shared schema
  /// [pool] reaches for the data source [name]: the application's
  /// (`@TomTenantTable`) and the framework's, where they exist.
  Future<Map<String, int>> _deleteSharedRows(
    TomDataSourceInfo pool,
    String name,
    String tenantId,
  ) async {
    final deleted = <String, int>{};
    final datasource = pool.datasource;
    final tables = <String, String>{
      for (final MapEntry(key: entity, value: table) in tenantTables.entries)
        if (table.datasource == name) table.table: _tenantColumnOf(entity),
      for (final table in frameworkTenantTables()) table.name: 'tenant',
    };
    for (final MapEntry(key: table, value: column) in tables.entries) {
      final exists = await datasource.executeQuery<TomCountResult>(
        'SELECT COUNT(*) AS count FROM information_schema.tables '
        'WHERE table_schema = ${datasource.sqlDialect.currentSchema} '
        'AND LOWER(table_name) = :table',
        {'table': table.toLowerCase()},
      );
      if (exists.single.count == 0) continue;
      final rows = await datasource.executeCommand(
        'DELETE FROM $table WHERE $column = :tenant',
        {'tenant': tenantId},
      );
      if (rows > BigInt.zero) deleted[table] = rows.toInt();
    }
    return deleted;
  }

  /// The column of [entity]'s tenant field ([TomTenantTable.field]).
  static String _tenantColumnOf(Type entity) {
    final field = TomAnnotationAnalyzer.findTenantTable(entity)!.field;
    return TomAnnotationAnalyzer.getPersistentColumns(
      entity,
    )!.firstWhere((c) => c.declaredName == field).field;
  }

  /// Stops serving [tenantId] on this node: it leaves [tenants], its routes are
  /// dropped, and the data sources this tenancy opened for it are closed.
  Future<void> _unroute(String tenantId) async {
    tenants.remove(tenantId);
    _statuses.remove(tenantId);
    _schemaChecks.remove(tenantId);
    _routes.removeWhere((key, _) => key.$2 == tenantId);
    final owned = [
      for (final info in _opened)
        if (info.name.endsWith('@$tenantId')) info,
    ];
    for (final info in owned) {
      _opened.remove(info);
      _pooled.remove(info.name);
      TomDataSourceInfo.datasources.remove(info.name);
      await info.datasource.close();
    }
  }

  /// The isolation [tenant] runs under: its own, else its type's default,
  /// else the deployment's [defaultIsolation].
  ///
  /// Throws `tenancy.type.unknown` for a tenant of an undeclared type.
  TomTenantIsolation isolationOf(TomTenant tenant) =>
      tenant.isolation ?? typeOf(tenant).isolation ?? defaultIsolation;

  /// The declared type of [tenant].
  ///
  /// Throws `tenancy.type.unknown` for a type the deployment does not
  /// declare.
  TomTenantType typeOf(TomTenant tenant) {
    final type = types[tenant.type];
    if (type != null) return type;
    throw TomTenancyException(
      'tenancy.type.unknown',
      "Tenant '${tenant.id}' is of type '${tenant.type}', which the "
          'deployment does not declare.',
      parameters: {'tenant': tenant.id, 'type': tenant.type},
    );
  }

  /// Throws unless [tenant] can be served: its type is declared
  /// (`tenancy.type.unknown`) and allows its isolation
  /// (`tenancy.type.isolation_not_allowed`).
  void validateTenant(TomTenant tenant) {
    final type = typeOf(tenant);
    final isolation = isolationOf(tenant);
    if (!type.isolations.contains(isolation)) {
      throw TomTenantType.isolationNotAllowed(
        type.name,
        isolation,
        "tenant '${tenant.id}''s",
      );
    }
  }

  /// [base] as the current tenant reaches it: the tenant's schema or database
  /// for a routed data source, [base] itself otherwise.
  ///
  /// Throws `tenancy.tenant.unknown` for a tenant in context that the
  /// deployment does not have — routing it to the shared data source would
  /// hand it everyone's.
  TomDataSourceInfo route(TomDataSourceInfo base) {
    final tenant = TomTenantContext.currentId;
    if (tenant == null || !routedDatasources.contains(base.name)) return base;
    if (_statuses[tenant] == TomTenantStatus.migrationFailed) {
      throw TomTenancyException(
        'tenancy.tenant.migration_failed',
        "Tenant '$tenant' is not routed: its migration failed.",
        parameters: {'tenant': tenant},
      );
    }
    final routed = _routes[(base.name, tenant)];
    if (routed != null) return routed;
    if (!tenants.containsKey(tenant)) throw unknownTenant(tenant);
    return base;
  }

  /// [base] as the tenant [tenantId] reaches it, whatever its status — the
  /// route of maintenance: migrating, repairing or rolling back a tenant
  /// whose migration failed, which [route] refuses to ordinary work.
  ///
  /// Throws `tenancy.tenant.unknown` for a tenant the deployment does not
  /// have.
  TomDataSourceInfo routeForMaintenance(
    String tenantId,
    TomDataSourceInfo base,
  ) {
    if (!tenants.containsKey(tenantId)) throw unknownTenant(tenantId);
    if (!routedDatasources.contains(base.name)) return base;
    return _routes[(base.name, tenantId)] ?? base;
  }

  /// Runs [body] for [tenantId], which must be a tenant of the deployment.
  Future<T> runFor<T>(String tenantId, FutureOr<T> Function() body) async {
    if (!tenants.containsKey(tenantId)) throw unknownTenant(tenantId);
    return TomTenantContext.run(tenantId, () async => body());
  }

  /// Runs [body] once for every tenant, in turn — per-tenant migrations, a
  /// nightly job that does each tenant's work, a cache warm-up.
  Future<void> forEachTenant(
    FutureOr<void> Function(TomTenant tenant) body,
  ) async {
    for (final tenant in List.of(tenants.values)) {
      await TomTenantContext.run(tenant.id, () async => body(tenant));
    }
  }

  /// The tenant [request] is for, or the rejection to answer it with; [claim]
  /// is the `tenant` claim of the request's verified token, if it has one.
  ///
  /// The token's claim is authoritative: a request carrying one is
  /// for that tenant, and naming another through the host or a header is
  /// refused (`tenancy.resolution.conflict`, 403) — a token is not a pass to
  /// another tenant. Without a claim, the [resolvers] are asked in order and
  /// the first answer wins. A tenant the deployment does not have is refused
  /// (`tenancy.tenant.unknown`, 404) — a path segment a
  /// [TomTenantPathResolver]'s lookup does not know included; so is an id
  /// that is not one
  /// (`tenancy.id.invalid`, 400). No answer at all is not a rejection: the
  /// request proceeds with no tenant, and tenant tables are closed to it.
  TomTenantResolution resolveRequest(Request request, {String? claim}) {
    String? named;
    for (final resolver in resolvers) {
      if (resolver is TomTenantPathResolver &&
          resolver.namesUnknownSegment(request)) {
        return const TomTenantResolution.rejected(
          404,
          'tenancy.tenant.unknown',
          'The request names a tenant this server does not have.',
        );
      }
      named = resolver.resolve(request);
      if (named != null) break;
    }
    if (claim != null && named != null && named != claim) {
      return TomTenantResolution.rejected(
        403,
        'tenancy.resolution.conflict',
        'The request names a different tenant than its token.',
      );
    }
    final tenant = claim ?? named;
    if (tenant == null) return const TomTenantResolution.none();
    if (!TomTenantContext.idPattern.hasMatch(tenant)) {
      return TomTenantResolution.rejected(
        400,
        'tenancy.id.invalid',
        'The request names no valid tenant.',
      );
    }
    if (!tenants.containsKey(tenant)) {
      return TomTenantResolution.rejected(
        404,
        'tenancy.tenant.unknown',
        'The request names a tenant this server does not have.',
      );
    }
    switch (_statuses[tenant] ?? TomTenantStatus.active) {
      case TomTenantStatus.active:
        switch (_schemaChecks[tenant]?.skew) {
          case TomSchemaSkew.behind:
            return const TomTenantResolution.rejected(
              503,
              'tenancy.tenant.schema_behind',
              "The tenant's schema is behind this server's code.",
            );
          case TomSchemaSkew.aheadIncompatible:
            return const TomTenantResolution.rejected(
              503,
              'tenancy.tenant.schema_ahead',
              "The tenant's schema is ahead of this server's code.",
            );
          case _:
            break;
        }
      case TomTenantStatus.suspended:
        return const TomTenantResolution.rejected(
          403,
          'tenancy.tenant.suspended',
          'The tenant is suspended.',
        );
      case TomTenantStatus.migrationFailed:
        return const TomTenantResolution.rejected(
          503,
          'tenancy.tenant.migration_failed',
          "The tenant's migration failed; it is not served until it is "
              'migrated again.',
        );
      case TomTenantStatus.provisioning ||
          TomTenantStatus.migrating ||
          TomTenantStatus.removed:
        return const TomTenantResolution.rejected(
          503,
          'tenancy.tenant.unavailable',
          'The tenant is not available yet.',
        );
    }
    return TomTenantResolution.of(tenant);
  }

  /// The path resolver of the configuration: `pathPrefix` (default `t`) and,
  /// when the URLs name tenants by another segment than their id,
  /// `pathSegments` mapping segment → tenant id.
  static TomTenantPathResolver _pathResolver(Map<Object?, Object?> raw) {
    final prefix = raw['pathPrefix'] == null
        ? TomTenantPathResolver.defaultPrefix
        : '${raw['pathPrefix']}';
    final segments = raw['pathSegments'];
    if (segments == null) return TomTenantPathResolver(prefix: prefix);
    if (segments is! Map) throw _notAMap('$configurationKey.pathSegments');
    final bySegment = {
      for (final e in segments.entries) '${e.key}': '${e.value}',
    };
    return TomTenantPathResolver(
      prefix: prefix,
      lookup: (segment) => bySegment[segment],
    );
  }

  /// The tenant of a deployment that installs no tenancy — the implicit
  /// tenant tenant-table work with no tenant in context runs as.
  static const String implicitTenant = TomTenant.defaultType;

  /// The tenant work on a tenant table ([what] names it) runs as: the tenant
  /// in context; with none, [implicitTenant] when no tenancy is installed, and
  /// `tenancy.context.missing` when one is — an installed tenancy never
  /// guesses whose rows these are.
  static String tenantForWork(String what) =>
      TomTenantContext.currentId ??
      (current == null ? implicitTenant : TomTenantContext.require(what));

  /// The tenant tables the deployment's code declares: every reflected
  /// `@TomDbTable` entity marked `@TomTenantTable`, with its table, as the
  /// annotation analyzer reports them.
  static Map<Type, TomDbTable> get tenantTables =>
      TomAnnotationAnalyzer.tenantTables();

  /// The exception for work in a tenant the deployment does not have.
  static TomTenancyException unknownTenant(String tenantId) =>
      TomTenancyException(
        'tenancy.tenant.unknown',
        'There is no tenant "$tenantId".',
        parameters: {'tenant': tenantId},
        clientThrow: true,
      );

  /// Opens what [tenant] reaches its data through and records its routes: a
  /// `schema` or `database` tenant's own pool per routed data source, and a
  /// shared tenant of a type other than [TomTenant.defaultType] the pool over
  /// its type's shared schema — opened once per type and data source, so
  /// every shared tenant of the type reaches the same schema. A shared tenant
  /// of the default type keeps the base data source.
  Future<void> _provision(TomTenant tenant) async {
    final type = typeOf(tenant);
    final isolation = isolationOf(tenant);
    if (isolation == TomTenantIsolation.shared &&
        type.name == TomTenant.defaultType) {
      return;
    }
    for (final name in datasourcesOf(type)) {
      final base = TomDataSourceInfo.getBaseDataSourceInfo(name);
      if (base == null) {
        throw TomTenancyException(
          'tenancy.config.unknown_datasource',
          "The routed data source '$name' is not registered.",
          parameters: {'datasource': name},
        );
      }
      final routed = switch (isolation) {
        TomTenantIsolation.shared => await _sharedOf(base, type),
        TomTenantIsolation.schema => await _schemaOf(base, tenant),
        TomTenantIsolation.database => await _databaseOf(base, tenant),
      };
      _routes[(name, tenant.id)] = routed;
    }
  }

  static final RegExp _schemaPattern = RegExp(r'^[A-Za-z0-9_]{1,64}$');

  static String _databaseNameOf(TomDataSourceInfo base) {
    final database = base.settings['databaseName'];
    if (database == null || '$database'.isEmpty) {
      throw TomTenancyException(
        'tenancy.config.schema_unsupported',
        "Schema isolation needs the data source '${base.name}' to name its "
            "'databaseName'.",
        parameters: {'datasource': base.name},
      );
    }
    return '$database';
  }

  Future<TomDataSourceInfo> _schemaOf(
    TomDataSourceInfo base,
    TomTenant tenant,
  ) async {
    final database = _databaseNameOf(base);
    final schema = schemaNameOf(base, tenant);
    if (!_schemaPattern.hasMatch(schema)) {
      throw TomTenancyException(
        'tenancy.config.invalid_schema',
        "The schema '$schema' of tenant '${tenant.id}' is not an identifier "
            'of at most 64 letters, digits and underscores.',
        parameters: {'tenant': tenant.id, 'schema': schema},
      );
    }
    for (final type in types.values) {
      if (type.sharedSchema(database) != schema) continue;
      throw TomTenancyException(
        'tenancy.config.schema_collision',
        "The schema '$schema' of tenant '${tenant.id}' is the shared schema "
            "of the tenant type '${type.name}'.",
        parameters: {'tenant': tenant.id, 'schema': schema, 'type': type.name},
      );
    }
    return _openSchema(base, schema, '${base.name}@${tenant.id}');
  }

  /// The pool over [type]'s shared schema on [base], opened on first use and
  /// shared by every shared-isolation tenant of the type. Registered as
  /// `<name>@type.<type>` — a `.` is never in a tenant id, so it cannot be a
  /// tenant's pool.
  Future<TomDataSourceInfo> _sharedOf(
    TomDataSourceInfo base,
    TomTenantType type,
  ) async {
    final key = (base.name, type.name);
    final open = _sharedPools[key];
    if (open != null) return open;
    final schema = type.sharedSchema(_databaseNameOf(base))!;
    if (!_schemaPattern.hasMatch(schema)) {
      throw TomTenancyException(
        'tenancy.config.invalid_schema',
        "The shared schema '$schema' of the tenant type '${type.name}' is not "
            'an identifier of at most 64 letters, digits and underscores.',
        parameters: {'type': type.name, 'schema': schema},
      );
    }
    return _sharedPools[key] = await _openSchema(
      base,
      schema,
      '${base.name}@type.${type.name}',
    );
  }

  Future<TomDataSourceInfo> _openSchema(
    TomDataSourceInfo base,
    String schema,
    String name,
  ) async {
    // Before anything touches the server: a schema it would create for a
    // pool it may not open is left uncreated.
    _checkCap(name, pool.perTenant);
    final dialect = base.datasource.sqlDialect;
    if (createSchemas) {
      // The schema pattern the callers check is what makes interpolating it
      // safe.
      await base.datasource.executeCommand(dialect.createSchema(schema));
    }
    // The base data source's own pool sizing is not the tenant pool's: the
    // tenancy's pool settings apply beneath nothing but the schema.
    return _open(name, {
      for (final MapEntry(:key, :value) in base.settings.entries)
        if (!pool.settings.containsKey(key)) key: value,
      dialect.schemaSetting: schema,
    });
  }

  Future<TomDataSourceInfo> _databaseOf(
    TomDataSourceInfo base,
    TomTenant tenant,
  ) async {
    final configured =
        tenant.datasources[base.name] ??
        (datasourcesOf(typeOf(tenant)).length == 1
            ? tenant.datasources['']
            : null);
    if (configured == null) {
      throw TomTenancyException(
        'tenancy.config.missing_datasource',
        "Tenant '${tenant.id}' is database-isolated and configures no data "
            "source for '${base.name}'.",
        parameters: {'tenant': tenant.id, 'datasource': base.name},
      );
    }
    if (configured is String) {
      final registered = TomDataSourceInfo.getBaseDataSourceInfo(configured);
      if (registered == null) {
        throw TomTenancyException(
          'tenancy.config.unknown_datasource',
          "Tenant '${tenant.id}' names the data source '$configured', which "
              'is not registered.',
          parameters: {'tenant': tenant.id, 'datasource': configured},
        );
      }
      return registered;
    }
    return _open(
      '${base.name}@${tenant.id}',
      Map<String, dynamic>.of(configured as Map<String, dynamic>),
    );
  }

  /// Opens the tenant pool [name] with [settings] — [pool]'s defaults
  /// applied beneath them — within [TomTenantPoolSettings.maxTotal].
  Future<TomDataSourceInfo> _open(
    String name,
    Map<String, dynamic> settings,
  ) async {
    final merged = {...pool.settings, ...settings};
    final size = merged['poolMaxSize'] is int
        ? merged['poolMaxSize'] as int
        : int.tryParse('${merged['poolMaxSize']}') ?? pool.perTenant;
    _checkCap(name, size);
    final info = TomDataSourceInfo(name, merged);
    await info.initialize();
    _opened.add(info);
    _pooled[name] = size;
    return info;
  }

  /// Throws `tenancy.pool.cap_exceeded` when opening the pool [name] of
  /// [size] connections would take the tenant pools past
  /// [TomTenantPoolSettings.maxTotal].
  void _checkCap(String name, int size) {
    final total = _pooled.values.fold(0, (a, b) => a + b) + size;
    final cap = pool.maxTotal;
    if (cap == null || total <= cap) return;
    throw TomTenancyException(
      'tenancy.pool.cap_exceeded',
      "Opening the tenant pool '$name' of $size connections would take the "
          'tenant pools to $total connections, above the cap of $cap '
          '(tenancy.pool.maxTotal).',
      parameters: {'pool': name, 'size': size, 'total': total, 'cap': cap},
    );
  }

  /// The schema of the `schema`-isolated [tenant] on the data source [base]:
  /// its own [TomTenant.schema], else `<databaseName>_<id>`.
  String schemaNameOf(TomDataSourceInfo base, TomTenant tenant) =>
      tenant.schema ?? '${_databaseNameOf(base)}_${tenant.id}';
}

/// What [TomTenancy.refreshFromRegistry] changed on this node.
class TomTenantRegistryRefresh {
  /// Creates the result.
  const TomTenantRegistryRefresh({
    this.added = const [],
    this.removed = const [],
    this.changed = const [],
    this.failed = const {},
  });

  /// The tenants now served that were not.
  final List<String> added;

  /// The tenants no longer served.
  final List<String> removed;

  /// The tenants whose status changed.
  final List<String> changed;

  /// The tenants that could not be provisioned here, with the error.
  final Map<String, Object> failed;

  /// Whether nothing changed.
  bool get isEmpty =>
      added.isEmpty && removed.isEmpty && changed.isEmpty && failed.isEmpty;

  @override
  String toString() =>
      'TomTenantRegistryRefresh(added: $added, removed: $removed, '
      'changed: $changed, failed: ${failed.keys.toList()})';
}

/// How the pools a [TomTenancy] opens for tenants — a `schema` tenant's, a
/// `database` tenant's configured by settings, a type's shared schema — are
/// sized: small, opened by their first statement, their idle connections
/// closed by a timer, all of them under one cap.
///
/// A deployment of many tenants of which few are busy at once holds few
/// connections: a pool opens no connection until its tenant's first
/// statement (`connectLazily`) and closes the ones idle for [idleTimeout]
/// even while nobody uses it (`poolSweepIdle`). A `database` tenant's own
/// settings override these.
class TomTenantPoolSettings {
  /// Settings of [perTenant] connections per pool, closed after [idleTimeout]
  /// idle, under [maxTotal] (no cap when `null`).
  const TomTenantPoolSettings({
    this.perTenant = 4,
    this.idleTimeout = const Duration(seconds: 60),
    this.maxTotal,
  });

  /// Reads `tenancy.pool`: `perTenant`, `idleSeconds`, `maxTotal`.
  factory TomTenantPoolSettings.fromMap(Map<Object?, Object?> map) {
    int? read(String key) {
      final value = map[key];
      if (value == null) return null;
      final number = value is int ? value : int.tryParse('$value');
      if (number == null || number < 1) {
        throw TomTenancyException(
          'tenancy.config.invalid_number',
          "The tenancy setting 'pool.$key' must be a positive whole number, "
              "not '$value'.",
          parameters: {'key': 'pool.$key', 'value': '$value'},
        );
      }
      return number;
    }

    return TomTenantPoolSettings(
      perTenant: read('perTenant') ?? 4,
      idleTimeout: Duration(seconds: read('idleSeconds') ?? 60),
      maxTotal: read('maxTotal'),
    );
  }

  /// The most connections a tenant pool opens (`poolMaxSize`).
  final int perTenant;

  /// How long a tenant pool's connection may sit idle before it is closed.
  final Duration idleTimeout;

  /// The most connections all tenant pools together may open — refused with
  /// `tenancy.pool.cap_exceeded` when a pool would pass it — or `null`.
  final int? maxTotal;

  /// The data-source settings these stand for, beneath a pool's own.
  Map<String, Object> get settings => {
    'poolMaxSize': perTenant,
    'poolIdleTimeoutMs': idleTimeout.inMilliseconds,
    'poolSweepIdle': true,
    'connectLazily': true,
  };
}

/// What [TomTenancy.purgeTenant] did for one tenant.
class TomTenantPurgeReport {
  /// The report of [tenant].
  const TomTenantPurgeReport(
    this.tenant, {
    this.dropped = const [],
    this.kept = const [],
    this.deleted = const {},
  });

  /// The purged tenant.
  final String tenant;

  /// The schemas and databases dropped, as `<datasource>: schema <name>` or
  /// `<datasource>: database <name>`.
  final List<String> dropped;

  /// What was left in place, and why — a database named by reference, or on
  /// another server.
  final List<String> kept;

  /// The rows deleted, by table (shared isolation) or store.
  final Map<String, int> deleted;

  @override
  String toString() =>
      '$tenant: dropped ${dropped.isEmpty ? 'nothing' : dropped.join(', ')}'
      '${kept.isEmpty ? '' : '; kept ${kept.join(', ')}'}'
      '; deleted $deleted';
}

/// Multi-tenancy: who the tenants are, where each one's data lives, and how a
/// request finds out which tenant it is for.
///
/// ## Three isolation models, one seam
///
/// | Model | Where a tenant's rows live | Isolation | Operating cost |
/// | ----- | -------------------------- | --------- | -------------- |
/// | [TomTenantIsolation.shared] | the shared database, every tenant-owned table carrying a tenant column | the row predicate | one database, one migration |
/// | [TomTenantIsolation.schema] | a schema of its own on the shared server (on MariaDB, a database) | the schema boundary, and the predicate | one schema and one pool per tenant |
/// | [TomTenantIsolation.database] | a database of its own, configured per tenant — another server, another region | the server boundary, and the predicate | one database, one pool and one migration run per tenant |
///
/// The model is chosen **per tenant**: most tenants can share a schema while
/// the one with a data-residency requirement gets a database of its own. Every
/// model is reached through one seam — a repository asks for its data source,
/// and [TomTenancy.route] answers with the current tenant's — so application
/// code is the same under all three.
///
/// The row predicate (`@TomTenantOwned`) applies in every model. Under the
/// schema and database models it is a second wall rather than the only one,
/// and it is what makes moving a tenant between models a copy of its rows
/// rather than a schema change.
///
/// ## What is tenant-scoped
///
/// | Concern | How |
/// | ------- | --- |
/// | Repositories | `@TomTenantOwned` predicate on every read and write; data source routed per tenant |
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

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import '../datasources/datasource_initialization.dart';
import '../little_things/server_exception.dart';
import 'tenant_resolution.dart';

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
/// | `tenancy.tenant.unknown` | Work for a tenant the deployment does not have. |
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
    this.name,
    this.isolation,
    this.schema,
    this.datasources = const {},
  }) {
    TomTenantContext.validate(id);
  }

  /// The tenant's id — what the token's `tenant` claim names.
  final String id;

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
  TomTenancy({
    required Iterable<TomTenant> tenants,
    this.datasources = const {'main'},
    this.resolvers = const [],
    this.defaultIsolation = TomTenantIsolation.shared,
    this.createSchemas = false,
  }) : tenants = {for (final tenant in tenants) tenant.id: tenant};

  /// The configuration path of the tenancy settings.
  static const String configurationKey = 'tenancy';

  /// The tenants, by id.
  final Map<String, TomTenant> tenants;

  /// The data sources routed per tenant.
  final Set<String> datasources;

  /// How a request without a token claim names its tenant, in order.
  final List<TomTenantResolver> resolvers;

  /// The isolation of a tenant that names none.
  final TomTenantIsolation defaultIsolation;

  /// Whether schema isolation creates the tenant's schema.
  final bool createSchemas;

  /// The routed data source per (data source name, tenant id).
  final Map<(String, String), TomDataSourceInfo> _routes = {};

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
    final resolution = raw['resolution'];
    final names = resolution is List
        ? [for (final name in resolution) '$name']
        : resolution == null
        ? const <String>[]
        : ['$resolution'];
    return TomTenancy(
      tenants: tenants,
      datasources: raw['datasources'] is List
          ? {for (final name in raw['datasources'] as List) '$name'}
          : const {'main'},
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
    );
  }

  static TomTenancyException _notAMap(String key) => TomTenancyException(
    'tenancy.config.not_a_map',
    "Configuration '$key' must be a map.",
    parameters: {'key': key},
  );

  /// Installs [tenancy]: provisions every tenant's schema or database and
  /// routes data source lookups through it. Replaces (and resets) any
  /// configuration installed before.
  static Future<void> install(TomTenancy tenancy) async {
    await reset();
    for (final tenant in tenancy.tenants.values) {
      await tenancy._provision(tenant);
    }
    _installed = tenancy;
    TomDataSourceInfo.router = tenancy.route;
  }

  /// Removes the installed configuration and closes the data sources it
  /// opened.
  static Future<void> reset() async {
    final previous = _installed;
    _installed = null;
    TomDataSourceInfo.router = null;
    if (previous == null) return;
    for (final info in previous._opened) {
      TomDataSourceInfo.datasources.remove(info.name);
      await info.datasource.close();
    }
    previous._opened.clear();
    previous._routes.clear();
  }

  /// Adds [tenant] to the running deployment, provisioning its schema or
  /// database first — onboarding without a restart.
  Future<void> addTenant(TomTenant tenant) async {
    await _provision(tenant);
    tenants[tenant.id] = tenant;
  }

  /// The isolation [tenant] runs under.
  TomTenantIsolation isolationOf(TomTenant tenant) =>
      tenant.isolation ?? defaultIsolation;

  /// [base] as the current tenant reaches it: the tenant's schema or database
  /// for a routed data source, [base] itself otherwise.
  ///
  /// Throws `tenancy.tenant.unknown` for a tenant in context that the
  /// deployment does not have — routing it to the shared data source would
  /// hand it everyone's.
  TomDataSourceInfo route(TomDataSourceInfo base) {
    final tenant = TomTenantContext.currentId;
    if (tenant == null || !datasources.contains(base.name)) return base;
    final routed = _routes[(base.name, tenant)];
    if (routed != null) return routed;
    if (!tenants.containsKey(tenant)) throw unknownTenant(tenant);
    return base;
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
  /// request proceeds with no tenant, and tenant-owned data is closed to it.
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

  /// The exception for work in a tenant the deployment does not have.
  static TomTenancyException unknownTenant(String tenantId) =>
      TomTenancyException(
        'tenancy.tenant.unknown',
        'There is no tenant "$tenantId".',
        parameters: {'tenant': tenantId},
        clientThrow: true,
      );

  Future<void> _provision(TomTenant tenant) async {
    final isolation = isolationOf(tenant);
    if (isolation == TomTenantIsolation.shared) return;
    for (final name in datasources) {
      final base = TomDataSourceInfo.getBaseDataSourceInfo(name);
      if (base == null) {
        throw TomTenancyException(
          'tenancy.config.unknown_datasource',
          "The routed data source '$name' is not registered.",
          parameters: {'datasource': name},
        );
      }
      final routed = isolation == TomTenantIsolation.schema
          ? await _schemaOf(base, tenant)
          : await _databaseOf(base, tenant);
      _routes[(name, tenant.id)] = routed;
    }
  }

  static final RegExp _schemaPattern = RegExp(r'^[A-Za-z0-9_]{1,64}$');

  Future<TomDataSourceInfo> _schemaOf(
    TomDataSourceInfo base,
    TomTenant tenant,
  ) async {
    final database = base.settings['databaseName'];
    if (database == null || '$database'.isEmpty) {
      throw TomTenancyException(
        'tenancy.config.schema_unsupported',
        "Schema isolation needs the data source '${base.name}' to name its "
            "'databaseName'.",
        parameters: {'datasource': base.name},
      );
    }
    final schema = tenant.schema ?? '${database}_${tenant.id}';
    if (!_schemaPattern.hasMatch(schema)) {
      throw TomTenancyException(
        'tenancy.config.invalid_schema',
        "The schema '$schema' of tenant '${tenant.id}' is not an identifier "
            'of at most 64 letters, digits and underscores.',
        parameters: {'tenant': tenant.id, 'schema': schema},
      );
    }
    if (createSchemas) {
      // The pattern above is what makes interpolating it safe.
      await base.datasource.executeCommand(
        'CREATE DATABASE IF NOT EXISTS `$schema`',
      );
    }
    return _open('${base.name}@${tenant.id}', {
      ...base.settings,
      'databaseName': schema,
    });
  }

  Future<TomDataSourceInfo> _databaseOf(
    TomDataSourceInfo base,
    TomTenant tenant,
  ) async {
    final configured =
        tenant.datasources[base.name] ??
        (datasources.length == 1 ? tenant.datasources[''] : null);
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

  Future<TomDataSourceInfo> _open(
    String name,
    Map<String, dynamic> settings,
  ) async {
    final info = TomDataSourceInfo(name, settings);
    await info.initialize();
    _opened.add(info);
    return info;
  }
}

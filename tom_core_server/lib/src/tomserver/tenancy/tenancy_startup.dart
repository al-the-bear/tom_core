/// What a server's start makes of tenancy: decided from the application's
/// tenant tables and the configuration, validated before anything is served.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../authentication/oauth_identity.dart';
import '../authentication/oauth_tokens.dart';
import '../authentication/two_factor_enrolment.dart';
import '../authorization/graded_authorization.dart';
import '../authorization/principal_delegation.dart';
import '../authorization/principal_resource_grant.dart';
import '../configuration/base_server_configuration.dart';
import '../db_migration/db_migration.dart';
import '../db_migration/schema_convergence.dart';
import '../object_persistence/persistence_annotations.dart';
import '../preferences/preference_default.dart';
import '../preferences/user_preference.dart';
import 'tenancy.dart';
import 'tenant_type.dart';

/// How a deployment runs, as its start decided it.
enum TomTenancyMode {
  /// No tenant table and no tenancy: nothing installed, nothing configured.
  plain,

  /// Tenant tables and no tenancy configured: one tenant, `default`, of the
  /// type `default`, shared, its tenant tables in the system schema — work
  /// with no tenant in context runs as it ([TomTenancy.implicitTenant]).
  /// Nothing is installed: the implicit tenant is what a deployment without
  /// a [TomTenancy] already is.
  implicit,

  /// A [TomTenancy] installed — by the application, or from the `tenancy`
  /// configuration key — and validated.
  configured,
}

/// What [TomTenancyStartup.configure] decided and found.
class TomTenancyStartupReport {
  /// A report of [mode].
  const TomTenancyStartupReport(
    this.mode, {
    this.tenantTables = const {},
    this.warnings = const [],
  });

  /// How the deployment runs.
  final TomTenancyMode mode;

  /// The application's tenant tables, by entity — the framework's own left
  /// out ([TomTenancyStartup.frameworkTenantEntities]).
  final Map<Type, TomDbTable> tenantTables;

  /// What the start warned about, one line each.
  final List<String> warnings;

  @override
  String toString() =>
      'TomTenancyStartupReport(${mode.name}, '
      '${tenantTables.length} tenant table(s)'
      '${warnings.isEmpty ? '' : ', ${warnings.length} warning(s)'})';
}

/// Decides at start whether a deployment needs tenancy, installs a configured
/// one and refuses the contradictions — `TomServer.start` calls [configure]
/// before it migrates.
abstract final class TomTenancyStartup {
  /// The tenant tables the framework itself declares. They are reflected into
  /// every server that imports the package, used or not, and their migrations
  /// are the framework's reference migrations (checked by
  /// `TomFrameworkSchemaCheck`); they are not what makes a deployment need
  /// tenancy, and a type's tree is not asked to create them.
  static const Set<Type> frameworkTenantEntities = {
    TomUserPreference,
    TomPreferenceDefault,
    TomResourceGrant,
    TomPrincipalResourceGrant,
    TomPrincipalDelegation,
    TomExternalIdentityLink,
    TomExternalIdentityToken,
    TomUserTwoFactorEnrolment,
  };

  /// The application's tenant tables: [TomTenancy.tenantTables] less the
  /// [frameworkTenantEntities].
  static Map<Type, TomDbTable> get applicationTenantTables => {
    for (final entry in TomTenancy.tenantTables.entries)
      if (!frameworkTenantEntities.contains(entry.key)) entry.key: entry.value,
  };

  /// Installs the tenancy the `tenancy` key of [config] (the server
  /// configuration unless given) describes, unless the application installed
  /// one already; decides the [TomTenancyMode] from the application's tenant
  /// tables ([tenantTables], [applicationTenantTables] unless given); and
  /// refuses the contradictions against the migration root [migrationsRoot]:
  ///
  /// | Contradiction | Key |
  /// | --- | --- |
  /// | a declared type without a migration tree | `tenancy.type.missing_migrations` (by [TomTenancy.install]) |
  /// | a tenant — configured or registered — of an unknown type | `tenancy.type.unknown` (by [TomTenancy.install]) |
  /// | a tree under `<root>/tenant/` for a type nobody declares | `tenancy.start.undeclared_type_tree` |
  /// | a tenant table its type routes that the type's tree never creates | `tenancy.start.table_missing_from_type` |
  ///
  /// A configured tenancy with no tenant table and no tenant tree starts, with
  /// a warning (`tenancy.start.no_tenant_tables`, logged and in the report's
  /// [TomTenancyStartupReport.warnings]). The implicit tenancy is checked the
  /// same way against the type `default`'s tree when there is one; without
  /// one its tenant tables are migrated with the system tree, in the system
  /// schema.
  static Future<TomTenancyStartupReport> configure({
    TomServerConfigResourceProvider? config,
    String? migrationsRoot,
    Map<Type, TomDbTable>? tenantTables,
  }) async {
    final provider =
        config ?? TomServerConfigResourceProvider.getServerConfig();
    if (TomTenancy.current == null &&
        provider.exists(TomTenancy.configurationKey)) {
      await TomTenancy.install(TomTenancy.fromConfiguration(provider));
    }
    final tables = tenantTables ?? applicationTenantTables;
    final tenancy = TomTenancy.current;
    final root = migrationsRoot;
    final warnings = <String>[];
    if (tenancy == null) {
      if (tables.isEmpty)
        return const TomTenancyStartupReport(TomTenancyMode.plain);
      _checkTypeTrees(root, {TomTenant.defaultType: null}, tables, null);
      tomLog.info(
        'Tenancy: ${tables.length} tenant table(s) and no tenancy configured '
        "— the implicit tenant '${TomTenancy.implicitTenant}', its tenant "
        'tables in the system schema.',
      );
      return TomTenancyStartupReport(
        TomTenancyMode.implicit,
        tenantTables: tables,
      );
    }
    _checkTypeTrees(root, tenancy.types, tables, tenancy);
    if (tables.isEmpty && !_hasTenantTree(root, tenancy)) {
      const line =
          'tenancy.start.no_tenant_tables: tenancy is configured, but no '
          'entity is a tenant table (@TomTenantTable) and no tenant migration '
          'tree exists — every table is a system table, shared by every '
          'tenant.';
      tomLog.warn(line);
      warnings.add(line);
    }
    return TomTenancyStartupReport(
      TomTenancyMode.configured,
      tenantTables: tables,
      warnings: warnings,
    );
  }

  /// Whether any tenant migration tree exists: a declared type's own, or a
  /// directory under `<root>/tenant/`.
  static bool _hasTenantTree(String? root, TomTenancy tenancy) {
    for (final type in tenancy.types.values) {
      final own = type.migrations;
      if (own != null && Directory(own).existsSync()) return true;
    }
    if (root == null) return false;
    final tenant = Directory(p.join(root, TomDbMigrations.tenantTreesName));
    return tenant.existsSync() &&
        tenant.listSync().whereType<Directory>().isNotEmpty;
  }

  /// Refuses a tree under `<root>/tenant/` for a type not in [types], and,
  /// for each type whose tree exists, a tenant table on a data source it
  /// routes that the tree's chain for that data source never creates.
  static void _checkTypeTrees(
    String? root,
    Map<String, TomTenantType?> types,
    Map<Type, TomDbTable> tables,
    TomTenancy? tenancy,
  ) {
    if (root != null) {
      final tenant = Directory(p.join(root, TomDbMigrations.tenantTreesName));
      if (tenant.existsSync()) {
        for (final dir in tenant.listSync().whereType<Directory>()) {
          final name = p.basename(dir.path);
          if (types.containsKey(name)) continue;
          throw TomTenancyException(
            'tenancy.start.undeclared_type_tree',
            'The migration tree "${dir.path}" is for the tenant type "$name", '
                'which the deployment does not declare.',
            parameters: {
              'type': name,
              'tree': dir.path,
              'declared': types.keys.toList()..sort(),
            },
          );
        }
      }
    }
    if (tables.isEmpty) return;
    final check = TomSchemaConvergenceCheck();
    for (final MapEntry(key: name, value: type) in types.entries) {
      final tree =
          type?.migrations ??
          (root == null ? null : TomTenantType.treeUnder(root, name));
      if (tree == null || !Directory(tree).existsSync()) continue;
      final routed = tenancy == null || type == null
          ? null
          : tenancy.datasourcesOf(type);
      for (final MapEntry(key: entity, value: table) in tables.entries) {
        final datasource = table.datasource;
        if (routed != null && !routed.contains(datasource)) continue;
        final report = check.verify(
          datasource: datasource,
          schema: TomDbMigrations.tenantHistoryLabel(name),
          chain: check.readChain(p.join(tree, datasource)),
          entityTypes: [entity],
        );
        final missing = report.divergences.any(
          (d) => d.kind == TomSchemaDivergenceKind.missingTable,
        );
        if (!missing) continue;
        throw TomTenancyException(
          'tenancy.start.table_missing_from_type',
          'The tenant table "${table.table}" ($entity, data source '
              '"$datasource") is never created by the migration tree of the '
              'tenant type "$name" ("$tree"): a tenant of the type would have '
              'no such table.',
          parameters: {
            'type': name,
            'table': table.table,
            'entity': '$entity',
            'datasource': datasource,
            'tree': tree,
          },
        );
      }
    }
  }
}

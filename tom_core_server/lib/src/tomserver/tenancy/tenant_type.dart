/// Tenant types: kinds of tenant that share a default isolation, the
/// isolation models they may use, the data sources they route and a migration
/// tree.
library;

import 'dart:io';

import 'tenancy.dart';

/// One kind of tenant of the deployment.
///
/// Every tenant names its type ([TomTenant.type]). A deployment that declares
/// no types has one, implicitly: [TomTenant.defaultType], allowing every
/// isolation model and routing [TomTenancy.datasources]. A deployment that
/// declares types serves only tenants of the types it declares.
///
/// **Shared tenants of one type share one tenant schema.** A shared-isolation
/// tenant of the type `default` lives in the system schema — the base data
/// source's own; a shared-isolation tenant of any other type lives in the
/// type's [sharedSchema], `<databaseName>_<type>`, which every shared tenant
/// of the type reaches through one pool. That schema is one migration target:
/// the type's tree is applied to it once, however many shared tenants it
/// holds, while a `schema` or `database` tenant is a target of its own.
///
/// A tenant's type is not edited in place: a configured tenant whose type
/// differs from its registry row is reported as a conflict and the row is
/// used, and [TomTenancy.addTenant] refuses to give a tenant the registry
/// holds another type (`tenancy.type.change`). Changing it is a move of the
/// tenant's data.
class TomTenantType {
  /// Creates a type.
  ///
  /// [isolation] is the default for its tenants (the deployment's
  /// [TomTenancy.defaultIsolation] when `null`); [isolations] are the models
  /// its tenants may use (all three when `null`); [datasources] are the data
  /// sources whose tenant data it routes ([TomTenancy.datasources] when
  /// `null`); [migrations] is the directory of its migration tree, which a
  /// declared type must have.
  ///
  /// Throws `tenancy.type.invalid` for a [name] that is not a type name and
  /// `tenancy.type.isolation_not_allowed` for an [isolation] outside
  /// [isolations].
  TomTenantType(
    this.name, {
    this.isolation,
    Set<TomTenantIsolation>? isolations,
    this.datasources,
    this.migrations,
  }) : isolations = Set.unmodifiable(
         isolations ?? TomTenantIsolation.values.toSet(),
       ) {
    if (!namePattern.hasMatch(name)) {
      throw TomTenancyException(
        'tenancy.type.invalid',
        'The tenant type "$name" is not a lowercase identifier of at most 32 '
            'letters, digits and underscores, starting with a letter.',
        parameters: {'type': name},
      );
    }
    final fallback = isolation;
    if (fallback != null && !this.isolations.contains(fallback)) {
      throw isolationNotAllowed(name, fallback, 'its default');
    }
  }

  /// Reads a type from its configuration [map]; [migrationsRoot] is
  /// `tenancy.migrations`, under which a type that names no `migrations`
  /// directory has its tree at `<migrationsRoot>/tenant/<name>`.
  factory TomTenantType.fromMap(
    String name,
    Map<Object?, Object?> map, {
    String? migrationsRoot,
  }) {
    final rawIsolations = map['isolations'];
    final rawDatasources = map['datasources'];
    return TomTenantType(
      name,
      isolation: map['isolation'] == null
          ? null
          : TomTenantIsolation.parse('${map['isolation']}'),
      isolations: rawIsolations == null
          ? null
          : {
              for (final raw
                  in rawIsolations is List ? rawIsolations : [rawIsolations])
                TomTenantIsolation.parse('$raw'),
            },
      datasources: rawDatasources == null
          ? null
          : {
              for (final raw
                  in rawDatasources is List ? rawDatasources : [rawDatasources])
                '$raw',
            },
      migrations: map['migrations'] != null
          ? '${map['migrations']}'
          : migrationsRoot == null
          ? null
          : treeUnder(migrationsRoot, name),
    );
  }

  /// What a type name must look like: a tenant id's shape, because a
  /// type's shared schema is named after it.
  static final RegExp namePattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

  /// The directory of [type]'s tree under the migrations [root].
  static String treeUnder(String root, String type) => '$root/tenant/$type';

  /// The type's name — what [TomTenant.type] names.
  final String name;

  /// The default isolation of its tenants, or `null` for the deployment's.
  final TomTenantIsolation? isolation;

  /// The isolation models its tenants may use.
  final Set<TomTenantIsolation> isolations;

  /// The data sources whose tenant data it routes, or `null` for the
  /// deployment's [TomTenancy.datasources].
  final Set<String>? datasources;

  /// The directory of its migration tree, or `null` when it names none.
  final String? migrations;

  /// The schema the type's shared-isolation tenants share, on a data source
  /// whose database is [databaseName]: `null` — the base data source's own
  /// schema — for the type [TomTenant.defaultType], `<databaseName>_<name>`
  /// for every other, so two types' trees never define one table twice in
  /// one schema.
  String? sharedSchema(String databaseName) =>
      name == TomTenant.defaultType ? null : '${databaseName}_$name';

  /// Throws `tenancy.type.missing_migrations` unless [migrations] names an
  /// existing directory.
  void verifyMigrations() {
    final tree = migrations;
    if (tree != null && Directory(tree).existsSync()) return;
    throw TomTenancyException(
      'tenancy.type.missing_migrations',
      tree == null
          ? 'The tenant type "$name" names no migration tree.'
          : 'The migration tree "$tree" of the tenant type "$name" does not '
                'exist.',
      parameters: {'type': name, 'migrations': ?tree},
    );
  }

  /// The exception for [isolation] where the type [type] does not allow it;
  /// [what] says whose isolation it is.
  static TomTenancyException isolationNotAllowed(
    String type,
    TomTenantIsolation isolation,
    String what,
  ) => TomTenancyException(
    'tenancy.type.isolation_not_allowed',
    'The tenant type "$type" does not allow $what isolation '
        '"${isolation.name}".',
    parameters: {'type': type, 'isolation': isolation.name},
  );

  @override
  String toString() => 'TomTenantType($name)';
}

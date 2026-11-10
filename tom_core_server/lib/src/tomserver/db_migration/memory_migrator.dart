/// A migrator that keeps its history in memory and runs no SQL — for tests and
/// examples of the migration orchestration.
library;

import '../datasources/datasource_initialization.dart';
import 'db_migration.dart';

/// A [TomDbMigrator] that records what it applies instead of running it.
///
/// Its history is kept per data source and history label (the `<schema>`
/// level of the system tree, `tenant_<type>` for a type's tree), in
/// [applied], and survives across instances that share the [history] (and
/// [scripts]) map — pass one map to every instance a test creates, as one database is shared
/// by every migrator over it. A migration named in [failing] by
/// `<datasource>/<label>/<version>` throws when it is applied, and is not
/// recorded.
class TomMemoryDbMigrator implements TomDbMigrator {
  /// A migrator over [history] that fails the migrations in [failing].
  TomMemoryDbMigrator({
    Map<String, List<int>>? history,
    Map<String, Map<int, String>>? scripts,
    Set<String> failing = const {},
  }) : history = history ?? {},
       scripts = scripts ?? {},
       failing = Set.of(failing);

  /// The applied versions by `<datasource>/<label>`, in the order applied.
  final Map<String, List<int>> history;

  /// The migrations that fail, as `<datasource>/<label>/<version>`.
  final Set<String> failing;

  /// The script each applied version was applied with, by
  /// `<datasource>/<label>` — what [appliedScripts] answers; shared like
  /// [history].
  final Map<String, Map<int, String>> scripts;

  String? _bound;

  /// The key of [dsi] and [label] in [history].
  static String keyOf(TomDataSourceInfo dsi, String label) =>
      '${dsi.name}/$label';

  /// The versions applied to [label] of [dsi].
  List<int> applied(TomDataSourceInfo dsi, String label) =>
      List.unmodifiable(history[keyOf(dsi, label)] ?? const []);

  @override
  Future<void> initializeMigration(
    TomDataSourceInfo dsi,
    String schemaName,
  ) async {
    _bound = keyOf(dsi, schemaName);
    history.putIfAbsent(_bound!, () => []);
  }

  @override
  Future<void> applyMigration(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  ) async {
    final key = keyOf(dsi, schemaName);
    if (_bound != key) {
      throw TomDbMigrationException(
        'db_migration.memory.not_initialized',
        'The memory migrator is not initialised for $key.',
      );
    }
    final versions = history[key]!;
    if (versions.contains(version)) return;
    if (failing.contains('$key/$version')) {
      throw TomDbMigrationException(
        'db_migration.memory.apply_failed',
        'Migration $version ($description) of $key failed.',
        parameters: {'target': key, 'version': version},
      );
    }
    versions.add(version);
    (scripts[key] ??= {})[version] = sql;
  }

  @override
  Future<Map<int, String>> appliedScripts(
    TomDataSourceInfo dsi,
    String schemaName,
  ) async {
    final key = keyOf(dsi, schemaName);
    return {
      for (final version in history[key] ?? const <int>[])
        version: scripts[key]?[version] ?? '',
    };
  }

  @override
  void reset() => _bound = null;

  @override
  Future<R> withMigrationLock<R>(
    TomDataSourceInfo dsi,
    Future<R> Function() body,
  ) => body();

  @override
  Future<void> repair(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    TomMigrationRepair action,
  ) async {
    final key = keyOf(dsi, schemaName);
    failing.remove('$key/$version');
    if (action == TomMigrationRepair.markResolved) {
      (history[key] ??= []).add(version);
    }
  }

  @override
  Future<List<int>> rollback(
    TomDataSourceInfo dsi,
    String schemaName,
    int toVersion,
    Map<int, TomMigrationScript> scripts,
  ) async {
    final versions = history[keyOf(dsi, schemaName)] ?? [];
    final undo = [
      for (final v in versions.reversed)
        if (v > toVersion) v,
    ];
    for (final v in undo) {
      if (scripts[v]?.down == null) {
        throw TomDbMigrationException(
          'db_migration.memory.no_down_script',
          'Migration $v of ${keyOf(dsi, schemaName)} has no down script.',
        );
      }
    }
    versions.removeWhere(undo.contains);
    return undo;
  }
}

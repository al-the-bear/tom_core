/// What a migration run did, target by target: the system schema, each tenant
/// type's shared schema and each tenant with a schema or database of its own.
library;

/// What a migration target is.
enum TomMigrationTargetKind {
  /// The system schema, migrated by `<root>/system/`.
  system,

  /// A tenant type's shared schema, migrated once by the type's tree for every
  /// shared-isolation tenant of the type.
  shared,

  /// One tenant's own schema or database, migrated by its type's tree.
  tenant,
}

/// Where a migration target's run stands — see [TomMigrationRun].
enum TomMigrationRunState {
  /// Not run in this process.
  notRun,

  /// Being applied now.
  running,

  /// Every migration applied.
  succeeded,

  /// A migration failed; [TomMigrationRun.error] says why.
  failed,
}

/// One target of a migration run: which it is, where its run stands, when it
/// started and finished, and the error it failed with.
///
/// The target is named `system`, `shared:<type>` or `tenant:<id>`
/// ([systemTarget], [sharedTarget], [tenantTarget]).
class TomMigrationRun {
  /// A run of [target].
  const TomMigrationRun(
    this.target,
    this.kind,
    this.state, {
    this.tenants = const [],
    this.startedAt,
    this.finishedAt,
    this.error,
  });

  /// The name of the system schema's target.
  static const String systemTarget = 'system';

  /// The name of the shared-schema target of the tenant type [type].
  static String sharedTarget(String type) => 'shared:$type';

  /// The name of the target of the tenant [tenant].
  static String tenantTarget(String tenant) => 'tenant:$tenant';

  /// The target: `system`, `shared:<type>` or `tenant:<id>`.
  final String target;

  /// What the target is.
  final TomMigrationTargetKind kind;

  /// Where its run stands.
  final TomMigrationRunState state;

  /// The tenants the target serves: none for the system schema, every
  /// shared tenant of the type for a shared schema, the one tenant for its
  /// own.
  final List<String> tenants;

  /// When it started; `null` when it has not.
  final DateTime? startedAt;

  /// When it ended, for a run that has.
  final DateTime? finishedAt;

  /// The error a failed run threw, as text.
  final String? error;

  /// This run with [state], [finishedAt] and [error] replaced.
  TomMigrationRun finished(
    TomMigrationRunState state, {
    required DateTime at,
    String? error,
  }) => TomMigrationRun(
    target,
    kind,
    state,
    tenants: tenants,
    startedAt: startedAt,
    finishedAt: at,
    error: error,
  );

  @override
  String toString() =>
      '$target: ${state.name}${error == null ? '' : ' ($error)'}';
}

/// The outcome of one `TomDbMigrations.migrateAll` call: every target's run,
/// in the order they started — the system schema first, then the shared
/// schemas, then the tenants.
class TomMigrationResult {
  /// A result of [runs].
  TomMigrationResult(Iterable<TomMigrationRun> runs)
    : runs = List.unmodifiable(runs);

  /// Every target's run.
  final List<TomMigrationRun> runs;

  /// Whether every target succeeded.
  bool get succeeded =>
      runs.every((run) => run.state == TomMigrationRunState.succeeded);

  /// The targets that failed.
  List<TomMigrationRun> get failed => [
    for (final run in runs)
      if (run.state == TomMigrationRunState.failed) run,
  ];

  /// The run of [target], or `null` when the call did not reach it.
  TomMigrationRun? runOf(String target) {
    for (final run in runs) {
      if (run.target == target) return run;
    }
    return null;
  }

  @override
  String toString() => runs.join('; ');
}

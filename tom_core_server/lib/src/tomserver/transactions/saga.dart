/// Sagas: work that spans services, made of local transactions that each have
/// a compensation, so no distributed transaction is needed.
///
/// An order that reserves stock in one service, charges a card in a second and
/// books a shipment in a third cannot commit in one transaction: the three own
/// their data. A saga does each step as a **local transaction** and, when a
/// later step fails for good, runs the **compensations** of the steps already
/// done, in reverse order — the stock is released and the charge refunded, so
/// the system ends where it started, by explicit undo rather than by rollback.
///
/// ```dart
/// final orchestrator = TomSagaOrchestrator(
///   store: TomSqlSagaStore('main'),
///   jobStore: TomSqlJobStore(mainDatasource),
/// )..register(TomSaga(
///     name: 'place_order',
///     steps: [
///       TomSagaStep('reserve', action: reserve, compensation: release),
///       TomSagaStep('charge', action: charge, compensation: refund),
///       TomSagaStep('ship', action: ship),
///     ],
///   ));
/// await orchestrator.start();
/// final id = await orchestrator.begin('place_order', data: {'order': 42});
/// ```
///
/// ## Orchestration
///
/// One coordinator — [TomSagaOrchestrator] — drives each saga, and its
/// progress is a row in the saga store ([TomSagaState]): which step comes
/// next, the saga's data, and a version. A saga whose services merely react to
/// each other's events (choreography) needs nothing from the framework; it is
/// an application using its message bus.
///
/// ## Built on the scheduler, the way the outbox is
///
/// The orchestrator owns no retry logic. Like the message outbox it runs an
/// inline scheduler of its own over a [TomJobStore], and every transition of a
/// saga — one step, or one compensation — is a job run: the retries and their
/// backoff, one runner per run, the recovery of a run whose node died, and the
/// alerts all come from the scheduler. Point it at the job store the outbox and
/// the application's scheduler use; each takes only the runs of its own jobs.
///
/// ## One transition, one local transaction
///
/// A step's action runs in a transaction together with the update that moves
/// the saga on, and that update only succeeds for the version the run was
/// queued for. So:
///
/// * a step whose action throws leaves no trace — its work and the saga's move
///   roll back together, and the run is retried;
/// * a step that committed is never run again: a run for an older version finds
///   the saga moved on and does nothing, however it came to run twice;
/// * a process that dies mid-step rolls the step back, and the run is taken up
///   again — by the scheduler's recovery on another node, or by [start] on
///   this one.
///
/// This holds for the work a step does in the saga store's data source. Work
/// on another data source joins the same transaction only when both are XA data
/// sources (see `transactions.md`). A call to another service is not part of
/// any local transaction: it runs at least once and must be idempotent, which
/// is what a message sent through a `TomMessageOutbox` whose job store shares
/// the saga's data source gives — the message is queued in the step's
/// transaction and delivered after it commits, or not at all.
///
/// ## Failure and compensation
///
/// A step is retried by its saga's [TomSaga.retryPolicy]. When its last attempt
/// fails, or it throws a [TomPermanentFailure], the saga turns to
/// [TomSagaStatus.compensating] and compensates the steps that completed, last
/// first; a step without a compensation is passed over. A compensation is
/// retried by [TomSaga.compensationRetryPolicy] — generously, because a
/// compensation that gives up leaves the system half done. One that fails for
/// good ends the saga [TomSagaStatus.failed], and the scheduler's alert names
/// it: what remains is for an operator.
///
/// ## Resumption
///
/// A saga's progress is in its store, so a restart loses nothing. [start]
/// re-queues the run of every unfinished saga whose run is no longer in the job
/// store — a run that was lost between a transition's commit and the queueing
/// of the next run, or one whose attempts ran out — and does so again every
/// [TomSagaOrchestrator.sweepInterval]. Under tenancy it does that in every
/// tenant's context, so a tenant's sagas are found in the tenant's data source.
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:uuid/v4.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import '../scheduling/event_instants.dart';
import '../tenancy/tenancy.dart';
import 'saga_sql.dart';
import 'transaction_manager.dart';

/// A saga that cannot be declared, started or stored.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `transactions.saga.invalid_definition` | A saga's name is empty or longer than 120 characters, it has no steps, or two steps share a name. |
/// | `transactions.saga.already_registered` | A saga of that name is registered with the orchestrator already. |
/// | `transactions.saga.unknown` | [TomSagaOrchestrator.begin] names a saga that is not registered. |
/// | `transactions.saga.invalid_id` | The saga id given to [TomSagaOrchestrator.begin] is empty or longer than 128 characters. |
/// | `transactions.saga.id_taken` | A saga with that id exists already. |
/// | `transactions.saga.data_not_json` | The saga's data is not JSON-encodable. |
/// | `transactions.saga.closed` | The orchestrator has been closed. |
/// | `transactions.saga.no_datasource` | The data source a [TomSqlSagaStore] names is not registered. |
/// | `transactions.saga.superseded` | A transition found its saga moved on since its run was queued. Raised inside the transition's transaction to roll it back, and caught by the orchestrator: it never reaches a caller. |
class TomSagaException extends TomServerException {
  /// Creates the exception; see [TomServerException] for the fields.
  TomSagaException(super.key, super.defaultUserMessage, {super.parameters})
    : super(clientThrow: false);
}

/// The work of a step or a compensation.
typedef TomSagaWork = FutureOr<void> Function(TomSagaContext context);

/// One step of a saga: an [action] and, optionally, the [compensation] that
/// undoes it.
class TomSagaStep {
  /// A step named [name], unique within its saga.
  const TomSagaStep(this.name, {required this.action, this.compensation});

  /// The step's name, unique within its saga.
  final String name;

  /// The step's work, run in a local transaction with the saga's transition.
  final TomSagaWork action;

  /// What undoes [action] once a later step has failed for good, or `null`
  /// for a step with nothing to undo — a read, or the last step.
  final TomSagaWork? compensation;
}

/// The declaration of a saga: its steps, in order, and how they are retried.
class TomSaga {
  /// A saga [name] of [steps].
  ///
  /// Throws `transactions.saga.invalid_definition` for a name that is empty or
  /// longer than 120 characters, no steps, or two steps of one name.
  TomSaga({
    required this.name,
    required List<TomSagaStep> steps,
    this.retryPolicy = const TomRetryPolicy(),
    this.compensationRetryPolicy = const TomRetryPolicy(
      maxAttempts: 10,
      initialBackoff: Duration(seconds: 30),
      maxBackoff: Duration(minutes: 30),
    ),
    this.timeout = const Duration(minutes: 2),
  }) : steps = List.unmodifiable(steps) {
    if (name.isEmpty || name.length > 120) {
      throw _invalid('A saga name is 1 to 120 characters long.');
    }
    if (this.steps.isEmpty) throw _invalid("The saga '$name' has no steps.");
    final names = <String>{};
    for (final step in this.steps) {
      if (!names.add(step.name)) {
        throw _invalid("The saga '$name' has two steps named '${step.name}'.");
      }
    }
  }

  /// The saga's name, which its state records and its jobs are named after.
  final String name;

  /// The steps, run in order.
  final List<TomSagaStep> steps;

  /// How a failing step is retried before the saga compensates.
  final TomRetryPolicy retryPolicy;

  /// How a failing compensation is retried before the saga fails.
  final TomRetryPolicy compensationRetryPolicy;

  /// How long one attempt of a step or a compensation may take.
  final Duration timeout;

  TomSagaException _invalid(String message) => TomSagaException(
    'transactions.saga.invalid_definition',
    message,
    parameters: {'saga': name},
  );
}

/// What a step's action or compensation is given.
class TomSagaContext {
  TomSagaContext._(
    TomSagaState state, {
    required this.stepName,
    required this.attempt,
    required this.isCompensating,
  }) : sagaId = state.id,
       sagaName = state.name,
       failure = state.error,
       data = jsonDecode(jsonEncode(state.data)) as Map<String, Object?>;

  /// The saga's id.
  final String sagaId;

  /// The saga's name.
  final String sagaName;

  /// The step being run or compensated.
  final String stepName;

  /// Which attempt this is, 1-based.
  final int attempt;

  /// Whether this is a compensation.
  final bool isCompensating;

  /// While compensating: why the saga compensates.
  final String? failure;

  /// The saga's data. An action may change it, and the change is saved with
  /// the step — so a later step, and the step's own compensation, see what it
  /// recorded (a reservation id, a payment reference). It must stay
  /// JSON-encodable. Changes made by a compensation are saved too; changes by
  /// an attempt that fails are not.
  final Map<String, Object?> data;
}

/// Where a saga is in its life.
enum TomSagaStatus {
  /// Running its steps.
  running,

  /// A step failed for good; compensating the steps done before it.
  compensating,

  /// Every step ran.
  completed,

  /// A step failed for good, and every step before it was compensated.
  compensated,

  /// A compensation failed for good: the saga is left half done, for an
  /// operator.
  failed;

  /// Whether the saga has ended.
  bool get isFinished =>
      this == completed || this == compensated || this == failed;

  /// The status stored as [name].
  static TomSagaStatus parse(String name) =>
      values.firstWhere((status) => status.name == name);
}

/// The persisted progress of one saga.
class TomSagaState {
  /// A state; see the fields.
  const TomSagaState({
    required this.id,
    required this.name,
    required this.tenant,
    required this.status,
    required this.step,
    required this.version,
    required this.data,
    required this.runWindow,
    required this.createdAt,
    required this.updatedAt,
    this.error,
  });

  /// The saga's id, unique within its tenant.
  final String id;

  /// The saga's name: which [TomSaga] it runs.
  final String name;

  /// The tenant the saga runs for, `''` for none.
  final String tenant;

  /// Where the saga is.
  final TomSagaStatus status;

  /// The cursor: the next step to run while [TomSagaStatus.running], the next
  /// step to compensate while [TomSagaStatus.compensating].
  final int step;

  /// Grows by one with every transition; a transition is written only over the
  /// version it was made from.
  final int version;

  /// The saga's data.
  final Map<String, Object?> data;

  /// Why the saga compensates, or failed.
  final String? error;

  /// The window instant of the job run that carries this version — its
  /// identity in the job store, not when it is due.
  final DateTime runWindow;

  /// When the saga began.
  final DateTime createdAt;

  /// When the saga last moved.
  final DateTime updatedAt;

  TomSagaState _next({
    required TomSagaStatus status,
    required int step,
    required Map<String, Object?> data,
    required DateTime now,
    String? error,
  }) => TomSagaState(
    id: id,
    name: name,
    tenant: tenant,
    status: status,
    step: step,
    version: version + 1,
    data: data,
    error: error,
    runWindow: TomEventInstants.next(now),
    createdAt: createdAt,
    updatedAt: now.toUtc(),
  );

  @override
  String toString() =>
      'TomSagaState($name $id: ${status.name} at step $step, v$version)';
}

/// Where saga states are kept.
///
/// Every operation works in the tenant in context: [load] and [unfinished] see
/// only that tenant's sagas.
abstract class TomSagaStore {
  /// Makes the store ready — creates its table — for the data source this
  /// context resolves. Called outside any transaction, before the others.
  Future<void> prepare();

  /// Stores a new saga; answers `false` when its id is taken.
  Future<bool> insert(TomSagaState state);

  /// The saga [id] of the tenant in context, or `null`.
  Future<TomSagaState?> load(String id);

  /// Writes [state] when the stored version is [expectedVersion]; answers
  /// whether it did.
  Future<bool> update(TomSagaState state, {required int expectedVersion});

  /// The unfinished sagas of the tenant in context.
  Future<List<TomSagaState>> unfinished();

  /// Removes the sagas of the tenant in context that finished before
  /// [before]; answers how many.
  Future<int> purgeFinishedBefore(DateTime before);
}

String get _currentTenant => TomTenantContext.currentId ?? '';

/// Saga states in memory: for tests, and for a single process that may lose
/// its sagas on restart.
class TomMemorySagaStore implements TomSagaStore {
  final Map<(String, String), TomSagaState> _states = {};

  @override
  Future<void> prepare() async {}

  @override
  Future<bool> insert(TomSagaState state) async {
    final key = (state.tenant, state.id);
    if (_states.containsKey(key)) return false;
    _states[key] = state;
    return true;
  }

  @override
  Future<TomSagaState?> load(String id) async => _states[(_currentTenant, id)];

  @override
  Future<bool> update(
    TomSagaState state, {
    required int expectedVersion,
  }) async {
    final key = (state.tenant, state.id);
    if (_states[key]?.version != expectedVersion) return false;
    // Encoded as the SQL store does, so data that would not survive a database
    // fails here as well.
    jsonEncode(state.data);
    _states[key] = state;
    return true;
  }

  @override
  Future<List<TomSagaState>> unfinished() async => [
    for (final state in _states.values)
      if (state.tenant == _currentTenant && !state.status.isFinished) state,
  ];

  @override
  Future<int> purgeFinishedBefore(DateTime before) async {
    final old = [
      for (final e in _states.entries)
        if (e.key.$1 == _currentTenant &&
            e.value.status.isFinished &&
            e.value.updatedAt.isBefore(before.toUtc()))
          e.key,
    ];
    old.forEach(_states.remove);
    return old.length;
  }
}

/// Saga states in a SQL data source — the store a saga's steps share their
/// local transaction with.
///
/// The data source is resolved by name on every call, so under tenancy a
/// tenant's sagas are kept in the tenant's data source.
class TomSqlSagaStore implements TomSagaStore {
  /// A store in [table] of the data source registered as [datasourceName].
  ///
  /// With [createSchema] (the default) the table is created on first use in
  /// each data source; a deployment whose user may not run DDL applies the
  /// shipped migration and passes `false`.
  TomSqlSagaStore(
    String this.datasourceName, {
    this.table = defaultSagaTable,
    this.createSchema = true,
  }) : _fixed = null;

  /// A store in [table] of [datasource] itself, resolved once.
  TomSqlSagaStore.over(
    TomDataSource datasource, {
    this.table = defaultSagaTable,
    this.createSchema = true,
  }) : datasourceName = null,
       _fixed = datasource;

  /// The registered name of the data source, or `null` for a store built
  /// [TomSqlSagaStore.over] one.
  final String? datasourceName;

  final TomDataSource? _fixed;

  /// The table's name.
  final String table;

  /// Whether the table is created on first use.
  final bool createSchema;

  late final TomFrameworkTable _table = sagaTable(table);
  final Expando<TomSchemaProvisioning> _schemas = Expando();

  TomDataSource _resolve() {
    final fixed = _fixed;
    if (fixed != null) return fixed;
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName!);
    if (info == null) {
      throw TomSagaException(
        'transactions.saga.no_datasource',
        "The saga store's data source '$datasourceName' is not registered.",
        parameters: {'datasource': datasourceName},
      );
    }
    return info.datasource;
  }

  @override
  Future<void> prepare() async {
    if (!createSchema) return;
    final ds = _resolve();
    await (_schemas[ds] ??= TomSchemaProvisioning()).ensure(
      () => _table.create(ds),
    );
  }

  static const String _columns =
      'tenant, saga_id, saga_name, status, step, version, data, error, '
      'run_window, created_at, updated_at';

  static Map<String, Object?> _bind(TomSagaState s) => {
    'tenant': s.tenant,
    'id': s.id,
    'name': s.name,
    'status': s.status.name,
    'step': s.step,
    'version': s.version,
    'data': jsonEncode(s.data),
    'error': s.error,
    'runWindow': sqlInstant(s.runWindow),
    'createdAt': sqlInstant(s.createdAt),
    'updatedAt': sqlInstant(s.updatedAt),
  };

  @override
  Future<bool> insert(TomSagaState state) async {
    final ds = _resolve();
    final inserted = await ds.executeCommand(
      _table.insertRow(ds.sqlDialect, const {
        'tenant': ':tenant',
        'saga_id': ':id',
        'saga_name': ':name',
        'status': ':status',
        'step': ':step',
        'version': ':version',
        'data': ':data',
        'error': ':error',
        'run_window': ':runWindow',
        'created_at': ':createdAt',
        'updated_at': ':updatedAt',
      }, ignoreConflict: true),
      _bind(state),
    );
    return inserted != BigInt.zero;
  }

  @override
  Future<TomSagaState?> load(String id) async {
    final rows = await _resolve().executeQuery<TomSagaRow>(
      'SELECT $_columns FROM $table WHERE tenant = :tenant AND saga_id = :id',
      {'tenant': _currentTenant, 'id': id},
    );
    return rows.isEmpty ? null : rows.single.toState();
  }

  @override
  Future<bool> update(
    TomSagaState state, {
    required int expectedVersion,
  }) async {
    final updated = await _resolve().executeCommand(
      'UPDATE $table SET status = :status, step = :step, version = :version, '
      'data = :data, error = :error, run_window = :runWindow, updated_at = :updatedAt '
      'WHERE tenant = :tenant AND saga_id = :id AND version = :expected',
      {..._bind(state), 'expected': expectedVersion},
    );
    return updated != BigInt.zero;
  }

  @override
  Future<List<TomSagaState>> unfinished() async {
    final rows = await _resolve().executeQuery<TomSagaRow>(
      'SELECT $_columns FROM $table WHERE tenant = :tenant AND status IN '
      "('running', 'compensating') ORDER BY updated_at",
      {'tenant': _currentTenant},
    );
    return [for (final row in rows) row.toState()];
  }

  @override
  Future<int> purgeFinishedBefore(DateTime before) async {
    final removed = await _resolve().executeCommand(
      'DELETE FROM $table WHERE tenant = :tenant AND status IN '
      "('completed', 'compensated', 'failed') AND updated_at < :before",
      {'tenant': _currentTenant, 'before': sqlInstant(before)},
    );
    return removed.toInt();
  }

  /// Empties the table of the data source this context resolves. For tests.
  Future<void> deleteAll() async {
    await prepare();
    await _resolve().executeCommand('DELETE FROM $table');
  }
}

/// One row of the saga table, as [TomSqlSagaStore] reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["tenant", "sagaId"],
)
class TomSagaRow {
  /// The tenant, `''` for none.
  @TomDbColumn(columnName: "tenant")
  String tenant = "";

  /// The saga's id.
  @TomDbColumn(columnName: "saga_id")
  String sagaId = "";

  /// The saga's name.
  @TomDbColumn(columnName: "saga_name")
  String sagaName = "";

  /// The status's name.
  @TomDbColumn(columnName: "status")
  String status = "";

  /// The cursor.
  @TomDbColumn(columnName: "step")
  int step = 0;

  /// The version.
  @TomDbColumn(columnName: "version")
  int version = 0;

  /// The data, as JSON.
  @TomDbColumn(columnName: "data")
  String data = "{}";

  /// Why the saga compensates or failed.
  @TomDbColumn(columnName: "error")
  String? error;

  /// The current run's window instant, as stored UTC text.
  @TomDbColumn(columnName: "run_window")
  String runWindow = "";

  /// When the saga began, as stored UTC text.
  @TomDbColumn(columnName: "created_at")
  String createdAt = "";

  /// When the saga last moved, as stored UTC text.
  @TomDbColumn(columnName: "updated_at")
  String updatedAt = "";

  /// The state this row stores.
  TomSagaState toState() => TomSagaState(
    id: sagaId,
    name: sagaName,
    tenant: tenant,
    status: TomSagaStatus.parse(status),
    step: step,
    version: version,
    data: (jsonDecode(data) as Map).cast<String, Object?>(),
    error: error,
    runWindow: parseSqlInstant(runWindow),
    createdAt: parseSqlInstant(createdAt),
    updatedAt: parseSqlInstant(updatedAt),
  );
}

/// The default prefix of the orchestrator's job names: a saga `place_order`
/// runs its steps as job `saga.place_order` and its compensations as
/// `saga.place_order.compensation`.
///
/// Stable across restarts by necessity, like every job name: it ties queued
/// runs to the definitions that execute them.
const String tomSagaJobPrefix = 'saga';

/// Runs sagas — see the library documentation.
class TomSagaOrchestrator implements TomClosable {
  /// An orchestrator keeping saga states in [store] and its runs in
  /// [jobStore].
  ///
  /// Both default to memory, which is right for tests and wrong for any
  /// deployment: a saga kept in memory is lost by a restart, which is what a
  /// saga exists to survive. Give a durable job store — the one the outbox and
  /// the application's scheduler use is the right one — and a [TomSqlSagaStore].
  factory TomSagaOrchestrator({
    TomSagaStore? store,
    TomJobStore? jobStore,
    String jobPrefix = tomSagaJobPrefix,
    Duration tickInterval = const Duration(seconds: 15),
    Duration sweepInterval = const Duration(minutes: 5),
    Duration leaseTimeout = const Duration(minutes: 15),
    DateTime Function()? clock,
    TomJobAlertSink? onAlert,
    TomLeaseLock? lock,
  }) {
    final queue = jobStore ?? TomMemoryJobStore();
    return TomSagaOrchestrator._(
      store: store ?? TomMemorySagaStore(),
      jobStore: queue,
      jobPrefix: jobPrefix,
      sweepInterval: sweepInterval,
      clock: clock ?? DateTime.now,
      scheduler: TomScheduler(
        store: queue,
        dispatcher: const TomInlineJobDispatcher(),
        tickInterval: tickInterval,
        leaseTimeout: leaseTimeout,
        clock: clock,
        onAlert: onAlert,
        lock: lock,
      ),
    );
  }

  TomSagaOrchestrator._({
    required this.store,
    required this.jobStore,
    required this.jobPrefix,
    required this.sweepInterval,
    required this.scheduler,
    required DateTime Function() clock,
  }) : _clock = clock;

  /// Where saga states are kept.
  final TomSagaStore store;

  /// The queue the saga runs are in.
  final TomJobStore jobStore;

  /// The prefix of the job names — see [tomSagaJobPrefix].
  final String jobPrefix;

  /// How often [start]ed orchestration looks for sagas whose run is gone.
  final Duration sweepInterval;

  /// The scheduler running the transitions. Owned and closed by [close].
  final TomScheduler scheduler;

  final DateTime Function() _clock;
  final Map<String, TomSaga> _sagas = {};
  Timer? _sweep;
  bool _closed = false;
  Future<void>? _closing;

  /// The registered sagas, by name.
  Map<String, TomSaga> get sagas => Map.unmodifiable(_sagas);

  /// The job running the steps of [saga].
  String stepJobName(String saga) => '$jobPrefix.$saga';

  /// The job running the compensations of [saga].
  String compensationJobName(String saga) => '$jobPrefix.$saga.compensation';

  /// Registers [saga], so it can be begun and its runs executed.
  ///
  /// Every node that may run a saga registers it, under the same name: the
  /// scheduler takes no run of a job it has not registered.
  void register(TomSaga saga) {
    _requireOpen();
    if (_sagas.containsKey(saga.name)) {
      throw TomSagaException(
        'transactions.saga.already_registered',
        "A saga named '${saga.name}' is registered already.",
        parameters: {'saga': saga.name},
      );
    }
    _sagas[saga.name] = saga;
    for (final (job, policy) in [
      (stepJobName(saga.name), saga.retryPolicy),
      (compensationJobName(saga.name), saga.compensationRetryPolicy),
    ]) {
      scheduler.register(
        TomJobDefinition(
          name: job,
          // Never clock-driven: a transition is queued by the one before it.
          schedule: const TomEventSchedule(
            Stream<Object?>.empty(),
            sourceName: 'saga',
          ),
          body: (run) => _TomSagaCommand(this, run),
          retryPolicy: policy,
          timeout: saga.timeout,
          // Sagas are independent; per-run overlap is also what keys the
          // cluster lease per run rather than per job.
          allowOverlap: true,
          // Safe: an interrupted transition rolled back with its process, and
          // one that committed has moved the saga past the run's version.
          requestsRecovery: true,
        ),
      );
    }
  }

  /// Begins the saga [sagaName] with [data], for the tenant in context, and
  /// answers its id: [id], or a new UUID.
  ///
  /// Returns once the saga is stored and its first step queued. Called inside
  /// a transaction on the saga store's data source, the saga begins only if
  /// that transaction commits.
  Future<String> begin(
    String sagaName, {
    Map<String, Object?> data = const {},
    String? id,
  }) async {
    _requireOpen();
    if (!_sagas.containsKey(sagaName)) {
      throw TomSagaException(
        'transactions.saga.unknown',
        "No saga named '$sagaName' is registered.",
        parameters: {'saga': sagaName},
      );
    }
    final sagaId = id ?? const UuidV4().generate();
    if (sagaId.isEmpty || sagaId.length > 128) {
      throw TomSagaException(
        'transactions.saga.invalid_id',
        'A saga id is 1 to 128 characters long.',
        parameters: {'length': sagaId.length},
      );
    }
    final Map<String, Object?> copy;
    try {
      copy = (jsonDecode(jsonEncode(data)) as Map).cast<String, Object?>();
    } on JsonUnsupportedObjectError catch (error) {
      throw TomSagaException(
        'transactions.saga.data_not_json',
        "The data of saga '$sagaName' is not JSON-encodable: it contains "
            '${error.unsupportedObject.runtimeType}.',
        parameters: {'saga': sagaName},
      );
    }
    final now = _clock().toUtc();
    final state = TomSagaState(
      id: sagaId,
      name: sagaName,
      tenant: _currentTenant,
      status: TomSagaStatus.running,
      step: 0,
      version: 0,
      data: copy,
      runWindow: TomEventInstants.next(now),
      createdAt: now,
      updatedAt: now,
    );
    await store.prepare();
    if (!await store.insert(state)) {
      throw TomSagaException(
        'transactions.saga.id_taken',
        "A saga with the id '$sagaId' exists already.",
        parameters: {'saga': sagaName, 'id': sagaId},
      );
    }
    await _enqueue(state);
    return sagaId;
  }

  /// The saga [id] of the tenant in context, or `null`.
  Future<TomSagaState?> find(String id) async {
    await store.prepare();
    return store.load(id);
  }

  /// Re-queues the run of every unfinished saga whose run is no longer in the
  /// job store, and answers how many it re-queued.
  ///
  /// Looks in the context's tenant and, when a [TomTenancy] is installed, in
  /// every tenant's. Called by [start] and every [sweepInterval] after it.
  Future<int> resume() async {
    var count = await _resumeHere();
    final tenancy = TomTenancy.current;
    if (tenancy != null) {
      for (final tenant in List.of(tenancy.tenants.keys)) {
        if (tenant == TomTenantContext.currentId) continue;
        count += await TomTenantContext.run(tenant, _resumeHere);
      }
    }
    return count;
  }

  Future<int> _resumeHere() async {
    await store.prepare();
    var count = 0;
    for (final state in await store.unfinished()) {
      if (!_sagas.containsKey(state.name)) continue;
      final run = await jobStore.findWindow(
        _jobOf(state),
        state.runWindow,
        tenant: state.tenant.isEmpty ? null : state.tenant,
      );
      if (run != null && !run.isFinished) continue;
      await _enqueue(state);
      count++;
    }
    return count;
  }

  /// Resumes the unfinished sagas ([resume]), then runs transitions on the
  /// scheduler's tick and looks for stranded sagas every [sweepInterval].
  Future<void> start() async {
    _requireOpen();
    await resume();
    _sweep ??= Timer.periodic(sweepInterval, (_) {
      unawaited(
        resume().catchError((Object error) {
          tomLog.warn('Saga sweep failed: $error');
          return 0;
        }),
      );
    });
    unawaited(scheduler.start());
  }

  /// Runs one pass of due transitions and waits for them to finish. For tests,
  /// and for a caller that wants a saga moved on now.
  ///
  /// While the orchestrator is [start]ed, a pass of its own may be under way;
  /// this one then returns at once, and the transitions are that pass's.
  Future<void> tick() async {
    await scheduler.tick();
    await scheduler.drain();
  }

  /// Stops running sagas and closes the scheduler, releasing its leases. The
  /// sagas stay where they are, and the next start resumes them.
  @override
  Future<void> close() => _closing ??= _shutDown();

  Future<void> _shutDown() async {
    _closed = true;
    _sweep?.cancel();
    await scheduler.close();
  }

  void _requireOpen() {
    if (_closed) {
      throw TomSagaException(
        'transactions.saga.closed',
        'The saga orchestrator has been closed.',
      );
    }
  }

  String _jobOf(TomSagaState state) =>
      state.status == TomSagaStatus.compensating
      ? compensationJobName(state.name)
      : stepJobName(state.name);

  Future<void> _enqueue(TomSagaState state) => jobStore.enqueue(
    TomJobRun(
      id: 'saga:${state.tenant}:${state.id}:${state.version}',
      jobName: _jobOf(state),
      scheduledFor: state.runWindow,
      // Due now: the window instant only keeps the run apart from others.
      runAt: _clock(),
      payload: {'saga': state.id, 'version': state.version},
      tenant: state.tenant.isEmpty ? null : state.tenant,
    ),
  );

  /// The highest step at or before [from] that has a compensation, or -1.
  static int _lastCompensable(TomSaga saga, int from) {
    var cursor = from;
    while (cursor >= 0 && saga.steps[cursor].compensation == null) {
      cursor--;
    }
    return cursor;
  }

  /// Runs the transition [run] carries.
  Future<Object?> _advance(TomJobRun run) async {
    final payload = run.payload;
    if (payload is! Map ||
        payload['saga'] is! String ||
        payload['version'] is! int) {
      // throws-outside-family: kernel protocol — the scheduler's signal for a
      // run that must not be retried.
      throw TomPermanentJobFailure(
        'Saga run ${run.id} carries no readable saga reference.',
      );
    }
    await store.prepare();
    final state = await store.load(payload['saga'] as String);
    if (state == null ||
        state.status.isFinished ||
        state.version != payload['version']) {
      return 'superseded';
    }
    final saga = _sagas[state.name];
    if (saga == null) {
      // throws-outside-family: kernel protocol — as above.
      throw TomPermanentJobFailure(
        "Saga run ${run.id} is for the saga '${state.name}', which is not "
        'registered here.',
      );
    }
    return state.status == TomSagaStatus.running
        ? _runStep(saga, state, run)
        : _compensate(saga, state, run);
  }

  /// Writes [next] over [state] in the transaction in context, rolling it back
  /// when the saga moved on.
  Future<TomSagaState> _move(TomSagaState state, TomSagaState next) async {
    if (!await store.update(next, expectedVersion: state.version)) {
      throw TomSagaException(
        _superseded,
        "The saga '${state.name}' ${state.id} moved past version "
        '${state.version} while this transition ran.',
        parameters: {'saga': state.name, 'id': state.id},
      );
    }
    return next;
  }

  static const String _superseded = 'transactions.saga.superseded';

  static bool _isSuperseded(Object error) =>
      error is TomSagaException && error.key == _superseded;

  Future<Object?> _runStep(
    TomSaga saga,
    TomSagaState state,
    TomJobRun run,
  ) async {
    final step = saga.steps[state.step];
    final context = TomSagaContext._(
      state,
      stepName: step.name,
      attempt: run.attempt,
      isCompensating: false,
    );
    final last = state.step == saga.steps.length - 1;
    TomSagaState next;
    try {
      next = await TomTransactionManager.runInTransaction((_) async {
        await step.action(context);
        return _move(
          state,
          state._next(
            status: last ? TomSagaStatus.completed : TomSagaStatus.running,
            step: state.step + 1,
            data: context.data,
            now: _clock(),
          ),
        );
      });
    } catch (error) {
      if (_isSuperseded(error)) return 'superseded';
      if (error is! TomPermanentFailure &&
          saga.retryPolicy.allowsRetryAfter(run.attempt)) {
        rethrow;
      }
      // The step failed for good: compensate the steps done before it.
      final cursor = _lastCompensable(saga, state.step - 1);
      try {
        next = await TomTransactionManager.runInTransaction(
          (_) => _move(
            state,
            state._next(
              status: cursor < 0
                  ? TomSagaStatus.compensated
                  : TomSagaStatus.compensating,
              step: cursor,
              data: state.data,
              now: _clock(),
              error: "step '${step.name}': $error",
            ),
          ),
        );
      } catch (moved) {
        if (_isSuperseded(moved)) return 'superseded';
        rethrow;
      }
    }
    if (!next.status.isFinished) await _enqueue(next);
    return next.status.name;
  }

  Future<Object?> _compensate(
    TomSaga saga,
    TomSagaState state,
    TomJobRun run,
  ) async {
    final step = saga.steps[state.step];
    final context = TomSagaContext._(
      state,
      stepName: step.name,
      attempt: run.attempt,
      isCompensating: true,
    );
    TomSagaState next;
    try {
      next = await TomTransactionManager.runInTransaction((_) async {
        await step.compensation!(context);
        final cursor = _lastCompensable(saga, state.step - 1);
        return _move(
          state,
          state._next(
            status: cursor < 0
                ? TomSagaStatus.compensated
                : TomSagaStatus.compensating,
            step: cursor,
            data: context.data,
            now: _clock(),
            error: state.error,
          ),
        );
      });
    } catch (error) {
      if (_isSuperseded(error)) return 'superseded';
      if (error is! TomPermanentFailure &&
          saga.compensationRetryPolicy.allowsRetryAfter(run.attempt)) {
        rethrow;
      }
      final reason =
          "${state.error}; compensation of step '${step.name}': $error";
      try {
        await TomTransactionManager.runInTransaction(
          (_) => _move(
            state,
            state._next(
              status: TomSagaStatus.failed,
              step: state.step,
              data: state.data,
              now: _clock(),
              error: reason,
            ),
          ),
        );
      } catch (moved) {
        if (_isSuperseded(moved)) return 'superseded';
        rethrow;
      }
      // throws-outside-family: kernel protocol — ends the run and raises the
      // scheduler's alert, which is how an operator learns of the saga.
      throw TomPermanentJobFailure(
        "Saga '${state.name}' ${state.id} failed: the compensation of step "
        "'${step.name}' failed for good, and the steps before it are not "
        'compensated.',
        cause: error,
      );
    }
    if (!next.status.isFinished) await _enqueue(next);
    return next.status.name;
  }
}

/// Runs one saga transition. Never leaves the isolate — the orchestrator's
/// scheduler dispatches inline.
class _TomSagaCommand extends TomCommand {
  _TomSagaCommand(this._orchestrator, this._run);

  final TomSagaOrchestrator _orchestrator;
  final TomJobRun _run;

  @override
  Future<Object?> execute() => _orchestrator._advance(_run);
}

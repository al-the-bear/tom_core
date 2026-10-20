/// The schema of the saga table.
///
/// Declared **once**, as a [TomFrameworkTable], like every framework table;
/// the shipped migration under `example/transactions/migrations/` stays
/// hand-written and `test/framework_schema_test.dart` fails if the two drift.
library;

import '../datasources/framework_table.dart';

/// The default name of the saga table.
const String defaultSagaTable = 'tom_saga';

/// The saga table [table], declared once.
///
/// Notes on the shape:
///
///  * the primary key is `(tenant, saga_id)`; `tenant` is `''` for a saga
///    started outside a tenant.
///  * `status` is the saga's lifecycle (`running`, `compensating`,
///    `completed`, `compensated`, `failed`) and `step` its cursor: the next
///    step to run while running, the next step to compensate while
///    compensating.
///  * `version` grows by one with every transition and is the optimistic lock:
///    a transition is an `UPDATE … WHERE version = :expected`, so of two nodes
///    advancing one saga only one succeeds.
///  * `data` is the saga's JSON data, written with every transition; `error`
///    is why it compensates or failed.
///  * `run_window` is the window instant of the job run that carries the
///    current version — its key in the job store — which is how a resumption
///    finds out whether that run still exists.
///  * `(status, updated_at)` is indexed: resumption and the purge read
///    unfinished and old finished sagas.
TomFrameworkTable sagaTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'sagaTable',
  columns: const [
    TomFrameworkColumn('tenant', 'VARCHAR(32)'),
    TomFrameworkColumn('saga_id', 'VARCHAR(191)'),
    TomFrameworkColumn('saga_name', 'VARCHAR(120)'),
    TomFrameworkColumn('status', 'VARCHAR(16)'),
    TomFrameworkColumn('step', 'INT'),
    TomFrameworkColumn('version', 'INT'),
    TomFrameworkColumn('data', 'LONGTEXT'),
    TomFrameworkColumn('error', 'TEXT', nullable: true),
    TomFrameworkColumn('run_window', 'DATETIME(6)'),
    TomFrameworkColumn('created_at', 'DATETIME(6)'),
    TomFrameworkColumn('updated_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['tenant', 'saga_id'],
  keys: const [
    TomFrameworkKey('progress', ['status', 'updated_at']),
  ],
);

/// The DDL for the saga table [table].
String sagaTableDdl(String table) => sagaTable(table).createTableDdl;

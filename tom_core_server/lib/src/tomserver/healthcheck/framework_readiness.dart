/// The framework's own readiness question: can this server reach what every
/// Tom server needs — its data sources, a migrated schema, a delivering
/// outbox?
///
/// `TomServer.start` installs [TomFrameworkReadinessAnalyzer] on `GET /ready`
/// when the application installed no readiness analyzer of its own (the
/// `frameworkReadiness` configuration key, on by default). An application with
/// further dependencies installs its own analyzer and asks this one first:
///
/// ```dart
/// class MyReadiness extends TomHealthAnalyzer {
///   final _framework = TomFrameworkReadinessAnalyzer();
///   @override
///   Future<TomHealthStatus> analyzeHealth(TomHealthCheck check) async {
///     final framework = await _framework.analyzeHealth(check);
///     if (!framework.isHealthy) return framework;
///     return await searchIndexAnswers()
///         ? framework
///         : const TomHealthStatus.unhealthy('search index unreachable');
///   }
/// }
/// ```
///
/// Readiness only: none of these is a reason to restart the process, and
/// liveness (`GET /health`) is left to its own analyzer.
library;

import 'dart:async';

import '../datasources/datasource_initialization.dart';
import '../datasources/sql_datasource.dart';
import '../db_migration/db_migration.dart';
import '../db_migration/migration_run.dart';
import '../messaging/outbox.dart';
import 'health_check.dart';

/// One check of [TomFrameworkReadinessAnalyzer]: what was checked, and what
/// was found.
class TomReadinessCheck {
  /// A check of [subject] that [passed], with a [detail] saying what was seen.
  const TomReadinessCheck(this.subject, {required this.passed, this.detail});

  /// What was checked: `datasource app`, `migrations`, `outbox messaging.outbox`.
  final String subject;

  /// Whether it allows traffic.
  final bool passed;

  /// What was seen — `ok`, or the reason it does not pass.
  final String? detail;

  @override
  String toString() => '$subject: ${detail ?? (passed ? 'ok' : 'failed')}';
}

/// Answers readiness from the data sources, the migrations and the outboxes of
/// this process — see the library documentation.
///
/// | Check | Ready when |
/// | ----- | ---------- |
/// | every registered data source | it reports operational, and an SQL data source answers `SELECT 1` within [dataSourceTimeout] |
/// | migrations, per target | the system schema of the last [TomDbMigrations.migrateAll] call in this process is not running and has not failed; each shared schema and tenant is listed with its state and does not hold the server back |
/// | every started [TomMessageOutbox] | its scheduler is running, and — when [maxOutboxWait] is set — no message has waited longer |
///
/// The body lists every check, one per line, after `ready` or `not ready`, so
/// the reason is on the wire next to the status code.
///
/// A migration that was never run in this process passes: a deployment whose
/// schema is applied by a DBA or a job never calls `migrateAll`, and a
/// readiness check that waited for it would never pass.
///
/// [maxOutboxWait] is off by default, and deliberately. Every node of a
/// cluster delivers from the same queue, so a backlog caused by a slow relay
/// would take every node out of the load balancer at once — refusing the
/// requests that are not waiting on mail at all. Set it where the outbox is
/// the service's purpose.
class TomFrameworkReadinessAnalyzer extends TomHealthAnalyzer {
  /// An analyzer with the given limits.
  TomFrameworkReadinessAnalyzer({
    this.dataSourceTimeout = const Duration(seconds: 2),
    this.maxOutboxWait,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// How long an SQL data source may take to answer `SELECT 1`.
  final Duration dataSourceTimeout;

  /// How long the oldest queued message may wait before the server is not
  /// ready; `null` — the default — does not look at the backlog.
  final Duration? maxOutboxWait;

  final DateTime Function() _clock;

  @override
  Future<TomHealthStatus> analyzeHealth(TomHealthCheck check) async {
    final checks = await this.checks(check);
    final passed = checks.every((c) => c.passed);
    final body = [passed ? 'ready' : 'not ready', ...checks].join('\n');
    return passed
        ? TomHealthStatus.healthy(body)
        : TomHealthStatus.unhealthy(body);
  }

  /// Every check, in the order the body lists them.
  ///
  /// Given a [check], stops between its stages once the probe has given up:
  /// a cancelled check throws [TomHealthCheckCancelled] instead of asking the
  /// outboxes after the data sources.
  Future<List<TomReadinessCheck>> checks([TomHealthCheck? check]) async {
    final dataSources = await Future.wait(_dataSources().map(_checkDataSource));
    check?.throwIfCancelled();
    final migrations = _checkMigrations();
    final outboxes = await Future.wait(
      TomMessageOutbox.started.map(_checkOutbox),
    );
    return [...dataSources, ...migrations, ...outboxes];
  }

  /// The registered data sources, each once: a `delegateTo` alias shares its
  /// target's entry.
  static Iterable<TomDataSourceInfo> _dataSources() {
    final seen = <TomDataSourceInfo>{};
    return [
      for (final info in TomDataSourceInfo.datasources.values)
        if (seen.add(info)) info,
    ];
  }

  Future<TomReadinessCheck> _checkDataSource(TomDataSourceInfo info) async {
    final subject = 'datasource ${info.name}';
    if (!info.isOperational) {
      return TomReadinessCheck(
        subject,
        passed: false,
        detail: 'not operational',
      );
    }
    final datasource = info.datasource;
    if (datasource is! TomSqlDatasource) {
      return TomReadinessCheck(subject, passed: true, detail: 'ok');
    }
    try {
      await datasource.executeCommand('SELECT 1').timeout(dataSourceTimeout);
      return TomReadinessCheck(subject, passed: true, detail: 'ok');
    } on TimeoutException {
      return TomReadinessCheck(
        subject,
        passed: false,
        detail: 'SELECT 1 did not answer within $dataSourceTimeout',
      );
    } catch (error) {
      return TomReadinessCheck(
        subject,
        passed: false,
        detail: 'SELECT 1 failed: $error',
      );
    }
  }

  /// One check per migration target of the last [TomDbMigrations.migrateAll]
  /// call, or a passing `migrations` check when none was made.
  ///
  /// The system schema's check passes only once it succeeded: without its
  /// tables nothing is served. A shared schema's or a tenant's check passes
  /// whatever its state, with the state as its detail — a tenant still
  /// migrating, or whose migration failed, is refused on its own
  /// (`tenancy.tenant.unavailable`) while the others are served.
  static List<TomReadinessCheck> _checkMigrations() {
    final runs = TomDbMigrations.runs;
    if (runs.isEmpty) {
      return const [
        TomReadinessCheck(
          'migrations',
          passed: true,
          detail: 'not run in this process',
        ),
      ];
    }
    return [
      for (final run in runs)
        TomReadinessCheck(
          'migrations ${run.target}',
          passed:
              run.kind != TomMigrationTargetKind.system ||
              run.state == TomMigrationRunState.succeeded,
          detail: switch (run.state) {
            TomMigrationRunState.succeeded => 'ok',
            TomMigrationRunState.running => 'running',
            TomMigrationRunState.notRun => 'not run',
            TomMigrationRunState.failed => 'failed: ${run.error}',
          },
        ),
    ];
  }

  Future<TomReadinessCheck> _checkOutbox(TomMessageOutbox outbox) async {
    final subject = 'outbox ${outbox.jobName}';
    if (!outbox.scheduler.isRunning) {
      return TomReadinessCheck(
        subject,
        passed: false,
        detail: 'not delivering: its scheduler is stopped',
      );
    }
    final limit = maxOutboxWait;
    if (limit == null) {
      return TomReadinessCheck(subject, passed: true, detail: 'ok');
    }
    try {
      final since = await outbox.oldestWaitingSince().timeout(
        dataSourceTimeout,
      );
      final waited = since == null ? Duration.zero : _clock().difference(since);
      if (waited > limit) {
        return TomReadinessCheck(
          subject,
          passed: false,
          detail: 'the oldest message has waited $waited, over $limit',
        );
      }
      return TomReadinessCheck(subject, passed: true, detail: 'ok');
    } catch (error) {
      return TomReadinessCheck(
        subject,
        passed: false,
        detail: 'its queue could not be read: $error',
      );
    }
  }
}

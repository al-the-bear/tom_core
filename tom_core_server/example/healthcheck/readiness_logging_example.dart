// ignore_for_file: avoid_print
/// Executable example of what a server tells an operator's tooling about
/// itself: the framework readiness checks behind `GET /ready`, and the
/// structured log line every request writes.
///
/// Readiness first. [TomFrameworkReadinessAnalyzer] asks what every Tom server
/// needs — its data sources answering, no database migration running or
/// failed, every started message outbox delivering — and answers `ready` or
/// `not ready` with one line per check. `TomServer.start` installs it on
/// `GET /ready` unless the application installed a readiness analyzer of its
/// own; an application with further dependencies composes it into its own.
///
/// Then the logs. `tomRequestContextMiddleware` gives a request its request id
/// and continues the caller's W3C trace, and with `logFormat: json` every line
/// written while serving is one JSON object carrying `trace_id`, `span_id`,
/// `request_id` and `tenant`.
///
/// No server is started and no database is needed: the readiness checks are
/// asked directly, the failed migration is a migrations directory that does
/// not exist, and the request runs through the middleware around a handler of
/// its own. `doc/healthcheck.md` and `doc/server.md` describe both in a real
/// server.
///
/// Run with `dart run example/healthcheck/readiness_logging_example.dart`.
/// Every step checks its own result and the run fails when one does not hold,
/// so a green run is a verification and not just a transcript.
///
/// The behaviour shown here is pinned by
/// `test/structured_logs_readiness_test.dart`.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// The caller's trace: a W3C `traceparent` a client or a gateway sends.
const _traceparent = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';

/// An application's readiness: the framework's checks first, then a
/// dependency of its own.
class _AppReadiness extends TomHealthAnalyzer {
  _AppReadiness({required this.searchIndexAnswers});

  final bool searchIndexAnswers;
  final _framework = TomFrameworkReadinessAnalyzer();

  @override
  Future<TomHealthStatus> analyzeHealth(TomHealthCheck check) async {
    final framework = await _framework.analyzeHealth(check);
    if (!framework.isHealthy) return framework;
    return searchIndexAnswers
        ? framework
        : TomHealthStatus.unhealthy(
            '${framework.message}\nsearch index: unreachable',
          );
  }
}

Future<void> run() async {
  // 1. A process with no data source registered, no migration run and no
  //    outbox started is ready: there is nothing it is waiting for. A
  //    migration never run passes, because a deployment whose schema is
  //    applied by a DBA or a job never runs one.
  final analyzer = TomFrameworkReadinessAnalyzer();
  final ready = await analyzer.analyzeHealth(
    TomHealthCheck('readiness', const Duration(seconds: 5)),
  );
  print('1. nothing registered        => ${ready.statusCode}');
  print(_indent(ready.message));
  check(ready.isHealthy, 'a process waiting for nothing is ready');
  check(
    ready.message.split('\n').first == 'ready',
    'the body opens with the verdict a person reads',
  );
  check(
    ready.message.contains('migrations: not run in this process'),
    'and says the migrations were not run here rather than hiding the check',
  );

  // 2. A migration that failed makes the server not ready — 503, the status a
  //    load balancer acts on — with the reason in the body. The process is
  //    not restarted for it: a restart would not change the schema.
  try {
    try {
      await TomDbMigrations.migrateDatabases('example/does/not/exist');
    } on TomDbMigrationException {
      // The boot step reports it; readiness keeps reporting it.
    }
    final failed = await analyzer.analyzeHealth(
      TomHealthCheck('readiness', const Duration(seconds: 5)),
    );
    print('2. after a failed migration  => ${failed.statusCode}');
    print(_indent(failed.message));
    check(
      TomDbMigrations.lastRun.state == TomMigrationRunState.failed,
      'the failed run is recorded where readiness reads it',
    );
    check(failed.statusCode == 503, 'a failed migration is not ready');
    check(
      failed.message.contains('migrations: failed:'),
      'and the body names the migrations as the reason',
    );
  } finally {
    TomDbMigrations.resetLastRun();
  }

  // 3. A started outbox is checked; one whose scheduler stopped is not
  //    delivering, which is this process's fault and so a reason to take it
  //    out of the load balancer. A backlog is not checked unless
  //    `maxOutboxWait` is set: every node delivers from the same queue, so a
  //    slow relay would take them all out at once.
  final outbox = TomMessageOutbox(
    router: TomMessageRouter()..register(TomMemoryMessageTransport()),
  )..start();
  try {
    final delivering = await analyzer.analyzeHealth(
      TomHealthCheck('readiness', const Duration(seconds: 5)),
    );
    outbox.scheduler.stop();
    final stopped = await analyzer.analyzeHealth(
      TomHealthCheck('readiness', const Duration(seconds: 5)),
    );
    print(
      '3. a started outbox          => ${delivering.statusCode}, '
      'stopped => ${stopped.statusCode}',
    );
    print(_indent(stopped.message));
    check(
      TomMessageOutbox.started.contains(outbox),
      'a started outbox registers itself for readiness',
    );
    check(
      delivering.isHealthy &&
          delivering.message.contains('outbox ${outbox.jobName}: ok'),
      'a delivering outbox is ready',
    );
    check(
      !stopped.isHealthy && stopped.message.contains('not delivering'),
      'an outbox whose scheduler stopped is not',
    );
  } finally {
    await outbox.close();
  }
  check(
    !TomMessageOutbox.started.contains(outbox),
    'a closed outbox is no longer checked',
  );

  // 4. An application with a dependency of its own installs its analyzer —
  //    which keeps `TomServer.start` from installing the framework's — and
  //    asks the framework's first. `/health` stays the liveness default.
  final service = TomHealthServer();
  try {
    TomHealthServer.installReadinessAnalyzer(
      _AppReadiness(searchIndexAnswers: false),
    );
    final readiness = await service.ready();
    final body = await readiness.readAsString();
    final liveness = await service.health();
    print(
      '4. ready() with the app check => ${readiness.statusCode}, '
      'health() => ${liveness.statusCode}',
    );
    print(_indent(body));
    check(
      readiness.statusCode == 503 && body.endsWith('search index: unreachable'),
      'the application check follows the framework checks in one answer',
    );
    check(
      liveness.statusCode == 200,
      'a dependency that is down is not a reason to restart the process',
    );
  } finally {
    TomHealthServer.resetHealthChecks();
  }

  // 5. `logFormat: json` replaces the default console output with a JSON one,
  //    keeps an output the application installed, and refuses a value it does
  //    not know without touching the output.
  final previousOutput = tomLog.logOutput;
  try {
    tomLog.logOutput = TomConsoleLogOutput();
    final json = TomServer.applyLogFormat('json');
    final installed = tomLog.logOutput;
    final own = TomJsonLogOutput(writer: (_, _) {});
    tomLog.logOutput = own;
    final kept = TomServer.applyLogFormat('json');
    print(
      '5. logFormat json            => ${installed.runtimeType}; '
      'an installed output kept: ${identical(tomLog.logOutput, own)}',
    );
    check(
      json && installed is TomJsonLogOutput,
      'json replaces the default console output',
    );
    check(
      kept && identical(tomLog.logOutput, own),
      'an output the application installed is not replaced',
    );
  } finally {
    tomLog.logOutput = previousOutput;
  }

  // 6. A request through `tomRequestContextMiddleware`: it continues the
  //    caller's trace with a span of its own, mints a request id, and every
  //    line logged while serving carries both — the handler passes nothing.
  //    The response names the request id and the server span.
  final lines = <Map<String, Object?>>[];
  final previous = tomLog.logOutput;
  final previousLevel = tomLog.logLevel;
  try {
    tomLog.logOutput = TomJsonLogOutput(
      writer: (line, _) => lines.add(jsonDecode(line) as Map<String, Object?>),
    );
    tomLog.setLogLevel(TomLogLevel.all);
    final handler = const Pipeline()
        .addMiddleware(tomRequestContextMiddleware())
        .addHandler((_) {
          tomLog.info('listing tasks');
          return Response.ok('[]');
        });
    final response = await TomTenantContext.run(
      'acme',
      () async => handler(
        Request(
          'GET',
          Uri.parse('http://localhost/tasks'),
          headers: {'traceparent': _traceparent},
        ),
      ),
    );
    final line = lines.lastWhere((l) => l['message'] == 'listing tasks');
    final serverSpan = TomTraceContext.parse(response.headers['traceparent']);
    print('6. one request, one JSON line =>');
    print('   ${jsonEncode(line)}');
    print('   X-Request-Id: ${response.headers[tomRequestIdHeader]}');
    print('   traceparent:  ${response.headers['traceparent']}');
    check(
      line['trace_id'] == '4bf92f3577b34da6a3ce929d0e0e4736',
      'the line carries the caller\'s trace',
    );
    check(
      line['span_id'] == serverSpan!.spanId &&
          serverSpan.spanId != '00f067aa0ba902b7',
      'under a span of the server\'s own, which the response names',
    );
    check(
      line['request_id'] == response.headers[tomRequestIdHeader],
      'the request id a user quotes is the one in every line',
    );
    check(line['tenant'] == 'acme', 'and the tenant the request ran for');
  } finally {
    tomLog.logOutput = previous;
    tomLog.setLogLevel(previousLevel);
  }

  print('\nReadiness and structured logging example completed.');
}

/// [text] indented under its step.
String _indent(String text) => text.split('\n').map((l) => '   $l').join('\n');

Future<void> main() async {
  await run();
}

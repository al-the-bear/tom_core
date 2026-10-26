/// Executable example for the health-check module of `tom_core_server`.
///
/// This example shows the surface you can drive directly: the two pluggable
/// [TomHealthAnalyzer]s, the way each turns its verdict into the status code a
/// probe reads and its message into the body, and why there are two of them —
/// an unready process is still alive — then two instances answering with
/// analyzers of their own, and a timed-out analysis that stops because its
/// analyzer looks at the cancelled check.
/// The `GET /health` route that publishes it is mounted by the reflection-based
/// endpoints pipeline, so showing it here would mean initializing generated
/// reflection and building a router — machinery that would bury the one thing
/// this example is about. See `doc/healthcheck.md` for how the route is
/// declared and wired.
///
/// Run with `dart run example/healthcheck/healthcheck_example.dart`. Every step
/// checks its own result and the run fails when one does not hold, so a green
/// run is a verification and not just a transcript.
///
/// The behaviour shown here is pinned by `test/healthcheck_test.dart`; the
/// mounted route is pinned by `test/endpoints_pipeline_test.dart`, in the group
/// named `healthcheck GET /health route`.
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// A custom analyzer that reports an unhealthy verdict from injected flags.
class _DemoAnalyzer extends TomHealthAnalyzer {
  final bool dbOk;
  final bool cacheOk;
  _DemoAnalyzer({required this.dbOk, required this.cacheOk});

  @override
  Future<TomHealthStatus> analyzeHealth(TomHealthCheck check) async =>
      dbOk && cacheOk
      ? const TomHealthStatus.healthy()
      : TomHealthStatus.unhealthy('db=$dbOk, cache=$cacheOk');
}

/// An analyzer whose future never completes — the dependency that has dropped
/// off the network rather than refusing a connection.
class _HangingAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth(TomHealthCheck check) =>
      Completer<TomHealthStatus>().future;
}

/// An analyzer that throws — the datasource that is down rather than slow,
/// which is the likelier way a real analyzer fails.
class _BrokenAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth(TomHealthCheck check) async =>
      throw StateError('the pool is closed');
}

/// An analyzer answering a fixed [status] — one service's own readiness.
class _FixedAnalyzer extends TomHealthAnalyzer {
  final TomHealthStatus status;
  _FixedAnalyzer(this.status);

  @override
  Future<TomHealthStatus> analyzeHealth(TomHealthCheck check) async => status;
}

/// An analyzer that asks one slow dependency after another, and looks at its
/// check between them — so it stops once the probe has given up.
class _StepwiseAnalyzer extends TomHealthAnalyzer {
  /// How many dependencies it asked.
  int asked = 0;

  /// Completes with how the analysis ended.
  final Completer<Object> ended = Completer();

  @override
  Future<TomHealthStatus> analyzeHealth(TomHealthCheck check) async {
    try {
      for (var i = 0; i < 20; i++) {
        check.throwIfCancelled();
        asked++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      ended.complete('answered');
      return const TomHealthStatus.healthy();
    } catch (error) {
      ended.complete(error);
      rethrow;
    }
  }
}

Future<void> run() async {
  final server = TomHealthServer();

  // 1. The default analyzer always reports healthy. The verdict and the message
  //    are two facts: the verdict is what a probe acts on, the message is what a
  //    person reads.
  final defaultStatus = await TomDefaultHealthAnalyzer().analyzeHealth(
    TomHealthCheck('readiness', const Duration(seconds: 5)),
  );
  print(
    '1. default analyzer          => ${defaultStatus.verdict.name} '
    '(${defaultStatus.message})',
  );
  check(
    defaultStatus.isHealthy && defaultStatus.message == 'OK',
    'a server that has plugged in no analyzer still reports itself healthy',
  );

  // 2. `health()` turns that verdict into the response a probe reads. 200,
  //    because the status code *is* the verdict.
  final healthy = await server.health();
  print(
    '2. health() by default       => ${healthy.statusCode} '
    '${await healthy.readAsString()}',
  );
  check(
    healthy.statusCode == 200,
    'a healthy process answers the status code every probe already checks',
  );

  // 3. Swapping an analyzer changes what that route returns — and the status
  //    code with it. A load balancer's default check reads the code and nothing
  //    else, so an unhealthy verdict that answered 200 would leave a broken
  //    process receiving traffic. The dependency check goes on *readiness*, for
  //    the reason step 4 shows.
  try {
    TomHealthServer.installReadinessAnalyzer(
      _DemoAnalyzer(dbOk: true, cacheOk: false),
    );
    final unhealthy = await server.ready();
    final body = await unhealthy.readAsString();
    print('3. ready() when degraded     => ${unhealthy.statusCode} $body');
    check(
      unhealthy.statusCode == 503,
      'an unhealthy verdict reaches the status code, not only the body',
    );
    check(
      body == 'db=true, cache=false',
      'and the message still names which dependency failed',
    );

    // 4. …and `/health` is still 200. This is why there are two routes: a
    //    failing readiness probe takes the pod out of the load balancer, a
    //    failing liveness probe restarts it. A dependency being down is a
    //    reason to stop receiving traffic and not a reason to be killed — a
    //    restart would not bring the cache back, and the loop would not end.
    final live = await server.health();
    print(
      '4. health() at the same time => ${live.statusCode} '
      '${await live.readAsString()}',
    );
    check(
      live.statusCode == 200,
      'an unready process is still alive, and must not be restarted',
    );
  } finally {
    // One supported call rather than a hand-written save-restore: the example
    // is where a reader learns how to put the process back.
    TomHealthServer.resetHealthChecks();
  }

  // 5. An analyzer that never answers does not stop the probe from answering.
  //    A TCP connection to a host that has dropped off the network waits for
  //    the OS connect timeout — over two minutes on Linux — and without a
  //    deadline the probe returns nothing for that whole window, which an
  //    orchestrator reads as a dead process rather than a slow dependency.
  try {
    TomHealthServer.installHealthTimeout(const Duration(milliseconds: 200));
    TomHealthServer.installLivenessAnalyzer(_HangingAnalyzer());
    final timedOut = await server.health();
    final body = await timedOut.readAsString();
    print('5. health() that hangs       => ${timedOut.statusCode} $body');
    check(
      timedOut.statusCode == 503,
      'a probe that cannot determine its health still answers, and says so',
    );
    check(
      body.startsWith('TIMEOUT:'),
      'and the message names the deadline rather than a dependency',
    );
  } finally {
    TomHealthServer.resetHealthChecks();
  }

  // 6. And an analyzer that throws answers too — the likelier failure of the
  //    two, since a datasource that is down throws rather than hangs. Left
  //    uncaught it would reach the endpoints pipeline's error envelope: a 500
  //    carrying JSON, where the probe was configured to read plain text, and on
  //    liveness a 500 is a restart.
  try {
    TomHealthServer.installReadinessAnalyzer(_BrokenAnalyzer());
    final broken = await server.ready();
    final body = await broken.readAsString();
    print('6. ready() that throws       => ${broken.statusCode} $body');
    check(
      broken.statusCode == 503,
      'a broken dependency is an unhealthy verdict, not a failed request',
    );
    check(
      body.startsWith('FAILED:') && body.contains('the pool is closed'),
      'and the exception reaches the operator on the wire',
    );
  } finally {
    TomHealthServer.resetHealthChecks();
  }

  // 7. Two services in one process, each with its own readiness analyzer: an
  //    instance carries its own analyzers, and what it leaves out — liveness
  //    here — is the process-wide setting. The mounted routes keep answering
  //    with the process-wide analyzers; an application calls these instances
  //    from routes of its own.
  final orders = TomHealthServer(
    readiness: _FixedAnalyzer(const TomHealthStatus.healthy('orders: ok')),
  );
  final billing = TomHealthServer(
    readiness: _FixedAnalyzer(
      const TomHealthStatus.unhealthy('billing: ledger unreachable'),
    ),
  );
  final ordersReady = await orders.ready();
  final billingReady = await billing.ready();
  final billingLive = await billing.health();
  print(
    '7. two services              => orders ${ordersReady.statusCode} '
    '${await ordersReady.readAsString()}, billing ${billingReady.statusCode} '
    '${await billingReady.readAsString()}',
  );
  check(
    ordersReady.statusCode == 200 && billingReady.statusCode == 503,
    'each instance answers readiness with its own analyzer',
  );
  check(
    billingLive.statusCode == 200 &&
        identical(billing.liveness, TomHealthServer.livenessAnalyzer),
    'and what it leaves out is the process-wide analyzer',
  );

  // 8. An instance deadline cancels the analysis it gave up on. The probe
  //    answers TIMEOUT at 120 ms; the analyzer looks at its check between its
  //    dependencies and stops there, rather than asking the remaining ones for
  //    an answer nobody waits for.
  final stepwise = _StepwiseAnalyzer();
  final hurried = TomHealthServer(
    readiness: stepwise,
    timeout: const Duration(milliseconds: 120),
  );
  final timedOut = await hurried.ready();
  final timedOutBody = await timedOut.readAsString();
  final ended = await stepwise.ended.future.timeout(const Duration(seconds: 2));
  print(
    '8. cancelled at the deadline => ${timedOut.statusCode} $timedOutBody; '
    'stopped after ${stepwise.asked} of 20',
  );
  check(
    timedOut.statusCode == 503 && timedOutBody.startsWith('TIMEOUT:'),
    'the probe answers at the instance deadline',
  );
  check(
    ended is TomHealthCheckCancelled && stepwise.asked < 20,
    'and the analyzer stops at its next step instead of finishing',
  );

  print('\nHealth-check example completed.');
}

Future<void> main() async {
  await run();
}

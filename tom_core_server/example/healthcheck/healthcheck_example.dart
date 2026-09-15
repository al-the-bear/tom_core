/// Executable example for the health-check module of `tom_core_server`.
///
/// This example shows the surface you can drive directly: the two pluggable
/// [TomHealthAnalyzer]s, the way each turns its verdict into the status code a
/// probe reads and its message into the body, and why there are two of them —
/// an unready process is still alive.
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

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// A custom analyzer that reports an unhealthy verdict from injected flags.
class _DemoAnalyzer extends TomHealthAnalyzer {
  final bool dbOk;
  final bool cacheOk;
  _DemoAnalyzer({required this.dbOk, required this.cacheOk});

  @override
  Future<TomHealthStatus> analyzeHealth() async => dbOk && cacheOk
      ? const TomHealthStatus.healthy()
      : TomHealthStatus.unhealthy('db=$dbOk, cache=$cacheOk');
}

Future<void> run() async {
  final server = TomHealthServer();

  // 1. The default analyzer always reports healthy. The verdict and the message
  //    are two facts: the verdict is what a probe acts on, the message is what a
  //    person reads.
  final defaultStatus = await TomDefaultHealthAnalyzer().analyzeHealth();
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
    TomHealthServer.resetHealthAnalyzers();
  }

  print('\nHealth-check example completed.');
}

Future<void> main() async {
  await run();
}

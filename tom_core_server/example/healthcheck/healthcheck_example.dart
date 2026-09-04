/// Executable example for the health-check module of `tom_core_server`.
///
/// This example shows the surface you can drive directly: the pluggable
/// [TomHealthAnalyzer] and the way [TomHealthServer.health] delegates to it.
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

/// A custom analyzer that reports a degraded status from injected flags.
class _DemoAnalyzer extends TomHealthAnalyzer {
  final bool dbOk;
  final bool cacheOk;
  _DemoAnalyzer({required this.dbOk, required this.cacheOk});

  @override
  Future<String> analyzeHealth() async =>
      (dbOk && cacheOk) ? 'OK' : 'DEGRADED: db=$dbOk, cache=$cacheOk';
}

Future<void> run() async {
  final server = TomHealthServer();

  // 1. The default analyzer always reports OK.
  final defaultStatus = await TomDefaultHealthAnalyzer().analyzeHealth();
  print('1. default analyzer => $defaultStatus');
  check(
    defaultStatus == 'OK',
    'a server that has plugged in no analyzer still reports itself healthy',
  );

  // 2. TomHealthServer.health() delegates to the global analyzer (OK default).
  final healthDefault = await server.health();
  print('2. health() with default analyzer => $healthDefault');
  check(
    healthDefault == 'OK',
    'health() reports whatever the global analyzer says, not its own verdict',
  );

  // 3. Swapping the global analyzer changes what every request returns.
  final previous = TomHealthServer.healthAnalyzer;
  try {
    TomHealthServer.healthAnalyzer = _DemoAnalyzer(dbOk: true, cacheOk: false);
    final degraded = await server.health();
    print('3. health() with degraded analyzer => $degraded');
    check(
      degraded == 'DEGRADED: db=true, cache=false',
      'one failing dependency degrades the report and names which one',
    );
  } finally {
    TomHealthServer.healthAnalyzer = previous;
  }

  print('\nHealth-check example completed.');
}

Future<void> main() async {
  await run();
}

/// Executable example for the health-check module of `tom_core_server`.
///
/// The `GET /health` route itself is mounted by the reflection-based endpoints
/// pipeline and needs a running server (see `doc/healthcheck.md`); this example
/// shows the server-free surface: the pluggable [HealthAnalyzer] and the way
/// [TomHealthServer.health] delegates to it.
///
/// Run with `dart run example/healthcheck/healthcheck_example.dart`.
/// The same behaviour is covered by `test/healthcheck_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// A custom analyzer that reports a degraded status from injected flags.
class _DemoAnalyzer extends HealthAnalyzer {
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
  final defaultStatus = await DefaultHealthAnalyzer().analyzeHealth();
  print('1. default analyzer => $defaultStatus');
  assert(defaultStatus == 'OK');

  // 2. TomHealthServer.health() delegates to the global analyzer (OK default).
  final healthDefault = await server.health();
  print('2. health() with default analyzer => $healthDefault');
  assert(healthDefault == 'OK');

  // 3. Swapping the global analyzer changes what every request returns.
  final previous = TomHealthServer.globalSettingsHealthAnalyzer;
  try {
    TomHealthServer.globalSettingsHealthAnalyzer =
        _DemoAnalyzer(dbOk: true, cacheOk: false);
    final degraded = await server.health();
    print('3. health() with degraded analyzer => $degraded');
    assert(degraded == 'DEGRADED: db=true, cache=false');
  } finally {
    TomHealthServer.globalSettingsHealthAnalyzer = previous;
  }

  print('\nHealth-check example completed.');
}

Future<void> main() async {
  await run();
}

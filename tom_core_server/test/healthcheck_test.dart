import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the server-free surface of the health-check module.
///
/// The `GET /health` route is mounted by the reflection-based endpoints
/// pipeline and is covered by `doc/healthcheck.md` and integration tests, not
/// here. This suite pins the pluggable [HealthAnalyzer] contract and the way
/// [TomHealthServer.health] delegates to the global analyzer.
class _FixedAnalyzer extends HealthAnalyzer {
  final String status;
  _FixedAnalyzer(this.status);

  @override
  Future<String> analyzeHealth() async => status;
}

void main() {
  // Restore the global analyzer after each test so swaps do not leak.
  final original = TomHealthServer.globalSettingsHealthAnalyzer;
  tearDown(() {
    TomHealthServer.globalSettingsHealthAnalyzer = original;
  });

  group('DefaultHealthAnalyzer', () {
    test('always returns OK', () async {
      expect(await DefaultHealthAnalyzer().analyzeHealth(), 'OK');
    });
  });

  group('TomHealthServer', () {
    test('defaults to the always-OK analyzer', () {
      expect(
        TomHealthServer.globalSettingsHealthAnalyzer,
        isA<DefaultHealthAnalyzer>(),
      );
    });

    test('health() returns OK with the default analyzer', () async {
      expect(await TomHealthServer().health(), 'OK');
    });

    test('health() delegates to the swapped global analyzer', () async {
      TomHealthServer.globalSettingsHealthAnalyzer = _FixedAnalyzer(
        'DEGRADED: db=false',
      );
      expect(await TomHealthServer().health(), 'DEGRADED: db=false');
    });

    test('the analyzer is shared across instances (static field)', () async {
      TomHealthServer.globalSettingsHealthAnalyzer = _FixedAnalyzer('CUSTOM');
      expect(await TomHealthServer().health(), 'CUSTOM');
      expect(await TomHealthServer().health(), 'CUSTOM');
    });
  });
}

/// Tests for the server-free surface of the health-check module: the pluggable
/// [TomHealthAnalyzer] contract and the way [TomHealthServer.health] delegates
/// to the global analyzer.
///
/// The mounted `GET /health` route is asserted in
/// `test/endpoints_pipeline_test.dart`, by the group named
/// `healthcheck GET /health route` — that it answers 200 unauthenticated as
/// `text/plain`, that it keeps doing so on a server that protects by default,
/// that a probe of it writes no request log line, and that its body follows
/// whichever [TomHealthAnalyzer] is installed. Route assertions belong there
/// rather than here because the route only exists once generated reflection has
/// been initialized and a router built over it, which is that suite's setup and
/// not this one's.
///
/// Named by group rather than by line number on purpose: this pointer has to
/// survive the file it points into being edited.
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

class _FixedAnalyzer extends TomHealthAnalyzer {
  final String status;
  _FixedAnalyzer(this.status);

  @override
  Future<String> analyzeHealth() async => status;
}

void main() {
  // Restore the global analyzer after each test so swaps do not leak.
  final original = TomHealthServer.healthAnalyzer;
  tearDown(() {
    TomHealthServer.healthAnalyzer = original;
  });

  group('TomDefaultHealthAnalyzer', () {
    test('always returns OK', () async {
      expect(await TomDefaultHealthAnalyzer().analyzeHealth(), 'OK');
    });
  });

  group('TomHealthServer', () {
    test('defaults to the always-OK analyzer', () {
      expect(TomHealthServer.healthAnalyzer, isA<TomDefaultHealthAnalyzer>());
    });

    test('health() returns OK with the default analyzer', () async {
      expect(await TomHealthServer().health(), 'OK');
    });

    test('health() delegates to the swapped global analyzer', () async {
      TomHealthServer.healthAnalyzer = _FixedAnalyzer('DEGRADED: db=false');
      expect(await TomHealthServer().health(), 'DEGRADED: db=false');
    });

    test('the analyzer is shared across instances (static field)', () async {
      TomHealthServer.healthAnalyzer = _FixedAnalyzer('CUSTOM');
      expect(await TomHealthServer().health(), 'CUSTOM');
      expect(await TomHealthServer().health(), 'CUSTOM');
    });
  });
}

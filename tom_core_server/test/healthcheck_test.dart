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

import 'dart:io';

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

  // The four facts of the route, read from the source that declares them.
  //
  // The pointer at the top of this file is accurate — `endpoints_pipeline_test`
  // does exercise the mounted route — but it exercises it through *generated
  // reflection*, and the generated file is checked in. So the annotation values
  // those tests observe come from `test/fixtures/reflection_fixture.reflection
  // .dart`, not from the declaration below them: changing `uri` here, or
  // `logRequests`, or the access annotation, leaves every one of those tests
  // green until somebody regenerates. Found by mutation — all four survived a
  // run of both suites.
  //
  // `reflection_currency_test.dart` is the guard for that gap in general and
  // says plainly what it cannot do: it matches *names*, not annotation values,
  // and the exact check is a two-to-four-minute regeneration. So the values are
  // pinned here, against the text of the declaration, which costs milliseconds
  // and fails on the edit rather than on the next regeneration.
  group('the declared route', () {
    final source = File(
      'lib/src/tomserver/healthcheck/health_check.dart',
    ).readAsStringSync();

    /// The `@TomEndpoint(...)` argument list, with the dartdoc left outside.
    ///
    /// Read from the declaration rather than from the whole file because the
    /// dartdoc above it quotes the same settings in prose — `logRequests:
    /// false` appears in both — so a check against the file text passes on a
    /// mutated annotation, which is how the first version of this test was
    /// found wanting.
    final opened = source.indexOf('@TomEndpoint(');
    final annotation = source.substring(
      opened,
      source.indexOf(');', opened) + 1,
    );

    test('is mounted at /health', () {
      // The path a container orchestrator is configured with. Renaming it is a
      // deployment break that no compiler and no mirror-driven test reports.
      expect(annotation, contains('uri: "/health"'));
    });

    test('is public, so an unauthenticated probe reaches it', () {
      // A probe carries no credential. Losing this annotation on a server that
      // protects by default turns every health check into a 401, and the
      // orchestrator reads that as the process being unhealthy.
      expect(
        source,
        contains(RegExp(r'@TomPublicAccess\(\)\s*\n\s*@TomEndpoint\(')),
      );
    });

    test('answers plain text', () {
      // The body is the analyzer's string verbatim. Declaring JSON would make
      // a probe reading the body parse `OK` as a document and fail.
      expect(annotation, contains('produces: TomMimeType.plainText'));
    });

    test('keeps probe traffic out of the request log', () {
      // A probe arrives every few seconds. This is the flag the endpoint
      // pipeline copies onto the request's log info, and the only reason a
      // health check does not drown the access log.
      expect(annotation, contains('logRequests: false'));
    });
  });
}

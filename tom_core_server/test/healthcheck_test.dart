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

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

class _FixedAnalyzer extends TomHealthAnalyzer {
  final TomHealthStatus status;
  _FixedAnalyzer(this.status);

  @override
  Future<TomHealthStatus> analyzeHealth() async => status;
}

/// The body of [response], read back.
Future<String> _bodyOf(Response response) => response.readAsString();

void main() {
  // Restore both global analyzers after each test so swaps do not leak.
  final liveness = TomHealthServer.livenessAnalyzer;
  final readiness = TomHealthServer.readinessAnalyzer;
  tearDown(() {
    TomHealthServer.livenessAnalyzer = liveness;
    TomHealthServer.readinessAnalyzer = readiness;
  });

  group('the verdict and the message are two facts', () {
    test('a verdict carries the status code a probe acts on', () {
      // The whole point of separating them. A probe reads the code; a person
      // reads the message. Encoding both into one string is what forced every
      // consumer to parse, and made a typo in an analyzer a wrong verdict.
      expect(TomHealthVerdict.healthy.statusCode, 200);
      expect(TomHealthVerdict.unhealthy.statusCode, 503);
    });

    test('there are two verdicts, because HTTP offers two answers', () {
      // Pinned by name. A third verdict would either map to one of these two —
      // a distinction no probe can act on — or invent a status code no
      // orchestrator reads. The gradation lives in the message.
      expect(TomHealthVerdict.values, [
        TomHealthVerdict.healthy,
        TomHealthVerdict.unhealthy,
      ]);
    });

    test('healthy defaults its message, unhealthy requires one', () {
      // `OK` is what a human reading a probe log expects and what keeps a
      // `curl` from looking broken; an unhealthy answer that does not say why
      // is the one somebody is reading at three in the morning, so the
      // constructor takes it.
      const healthy = TomHealthStatus.healthy();
      expect(healthy.message, 'OK');
      expect(healthy.isHealthy, isTrue);
      expect(healthy.statusCode, 200);

      const unhealthy = TomHealthStatus.unhealthy('db=false');
      expect(unhealthy.message, 'db=false');
      expect(unhealthy.isHealthy, isFalse);
      expect(unhealthy.statusCode, 503);
    });
  });

  group('TomDefaultHealthAnalyzer', () {
    test('always reports healthy', () async {
      final status = await TomDefaultHealthAnalyzer().analyzeHealth();
      expect(status.verdict, TomHealthVerdict.healthy);
      expect(status.message, 'OK');
    });
  });

  group('TomHealthServer', () {
    test('defaults to the always-healthy analyzer', () {
      expect(TomHealthServer.livenessAnalyzer, isA<TomDefaultHealthAnalyzer>());
    });

    test('health() answers 200 and OK with the default analyzer', () async {
      final response = await TomHealthServer().health();
      expect(response.statusCode, 200);
      expect(await _bodyOf(response), 'OK');
    });

    test('an unhealthy analyzer answers 503, with its message', () async {
      // The defect this closes: a load balancer's default check reads the
      // status code and nothing else, so a deployment watching its analyzer
      // correctly report a dead database still received traffic.
      TomHealthServer.livenessAnalyzer = _FixedAnalyzer(
        const TomHealthStatus.unhealthy('DEGRADED: db=false'),
      );
      final response = await TomHealthServer().health();
      expect(response.statusCode, 503);
      expect(await _bodyOf(response), 'DEGRADED: db=false');
    });

    test(
      'the body is plain text, since a Response bypasses produces',
      () async {
        // A handler returning a `Response` is passed through untouched, so the
        // endpoint's `produces` never reaches it. Without this the probe log
        // fills with `application/octet-stream`.
        final response = await TomHealthServer().health();
        expect(
          response.headers[TomHeader.contentType.toLowerCase()],
          startsWith('text/plain'),
        );
      },
    );

    test('ready() answers 200 and OK with the default analyzer', () async {
      // The default is always-ready, and that is a choice rather than an
      // oversight: "not ready until told" would leave a deployment that never
      // configures readiness with an empty load balancer, a healthy process and
      // a passing liveness probe — a failure with no visible cause.
      final response = await TomHealthServer().ready();
      expect(response.statusCode, 200);
      expect(await _bodyOf(response), 'OK');
    });

    test('the two analyzers are independent', () async {
      // The whole point of two routes. A dependency being down is a reason to
      // stop receiving traffic and not a reason for the process to be
      // restarted, so the readiness verdict must not reach the liveness route.
      TomHealthServer.readinessAnalyzer = _FixedAnalyzer(
        const TomHealthStatus.unhealthy('db=false'),
      );

      final ready = await TomHealthServer().ready();
      expect(ready.statusCode, 503);
      expect(await _bodyOf(ready), 'db=false');

      final live = await TomHealthServer().health();
      expect(
        live.statusCode,
        200,
        reason: 'an unready process is still alive, and must not be restarted',
      );
      expect(await _bodyOf(live), 'OK');
    });

    test('and the independence holds the other way too', () async {
      // The control. Without it the assertion above is satisfied by a server
      // whose readiness analyzer is simply ignored on the other route by
      // accident rather than by design.
      TomHealthServer.livenessAnalyzer = _FixedAnalyzer(
        const TomHealthStatus.unhealthy('the isolate is gone'),
      );

      expect((await TomHealthServer().health()).statusCode, 503);
      expect((await TomHealthServer().ready()).statusCode, 200);
    });

    test('they default to two instances, not one shared object', () {
      // Assigning one must not change the other, which a shared default would
      // not guarantee the moment somebody mutated an analyzer in place.
      expect(
        TomHealthServer.livenessAnalyzer,
        isNot(same(TomHealthServer.readinessAnalyzer)),
      );
    });

    test('the analyzer is shared across instances (static field)', () async {
      TomHealthServer.livenessAnalyzer = _FixedAnalyzer(
        const TomHealthStatus.unhealthy('CUSTOM'),
      );
      expect((await TomHealthServer().health()).statusCode, 503);
      expect(await _bodyOf(await TomHealthServer().health()), 'CUSTOM');
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
    /// The liveness endpoint's annotation — the first in the file.
    final opened = source.indexOf('@TomEndpoint(');
    final annotation = source.substring(
      opened,
      source.indexOf(');', opened) + 1,
    );

    /// The readiness endpoint's, which is the next one.
    final opened2 = source.indexOf('@TomEndpoint(', opened + 1);
    final readiness = source.substring(
      opened2,
      source.indexOf(');', opened2) + 1,
    );

    test('is mounted at /health, with /ready beside it', () {
      // The paths a container orchestrator is configured with. Renaming either
      // is a deployment break that no compiler and no mirror-driven test
      // reports.
      expect(annotation, contains('uri: "/health"'));
      expect(readiness, contains('uri: "/ready"'));
    });

    test('readiness is public and unlogged too', () {
      // Both facts matter for the same reasons they do on liveness: a probe
      // carries no credential, and it arrives every few seconds. A readiness
      // route that authenticated would report every pod as unready.
      expect(readiness, contains('logRequests: false'));
      expect(readiness, contains('produces: TomMimeType.plainText'));
      expect(
        source,
        contains(
          RegExp(r'@TomPublicAccess\(\)\s*\n\s*@TomEndpoint\([^)]*/ready'),
        ),
      );
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

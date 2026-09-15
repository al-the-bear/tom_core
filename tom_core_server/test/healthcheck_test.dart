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

import 'dart:async';
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

/// An analyzer whose future never completes — the dependency that has dropped
/// off the network rather than refused a connection.
class _HangingAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth() =>
      Completer<TomHealthStatus>().future;
}

/// An analyzer that throws instead of answering, from inside an async body —
/// the future completes with an error.
class _ThrowingAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth() async =>
      throw StateError('the pool is closed');
}

/// An analyzer that raises before it returns a future at all.
///
/// A distinct path: a synchronous throw never reaches [Future.timeout], so it
/// is caught only because the call itself is inside the guarded block.
class _SynchronouslyThrowingAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth() =>
      throw StateError('no datasource is registered');
}

/// An analyzer whose future fails *after* the deadline has already fired.
///
/// The failure nobody sees coming: the probe has answered TIMEOUT and stopped
/// waiting, and the original future then completes with an error that no longer
/// has a caller.
class _LateFailingAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth() => Future.delayed(
    const Duration(milliseconds: 300),
    () => throw StateError('the connection attempt gave up'),
  );
}

/// Collects the info-level lines the installer writes.
class _InfoLog extends TomLogOutput {
  final List<String> lines = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    final text = convertToString(message);
    if (text.contains('TomHealthServer:')) {
      lines.add(text);
    }
  }
}

/// The body of [response], read back.
Future<String> _bodyOf(Response response) => response.readAsString();

void main() {
  // Put the process back the way a fresh one starts, so installations do not
  // leak between tests — analyzers and deadline alike. One supported call,
  // rather than a hand-written save-restore per global.
  tearDown(TomHealthServer.resetHealthChecks);

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
      TomHealthServer.installLivenessAnalyzer(
        _FixedAnalyzer(const TomHealthStatus.unhealthy('DEGRADED: db=false')),
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
      TomHealthServer.installReadinessAnalyzer(
        _FixedAnalyzer(const TomHealthStatus.unhealthy('db=false')),
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
      TomHealthServer.installLivenessAnalyzer(
        _FixedAnalyzer(const TomHealthStatus.unhealthy('the isolate is gone')),
      );

      expect((await TomHealthServer().health()).statusCode, 503);
      expect((await TomHealthServer().ready()).statusCode, 200);
    });

    test('they default to two instances, not one shared object', () {
      // Installing on one must not change the other, which a shared default
      // would not guarantee the moment somebody mutated an analyzer in place.
      expect(
        TomHealthServer.livenessAnalyzer,
        isNot(same(TomHealthServer.readinessAnalyzer)),
      );
    });

    test('the analyzer is shared across instances (static state)', () async {
      TomHealthServer.installLivenessAnalyzer(
        _FixedAnalyzer(const TomHealthStatus.unhealthy('CUSTOM')),
      );
      expect((await TomHealthServer().health()).statusCode, 503);
      expect(await _bodyOf(await TomHealthServer().health()), 'CUSTOM');
    });
  });

  group('installing an analyzer is a boundary, not an assignment', () {
    test('the analyzers are read-only from outside the class', () {
      // The point of the boundary. A public assignable static can be replaced
      // by anything in the process at any moment, including after the server is
      // serving, and the replacement leaves no trace. Read from the source that
      // declares it, because `analyze` alone would not catch a getter growing a
      // setter beside it.
      final source = File(
        'lib/src/tomserver/healthcheck/health_check.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('static TomHealthAnalyzer get livenessAnalyzer'),
        reason: 'the liveness analyzer is exposed by a getter',
      );
      expect(
        source,
        contains('static TomHealthAnalyzer get readinessAnalyzer'),
        reason: 'the readiness analyzer is exposed by a getter',
      );
      expect(
        source,
        isNot(contains('set livenessAnalyzer')),
        reason: 'a setter would put the unguarded assignment straight back',
      );
      expect(
        source,
        isNot(contains('set readinessAnalyzer')),
        reason: 'a setter would put the unguarded assignment straight back',
      );
    });

    test('installing announces the replacement, naming both types', () async {
      // The trace an assignment did not leave. A deployment answering probes
      // with the wrong analyzer can now read which one is installed and when it
      // arrived, instead of inferring it from the body.
      final log = _InfoLog();
      final previousOutput = tomLog.logOutput;
      final previousLevel = tomLog.logLevel;
      addTearDown(() {
        tomLog.logOutput = previousOutput;
        tomLog.setLogLevel(previousLevel);
      });
      tomLog.logOutput = log;
      tomLog.setLogLevel(TomLogLevel.all);

      TomHealthServer.installReadinessAnalyzer(
        _FixedAnalyzer(const TomHealthStatus.unhealthy('db=false')),
      );

      expect(log.lines, hasLength(1));
      expect(log.lines.single, contains('readiness'));
      expect(
        log.lines.single,
        contains('_FixedAnalyzer'),
        reason: 'the incoming analyzer is what the reader is looking for',
      );
      expect(
        log.lines.single,
        contains('TomDefaultHealthAnalyzer'),
        reason: 'naming the outgoing one is how a double install reads',
      );
    });

    test('a reset is an installation, and says so', () async {
      // A reset that went unrecorded would be the one replacement the log could
      // not account for — and it is the one every test and example performs.
      TomHealthServer.installLivenessAnalyzer(
        _FixedAnalyzer(const TomHealthStatus.unhealthy('gone')),
      );
      TomHealthServer.installHealthTimeout(const Duration(seconds: 1));

      final log = _InfoLog();
      final previousOutput = tomLog.logOutput;
      final previousLevel = tomLog.logLevel;
      addTearDown(() {
        tomLog.logOutput = previousOutput;
        tomLog.setLogLevel(previousLevel);
      });
      tomLog.logOutput = log;
      tomLog.setLogLevel(TomLogLevel.all);

      TomHealthServer.resetHealthChecks();

      expect(log.lines, hasLength(3));
      expect(log.lines[0], contains('liveness'));
      expect(log.lines[1], contains('readiness'));
      expect(log.lines[2], contains('deadline'));
      expect((await TomHealthServer().health()).statusCode, 200);
      expect(
        TomHealthServer.healthTimeout,
        TomHealthServer.defaultHealthTimeout,
        reason:
            'a reset restores every process-wide knob, not just the two '
            'that share a name with the call',
      );
    });

    test('a reset restores two analyzer instances, not one shared object', () {
      // The invariant a fresh process starts with. Handing both probes the same
      // default would make an analyzer mutated in place answer both routes.
      TomHealthServer.resetHealthChecks();
      expect(
        TomHealthServer.livenessAnalyzer,
        isA<TomDefaultHealthAnalyzer>().having(
          (a) => identical(a, TomHealthServer.readinessAnalyzer),
          'shares the readiness instance',
          isFalse,
        ),
      );
    });
  });

  group('a probe answers even when its analyzer does not', () {
    test('a hanging analyzer becomes an unhealthy verdict, not a hang', () {
      // The defect this closes. `analyzeHealth` is async precisely so a
      // SELECT 1 and a cache PING can be awaited, and a TCP connection to a
      // host that has dropped off the network waits for the OS connect timeout
      // — over two minutes on Linux. Awaited without a deadline the probe
      // returns nothing at all for that window, so an orchestrator sees a probe
      // *timeout* rather than a degraded body and restarts a process whose only
      // problem was a slow dependency.
      //
      // Asserted with a fake clock rather than a real wait: `fakeAsync` would
      // be the other way, but the deadline is short enough to spend for real
      // and a 200 ms wall clock keeps the test readable.
      TomHealthServer.installHealthTimeout(const Duration(milliseconds: 200));
      TomHealthServer.installLivenessAnalyzer(_HangingAnalyzer());

      return expectLater(
        TomHealthServer().health().then((r) async {
          expect(r.statusCode, 503);
          final body = await _bodyOf(r);
          expect(body, startsWith('TIMEOUT:'));
          expect(
            body,
            contains('liveness'),
            reason: 'the message names which check did not answer',
          );
          return body;
        }),
        completes,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('the deadline did not fire: the probe hung'),
      );
    });

    test('and the other probe is unaffected while it hangs', () async {
      // The deadline is per call, not a process-wide latch: a hanging liveness
      // analyzer must not make readiness wait for it too.
      TomHealthServer.installHealthTimeout(const Duration(milliseconds: 200));
      TomHealthServer.installLivenessAnalyzer(_HangingAnalyzer());

      final ready = await TomHealthServer().ready();
      expect(ready.statusCode, 200);
      expect(await _bodyOf(ready), 'OK');
    });

    test('a throwing analyzer becomes an unhealthy verdict too', () async {
      // Letting it out turns the probe into the pipeline's 500, which on
      // liveness is also a restart, and loses the message. The exception text
      // reaches the body, so nothing is swallowed — it is answered.
      TomHealthServer.installReadinessAnalyzer(_ThrowingAnalyzer());

      final response = await TomHealthServer().ready();
      expect(response.statusCode, 503);
      final body = await _bodyOf(response);
      expect(body, startsWith('FAILED:'));
      expect(body, contains('readiness'));
      expect(
        body,
        contains('the pool is closed'),
        reason: 'the cause belongs on the wire, not only in a log',
      );
    });

    test('a synchronous throw is caught as well', () async {
      // The other half of "throws": an analyzeHealth that is not async and
      // raises before returning a future never reaches Future.timeout, so it is
      // caught only because the call itself sits inside the guarded block.
      TomHealthServer.installLivenessAnalyzer(_SynchronouslyThrowingAnalyzer());

      final response = await TomHealthServer().health();
      expect(response.statusCode, 503);
      expect(await _bodyOf(response), contains('no datasource is registered'));
    });

    test('a failure arriving after the deadline stays quiet', () async {
      // `Future.timeout` stops the waiting, not the work, so the analyzer's
      // future outlives the answer and then fails. Nothing is listening by
      // then — and an unhandled asynchronous error is not a quiet event, it is
      // reported to the zone and can take the isolate down. Asserted by letting
      // the late failure land inside this test.
      TomHealthServer.installHealthTimeout(const Duration(milliseconds: 100));
      TomHealthServer.installLivenessAnalyzer(_LateFailingAnalyzer());

      final response = await TomHealthServer().health();
      expect(await _bodyOf(response), startsWith('TIMEOUT:'));

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(
        (await TomHealthServer().ready()).statusCode,
        200,
        reason: 'the isolate is still serving after the late failure landed',
      );
    });

    test('an analyzer that answers in time is not touched', () async {
      // The control. Without it the two assertions above are satisfied by a
      // deadline that fires on every request.
      TomHealthServer.installLivenessAnalyzer(
        _FixedAnalyzer(const TomHealthStatus.unhealthy('db=false')),
      );
      final response = await TomHealthServer().health();
      expect(response.statusCode, 503);
      expect(await _bodyOf(response), 'db=false');
    });

    test('the deadline defaults to five seconds', () {
      // Pinned by value because it is a promise to a deployment: long enough
      // that a real dependency check answers well inside it, short enough to
      // beat the OS connect timeout it exists for.
      expect(TomHealthServer.defaultHealthTimeout, const Duration(seconds: 5));
      expect(TomHealthServer.healthTimeout, const Duration(seconds: 5));
    });

    test('a non-positive deadline is refused at the boundary', () {
      // A zero deadline would make every probe answer TIMEOUT before its
      // analyzer ran — wrong in the direction that looks safe, since 503 on
      // liveness is a restart.
      expect(
        () => TomHealthServer.installHealthTimeout(Duration.zero),
        throwsArgumentError,
      );
      expect(
        () => TomHealthServer.installHealthTimeout(const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(
        TomHealthServer.healthTimeout,
        TomHealthServer.defaultHealthTimeout,
        reason: 'a refused installation leaves the deadline where it was',
      );
    });

    test('verdictOf is the seam a third probe route reuses', () async {
      // Public so a deployment adding its own probe path gets the deadline and
      // the failure handling rather than a second, thinner spelling of them.
      TomHealthServer.installHealthTimeout(const Duration(milliseconds: 200));

      final verdict = await TomHealthServer.verdictOf(
        _HangingAnalyzer(),
        'startup',
      );
      expect(verdict.isHealthy, isFalse);
      expect(verdict.message, contains('startup'));
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

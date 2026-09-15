import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';

/// Whether a deployment should be sent traffic.
///
/// Two values, and deliberately not three. HTTP offers a probe exactly two
/// answers — send me traffic, or do not — so a third verdict would either map
/// to one of those two, making a distinction no probe can act on, or invent a
/// status code no orchestrator reads. The gradation belongs in
/// [TomHealthStatus.message], which is free-form and is where "degraded:
/// cache=false, db=true" says what a number cannot.
enum TomHealthVerdict {
  /// Everything the analyzer checked answered. HTTP 200.
  healthy(200),

  /// Something the analyzer checked did not. HTTP 503, which is what takes a
  /// pod out of a load balancer and what a default probe already understands.
  unhealthy(503);

  const TomHealthVerdict(this.statusCode);

  /// The HTTP status a response carrying this verdict is answered with.
  final int statusCode;
}

/// What an analyzer concluded: a verdict a probe can act on, and a message a
/// human can read.
///
/// The two are separate because they are different facts. Encoding both into
/// one string — `"OK"` meaning healthy and anything else meaning not — is what
/// forces every consumer to parse, makes a typo in an analyzer a wrong verdict,
/// and leaves an orchestrator no way to act without a body matcher.
class TomHealthStatus {
  /// A healthy verdict, with an optional [message].
  ///
  /// The default message is `OK` because that is what a human reading a probe
  /// log expects to see, and because an empty body makes a `curl` look broken.
  const TomHealthStatus.healthy([this.message = 'OK'])
    : verdict = TomHealthVerdict.healthy;

  /// An unhealthy verdict, with a [message] saying what failed.
  ///
  /// The message is required here and optional above: an unhealthy answer that
  /// does not say why is the one a person is reading at three in the morning.
  const TomHealthStatus.unhealthy(this.message)
    : verdict = TomHealthVerdict.unhealthy;

  /// The verdict, which decides the HTTP status.
  final TomHealthVerdict verdict;

  /// A free-form description, served as the response body verbatim.
  final String message;

  /// Whether this is [TomHealthVerdict.healthy].
  bool get isHealthy => verdict == TomHealthVerdict.healthy;

  /// The HTTP status this status is answered with — [TomHealthVerdict
  /// .statusCode].
  int get statusCode => verdict.statusCode;

  @override
  String toString() => 'TomHealthStatus(${verdict.name}: $message)';
}

/// Analyzer for customizing health check responses.
///
/// Extend this class to implement custom health check logic such as:
/// - Database connectivity checks
/// - External service availability
/// - Memory/resource usage checks
/// - Custom application health metrics
///
/// ## Example
///
/// ```dart
/// class MyHealthAnalyzer extends TomHealthAnalyzer {
///   @override
///   Future<TomHealthStatus> analyzeHealth() async {
///     final dbOk = await checkDatabaseConnection();
///     final cacheOk = await checkCacheService();
///     if (dbOk && cacheOk) {
///       return const TomHealthStatus.healthy();
///     }
///     return TomHealthStatus.unhealthy('db=$dbOk, cache=$cacheOk');
///   }
/// }
///
/// // Install globally before the server starts. A dependency check belongs on
/// // readiness: a database being down is a reason to stop receiving traffic
/// // and not a reason for the process to be restarted.
/// TomHealthServer.installReadinessAnalyzer(MyHealthAnalyzer());
/// ```
abstract class TomHealthAnalyzer {
  /// Analyzes the health of the server.
  ///
  /// Returns the verdict a probe acts on and the message a person reads. An
  /// analyzer that touches anything remote should impose its own timeout and
  /// answer [TomHealthStatus.unhealthy] rather than hang: `/health` is the
  /// request an orchestrator uses to decide whether the process is alive, so a
  /// slow dependency that hangs it reads as a dead process.
  Future<TomHealthStatus> analyzeHealth();
}

/// Default health analyzer that always reports healthy.
class TomDefaultHealthAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth() async =>
      const TomHealthStatus.healthy();
}

/// Health check service interface for server health monitoring.
///
/// Declares the two endpoints container orchestration tools (Docker,
/// Kubernetes, Cloud Run, every load balancer) expect. Both answer the
/// installed analyzer's message verbatim — `"OK"` is the
/// [TomDefaultHealthAnalyzer]'s answer, not a constant of the endpoint — with
/// the **status code carrying the verdict**: `200` for
/// [TomHealthVerdict.healthy], `503` for [TomHealthVerdict.unhealthy].
///
/// Which is what makes an ordinary probe correct. A load balancer's default
/// check reads the status code and nothing else, as does a Kubernetes `httpGet`
/// probe unless the deployment adds a body matcher. A probe that wants the
/// *reason* still reads the body, which is where it has always been.
///
/// ## Two routes, because the two questions have opposite consequences
///
/// `GET /health` is **liveness** — am I running — and a failure restarts the
/// process. `GET /ready` is **readiness** — can I serve traffic — and a failure
/// takes it out of the load balancer and leaves it alone. One route cannot
/// answer both: "the container started but its database is unreachable" is
/// ready-false with live-true, and a single verdict forces a deployment to pick
/// which consequence it wants. Answering unhealthy there restarts a pod that
/// would have recovered, in a loop, because restarting does not bring the
/// database back; answering healthy sends it traffic it cannot serve.
///
/// So the split is by *what the check touches*: a liveness analyzer looks at
/// the process — is the event loop turning, is a critical isolate still there —
/// and a readiness analyzer looks at what the process needs — the pool, the
/// cache, the downstream API. A dependency being down is a reason to stop
/// receiving traffic and not a reason to be killed.
///
/// A route per question rather than one route with a `?probe=` parameter: query
/// parameters on a health check are awkward to configure in several
/// orchestrators, and a single route stays a single point of failure for both
/// answers.
@tomReflector
@tomService
abstract class TomHealthService {
  /// The `GET /health` endpoint — **liveness**: a plain-text status string,
  /// with the status code carrying the verdict. Marked `@TomPublicAccess` (no
  /// authentication) and `logRequests: false` so probe traffic does not flood
  /// the logs.
  ///
  /// Returns a shelf [Response] rather than a `String`, because the status is
  /// part of the answer and a `String` has nowhere to put it. That is the
  /// pipeline's documented escape hatch — a handler that knows its whole
  /// response returns one — and it is used here rather than inventing a
  /// directive in `endpoint_results.dart` because one caller is not a pattern:
  /// `TomRedirect` exists for the case where the *body* is implied by the
  /// intent, and here the handler is holding both facts already.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: "/health",
    produces: TomMimeType.plainText,
    logRequests: false,
  )
  Future<Response> health();

  /// The `GET /ready` endpoint — **readiness**: the same shape as [health],
  /// answered by [TomHealthServer.readinessAnalyzer].
  ///
  /// `/ready` rather than `/health/ready`: a sub-path of the liveness route
  /// reads as a refinement of it, and these are two questions rather than one
  /// asked in more detail. It is also the path the platforms' own examples use,
  /// which is the path an operator will try first.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: "/ready",
    produces: TomMimeType.plainText,
    logRequests: false,
  )
  Future<Response> ready();
}

/// Default implementation of [TomHealthService].
///
/// Delegates each route to its own analyzer — [livenessAnalyzer] for `/health`,
/// [readinessAnalyzer] for `/ready` — and turns the verdict it gets back into
/// the response. Install a custom [TomHealthAnalyzer] on either before server
/// startup to add real checks.
@tomReflector
@tomComponent
class TomHealthServer implements TomHealthService {
  static TomHealthAnalyzer _livenessAnalyzer = TomDefaultHealthAnalyzer();
  static TomHealthAnalyzer _readinessAnalyzer = TomDefaultHealthAnalyzer();

  /// The analyzer every `GET /health` request is answered by — **liveness**.
  ///
  /// Defaults to [TomDefaultHealthAnalyzer], which reports healthy. Install a
  /// custom implementation with [installLivenessAnalyzer].
  ///
  /// Named for the question rather than for the module, now that there are two:
  /// a `healthAnalyzer` sitting beside a [readinessAnalyzer] reads as though it
  /// covered both.
  ///
  /// It is `static`, so it is process-wide: one installation applies to every
  /// request and to every [TomHealthServer] instance. There is no per-instance
  /// or per-request override.
  static TomHealthAnalyzer get livenessAnalyzer => _livenessAnalyzer;

  /// The analyzer every `GET /ready` request is answered by — **readiness**.
  ///
  /// A separate instance rather than the same object, so installing one does
  /// not silently change the other.
  ///
  /// Defaults to always-ready, and that default is a choice worth naming. The
  /// cautious alternative — not ready until something says so — would make a
  /// deployment that never configures readiness receive no traffic at all, and
  /// the cause would be invisible: a healthy process, a passing liveness probe
  /// and an empty load balancer. Always-ready keeps the framework's default a
  /// working server, and a deployment that has a real readiness question
  /// answers it here.
  static TomHealthAnalyzer get readinessAnalyzer => _readinessAnalyzer;

  /// Installs [analyzer] as the process-wide liveness analyzer, logging the
  /// replacement at info.
  ///
  /// Read-only storage with one installing function, rather than an assignable
  /// field, because installation is the whole of the module's configuration and
  /// it happens through a process-wide global. A bare public static can be
  /// replaced by anything in the process at any moment — including after the
  /// server is serving — and an assignment leaves no trace, so a deployment
  /// answering a probe with the wrong analyzer has nothing to read. The log
  /// line, naming the outgoing and incoming runtime types, is that trace.
  ///
  /// It is not sealed after startup, and deliberately: the analyzer has to be
  /// replaceable before the bean context exists, which is what rules out making
  /// it a bean, and the framework has no way to know when a given deployment
  /// has finished installing. A seal nothing can call is dead code; a visible
  /// late installation is the boundary that can actually be enforced.
  static void installLivenessAnalyzer(TomHealthAnalyzer analyzer) =>
      _livenessAnalyzer = _installed('liveness', _livenessAnalyzer, analyzer);

  /// Installs [analyzer] as the process-wide readiness analyzer, logging the
  /// replacement at info. See [installLivenessAnalyzer] for why installation
  /// goes through a function.
  static void installReadinessAnalyzer(TomHealthAnalyzer analyzer) =>
      _readinessAnalyzer = _installed(
        'readiness',
        _readinessAnalyzer,
        analyzer,
      );

  /// Installs a fresh [TomDefaultHealthAnalyzer] on both probes.
  ///
  /// The supported spelling for a test or an example that installed an analyzer
  /// and wants the process back the way it found it. Each probe gets its own
  /// instance, which is the state a fresh process starts in.
  ///
  /// It logs like any other installation, because it is one: a reset that went
  /// unrecorded would be the one replacement the log could not account for.
  static void resetHealthAnalyzers() {
    installLivenessAnalyzer(TomDefaultHealthAnalyzer());
    installReadinessAnalyzer(TomDefaultHealthAnalyzer());
  }

  /// Announces that [next] replaces [previous] on the [probe] analyzer, and
  /// returns [next] for the caller to store.
  static TomHealthAnalyzer _installed(
    String probe,
    TomHealthAnalyzer previous,
    TomHealthAnalyzer next,
  ) {
    tomLog.info(
      'TomHealthServer: $probe analyzer is now ${next.runtimeType}, '
      'installed over ${previous.runtimeType}',
    );
    return next;
  }

  @override
  Future<Response> health() async =>
      responseFor(await _livenessAnalyzer.analyzeHealth());

  @override
  Future<Response> ready() async =>
      responseFor(await _readinessAnalyzer.analyzeHealth());

  /// The HTTP response one [status] is served as.
  ///
  /// Public and static so a deployment writing a health endpoint of its own —
  /// a third route, a different path — answers with the same shape rather than
  /// a second spelling of it.
  ///
  /// The content type is set here because a handler returning a `Response`
  /// bypasses the endpoint's `produces`, and a probe log full of
  /// `application/octet-stream` is a small confusion nobody needs to earn.
  static Response responseFor(TomHealthStatus status) => Response(
    status.statusCode,
    body: status.message,
    headers: {TomHeader.contentType: TomMimeType.plainText.toHeaderValue()},
  );
}

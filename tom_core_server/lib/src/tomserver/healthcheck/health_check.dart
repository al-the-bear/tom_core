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
/// // Set globally before server starts
/// TomHealthServer.healthAnalyzer = MyHealthAnalyzer();
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
/// Declares the `GET /health` endpoint that container orchestration tools
/// (Docker, Kubernetes) call to verify server availability. The response body
/// is the installed [TomHealthAnalyzer]'s message verbatim — `"OK"` is the
/// [TomDefaultHealthAnalyzer]'s answer, not a constant of the endpoint — and
/// the **status code is the verdict**: `200` for
/// [TomHealthVerdict.healthy], `503` for [TomHealthVerdict.unhealthy].
///
/// Which is what makes an ordinary probe correct. A load balancer's default
/// check reads the status code and nothing else, as does a Kubernetes `httpGet`
/// probe unless the deployment adds a body matcher; both now stop sending
/// traffic to a process whose analyzer says it cannot serve. A probe that wants
/// the *reason* still reads the body, which is where it has always been.
@tomReflector
@tomService
abstract class TomHealthService {
  /// The `GET /health` endpoint: a plain-text status string, with the status
  /// code carrying the verdict. Marked `@TomPublicAccess` (no authentication)
  /// and `logRequests: false` so probe traffic does not flood the logs.
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
}

/// Default implementation of [TomHealthService].
///
/// Delegates every request to [healthAnalyzer]; assign a custom
/// [TomHealthAnalyzer] there before server startup to add real checks.
@tomReflector
@tomComponent
class TomHealthServer implements TomHealthService {
  /// The analyzer every `/health` request is answered by.
  ///
  /// Defaults to [TomDefaultHealthAnalyzer], which reports healthy. Replace it
  /// with a custom implementation before the server starts.
  ///
  /// It is `static`, so it is process-wide: one assignment applies to every
  /// request and to every [TomHealthServer] instance. There is no per-instance
  /// or per-request override.
  static TomHealthAnalyzer healthAnalyzer = TomDefaultHealthAnalyzer();

  @override
  Future<Response> health() async =>
      responseFor(await healthAnalyzer.analyzeHealth());

  /// The HTTP response one [status] is served as.
  ///
  /// Public and static so a deployment writing its own health endpoint — a
  /// second route, a different path — answers with the same shape rather than
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

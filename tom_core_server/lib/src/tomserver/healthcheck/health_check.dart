import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';

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
/// class MyHealthAnalyzer extends HealthAnalyzer {
///   @override
///   Future<String> analyzeHealth() async {
///     final dbOk = await checkDatabaseConnection();
///     final cacheOk = await checkCacheService();
///     if (dbOk && cacheOk) {
///       return "OK";
///     }
///     return "DEGRADED: db=$dbOk, cache=$cacheOk";
///   }
/// }
///
/// // Set globally before server starts
/// TomHealthServer.globalSettingsHealthAnalyzer = MyHealthAnalyzer();
/// ```
abstract class HealthAnalyzer {
  /// Analyzes the health of the server and returns a status string.
  ///
  /// Returns "OK" for healthy status, or a descriptive message for
  /// degraded/unhealthy states.
  Future<String> analyzeHealth();
}

/// Default health analyzer that always returns "OK".
class DefaultHealthAnalyzer extends HealthAnalyzer {
  @override
  Future<String> analyzeHealth() async {
    return "OK";
  }
}

/// Health check service interface for server health monitoring.
///
/// Declares the `GET /health` endpoint that container orchestration tools
/// (Docker, Kubernetes) call to verify server availability. The response body
/// is whatever the installed [HealthAnalyzer] returns, verbatim — `"OK"` is
/// the [DefaultHealthAnalyzer]'s answer, not a constant of the endpoint.
///
/// Which is what decides how the probe should be written. Every analyzer
/// string is served with HTTP 200, because mapping a status to a status code
/// is deliberately left to the deployment (see `doc/healthcheck.md`). So a
/// probe that checks only for a 200 is testing liveness alone, and will keep
/// reporting healthy while a custom analyzer answers `"DEGRADED: db=false"`.
/// A probe that is meant to act on the verdict has to read the body.
@tomReflector
@tomService
abstract class TomHealthService {
  /// The `GET /health` endpoint: returns a plain-text status string. Marked
  /// `@TomPublicAccess` (no authentication) and `logRequests: false` so probe
  /// traffic does not flood the logs.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: "/health",
    produces: TomMimeType.plainText,
    logRequests: false,
  )
  Future<String> health();
}

/// Default implementation of [TomHealthService].
///
/// Delegates health checks to [globalSettingsHealthAnalyzer].
/// Set [globalSettingsHealthAnalyzer] to a custom [HealthAnalyzer]
/// implementation before server startup for custom health check logic.
@tomReflector
@tomComponent
class TomHealthServer implements TomHealthService {
  /// Global health analyzer instance used by all health check requests.
  ///
  /// Defaults to [DefaultHealthAnalyzer] which returns "OK".
  /// Replace with a custom implementation for advanced health checks.
  static HealthAnalyzer globalSettingsHealthAnalyzer = DefaultHealthAnalyzer();

  @override
  Future<String> health() async {
    return globalSettingsHealthAnalyzer.analyzeHealth();
  }
}

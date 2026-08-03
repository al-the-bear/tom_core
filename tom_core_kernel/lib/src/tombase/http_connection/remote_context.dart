/// Remote server context configuration module.
///
/// This library provides [TomClientRemoteContext] for configuring
/// where client applications should send server requests. It supports:
///
/// - Primary server base URI configuration
/// - Separate authentication server URI (optional)
/// - Singleton pattern for global access
///
/// ## Example
///
/// ```dart
/// // Initialize the remote context (typically at app startup)
/// TomClientRemoteContext.setCurrent(
///   TomClientRemoteContext(
///     Uri.parse('https://api.example.com'),
///     Uri.parse('https://auth.example.com'), // optional
///   ),
/// );
///
/// // Access later in code
/// final baseUri = TomClientRemoteContext.current!.baseUri;
/// ```
library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXCEPTIONS
// =============================================================================

/// Exception thrown when remote context initialization fails.
///
/// Typically thrown when attempting to initialize the context twice.
class TomClientRemoteContextException extends TomException {
  TomClientRemoteContextException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

// =============================================================================
// REMOTE CONTEXT
// =============================================================================

/// Configures the remote server connection for client applications.
///
/// This class holds the base URI for the primary API server and optionally
/// a separate authentication server. Only one context can be active at a time.
///
/// ## Initialization
///
/// The context should be set once during application startup:
///
/// ```dart
/// TomClientRemoteContext.setCurrent(
///   TomClientRemoteContext(Uri.parse('https://api.example.com')),
/// );
/// ```
///
/// ## Separate Authentication Server
///
/// If your authentication server is different from your API server:
///
/// ```dart
/// TomClientRemoteContext.setCurrent(
///   TomClientRemoteContext(
///     Uri.parse('https://api.example.com'),
///     Uri.parse('https://auth.example.com'),
///   ),
/// );
/// ```
class TomClientRemoteContext {
  /// The process-wide context installed by [setCurrent].
  static TomClientRemoteContext? _processContext;

  /// The currently active remote context.
  ///
  /// Returns the context installed by the nearest enclosing [runWithContext],
  /// falling back to the one set by [setCurrent], or `null` if neither has run.
  ///
  /// Read-only: this value decides which remote *every* subsequent call
  /// addresses, so it is written only through [setCurrent] (once, at startup)
  /// or [runWithContext] (scoped to a body).
  static TomClientRemoteContext? get current =>
      getFromCurrentZone<TomClientRemoteContext>() ?? _processContext;

  /// The URI for authentication requests.
  ///
  /// Defaults to [baseUri] if not specified separately.
  late Uri authenticationUri;

  /// The base URI for all API requests.
  Uri baseUri;

  /// Creates a new remote context.
  ///
  /// - [baseUri]: The primary server URI for API requests
  /// - [authenticationUri]: Optional separate URI for authentication.
  ///   If not provided, [baseUri] is used for authentication as well.
  TomClientRemoteContext(this.baseUri, [Uri? authenticationUri]) {
    this.authenticationUri = authenticationUri ?? baseUri;
  }

  /// Sets the current remote context for the application.
  ///
  /// This can only be called once. Attempting to set the context
  /// a second time will throw [TomClientRemoteContextException].
  ///
  /// ## Example
  ///
  /// ```dart
  /// TomClientRemoteContext.setCurrent(
  ///   TomClientRemoteContext(Uri.parse('https://api.example.com')),
  /// );
  /// ```
  static void setCurrent(TomClientRemoteContext context) {
    if (_processContext == null) {
      _processContext = context;
      tomLog.info("Setting remote context to $context");
    } else {
      throw TomClientRemoteContextException(
        "tomclient.remote_context_state_error.already_initialized",
        "TomClientRemoteContext cannot be initialized twice",
      );
    }
  }

  /// Runs [body] with [context] as [current], then restores what was there
  /// before.
  ///
  /// This is the supported way to address a different remote for part of a
  /// program — a tool talking to two servers, or a test exercising one. The
  /// context is carried on the [Zone], so it follows [body] across `await`
  /// boundaries and cannot leak past it.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final report = await TomClientRemoteContext.runWithContext(
  ///   TomClientRemoteContext(Uri.parse('https://reporting.example.com')),
  ///   () => reportingApi.fetchSummary(),
  /// );
  /// ```
  static T runWithContext<T>(
    TomClientRemoteContext context,
    T Function() body,
  ) {
    return runZoned(body, zoneValues: {TomClientRemoteContext: context});
  }

  /// Clears the context installed by [setCurrent], so it may be called again.
  ///
  /// Exists for tests, which need a clean process context per case;
  /// application code sets the context once at startup and uses
  /// [runWithContext] for anything narrower.
  @visibleForTesting
  static void resetCurrent() => _processContext = null;

  @override
  String toString() => "TomClientRemoteContext $baseUri";
}

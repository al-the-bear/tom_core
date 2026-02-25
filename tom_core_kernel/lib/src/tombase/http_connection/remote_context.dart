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
  /// The currently active remote context.
  ///
  /// Returns `null` if no context has been set.
  static TomClientRemoteContext? current;

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
    if (current == null) {
      current = context;
      tomLog.info("Setting remote context to $context");
    } else {
      throw TomClientRemoteContextException(
        "tomclient.remote_context_state_error.already_initialized",
        "TomClientRemoteContext cannot be initialized twice",
      );
    }
  }

  @override
  String toString() => "TomClientRemoteContext $baseUri";
}

/// Exception base classes and error handling utilities.
///
/// This library provides the foundation for exception handling throughout
/// the tom_core framework. It includes:
///
/// - [TomException] - Full-featured exception class with logging and server error support
///
/// For the minimal base class without dependencies, see [TomBaseException]
/// from the `tom_basics` package.
///
/// ## Example
///
/// ```dart
/// // Create and throw a tracked exception
/// throw TomException(
///   'USER_NOT_FOUND',
///   'The requested user could not be found',
///   parameters: {'userId': userId},
///   autoLog: true,
/// );
///
/// // Catch and inspect
/// try {
///   // ... operation that may fail
/// } on TomException catch (e) {
///   print('Error ${e.uuid}: ${e.key}');
///   e.printStackTrace();
/// }
/// ```
library;

import 'package:tom_basics/tom_basics.dart';

import '../http_connection/server_connection.dart';
import 'little_things.dart';

// =============================================================================
// EXCEPTION CLASSES
// =============================================================================

/// Full-featured exception class with logging, server error tracking, and UUID support.
///
/// [TomException] extends [TomBaseException] with additional features:
///
/// - **Auto Logging**: Optional automatic logging when thrown
/// - **Server Call Error**: Track HTTP-related error details
/// - **TomLoggable**: Integration with the TOM logging system
///
/// For a minimal exception class without these dependencies, use
/// [TomBaseException] from the `tom_basics` package.
///
/// ## Example
///
/// ```dart
/// // Basic exception
/// throw TomException('ERROR_CODE', 'Something went wrong');
///
/// // Exception with parameters for context
/// throw TomException(
///   'VALIDATION_ERROR',
///   'Invalid email format',
///   parameters: {'field': 'email', 'value': userInput},
/// );
///
/// // Exception with auto-logging enabled
/// throw TomException(
///   'CRITICAL_ERROR',
///   'Database connection failed',
///   autoLog: true,
///   rootException: originalException,
/// );
/// ```
///
/// See also:
/// - [TomBaseException] for the minimal base class
/// - [TomServerConnectionException] for HTTP-related errors
/// - [TomLoggable] for the logging interface
class TomException extends TomBaseException implements TomLoggable {
  /// Whether to automatically log this exception when created.
  bool autoLog;

  /// Server call error details, if this exception originated from an HTTP call.
  TomServerCallError? serverCallError;

  /// Reserved for future use.
  String? newField;

  /// Creates a new [TomException] with the given error details.
  ///
  /// The [key] should be a consistent error code for programmatic handling.
  /// The [defaultUserMessage] should be human-readable.
  ///
  /// If [autoLog] is true, the exception is logged immediately upon creation.
  TomException(
    super.key,
    super.defaultUserMessage, {
    super.requestUuid,
    super.parameters,
    super.rootException,
    this.autoLog = false,
    super.stack,
    super.uuid,
    this.serverCallError,
  }) {
    if (autoLog) {
      tomLog.error("EXCEPTION: $this");
      tomLog.error("EXCEPTION_STACKTRACE: $uuid-$requestUuid $stackTrace");
    }
  }

  @override
  String get logRepresentation => toString();

  /// Prints the stack trace to the log.
  ///
  /// The [depth] parameter limits how many stack frames to print.
  /// Use -1 (default) to print all frames.
  @override
  void printStackTrace([int depth = -1]) {
    tomPrintStackTrace(
      stack,
      depth: depth,
      message: "$uuid-$requestUuid exception stacktrace",
    );
  }
}

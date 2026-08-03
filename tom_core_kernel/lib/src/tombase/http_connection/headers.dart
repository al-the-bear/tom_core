/// HTTP header constants module.
///
/// This library provides commonly used HTTP header name constants
/// for consistent header usage across the application.
///
/// ## Example
///
/// ```dart
/// response.headers[TomHeader.contentType] = 'application/json';
/// response.headers[TomHeader.contentDisposition] = 'attachment; filename="data.json"';
/// ```
library;

// =============================================================================
// HEADER CONSTANTS
// =============================================================================

/// Constants for commonly used HTTP header names.
///
/// Provides standardized access to HTTP header field names to avoid
/// typos and ensure consistency across the codebase.
///
/// ## Example
///
/// ```dart
/// final contentType = request.headers[TomHeader.contentType];
/// ```
class TomHeader {
  /// The Content-Type header field name.
  ///
  /// Indicates the media type of the resource or the data being sent.
  static const contentType = "Content-Type";

  /// The Content-Disposition header field name.
  ///
  /// Used to indicate if the content should be displayed inline or
  /// as an attachment to be downloaded.
  static const contentDisposition = "Content-Disposition";

  /// The Location header field name.
  ///
  /// Carries the target of a redirect (3xx) response — the one header that
  /// makes a redirect a redirect rather than an empty body with an odd status.
  static const location = "Location";
}

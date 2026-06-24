/// MIME type definitions and utilities module.
///
/// This library provides the [TomMimeType] class for representing and
/// working with MIME types (media types). It includes:
///
/// - Common MIME type constants (JSON, HTML, PDF, etc.)
/// - Parsing MIME types from strings
/// - File extension to MIME type mapping
/// - Content-Type header value generation
///
/// ## Example
///
/// ```dart
/// // Use predefined constants
/// final jsonType = TomMimeType.json;
/// print(jsonType.toHeaderValue()); // "application/json;charset=UTF-8"
///
/// // Parse from string
/// final parsed = TomMimeType.parse('text/html');
///
/// // Get MIME type from file extension
/// final pdfType = StaticFileMimetypeMapping.getMimeType('.pdf');
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXCEPTIONS
// =============================================================================

/// Exception thrown when MIME type parsing or validation fails.
class TomMimeTypeException extends TomException {
  TomMimeTypeException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

// =============================================================================
// MIME TYPE DEFINITION
// =============================================================================

/// Represents a MIME type (media type) with primary type, subtype, and optional charset.
///
/// MIME types are used to specify the format of data in HTTP requests and responses.
/// They follow the pattern `primaryType/subType` (e.g., `application/json`).
///
/// ## Predefined Types
///
/// Common MIME types are available as static constants:
/// - Text: [plainText], [html], [css], [csv], [javascript]
/// - Application: [json], [xml], [pdf], [zip], [octetStream]
/// - Multipart: [multipartFormData], [multipartByteranges]
/// - Form: [urlEncoded]
///
/// ## Example
///
/// ```dart
/// // Use predefined constant
/// final mimeType = TomMimeType.json;
///
/// // Create custom MIME type
/// final custom = TomMimeType('application', 'vnd.api+json');
///
/// // Generate header value
/// response.headers['Content-Type'] = mimeType.toHeaderValue();
/// ```
class TomMimeType {
  /// Placeholder for endpoints that don't consume a request body.
  ///
  /// Use for GET, HEAD, TRACE requests or similar.
  static const none = TomMimeType('none', 'none');

  /// Plain text MIME type (`text/plain`).
  static const plainText = TomMimeType('text', 'plain');

  /// iCalendar MIME type (`text/calendar`) for .ics files.
  static const ics = TomMimeType("text", "calendar");

  /// HTML MIME type (`text/html`).
  static const html = TomMimeType('text', 'html');

  /// CSS MIME type (`text/css`).
  static const css = TomMimeType('text', 'css');

  /// CSV MIME type (`text/csv`).
  static const csv = TomMimeType('text', 'csv');

  /// JavaScript MIME type (`text/javascript`).
  static const javascript = TomMimeType('text', 'javascript', charset: null);

  /// JSON MIME type (`application/json`).
  static const json = TomMimeType('application', 'json');

  /// XML MIME type (`application/xml`).
  static const xml = TomMimeType('application', 'xml');

  /// Binary/octet-stream MIME type (`application/octet-stream`).
  ///
  /// Used for arbitrary binary data.
  static const octetStream = TomMimeType(
    'application',
    'octet-stream',
    charset: null,
  );

  /// PDF MIME type (`application/pdf`).
  static const pdf = TomMimeType('application', 'pdf', charset: null);

  /// RTF MIME type (`application/rtf`).
  static const rtf = TomMimeType('application', 'rtf');

  /// PKCS8 MIME type (`application/pkcs8`).
  static const pkcs8 = TomMimeType('application', 'pkcs8', charset: null);

  /// ZIP archive MIME type (`application/zip`).
  static const zip = TomMimeType('application', 'zip', charset: null);

  /// Multipart form data MIME type (`multipart/form-data`).
  ///
  /// Used for form submissions with file uploads.
  static const multipartFormData = TomMimeType(
    'multipart',
    'form-data',
    charset: null,
  );

  /// Multipart byteranges MIME type (`multipart/byteranges`).
  static const multipartByteranges = TomMimeType(
    'multipart',
    'byteranges',
    charset: null,
  );

  /// URL-encoded form MIME type (`application/x-www-form-urlencoded`).
  ///
  /// Used for standard HTML form submissions.
  static const urlEncoded = TomMimeType(
    'application',
    'x-www-form-urlencoded',
    charset: null,
  );

  /// The primary type (e.g., "application", "text", "image").
  final String primaryType;

  /// The subtype (e.g., "json", "html", "png").
  final String subType;

  /// Optional charset for text-based types (e.g., "UTF-8").
  final String? charset;

  /// Optional codecs for media types (e.g., for video).
  final List<String> codecs;

  /// Creates a MIME type with the given primary type and subtype.
  ///
  /// - [primaryType]: The top-level type (e.g., "application", "text")
  /// - [subType]: The specific format (e.g., "json", "html")
  /// - [charset]: Character encoding (defaults to "UTF-8", use `null` for binary)
  /// - [codecs]: Optional list of codecs for media types
  const TomMimeType(
    this.primaryType,
    this.subType, {
    this.charset = "UTF-8",
    this.codecs = const [],
  });

  /// Parses a MIME type string into a [TomMimeType] instance.
  ///
  /// Expects format: `primaryType/subType` (e.g., "application/json").
  ///
  /// Throws [TomMimeTypeException] if the string is not a valid MIME type.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final mimeType = TomMimeType.parse('text/html');
  /// print(mimeType.primaryType); // "text"
  /// print(mimeType.subType);     // "html"
  /// ```
  factory TomMimeType.parse(final String type) {
    final parts = type.split('/');
    if (parts.length != 2) {
      throw TomMimeTypeException(
        "mime_type.parse.invalid_number_of_parts",
        'Invalid mime type $type',
      );
    }

    final primaryType = parts[0];
    final subType = parts[1];

    if (primaryType.isEmpty || subType.isEmpty) {
      throw TomMimeTypeException(
        "mime_type.parse.invalid_mime_type,.empty_parts",
        'Invalid mime type $type',
      );
    }

    return TomMimeType(primaryType, subType);
  }

  /// Whether this MIME type represents text-based content.
  ///
  /// Returns `true` for:
  /// - All `text/*` types
  /// - `application/json`, `application/xml`, `application/javascript`
  /// - Types with `+json` or `+xml` suffix
  bool get isText {
    if (primaryType == 'text') return true;
    if (primaryType == 'application') {
      final st = subType.toLowerCase();
      // Common text-like app types and structured syntax suffixes.
      return st == 'json' ||
          st == 'xml' ||
          st == 'javascript' ||
          st == 'x-www-form-urlencoded' ||
          st.endsWith('+json') ||
          st.endsWith('+xml');
    }
    return false;
  }

  /// Returns the value to use for the Content-Type header.
  ///
  /// Includes charset if specified, and codecs for media types.
  ///
  /// ## Example
  ///
  /// ```dart
  /// TomMimeType.json.toHeaderValue(); // "application/json;charset=UTF-8"
  /// ```
  String toHeaderValue() =>
      '$primaryType/$subType${charset != null ? ";charset=$charset" : ""}${codecs.isNotEmpty ? ";codecs=${codecs.join(",")}" : ""}';

  @override
  String toString() =>
      '$primaryType/$subType${charset != null ? ";charset:$charset" : ""}${codecs.isNotEmpty ? codecs.toString() : ""}';

  @override
  bool operator ==(final Object other) {
    if (other is! TomMimeType) return false;
    if (isEqualType(other)) {
      if (other.codecs.length == codecs.length) {
        for (var i = 0; i < codecs.length; i++) {
          if (codecs[i] != other.codecs[i]) {
            return false;
          }
        }
        return true;
      } else {
        return false;
      }
    }
    return false;
  }

  /// Checks if this MIME type has the same primary and sub type as another.
  ///
  /// Does not compare charset or codecs.
  bool isEqualType(TomMimeType other) {
    return primaryType == other.primaryType && subType == other.subType;
  }

  @override
  int get hashCode => Object.hash(primaryType, subType, charset, codecs);
}

// =============================================================================
// FILE EXTENSION MAPPING
// =============================================================================

/// Maps file extensions to their corresponding MIME types.
///
/// Useful for serving static files with correct Content-Type headers.
///
/// ## Example
///
/// ```dart
/// final mimeType = StaticFileMimetypeMapping.getMimeType('.json');
/// // Returns TomMimeType.json
/// ```
class StaticFileMimetypeMapping {
  static const _mimeTypeMapping = <String, TomMimeType>{
    '.js': TomMimeType.javascript,
    '.json': TomMimeType.json,
    '.wasm': TomMimeType('application', 'wasm', charset: null),
    '.css': TomMimeType.css,
    '.png': TomMimeType('image', 'png', charset: null),
    '.jpg': TomMimeType('image', 'jpeg', charset: null),
    '.jpeg': TomMimeType('image', 'jpeg', charset: null),
    '.svg': TomMimeType('image', 'svg+xml'),
    '.ttf': TomMimeType('application', 'x-font-ttf', charset: null),
    '.woff': TomMimeType('application', 'x-font-woff', charset: null),
    '.mp3': TomMimeType('audio', 'mpeg', charset: null),
    '.pdf': TomMimeType.pdf,
    '.apng': TomMimeType('image', 'apng', charset: null),
    '.avi': TomMimeType('image', 'avif', charset: null),
    '.gif': TomMimeType('image', 'gif', charset: null),
    '.webp': TomMimeType('image', 'webp', charset: null),
    '.rar': TomMimeType('application', 'x-rar-compressed', charset: null),
    '.mp4': TomMimeType('video', 'mp4', charset: null),
    '.mpeg': TomMimeType('video', 'mpg', charset: null),
    '.ogg': TomMimeType('video', 'ogg', charset: null),
    '.qt': TomMimeType('video', 'quicktime', charset: null),
    '.zip': TomMimeType.zip,
  };

  /// Gets the MIME type for a file extension.
  ///
  /// Returns `null` if the extension is not recognized.
  ///
  /// - [extension]: The file extension including the dot (e.g., ".json")
  static TomMimeType? getMimeType(String extension) {
    return _mimeTypeMapping[extension.toLowerCase()];
  }
}

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
/// ## Equality
///
/// [operator ==] is whole-value — charset and codecs count, because they change
/// how the bytes are read. [isEqualType] is the media-type-only comparison, and
/// is the one to use against an incoming `content-type`: a real request carries
/// parameters the declaration never named.
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

  /// Parses a `Content-Type` value into a [TomMimeType] instance.
  ///
  /// Accepts a media type optionally followed by parameters — the shape a real
  /// header has: `application/json;charset=UTF-8`, `text/html; charset="utf-8"`,
  /// `multipart/form-data; boundary=----abc`. Optional whitespace after each
  /// `;` and a quoted parameter value are both allowed, and parameter names are
  /// matched case-insensitively.
  ///
  /// [charset] and [codecs] are read from the parameters; **any other parameter
  /// is ignored** rather than rejected, because a request this is asked to read
  /// carries parameters this class has no field for (a multipart boundary
  /// always does).
  ///
  /// A charset the header does not state stays `null` rather than defaulting to
  /// `UTF-8` — a header states what it states, and inventing an encoding here
  /// would make a parsed `application/pdf` differ from [pdf]. This makes the
  /// factory the exact inverse of [toHeaderValue]:
  /// `TomMimeType.parse(x.toHeaderValue()) == x` for every value.
  ///
  /// Throws [TomMimeTypeException] if the media type is not `primary/sub` with
  /// both parts present.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final mimeType = TomMimeType.parse('text/html;charset=UTF-8');
  /// print(mimeType.primaryType); // "text"
  /// print(mimeType.subType);     // "html"
  /// print(mimeType.charset);     // "UTF-8"
  /// ```
  factory TomMimeType.parse(final String type) {
    final separator = type.indexOf(';');
    final mediaType = separator < 0 ? type : type.substring(0, separator);

    final parts = mediaType.split('/');
    if (parts.length != 2) {
      throw TomMimeTypeException(
        "mime_type.parse.invalid_number_of_parts",
        'Invalid mime type $type',
      );
    }

    final primaryType = parts[0].trim();
    final subType = parts[1].trim();

    if (primaryType.isEmpty || subType.isEmpty) {
      throw TomMimeTypeException(
        "mime_type.parse.invalid_mime_type.empty_parts",
        'Invalid mime type $type',
      );
    }

    if (separator < 0) {
      return TomMimeType(primaryType, subType, charset: null);
    }

    String? charset;
    var codecs = const <String>[];
    for (final parameter in type.substring(separator + 1).split(';')) {
      final assignment = parameter.indexOf('=');
      // A parameter with no value carries nothing this class stores; skipping
      // it keeps a stray `;` from failing a header that is otherwise readable.
      if (assignment < 0) continue;
      final name = parameter.substring(0, assignment).trim().toLowerCase();
      final value = _unquote(parameter.substring(assignment + 1).trim());
      switch (name) {
        case 'charset':
          charset = value;
        case 'codecs':
          codecs = value
              .split(',')
              .map((codec) => codec.trim())
              .where((codec) => codec.isNotEmpty)
              .toList(growable: false);
      }
    }

    return TomMimeType(
      primaryType,
      subType,
      charset: charset,
      codecs: codecs,
    );
  }

  /// Strips one pair of surrounding double quotes, which a parameter value is
  /// allowed to carry. The content is returned verbatim otherwise — a charset
  /// is echoed as the sender spelled it.
  static String _unquote(String value) {
    if (value.length < 2) return value;
    if (!value.startsWith('"') || !value.endsWith('"')) return value;
    return value.substring(1, value.length - 1);
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

  /// Whole-value equality: the media type **and** its parameters.
  ///
  /// Two values are equal when their primary type, subtype, charset and codecs
  /// all match. Parameters are part of identity because they change how the
  /// bytes are read: `text/html;charset=UTF-8` and the same type in Latin-1
  /// decode to different characters, and `video/mp4;codecs=avc1` is playable by
  /// a client that cannot decode `hevc`.
  ///
  /// [isEqualType] is the deliberately weaker comparison for the cases where
  /// only the media type matters — matching a declared constant against the
  /// `content-type` of a real request, which always carries parameters the
  /// declaration does not name.
  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    if (other is! TomMimeType) return false;
    if (!isEqualType(other)) return false;
    if (charset != other.charset) return false;
    if (codecs.length != other.codecs.length) return false;
    for (var i = 0; i < codecs.length; i++) {
      if (codecs[i] != other.codecs[i]) return false;
    }
    return true;
  }

  /// Checks if this MIME type has the same primary and sub type as another.
  ///
  /// Does not compare charset or codecs — unlike [operator ==], which is
  /// whole-value. This is the comparison to reach for when matching a declared
  /// constant against an incoming `content-type`: a real request carries a
  /// boundary or a charset the declaration never named, so whole-value equality
  /// would never match.
  bool isEqualType(TomMimeType other) {
    return primaryType == other.primaryType && subType == other.subType;
  }

  /// Hashes exactly the fields [operator ==] compares, as the contract requires.
  ///
  /// [codecs] goes through [Object.hashAll] rather than into [Object.hash]
  /// directly: a `List` hashes by identity, so two values with equal codec
  /// content would land in different buckets while comparing equal — a
  /// `Set` would hold both and a `Map` lookup would miss.
  @override
  int get hashCode =>
      Object.hash(primaryType, subType, charset, Object.hashAll(codecs));
}

// =============================================================================
// FILE EXTENSION MAPPING
// =============================================================================

/// Maps file extensions to their corresponding MIME types.
///
/// Useful for serving static files with correct Content-Type headers.
///
/// Every entry is the media type the IANA registry assigns to that extension.
/// The one exception is `.avi`, which IANA does not register at all — see the
/// note on that entry.
///
/// The table is deliberately short: it covers the extensions a Tom application
/// actually serves, and [getMimeType] returns `null` for anything else so the
/// caller can decide. Callers wanting a total function should use
/// `TomFileSource.guessMediaType`, which falls back to
/// `application/octet-stream`.
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
    // RFC 8081 registered the `font` tree; the older `application/x-font-*`
    // spellings were never registered.
    '.ttf': TomMimeType('font', 'ttf', charset: null),
    '.woff': TomMimeType('font', 'woff', charset: null),
    '.mp3': TomMimeType('audio', 'mpeg', charset: null),
    '.pdf': TomMimeType.pdf,
    '.apng': TomMimeType('image', 'apng', charset: null),
    '.avif': TomMimeType('image', 'avif', charset: null),
    // The only unregistered type in this table: IANA assigns no media type to
    // AVI, so this is the de-facto type servers and browsers agree on.
    '.avi': TomMimeType('video', 'x-msvideo', charset: null),
    '.gif': TomMimeType('image', 'gif', charset: null),
    '.webp': TomMimeType('image', 'webp', charset: null),
    '.rar': TomMimeType('application', 'vnd.rar', charset: null),
    '.mp4': TomMimeType('video', 'mp4', charset: null),
    '.mpeg': TomMimeType('video', 'mpeg', charset: null),
    // RFC 5334 splits the Ogg container by content: `.ogg` is audio, because
    // implementations predating the split read it as Vorbis, and video moved
    // to `.ogv`.
    '.ogg': TomMimeType('audio', 'ogg', charset: null),
    '.ogv': TomMimeType('video', 'ogg', charset: null),
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

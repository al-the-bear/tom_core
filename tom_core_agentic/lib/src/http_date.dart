// RFC 7231 HTTP-date parsing — without `dart:io`.
//
// `dart:io` ships an `HttpDate.parse`, but pulling in `dart:io` makes
// the consuming library VM-only. This re-implementation uses only core
// Dart so web tools that must compile under Flutter web can still parse
// a `Retry-After` / `Date` header.

/// Parser for the three date formats RFC 7231 § 7.1.1.1 permits in an
/// HTTP-date header.
///
/// Accepts:
///   - RFC 1123: `Wed, 21 Oct 2026 07:28:00 GMT`
///   - RFC 850:  `Wednesday, 21-Oct-26 07:28:00 GMT`
///   - asctime:  `Wed Oct 21 07:28:00 2026`
///
/// Always returns a UTC [DateTime]. Throws [FormatException] on any
/// unparseable input.
class HttpDate {
  static const _months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static DateTime parse(String input) {
    final trimmed = input.trim();
    // RFC 1123 + RFC 850 share the comma; asctime does not.
    if (trimmed.contains(',')) {
      return _parseRfc1123OrRfc850(trimmed);
    }
    return _parseAsctime(trimmed);
  }

  static DateTime _parseRfc1123OrRfc850(String input) {
    // After the comma: `21 Oct 2026 07:28:00 GMT` or
    // `21-Oct-26 07:28:00 GMT`.
    final afterComma = input.split(',').last.trim();
    final tokens = afterComma.split(RegExp(r'[\s-]+'));
    if (tokens.length < 5) {
      throw FormatException('Invalid HTTP-date: $input');
    }
    final day = int.parse(tokens[0]);
    final month = _monthOrThrow(tokens[1]);
    final yearToken = tokens[2];
    final year = yearToken.length == 2
        ? 2000 + int.parse(yearToken)
        : int.parse(yearToken);
    final timeParts = tokens[3].split(':');
    if (timeParts.length != 3) {
      throw FormatException('Invalid HTTP-date time: $input');
    }
    return DateTime.utc(
      year,
      month,
      day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }

  static DateTime _parseAsctime(String input) {
    final tokens = input.split(RegExp(r'\s+'));
    if (tokens.length < 5) {
      throw FormatException('Invalid HTTP-date (asctime): $input');
    }
    final month = _monthOrThrow(tokens[1]);
    final day = int.parse(tokens[2]);
    final timeParts = tokens[3].split(':');
    if (timeParts.length != 3) {
      throw FormatException('Invalid HTTP-date asctime time: $input');
    }
    final year = int.parse(tokens[4]);
    return DateTime.utc(
      year,
      month,
      day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }

  static int _monthOrThrow(String token) {
    final m = _months[token.toLowerCase().substring(0, 3)];
    if (m == null) {
      throw FormatException('Unknown HTTP-date month: $token');
    }
    return m;
  }
}

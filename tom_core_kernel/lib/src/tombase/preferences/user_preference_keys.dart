/// The framework's well-known preference keys — the vocabulary shared by the
/// server-side store (C-13) and the device-side store (C-14).
///
/// A preference key is a string, and a string that is spelled in two places is
/// a preference that silently splits in two: the client writes `"timezone"`,
/// the server reads `"timeZone"`, and neither side fails — the reader simply
/// finds nothing and falls back, forever. So the keys the framework itself
/// reads live here, once, in the package both halves already depend on.
///
/// Applications are not limited to these. Any key satisfying
/// [TomUserPreferenceKeys.validate] is an application's to use; these are only
/// the ones the framework's own code looks up, and they are named so that an
/// application storing the same concept lands on the same key rather than
/// inventing a synonym.
library;

import '../little_things/exception_base.dart';

/// Raised when a preference key does not satisfy [TomUserPreferenceKeys].
///
/// A [TomException] rather than an `ArgumentError`, although a key is nearly
/// always a compile-time constant and a bad one is nearly always a bug. The
/// exception is that the server reads a key off the URL, where it is untrusted
/// input and its rejection is an answer the client is owed — an `ArgumentError`
/// there would surface as an opaque `500` for what is squarely a bad request.
/// One type covers both, and the `preferences.key.invalid` code is what the
/// boundary branches on.
class TomUserPreferenceKeyException extends TomException {
  /// Creates the exception; parameters mirror [TomException].
  TomUserPreferenceKeyException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  });
}

/// The preference keys the framework reads, and the rule every key obeys.
///
/// A namespace of constants rather than an enum: preference keys cross the wire
/// and live in a database column, so their *text* is the contract. An enum
/// would hide that text behind a name and make an application's own key a
/// second-class citizen of a different type.
///
/// ## What a key may be
///
/// **One to [maxLength] characters, starting with an ASCII letter, and
/// thereafter only ASCII letters, digits, `.`, `_` and `-`.**
///
/// A key is not free text, because it is not only a map key: the read and
/// delete endpoints are mounted at `/{key}`, so **every key is a URL path
/// segment**, and a segment that has to be escaped to be sent is a segment
/// whose meaning depends on what unescapes it. The write is the exception —
/// it states its key in the body — but that buys nothing here: a key written
/// through the body is read and deleted through the path, so a key the path
/// cannot carry is a key that can only be stored. Measured against the
/// contract's own endpoints, an unconstrained key does not merely look odd:
///
/// | Key | Resolves to | What that is |
/// | --- | ----------- | ------------ |
/// | `a/b` | `/preferences/a%2Fb` | a `%2F` much HTTP infrastructure rejects, or normalises back to `/` — addressing a two-segment path the API never declared |
/// | `""` | `/preferences/` | the **list** endpoint's URI |
/// | `.` | `/preferences/` | the same again |
/// | `..` | `/` | outside the API's path entirely |
///
/// The empty key is not a contrived input: it is what
/// `TomUserPreferenceKeyRequest()`'s own default produces, so a caller that
/// forgets to set one sends it.
///
/// Two clauses are worth their reasons:
///
/// - **It starts with a letter.** That is what excludes `.` and `..` above,
///   as a consequence of the rule rather than as two special cases — and with
///   them every other leading character (`-`, `_`, a digit) that some reader
///   somewhere treats as a flag, a hidden file or a number.
/// - **ASCII only.** `ü` has a composed and a decomposed Unicode form that
///   render identically and compare unequal, so one *visible* key would be two
///   stored keys. That is precisely the silent split this library's own
///   vocabulary exists to prevent, in a form no diff would ever show.
///
/// The rule lives here rather than in either half because both halves enforce
/// it: a client refuses to build a request under an illegal key, and the
/// server refuses one that arrives anyway. A rule stated in one half is a rule
/// the other half's callers discover in production.
class TomUserPreferenceKeys {
  const TomUserPreferenceKeys._();

  /// The longest a preference key may be.
  ///
  /// 191, which is `tom_user_preference.preference_key`'s own width — a longer
  /// key is one the server would store truncated, and two keys differing only
  /// past the cut would silently become one row. (191 rather than 255 because
  /// that is the widest `utf8mb4` column MariaDB will index under the default
  /// 767-byte key length, and the column is half of a unique key.)
  ///
  /// `tom_core_server`'s `user_preference_test.dart` asserts the DDL agrees, so
  /// the two cannot drift into disagreeing by inspection.
  static const int maxLength = 191;

  /// Whether [key] is a legal preference key — see the class documentation.
  ///
  /// The predicate a caller uses to *ask*; [validate] is the one that refuses.
  /// Both read the same rule, so there is no way for a key to pass one and
  /// fail the other.
  static bool isValid(String key) => _causeOf(key) == null;

  /// Throws a [TomUserPreferenceKeyException] unless [key] is legal.
  ///
  /// Called wherever a key enters — by the codec when it builds a DTO, by the
  /// client before it builds a URI, and by the server store before it reaches
  /// a column.
  static void validate(String key) {
    final cause = _causeOf(key);
    if (cause == null) return;
    throw TomUserPreferenceKeyException(
      'preferences.key.invalid',
      "'$key' is not a usable preference key: ${_explanationOf(cause, key)} "
          'A key is 1 to $maxLength characters, starts with an ASCII letter, '
          'and thereafter uses only ASCII letters, digits, and the characters '
          '. _ - — because it is sent as a URL path segment.',
      parameters: {'key': key, 'cause': cause},
    );
  }

  /// Which clause [key] breaks, or `null` when it breaks none.
  ///
  /// Ordered shape-before-size: a caller who fixes the characters and then
  /// hits the length has been told about two real problems, whereas one told
  /// only that a 300-character key is too long may shorten it and find the
  /// separator still in it.
  static String? _causeOf(String key) {
    if (key.isEmpty) return 'empty';
    if (!_isLetter(key.codeUnitAt(0))) return 'leading_character';
    for (var index = 1; index < key.length; index++) {
      if (!_isLegalBodyUnit(key.codeUnitAt(index))) return 'illegal_character';
    }
    if (key.length > maxLength) return 'too_long';
    return null;
  }

  /// The clause-specific half of the refusal, which names what is wrong with
  /// *this* key before the rule restates what a key is.
  static String _explanationOf(String cause, String key) {
    switch (cause) {
      case 'empty':
        return 'it is empty, which addresses the list endpoint rather than a '
            'preference.';
      case 'leading_character':
        return 'it starts with '
            "'${String.fromCharCode(key.codeUnitAt(0))}' rather than a "
            'letter.';
      case 'too_long':
        return 'it is ${key.length} characters long.';
      default:
        return "it contains '${_firstIllegalOf(key)}', which has to be "
            'escaped to be sent.';
    }
  }

  /// The first character of [key] the rule does not allow.
  static String _firstIllegalOf(String key) {
    for (var index = 1; index < key.length; index++) {
      if (!_isLegalBodyUnit(key.codeUnitAt(index))) {
        return key.substring(index, index + 1);
      }
    }
    return key;
  }

  static bool _isLetter(int unit) =>
      (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A);

  /// A letter, a digit, or one of `.`, `_`, `-`.
  static bool _isLegalBodyUnit(int unit) =>
      _isLetter(unit) ||
      (unit >= 0x30 && unit <= 0x39) ||
      unit == 0x2E ||
      unit == 0x5F ||
      unit == 0x2D;

  /// The user's preferred IANA timezone identifier (e.g. `Europe/Berlin`).
  ///
  /// Read during authentication: a stored value wins over the timezone the
  /// client asserts about itself, because the stored one is the user's choice
  /// and the asserted one is only wherever the device happens to be.
  static const String timezone = 'tom.timezone';

  /// The user's preferred language as an ISO 639-1 code (e.g. `de`).
  static const String language = 'tom.language';

  /// The user's preferred country as an ISO 3166-1 alpha-2 code (e.g. `DE`).
  static const String country = 'tom.country';

  /// The user's preferred UI theme name.
  static const String theme = 'tom.theme';
}

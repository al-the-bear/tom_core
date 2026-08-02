/// The framework's well-known preference keys — the vocabulary shared by the
/// server-side store (C-13) and the device-side store (C-14).
///
/// A preference key is a string, and a string that is spelled in two places is
/// a preference that silently splits in two: the client writes `"timezone"`,
/// the server reads `"timeZone"`, and neither side fails — the reader simply
/// finds nothing and falls back, forever. So the keys the framework itself
/// reads live here, once, in the package both halves already depend on.
///
/// Applications are not limited to these. A key is any string; these are only
/// the ones the framework's own code looks up, and they are named so that an
/// application storing the same concept lands on the same key rather than
/// inventing a synonym.
library;

/// The preference keys the framework reads.
///
/// A namespace of constants rather than an enum: preference keys cross the wire
/// and live in a database column, so their *text* is the contract. An enum
/// would hide that text behind a name and make an application's own key a
/// second-class citizen of a different type.
class TomUserPreferenceKeys {
  const TomUserPreferenceKeys._();

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

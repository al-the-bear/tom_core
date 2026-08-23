import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Parses `key=value` command-line arguments and converts string values to
/// their natural Dart types.
///
/// All members are static; the class is a namespace, not a value type. Three
/// entry points share the same value-conversion rules (see [convertToObjectMap]
/// for the exact table):
///
/// - [fillFromArgs] populates a reflected configuration object from `argv`.
/// - [parseArgsToMap] returns the arguments as a loose `Map<String, dynamic>`.
/// - [convertToObjectMap] converts an existing string map (e.g.
///   `Platform.environment`) using the same rules.
///
/// An argument is split on its **first** `=`: the key is the text before it and
/// the value is everything after, so a value may itself contain `=` (a
/// connection string, a URL with a query, a padded base64 blob). This is the
/// rule `TomEnvFile.parse` applies, so the same text means the same thing on
/// the command line and in a `.env` file.
///
/// An argument with no `=` is treated as a flag. Both map-producing paths
/// encode a bare flag identically as the boolean `true` — consistent with how
/// `key=true` is converted (see [convertToObjectMap]) — so a bare flag can fill
/// a reflected `bool` field directly.
///
/// An argument whose key is empty is **skipped**: an empty argument, and one
/// that starts with `=` so that nothing precedes the separator, both name no
/// field and are dropped rather than recorded under an empty key. This too is
/// the rule `TomEnvFile.parse` applies. Skipping is per argument — the
/// arguments around a malformed one are still parsed.
class TomArgs {
  /// Fills [fillIn] from `key=value` [args] using reflection and returns it.
  ///
  /// Each `key=value` argument becomes a field assignment on [fillIn]: the key
  /// is the text before the first `=`, the value is everything after it, and
  /// the value is type-converted (see [convertToObjectMap]).
  /// A bare flag (`--verbose`) is recorded as the boolean `true`, matching how
  /// `key=true` converts, so it fills a reflected `bool` field directly. An
  /// argument with an empty key is skipped and never reaches [fillIn].
  ///
  /// [T] must be a type registered with the reflection system
  /// (`tomReflectionInfo.setValues` performs the assignment); unknown keys that
  /// do not map to a field are ignored by the reflection layer.
  static T fillFromArgs<T extends Object>(List<String> args, T fillIn) {
    tomReflectionInfo.setValues<T>(fillIn, _parseArgs(args));
    return fillIn;
  }

  /// Matches a run of digits. A value is parsed as an `int` only when this
  /// pattern matches the *whole* string, so a leading sign or trailing text
  /// keeps the value a `String` (e.g. `-5` and `12px` stay strings).
  ///
  /// Matching is necessary but not sufficient: the pattern constrains shape,
  /// not magnitude, and a run too long for a 64-bit `int` also stays a
  /// `String`.
  static final RegExp intPattern = RegExp("[0-9]+");

  /// Matches a decimal number (`digits . digits*`). A value is parsed as a
  /// `double` only when this pattern matches the *whole* string and it is not
  /// already an `int`; a leading sign or a missing integer part keeps the value
  /// a `String` (e.g. `-1.5` and `.5` stay strings).
  ///
  /// The fractional part is `*`, zero or more digits — not one optional digit.
  /// So `3.14` converts, and so does a value ending in a bare `.`: `5.` becomes
  /// the `double` `5.0` rather than staying a `String`.
  static final RegExp doublePattern = RegExp("[0-9]+[.][0-9]*");

  /// Parses `key=value` [args] into a loose map, type-converting each value.
  ///
  /// `key=value` becomes `key -> convertedValue`, split on the first `=` (see
  /// [convertToObjectMap] for the conversion table); a bare flag becomes
  /// `flag -> true` (boolean). An argument with an empty key contributes no
  /// entry, so the returned map never carries an empty key.
  static Map<String, dynamic> parseArgsToMap(List<String> args) =>
      _parseArgs(args);

  /// Converts every value in a string [map] to its natural Dart type.
  ///
  /// Useful for normalising an environment map such as `Platform.environment`.
  /// Each value is converted as follows:
  ///
  /// | Input | Result |
  /// | ----- | ------ |
  /// | `"true"` / `null` | `bool` `true` |
  /// | `"false"` | `bool` `false` |
  /// | wrapped in a matched pair of `"` or `'` | the unquoted contents |
  /// | all digits, and it fits a 64-bit `int` | `int` |
  /// | decimal number, `digits . digits*` (`5.` included) | `double` |
  /// | anything else | the original `String` |
  ///
  /// Quotes are only stripped as a **pair** (see [unquote]): an unbalanced
  /// quote is not a quoted value, so a lone `"` and an unterminated `"hello`
  /// are both passed through unchanged rather than truncated.
  ///
  /// The magnitude limit is part of the rule, not an edge case: Dart's `int` is
  /// 64-bit, so a digit run larger than `9223372036854775807` has no `int` to
  /// become and stays a `String` — an account number or a device id arrives as
  /// the text it was written as, rather than aborting the parse.
  static Map<String, dynamic> convertToObjectMap(Map<String, String> map) {
    Map<String, dynamic> result = {};
    for (var key in map.keys) {
      result[key] = _convertString(map[key]);
    }
    return result;
  }

  /// Splits each `key=value` entry of [args] on its **first** `=` and converts
  /// the value, returning the resulting map. An entry with no `=` is a flag and
  /// maps to the boolean `true`.
  ///
  /// The first `=` rather than every `=`, because everything after the
  /// separator is the value and may legitimately contain more of them — a
  /// connection string, a URL with a query, and a padded base64 blob all do.
  /// `TomEnvFile.parse` splits the same way, which is what lets the two sources
  /// be documented as one syntax rather than two that merely resemble each
  /// other.
  ///
  /// An argument whose key is empty (`""`, `"=orphan"`, `"="`) is skipped, as
  /// the same shape is in a `.env` file.
  ///
  /// Both public entry points parse through here, so they cannot disagree.
  static Map<String, dynamic> _parseArgs(List<String> args) {
    var argMap = <String, dynamic>{};
    for (String arg in args) {
      var separator = arg.indexOf("=");
      final key = separator < 0 ? arg : arg.substring(0, separator);
      // An empty key names nothing. On the fillFromArgs path it could never
      // match a field, so it would reach setValues as dead weight; and
      // `TomEnvFile.parse` has always skipped it, so accepting it here would
      // make the same text mean different things in the two sources.
      // Skipped rather than fatal: one malformed argument must not cost the
      // launch line the arguments around it.
      if (key.isEmpty) {
        continue;
      }
      if (separator < 0) {
        argMap[key] = true;
      } else {
        argMap[key] = _convertString(arg.substring(separator + 1));
      }
    }
    return argMap;
  }

  /// Returns the contents of [value] with its surrounding quotes removed, or
  /// `null` if [value] is not a quoted literal.
  ///
  /// A value is quoted only when its quotes form a **pair**: it is at least two
  /// characters long, starts with `"` or `'`, and ends with that same
  /// character. `""` is therefore a quoted literal whose contents are empty,
  /// while a lone `"`, an unterminated `"hello`, and a mismatched `"hello'` are
  /// not quoted at all and yield `null` so the caller can use them verbatim.
  ///
  /// Requiring the pair is what keeps a stray quote harmless. Dropping the
  /// first and last character on the strength of the opening quote alone
  /// truncates an unterminated value (`"hello` → `hello` minus its last
  /// character), and on a one-character value it asks for `substring(1, 0)` —
  /// a `RangeError` that names neither the key nor the file it came from.
  ///
  /// Both this class and `TomEnvFile.parse` decide through here, so the two
  /// sources cannot disagree about what counts as quoted.
  static String? unquote(String value) {
    if (value.length < 2) {
      return null;
    }
    final quote = value[0];
    if (quote != '"' && quote != "'") {
      return null;
    }
    if (!value.endsWith(quote)) {
      return null;
    }
    return value.substring(1, value.length - 1);
  }

  /// Converts a single string [value] to its natural Dart type. See
  /// [convertToObjectMap] for the conversion table.
  static Object _convertString(String? value) {
    if (value == "true" || value == null) {
      return true;
    }
    if (value == "false") {
      return false;
    }
    final unquoted = unquote(value);
    if (unquoted != null) {
      return unquoted;
    }
    if (intPattern.stringMatch(value) == value) {
      // tryParse, not parse: the pattern says "all digits", which is a claim
      // about shape and not about magnitude. Dart's int is 64-bit, so a longer
      // run has no int to become and tryParse returns null — the value then
      // falls through to the String at the end, exactly as `-5` and `12px` do.
      // parse would instead throw a FormatException naming neither the key nor
      // the source, aborting the whole parse over one account number.
      final asInt = int.tryParse(value);
      if (asInt != null) {
        return asInt;
      }
    }
    if (doublePattern.stringMatch(value) == value) {
      return double.parse(value);
    }
    return value;
  }
}

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
class TomArgs {
  /// Fills [fillIn] from `key=value` [args] using reflection and returns it.
  ///
  /// Each `key=value` argument becomes a field assignment on [fillIn]: the key
  /// is the text before the first `=`, the value is everything after it, and
  /// the value is type-converted (see [convertToObjectMap]).
  /// A bare flag (`--verbose`) is recorded as the boolean `true`, matching how
  /// `key=true` converts, so it fills a reflected `bool` field directly.
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
  static final RegExp intPattern = RegExp("[0-9]+");

  /// Matches a decimal number (`digits . digits?`). A value is parsed as a
  /// `double` only when this pattern matches the *whole* string and it is not
  /// already an `int`; a leading sign or a missing integer part keeps the value
  /// a `String` (e.g. `-1.5` and `.5` stay strings).
  static final RegExp doublePattern = RegExp("[0-9]+[.][0-9]*");

  /// Parses `key=value` [args] into a loose map, type-converting each value.
  ///
  /// `key=value` becomes `key -> convertedValue`, split on the first `=` (see
  /// [convertToObjectMap] for the conversion table); a bare flag becomes
  /// `flag -> true` (boolean).
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
  /// | starts with `"` or `'` | the unquoted contents (first/last char dropped) |
  /// | all digits | `int` |
  /// | decimal number | `double` |
  /// | anything else | the original `String` |
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
  /// Both public entry points parse through here, so they cannot disagree.
  static Map<String, dynamic> _parseArgs(List<String> args) {
    var argMap = <String, dynamic>{};
    for (String arg in args) {
      var separator = arg.indexOf("=");
      if (separator < 0) {
        argMap[arg] = true;
      } else {
        argMap[arg.substring(0, separator)] = _convertString(
          arg.substring(separator + 1),
        );
      }
    }
    return argMap;
  }

  /// Converts a single string [value] to its natural Dart type. See
  /// [convertToObjectMap] for the conversion table.
  static Object _convertString(String? value) {
    if (value == "true" || value == null) {
      return true;
    } else if (value == "false") {
      return false;
    } else if (value.startsWith('"') || value.startsWith("'")) {
      return value.substring(1, value.length - 1);
    } else if (intPattern.stringMatch(value) == value) {
      return int.parse(value);
    } else if (doublePattern.stringMatch(value) == value) {
      return double.parse(value);
    } else {
      return value;
    }
  }
}

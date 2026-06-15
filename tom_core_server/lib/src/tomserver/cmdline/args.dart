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
/// An argument with no `=` is treated as a flag. Note the two map-producing
/// paths differ in how they encode a bare flag: [parseArgsToMap] stores the
/// boolean `true`, whereas [fillFromArgs] stores the string `"true"` (the
/// reflection layer coerces it to the target field's type on assignment).
class TomArgs {
  /// Fills [fillIn] from `key=value` [args] using reflection and returns it.
  ///
  /// Each `key=value` argument becomes a field assignment on [fillIn]: the key
  /// names the field and the value is type-converted (see [convertToObjectMap]).
  /// A bare flag (`--verbose`) is recorded as the string `"true"`, which the
  /// reflection layer coerces to the field's declared type.
  ///
  /// [T] must be a type registered with the reflection system
  /// (`tomReflectionInfo.setValues` performs the assignment); unknown keys that
  /// do not map to a field are ignored by the reflection layer.
  static T fillFromArgs<T extends Object>(List<String> args, T fillIn) {
    var argMap = <String, Object>{};
    for (String arg in args) {
      var parts = arg.split("=");
      if (parts.length > 1) {
        argMap[parts[0]] = _convertString(parts[1]);
      } else {
        argMap[arg] = "true";
      }
    }
    tomReflectionInfo.setValues<T>(fillIn, argMap);
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
  /// `key=value` becomes `key -> convertedValue` (see [convertToObjectMap] for
  /// the conversion table); a bare flag becomes `flag -> true` (boolean).
  static Map<String, dynamic> parseArgsToMap(List<String> args) {
    var argMap = <String, dynamic>{};
    for (String arg in args) {
      var parts = arg.split("=");
      if (parts.length > 1) {
        argMap[parts[0]] = _convertString(parts[1]);
      } else {
        argMap[arg] = true;
      }
    }
    return argMap;
  }

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

import 'package:tom_core_kernel/tom_core_kernel.dart';

class TomArgs {
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

  static final RegExp intPattern = RegExp("[0-9]+");
  static final RegExp doublePattern = RegExp("[0-9]+[.][0-9]*");

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

  static Map<String, dynamic> convertToObjectMap(Map<String, String> map) {
    Map<String, dynamic> result = {};
    for (var key in map.keys) {
      result[key] = _convertString(map[key]);
    }
    return result;
  }

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

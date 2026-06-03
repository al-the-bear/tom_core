import 'package:yaml/yaml.dart';

/// Builds the domain-specific exception a [YamlConfigReader] throws when
/// a typed access or `${ENV}` expansion fails.
///
/// Every loader supplies its own factory so error *types* stay
/// domain-specific (e.g. `SubstrateConfigException`,
/// `MemoryConfigException`) while the parsing and substitution logic is
/// shared. The factory receives the fully-formed, engineer-readable
/// message and wraps it in the loader's exception class.
typedef YamlConfigErrorFactory = Object Function(String message);

/// Type-safe accessors over a parsed `package:yaml` document, plus an
/// explicit `${NAME}` environment-variable expander.
///
/// This is the consolidation of the field-helper blocks that several
/// brain loaders grew independently (`SubstrateConfigLoader`,
/// `MemoryConfigLoader`). They were behaviourally identical line-for-line
/// apart from the exception class they raised; the [errorFactory] seam
/// preserves that one intended difference and removes the duplication.
///
/// Construction is per parse: a loader builds one reader with the env
/// map for that call and its own error factory, then routes every typed
/// read through it:
///
/// ```dart
/// final reader = YamlConfigReader(
///   env: env,
///   errorFactory: SubstrateConfigException.new,
/// );
/// final id = reader.requireString(node, 'id', 'substrate.providers[0].id');
/// final url = reader.expandEnv(rawUrl, 'substrate.providers[0].baseUrl');
/// ```
///
/// **Path argument.** Every accessor takes a `path` — the dotted
/// location of the value in the document (e.g. `substrate.embedding.dims`).
/// It appears verbatim in error messages so a failure points the reader
/// straight at the offending line. [optionalMap] is the one exception:
/// it reports by `key` rather than `path`, matching the original
/// loaders' message shape.
final class YamlConfigReader {
  /// Environment used by [expandEnv] to resolve `${NAME}` tokens.
  final Map<String, String> env;

  /// Wraps a message in the loader's domain exception type.
  final YamlConfigErrorFactory errorFactory;

  const YamlConfigReader({
    required this.env,
    required this.errorFactory,
  });

  Never _fail(String message) => throw errorFactory(message);

  // ---------------------------------------------------------------
  // Typed field accessors.
  // ---------------------------------------------------------------

  /// Returns the string at [key]; throws if missing or non-string.
  String requireString(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) {
      _fail('Missing required field: $path');
    }
    if (v is! String) {
      _fail('$path must be a string (got ${v.runtimeType}).');
    }
    return v;
  }

  /// Returns the string at [key], or `null` when absent; throws if
  /// present but non-string.
  String? optionalString(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) return null;
    if (v is! String) {
      _fail('$path must be a string (got ${v.runtimeType}).');
    }
    return v;
  }

  /// Returns the int at [key]; throws if missing or non-int.
  int requireInt(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) {
      _fail('Missing required field: $path');
    }
    if (v is! int) {
      _fail('$path must be an integer (got ${v.runtimeType}).');
    }
    return v;
  }

  /// Returns the int at [key], or `null` when absent; throws if present
  /// but non-int.
  int? optionalInt(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) return null;
    if (v is! int) {
      _fail('$path must be an integer (got ${v.runtimeType}).');
    }
    return v;
  }

  /// Returns the number at [key] as a double; throws if missing or
  /// non-numeric.
  double requireDouble(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) {
      _fail('Missing required field: $path');
    }
    if (v is num) return v.toDouble();
    _fail('$path must be a number (got ${v.runtimeType}).');
  }

  /// Returns the number at [key] as a double, or `null` when absent;
  /// throws if present but non-numeric.
  double? optionalDouble(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    _fail('$path must be a number (got ${v.runtimeType}).');
  }

  /// Returns the bool at [key], or `null` when absent; throws if present
  /// but non-bool.
  bool? optionalBool(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) return null;
    if (v is! bool) {
      _fail('$path must be a boolean (got ${v.runtimeType}).');
    }
    return v;
  }

  /// Returns the map at [key]; throws if missing or non-map.
  YamlMap requireMap(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) {
      _fail('Missing required field: $path');
    }
    if (v is! YamlMap) {
      _fail('$path must be a map (got ${v.runtimeType}).');
    }
    return v;
  }

  /// Returns the map at [key], or `null` when absent; throws if present
  /// but non-map.
  ///
  /// Reports by [key] rather than a dotted path, matching the original
  /// loader message (`Field \`webSearch\` must be a map …`).
  YamlMap? optionalMap(YamlMap node, String key) {
    final v = node[key];
    if (v == null) return null;
    if (v is! YamlMap) {
      _fail('Field `$key` must be a map (got ${v.runtimeType}).');
    }
    return v;
  }

  /// Returns the list at [key]; throws if missing or non-list.
  YamlList requireList(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) {
      _fail('Missing required field: $path');
    }
    if (v is! YamlList) {
      _fail('$path must be a list (got ${v.runtimeType}).');
    }
    return v;
  }

  /// Returns the list at [key], or `null` when absent; throws if present
  /// but non-list.
  YamlList? optionalList(YamlMap node, String key, String path) {
    final v = node[key];
    if (v == null) return null;
    if (v is! YamlList) {
      _fail('$path must be a list (got ${v.runtimeType}).');
    }
    return v;
  }

  /// Parses [raw] as a [Uri]; throws if it is not a valid URI.
  Uri parseUri(String raw, String path) {
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      _fail('$path must be a valid URI (got "$raw").');
    }
    return uri;
  }

  // ---------------------------------------------------------------
  // `${NAME}` substitution.
  //
  // Deliberately a hand-written scanner rather than a regex: the input
  // is small and an explicit scan yields precise, located error
  // messages (unterminated token, empty token, undefined var).
  // ---------------------------------------------------------------

  /// Expands every `${NAME}` token in [input] against [env].
  ///
  /// Returns [input] unchanged when it contains no `$`. Throws when a
  /// token is unterminated, empty, or names an undefined variable —
  /// each with [path] in the message.
  String expandEnv(String input, String path) {
    if (!input.contains(r'$')) return input;
    final out = StringBuffer();
    var i = 0;
    while (i < input.length) {
      final ch = input[i];
      if (ch == r'$' && i + 1 < input.length && input[i + 1] == '{') {
        final close = input.indexOf('}', i + 2);
        if (close < 0) {
          _fail('$path has unterminated `\${` token.');
        }
        final name = input.substring(i + 2, close);
        if (name.isEmpty) {
          _fail('$path has empty `\${}` token.');
        }
        final value = env[name];
        if (value == null) {
          _fail('$path references undefined env var `\${$name}`.');
        }
        out.write(value);
        i = close + 1;
      } else {
        out.write(ch);
        i++;
      }
    }
    return out.toString();
  }
}

import 'dart:io';

import 'args.dart';

/// Reads environment variables from a `.env` file.
///
/// The `.env` file format supports:
/// - Key-value pairs: `KEY=value`
/// - Comments: Lines starting with `#`
/// - Empty lines (ignored)
/// - Quoted values: `KEY="value with spaces"` or `KEY='value'`
/// - Inline comments: `KEY=value # comment` (only if not inside quotes)
///
/// Example `.env` file:
/// ```
/// # Database configuration
/// DB_HOST=localhost
/// DB_PORT=5432
/// DB_NAME="my_database"
///
/// # Server settings
/// SERVER_PORT=8080
/// DEBUG=true
/// ```
class TomEnvFile {
  /// Reads environment variables from a `.env` file in the current directory.
  ///
  /// Returns a [Map<String, Object?>] where values are automatically converted
  /// to appropriate types (int, double, bool, or String).
  ///
  /// If the file doesn't exist, returns an empty map.
  ///
  /// Optionally specify a custom [path] to read from a different location.
  static Map<String, Object?> read([String path = '.env']) {
    final file = File(path);
    if (!file.existsSync()) {
      return {};
    }

    final lines = file.readAsLinesSync();
    return parse(lines);
  }

  /// Reads environment variables from a `.env` file asynchronously.
  ///
  /// Returns a [Map<String, Object?>] where values are automatically converted
  /// to appropriate types (int, double, bool, or String).
  ///
  /// If the file doesn't exist, returns an empty map.
  ///
  /// Optionally specify a custom [path] to read from a different location.
  static Future<Map<String, Object?>> readAsync([String path = '.env']) async {
    final file = File(path);
    if (!await file.exists()) {
      return {};
    }

    final content = await file.readAsString();
    final lines = content.split('\n');
    return parse(lines);
  }

  /// Parses a list of lines from an `.env` file format into a map.
  ///
  /// This can be used to parse `.env` content from any source,
  /// not just files.
  static Map<String, Object?> parse(List<String> lines) {
    final result = <String, Object?>{};

    for (var line in lines) {
      line = line.trim();

      // Skip empty lines and comments
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      // Find the first '=' to split key and value
      final equalsIndex = line.indexOf('=');
      if (equalsIndex == -1) {
        continue;
      }

      final key = line.substring(0, equalsIndex).trim();
      if (key.isEmpty) {
        continue;
      }

      var value = line.substring(equalsIndex + 1).trim();

      // Handle quoted values. TomArgs.unquote owns the rule — quotes count
      // only as a matched pair — so the two sources cannot disagree about what
      // is quoted, and a stray quote is not mistaken for one.
      final unquoted = TomArgs.unquote(value);
      if (unquoted != null) {
        // Remove quotes and use as string (don't convert to other types)
        result[key] = unquoted;
        continue;
      }

      // Handle inline comments (only if not quoted)
      final commentIndex = value.indexOf('#');
      if (commentIndex != -1) {
        value = value.substring(0, commentIndex).trim();
      }

      // Convert value to appropriate type
      result[key] = _convertValue(value);
    }

    return result;
  }

  /// Converts a string value to the appropriate type.
  ///
  /// Converts to:
  /// - `bool` for "true" or "false"
  /// - `int` for integer strings
  /// - `double` for decimal strings
  /// - `null` for empty strings
  /// - `String` otherwise
  static Object? _convertValue(String value) {
    if (value.isEmpty) {
      return null;
    }

    // Use TomArgs conversion for consistent behavior
    return TomArgs.convertToObjectMap({'_': value})['_'];
  }

  /// Merges environment variables from multiple sources.
  ///
  /// Later sources override earlier ones. This is useful for
  /// having a base `.env` file and an environment-specific override.
  ///
  /// Example:
  /// ```dart
  /// final env = TomEnvFile.merge([
  ///   TomEnvFile.read('.env'),
  ///   TomEnvFile.read('.env.local'),
  ///   TomEnvFile.read('.env.${Platform.environment['ENV'] ?? 'dev'}'),
  /// ]);
  /// ```
  ///
  /// **Values are merged as they arrive; nothing is converted here.** [read],
  /// [parse] and `TomArgs.parseArgsToMap` all convert on the way out, so a
  /// stack built from those is typed. A raw `Map<String, String>` is not —
  /// and Dart's covariance lets one pass as a `Map<String, Object?>` without
  /// complaint, so `Platform.environment` merges silently and contributes
  /// every value as a `String`. Wrap it in `TomArgs.convertToObjectMap` first,
  /// or an `int` or `bool` field will be refused by the reflector when the
  /// result reaches `setValues`.
  static Map<String, Object?> merge(List<Map<String, Object?>> sources) {
    final result = <String, Object?>{};
    for (final source in sources) {
      result.addAll(source);
    }
    return result;
  }

  /// Loads environment variables from a `.env` file and adds them
  /// to the process environment.
  ///
  /// Note: This only affects Dart code that reads from [Platform.environment]
  /// after this call. It does not modify the actual OS environment.
  ///
  /// Returns the loaded environment variables.
  static Map<String, Object?> load([String path = '.env']) {
    final env = read(path);
    // Note: Platform.environment is read-only, so we can't actually
    // add to it. This method returns the loaded values for manual use.
    return env;
  }

  /// The effective environment for `${VAR}` expansion: [processEnvironment]
  /// (the OS environment by default) with the `.env` file at [path] layered
  /// **on top**.
  ///
  /// This is the map `TomYaml.loadYamlFile`'s `environment` parameter wants.
  /// Without it a `.env` reaches a server's *configuration keys* — because
  /// `TomBaseServerConfiguration.getDefaultValues` merges [read] — but not the
  /// `${VAR:default}` placeholders in its datasource and resource YAML, which
  /// expand from the OS environment alone. A boot that resolves this once and
  /// passes it down closes that gap.
  ///
  /// **The `.env` file wins over the process environment**, because that is the
  /// order `getDefaultValues` already applies to the same two sources (config
  /// resources, then OS environment, then `.env`, then CLI args). One file, one
  /// rule: a variable behaves the same whether it is read as a config key or
  /// expanded into a placeholder. Note this inverts Docker Compose's own
  /// precedence, where the shell wins over `.env` — so a `.env` shared with a
  /// compose file resolves differently on the two sides for a key that is
  /// *also* exported in the shell. Export nothing you also write in `.env`, and
  /// the question does not arise.
  ///
  /// Values are stringified because that is what `substituteEnvVars` takes, and
  /// nothing is lost by it: substitution writes its expansion back into the
  /// tree as text, so a substituted value is a `String` whatever [read] typed
  /// it as. A key whose `.env` value is empty — [read] maps that to `null` —
  /// is dropped rather than contributed as `''`; `substituteEnvVars` treats an
  /// empty value as unset, so the two resolve identically, and dropping keeps
  /// the map free of entries that mean nothing.
  ///
  /// A missing file contributes nothing ([read] returns `{}`), so the result is
  /// then [processEnvironment] unchanged.
  static Map<String, String> resolveEnvironment({
    String path = '.env',
    Map<String, String>? processEnvironment,
  }) {
    final result = <String, String>{
      ...processEnvironment ?? Platform.environment,
    };
    for (final entry in read(path).entries) {
      final value = entry.value;
      if (value == null) continue;
      result[entry.key] = '$value';
    }
    return result;
  }
}

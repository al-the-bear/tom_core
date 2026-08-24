import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:yaml/yaml.dart';

/// Utility class for loading and processing YAML configuration files.
///
/// Provides methods to load YAML files with automatic environment variable
/// substitution using the `${VAR_NAME}` or `${VAR_NAME:default}` syntax.
///
/// Substitution runs *after* the YAML parser has assigned types and writes its
/// expansion back into the tree as text, so a substituted value is always a
/// `String`: `port: 3306` yields the `int` `3306`, `port: ${DB_PORT:3306}` the
/// `String` `'3306'` — even when `DB_PORT` is unset and the default supplies
/// the same digits. `TomConfig` casts rather than parses, so read a substituted
/// number with `TomStringConfig` and parse it.
class TomYaml {
  /// Loads a YAML file and returns it as a Map, substituting environment
  /// variables.
  ///
  /// This is the class's only loader; [mergeInYamlFile] is one line over it.
  /// Values are expanded from [Platform.environment] and support placeholders
  /// like `${VAR_NAME}` or `${VAR_NAME:default}`.
  ///
  /// ## Example YAML with placeholders
  /// ```yaml
  /// database:
  ///   host: ${DB_HOST:localhost}
  ///   port: ${DB_PORT:3306}
  ///   user: ${DB_USER}
  /// ```
  ///
  /// Throws a [PathNotFoundException] if [filename] does not exist. Note the
  /// contrast with the sibling loader in the same configuration pipeline:
  /// `TomEnvFile.read` returns an empty map for an absent file, where this one
  /// throws. For an optional overlay, guard with `File(filename).existsSync()`
  /// or catch [PathNotFoundException] specifically — a bare `catch` would
  /// also swallow a syntax error in a file that *is* there and report it as
  /// absent.
  static Map<String, Object?> loadYamlFile(String filename) {
    var yamlText = File(filename).readAsStringSync();
    var yamlData = loadYaml(yamlText);
    var cleanMap = makeCleanJsonMap(yamlData);
    substituteEnvVars(cleanMap, Platform.environment);
    return cleanMap;
  }

  /// Loads a YAML file with [loadYamlFile] and merges it into [result].
  ///
  /// The load *is* [loadYamlFile] — same normalisation, same substitution,
  /// same [PathNotFoundException] for an absent [filename]. See there for the
  /// placeholder syntax and for what to do about an optional overlay.
  ///
  /// The merge is one-sided: keys from [filename] overwrite those already in
  /// [result], and keys only in [result] survive. Because the load is an
  /// argument to the merge it completes first, so a throw leaves [result]
  /// untouched — an overlay never half-applies.
  static void mergeInYamlFile(Map<String, Object?> result, String filename) {
    mergeMapsOneSided(result, loadYamlFile(filename));
  }
}

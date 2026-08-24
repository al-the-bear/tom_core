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
  /// Loads a YAML file and merges it into [result] with environment variable substitution.
  ///
  /// Environment variables in the YAML values are expanded using [Platform.environment].
  ///
  /// Throws a [PathNotFoundException] if [filename] does not exist — the
  /// file is required, not optional. For an optional overlay, guard with
  /// `File(filename).existsSync()` or catch [PathNotFoundException]
  /// specifically; a bare `catch` would also swallow a syntax error in a file
  /// that *is* there and report it as absent. The read happens before the
  /// merge, so a throw leaves [result] untouched.
  static void mergeInYamlFile(Map<String, Object?> result, String filename) {
    var yamlText = File(filename).readAsStringSync();
    var yamlData = loadYaml(yamlText);
    var cleanMap = makeCleanJsonMap(yamlData);
    substituteEnvVars(cleanMap, Platform.environment);
    mergeMapsOneSided(result, cleanMap);
  }

  /// Loads a YAML file and returns it as a Map with environment variable substitution.
  ///
  /// Environment variables in the YAML values are expanded using [Platform.environment].
  /// Supports placeholders like `${VAR_NAME}` or `${VAR_NAME:default}`.
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
}

import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:yaml/yaml.dart';

/// Utility class for loading and processing YAML configuration files.
///
/// Provides methods to load YAML files with automatic environment variable
/// substitution using the `${VAR_NAME}` or `${VAR_NAME:default}` syntax.
class TomYaml {
  /// Loads a YAML file and merges it into [result] with environment variable substitution.
  ///
  /// Environment variables in the YAML values are expanded using [Platform.environment].
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
  static Map<String, Object?> loadYamlFile(String filename) {
    var yamlText = File(filename).readAsStringSync();
    var yamlData = loadYaml(yamlText);
    var cleanMap = makeCleanJsonMap(yamlData);
    substituteEnvVars(cleanMap, Platform.environment);
    return cleanMap;
  }
}

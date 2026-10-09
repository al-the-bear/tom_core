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
/// the same digits. The map keeps the text; a typed `TomConfig` reads it as its
/// type, so `TomIntConfig` resolves both forms to `3306`.
class TomYaml {
  /// Loads a YAML file and returns it as a Map, substituting environment
  /// variables.
  ///
  /// This is the class's only loader; [mergeInYamlFile] is one line over it.
  /// Values are expanded from [environment] — [Platform.environment] when it is
  /// omitted — and support placeholders like `${VAR_NAME}` or
  /// `${VAR_NAME:default}`.
  ///
  /// Pass [environment] when the process environment is not the whole story.
  /// The case this exists for is a `.env` file: `TomEnvFile.resolveEnvironment`
  /// returns the OS environment with `./.env` layered on top, in the same order
  /// `TomBaseServerConfiguration.getDefaultValues` uses, so a boot that resolves
  /// it once and passes it here expands its YAML from the same variables its
  /// configuration keys came from. Left to the default, a `.env` reaches the
  /// configuration and *not* the placeholders — the datasource keeps the
  /// `${VAR:default}` defaults while everything else follows the file.
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
  /// throws. For an overlay that may legitimately be absent use
  /// [loadYamlFileIfPresent], which tolerates that one condition and nothing
  /// else.
  static Map<String, Object?> loadYamlFile(
    String filename, {
    Map<String, String>? environment,
  }) {
    var yamlText = File(filename).readAsStringSync();
    var yamlData = loadYaml(yamlText);
    var cleanMap = makeCleanJsonMap(yamlData);
    substituteEnvVars(cleanMap, environment ?? Platform.environment);
    return cleanMap;
  }

  /// Loads a YAML file with [loadYamlFile] and merges it into [result].
  ///
  /// The load *is* [loadYamlFile] — same normalisation, same substitution from
  /// [environment], same [PathNotFoundException] for an absent [filename]. See
  /// there for the placeholder syntax and for what [environment] is for; for an
  /// overlay that may legitimately be absent, see [mergeInYamlFileIfPresent].
  ///
  /// The merge is one-sided: keys from [filename] overwrite those already in
  /// [result], and keys only in [result] survive. Because the load is an
  /// argument to the merge it completes first, so a throw leaves [result]
  /// untouched — an overlay never half-applies.
  ///
  /// It **recurses into subtrees**, so the overwrite is per leaf rather than
  /// per branch: a file naming `db.host` alone replaces that key and leaves the
  /// `db` branch's other keys standing. That is what lets a per-environment
  /// file state only its differences instead of restating every sibling
  /// setting to avoid losing it.
  static void mergeInYamlFile(
    Map<String, Object?> result,
    String filename, {
    Map<String, String>? environment,
  }) {
    mergeMapsOneSided(result, loadYamlFile(filename, environment: environment));
  }

  /// Loads [filename] with [loadYamlFile], or returns `null` when there is no
  /// such file.
  ///
  /// The tolerant half of the pair. Everything [loadYamlFile] does it does —
  /// normalisation, substitution from [environment] — and the *only* condition
  /// it forgives is that the file is not there. A file that exists and does not
  /// parse still throws, which is the whole point: a bare `catch` around
  /// [loadYamlFile] reports a YAML syntax error as an absent overlay, so a
  /// mistyped file goes on being skipped and the settings in it silently never
  /// apply.
  ///
  /// `null` rather than an empty map, so a caller can tell an absent overlay
  /// from an empty one. An overlay that never applied is exactly what an
  /// operator hunting a setting that had no effect needs to be told, and a
  /// method that returns `{}` for both cannot tell them.
  ///
  /// This is the shape the layered-overlay pattern needs: a per-environment or
  /// per-locale file of which only one of the candidates is ever present is the
  /// normal case, not the error case.
  static Map<String, Object?>? loadYamlFileIfPresent(
    String filename, {
    Map<String, String>? environment,
  }) {
    try {
      return loadYamlFile(filename, environment: environment);
    } on PathNotFoundException {
      // Caught rather than pre-empted with `existsSync`, which asks the
      // question a moment before the answer is used and can be overtaken
      // between the two. This asks it by attempting the read.
      return null;
    }
  }

  /// Merges [filename] into [result] with [mergeInYamlFile] if there is such a
  /// file, and reports whether there was.
  ///
  /// The tolerant half of the merging pair, over [loadYamlFileIfPresent]: an
  /// absent [filename] leaves [result] untouched and returns `false`, and every
  /// other failure — a syntax error above all — still throws. See
  /// [mergeInYamlFile] for what the merge does, and [loadYamlFileIfPresent] for
  /// why absence is the only forgiven condition.
  ///
  /// The `bool` is the overlay's own answer to "did you apply?". A boot that
  /// asks every environment in a hierarchy for an overlay can say which ones it
  /// found, instead of leaving a reader to infer it from the settings that took
  /// effect.
  static bool mergeInYamlFileIfPresent(
    Map<String, Object?> result,
    String filename, {
    Map<String, String>? environment,
  }) {
    final overlay = loadYamlFileIfPresent(filename, environment: environment);
    if (overlay == null) return false;
    mergeMapsOneSided(result, overlay);
    return true;
  }
}

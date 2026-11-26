/// A package's texts in a test: its resource file loaded, mounted under a
/// scope, installed as the application's text resources, and a body run in
/// that scope, as an application mounts the package.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A resource file that cannot be used: missing, not JSON, or not shaped as
/// the guideline says.
class TextResourceFileException implements Exception {
  TextResourceFileException(this.file, this.message);

  /// The file.
  final String file;

  /// What is wrong.
  final String message;

  @override
  String toString() => 'TextResourceFileException: $file: $message';
}

/// Two text maps that both hold a text at the same path, or a text where the
/// other holds a map: the second would overwrite the first.
class TextMergeConflict implements Exception {
  TextMergeConflict(this.path);

  /// The dotted path both maps hold.
  final String path;

  @override
  String toString() =>
      'TextMergeConflict: both text maps hold "$path"; one would overwrite '
      'the other';
}

/// The path of a package's resource file for [language], relative to the
/// package root: `lib/resources/<package-name>_<language>.json`.
String textResourcePath(String packageName, [String language = 'en']) =>
    'lib/resources/${packageName}_$language.json';

/// A package's texts in one language: the block its resource file holds
/// under the package name.
class PackageTexts {
  PackageTexts(this.packageName, this.block, {this.language = 'en'});

  /// Loads `lib/resources/<packageName>_<language>.json` under
  /// [packageRoot] (default: the current directory, which is the package
  /// root when its tests run).
  ///
  /// Throws a [TextResourceFileException] when the file is missing, is not
  /// a JSON object, or holds anything but the package name at its top level.
  factory PackageTexts.load(
    String packageName, {
    String language = 'en',
    String packageRoot = '.',
  }) {
    final path = '$packageRoot/${textResourcePath(packageName, language)}';
    final file = File(path);
    if (!file.existsSync()) {
      throw TextResourceFileException(path, 'no such file');
    }
    final Object? json;
    try {
      json = jsonDecode(file.readAsStringSync());
    } on FormatException catch (error) {
      throw TextResourceFileException(path, 'not JSON: ${error.message}');
    }
    if (json is! Map<String, dynamic>) {
      throw TextResourceFileException(path, 'not a JSON object');
    }
    final extra = json.keys.where((key) => key != packageName).toList();
    if (extra.isNotEmpty || json[packageName] is! Map<String, dynamic>) {
      throw TextResourceFileException(
        path,
        'the top level must be the one key "$packageName" holding an '
        'object${extra.isEmpty ? '' : ' (found ${extra.join(', ')})'}',
      );
    }
    return PackageTexts(
      packageName,
      json[packageName] as Map<String, dynamic>,
      language: language,
    );
  }

  /// The package's name: the top level of its file and its default scope.
  final String packageName;

  /// The texts under the package name.
  final Map<String, dynamic> block;

  /// The language of the texts.
  final String language;

  /// The texts as an application's assembled file holds them when it mounts
  /// the package under [scopePath] (default: the package name): [block]
  /// nested under the scope's segments, `a.b` one level deeper than `a`.
  Map<String, dynamic> mountedAt([String? scopePath]) =>
      mountTexts(block, scopePath ?? packageName);

  /// Installs the texts mounted under [scopePath] (default: the package
  /// name) as the application's text resources.
  void install([String? scopePath]) => installTexts(mountedAt(scopePath));

  /// Installs the texts mounted under every scope of [scopePaths] at once,
  /// as an application that mounts the package more than once.
  void installAt(Iterable<String> scopePaths) => installTexts(
    mergeTexts([for (final path in scopePaths) mountedAt(path)]),
  );

  /// Runs [body] in the scope [scopePath] (default: the package name), so a
  /// component constructed there resolves its ids as an application
  /// mounting the package there.
  T run<T>(T Function() body, [String? scopePath]) =>
      runInScopePath(scopePath ?? packageName, body);
}

/// [block] under the segments of [scopePath]: `mountTexts(b, 'a.b')` is
/// `{'a': {'b': b}}`. An empty path answers [block] itself.
Map<String, dynamic> mountTexts(Map<String, dynamic> block, String scopePath) {
  Map<String, dynamic> node = block;
  if (scopePath.isEmpty) return node;
  for (final id in scopePath.split('.').reversed) {
    node = <String, dynamic>{id: node};
  }
  return node;
}

/// The text maps of [maps] merged into one, deeply.
///
/// Throws a [TextMergeConflict] when two of them hold a text at the same
/// path, or one a text where another holds a map.
Map<String, dynamic> mergeTexts(Iterable<Map<String, dynamic>> maps) {
  final out = <String, dynamic>{};
  for (final map in maps) {
    _mergeInto(out, map, '');
  }
  return out;
}

void _mergeInto(
  Map<String, dynamic> into,
  Map<String, dynamic> from,
  String path,
) {
  for (final entry in from.entries) {
    final at = path.isEmpty ? entry.key : '$path.${entry.key}';
    final existing = into[entry.key];
    final value = entry.value;
    if (existing == null) {
      into[entry.key] = value is Map<String, dynamic> ? _copy(value) : value;
    } else if (existing is Map<String, dynamic> &&
        value is Map<String, dynamic>) {
      _mergeInto(existing, value, at);
    } else {
      throw TextMergeConflict(at);
    }
  }
}

Map<String, dynamic> _copy(Map<String, dynamic> map) => {
  for (final entry in map.entries)
    entry.key: entry.value is Map<String, dynamic>
        ? _copy(entry.value as Map<String, dynamic>)
        : entry.value,
};

/// Installs [texts] as the application's text resources
/// (`TomTextResourceProvider.setAppResourceProvider`).
void installTexts(Map<String, dynamic> texts) =>
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(texts),
    );

/// Removes the application's text resources again
/// (`TomTextResourceProvider.clearAppResourceProvider`); call it in
/// `tearDown`.
void clearTexts() =>
    // This package is test support: its callers are tests.
    // ignore: invalid_use_of_visible_for_testing_member
    TomTextResourceProvider.clearAppResourceProvider();

/// Runs [body] in the scopes of [scopePath], outermost first
/// (`TomScope.withScope` per segment); an empty path runs it as it is.
T runInScopePath<T>(String scopePath, T Function() body) {
  if (scopePath.isEmpty) return body();
  final ids = scopePath.split('.');
  T run(int i) =>
      i == ids.length ? body() : TomScope.withScope(ids[i], () => run(i + 1));
  return run(0);
}

/// Loads [packageName]'s texts, installs them mounted under [scopePath]
/// (default: the package name), runs [body] in that scope and clears the
/// texts afterwards: when [body] has returned, or, when it returns a
/// `Future`, when that future completes.
T withPackageTexts<T>(
  String packageName,
  T Function() body, {
  String? scopePath,
  String language = 'en',
  String packageRoot = '.',
}) {
  final texts = PackageTexts.load(
    packageName,
    language: language,
    packageRoot: packageRoot,
  )..install(scopePath);
  final T result;
  try {
    result = texts.run(body, scopePath);
  } catch (_) {
    clearTexts();
    rethrow;
  }
  if (result is Future) {
    return result.whenComplete(clearTexts) as T;
  }
  clearTexts();
  return result;
}

import 'dart:convert';
import 'dart:io';

import 'client_configuration_store.dart';

/// A [TomClientConfigurationStore] backed by a JSON file on the local
/// filesystem — the native (`dart:io`) variant.
///
/// Reach for it through `file_configuration_store.dart`, which selects this
/// implementation on desktop and mobile and a loudly-failing one elsewhere.
///
/// The file is the *override* map, JSON-encoded: a flat object whose keys are
/// the dotted configuration keys. It is written whole, never appended to, and
/// **deleted** when the override map becomes empty — an install that resets
/// everything should leave no file behind, and "no file" and "empty object"
/// must not be two ways to say the same thing.
class TomFileClientConfigurationStore extends TomClientConfigurationStore {
  /// Creates a store over the file at [path].
  ///
  /// The path is the caller's choice because only the app knows where its
  /// machine-local state belongs (`path_provider`'s application-support
  /// directory on a Flutter client, a temp directory in a test). Missing
  /// parent directories are created on the first [write].
  const TomFileClientConfigurationStore(this.path);

  /// Absolute path of the JSON file holding the override map.
  final String path;

  @override
  Future<Map<String, Object?>> read() async {
    final file = File(path);
    if (!await file.exists()) return {};
    final content = await file.readAsString();
    // A zero-length file is the one "unreadable" case that is not corruption:
    // a crash between create and write leaves it, and treating it as empty
    // loses nothing that was ever committed.
    if (content.trim().isEmpty) return {};

    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (exception, stack) {
      throw TomClientConfigurationException(
        'client_configuration.store.invalid_content',
        'Client configuration file $path does not contain valid JSON.',
        parameters: {'path': path},
        rootException: exception,
        stack: stack,
      );
    }
    if (decoded is! Map) {
      throw TomClientConfigurationException(
        'client_configuration.store.invalid_content',
        'Client configuration file $path must contain a JSON object, '
            'but holds a ${decoded.runtimeType}.',
        parameters: {'path': path},
      );
    }
    return {
      for (final entry in decoded.entries) '${entry.key}': entry.value,
    };
  }

  @override
  Future<void> write(Map<String, Object?> values) async {
    final file = File(path);
    if (values.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    // Write-then-rename: a rename within a directory is atomic, so a failure
    // part-way through leaves the previous content readable instead of a
    // truncated file — which the store contract requires and which matters
    // more here than anywhere, since a truncated override map silently
    // discards the install's settings.
    final temporary = File('$path.part');
    await temporary.writeAsString(jsonEncode(values), flush: true);
    await temporary.rename(path);
  }
}

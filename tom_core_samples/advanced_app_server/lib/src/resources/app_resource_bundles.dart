/// The app server's text resource bundle (step / todo 7; externalized in RC-24).
///
/// The app client's post-login screens — the board and the item editor — render
/// their labels and hints through the Tom Flutter UI resource system rather than
/// from client-side strings. This is the server-owned source of those texts.
///
/// The texts no longer live as Dart `const` maps: they are a **nested JSON
/// asset** (`assets/resources_app.json`) structured along the client's
/// scope → form → field hierarchy (`todo.item.title.label`, `board.*`). The
/// asset is loaded once and [flattenResourceTree]-ed into the flat
/// `<basePath>.<suffix>` map the `appResources` endpoint serves and the client
/// installs via `TomTextResourceProvider.from(dto.texts)` (todo 9). The flat
/// served shape is byte-equivalent to the pre-RC-24 bundle, so the wire contract
/// and the resource-endpoint tests are unchanged.
///
/// The item-form keys live under `todo.item.*` so a served label key tracks the
/// field's grade key: the field at `todo.item.title` is graded on
/// `todo.item.title` and labelled from `todo.item.title.label`. Board texts use
/// the `board.*` namespace, which has no grade counterpart (the board is not a
/// gradable form). Enum display text (G-RES-5) lives under `global.*` —
/// `global.todostatus.inreview`, `global.projectrole.editor`, … — so the domain
/// enums carry no hardcoded strings and the client resolves each value's text
/// from this bundle.
library;

import 'dart:convert';
import 'dart:io';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

/// Builds the app client's full text bundle (board + item-form texts) from the
/// `assets/resources_app.json` resource tree.
class AppResourceBundles {
  const AppResourceBundles._();

  /// The nested resource asset, resolved relative to the process working
  /// directory (the package root under `dart test`, the server's `working_dir`
  /// at boot — the same convention the datasource/config YAML assets use).
  static const String assetPath = 'assets/resources_app.json';

  /// The flattened bundle, parsed once and memoised.
  static Map<String, Object?>? _cache;

  /// The flat `<basePath>.<suffix>` → text map the bundle carries, loaded from
  /// [assetPath] and flattened on first access.
  static Map<String, Object?> texts() =>
      _cache ??= loadFlatResourceAsset(assetPath);

  /// The app client's full bundle (board + item-form texts).
  static ResourceBundleDto appBundle() => ResourceBundleDto(texts());
}

/// Reads a nested JSON resource asset at [path] (working-directory-relative) and
/// flattens it to the flat `<basePath>.<suffix>` map the wire bundle carries.
///
/// Throws a [StateError] when the asset is missing, rather than silently serving
/// an empty bundle — an absent text asset would otherwise break the
/// no-hard-coded-strings property invisibly.
Map<String, Object?> loadFlatResourceAsset(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Resource asset not found: $path (cwd: ${Directory.current.path})',
    );
  }
  final tree = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return flattenResourceTree(tree);
}

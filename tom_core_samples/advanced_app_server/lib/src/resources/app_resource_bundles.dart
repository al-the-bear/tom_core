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
///
/// The framework's own file-field chrome is worded here too, at the **global**
/// level the framework resolves it from: `file.*` (choose / progress / retry /
/// cancel wording read by `TomFileLabels`), `file_transfer.*` (the transport's
/// stable error keys) and `error.file*` (the picker's rejection reasons, shared
/// with the form validators that raise the same keys). Global rather than
/// scoped, because one wording for every file field in the app is the point —
/// a per-field override remains possible by repeating the key under that
/// field's base path.
///
/// The item's attachment is worded under `board.item.attachment.*`, **not**
/// under `todo.item.*`: [AppResourceBundles.gradableItemKeys] derives the
/// graded field set from the `todo.item.*` keys, and the attachment is not a
/// graded field — it is a file slot, authorized by the item's resource state.
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

  /// The scope/`tomId` prefix (`todo.item.`) every gradable field key sits under.
  static const String gradableItemPrefix = 'todo.item.';

  /// The gradable `todo.item.<field>` keys, in the display order the served
  /// bundle labels them — the app server's **single source** for the gradable
  /// item set (step 21). Derived from the fields labelled under `todo.item.*` in
  /// [texts] rather than a hand-maintained list, so a field added to or removed
  /// from the resource tree changes the graded set with it. Both the field-grade
  /// resolver (which reports a [TomAuthState] per key) and the write path (which
  /// enforces grades per column) address exactly these keys.
  ///
  /// The bundle — not raw entity reflection — is the source because it carries
  /// the wire tokens the two authorization layers agree on (`estimate`, whose
  /// reflected member is `estimateHours`; D-A2). The bundle↔domain linkage is
  /// held by the `resource_key_consistency` drift guard.
  static List<String> gradableItemKeys() {
    final seen = <String>{};
    final keys = <String>[];
    for (final key in texts().keys) {
      if (!key.startsWith(gradableItemPrefix)) continue;
      // `todo.item.<field>.<suffix>` — the field token sits at index 2.
      final parts = key.split('.');
      if (parts.length < 4) continue;
      final field = parts[2];
      if (seen.add(field)) keys.add('$gradableItemPrefix$field');
    }
    return keys;
  }
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
